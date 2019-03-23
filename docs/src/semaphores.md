# Semaphores

A semaphore is associated with an integer value which is never allowed to fall
below zero.  Two operations can be performed on a semaphore `sem`: increment
the semaphore value by one with `post(sem)`; and decrement the semaphore value
by one with `wait(sem)`.  If the value of a semaphore is currently zero, then a
`wait(sem)` call will block until the value becomes greater than zero.

There are two kinds of semaphores: *named* and *anonymous* semaphores.  [Named
Semaphores](@ref) are identified by their name which is a string of the form
`"/somename"`.  [Anonymous Semaphores](@ref) are backed by *memory* objects
(usually shared memory) providing the necessary storage.  In Julia IPC package,
semaphores are instances of `Semaphore{T}` where `T` is `String` for named
semaphores and the type of the backing memory object for anonymous semaphores.


## Named Semaphores

Named semaphores are identified by their name which is a string of the form
`"/somename"`.  A new named semaphore identified by the string `name` is
created by:

```julia
Semaphore(name, value; perms=0o600, volatile=true) -> sem
```

which creates a new named semaphore with initial value set to `value` and
returns an instance of `Semaphore{String}`.  Keyword `perms` can be used to
specify access permissions (the default value warrants read and write
permissions for the caller).  Keyword `volatile` specify whether the semaphore
should be unlinked when the returned object is finalized.

Another process (or thread) can open an existing named semaphore by calling:

```julia
Semaphore(name) -> sem
```

which yields an instance of `Semaphore{String}`.

To unlink (remove) a persistent named semaphore, simply do:

```julia
rm(Semaphore, name)
```

If the semaphore does not exists, the error is ignored.  A `SystemError` is
however thrown for other errors.

For maximum flexibility, an instance of a named semaphore may also be created
by:

```julia
open(Semaphore, name, flags, mode, value, volatile) -> sem
```

where `flags` may have the bits `IPC.O_CREAT` and `IPC.O_EXCL` set, `mode`
specifies the granted access permissions, `value` is the initial semaphore
value and `volatile` is a boolean indicating whether the semaphore should be
unlinked when the returned object `sem` is finalized.  The values of `mode` and
`value` are ignored if an existing named semaphore is open.


## Anonymous Semaphores

Anonymous semaphores are backed by *memory* objects providing the necessary
storage.

A new anonymous semaphore is created by:

```julia
Semaphore(mem, value; offset=0, volatile=true) -> sem
```

which initializes an anonymous semaphore backed by memory object `mem` with
initial value set to `value` and returns an instance of
`Semaphore{typeof(mem)}`.  Keyword `offset` can be used to specify the address
(in bytes) of the semaphore data relative to `pointer(mem)`.  Keyword
`volatile` specify whether the semaphore should be destroyed when the returned
object is finalized.

The number of bytes needed to store an anonymous semaphore is given by
`sizeof(Semaphore)` and anonymous semaphore must be aligned in memory at
multiples of the word size in bytes (that is `Sys.WORD_SIZE >> 3`).  Memory
objects used to store an anonymous semaphore must implement two methods:
`pointer(mem)` and `sizeof(mem)` to yield respectively the base address (as an
instance of `Ptr`) and the size (in bytes) of the associated memory.

Another process (or thread) can use an existing (initialized) anonymous
semaphore by calling:

```julia
Semaphore(mem; offset=0) -> sem
```

where `mem` is the memory object which provides the storage of the semaphore at
relative position specified by keyword `offset` (zero by default).  The
returned value is an instance of `Semaphore{typeof(mem)}`


## Operations on Semaphores

### Semaphore Value and Size

To query the value of semaphore `sem`, do:

```julia
sem[]
```

However beware that the value of the semaphore may already have changed by the
time the result is returned.  The minimal and maximal values that can take a
semaphore are given by:

```julia
typemin(Semaphore)
typemax(Semaphore)
```

To allocate memory for anonymous semaphores, you need to know the number of
bytes needed to store a semaphore.  This is given by:

```julia
sizeof(Semaphore)
```


### Post and Wait

To unlock the semaphore `sem`, call:

```julia
post(sem)
```

which increments by one the semaphore's value.  If the semaphore's value
consequently becomes greater than zero, then another process or thread blocked
in a `wait` call on this semaphore will be woken up.

Locking the semaphore `sem` is done by:

```julia
wait(sem)
```

which decrements by one the semaphore `sem`.  If the semaphore's value is
greater than zero, then the decrement proceeds and the function returns
immediately.  If the semaphore currently has the value zero, then the call
blocks until either it becomes possible to perform the decrement (i.e., the
semaphore value rises above zero), or a signal handler interrupts the call (in
which case an instance of `InterruptException` is thrown).  A `SystemError` may
be thrown if an unexpected error occurs.

To try locking the semaphore `sem` without blocking, do:

```julia
trywait(sem) -> boolean
```

which attempts to immediately decrement (lock) the semaphore returning `true`
if successful.  If the decrement cannot be immediately performed, then `false`
is returned.  If an interruption is received or if an unexpected error occurs,
an exception is thrown (`InterruptException` or `SystemError` repectively).

Finally, the call:

```julia
timedwait(sem, secs)
```

decrements (locks) the semaphore `sem`.  If the semaphore's value is greater
than zero, then the decrement proceeds and the function returns immediately.
If the semaphore currently has the value zero, then the call blocks until
either it becomes possible to perform the decrement (i.e., the semaphore value
rises above zero), or the limit of `secs` seconds expires (in which case an
instance of `TimeoutError` is thrown), or a signal handler interrupts the call
(in which case an instance of `InterruptException` is thrown).
