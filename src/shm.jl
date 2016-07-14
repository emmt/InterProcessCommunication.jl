#
# shm.jl --
#
# Management of shared memory for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016, Éric Thiébaut (https://github.com/emmt).
#

immutable ShmId
    value::Cint
end

type ShmArray{T,N} <: DenseArray{T,N}
    # All members shall be considered as private.
    _buf::Array{T,N}
    _ptr::Ptr{Void}
    _id::ShmId
    function ShmArray(buf::Array{T,N}, ptr::Ptr{Void},
                               id::ShmId)
        @assert pointer(buf) == ptr
        obj = new(buf, ptr, id)
        finalizer(obj, obj -> shmdt(obj._ptr))
        return obj
    end
end

type ShmInfo
    atime::UInt64 # last attach time
    dtime::UInt64 # last detach time
    ctime::UInt64 # last change time
    segsz::UInt64 # size of the public area
    id::Int32     # shared memory identifier
    cpid::Int32   # process ID of creator
    lpid::Int32   # process ID of last operator
    nattch::Int32 # no. of current attaches
    mode::UInt32  # lower 9 bits of access modes
    uid::UInt32   # effective user ID of owner
    gid::UInt32   # effective group ID of owner
    cuid::UInt32  # effective user ID of creator
    cgid::UInt32  # effective group ID of creator
    ShmInfo() = new(0,0,0,0,0,0,0,0,0,0,0,0,0)
end

const BAD_PTR = Core.Intrinsics.box(Ptr{Void}, -1)

# a bit of magic for calling C-code:
convert(::Type{Cint}, id::ShmId) = id.value
convert(::Type{ASCIIString}, id::ShmId) = string(id)

string(id::ShmId) = dec(id.value)
show(io::IO, id::ShmId) =
    (write(io, "IPC.ShmId: "*dec(id.value)); nothing)

"""
# Array attached to a shared memory segment

The methods `ShmArray()` return an array whose elements are stored in shared
memory.  There are different possibilities depending whether a new shared
memory segment should be created or one wants to attach an array to an existing
memory segment.

To get an array attached to a new *volatile* shared memory segment:

    ShmArray(T, dims...; key=IPC.PRIVATE, perms=...)

where `T` and `dims` are the type of the array elements and the dimensions of
the array.  The shared memory segment is *volatile* in the sense that it will
be automatically destroyed when no more processes are attached to it.  Keyword
`key` may be used to specify an IPC key other than the default `IPC.PRIVATE`.
If `key` is not `IPC.PRIVATE`, the method will fail if an IPC identifer already
exists with that key.  Keyword `perms` can be used to specify the access
permissions for the created shared memory segment, at least read-write access
to the caller will be granted.

To attach an array to an existing shared memory segment:

    ShmArray(id; readonly=false, info=...)
    ShmArray(id, T; readonly=false, info=...)
    ShmArray(id, T, dims...; readonly=false, info=...)

where `id` is the identifier of the shared memory segment of the IPC key
associated with it.  Arguments `T` and `dims` specify the element type and the
dimensions of the array assiocated with the attached shared memory segment.  If
the element type is not specified, it defaults to `UInt8`.  If the dimensions
are not specified, the result is a the longuest vector of that type which fits
in the shared memory segment.  Keyword `info` may be set with an instance of
`ShmInfo` to store information about the shared memory segment.  Keyword
`readonly` may be set `true` to require read-only access to the shared memory.
Bt default, a read-write access is granted.  Whatever the requested access, the
caller must have sufficient permissions.

Finally:

    ShmArray(arr; key=IPC.PRIVATE, perms=...)

yields a new shared memory array whose type, dimensions and contents are copied
from `arr`.

The value returned by `ShmArray()`, say `shm`, behaves like a dense Julia
array:

    shm[i]          # retrieve value of i-th byte
    shm[i] = val    # set value of i-th byte

of course, `i` can also be a range, multiple indices, etc.  The number of
elements, the dimensions, etc., are accessible by:

    length(shm)
    sizeof(shm)
    size(shm)
    size(shm, i)
    eltype(shm)

The handle can also be reinterpreted or reshaped:

    reinterpret(T, shm)
    reshape(shm, dims)

"""
function ShmArray{T,N}(::Type{T}, dims::NTuple{N,Int};
                       key::Key=IPC.PRIVATE, perms::Integer=0)
    @assert isbits(T)
    siz = sizeof(T)*prod(dims)
    # make sure creator has at least read-write access
    flags = Cuint(perms & 0777) | (IRUSR|IWUSR|CREAT|EXCL)
    id = shmget(key, siz, flags)
    arr = ShmArray(id, T, dims)
    shmrm(arr) # mark for destruction on last detach
    return arr
end

ShmArray{T}(::Type{T}, dims::Integer...; kwds...) =
    ShmArray(T, makedims(dims); kwds...)

