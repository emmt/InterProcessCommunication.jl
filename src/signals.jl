#
# signals.jl --
#
# Implements "real-time" signals for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2017, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#
# Part of the documentation is more or less directly extracted from the Linux
# manual pages (http://www.kernel.org/doc/man-pages/).
#

"""

`SigSet` represents a C `sigset_t` structure.  It should be considered as
*opaque*, its contents is stored as a tuple of unsigned integers whose size
matches that of `sigset_t`.

Typical usage is:

```julia
sigset = SigSet()
sigset[signum] -> boolean
sigset[signum] = boolean
fill!(sigset, boolean) -> sigset
```
```julia
IPC.sigfillset!(sigset)          # same as fill!(signum, true)
IPC.sigemptyset!(sigset)         # same as fill!(signum, false)
IPC.sigaddset!(sigset, signum)   # same as sigset[signum] = true
IPC.sigdelset!(sigset, signum)   # same as sigset[signum] = false
IPC.sigismember(sigset, signum)  # same as sigset[signum]

```

`signum` is the signal number, an integer greater or equal `1` and less or
equal`IPC.SIGRTMAX`.  Real-time signals have a number `signum` such that
`IPC.SIGRTMIN ≤ signum ≤ IPC.SIGRTMAX`

""" SigSet

Base.unsafe_convert(::Type{T}, pid::ProcessId) where {T<:Integer} =
    convert(T, pid.value)

Base.cconvert(::Type{T}, pid::ProcessId) where {T<:Integer} =
    convert(T, pid.value)

Base.getindex(sigset::SigSet, i::Integer) = sigismember(sigset, i)

Base.setindex!(sigset::SigSet, val::Bool, i::Integer) =
    (val ? sigaddset!(sigset, i) : sigdelset!(sigset, i))

function Base.fill!(sigset::SigSet, val::Bool)
    if val
        sigfillset!(sigset)
    else
        sigemptyset!(sigset)
    end
    return sigset
end

for T in (SigSet, SigInfo)
    @eval begin
        Base.pointer(obj::$T) = unsafe_convert(Ptr{$T}, obj)
        Base.unsafe_convert(::Type{Ptr{$T}}, obj::$T) =
            convert(Ptr{$T}, pointer_from_objref(obj))
    end
end

sigemptyset!(sigset::SigSet) =
    systemerror("sigemptyset", _sigemptyset(pointer(sigset)) != SUCCESS)

_sigemptyset(sigset::Ref{SigSet}) =
    ccall(:sigemptyset, Cint, (Ptr{SigSet},), sigset)

sigfillset!(sigset::SigSet) =
    systemerror("sigfillset", _sigfillset(pointer(sigset)) != SUCCESS)

_sigfillset(sigset::Ref{SigSet}) =
    ccall(:sigfillset, Cint, (Ptr{SigSet},), sigset)

sigaddset!(sigset::SigSet, signum::Integer) =
    systemerror("sigaddset",
                _sigaddset(pointer(sigset), signum) != SUCCESS)

_sigaddset(sigset::Ref{SigSet}, signum::Integer) =
    ccall(:sigaddset, Cint, (Ptr{SigSet}, Cint), sigset, signum)

sigdelset!(sigset::SigSet, signum::Integer) =
    systemerror("sigdelset",
                _sigdelset(pointer(sigset), signum) != SUCCESS)

_sigdelset(sigset::Ref{SigSet}, signum::Integer) =
    ccall(:sigdelset, Cint, (Ptr{SigSet}, Cint), sigset, signum)

function sigismember(sigset::SigSet, signum::Integer)
    val = _sigismember(pointer(sigset), signum)
    systemerror("sigismember", val == FAILURE)
    return val == one(val)
end

_sigismember(sigset::Ref{SigSet}, signum::Integer) =
    ccall(:sigismember, Cint, (Ptr{SigSet}, Cint), sigset, signum)


"""
```julia
sigqueue(pid, sig, val=0)
```

sends the signal `sig` to the process whose identifier is `pid`.  Argument
`val` is an optional value to join to to the signal.  This value represents a C
type `union sigval` (an union of a C `int` and a C `void*`), in Julia it is
specified as an integer large enough to represent both kind of values.

"""
sigqueue(pid::ProcessId, sig::Integer, val::Integer = 0) =
    systemerror("sigqueue",
                _sigqueue(pid.value, sig, val) != SUCCESS)

_sigqueue(pid::Integer, sig::Integer, val::Integer) =
    ccall(:sigqueue, Cint, (_typeof_pid_t, Cint, _typeof_sigval_t), pid, sig, val)

