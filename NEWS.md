# User visible changes in `InterProcessCommunication`

# Version 0.1.2

* Export `umask` to set the calling process's file mode creation mask.

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