function ShmArray(id::ShmId, T::DataType=UInt8;
                  readonly::Bool=false, info::ShmInfo=ShmInfo())
    @assert isbits(T)
    ptr = shmat(id, readonly, info)
    len = div(info.segsz/sizeof(T))
    buf = pointer_to_array(convert(Ptr{T}, ptr), len, false)
    return ShmArray{T,N}(buf, ptr, id)
end

ShmArray(key::Key, T::DataType=UInt8; readonly::Bool=false, kwds...) =
    ShmArray(shmid(key, readonly), T; readonly=readonly, kwds...)

function ShmArray{T,N}(id::ShmId, ::Type{T}, dims::NTuple{N,Int};
                       readonly::Bool=false, info::ShmInfo=ShmInfo())
    @assert isbits(T)
    siz = sizeof(T)*prod(dims)
    ptr = shmat(id, readonly, info)
    if info.segsz < siz
        shmdt(ptr)
        error("shared memory segment is too small")
    end
    buf = pointer_to_array(convert(Ptr{T}, ptr), dims, false)
    return ShmArray{T,N}(buf, ptr, id)
end

function ShmArray{T,N}(key::Key, ::Type{T}, dims::NTuple{N,Int};
                       readonly::Bool=false, kwds...)
    ShmArray(shmid(key, readonly), T, dims; readonly=readonly, kwds...)
end

function ShmArray{T}(arg::Union{ShmId,Key}, ::Type{T},
                     dims::Integer...; kwds...)
    ShmArray(arg, T, makedims(dims); kwds...)
end

ShmArray{T,N}(arr::AbstractArray{T,N}; kwds...) =
    copy!(ShmArray(T, size(arr); kwds...), arr)

convert{T,N}(::Type{ShmArray{T,N}}, arr::AbstractArray{T,N}) =
    ShmArray(arr)

convert{T,N}(::Type{ShmArray{T,N}}, arr::ShmArray{T,N}) = arr

getindex(shm::ShmArray, i1) = getindex(shm._buf, i1)

getindex(shm::ShmArray, i1, i2...) = getindex(shm._buf, i1, i2...)

setindex!(shm::ShmArray, value, i1) = setindex!(shm._buf, value, i1)

setindex!(shm::ShmArray, value, i1, i2...) =
    setindex!(shm._buf, value, i1, i2...)

eltype{T,N}(shm::ShmArray{T,N}) = T

length(shm::ShmArray) = length(shm._buf)

ndims{T,N}(shm::ShmArray{T,N}) = N

sizeof(shm::ShmArray) = sizeof(shm._buf)

size(shm::ShmArray) = size(shm._buf)

size(shm::ShmArray, i::Number) = size(shm._buf, i)

eachindex(shm::ShmArray) = eachindex(shm._buf)

linearindexing{T<:ShmArray}(::Type{T}) = Base.LinearFast()

stride(shm::ShmArray, i::Integer) = stride(shm._buf, i)

strides(shm::ShmArray) = strides(shm._buf)

copy(shm::ShmArray) = copy(shm._buf)

copy!(dest::ShmArray, src::AbstractArray) = (copy!(dest._buf, src); dest)

pointer(shm::ShmArray) = pointer(shm._buf)

reinterpret{T}(::Type{T}, shm::ShmArray) =
    reinterpret(T, shm._buf)

reshape(shm::ShmArray, dims::Tuple{Vararg{Int}}) =
    reshape(shm._buf, dims)

"""
# Get the identifier of an existing shared memory segment

The following calls:

    shmid(id)                  -> id
    shmid(shm)                 -> id
    shmid(key, readlony=false) -> id

yield the the identifier of the existing shared memory segment associated with
the value of the first argument.  `id` is the identifer of the shared memory
segment, `shm` is a shared array attached to the shared memory segment and
`key` is the key associated with the shared memory segment.  In that latter
case, `readlony` can be set `true` to only request read-only access; otherwise
read-write acess is requested.

"""
function shmid end

shmid(id::ShmId) = id
shmid(shm::ShmArray) = shm._id
shmid(key::Key, readonly::Bool=false) =
    shmget(key, 0, (rw ? IPC.IRUSR : (IPC.IRUSR|IPC.IWUSR)))

