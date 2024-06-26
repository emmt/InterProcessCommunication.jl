#
# shm.jl --
#
# Management of shared memory for Julia.  Both POSIX and System V shared memory
# models are supported.
#
#------------------------------------------------------------------------------
#
# This file is part of InterProcessCommunication.jl released under the MIT
# "expat" license.
#
# Copyright (c) 2016-2024, Éric Thiébaut
# (https://github.com/emmt/InterProcessCommunication.jl).
#

"""
```julia
SharedMemory(id, len; perms=0o600, volatile=true)
```

yields a new shared memory object identified by `id` and whose size is `len`
bytes.  The identifier `id` can be a string starting by a `'/'` to create a
POSIX shared memory object or a System V IPC key to create a System V shared
memory segment.  In this latter case, the key can be `IPC.PRIVATE` to
automatically create a non-existing shared memory segment.

Keyword `perms` can be used to specify which access permissions are granted.
By default, only reading and writing by the user is granted.

Keyword `volatile` can be used to specify whether the shared memory is volatile
or not.  If non-volatile, the shared memory will remain accessible until
explicit destruction or system reboot.  By default, the shared memory is
destroyed when no longer in use.

To retrieve an existing shared memory object, call:

```julia
SharedMemory(id; readonly=false)
```

where `id` is the shared memory identifier (a string, an IPC key or a System V
IPC identifier of shared memory segment as returned by `ShmId`).  Keyword
`readonly` can be set true if only read access is needed.  Note that method
`shmid(obj)` may be called to retrieve the identifier of the shared memory
object `obj`.

Some methods are extended for shared memory objects.  Assuming `shm` is an
instance of `SharedMemory`, then:

```julia
pointer(shm)    # yields the base address of the shared memory
sizeof(shm)     # yields the number of bytes of the shared memory
shmid(shm)      # yields the identifier the shared memory
```

To ensure that shared memory object `shm` is eventually destroyed, call:

```julia
rm(shm)
```

See also [`shmid`](@ref), [`shmrm`](@ref).

"""
function SharedMemory(key::Key, len::Integer;
                      perms::Integer = S_IRUSR|S_IWUSR,
                      volatile::Bool = true)::SharedMemory{ShmId}
    # Create a new System V shared memory segment with given size and, at
    # least, read and write access for the caller.
    len ≥ 1 || throw_argument_error("bad number of bytes (", len, ")")
    flags = maskmode(perms) | (S_IRUSR|S_IWUSR|IPC_CREAT|IPC_EXCL)
    id = _shmget(key.value, len, flags)
    if id < 0
        throw_system_error("shmget")
    end

    # Attach shared memory segment to process address space.
    ptr = _shmat(id, C_NULL, 0)
    if ptr == Ptr{Cvoid}(-1)
        errno = Libc.errno()
        _shmctl(id, IPC_RMID, C_NULL)
        throw_system_error("shmat", errno)
    end
    if volatile && _shmctl(id, IPC_RMID, C_NULL) == -1
        errno = Libc.errno()
        _shmdt(ptr)
        throw_system_error("shmctl", errno)
    end

    # Instanciate Julia object.
    return SharedMemory{ShmId}(ptr, len, volatile, ShmId(id))
end

SharedMemory(key::Key; readonly::Bool = false, kwds...) =
    SharedMemory(ShmId(key, readonly); kwds...)

function SharedMemory(id::ShmId; readonly::Bool=false)::SharedMemory{ShmId}
    len = sizeof(id)
    ptr = shmat(id, readonly)
    return SharedMemory{ShmId}(ptr, len, false, id)
end

# Create a new POSIX shared memory object.
function SharedMemory(name::AbstractString,
                      len::Integer;
                      perms::Integer = S_IRUSR | S_IWUSR,
                      volatile::Bool = true) :: SharedMemory{String}
    # Make sure owner has read and write permissions (otherwise setting the
    # size will fail).
    mode = maskmode(perms) | (S_IRUSR | S_IWUSR)
    flags = O_CREAT | O_EXCL | O_RDWR
    return SharedMemory(name, flags, mode, len, volatile)
