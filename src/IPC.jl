#
# IPC.jl --
#
# Inter-Process Communication for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2017, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

isdefined(Base, :__precompile__) && __precompile__(true)

module IPC

using Compat
import Compat.String

import Base: convert, getindex, setindex!, eltype, length, ndims, sizeof,
             size, eachindex, linearindexing, stride, strides,
             reinterpret, reshape, copy, copy!, show, string, pointer

export ShmArray, shmget, shmid, shmat, shmdt, shmrm, shmcfg, shminfo, shminfo!

const libswl = joinpath(@__DIR__, "..", "deps", "lib", "libswl."*Libdl.dlext)

if stat(joinpath(@__DIR__, "..", "deps", "constants.jl")).nlink == 0
    error("File `constants.jl` does not exists.  Run `make` in the `deps` directory of the `IPC` module.")
end
include("../deps/constants.jl")

@static if VERSION ≥ v"0.6"
    include("types.jl")
else
    include("oldtypes.jl")
end

const PRIVATE = Key(0)

# a bit of magic for calling C-code:
convert(::Type{Cint}, key::Key) = key.value
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
    key = ccall((:SWL_GenerateKey, libswl), Cint,
                (Ptr{UInt8}, Cint), path, proj)
    if key == -1
        error(syserrmsg("failed to create IPC key"))
    end
    return Key(key)
end

syserrmsg(msg::AbstractString, code::Integer=Libc.errno()) =
    string(msg," [",Libc.strerror(code),"]")

makedims{N}(dims::NTuple{N,Int}) = dims
makedims{N}(dims::NTuple{N,Integer}) = ntuple(i -> Int(dims[i]), N)
makedims{T<:Integer}(dims::Array{T,1}) = ntuple(i -> Int(dims[i]), length(dims))

include("shm.jl")

end # module IPC

