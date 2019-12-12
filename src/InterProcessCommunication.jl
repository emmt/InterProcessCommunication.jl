#
# InterProcessCommunication.jl --
#
# Inter-Process Communication for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of InterProcessCommunication.jl released under the MIT
# "expat" license.
#
# Copyright (C) 2016-2019, Éric Thiébaut
# (https://github.com/emmt/InterProcessCommunication.jl).
#

module InterProcessCommunication

export
    CLOCK_MONOTONIC,
    CLOCK_REALTIME,
    DynamicMemory,
    FileDescriptor,
    FileStat,
    IPC,
    Semaphore,
    SharedMemory,
    ShmArray,
    ShmId,
    ShmInfo,
    ShmMatrix,
    ShmVector,
    SigAction,
    SigInfo,
    SigSet,
    TimeSpec,
    TimeVal,
    TimeoutError,
    WrappedArray,
    clock_getres,
    clock_gettime,
    clock_settime,
    gettimeofday,
    nanosleep,
    post,
    shmat,
    shmcfg,
    shmctl,
    shmdt,
    shmget,
    shmid,
    shminfo!,
    shminfo,
    shmrm,
    sigaction!,
    sigaction,
    signal,
    sigpending!,
    sigpending,
    sigprocmask!,
    sigprocmask,
    sigqueue,
    sigsuspend,
    sigwait!,
    sigwait,
    trywait

using Printf

using Base: elsize, tail, OneTo, throw_boundserror, @propagate_inbounds

import Base: convert, unsafe_convert,
    lock, unlock, trylock, timedwait, wait, broadcast

# The following is an exported shortcut to the package.
const IPC = InterProcessCommunication
const PARANOID = true

isfile(joinpath(@__DIR__, "..", "deps", "deps.jl")) ||
    error("InterProcessCommunication not properly installed.  Please run Pkg.build(\"InterProcessCommunication\")")
include(joinpath("..", "deps", "deps.jl"))
include("types.jl")
include("wrappedarrays.jl")
include("unix.jl")
include("utils.jl")
include("shm.jl")
include("semaphores.jl")
include("signals.jl")
include("mutex.jl")

@deprecate IPC_NEW IPC.PRIVATE

end # module InterProcessCommunication
