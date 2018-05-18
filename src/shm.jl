#
# shm.jl --
#
# Management of shared memory for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

const BAD_PTR = Ptr{Void}(-1)


"""
# Array attached to a shared memory segment

The method `ShmArray()` returns an array whose elements are stored in shared
memory.  There are different possibilities depending whether a new shared
memory segment should be created or one wants to attach an array to an existing
memory segment.

To get an array attached to a new *volatile* shared memory segment:

```julia
ShmArray(T, dims...; key=IPC.PRIVATE, perms=..., info=...,
                     offset=0, persistent=false)
```

where `T` and `dims` are the element type and the dimensions of the array.
Unless keyword `persistent` is set `true`, the shared memory segment is
*volatile* in the sense that it will be automatically destroyed when no more
processes are attached to it (method `shmrm` can be called later to have the
shared memory automatically destroyed when no more processes are attached to
it).  Keyword `key` may be used to specify an IPC key other than the default
`IPC.PRIVATE`.  If `key` is not `IPC.PRIVATE`, the method will fail if an IPC
identifer already exists with that key.  Keyword `perms` can be used to specify
the access permissions for the created shared memory segment, at least
read-write access to the caller will be granted.  Keyword `offset` can be used
to specify the offset (in bytes) of the first element of the array relative to
the base of the shared memory segment (`offset` must be a multiple of
`Base.datatype_alignment(T)`).

The `shmid` method can be applied to the returned shared memory array to
retrieve the identifier of the associated shared memory.  This identifier is
need to attach the shared memory in another process.

To attach an array to an existing shared memory segment:

```julia
ShmArray(id; readonly=false, info=...)
ShmArray(id, T; readonly=false, info=...)
ShmArray(id, T, dims...; readonly=false, info=...)
```

where `id` is the identifier of the shared memory segment of the IPC key
associated with it (the value returned by the `shmid` method).  Arguments `T`
and `dims` specify the element type and the dimensions of the array associated
with the attached shared memory segment.  If the element type is not specified,
`UInt8` is assumed.  If the dimensions are not specified, the result is a the
longest vector of that type which fits in the shared memory segment.  Keyword
`info` may be set with an instance of `ShmInfo` to store information about the
shared memory segment.  Keyword `readonly` may be set `true` to require
read-only access to the shared memory.  By default, a read-write access is
granted.  Whatever the requested access, the caller must have sufficient
permissions.

Finally:

```julia
ShmArray(arr; key=IPC.PRIVATE, perms=...)
```

yields a new shared memory array whose type, dimensions and contents are copied
from `arr`.

The value returned by `ShmArray()`, say `shm`, behaves like a dense Julia
array:

```julia
shm[i]          # retrieve value of i-th byte
shm[i] = val    # set value of i-th byte
```

of course, `i` can also be a range, multiple indices, etc.  The number of
elements, the dimensions, etc., are accessible by:

```julia
length(shm)
sizeof(shm)
size(shm)
size(shm, i)
eltype(shm)
```

The handle can also be reinterpreted or reshaped:

```julia
reinterpret(T, shm)
reshape(shm, dims)
```

See also: [`shmid`](@ref), [`shmrm`](@ref), [`Base.datatype_alignment`](@ref).

"""
function ShmArray(::Type{T}, dims::NTuple{N,Int};
                  key::Key=PRIVATE, perms::Integer=0,
                  offset::Integer=0, persistent::Bool=false,
                  info::ShmInfo=ShmInfo()) :: ShmArray{T,N} where {T,N}
    # Check arguments and compute size of shared memory segment.
    _checktypeoffset(T, offset)
    number = checkdims(dims)
    nbytes = offset + sizeof(T)*number

    # Get shared memory segment (make sure creator has at least read-write
    # access).
    flags = (Cint(perms & (S_IRWXU|S_IRWXG|S_IRWXO)) |
             (S_IRUSR|S_IWUSR|IPC_CREAT|IPC_EXCL))
    id = shmget(key, nbytes, flags)

    # Attach shared memory segment to process address space and wrap a Julia
    # array around it.
    ptr = C_NULL
    try
        ptr = shmat(id, false)
        shminfo!(id, info)
        info.segsz ≥ nbytes || error("shared memory segment is too small")
        persistent || shmrm(id) # mark for destruction on last detach
        return _buildsharedarray(id, ptr, offset, T, dims)
    catch ex
        _shmrm(id)
        ptr != C_NULL && _shmdt(ptr)
        rethrow(ex)
    end
