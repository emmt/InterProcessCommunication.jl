# Reference

The following provides detailled documentation about types and methods provided
by the IPC package.  This information is also available from the REPL by typing
`?` followed by the name of a method or a type.


## Semaphores

```@docs
Semaphore
```

```@docs
post(::Semaphore)
```

```@docs
wait(::Semaphore)
```

```@docs
timedwait(::Semaphore, ::Real)
```

```@docs
trywait(::Semaphore)
```


## Exceptions

```@docs
TimeoutError
```
