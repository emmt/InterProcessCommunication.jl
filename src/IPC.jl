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
    reinterpret, reshape, copy, copy!, show, string, pointer,
    lock, unlock, trylock, timedwait, broadcast

export
    TimeVal,
    TimeSpec,
    gettimeofday,
    nanosleep,
    signal,
    IPC_NEW,
    ShmArray,
    shmget,
    shmid,
    shmat,
    shmat!,
    shmdt,
    shmrm,
    shmcfg,
    shminfo,
    shminfo!

if stat(joinpath(@__DIR__, "..", "deps", "constants.jl")).nlink == 0
    error("File `constants.jl` does not exists.  Run `make` in the `deps` directory of the `IPC` module.")
end
include("../deps/constants.jl")

@static if VERSION ≥ v"0.6"
    include("types.jl")
else
    include("oldtypes.jl")
end

include("utils.jl")
include("shm.jl")
include("mutex.jl")

end # module IPC

