#
# types.jl --
#
# Definitions fo types for IPC module of Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2017, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

struct TimeVal
    tv_sec::_typeof_tv_sec    # seconds
    tv_usec::_typeof_tv_usec  # microseconds
end

struct TimeSpec
    tv_sec::_typeof_tv_sec    # seconds
    tv_nsec::_typeof_tv_nsec  # nanoseconds
end

struct Key
    value::_typeof_key_t
end

struct ShmId
    value::Cint
end

mutable struct ShmArray{T,N} <: DenseArray{T,N}
    # All members shall be considered as private.
    _buf::Array{T,N}
    _ptr::Ptr{Void}
    _id::ShmId
    function ShmArray{T,N}(buf::Array{T,N}, ptr::Ptr{Void},
                           id::ShmId) where {T,N}
        @assert pointer(buf) == ptr
        obj = new{T,N}(buf, ptr, id)
        finalizer(obj, obj -> shmdt(obj._ptr))
        return obj
    end
end

mutable struct ShmInfo
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

