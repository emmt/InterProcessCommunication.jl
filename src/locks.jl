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

# Abstract types to identify pointers to specific kind of C structures.
abstract type MutexData     end
abstract type ConditionData end
abstract type RWLockData    end

# Number of bytes for each C structures.
Base.sizeof(::Type{MutexData})     = _sizeof_pthread_mutex_t
Base.sizeof(::Type{ConditionData}) = _sizeof_pthread_cond_t
Base.sizeof(::Type{RWLockData})    = _sizeof_pthread_rwlock_t

"""
```julia
IPC.Mutex()
```

yields an initialized POSIX mutex.  The mutex is automatically unlocked and
associated ressources are automatically destroyed when the returned object is
garbage collected.

```julia
IPC.Mutex(buf, off=0; shared=false)
```

yields a new mutex object using buffer `buf` at offset `off` (in bytes) for its
storage.  There must be at least `sizeof(IPC.MutexData)` available bytes at
address `pointer(buf) + off`, these bytes must not be used for something else
and must remain accessible during the lifetime of the object.

Keyword `shared` can be set true to create a mutex that is shared between
processes; otherwise, the mutex is private that is it can only be used by
threads of the process which creates the mutex.  A shared mutex must be stored
in a part of the memory, like shared memory, that can be shared with other
processes.

See also: [`IPC.Condition`](@ref), [`IPC.RWLock`](@ref), [`lock`](@ref),
[`unlock`](@ref), [`trylock`](@ref).

"""
mutable struct Mutex{T}
    handle::Ptr{MutexData} # typed pointer to object data
    buffer::T              # object data
    locked::Bool
    function Mutex{T}(buf::T, off::Int; shared::Bool=false) where {T}
        off ≥ 0 || error("offset must be nonnegative")
        sizeof(buf) ≥ sizeof(MutexData) + off ||
            error("insufficient buffer size to store POSIX mutex")
        obj = new{T}(pointer(buf) + off, buf, false)
        attr = Vector{UInt8}(undef, _sizeof_pthread_mutexattr_t)
        code = ccall(:pthread_mutexattr_init, Cint, (Ptr{UInt8},), attr)
        code == 0 || throw_system_error("pthread_mutexattr_init", code)
        code = ccall(:pthread_mutexattr_setpshared, Cint, (Ptr{UInt8}, Cint), attr,
                     (shared ? PTHREAD_PROCESS_SHARED : PTHREAD_PROCESS_PRIVATE))
        code == 0 || throw_system_error("pthread_mutexattr_setpshared", code)
        code = ccall(:pthread_mutex_init, Cint,
                     (Ptr{MutexData}, Ptr{UInt8}), obj, attr)
        code == 0 || throw_system_error("pthread_mutex_init", code)
        code = ccall(:pthread_mutexattr_destroy, Cint, (Ptr{UInt8},), attr)
        code == 0 || (_destroy(obj);
                      throw_system_error("pthread_mutexattr_destroy", code))
        return finalizer(_destroy, obj)
    end
end

Mutex(buf::T, off::Integer = 0; kwds...) where {T} =
    Mutex{T}(buf, Int(off); kwds...)

Mutex(; kwds...) = Mutex(Vector{UInt8}(undef, sizeof(MutexData)); kwds...)

function _destroy(obj::Mutex)
    if (ptr = obj.handle) != C_NULL
        islocked(obj) && unlock(obj)
        obj.handle = C_NULL # to not free twice
        ccall(:pthread_mutex_destroy, Cint, (Ptr{MutexData},), ptr)
    end
    nothing
end

Base.islocked(obj::Mutex) = obj.locked

function Base.lock(obj::Mutex)
    islocked(obj) && error("mutex is already locked by owner")
    code = ccall(:pthread_mutex_lock, Cint, (Ptr{MutexData},), obj)
    code == 0 || throw_system_error("pthread_mutex_lock", code)
    obj.locked = true
    nothing
end

function Base.unlock(obj::Mutex)
    islocked(obj) || error("mutex is not locked by owner")
    code = ccall(:pthread_mutex_unlock, Cint, (Ptr{MutexData},), obj)
    code == 0 || throw_system_error("pthread_mutex_unlock", code)
    obj.locked = false
    nothing
end