"""
# Get or create a shared memory segment

The call:

    shmget(key, siz, flg) -> id

yields the identifier of the shared memory segment associated with the value of
the argument `key`.  A new shared memory segment, with size equal to the value
of `siz` (possibly rounded up to a multiple of the memory page size), is
created if `key` has the value `IPC.PRIVATE` or `key` isn't `IPC.PRIVATE`, no
shared memory segment corresponding to `key` exists, and `IPC.CREAT` is
specified in argument `flg`.

Arguments are:

* `key` is the System V IPC key associated with the shared memory segment.

* `siz` specifies the size (in bytes) of the shared memory segment (may be
  rounded up to multiple of the memory page size).

* `flg` specify bitwise flags.  The least significant 9 bits specify the
  permissions granted to the owner, group, and others.  These bits have the
  same format, and the same meaning, as the mode argument of `chmod`.  Bit
  `IPC.CREAT` can be set to create a new segment.  If this flag is not used,
  then `shmget` will find the segment associated with `key` and
  check to see if the user has permission to access the segment.  Bit
  `IPC.EXCL` can be set in addition to `IPC.CREAT` to ensure that this call
  creates the segment.  If the segment already exists, the call fails.

"""
function shmget(key::Key, siz::Integer, flg::Integer)
    id = ccall((:SWL_GetSharedMemory, libswl), Cint,
               (Cint, Csize_t, Cuint), key, siz, flg)
    if id < 0
        error(syserrmsg("failed to create shared memory segment"))
    end
    return ShmId(id)
end

"""
To attach a shared memory segment to the address space of the caller, call:

    shmat(id, readonly, info) -> ptr

with `id` the identifer of the shared memory segment.  Boolean argument
`readonly` specifies whether to attach the segment for read-only access;
otheriwse (the default), the segment is attached for read and write access, and
the process must have read and write permission for the segment.  Argument
`info` is used to store information about the shared memory segment.  The
returned value is the pointer to access the shared memory segment.

"""
function shmat(id::ShmId, readonly::Bool,
               info::ShmInfo)
    ptr = ccall((:SWL_AttachSharedMemory, libswl), Ptr{Void},
                (Cint, Cuint, Ptr{ShmInfo}),
                id, (readonly ? IPC.RDONLY : 0), Ref(info))
    if ptr == BAD_PTR
        error(syserrmsg("failed to attach shared memory segment"))
    end
    return ptr
end

"""
To detach a shared memory segment from the address space of the caller, call:

    shmdt(ptr)

with `ptr` the pointer returned by a previous `shmat()` call.

"""
function shmdt(ptr::Ptr{Void})
    if ccall((:SWL_DetachSharedMemory, libswl), Cint,
             (Ptr{Void},), ptr) != SUCCESS
        error(syserrmsg("failed to detach shared memory segment"))
    end
    nothing
end

"""
# Mark a shared memory segment for destruction

To ensure that a shared memory segment is destroyed when no more processes are
attached to it, call:

    shmrm(arg) -> id

where the argument can be the identifier of the shared memory segment, a shared
array attached to the shared memory segment or the System V IPC key associated
with the shared memory segment.  In all cases, the identifier of the shared
memory segment is returned.

"""
function shmrm(id::ShmId)
    if ccall((:SWL_DestroySharedMemory, libswl), Cint, (Cint,), id) != SUCCESS
        warn(syserrmsg("failed to mark shared memory segment for destruction"))
    end
    return id
end

shmrm(arg::Union{ShmArray,Key}) = shmrm(shmid(arg))

"""
# Configure access permissions of a shared memory segment

To change the access permissions of a shared memory segment, call:

    shmcfg(arg, perms) -> id

where `perms` specifies bitwise flags with the new permissions.  The first
argument can be the identifier of the shared memory segment, a shared array
attached to the shared memory segment or the System V IPC key associated with
the shared memory segment.  In all cases, the identifier of the shared memory
segment is returned.

"""
function shmcfg(id::ShmId, perms::Integer)
    if ccall((:SWL_ConfigureSharedMemory, libswl), Cint,
             (Cint, Cuint), id, (perms | 0777)) != SUCCESS
        error(syserrmsg("failed to configure shared memory segment"))
    end
    return id
end

shmcfg(arg::Union{ShmArray,Key}, perms::Integer) =
    shmcfg(shmid(arg), perms)

"""
# Retrieve information about a shared memory segment

To store information about a shared memory segment into `info`, call:

    shminfo!(arg, info) -> info

where `info` is an instance of `ShmInfo` and the first argument can be
the identifier of the shared memory segment, a shared array attached to the
shared memory segment or the System V IPC key associated with the shared memory
segment.  In all cases, `info` is returned.

To retrieve information about a shared memory segment without providing an
instance of `ShmInfo`, call:

    shminfo(arg) -> info

"""
function shminfo!(id::ShmId, info::ShmInfo)
    if ccall((:SWL_QuerySharedMemoryInfo, libswl), Cint,
             (Cint, Ptr{ShmInfo}), id, Ref(info)) != SUCCESS
        error(syserrmsg("failed to retrieve shared memory segment information"))
    end
    return info
end

shminfo!(arr::ShmArray, info::ShmInfo) = shminfo!(shmid(arr), info)

shminfo!(key::Key, info::ShmInfo) = shminfo!(shmid(key, true), info)

shminfo(arg::Union{ShmId,ShmArray,Key}) = shminfo!(arg, ShmInfo())

@doc @doc(shminfo!) shminfo
