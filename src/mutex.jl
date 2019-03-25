#
# mutex.jl --
#
# POSIX mutexes and condition variables for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

"""
```julia
IPC.Mutex()
```

yields an initialized POSIX mutex.  Associated ressources are automatically
destroy when the returned object is grabage collected.  It is however the
user's responsability to ensure that the object is eventually unlocked.

See also: [`IPC.Condition`](@ref), [`lock`](@ref), [`unlock`](@ref),
          [`trylock`](@ref).

"""
mutable struct Mutex
    handle::Ptr{Cvoid}
    function Mutex()
        buf = Libc.malloc(_sizeof_pthread_mutex_t)
        buf != C_NULL || throw(OutOfMemoryError())
        if ccall(:pthread_mutex_init, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
                 buf, C_NULL) != SUCCESS
            # In principle, `pthread_mutex_init` should always return 0.
            Libc.free(buf)
            throw_system_error("pthread_mutex_init")
        end
        return finalizer(_destroy, new(buf))
    end
end

"""
```julia
IPC.Condition()
```

yields an initialized POSIX condition variable.  Associated ressources are
automatically destroy when the returned object is grabage collected.

See also: [`IPC.Mutex`](@ref).
"""
mutable struct Condition
    handle::Ptr{Cvoid}
    function Condition()
        buf = Libc.malloc(_sizeof_pthread_cond_t)
        buf != C_NULL || throw(OutOfMemoryError())
        if ccall(:pthread_cond_init, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
                 buf, C_NULL) != SUCCESS
            Libc.free(buf)
            throw_system_error("pthread_cond_init")
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

Base.lock(mutex::Mutex) =
    systemerror("pthread_mutex_lock",
                ccall(:pthread_mutex_lock, Cint, (Ptr{Cvoid},),
                      mutex.handle) != SUCCESS)

Base.unlock(mutex::Mutex) =
    systemerror("pthread_mutex_unlock",
                ccall(:pthread_mutex_unlock, Cint, (Ptr{Cvoid},),
                      mutex.handle) != SUCCESS)

function Base.trylock(mutex::Mutex)
    code = ccall(:pthread_mutex_trylock, Cint, (Ptr{Cvoid},), mutex.handle)
    return (code == 0 ? true :
            code == Libc.EBUSY ? false :
            throw_system_error("pthread_mutex_trylock", code))
end

signal(cond::Condition) =
    systemerror("pthread_cond_signal",
                ccall(:pthread_cond_signal, Cint, (Ptr{Cvoid},),
                      cond.handle) != SUCCESS)

Base.broadcast(cond::Condition) =
    systemerror("pthread_cond_broadcast",
                ccall(:pthread_cond_broadcast, Cint, (Ptr{Cvoid},),
                      cond.handle) != SUCCESS)

Base.wait(cond::Condition, mutex::Mutex) =
    systemerror("pthread_cond_wait",
                ccall(:pthread_cond_wait, Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
                      cond.handle, mutex.handle) != SUCCESS)

"""
```julia
timedwait(cond, mutex, sec)
timedwait(cond, mutex, sec, nsec)
timedwait(cond, mutex, abstime)
```

A timeout relative to the current time can be specified either by the
number of seconds `sec` (can be fractional) to wait or by the numbers of
seconds and nanoseconds `sec` and `sec` (both integers).  Otherwise, an
absolute timeout can be specified by `abstime` (of type `IPC.TimeSpec`).

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
    status = ccall(:pthread_cond_timedwait, Cint,
                   (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{TimeSpec}),
                   cond.handle, mutex.handle, Ref(abstime))
    status == 0 && return true
    status == Libc.ETIMEDOUT && return false
    throw_system_error("pthread_cond_timedwait")
end