function Base.trylock(obj::Mutex)
    if ! islocked(obj)
        code = ccall(:pthread_mutex_trylock, Cint, (Ptr{MutexData},), obj)
        if code == 0
            obj.locked = true
        elseif code == Libc.EBUSY
            return false
        else
            throw_system_error("pthread_mutex_trylock", code)
        end
    end
    return true
end

"""
```julia
IPC.Condition()
```

yields an initialized condition variable.  The ressources associated to the
condition variable are automatically destroyed when the returned object is
garbage collected.

```julia
IPC.Condition(buf, off=0; shared=false)
```

yields a new condition variable object using buffer `buf` at offset `off` (in
bytes) for its storage.  There must be at least `sizeof(IPC.ConditionData)`
available bytes at address `pointer(buf) + off`, these bytes must not be used
for something else and must remain accessible during the lifetime of the
object.

Keyword `shared` can be set true to create a condition variable that is shared
between processes; otherwise, the condition variable is private that is it can
only be used by threads of the process which creates the condition variable.  A
shared condition variable must be stored in a part of the memory, like shared
memory, that can be shared with other processes.

See also: [`IPC.Mutex`](@ref), [`IPC.RWLock`](@ref), [`signal`](@ref),
[`broadcast`](@ref), [`wait`](@ref), [`timedwait`](@ref).

"""
mutable struct Condition{T}
    handle::Ptr{ConditionData} # typed pointer to object data
    buffer::T                  # object data
    function Condition{T}(buf::T, off::Int; shared::Bool=false) where {T}
        off ≥ 0 || error("offset must be nonnegative")
        sizeof(buf) ≥ sizeof(ConditionData) + off ||
            error("insufficient buffer size to store condition variable")
        obj = new{T}(pointer(buf) + off, buf, false)
        attr = Vector{UInt8}(undef, _sizeof_pthread_condattr_t)
        code = ccall(:pthread_condattr_init, Cint, (Ptr{UInt8},), attr)
        code == 0 || throw_system_error("pthread_condattr_init", code)
        code = ccall(:pthread_condattr_setpshared, Cint, (Ptr{UInt8}, Cint), attr,
                     (shared ? PTHREAD_PROCESS_SHARED : PTHREAD_PROCESS_PRIVATE))
        code == 0 || throw_system_error("pthread_condattr_setpshared", code)
        code = ccall(:pthread_cond_init, Cint,
                     (Ptr{ConditionData}, Ptr{UInt8}), obj, attr)
        code == 0 || throw_system_error("pthread_cond_init", code)
        code = ccall(:pthread_condattr_destroy, Cint, (Ptr{UInt8},), attr)
        code == 0 || (_destroy(obj);
                      throw_system_error("pthread_condattr_destroy", code))
        return finalizer(_destroy, obj)
    end
end

Condition(buf::T, off::Integer = 0; kwds...) where {T} =
    Condition{T}(buf, Int(off); kwds...)

Condition(; kwds...) = Condition(Vector{UInt8}(undef, sizeof(ConditionData)); kwds...)

function _destroy(obj::Condition)
    if (ptr = obj.handle) != C_NULL
        obj.handle = C_NULL # to not free twice
        ccall(:pthread_cond_destroy, Cint, (Ptr{ConditionData},), ptr)
    end
    nothing
end

function signal(cond::Condition)
    code = ccall(:pthread_cond_signal, Cint, (Ptr{ConditionData},), cond)
    code == 0 || throw_system_error("pthread_cond_signal", code)
    nothing
end

function Base.broadcast(cond::Condition)
    code = ccall(:pthread_cond_broadcast, Cint, (Ptr{ConditionData},), cond)
    code == 0 || throw_system_error("pthread_cond_broadcast", code)
    nothing
end

function Base.wait(cond::Condition, mutex::Mutex)
    code = ccall(:pthread_cond_wait, Cint,
                 (Ptr{ConditionData}, Ptr{MutexData}), cond, mutex)
    code == 0 || throw_system_error("pthread_cond_wait", code)
    nothing
end

"""

```julia
timedwait(cond, mutex, lim) -> bool
```

waits for condition variable `cond` to be signaled using lock `mutex` for
synchronization but no longer than the time limit specified by `lim`.

Argument `lim` can be and instance of [``TimeSpec`](@ref) or [`TimeVal`](@ref)
to specify an absolute time limit since the Epoch, or a real to specify a limit
as a number of seconds relative to the current time.

The returned value is `true` if the condition is signalled before expiration of
the time limit, and `false` otherwise.

"""
function Base.timedwait(cond::Condition, mutex::Mutex, abstime::TimeSpec)
    code = ccall(:pthread_cond_timedwait, Cint,
                 (Ptr{ConditionData}, Ptr{MutexData}, Ptr{TimeSpec}),
                 cond, mutex, Ref(abstime))
    if code != 0
        code == Libc.ETIMEDOUT || throw_system_error("pthread_cond_timedwait", code)
        return false
    else
        return true
    end