"""

```julia
sigpending() -> mask
```

yields the set of signals that are pending for delivery to the calling thread
(i.e., the signals which have been raised while blocked).  The returned value is
an instance of [`SigSet`](@ref).

See also: [`sigpending!`](@ref).

"""
sigpending() = sigpending!(SigSet())

"""

```julia
sigpending!(mask) -> mask
```

overwites `mask` with the set of pending signals and returns its argument.

See also: [`sigpending`](@ref).

"""
function sigpending!(mask::SigSet)
    systemerror("sigpending", _sigpending(pointer(mask)) != SUCCESS)
    return mask
end

_sigpending(mask::Ref{SigSet}) =
    ccall(:sigpending, Cint, (Ptr{SigSet},), mask)

"""

```julia
sigprocmask() -> cur
```

yields the current set of blocked signals.  To change the set of blocked
signals, call:

```julia
sigprocmask(how, set)
```

with `set` a `SigSet` mask and `how` a parameter which specifies how to
interpret `set`:

* `IPC.SIG_BLOCK`: The set of blocked signals is the union of the current set
  and the `set` argument.

* `IPC.SIG_UNBLOCK`: The signals in `set` are removed from the current set of
  blocked signals.  It is permissible to attempt to unblock a signal which is
  not blocked.

* `IPC.SIG_SETMASK`: The set of blocked signals is set to the argument `set`.

See also: [`sigprocmask!`](@ref).

"""
sigprocmask() = sigprocmask!(SigSet())

sigprocmask(how::Integer, set::SigSet) =
    systemerror(string(_sigprocmask_symbol),
                _sigprocmask(how, pointer(set), Ptr{SigSet}(0)) != SUCCESS)

# Constant `_sigprocmask_symbol` is `:sigprocmask` or `:pthread_sigmask`.
const _sigprocmask_symbol = :pthread_sigmask

"""

```julia
sigprocmask!(cur) -> cur
```

overwrites `cur`, an instance of `SigSet`, with the current set of blocked
signals and returns it.  To change the set of blocked signals, call:

```julia
sigprocmask!(how, set, old) -> old
```

which changes the set of blocked signals according to `how` and `set` (see
[`sigprocmask`](@ref)), overwrites `old`, an instance of `SigSet`, with the
previous set of blocked signals and returns `old`.

See also: [`sigprocmask`](@ref).

"""
function sigprocmask!(cur::SigSet)
    systemerror(string(_sigprocmask_symbol),
                _sigprocmask(IPC.SIG_BLOCK, Ptr{SigSet}(0), pointer(cur)) != SUCCESS)
    return cur
end

function sigprocmask!(how::Integer, set::SigSet, old::SigSet)
    systemerror(string(_sigprocmask_symbol),
                _sigprocmask(how, pointer(set), pointer(old)) != SUCCESS)
    return old
end

@doc @doc(sigprocmask) sigprocmask!

_sigprocmask(how::Integer, set::Ref{SigSet}, old::Ref{SigSet}) =
    ccall(_sigprocmask_symbol, Cint, (Cint, Ptr{SigSet}, Ptr{SigSet}),
          how, set, old)
"""
```julia
sigsuspend(mask)
```

temporarily replaces the signal mask of the calling process with the mask given
by `mask` and then suspends the process until delivery of a signal whose action
is to invoke a signal handler or to terminate a process.

If the signal terminates the process, then `sigsuspend` does not return.  If
the signal is caught, then `sigsuspend` returns after the signal handler
returns, and the signal mask is restored to the state before the call to
`sigsuspend`.

It is not possible to block `IPC.SIGKILL` or `IPC.SIGSTOP`; specifying these
signals in mask, has no effect on the process's signal mask.

"""
sigsuspend(mask::SigSet) =
    systemerror("sigsuspend", _sigsuspend(pointer(mask)) != SUCCESS)

_sigsuspend(mask::Ref{SigSet}) =
    ccall(:sigsuspend, Cint, (Ptr{SigSet},), mask)

"""
```julia
sigwait(mask, timeout=Inf) -> signum
```

suspends execution of the calling thread until one of the signals specified in
the signal set `mask` becomes pending.  The function accepts the signal
(removes it from the pending list of signals), and returns the signal number
`signum`.

Optional argument `timeout` can be specified to set a limit on the time to wait
for one the signals to become pending.  `timeout` can be a real number to
specify a number of seconds or an instance of `TimeSpec`.  If `timeout` is
`Inf` (the default), it is assumed that there is no limit on the time to wait.
If `timeout` is a number of seconds smaller or equal zero or if `timeout` is
`TimeSpec(0,0)`, the methods performs a poll and returns immediately.  It none
of the signals specified in the signal set `mask` becomes pending during the
allowed waiting time, a `TimeoutError` exception is raised.

See also: [`sigwait!`](@ref).

"""
function sigwait(mask::SigSet)
    signum = Ref{Cint}()
    code = _sigwait(pointer(mask), signum)
    code == 0 || throw_system_error("sigwait", code)
    return signum[]
