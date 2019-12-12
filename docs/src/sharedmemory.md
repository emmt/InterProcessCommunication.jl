# Shared Memory

The `IPC` package provides two kinds of shared memory objects: *named shared
memory* objects which are identified by their name and *BSD (System V) shared
memory segments* which are identified by a key.


## Shared Memory Objects

Shared memory objects are instances of `IPC.SharedMemory`.  A new shared memory
object is created by calling:

```julia
SharedMemory(id, len; perms=0o600, volatile=true)
```

with `id` an identifier and `len` the size, in bytes, of the allocated memory.
The identifier `id` can be a string starting by a `'/'` to create a POSIX
shared memory object or a System V IPC key to create a BSD System V shared
memory segment.  In this latter case, the key can be `IPC.PRIVATE` to
automatically create a non-existing shared memory segment.

Use keyword `perms` to specify which access permissions are granted.  By
default, only reading and writing by the user is granted.

Use keyword `volatile` to specify whether the shared memory is volatile or not.
If non-volatile, the shared memory will remain accessible until explicit
destruction or system reboot.  By default, the shared memory is destroyed when
no longer in use.

To retrieve an existing shared memory object, call:

```julia
SharedMemory(id; readonly=false)
```

where `id` is the shared memory identifier (a string, an IPC key or a System V
IPC identifier of shared memory segment as returned by `ShmId`).  Keyword
`readonly` can be set true if only read access is needed.  Note that method
`shmid(obj)` may be called to retrieve the identifier of the shared memory
object `obj`.

Some methods are extended for shared memory objects.  Assuming `shm` is an
instance of `SharedMemory`, then:

```julia
pointer(shm)    # yields the base address of the shared memory
sizeof(shm)     # yields the number of bytes of the shared memory
shmid(shm)      # yields the identifier the shared memory
```

To ensure that shared memory object `shm` is eventually destroyed, call:

```julia
rm(shm)
```


## BSD System V Shared Memory

The following methods and type give a lower-level access (compared to
`SharedMemory` objects) to manage BSD System V shared memory segments.


### System V shared memory segment identifiers

The following statements:

```julia
ShmId(id)                  -> id
ShmId(arr)                 -> id
ShmId(key, readlony=false) -> id
```

yield the the identifier of the existing System V shared memory segment
associated with the value of the first argument.  `id` is the identifier of the
shared memory segment, `arr` is an array attached to a System V shared memory
segment and `key` is the key associated with the shared memory segment.  In
that latter case, `readlony` can be set `true` to only request read-only
access; otherwise read-write access is requested.


### Getting or creating a shared memory segment

Call:

```julia
shmget(key, siz, flg) -> id
```

to get the identifier of the shared memory segment associated with the System V
IPC key `key`.  A new shared memory segment, with size equal to the value of
`siz` (possibly rounded up to a multiple of the memory page size
`IPC.PAGE_SIZE`), is created if `key` has the value `IPC.PRIVATE` or if
`IPC_CREAT` is specified in the argument `flg`, `key` isn't `IPC.PRIVATE` and
no shared memory segment corresponding to `key` exists.

Argument `flg` is a bitwise combination of flags.  The least significant 9 bits
specify the permissions granted to the owner, group, and others.  These bits
have the same format, and the same meaning, as the mode argument of `chmod`.
Bit `IPC_CREAT` can be set to create a new segment.  If this flag is not used,
then `shmget` will find the segment associated with `key` and check to see if
the user has permission to access the segment.  Bit `IPC_EXCL` can be set in
addition to `IPC_CREAT` to ensure that this call creates the segment.  If
`IPC_EXCL` and `IPC_CREAT` are both set, the call will fail if the segment
already exists.


### Attaching and detaching shared memory

Call:

```julia
shmat(id, readonly) -> ptr
```

to attach an existing shared memory segment to the address space of the caller.
Argument `id` is the identifier of the shared memory segment.  Boolean argument
`readonly` specifies whether to attach the segment for read-only access;
otherwise, the segment is attached for read and write accesses and the process
must have read and write permissions for the segment.  The returned value is a
pointer to the shared memory segment in the caller address space.

Assuming `ptr` is the pointer returned by a previous `shmat()` call:

```julia
shmdt(ptr)
```

detaches the System V shared memory segment from the address space of the caller.


### Destroying shared memory

To remove shared memory assoicaite with `arg`, call:

```julia
shmrm(arg)
```

If `arg` is a name, the corresponding POSIX named shared memory is unlinked.
If `arg` is a key or identifier of a BSD shared memory segment, the segment is
marked to be eventually destroyed.  Argument `arg` can also be a `SharedMemory`
object.

The `rm` method may also be called to remove an existing shared memory segment
or object:

```julia
rm(SharedMemory, name)
rm(SharedMemory, key)
rm(id)
rm(shm)
```

where `name` identifies a POSIX shared memory object, `key` is associated with
a BSD shared memory segment, `id` is the identifier of a BSD shared memory
segment and `shm` is an instance of `SharedMemory`.


### Controlling shared memory

To change the access permissions of a System V IPC shared memory segment, call:

```julia
shmcfg(arg, perms) -> id
```

where `perms` specifies bitwise flags with the new permissions.  The first
argument can be the identifier of the shared memory segment, a shared array
attached to the shared memory segment or the System V IPC key associated with
the shared memory segment.  In all cases, the identifier of the shared memory
segment is returned.

Other control operations can be performed with:

```julia
shmctl(id, cmd, buf)
```

where `id` is the identifier of the shared memory segment, `cmd` is the command
to perform and `buf` is a buffer large enough to store a `shmid_ds` C structure
(`IPC._sizeof_struct_shmid_ds` bytes).


### Retrieving shared memory information

To retrieve information about a System V shared memory segment, call one of:

```julia
shminfo(arg) -> info
ShmInfo(arg) -> info
```

with `arg` the identifier of the shared memory segment, a shared array attached
to the shared memory segment or the System V IPC key associated with the shared
memory segment.  The result is an instance of  `ShmInfo`.

Memory for the `ShmInfo` structure may be provided:

```julia
shminfo!(arg, info) -> info
```

where `info` is an instance of `ShmInfo` which is overwritten with information
about `arg` and returned.
