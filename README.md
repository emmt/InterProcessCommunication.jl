# Inter-Process Communication for Julia

Julia has already many methods for inter-process communication (IPC): sockets,
memory mapped files, etc.  You may however want to have Julia interacts with
other processes by means of System V IPC shared memory, semaphores
or message queues.  Package `IPC.jl` provides such facilities.

*For now only shared memory is implemented.*


## Installation

For now, installation is not yet fully automated in the spirit of Julia
packages.  To perform a first time installation, just run the `install` script
in the top directory of the `IPC.jl` repository:

    ./install

This simple script, creates a `deps` directory where the dynamic library
for the package is built and installed.  It also creates a symbolic link
`~/.julia/modules/IPC` to the `IPC.jl` repository.
If the dynamic library needs to be recompiled, it should be sufficient
to go to the `deps/build` directory and then run:

    make install