end

# Map an existing POSIX shared memory object.
function SharedMemory(name::AbstractString;
                      readonly::Bool=false) :: SharedMemory{String}
    flags = (readonly ? O_RDONLY : O_RDWR)
    mode = (readonly ? S_IRUSR : S_IRUSR|S_IWUSR)
    return SharedMemory(name, flags, mode, 0, false)
end

function SharedMemory(name::AbstractString,
                      flags::Integer,
                      mode::Integer,
                      len::Integer = 0,
                      volatile::Bool = false)

    # Create a new POSIX shared memory object?
    create = ((flags & O_CREAT) != 0)
    if create
        len ≥ 1 || throw_argument_error("bad number of bytes (", len, ")")
    end

    # Open shared memory and set or get its size.
    fd = _shm_open(name, flags, mode)
    if fd == -1
        throw_system_error("shm_open")
    end
    local nbytes::Int = 0
    if create
        # Set the size of the new shared memory object.
        if _ftruncate(fd, len) != SUCCESS
            errno = Libc.errno()
            _close(fd)
            _shm_unlink(name)
            throw_system_error("ftruncate", errno)
        end
        nbytes = Int(len)
    else
        # Get the size of the existing shared memory object.
        try
            nbytes = Int(filesize(fd))
        catch err
            _close(fd)
            rethrow(err)
        end
    end

    # Map the shared memory.  Note that `prot = PROT_NONE` should never occur.
    access = flags & (O_RDONLY|O_WRONLY|O_RDWR)
    prot = (access == O_RDONLY ? PROT_READ :
            access == O_WRONLY ? PROT_WRITE :
            access == O_RDWR   ? PROT_READ|PROT_WRITE : PROT_NONE)
    ptr = _mmap(C_NULL, nbytes, prot, MAP_SHARED, fd, 0)
    if ptr == MAP_FAILED
        errno = Libc.errno()
        _close(fd)
        if create
            _shm_unlink(name)
        end
        throw_system_error("mmap", errno)
    end

    # File descriptor can be closed.
    if _close(fd) != SUCCESS
        errno = Libc.errno()
        if create
            _shm_unlink(name)
        end
        _munmap(ptr, len)
        throw_system_error("close", errno)
    end

    # Return the shared memory object.
    return SharedMemory{String}(ptr, nbytes, volatile, String(name))
end

function _destroy(obj::SharedMemory{String})
    if obj.volatile
        _shm_unlink(obj.id)
    end
    _munmap(obj.ptr, obj.len)
    if PARANOID
        obj.ptr = C_NULL
        obj.len = 0
        obj.volatile = false
        obj.id = ""
    end
end

function _destroy(obj::SharedMemory{ShmId})
    _shmdt(obj.ptr)
    if PARANOID
        obj.ptr = C_NULL
        obj.len = 0
        obj.volatile = false
        obj.id = ShmId(-1)
    end
end

Base.sizeof(obj::SharedMemory) = obj.len
Base.pointer(obj::SharedMemory) = obj.ptr

# The short version of `show` if also used for string interpolation in
# scripts so that it is not necessary to extend methods:
#     Base.convert(::Type{String}, obj::T)
#     Base.string(obj::T)

Base.show(io::IO, obj::SharedMemory{String}) =
    print(io, "SharedMemory(\"", obj.id, "\"; len=", obj.len,
          ", ptr=Ptr{Cvoid}(0x", string(convert(Int, obj.ptr), base=16),"))")

Base.show(io::IO, obj::SharedMemory{ShmId}) =
    print(io, "SharedMemory(", obj.id, "; len=", obj.len,
          ", ptr=Ptr{Cvoid}(0x", string(convert(Int, obj.ptr), base=16),"))")

Base.show(io::IO, ::MIME"text/plain", obj::SharedMemory) = show(io, obj)