end

ShmArray(T::DataType, dims::Integer...; kwds...) =
    ShmArray(T, makedims(dims); kwds...)

function ShmArray(id::ShmId, ::Type{T}=UInt8;
                  readonly::Bool=false, info::ShmInfo=ShmInfo(),
                  offset::Integer=0) :: ShmArray{T,1} where {T}
    # Check arguments and compute number of elements after offset.
    _checktypeoffset(T, offset)
    shminfo!(id, info)
    segsz = info.segsz
    offset ≤ segsz ||
        throw(ArgumentError("offset must be smaller or equal $segsz"))
    len = convert(Int, div(segsz - offset, sizeof(T)))

    # Attach shared memory segment to process address space and wrap a Julia
    # array around it.
    ptr = shmat(id, readonly)
    try
        return _buildsharedarray(id, ptr, offset, T, (len,))
    catch ex
        _shmdt(ptr)
        rethrow(ex)
    end
end

ShmArray(key::Key, T::DataType=UInt8; readonly::Bool=false, kwds...) =
    ShmArray(shmid(key, readonly), T; readonly=readonly, kwds...)

function ShmArray(id::ShmId, ::Type{T}, dims::NTuple{N,Int};
                  readonly::Bool=false, info::ShmInfo=ShmInfo(),
                  offset::Integer=0) :: ShmArray{T,N} where {T,N}
    # Check arguments and compute size of shared memory segment.
    _checktypeoffset(T, offset)
    number = checkdims(dims)
    nbytes = offset + sizeof(T)*number
    shminfo!(id, info)
    info.segsz ≥ nbytes || error("shared memory segment is too small")

    # Attach shared memory segment to process address space and wrap a Julia
    # array around it.
    ptr = shmat(id, readonly)
    try
        return _buildsharedarray(id, ptr, offset, T, dims)
    catch ex
        _shmdt(ptr)
        rethrow(ex)
    end
end

function _buildsharedarray(id::ShmId, ptr::Ptr{Void},
                           offset::Integer, ::Type{T},
                           dims::NTuple{N,Int})::ShmArray{T,N} where {T,N}
    arr = unsafe_wrap(Array, Ptr{T}(ptr + offset), dims, false)
    return ShmArray{T,N}(arr, ptr, id)
end

function _checktypeoffset(T::DataType, offset::Integer)
    isbits(T) || throw(ArgumentError("illegal element type ($T)"))
    if offset > 0
        n = Base.datatype_alignment(T)
        rem(offset, n) == 0 ||
            throw(ArgumentError("offset must be a multiple of $n bytes"))
    elseif offset < 0
        throw(ArgumentError("offset must be nonnegative"))
    end
end

function ShmArray(key::Key, ::Type{T}, dims::NTuple{N,Int};
                  readonly::Bool=false, kwds...) where {T,N}
    ShmArray(shmid(key, readonly), T, dims; readonly=readonly, kwds...)
end

function ShmArray(arg::Union{ShmId,Key}, ::Type{T},
                  dims::Integer...; kwds...) where {T}
    ShmArray(arg, T, makedims(dims); kwds...)
end

ShmArray(arr::AbstractArray{T,N}; kwds...) where {T,N} =
    copy!(ShmArray(T, size(arr); kwds...), arr)

_destroy(obj::ShmArray) = shmdt(obj.ptr)

Base.convert(::Type{ShmArray{T,N}}, arr::AbstractArray{T,N}) where {T,N} =
    ShmArray(arr)

Base.convert(::Type{ShmArray{T,N}}, arr::ShmArray{T,N}) where {T,N} = arr

Base.getindex(shm::ShmArray, i1) = getindex(shm.arr, i1)

Base.getindex(shm::ShmArray, i1, i2...) = getindex(shm.arr, i1, i2...)

