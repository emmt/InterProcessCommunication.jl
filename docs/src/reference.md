# Reference

The following provides detailled documentation about types and methods provided
by the `InterProcessCommunication` package.  This information is also available
from the REPL by typing `?` followed by the name of a method or a type.


## Semaphores

```@docs
Semaphore
post(::Semaphore)
wait(::Semaphore)
timedwait(::Semaphore, ::Real)
trywait(::Semaphore)
```


## Shared Memory

```@docs
SharedMemory
ShmId
ShmInfo
shmid
shmget
shmat
shmdt
shmrm
shmctl
shmcfg
shminfo
shminfo!
```

## Signals

```@docs
SigSet
SigAction
SigInfo
sigaction
sigaction!
sigpending
sigpending!
sigprocmask
sigprocmask!
sigqueue
sigsuspend
sigwait
sigwait!
```

## Wrapped arrays

```@docs
WrappedArray
```

## Utilities

```@docs
TimeSpec
TimeVal
clock_getres
clock_gettime
clock_settime
gettimeofday
nanosleep
```

## Exceptions

```@docs
TimeoutError
```