"""
```julia
shmid(arg)
```

yield the identifier of an existing POSIX shared memory object or Sytem V
shared memory segment identifed by `arg` or associated with `arg`.  Argument
can be:

* An instance of `SharedMemory`.

* An instance of `WrappedArray` whose contents is stored into shared memory.

* A string starting with a `'/'` (and no other `'/'`) to identify a POSIX
  shared memory object.

* An instance of `IPC.Key` to specify a System V IPC key associated with a
  shared memory segment.  In that case, an optional second argument `readonly`
  can be set `true` to only request read-only access; otherwise read-write
  access is requested.

* An instance of `ShmId` to specify a System V shared memory segment.

See also: [`SharedMemory`](@ref), [`shmrm`](@ref).

"""
shmid(shm::SharedMemory) = shm.id
shmid(arr::WrappedArray{T,N,<:SharedMemory}) where {T,N} = shmid(arr.mem)
shmid(id::ShmId) = id
shmid(key::Key, args...) = ShmId(key, args...)

Base.rm(shm::SharedMemory) = shmrm(shm)
Base.rm(id::ShmId) = shmrm(id)
Base.rm(::Type{SharedMemory}, key::Key) = shmrm(key)
Base.rm(::Type{SharedMemory}, name::AbstractString) = shmrm(name)

"""

```julia
shmrm(arg)
```

removes the shared memory associated with `arg`.  If `arg` is a name, the
corresponding POSIX named shared memory is unlinked.  If `arg` is a key or
identifier of a BSD shared memory segment, the segment is marked to be
eventually destroyed.  Argument `arg` can also be a `SharedMemory` object.

The `rm` method may also be called to remove an existing shared memory segment
or object.  There are several possibilities:

```julia
rm(SharedMemory, name)  # `name` identifies a POSIX shared memory object
rm(SharedMemory, key)   # `key` is associated with a BSD shared memory segment
rm(id)                  # `id` is the identifier of a BSD shared memory segment
rm(shm)                 # `shm` is an instance of `SharedMemory`
```

See also: [`SharedMemory`](@ref), [`shmid`](@ref), [`shmat`](@ref).

"""
shmrm(shm::SharedMemory) = shmrm(shmid(shm))
shmrm(key::Key) = shmrm(shmid(key))

shmrm(name::AbstractString) = begin
    if _shm_unlink(name) != SUCCESS
        errno = Libc.errno()
        if errno != Libc.ENOENT
            throw_system_error("shm_unlink", errno)
        end
    end
end

shmrm(id::ShmId) = begin
    if _shmrm(name) != SUCCESS
        # Only throw an error if not an already removed shared memory segment.
        errno = Libc.errno()
        if errno != Libc.EIDRM
            throw_system_error("shmctl", errno)
        end
    end
end


#------------------------------------------------------------------------------
# System V Shared Memory
#
# Methods which directly call C functions are prefixed by an underscore and do
# not perform any checking of their arguments (except that type of arguments
# must be correct).
#
# Higher level versions are not prefixed by an underscore and throw a
# `SystemError` if the value returned by the C function indicates an error.
# Their arguments may be slightly different.
#

Base.convert(::Type{Cint}, id::ShmId) = id.value
Base.convert(::Type{T}, id::ShmId) where {T<:Integer} = convert(T, id.value)

Base.show(io::IO, id::ShmId) = print(io, "ShmId(", id.value, ")")
Base.show(io::IO, ::MIME"text/plain", id::ShmId) = show(io, id)

function Base.sizeof(id::ShmId)
    # Note it is faster to create a Julia array of small size than calling
    # malloc/free or using a tuple unless the number of elements of the tuple
    # is small.
    buf = _workspace(_sizeof_struct_shmid_ds)
    shmctl(id, IPC_STAT, buf)
    return _peek(_typeof_shm_segsz, buf, _offsetof_shm_segsz)
end

"`_workspace(size)` yields an array of `size` uninitialized bytes."
@inline _workspace(size::Integer) = Array{UInt8}(undef, size)