end

sigwait(mask::SigSet, secs::Real)::Cint =
    (secs ≥ Inf ? sigwait(mask) : sigwait(mask, _sigtimedwait_timeout(secs)))

"""

```julia
sigwait!(mask, info, timeout=Inf) -> signum
```

behaves like [`sigwait`](@ref) but additional argument `info` is an instance of
`SigInfo` to store the information about the accepted signal, other arguments
are as for the [`sigwait`](@ref) method.

"""
sigwait!(mask::SigSet, info::SigInfo, secs::Real)::Cint =
    (secs ≥ Inf ? sigwait!(mask, info) :
     sigwait!(mask, info, _sigtimedwait_timeout(secs)))

function sigwait(mask::SigSet, timeout::TimeSpec)::Cint
    signum = _sigtimedwait(pointer(mask), Ptr{SigInfo}(0), Ref(timeout))
    signum == FAILURE && _throw_sigtimedwait_error()
    return signum
end

function sigwait!(mask::SigSet, info::SigInfo)
    signum = _sigwaitinfo(pointer(mask), pointer(info))
    systemerror("sigwaitinfo", signum == FAILURE)
    return signum
end

function sigwait!(mask::SigSet, info::SigInfo, timeout::TimeSpec)
    signum = _sigtimedwait(pointer(mask), pointer(info), Ref(timeout))
    signum == FAILURE && _throw_sigtimedwait_error()
    return signum
end

_sigwait(mask::Ref{SigSet}, signum::Ref{Cint}) =
    ccall(:sigwait, Cint, (Ptr{Cvoid}, Ptr{Cint}), mask, signum)

_sigwaitinfo(set::Ref{SigSet}, info::Ref{SigInfo}) =
    ccall(:sigwaitinfo, Cint, (Ptr{SigSet}, Ptr{SigInfo}), set, info)

_sigtimedwait(set::Ref{SigSet}, info::Ref{SigInfo}, timeout::Ref{TimeSpec}) =
    ccall(:sigtimedwait, Cint, (Ptr{SigSet}, Ptr{SigInfo}, Ptr{TimeSpec}),
          set, info, timeout)

function _sigtimedwait_timeout(secs::Real)::TimeSpec
    isnan(secs) && throw_argument_error("number of seconds is NaN")
    if secs > 0
        # Timeout is in the future.
        return TimeSpec(secs)
    else
        # Set timeout so as to perform a poll and return immediately.
        return TimeSpec(0, 0)
    end
end

function _throw_sigtimedwait_error()
    errno = Libc.errno()
    if errno == Libc.EAGAIN
        throw(TimeoutError())
    elseif errno == Libc.EINTR
        throw(InterruptException())
    else
        throw_system_error("sigtimedwait", errno)
    end
end

"""

`SigAction` is the counterpart of the C `struct sigaction` structure.  It is
used to specify the action taken by a process on receipt of a signal.  Assuming
`sa` is an instance of `SigAction`, its fields are:

```julia
sa.handler         # address of a signal handler
sa.mask            # mask of the signals to block
sa.flags           # bitwise flags
```

where `sa.handler` is the address of a C function (can be `SIG_IGN` or
`SIG_DFL`) to be called on receipt of the signal.  This function may be given
by `cfunction`.  If `IPC.SA_INFO` is not set in `sa.flags`, then the signature
of the handler is:

``julia
function handler(signum::Cint)::Nothing
```

that is a function which takes a single argument of type `Cint` and returns
nothing; if `IPC.SA_INFO` is not set in `sa.flags`, then the signature of the
handler is:

``julia
function handler(signum::Cint, siginf::Ptr{SigInfo}, unused::Ptr{Cvoid})::Nothing
```

that is a function which takes 3 arguments of type `Cint`, `Ptr{SigInfo}`,
`Ptr{Cvoid}` repectively and which returns nothing.  See [`SigInfo`](@ref)
for a description of the `siginf` argument by the handler.

Call:

```julia
sa = SigAction()
```

to create a new empty structure or

```julia
sa = SigAction(handler, mask, flags)
```

to provide all fields.


See also [`SigInfo`](@ref), [`sigaction`](@ref) and [`sigaction!`](@ref).

"""
SigAction() = SigAction(C_NULL, SigSet(), 0)

