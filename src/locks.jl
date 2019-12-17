#
# locks.jl --
#
# Mutexes, condition variables and read/write locks for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of InterProcessCommunication.jl released under the MIT
# "expat" license.
#
# Copyright (C) 2016-2019, Éric Thiébaut
# (https://github.com/emmt/InterProcessCommunication.jl).
#

"""
```julia
IPC.Mutex()
```

yields an initialized POSIX mutex.  Associated ressources are automatically
destroyed when the returned object is garbage collected.  It is however the
user's responsability to ensure that the object is eventually unlocked.

See also: [`IPC.Condition`](@ref), [`lock`](@ref), [`unlock`](@ref),
          [`trylock`](@ref).

"""
mutable struct Mutex
    handle::Ptr{Cvoid}
    function Mutex()
        buf = Libc.malloc(_sizeof_pthread_mutex_t)
        buf != C_NULL || throw(OutOfMemoryError())
        code = ccall(:pthread_mutex_init, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
                     buf, C_NULL)
        if code != SUCCESS
            # In principle, `pthread_mutex_init` should always return 0.
            Libc.free(buf)
            throw_system_error("pthread_mutex_init", code)
        end
        return finalizer(_destroy, new(buf))
    end
end

"""
```julia
IPC.Condition()
```

yields an initialized POSIX condition variable.  Associated ressources are
automatically destroyed when the returned object is garbage collected.

See also: [`IPC.Mutex`](@ref).

"""
mutable struct Condition
    handle::Ptr{Cvoid}
    function Condition()
        buf = Libc.malloc(_sizeof_pthread_cond_t)
        buf != C_NULL || throw(OutOfMemoryError())
        code = ccall(:pthread_cond_init, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
                     buf, C_NULL)
        if code != SUCCESS
            Libc.free(buf)
            throw_system_error("pthread_cond_init", code)
        end
        return finalizer(_destroy, new(buf))
    end
end

function _destroy(obj::Mutex)
    if (ptr = obj.handle) != C_NULL
        obj.handle = C_NULL # to not free twice
        ccall(:pthread_mutex_destroy, Cint, (Ptr{Cvoid},), ptr)
        Libc.free(ptr)
    end
end

function _destroy(obj::Condition)
    if (ptr = obj.handle) != C_NULL
        obj.handle = C_NULL # to not free twice
        ccall(:pthread_cond_destroy, Cint, (Ptr{Cvoid},), ptr)
        Libc.free(ptr)
    end
end

Base.pointer(obj::Mutex) = obj.handle
Base.pointer(obj::Condition) = obj.handle

function Base.lock(mutex::Mutex)
    code = ccall(:pthread_mutex_lock, Cint, (Mutex,), mutex)
    code == 0 || throw_system_error("pthread_mutex_lock", code)
    nothing
end

function Base.unlock(mutex::Mutex)
    code = ccall(:pthread_mutex_unlock, Cint, (Mutex,), mutex)
    code == 0 || throw_system_error("pthread_mutex_unlock", code)
    nothing
end

function Base.trylock(mutex::Mutex)
    code = ccall(:pthread_mutex_trylock, Cint, (Mutex,), mutex)
    return (code == 0 ? true :
            code == Libc.EBUSY ? false :
            throw_system_error("pthread_mutex_trylock", code))
end

function signal(cond::Condition)
    code = ccall(:pthread_cond_signal, Cint, (Condition,), cond)
    code == 0 || throw_system_error("pthread_cond_signal", code)
    nothing
end

function Base.broadcast(cond::Condition)
    code = ccall(:pthread_cond_broadcast, Cint, (Condition,), cond)
    code == 0 || throw_system_error("pthread_cond_broadcast", code)
    nothing
end

function Base.wait(cond::Condition, mutex::Mutex)
    code = ccall(:pthread_cond_wait, Cint, (Condition, Mutex), cond, mutex)
    code == 0 || throw_system_error("pthread_cond_wait", code)
    nothing
end

"""

```julia
timedwait(cond, mutex, sec)        -> bool
timedwait(cond, mutex, sec, nsec)  -> bool
timedwait(cond, mutex, abstime)    -> bool
```

waits for condition variable `cond` to be signaled using lock `mutex` for
synchronization but no longer than a time limit.

A timeout relative to the current time can be specified either by the number of
seconds `sec` (can be fractional) to wait or by the numbers of seconds and
nanoseconds `sec` and `sec` (both integers).  Otherwise, an absolute timeout
can be specified by `abstime` (of type [`IPC.TimeSpec`](@ref)).

The returned value is `true` if the condition is signalled before expiration of
the timeout, and `false` otherwise.

"""
Base.timedwait(cond::Condition, mutex::Mutex, sec::Integer, nsec::Integer = 0) =
    timedwait(cond, mutex, Int(sec), Int(nsec))

Base.timedwait(cond::Condition, mutex::Mutex, timeout::AbstractFloat) =
    timedwait(cond, mutex, Float64(timeout))

function Base.timedwait(cond::Condition, mutex::Mutex, sec::Int, nsec::Int)
    now = gettimeofday()
    sec += now.tv_sec
    nsec += 1_000*now.tv_usec
    inc, nsec = divrem(nsec, 1_000_000_000)
    sec += inc
    timedwait(cond, mutex, TimeSpec(sec, nsec))
end

function Base.timedwait(cond::Condition, mutex::Mutex, timeout::Float64)
    local sec::Int, nsec::Int
    timeout = max(timeout, 0.0)
    timedwait(cond, mutex, trunc(Int, timeout),
              round(Int, (timeout - trunc(timout))*1E9))
end

function Base.timedwait(cond::Condition, mutex::Mutex, abstime::TimeSpec)
    code = ccall(:pthread_cond_timedwait, Cint,
                 (Condition, Mutex, Ptr{TimeSpec}),
                 cond, mutex, Ref(abstime))
    code == 0 && return true
    code == Libc.ETIMEDOUT && return false
    throw_system_error("pthread_cond_timedwait", code)
end
