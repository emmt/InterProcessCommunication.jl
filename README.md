# Inter-Process Communication for Julia

Julia has already many methods for inter-process communication (IPC): sockets,
memory mapped files, etc.  You may however want to have Julia interacts with
other processes by means of System V IPC shared memory, semaphores
or message queues.  Module `IPC.jl` provides such facilities.

*For now only shared memory is implemented.*


## Installation

For now, installation is not yet fully automated in the spirit of Julia
packages.  To perform a first time installation or after updating the source
tree (`git pull`), execute the command `make` in the `deps` subdirectory the
`IPC.jl` repository.  This should compile a small executable `gencode` and
generate the file `constants.jl` with all constants required by the `IPC`
module and which may depend on your machine.
