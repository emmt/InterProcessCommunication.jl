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
    CLOCK_MONOTONIC,
    CLOCK_REALTIME,
    IPC_NEW,
    ShmArray,
    ShmMatrix,
    ShmVector,
    TimeSpec,
    TimeVal,
    clock_getres,
    clock_gettime,
    clock_settime,
    gettimeofday,
    nanosleep,
    shmarr,
    shmat!,
    shmat,
    shmcfg,
    shmdt,
    shmget,
    shmid,
    shminfo!,
    shminfo,
    shmrm,
    signal

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