"""
# Get the identifier of an existing System V shared memory segment

The following calls:

```julia
ShmId(id)                  -> id
ShmId(arr)                 -> id
ShmId(key, readlony=false) -> id
```

yield the the identifier of the existing System V shared memory segment
associated with the value of the first argument.  `id` is the identifier of the
shared memory segment, `arr` is an array attached to a System V shared memory
segment and `key` is the key associated with the shared memory segment.  In
that latter case, `readlony` can be set `true` to only request read-only
access; otherwise read-write access is requested.

See also: [`shmid`](@ref), [`shmget`](@ref).

"""
ShmId(id::ShmId) = id
ShmId(shm::SharedMemory{ShmId}) = shmid(shm)
ShmId(arr::WrappedArray{T,N,SharedMemory{ShmId}}) where {T,N} = shmid(arr)
ShmId(key::Key, readonly::Bool = false) =
    shmget(key, 0, (readonly ? S_IRUSR : (S_IRUSR|S_IWUSR)))

"""
# Get or create a System V shared memory segment

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

* `flg` is a bitwise combination of flags.  The least significant 9 bits
  specify the permissions granted to the owner, group, and others.  These bits
  have the same format, and the same meaning, as the mode argument of `chmod`.
  Bit `IPC_CREAT` can be set to create a new segment.  If this flag is not
  used, then `shmget` will find the segment associated with `key` and check to
  see if the user has permission to access the segment.  Bit `IPC_EXCL` can be
  set in addition to `IPC_CREAT` to ensure that this call creates the segment.
  If `IPC_EXCL` and `IPC_CREAT` are both set, the call will fail if the segment
  already exists.

"""
function shmget(key::Key, siz::Integer, flg::Integer)
    id = _shmget(key.value, siz, flg)
    systemerror("shmget", id < 0)
    return ShmId(id)
end

_shmget(key::Integer, siz::Integer, flg::Integer) =
    ccall(:shmget, Cint, (key_t, Csize_t, Cint), key, siz, flg)


"""
```julia
shmat(id, readonly) -> ptr
```

attaches a shared memory segment to the address space of the caller.  Argument
`id` is the identifier of the shared memory segment.  Boolean argument
`readonly` specifies whether to attach the segment for read-only access;
otherwise, the segment is attached for read and write accesses and the process
must have read and write permissions for the segment.  The returned value is
the pointer to access the shared memory segment.

See also: [`shmdt`](@ref), [`shmrm`](@ref).

"""
function shmat(id::ShmId, readonly::Bool)
    flg = (readonly ? SHM_RDONLY : zero(SHM_RDONLY))
    ptr = _shmat(id.value, C_NULL, flg)
    systemerror("shmat", ptr == Ptr{Cvoid}(-1))
    return ptr
end

_shmat(id::Integer, ptr::Ptr{Cvoid}, flg::Integer) =
    ccall(:shmat, Ptr{Cvoid}, (Cint, Ptr{Cvoid}, Cint), id, ptr, flg)


"""
```julia
shmdt(ptr)
```

detaches a System V shared memory segment from the address space of the caller.
Argument `ptr` is the pointer returned by a previous `shmat()` call.

See also: [`shmdt`](@ref), [`shmget`](@ref).

"""
shmdt(ptr::Ptr{Cvoid}) = systemerror("shmdt", _shmdt(ptr) != SUCCESS)

_shmdt(ptr::Ptr{Cvoid}) =
    ccall(:shmdt, Cint, (Ptr{Cvoid},), ptr)

"""

```julia
shmctl(id, cmd, buf)
```

performs the control operation specified by `cmd` on the System V shared memory
segment whose identifier is given in `id`.  The `buf` argument is a pointer to
a `shmid_ds` C structure.

See also [`shminfo`](@ref), [`shmcfg`](@ref) and [`shmrm`](@ref).

"""
shmctl(id::ShmId, cmd::Integer, buf::Union{DenseVector,Ptr}) =
    systemerror("shmctl", _shmctl(id.value, cmd, buf) == -1)

_shmctl(id::Integer, cmd::Integer, buf::Union{DenseVector,Ptr}) =
    ccall(:shmctl, Cint, (Cint, Cint, Ptr{Cvoid}), id, cmd, buf)