Base.setindex!(shm::ShmArray, value, i1) = setindex!(shm.arr, value, i1)

Base.setindex!(shm::ShmArray, value, i1, i2...) =
    setindex!(shm.arr, value, i1, i2...)

Base.eltype(shm::ShmArray{T,N}) where {T,N} = T

Base.length(shm::ShmArray) = length(shm.arr)

Base.ndims(shm::ShmArray{T,N}) where {T,N} = N

Base.sizeof(shm::ShmArray) = sizeof(shm.arr)

Base.size(shm::ShmArray) = size(shm.arr)

Base.size(shm::ShmArray, i::Number) = size(shm.arr, i)

Base.eachindex(shm::ShmArray) = eachindex(shm.arr)

Base.IndexStyle(::Type{<:ShmArray}) = Base.IndexLinear()

Base.stride(shm::ShmArray, i::Integer) = stride(shm.arr, i)

Base.strides(shm::ShmArray) = strides(shm.arr)

Base.copy(shm::ShmArray) = copy(shm.arr)

Base.copy!(dest::ShmArray, src::AbstractArray) = (copy!(dest.arr, src); dest)

Base.pointer(shm::ShmArray) = pointer(shm.arr)

Base.reinterpret(::Type{T}, shm::ShmArray) where {T} =
    reinterpret(T, shm.arr)

Base.reshape(shm::ShmArray, dims::Tuple{Vararg{Int}}) =
    reshape(shm.arr, dims)

"""
# Get the identifier of an existing shared memory segment

The following calls:

```julia
shmid(id)                  -> id
shmid(shmarr)              -> id
shmid(key, readlony=false) -> id
```

yield the the identifier of the existing shared memory segment associated with
the value of the first argument.  `id` is the identifier of the shared memory
segment, `shmarr` is a shared array attached to the shared memory segment and
`key` is the key associated with the shared memory segment.  In that latter
case, `readlony` can be set `true` to only request read-only access; otherwise
read-write access is requested.

"""
shmid(id::ShmId) = id
shmid(shmarr::ShmArray) = shmarr.id
shmid(key::Key, readonly::Bool=false) =
    shmget(key, 0, (readonly ? S_IRUSR : (S_IRUSR|S_IWUSR)))

"""
# Get or create a shared memory segment

The call:

```julia
shmget(key, siz, flg) -> id
```

yields the identifier of the shared memory segment associated with the value of
the argument `key`.  A new shared memory segment, with size equal to the value
of `siz` (possibly rounded up to a multiple of the memory page size
`IPC.PAGE_SIZE`), is created if `key` has the value `IPC.PRIVATE` or `key`
isn't `IPC.PRIVATE`, no shared memory segment corresponding to `key` exists,
and `IPC_CREAT` is specified in argument `flg`.

Arguments are:

* `key` is the System V IPC key associated with the shared memory segment.

* `siz` specifies the size (in bytes) of the shared memory segment (may be
  rounded up to multiple of the memory page size).

* `flg` specify bitwise flags.  The least significant 9 bits specify the
  permissions granted to the owner, group, and others.  These bits have the
  same format, and the same meaning, as the mode argument of `chmod`.  Bit
  `IPC_CREAT` can be set to create a new segment.  If this flag is not used,
  then `shmget` will find the segment associated with `key` and check to see if
  the user has permission to access the segment.  Bit `IPC_EXCL` can be set in
  addition to `IPC_CREAT` to ensure that this call creates the segment.  If
  `IPC_EXCL` and `IPC_CREAT` are both set, the call will fail if the segment
  already exists.

"""
function shmget(key::Key, siz::Integer, flg::Integer)
    id = ccall(:shmget, Cint, (_typeof_key_t, Csize_t, Cint),
               key.value, siz, flg)
    systemerror("shmget", id < 0)
    return ShmId(id)
end

