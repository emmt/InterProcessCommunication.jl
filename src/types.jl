#
# types.jl --
#
# Definitions fo types for IPC module of Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

struct TimeVal
    sec::_typeof_timeval_sec    # seconds
    usec::_typeof_timeval_usec  # microseconds
end

struct TimeSpec
    sec::_typeof_timespec_sec    # seconds
    nsec::_typeof_timespec_nsec  # nanoseconds
end

struct Key
    value::_typeof_key_t
end

struct ShmId
    value::Cint
end

mutable struct ShmArray{T,N} <: DenseArray{T,N}
    # All members shall be considered as private.
    arr::Array{T,N} # wrapped Julia array
    ptr::Ptr{Void}  # address where shared memory is attached
    id::ShmId       # shared memory identifier
    function ShmArray{T,N}(arr::Array{T,N}, ptr::Ptr{Void},
                           id::ShmId) where {T,N}
        obj = new{T,N}(arr, ptr, id)
        finalizer(obj, _destroy)
        return obj
    end
end

const ShmVector{T} = ShmArray{T,1}
const ShmMatrix{T} = ShmArray{T,2}

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