_shmrm(id::Integer) = _shmctl(id, IPC_RMID, C_NULL)

"""

```julia
shmcfg(arg, perms) -> id
```

changes the access permissions of a System V IPC shared memory segment.
Argument `perms` specifies bitwise flags with the new permissions.  The first
argument `arg` can be the identifier of the shared memory segment, a shared
array attached to the shared memory segment or the System V IPC key associated
with the shared memory segment.  In all cases, the identifier of the shared
memory segment is returned.

See also [`ShmId`](@ref), [`shmget`](@ref), [`shmctl`](@ref) and
[`SharedMemory`](@ref).

"""
function shmcfg(id::ShmId, perms::_typeof_shm_perm_mode)
    mask = convert(_typeof_shm_perm_mode, MASKMODE)
    buf = _workspace(_sizeof_struct_shmid_ds)
    shmctl(id, IPC_STAT, buf)
    mode = _peek(_typeof_shm_perm_mode, buf, _offsetof_shm_perm_mode)
    if (mode & mask) != (perms & mask)
        _poke!(_typeof_shm_perm_mode, buf, _offsetof_shm_perm_mode,
               (mode & ~mask) | (perms & mask))
        shmctl(id, IPC_SET, buf)
    end
    return id
end

shmcfg(id::ShmId, perms::Integer) =
    shmcfg(id, convert(_typeof_shm_perm_mode, perms))

shmcfg(arg::Union{ShmArray,Key}, perms::Integer) =
    shmcfg(ShmId(arg), perms)


"""

`ShmInfo` is the structure used to store information about a System V shared memory segment.
The call `ShmInfo(arg)` is equivalent to [`shminfo(arg)`](@ref shminfo).

"""
ShmInfo(arg::Union{ShmId,ShmArray,Key}) = shminfo(arg)

"""

```julia
shminfo(arg) -> info
```

yields information about the System V shared memory segment identified or
associated with `arg` which can be the identifier of the shared memory segment,
a shared array attached to the shared memory segment or the System V IPC key
associated with the shared memory segment.

See also [`ShmInfo`](@ref), [`ShmId`](@ref), [`shmget`](@ref), [`shmat`](@ref),
[`SharedMemory`](@ref).

"""
shminfo(arg::Union{ShmId,ShmArray,Key}) = shminfo!(arg, ShmInfo())

"""

```julia
shminfo!(arg, info) -> info
```

overwrites `info` (an instance of [`ShmInfo`](@ref)) with the information about
the System V shared memory segment identified or associated with `arg`.  See
[`shminfo`](@ref) for more details.

"""
function shminfo!(id::ShmId, info::ShmInfo)
    buf = _workspace(_sizeof_struct_shmid_ds)
    shmctl(id, IPC_STAT, buf)
    info.atime  = _peek(time_t,        buf, _offsetof_shm_atime)
    info.dtime  = _peek(time_t,        buf, _offsetof_shm_dtime)
    info.ctime  = _peek(time_t,        buf, _offsetof_shm_ctime)
    info.segsz  = _peek(_typeof_shm_segsz,     buf, _offsetof_shm_segsz)
    info.id     = id.value
    info.cpid   = _peek(pid_t,         buf, _offsetof_shm_cpid)
    info.lpid   = _peek(pid_t,         buf, _offsetof_shm_lpid)
    info.nattch = _peek(shmatt_t,      buf, _offsetof_shm_nattch)
    info.mode   = _peek(_typeof_shm_perm_mode, buf, _offsetof_shm_perm_mode)
    info.uid    = _peek(uid_t,         buf, _offsetof_shm_perm_uid)
    info.gid    = _peek(gid_t,         buf, _offsetof_shm_perm_gid)
    info.cuid   = _peek(uid_t,         buf, _offsetof_shm_perm_cuid)
    info.cgid   = _peek(gid_t,         buf, _offsetof_shm_perm_cgid)
    return info
end

shminfo!(arg, info::ShmInfo) = shminfo!(ShmId(arg), info)

shminfo!(key::Key, info::ShmInfo) = shminfo!(ShmId(key, true), info)
