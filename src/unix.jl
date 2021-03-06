#
# unix.jl --
#
# Low level interface to (some) Unix functions for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of InterProcessCommunication.jl released under the MIT
# "expat" license.
#
# Copyright (C) 2016-2018, Éric Thiébaut
# (https://github.com/emmt/InterProcessCommunication.jl).
#

"""
```julia
IPC.getpid() -> pid
```

yields the process ID of the calling process.

```julia
IPC.getppid() -> pid
```

yields the the process ID of the parent of the calling process.

These 2 methods yields an instance of `IPC.ProcessId`.

See also: [`getuid`](@ref).

""" ProcessId

getpid() = ccall(:getpid, ProcessId, ())
getppid() = ccall(:getppid, ProcessId, ())

@doc @doc(ProcessId) getpid
@doc @doc(ProcessId) getppid

"""
```julia
IPC.getuid() -> uid
```

yields the real user ID of the calling process.

```julia
IPC.geteuid() -> uid
```

yields the effective user ID of the calling process.

These 2 methods yields an instance of `IPC.UserId`.

See also: [`getpid`](@ref).

""" UserId

getuid() = ccall(:getuid, UserId, ())
geteuid() = ccall(:geteuid, UserId, ())

@doc @doc(UserId) getuid
@doc @doc(UserId) geteuid


Base.show(io::IO, id::ProcessId) = print(io, "IPC.ProcessId(", id.value, ")")

Base.show(io::IO, id::UserId) = print(io, "IPC.UserId(", id.value, ")")

Base.show(io::IO, ::MIME"text/plain", arg::Union{ProcessId,UserId}) =
    show(io, arg)


const MASKMODE = (S_IRWXU|S_IRWXG|S_IRWXO)

"""
```julia
maskmode(mode)
```

returns the `MASKMODE` bits of `mode` converted to `mode_t` C type.

Constant `MASKMODE` is a bit mask for the granted access permissions (in
general it has its 9 least significant bitrs set).

"""
maskmode(mode::Integer) :: _typeof_mode_t =
    convert(_typeof_mode_t, mode) & MASKMODE

@doc @doc(maskmode) MASKMODE

_open(path::AbstractString, flags::Integer, mode::Integer) =
    ccall(:open, Cint, (Cstring, Cint, _typeof_mode_t), path, flags, mode)

_creat(path::AbstractString, mode::Integer) =
    _open(path, O_CREAT|O_WRONLY|O_TRUNC, mode)

_close(fd::Integer) =
    ccall(:close, Cint, (Cint,), fd)

_umask(mask::Integer) =
    ccall(:umask, _typeof_mode_t, (_typeof_mode_t,), mask)

_read(fd::Integer, buf::Union{DenseArray,Ptr}, cnt::Integer) =
    ccall(:read, _typeof_ssize_t, (Cint, Ptr{Cvoid}, _typeof_size_t),
          fd, buf, cnt)

_write(fd::Integer, buf::Union{DenseArray,Ptr}, cnt::Integer) =
    ccall(:write, _typeof_ssize_t, (Cint, Ptr{Cvoid}, _typeof_size_t),
          fd, buf, cnt)

_lseek(fd::Integer, off::Integer, whence::Integer) =
    ccall(:lseek, _typeof_off_t, (Cint, _typeof_off_t, Cint), fd, off, whence)

_truncate(path::AbstractString, len::Integer) =
    ccall(:truncate, Cint, (Cstring, _typeof_off_t), path, len)

_ftruncate(fd::Integer, len::Integer) =
    ccall(:ftruncate, Cint, (Cint, _typeof_off_t), fd, len)

_chown(path::AbstractString, uid::Integer, gid::Integer) =
    ccall(:chown, Cint, (Cstring, _typeof_uid_t, _typeof_gid_t), path, uid, gid)

_lchown(path::AbstractString, uid::Integer, gid::Integer) =
    ccall(:lchown, Cint, (Cstring, _typeof_uid_t, _typeof_gid_t),
          path, uid, gid)

_fchown(fd::Integer, uid::Integer, gid::Integer) =
    ccall(:fchown, Cint, (Cint, _typeof_uid_t, _typeof_gid_t), fd, uid, gid)

_chmod(path::AbstractString, mode::Integer) =
    ccall(:chmod, Cint, (Cstring, _typeof_mode_t), path, mode)

_fchmod(fd::Integer, mode::Integer) =
    ccall(:fchmod, Cint, (Cint, _typeof_mode_t), fd, mode)

_mmap(addr::Ptr, len::Integer, prot::Integer, flags::Integer, fd::Integer,
      off::Integer) =
          ccall(:mmap, Ptr{Cvoid},
                (Ptr{Cvoid}, _typeof_size_t, Cint, Cint, Cint, _typeof_off_t),
                addr, len, prot, flags, fd, off)

_mprotect(addr::Ptr, len::Integer, prot::Integer) =
    ccall(:mprotect, Cint, (Ptr{Cvoid}, _typeof_size_t, Cint), addr, len, prot)