function Base.show(io::IO, obj::SigAction)
    print(io, "SigAction(handler=Ptr{Cvoid}(")
    @printf(io, "%p", obj.handler)
    print(io, "), mask=SigSet(....), flags=0x", string(obj.flags, base=16), ")")
end

Base.show(io::IO, ::MIME"text/plain", obj::SigAction) = show(io, obj)

"""

```julia
sigaction(signum) -> cur
```

yields the current action taken by the process on receipt of the signal
`signum`.

```julia
sigaction(signum, sigact)
```

installs `sigact` (an instance of [`SigAction`](@ref)) to be the action taken
by the process on receipt of the signal `signum`.

Note that `signum` cannot be `SIGKILL` nor `SIGSTOP`.

See also [`SigAction`](@ref) and [`sigaction!`](@ref).

"""
function sigaction(signum::Integer)
    buf = _sigactionbuffer()
    ptr = pointer(buf)
    systemerror("sigaction", _sigaction(signum, C_NULL, ptr) != SUCCESS)
    flags = _getsigactionflags(ptr)
    return SigAction(_getsigactionhandler(ptr, flags),
                     _getsigactionmask(ptr), flags)
end

function sigaction(signum::Integer, sigact::SigAction)
    buf = _sigactionbuffer()
    ptr = pointer(buf)
    _storesigaction!(ptr, sigact)
    systemerror("sigaction", _sigaction(signum, ptr, C_NULL) != SUCCESS)
end

"""

```julia
sigaction!(signum, sigact, oldact) -> oldact
```

installs `sigact` to be the action taken by the process on receipt of the
signal `signum`, overwrites `oldact` with the previous action and returns it.
See [`SigAction`](@ref) and [`sigaction`](@ref) for more details.

"""
function sigaction!(signum::Integer, sigact::SigAction, old::SigAction)
    newbuf = _sigactionbuffer()
    newptr = pointer(newbuf)
    oldbuf = _sigactionbuffer()
    oldptr = pointer(oldbuf)
    _storesigaction!(newptr, sigact)
    systemerror("sigaction", _sigaction(signum, newptr, oldptr) != SUCCESS)
    old.flags = _getsigactionflags(oldptr)
    old.handler = _getsigactionhandler(oldptr, old.flags)
    old.mask = _getsigactionmask(oldptr)
    return old
end

_sigaction(signum::Integer, act::Ptr{<:Union{UInt8,Nothing}}, old::Ptr{<:Union{UInt8,Nothing}}) =
    ccall(:sigaction, Cint, (Cint, Ptr{Cvoid}, Ptr{Cvoid}), signum, act, old)

_sigactionbuffer() = zeros(UInt8, _sizeof_sigaction)

function _storesigaction!(ptr::Ptr{UInt8}, sigact::SigAction)
    _setsigactionhandler!(ptr, sigact.handler, sigact.flags)
    _setsigactionmask!(ptr, sigact.mask)
    _setsigactionflags!(ptr, sigact.flags)
    return ptr
end

function _getsigactionhandler(ptr::Ptr{UInt8}, flags::_typeof_sigaction_flags)
    offset = ((flags & SA_SIGINFO) == SA_SIGINFO ?
              _offsetof_sigaction_action :
              _offsetof_sigaction_handler)
    return _peek(Ptr{Cvoid}, ptr + offset)
end

function _setsigactionhandler!(ptr::Ptr{UInt8}, handler::Ptr{Cvoid},
                               flags::_typeof_sigaction_flags)
    offset = ((flags & SA_SIGINFO) == SA_SIGINFO ?
              _offsetof_sigaction_action :
              _offsetof_sigaction_handler)
    _poke!(Ptr{Cvoid}, ptr + offset, handler)
end

_setsigactionaction!(ptr::Ptr{UInt8}, action::Ptr{Cvoid}) =
    _poke!(Ptr{Cvoid}, ptr + _offsetof_sigaction_action, action)

_getsigactionmask(ptr::Ptr{UInt8}) =
    _peek(SigSet, ptr + _offsetof_sigaction_mask)

_setsigactionmask!(ptr::Ptr{UInt8}, mask::SigSet) =
    _poke!(SigSet, ptr + _offsetof_sigaction_mask, mask)

_getsigactionflags(ptr::Ptr{UInt8}) =
    _peek(_typeof_sigaction_flags, ptr + _offsetof_sigaction_flags)

