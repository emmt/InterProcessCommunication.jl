#
# unix.jl --
#
# Low level interface to (some) Unix functions for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

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

# FIXME: `getpid` already provided by Julia.
# getpid() = ccall(:getpid, _typeof_pid_t, ())
getppid() = ccall(:getppid, _typeof_pid_t, ())

_open(path::AbstractString, flags::Integer, mode::Integer) =
    ccall(:open, Cint, (Cstring, Cint, _typeof_mode_t), path, flags, mode)

_creat(path::AbstractString, mode::Integer) =
    _open(path, O_CREAT|O_WRONLY|O_TRUNC, mode)

_close(fd::Integer) =
    ccall(:close, Cint, (Cint,), fd)

_umask(mask::Integer) =
    ccall(:umask, _typeof_mode_t, (_typeof_mode_t,), mask)

_read(fd::Integer, buf::Union{DenseArray,Ptr}, cnt::Integer) =
    ccall(:read, _typeof_ssize_t, (Cint, Ptr{Void}, _typeof_size_t),
          fd, buf, cnt)

_write(fd::Integer, buf::Union{DenseArray,Ptr}, cnt::Integer) =
    ccall(:write, _typeof_ssize_t, (Cint, Ptr{Void}, _typeof_size_t),
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
          ccall(:mmap, Ptr{Void},
                (Ptr{Void}, _typeof_size_t, Cint, Cint, Cint, _typeof_off_t),
                addr, len, prot, flags, fd, off)

_mprotect(addr::Ptr, len::Integer, prot::Integer) =
    ccall(:mprotect, Cint, (Ptr{Void}, _typeof_size_t, Cint), addr, len, prot)

_msync(addr::Ptr, len::Integer, flags::Integer) =
    ccall(:msync, Cint, (Ptr{Void}, _typeof_size_t, Cint), addr, len, flags)

_munmap(addr::Ptr, len::Integer) =
    ccall(:munmap, Cint, (Ptr{Void}, _typeof_size_t), addr, len)

_shm_open(path::AbstractString, flags::Integer, mode::Integer) =
    ccall(:shm_open, Cint, (Cstring, Cint, _typeof_mode_t), path, flags, mode)

_shm_unlink(path::AbstractString) =
    ccall(:shm_unlink, Cint, (Cstring,), path)

_sem_open(path::AbstractString, flags::Integer, mode::Integer, value::Unsigned) =
    ccall(:sem_open, Ptr{Void}, (Cstring, Cint, _typeof_mode_t, Cuint),
          path, flags, mode, value)

_sem_close(sem::Ptr{Void}) =
    ccall(:sem_close, Cint, (Ptr{Void},), sem)

_sem_unlink(path::AbstractString) =
    ccall(:sem_unlink, Cint, (Cstring,), path)

_sem_getvalue(sem::Ptr{Void}, val::Union{Ref{Cint},Ptr{Cint}}) =
    ccall(:sem_getvalue, Cint, (Ptr{Void}, Ptr{Cint}), sem, val)

_sem_post(sem::Ptr{Void}) =
    ccall(:sem_post, Cint, (Ptr{Void},), sem)

_sem_wait(sem::Ptr{Void}) =
    ccall(:sem_wait, Cint, (Ptr{Void},), sem)

_sem_trywait(sem::Ptr{Void}) =
    ccall(:sem_trywait, Cint, (Ptr{Void},), sem)

_sem_timedwait(sem::Ptr{Void}, timeout::Union{Ref{TimeSpec},Ptr{TimeSpec}}) =
    ccall(:sem_timedwait, Cint, (Ptr{Void}, Ptr{TimeSpec}), sem, timeout)

_sem_init(sem::Ptr{Void}, shared::Bool, value::Unsigned) =
    ccall(:sem_init, Cint, (Ptr{Void}, Cint, Cuint),
          sem, shared, value)

_sem_destroy(sem::Ptr{Void}) =
    ccall(:sem_destroy, Cint, (Ptr{Void},), sem)

#------------------------------------------------------------------------------
# FILE DESCRIPTOR

Base.stat(obj::FileDescriptor) = stat(obj.fd)

function Base.open(::Type{FileDescriptor}, path::AbstractString,
                   flags::Integer, mode::Integer=DEFAULT_MODE)
    fd = _open(path, flags, mode)
    systemerror("open", fd < 0)
    obj = FileDescriptor(fd)
    finalizer(obj, _close)
    return obj
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
        error("unknown access mode \"$access\"")
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

