# A Julia Package for Inter-Process Communication

Julia has already many methods for inter-process communication (IPC): sockets,
semaphores, memory mapped files, etc.  You may however want to have Julia
interacts with other processes or threads by means of BSD (System V) IPC or
POSIX shared memory, semaphores, message queues or mutexes and condition
variables.  Package `IPC.jl` intends to provide such facilities.

The code source of `IPC.jl` is [here](https://github.com/emmt/IPC.jl).

```@contents
Pages = ["semaphores.md", "sharedmemory.md", "reference.md"]
```

## Index

```@index
```