_setsigactionflags!(ptr::Ptr{UInt8}, flags::Integer) =
    _poke!(_typeof_sigaction_flags, ptr + _offsetof_sigaction_flags, flags)


"""

`SigInfo` represents a C `siginfo_t` structure.  It should be considered as
opaque, its contents is stored as a tuple of unsigned integers whose size
matches that of `siginfo_t` but, in principle, only a pointer of it should be
received by a signal handler established with the `SA_SIGINFO` flag.

Given `ptr`, an instance of `Ptr{SigInfo}` received by a signal handler, the
members of the corresponding C `siginfo_t` structure are retrieved by:

```julia
IPC.siginfo_signo(ptr)  # Signal number.
IPC.siginfo_code(ptr)   # Signal code.
IPC.siginfo_errno(ptr)  # If non-zero, an errno value associated with this
                        # signal.
IPC.siginfo_pid(ptr)    # Sending process ID.
IPC.siginfo_uid(ptr)    # Real user ID of sending process.
IPC.siginfo_addr(ptr)   # Address of faulting instruction.
IPC.siginfo_status(ptr) # Exit value or signal.
IPC.siginfo_band(ptr)   # Band event for SIGPOLL.
IPC.siginfo_value(ptr)  # Signal value.
```

These methods are *unsafe* because they directly use an address.  They are
therefore not exported by default.  Depending on the context, not all members
of `siginfo_t` are relevant (furthermore they may be defined as union and thus
overlap in memory).  For now, only the members defined by the POSIX standard
are accessible.  Finally, the value given by `IPC.siginfo_value(ptr)`
represents a C type `union sigval` (an union of a C `int` and a C `void*`), in
Julia it is returned (and set in [`sigqueue`](@ref)) as an integer large enough
to represent both kind of values.

""" SigInfo

for f in (:siginfo_signo, :siginfo_code, :siginfo_errno, :siginfo_pid,
          :siginfo_uid, :siginfo_status, :siginfo_value, :siginfo_addr,
          :siginfo_band)
    @eval begin
        @doc @doc(SigInfo) $f
        $f(si::SigInfo) = $f(pointer(si))
    end
end

siginfo_signo(ptr::Ptr{SigInfo}) =
    _peek(Cint, ptr + _offsetof_siginfo_signo)

siginfo_code(ptr::Ptr{SigInfo}) =
    _peek(Cint, ptr + _offsetof_siginfo_code)

siginfo_errno(ptr::Ptr{SigInfo}) =
    _peek(Cint, ptr + _offsetof_siginfo_errno)

siginfo_pid(ptr::Ptr{SigInfo}) =
    _peek(ProcessId, ptr + _offsetof_siginfo_pid)

siginfo_uid(ptr::Ptr{SigInfo}) =
    _peek(UserId, ptr + _offsetof_siginfo_uid)

siginfo_status(ptr::Ptr{SigInfo}) =
    _peek(Cint, ptr + _offsetof_siginfo_status)

siginfo_value(ptr::Ptr{SigInfo}) =
    _peek(_typeof_sigval_t, ptr + _offsetof_siginfo_value)

siginfo_addr(ptr::Ptr{SigInfo}) =
    _peek(Ptr{Cvoid}, ptr + _offsetof_siginfo_addr)

siginfo_band(ptr::Ptr{SigInfo}) =
    _peek(Clong, ptr + _offsetof_siginfo_band)

# FIXME: non-POSIX
# siginfo_utime(ptr::Ptr{SigInfo}) =
#     _peek(_typeof_clock_t, ptr + _offsetof_siginfo_utime)
# siginfo_stime(ptr::Ptr{SigInfo}) =
#     _peek(_typeof_clock_t, ptr + _offsetof_siginfo_stime)
# siginfo_int(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_int)
# siginfo_ptr(ptr::Ptr{SigInfo}) =
#     _peek(Ptr{Cvoid}, ptr + _offsetof_siginfo_ptr)
# siginfo_overrun(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_overrun)
# siginfo_timerid(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_timerid)
# siginfo_fd(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_fd)
# siginfo_addr_lsb(ptr::Ptr{SigInfo}) =
#     _peek(Cshort, ptr + _offsetof_siginfo_)
# siginfo_call_addr(ptr::Ptr{SigInfo}) =
#     _peek(Ptr{Cvoid}, ptr + _offsetof_siginfo_)
# siginfo_syscall(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_)
# siginfo_arch(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_)

# FIXME: siginterrupt - allow signals to interrupt system calls.
#        Not implemented (obsoleted in POSIX), use sigaction with SA_RESTART
#        flag instead.