end

Base.timedwait(cond::Condition, mutex::Mutex, abstime::Union{TimeVal,Libc.TimeVal}) =
    timedwait(cond, mutex, TimeSpec(abstime))

Base.timedwait(cond::Condition, mutex::Mutex, secs::Real) =
    timedwait(cond, mutex, now(TimeSpec) + secs)


"""
```julia
IPC.RWLock()
```

yields an initialized read/write lock object.  The lock is automatically
released and associated ressources are automatically destroyed when the
returned object is garbage collected.

```julia
IPC.RWLock(buf, off=0; shared=false)
```

yields a new read/write lock object using buffer `buf` at offset `off` (in
bytes) for its storage.  There must be at least `sizeof(IPC.RWLockData)`
available bytes at address `pointer(buf) + off`, these bytes must not be used
for something else and must remain accessible during the lifetime of the
object.

Keyword `shared` can be set true to create a read/write lock that is shared
between processes; otherwise, the lock is private that is it can only be used
by threads of the process which creates the lock.  A shared lock must be stored
in a part of the memory, like shared memory, that can be shared with other
processes.

See also: [`IPC.Mutex`](@ref), [`IPC.Condition`](@ref), [`lock`](@ref),
[`unlock`](@ref), [`trylock`](@ref).

"""
mutable struct RWLock{T}
    handle::Ptr{RWLockData} # typed pointer to object data
    buffer::T               # object data
    locked::Int             # 0 = unlocked, 1 = locked for reading, 2 = locked for writing
    function RWLock{T}(buf::T, off::Int; shared::Bool=false) where {T}
        off ≥ 0 || error("offset must be nonnegative")
        sizeof(buf) ≥ sizeof(RWLockData) + off ||
            error("insufficient buffer size to store read/write lock")
        obj = new{T}(pointer(buf) + off, buf, 0)
        attr = Vector{UInt8}(undef, _sizeof_pthread_rwlockattr_t)
        code = ccall(:pthread_rwlockattr_init, Cint, (Ptr{UInt8},), attr)
        code == 0 || throw_system_error("pthread_rwlockattr_init", code)
        code = ccall(:pthread_rwlockattr_setpshared, Cint, (Ptr{UInt8}, Cint), attr,
                     (shared ? PTHREAD_PROCESS_SHARED : PTHREAD_PROCESS_PRIVATE))
        code == 0 || throw_system_error("pthread_rwlockattr_setpshared", code)
        code = ccall(:pthread_rwlock_init, Cint,
                     (Ptr{RWLockData}, Ptr{UInt8}), obj, attr)
        code == 0 || throw_system_error("pthread_rwlock_init", code)
        code = ccall(:pthread_rwlockattr_destroy, Cint, (Ptr{UInt8},), attr)
        code == 0 || (_destroy(obj);
                      throw_system_error("pthread_rwlockattr_destroy", code))
        return finalizer(_destroy, obj)
    end
end

RWLock(buf::T, off::Integer = 0;  kwds...) where {T} =
    RWLock{T}(buf, Int(off); kwds...)

RWLock(; kwds...) = RWLock(Vector{UInt8}(undef, sizeof(RWLockData)); kwds...)

function _destroy(obj::RWLock)
    if (ptr = obj.handle) != C_NULL
        islocked(obj) && unlock(obj)
        obj.handle = C_NULL # to not free twice
        ccall(:pthread_rwlock_destroy, Cint, (Ptr{RWLockData},), ptr)
    end
    nothing
end

Base.islocked(obj::RWLock) = (obj.locked != 0)

"""

```julia
lock(obj, mode)
```

locks read/write lock object `obj` for reading if `mode` is `'r'`, for writing
if `mode` is `'w'`.

"""
function Base.lock(obj::RWLock, mode::Char)
    locked = (mode == 'r' ? 1 :
              mode == 'w' ? 2 : throw(ArgumentError("invalid mode")))
    islocked(obj) && error("r/w lock is already locked by owner")
    if mode == 'r'
        code = ccall(:pthread_rwlock_rdlock, Cint, (Ptr{RWLockData},), obj)
        code == 0 || throw_system_error("pthread_rwlock_rdlock", code)
    else
        code = ccall(:pthread_rwlock_wrlock, Cint, (Ptr{RWLockData},), obj)
        code == 0 || throw_system_error("pthread_rwlock_wrlock", code)
    end
    obj.locked = locked
    nothing
