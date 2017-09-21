#
# utils.jl --
#
# Useful methods and constants for IPC module of Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2017, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

const PRIVATE = Key(IPC_PRIVATE)

# A bit of magic for calling C-code:
convert(::Type{_typeof_key_t}, key::Key) = key.value
#convert{T<:Integer}(::Type{T}, ipckey::Key) = convert(T, ipckey.value)
convert(::Type{String}, key::Key) = string(key)

string(key::Key) = dec(key.value)
show(io::IO, key::Key) = (write(io, "IPC.Key: "*dec(key.value)); nothing)


"""

Immutable type `IPC.Key` stores a System V IPC key.  The call:

    IPC.Key(path, proj)

generates a System V IPC key from pathname `path` and a project identifier
`proj` (a single character).  The key is suitable for System V Inter-Process
Communication (IPC) facilities (message queues, semaphores and shared memory).
For instance:

    key = IPC.Key(".", 'a')

The special IPC key `IPC.PRIVATE` is also available.
"""
function Key(path::AbstractString, proj::Char)
    isascii(proj) || throw(ArgumentError("`proj` must belong to the ASCII character set"))
    key = ccall(:ftok, _typeof_key_t, (Cstring, Cint), path, proj)
    key != -1 || throw(SystemError("ftok failed"))
    return Key(key)
end

syserrmsg(msg::AbstractString, code::Integer=Libc.errno()) =
    string(msg," [",Libc.strerror(code),"]")

makedims{N}(dims::NTuple{N,Int}) = dims
makedims{N}(dims::NTuple{N,Integer}) = ntuple(i -> Int(dims[i]), N)
makedims{T<:Integer}(dims::Array{T,1}) = ntuple(i -> Int(dims[i]), length(dims))

@inline _peek{T}(ptr::Ptr{T}) = unsafe_load(ptr)
@inline _peek{T}(::Type{T}, ptr::Ptr) = _peek(convert(Ptr{T}, ptr))
@inline _peek{T}(::Type{T}, ptr::Ptr, off::Integer) =
    _peek(convert(Ptr{T}, ptr + off))

@inline _poke!{T}(ptr::Ptr{T}, val) = unsafe_store!(ptr, val)
@inline _poke!{T}(::Type{T}, ptr::Ptr, val) =
    _poke!(convert(Ptr{T}, ptr), val)
@inline _poke!{T}(::Type{T}, ptr::Ptr, off::Integer, val) =
    _poke!(ptr + off, val)

