#
# IPC.jl --
#
# Inter-Process Communication for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

__precompile__(true)

module IPC

import Base: lock, unlock, trylock, timedwait, broadcast

export
    TimeVal,
    TimeSpec,
    gettimeofday,
    nanosleep,
    signal,
    IPC_NEW,
    ShmArray,
    ShmMatrix,
    ShmVector,
    shmarr,
    shmget,
    shmid,
    shmat,
    shmat!,
    shmdt,
    shmrm,
    shmcfg,
    shminfo,
    shminfo!

if stat(joinpath(@__DIR__, "constants.jl")).nlink == 0
    error("File `constants.jl` does not exists.  Run `make all` in the `deps` directory of the `IPC` module.")
end
include("constants.jl")
include("types.jl")
include("utils.jl")
include("shm.jl")
include("mutex.jl")

@deprecate IPC_NEW IPC.PRIVATE

end # module IPC