_msync(addr::Ptr, len::Integer, flags::Integer) =
    ccall(:msync, Cint, (Ptr{Cvoid}, _typeof_size_t, Cint), addr, len, flags)

_munmap(addr::Ptr, len::Integer) =
    ccall(:munmap, Cint, (Ptr{Cvoid}, _typeof_size_t), addr, len)

_shm_open(path::AbstractString, flags::Integer, mode::Integer) =
    ccall(:shm_open, Cint, (Cstring, Cint, _typeof_mode_t), path, flags, mode)

_shm_unlink(path::AbstractString) =
    ccall(:shm_unlink, Cint, (Cstring,), path)

_sem_open(path::AbstractString, flags::Integer, mode::Integer, value::Unsigned) =
    ccall(:sem_open, Ptr{Cvoid}, (Cstring, Cint, _typeof_mode_t, Cuint),
          path, flags, mode, value)

_sem_close(sem::Ptr{Cvoid}) =
    ccall(:sem_close, Cint, (Ptr{Cvoid},), sem)

_sem_unlink(path::AbstractString) =
    ccall(:sem_unlink, Cint, (Cstring,), path)

_sem_getvalue(sem::Ptr{Cvoid}, val::Union{Ref{Cint},Ptr{Cint}}) =
    ccall(:sem_getvalue, Cint, (Ptr{Cvoid}, Ptr{Cint}), sem, val)

_sem_post(sem::Ptr{Cvoid}) =
    ccall(:sem_post, Cint, (Ptr{Cvoid},), sem)

_sem_wait(sem::Ptr{Cvoid}) =
    ccall(:sem_wait, Cint, (Ptr{Cvoid},), sem)

_sem_trywait(sem::Ptr{Cvoid}) =
    ccall(:sem_trywait, Cint, (Ptr{Cvoid},), sem)

_sem_timedwait(sem::Ptr{Cvoid}, timeout::Union{Ref{TimeSpec},Ptr{TimeSpec}}) =
    ccall(:sem_timedwait, Cint, (Ptr{Cvoid}, Ptr{TimeSpec}), sem, timeout)

_sem_init(sem::Ptr{Cvoid}, shared::Bool, value::Unsigned) =
    ccall(:sem_init, Cint, (Ptr{Cvoid}, Cint, Cuint),
          sem, shared, value)

_sem_destroy(sem::Ptr{Cvoid}) =
    ccall(:sem_destroy, Cint, (Ptr{Cvoid},), sem)

#------------------------------------------------------------------------------
# FILE DESCRIPTOR

Base.stat(obj::FileDescriptor) = stat(obj.fd)

function Base.open(::Type{FileDescriptor}, path::AbstractString,
                   flags::Integer, mode::Integer=DEFAULT_MODE)
    fd = _open(path, flags, mode)
    systemerror("open", fd < 0)
    return finalizer(_close, FileDescriptor(fd))
end

function Base.open(::Type{FileDescriptor}, path::AbstractString,
                   access::AbstractString)
    flags0 = zero(Cint)
    flags1 = zero(Cint)
    mode = S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH
    len = length(access)
    c = (len ≥ 1 ? access[1] : '\0')
    if c == 'r'
        flags0 = O_RDONLY
    elseif c == 'w'
        flags0 = O_WRONLY
        flags1 = O_CREAT|O_TRUNC;
    elseif c == 'a'
        flags0 = O_WRONLY
        flags1 = O_CREAT|O_APPEND;
    else
        throw_argument_error("unknown access mode \"", access, "\"")
    end
    for i in 2:len
        c = access[i]
        if c == '+'
            flags0 = O_RDWR
            break
        end
    end
    return open(FileDescriptor, path, flags0|flags1, mode)
end

function Base.close(obj::FileDescriptor)
    # We must take care of not closing twice.
    if (fd = obj.fd) != -1
        obj.fd = -1
        systemerror("close", _close(fd) == -1)
    end
end

function _close(obj::FileDescriptor)
    if (fd = obj.fd) != -1
        obj.fd = -1
        _close(fd)
    end
end

Base.fd(obj::FileDescriptor) = obj.fd

function Base.position(obj::FileDescriptor)
    off = _lseek(fd(obj), 0, SEEK_CUR)
    systemerror("lseek", off < 0)
    return off
end

function Base.seek(obj::FileDescriptor, pos::Integer)
    off = _lseek(fd(obj), pos, SEEK_SET)
    systemerror("lseek", off < 0)
    return off
end

Base.seekstart(obj::FileDescriptor) = seek(obj, 0)

function Base.seekend(obj::FileDescriptor)
    off = _lseek(fd(obj), 0, SEEK_END)
    systemerror("lseek", off < 0)
    return off
end

function Base.skip(obj::FileDescriptor, offset::Integer)
    off = _lseek(fd(obj), offset, SEEK_CUR)
    systemerror("lseek", off < 0)
    return off
end

Base.isopen(obj::FileDescriptor) = fd(obj) ≥ 0
