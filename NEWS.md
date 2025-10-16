# User visible changes in `InterProcessCommunication`

# Version 0.1.6 [2025-10-16]

* Fix getting file size on a file descriptor (thanks to Carroll Vance, see [PR
  15](https://github.com/emmt/InterProcessCommunication.jl/pull/115)).

# Version 0.1.5

* Fix definition of constants `SIGUSR1` and `SIGUSR2` (see [PR 12](https://github.com/emmt/InterProcessCommunication.jl/pull/12)).

# Version 0.1.4

* `convert(RawFD, f)` and `RawFD(f)` yield the raw file descriptor of `FileDescriptor`
  instance `f`.

# Version 0.1.3

* Argument `readonly` is now a keyword in `ShmId` constructor and `shmid` method. Old
  behavior where it was the optional last argument has been deprecated.

* Argument `shmctl` checks that the buffer is large enough. Call `IPC.unsafe_shmct` to
  avoid this check or to directly pass a pointer.

# Version 0.1.2

* Export `umask` to set the calling process's file mode creation mask.

* When creating a semaphore, `Semaphore(...)` ignores the calling process's file mode
  creation mask for the access permissions while `open(Semaphore, ...)` masks the access
  permissions against the process `umask` like `sem_open`.

* Standard C types are no longer prefixed by `_typeof_`. For example, Julia equivalent of
  C `mode_t` is given by constant `IPC.mode_t`.

# Version 0.1.1

* Provide named and anonymous semaphores.

* Provide shared memory objects (instances of `SharedMemory`) which can be
  associated with System V or POSIX shared memory.

* Provide versatile wrapped arrays (instances of `WrappedArray`) which are seen
  as regular Julia arrays but whose elements are stored in a managed object.

* Arrays in shared memory are special instances of `WrappedArray` whose
  contents are stored by an instance of `SharedMemory`.