end

function Base.unlock(obj::RWLock)
    islocked(obj) || error("r/w lock is not locked by owner")
    code = ccall(:pthread_rwlock_unlock, Cint, (Ptr{RWLockData},), obj)
    code == 0 || throw_system_error("pthread_rwlock_unlock", code)
    obj.locked = 0
    nothing
end

"""

```julia
trylock(obj, mode) -> bool
```

attempts to lock read/write lock object `obj` for reading if `mode` is `'r'`,
for writing if `mode` is `'w'` and returns a boolean indicating whether `obj`
has been successfully locked for the given mode.


See Also: [`timedlock`](@ref).

"""
function Base.trylock(obj::RWLock, mode::Char)
    locked = (mode == 'r' ? 1 :
              mode == 'w' ? 2 : throw(ArgumentError("invalid mode")))
    if obj.locked == 0
        if mode == 'r'
            code = ccall(:pthread_rwlock_tryrdlock, Cint, (Ptr{RWLockData},), obj)
            if code != 0
                code == Libc.EBUSY ||
                    throw_system_error("pthread_rwlock_tryrdlock", code)
                return false
            end
        else
            code = ccall(:pthread_rwlock_trywrlock, Cint, (Ptr{RWLockData},), obj)
            if code != 0
                code == Libc.EBUSY ||
                    throw_system_error("pthread_rwlock_trywrlock", code)
                return false
            end
        end
    elseif obj.locked != locked
        if mode == 'r'
            error("r/w lock is already locked for writing by owner")
        else
            error("r/w lock is already locked for reading by owner")
        end
    end
    obj.locked = locked
    return true
end

"""

```julia
timedlock(rwlock, mode, lim) -> bool
```

locks read/write lock object `rwlock` for reading if `mode` is `'r'`, for
writing if `mode` is `'w'`, but waits no longer than the time limit specified
by `lim`.  The returned boolean value indicates whether the object could be
locked before the time limit.

Argument `lim` can be and instance of [``TimeSpec`](@ref) or [`TimeVal`](@ref)
to specify an absolute time limit since the Epoch, or a real to specify a limit
as a number of seconds relative to the current time.

See Also: [`trylock`](@ref).

"""
function timedlock(obj::RWLock, mode::Char, abstime::TimeSpec)
    locked = (mode == 'r' ? 1 :
              mode == 'w' ? 2 : throw(ArgumentError("invalid mode")))
    if obj.locked == 0
        if mode == 'r'
            code = ccall(:pthread_rwlock_timedrdlock, Cint,
                         (Ptr{RWLockData}, Ref{TimeSpec}), obj, Ref(abstime))
            if code != 0
                code == Libc.ETIMEDOUT ||
                    throw_system_error("pthread_rwlock_timedrdlock", code)
                return false
            end
        else
            code = ccall(:pthread_rwlock_timedwrlock, Cint,
                         (Ptr{RWLockData}, Ref{TimeSpec}), obj, Ref(abstime))
            if code != 0
                code == Libc.ETIMEDOUT ||
                    throw_system_error("pthread_rwlock_timedwrlock", code)
                return false
            end
        end
    elseif obj.locked != locked
        if mode == 'r'
            error("r/w lock is already locked for writing by owner")
        else
            error("r/w lock is already locked for reading by owner")
        end
    end
    obj.locked = locked
    return true
end

timedlock(obj::RWLock, mode::Char, abstime::Union{TimeVal,Libc.TimeVal}) =
    timedlock(obj, mode, TimeSpec(abstime))

timedlock(obj::RWLock, mode::Char, secs::Real) =
    timedlock(obj, mode, now(TimeSpec) + secs)

# The following are needed for ccall's.
Base.unsafe_convert(::Type{Ptr{MutexData}}, obj::Mutex) = obj.handle
Base.unsafe_convert(::Type{Ptr{ConditionData}}, obj::Condition) = obj.handle
Base.unsafe_convert(::Type{Ptr{RWLockData}}, obj::RWLock) = obj.handle