"""
```julia
shmat(id, readonly) -> ptr
```

attaches a shared memory segment to the address space of the caller.  Argument
`id` is the identifier of the shared memory segment.  Boolean argument
`readonly` specifies whether to attach the segment for read-only access;
otherwise, the segment is attached for read and write access and the process
must have read and write permission for the segment.  The returned value is the
pointer to access the shared memory segment.

See also: [`shmat!`](@ref), [`shmdt`](@ref), [`shmrm`](@ref).

"""
function shmat(id::ShmId, readonly::Bool)
    shmflg = (readonly ? SHM_RDONLY : zero(SHM_RDONLY))
    ptr = ccall(:shmat, Ptr{Void}, (Cint, Ptr{Void}, Cint),
                id.value, C_NULL, shmflg)
    systemerror("shmat", ptr == BAD_PTR)
    return ptr
end

"""
```julia
shmat!(id, readonly, info) -> ptr
```

attaches a shared memory segment to the address space of the caller.  Argument
`id`, argument `readonly` and returned value are the same as for `shmat`.
Argument `info` is used to store information about the shared memory segment.

See also: [`shmat`](@ref), [`shmdt`](@ref), [`shmrm`](@ref).

"""
function shmat!(id::ShmId, readonly::Bool, info::ShmInfo)
    ptr = shmat(id, readonly)
    try
        shminfo!(id, info)
    catch err
        _shmdt(ptr)
        rethrow(err)
    end
    return ptr
end

"""
```julia
shmdt(ptr)
```

detaches a shared memory segment from the address space of the caller.
Argument `ptr` is the pointer returned by a previous `shmat()` or `shmat!()`
call.

"""
shmdt(ptr::Ptr{Void}) = systemerror("shmdt", _shmdt(ptr) != SUCCESS)

@inline _shmdt(ptr::Ptr{Void}) = ccall(:shmdt, Cint, (Ptr{Void},), ptr)


"""
# Mark a shared memory segment for destruction

To ensure that a shared memory segment is destroyed when no more processes are
attached to it, call:

```julia
shmrm(arg) -> id
```

where the argument can be the identifier of the shared memory segment, a shared
array attached to the shared memory segment or the System V IPC key associated
with the shared memory segment.  In all cases, the identifier of the shared
memory segment is returned.

See also: [`shmat`](@ref), [`shmdt`](@ref);

"""
function shmrm(id::ShmId)
    systemerror("failed to mark shared memory segment for destruction",
                _shmrm(id) != SUCCESS)
    return id
end

shmrm(arg::Union{ShmArray,Key}) = shmrm(shmid(arg))

_shmrm(id::ShmId) = _shmctl(id, IPC_RMID, C_NULL)

"""
# Configure access permissions of a shared memory segment

To change the access permissions of a shared memory segment, call:

```julia
shmcfg(arg, perms) -> id
```

where `perms` specifies bitwise flags with the new permissions.  The first
argument can be the identifier of the shared memory segment, a shared array
attached to the shared memory segment or the System V IPC key associated with
the shared memory segment.  In all cases, the identifier of the shared memory
segment is returned.

"""
function shmcfg(id::ShmId, perms::Cushort)
    buf = Libc.malloc(_sizeof_struct_shmid_ds)
    buf != C_NULL || throw(OutOfMemoryError())
    status = _shmctl(id, IPC_STAT, buf)
    if status == SUCCESS
        const PERMS_MASK = Cushort(0777)
        mode = _peek(Cushort, buf, _offsetof_shm_perm_mode)
        if (mode & PERMS_MASK) != (perms & PERMS_MASK)
            _poke!(Cushort, buf, _offsetof_shm_perm_mode,
                   (mode & ~PERMS_MASK) | (perms & PERMS_MASK))
            status = _shmctl(id, IPC_SET, buf)
        end
    end
    Libc.free(buf)
    systemerror("shmctl", status != SUCCESS)
    return id
end

shmcfg(id::ShmId, perms::Integer) =
    shmcfg(shmid(arg), Cushort(perms))

shmcfg(arg::Union{ShmArray,Key}, perms::Integer) =
    shmcfg(shmid(arg), perms)

