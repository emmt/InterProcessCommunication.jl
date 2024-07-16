# A Julia Package for Inter-Process Communication

# Introduction

Julia already provides many methods for inter-process communication (IPC): sockets,
semaphores, memory mapped files, etc. You may however want to have Julia interacts with
other processes or threads by means of BSD (System V) IPC or POSIX shared memory,
semaphores, message queues or mutexes and condition variables. Package
`InterProcessCommunication` intends to provide such facilities.

The statement `using InterProcessCommunication` exports (among others) a shortcut named
`IPC` to the `InterProcessCommunication` module. This documentation assumes this shortcut
and the prefix `IPC.` is used in many places instead of the much longer
`InterProcessCommunication.` prefix.

The code source of `InterProcessCommunication.jl` is
[here](https://github.com/emmt/InterProcessCommunication.jl).

# Table of contents

```@contents
Pages = ["semaphores.md", "sharedmemory.md", "reference.md"]
```

## Index

```@index
```
