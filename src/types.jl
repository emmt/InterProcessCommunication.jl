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

"""
`TimeoutError` is used to throw a timeout exception.
"""
struct TimeoutError <: Exception; end

struct TimeVal
    sec::_typeof_timeval_sec    # seconds
    usec::_typeof_timeval_usec  # microseconds
end

struct TimeSpec
    sec::_typeof_timespec_sec    # seconds
    nsec::_typeof_timespec_nsec  # nanoseconds
end

struct ProcessId
    value::_typeof_pid_t
end

struct UserId
    value::_typeof_uid_t
end

# Counterpart of C `sigset_t` structure.  Must be mutable to avoid wrapping it
# in a Ref when passed by address.
mutable struct SigSet
    bits::_typeof_sigset
    SigSet() = fill!(new(), false)
end

# Counterpart of C `struct sigaction` structure.  Must be mutable to avoid
# wrapping it in a Ref when passed by address.
mutable struct SigAction
    handler::Ptr{Cvoid}
    mask::SigSet
    flags::_typeof_sigaction_flags
end

# Counterpart of C `siginfo_t` structure; although only a pointer of this is
# ever used by signal handlers.  Must be mutable to avoid wrapping it in a Ref
# when passed by address.
mutable struct SigInfo
    bits::_typeof_siginfo
    function SigInfo()
        obj = new()
        ccall(:memset, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Csize_t),
              pointer_from_objref(obj), 0, sizeof(obj))
        return obj
    end
end

struct Key
    value::_typeof_key_t
    Key(value::Integer) = new(value)
end

struct ShmId
    value::Cint
    ShmId(value::Integer) = new(value)
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

mutable struct SemInfo
    otime::UInt64 # last semop time
    ctime::UInt64 # last change time
    nsems::Int32  # number of semaphores in set
    id::Int32     # semaphore set identifier
    uid::UInt32   # effective user ID of owner
    gid::UInt32   # effective group ID of owner
    cuid::UInt32  # effective user ID of creator
    cgid::UInt32  # effective group ID of creator
    mode::UInt32  # lower 9 bits of access modes
    SemInfo() = new(0,0,0,0,0,0,0,0,0)
end

# Must be mutable to allow for finalizing.
mutable struct FileDescriptor
    fd::Cint
end

abstract type MemoryBlock end

mutable struct DynamicMemory <: MemoryBlock
    ptr::Ptr{Cvoid}
    len::Int
    function DynamicMemory(len::Integer)
        @assert len ≥ 1
        ptr = Libc.malloc(len)
        ptr != C_NULL || throw(OutOfMemoryError())
        return finalizer(_destroy, new(ptr, len))
    end
end

mutable struct SharedMemory{T<:Union{String,ShmId}} <: MemoryBlock
    ptr::Ptr{Cvoid} # mapped address of shared memory segment
    len::Int        # size of shared memory segment (in bytes)
    volatile::Bool  # true if shared memory is volatile (only for the creator)
    id::T           # identifier of shared memory segment
    function SharedMemory{T}(ptr::Ptr{Cvoid},
                             len::Integer,
                             volatile::Bool,
                             id::T) where {T<:Union{String,ShmId}}
        return finalizer(_destroy, new(ptr, len, volatile, id))
    end
end

struct WrappedArray{T,N,M} <: DenseArray{T,N}
    # All members shall be considered as private.
    arr::Array{T,N}  # wrapped Julia array
    mem::M           # object providing the memory
    function WrappedArray{T,N,M}(ptr::Ptr{T},
                                 dims::NTuple{N,<:Integer},
                                 mem::M) where {T,N,M}
        arr = unsafe_wrap(Array, ptr, dims)
        return new{T,N,M}(arr, mem)
    end
end

const WrappedVector{T,M} = WrappedArray{T,1,M}
const WrappedMatrix{T,M} = WrappedArray{T,2,M}

const ShmArray{T,N,M<:SharedMemory} = WrappedArray{T,N,M}
const ShmVector{T,M} = ShmArray{T,1,M}
const ShmMatrix{T,M} = ShmArray{T,2,M}

# Header for saving a minimal description of a wrapped array.  The layout is:
#
#   Name   Size
#   --------------
#   magic  4 bytes
#   etype  2 bytes
#   ndims  2 bytes
#   offset 8 bytes
#
# This header is supposed to be directly followed by the array dimensions
# stored as 8-byte signed integers.
#
struct WrappedArrayHeader
    magic::UInt32 # magic number to check correctness
    etype::UInt16 # identifier of element type
    ndims::UInt16 # number of dimensions
    offset::Int64 # total size of header
end
@assert rem(sizeof(WrappedArrayHeader), sizeof(Int64)) == 0

# FIXME: too bad that the following construction does not work to simplify
#        writing method signatures:
# const Dimensions{N} = Union{Vararg{<:Integer,N},Tuple{Vararg{<:Integer,N}}}

mutable struct Semaphore{T}
    ptr::Ptr{Cvoid}
    lnk::T
    # Provide inner constructor to force fully qualified calls.
    Semaphore{T}(ptr::Ptr, lnk) where {T} = new{T}(ptr, lnk)
end