"""
# Retrieve information about a shared memory segment

To store information about a shared memory segment into `info`, call:

```julia
shminfo!(arg, info) -> info
```

where `info` is an instance of `ShmInfo` and the first argument can be
the identifier of the shared memory segment, a shared array attached to the
shared memory segment or the System V IPC key associated with the shared memory
segment.  In all cases, `info` is returned.

To retrieve information about a shared memory segment without providing an
instance of `ShmInfo`, call:

```julia
shminfo(arg) -> info
```
"""
function shminfo!(id::ShmId, info::ShmInfo)
    buf = Libc.malloc(_sizeof_struct_shmid_ds)
    buf != C_NULL || throw(OutOfMemoryError())
    status = _shmctl(id, IPC_STAT, buf)
    if status == SUCCESS
        info.atime  = _peek(_typeof_time_t,   buf, _offsetof_shm_atime)
        info.dtime  = _peek(_typeof_time_t,   buf, _offsetof_shm_dtime)
        info.ctime  = _peek(_typeof_time_t,   buf, _offsetof_shm_ctime)
        info.segsz  = _peek(Csize_t,          buf, _offsetof_shm_segsz)
        info.id     = id.value
        info.cpid   = _peek(_typeof_pid_t,    buf, _offsetof_shm_cpid)
        info.lpid   = _peek(_typeof_pid_t,    buf, _offsetof_shm_lpid)
        info.nattch = _peek(_typeof_shmatt_t, buf, _offsetof_shm_nattch)
        info.mode   = _peek(Cushort,          buf, _offsetof_shm_perm_mode)
        info.uid    = _peek(_typeof_uid_t,    buf, _offsetof_shm_perm_uid)
        info.gid    = _peek(_typeof_gid_t,    buf, _offsetof_shm_perm_gid)
        info.cuid   = _peek(_typeof_uid_t,    buf, _offsetof_shm_perm_cuid)
        info.cgid   = _peek(_typeof_gid_t,    buf, _offsetof_shm_perm_cgid)
    end
    Libc.free(buf)
    systemerror("shmctl", status != SUCCESS)
    return info
end

shminfo!(arr::ShmArray, info::ShmInfo) = shminfo!(shmid(arr), info)

shminfo!(key::Key, info::ShmInfo) = shminfo!(shmid(key, true), info)

shminfo(arg::Union{ShmId,ShmArray,Key}) = shminfo!(arg, ShmInfo())

@doc @doc(shminfo!) shminfo

# Low-level call (i.e., no checking of the argumenst, nor of the returned
# status).
@inline _shmctl(id::ShmId, cmd, buf) =
    ccall(:shmctl, Cint, (Cint, Cint, Ptr{Void}), id.value, cmd, buf)

#------------------------------------------------------------------------------
# SHARED ARRAYS WITH HEADER

const SHMARR_MAGIC = UInt32(0x4D417631) # "MAv1" = Memory Array version 1
const SHMARR_ALIGN = max(sizeof(Int), 64) # require atl least 512 bits alignment

const SHMARR_TYPES = (( 1, Int8,       "signed 8-bit integer"),
               ( 2, UInt8,      "unsigned 8-bit integer"),
               ( 3, Int16,      "signed 16-bit integer"),
               ( 4, UInt16,     "unsigned 16-bit integer"),
               ( 5, Int32,      "signed 32-bit integer"),
               ( 6, UInt32,     "unsigned 32-bit integer"),
               ( 7, Int64,      "signed 64-bit integer"),
               ( 8, UInt64,     "unsigned 64-bit integer"),
               ( 9, Float32,    "32-bit floating-point"),
               (10, Float64,    "64-bit floating-point"),
               (11, Complex64,  "64-bit complex"),
               (12, Complex128, "128-bit complex"))

const SHMARR_ETYPES = DataType[T for (i, T, str) in SHMARR_TYPES]
const SHMARR_ESIZES = Int[sizeof(T) for (i, T, str) in SHMARR_TYPES]
const SHMARR_DESCRS = String[str for (i, T, str) in SHMARR_TYPES]
const SHMARR_IDENTS = Dict(T => i for (i, T, str) in SHMARR_TYPES)

#
# header is:
#   magic  4-bytes
#   etype  2-bytes
#   ndims  2-bytes
#   pad    (to have remaining fields aligned)
#   offset sizeof(Int)
#   dim1   sizeof(Int)
#   dim2   sizeof(Int)
#   ...
# minimal size if

struct ShmArrHeader
    magic::UInt32 # magic number to check correctness
    etype::UInt16 # identifier of element type
    ndims::UInt16 # number of dimensions
    offset::Int   # size of header
end

"""
```julia
shmarr(T, dims)
```

yields a new array with elements of type `T` and dimensions `dims` and whose
contents is stored in shared memory.  Keywords like `perms`, `key`,
`persistent` and `info` can be specified (see [`ShmArray`](@ref)).

Compared to directly call `ShmArray`, this method also write a descriptor of
the array (element type and dimensions) in shared memory so that it is easier
to retrieve the array for another process by calling:

```julia
shmarr(id; readonly=false)
```

which yields a Julia array whose contents has been stored in shared memory by a
call to `shmarr` as above.  Here `id` is the shared memory identifier (provided
by `shmid`) of the same IPC key as the one used to create the shared memory
array.  Beware that, for this mechanim to work, `id` must correspond to an
array created with `shmarr` (not directly with `ShmArray`).

See also: [`shmid`](@ref), [`IPC.Key`](@ref), [`ShmArray`](@ref).

"""
function shmarr(::Type{T}, dims::NTuple{N,Int};
                kwds...) :: ShmArray{T,N} where {T,N}
    # Check inputs.
    haskey(SHMARR_IDENTS, T) ||
        throw(ArgumentError("unsupported data type ($T)"))
    ident = SHMARR_IDENTS[T]

    # Compute offset to store header and create array.
    offset = div(sizeof(ShmArrHeader) + N*sizeof(Int) + SHMARR_ALIGN - 1,
                 SHMARR_ALIGN)*SHMARR_ALIGN
    arr = ShmArray(T, dims; kwds..., offset=offset)

    # Retrieve address of shared memory segment.
    ptr = arr.ptr
    @assert pointer(arr.arr) == ptr + offset

    # Write header and dimensions.
    hdr = ShmArrHeader(SHMARR_MAGIC, ident, N, offset)
    unsafe_store!(Ptr{ShmArrHeader}(ptr), hdr)
    addr = Ptr{Int}(ptr + sizeof(ShmArrHeader))
    for i in 1:N
        unsafe_store!(addr, dims[i], i)
    end

    # Return shared array.
    return arr
end

shmarr(::Type{T}, dims::Integer...; kwds...) where {T} =
    shmarr(T, makedims(dims); kwds...)

shmarr(::Type{T}, dims::NTuple{N,Integer}; kwds...) where {T,N} =
    shmarr(T, makedims(dims); kwds...)

shmarr(key::Key; readonly::Bool=false) =
    shmarr(shmid(key, readonly); readonly=readonly)

function shmarr(id::ShmId; readonly::Bool=false)
    const NTYPES = length(SHMARR_ETYPES)
    info = shminfo(id)
    segsz = info.segsz
    segsz ≥ sizeof(ShmArrHeader) ||
        error("too small shared memory segment ($(Int(segsz)) bytes)")
    ptr = shmat(id, readonly)
    try
        hdr = _peek(ShmArrHeader, ptr)
        hdr.magic == SHMARR_MAGIC ||
            error("invalid magic number (0x$(hex(hdr.magic)))")
        etype = Int(hdr.etype)
        1 ≤ etype ≤ NTYPES || error("invalid element type identifier ($etype)")
        ndims = Int(hdr.ndims)
        1 ≤ ndims || error("invalid number of dimensions ($ndims)")
        offset = Int(hdr.offset)
        offset ≥ sizeof(ShmArrHeader) + ndims*sizeof(Int) ||
            error("too small offset ($offset)")
        addr = Ptr{Int}(ptr + sizeof(ShmArrHeader))
        dims = ntuple(i -> unsafe_load(addr, i), ndims)
        number = checkdims(dims)
        T = SHMARR_ETYPES[etype]
        segsz ≥ sizeof(T)*number + offset ||
            error("too small shared memory segment ($(Int(segsz)) bytes)")
        return _buildsharedarray(id, ptr, offset, T, dims)
    catch ex
        _shmdt(ptr)
        rethrow(ex)
    end
end
