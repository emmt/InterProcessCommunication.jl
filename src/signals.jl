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

sigemptyset!(sigset::SigSet) =
    systemerror("sigemptyset", _sigemptyset(Ref(sigset)) != SUCCESS)

_sigemptyset(sigset::Ref{SigSet}) =
    ccall(:sigemptyset, Cint, (Ptr{SigSet},), sigset)

sigfillset!(sigset::SigSet) =
    systemerror("sigfillset", _sigfillset(Ref(sigset)) != SUCCESS)

_sigfillset(sigset::Ref{SigSet}) =
    ccall(:sigfillset, Cint, (Ptr{SigSet},), sigset)

sigaddset!(sigset::SigSet, signum::Integer) =
    systemerror("sigaddset",
                _sigaddset(Ref(sigset), signum) != SUCCESS)

_sigaddset(sigset::Ref{SigSet}, signum::Integer) =
    ccall(:sigaddset, Cint, (Ptr{SigSet}, Cint), sigset, signum)

sigdelset!(sigset::SigSet, signum::Integer) =
    systemerror("sigdelset",
                _sigdelset(Ref(sigset), signum) != SUCCESS)

_sigdelset(sigset::Ref{SigSet}, signum::Integer) =
    ccall(:sigdelset, Cint, (Ptr{SigSet}, Cint), sigset, signum)

function sigismember(sigset::SigSet, signum::Integer)
    val = _sigismember(Ref(sigset), signum)
    systemerror("sigismember", val == FAILURE)
    return val == one(val)
end

_sigismember(sigset::Ref{SigSet}, signum::Integer) =
    ccall(:sigismember, Cint, (Ptr{SigSet}, Cint), sigset, signum)


"""
```julia
sigqueue(pid::Integer, sig::Integer, val
```
"""
sigqueue(pid::ProcessId, sig::Integer, val::Integer = 0) =
    systemerror("sigqueue",
                _sigqueue(pid.value, sig, val) != SUCCESS)

_sigqueue(pid::Integer, sig::Integer, val::Integer) =
    ccall(:sigqueue, Cint, (_typeof_pid_t, Cint, _typeof_sigval_t), pid, sig, val)

"""
```julia
sigpending() -> sigset
```

yields the set of signals that are pending for delivery to the calling thread
(i.e., the signals which have been raised while blocked).  The retuened value is
an instance of [`SigSet`](@ref).

The call:
```julia
sigpending!(sigset) -> sigset
```

overwites `sigset` with the set of pending signals and returns its argument.

""" sigpending

@doc @doc(sigpending) sigpending!

sigpending() = sigpending!(SigSet())

function sigpending!(sigset::SigSet)
    systemerror("sigpending", _sigpending(Ref(sigset)) != SUCCESS)
    return sigset
end

_sigpending(sigset::Ref{SigSet}) =
    ccall(:sigpending, Cint, (Ptr{SigSet},), sigset)

_sigprocmask(how::Integer, sigset::SigSet, oldset::SigSet) =
    ccall(:sigprocmask, Cint, (Cint, Ptr{SigSet}, Ptr{SigSet}),
          how, sigset, oldset)

"""
```julia
wait(sigset::SigSet) -> signum
```

suspends execution of the calling thread until one of the signals specified in
the signal set `sigset` becomes pending.  The function accepts the signal
(removes it from the pending list of signals), and returns the signal number
`signum`.

"""
function Base.wait(sigset::SigSet)
    signum = Ref{Cint}()
    code = _sigwait(Ref(sigset), signum)
    code == 0 || throw_system_error("sigwait", code)
    return signum[]
end

_sigwait(sigset::Ref{SigSet}, signum::Ref{Cint}) =
    ccall(:sigwait, Cint, (Ptr{Void}, Ptr{Cint}), sigset, signum)

"""
```julia
sigaction(signum) -> curact
```

yields the current action taken by the process on receipt of the signal
`signum`.

```julia
sigaction(signum, sigact)
```

installs `sigact` to be the action taken by the process on receipt of the
signal `signum`.

```julia
sigaction!(signum, sigact, oldact) -> oldact
```

installs `sigact` to be the action taken by the process on receipt of the
signal `signum`, overwrites `oldact` with the previous action and returns it.

Note that `signum` cannot be `SIGKILL` nor `SIGSTOP`.

The action taken by a process on receipt of a signal is specified by an
instance of `SigAction` wich is used as follows:

``julia
sa = SigAction()   # create a new empty structure
sa.handler         # address of a signal handler
sa.mask            # mask of the signals to block
sa.flags           # bitwise flags
```

or

```julia
sa = SigAction(handler, mask, flags)
```

Here `sa.handler` is the address of a C function (can be `SIG_IGN` or
`SIG_DFL`) to be called on receipt of the signal.  This function may be given
by [`cfunction`](@ref).  If `IPC.SA_INFO` is not set in `sa.flags`, then the
signature of the handler is:

``julia
function handler(signum::Cint)::Void
```

that is a function which takes a single argument of type `Cint` and returns
nothing; if `IPC.SA_INFO` is not set in `sa.flags`, then the signature of the
handler is:

``julia
function handler(signum::Cint, siginf::Ptr{SigInfo}, unused::Ptr{Void})::Void
```

that is a function which takes 3 arguments of type `Cint`, `Ptr{SigInfo}`,
`Ptr{Void}` repectively and which returns nothing.  See [`SigInfo`](@ref)
for a description of the `siginf` argument by the handler.

See also: [`SigInfo`](@ref).

""" SigAction

@doc @doc(SigAction) sigaction
@doc @doc(SigAction) sigaction!

SigAction() = SigAction(C_NULL, SigSet(), 0)

function Base.show(io::IO, obj::SigAction)
    print(io, "SharedMemory(handler=Ptr{Void}(")
    @printf(io, "%p", obj.handler)
    print(io, "), mask=SigSet(....), flags=0x", hex(obj[:flags]), ")")
end

Base.show(io::IO, ::MIME"text/plain", obj::SigAction) = show(io, obj)

function sigaction(signum::Integer)
    buf = _sigactionbuffer()
    ptr = pointer(buf)
    systemerror("sigaction", _sigaction(signum, C_NULL, ptr) != SUCCESS)
    return _loadsigaction(ptr)
end

function sigaction(signum::Integer, sigact::SigAction)
    buf = _sigactionbuffer()
    ptr = pointer(buf)
    _storesigaction!(ptr, sigact)
    systemerror("sigaction", _sigaction(signum, ptr, C_NULL) != SUCCESS)
end

function sigaction!(signum::Integer, sigact::SigAction, sigold::SigAction)
    newbuf = _sigactionbuffer()
    newptr = pointer(newbuf)
    oldbuf = _sigactionbuffer()
    oldptr = pointer(oldbuf)
    _storesigaction!(newptr, sigact)
    systemerror("sigaction", _sigaction(signum, newptr, oldptr) != SUCCESS)
    return _loadsigaction(oldptr)
end

_sigaction(signum::Integer, act::Ptr{<:Union{UInt8,Void}}, old::Ptr{<:Union{UInt8,Void}}) =
    ccall(:sigaction, Cint, (Cint, Ptr{Void}, Ptr{Void}), signum, act, old)

_sigactionbuffer() =
    fill!(Array{UInt8}(_sizeof_sigaction),0)

function _storesigaction!(buf::Ptr{UInt8}, sigact::SigAction)
    _setsigactionhandler!(buf, sigact.handler, sigact.flags)
    _setsigactionmask!(buf, sigact.mask)
    _setsigactionflags!(buf, sigact.flags)
    return buf
end

function _loadsigaction(buf::Ptr{UInt8})
    flags = _getsigactionflags(buf)
    return SigAction(_getsigactionhandler(buf, flags),
                     _getsigactionmask(buf), flags)
end

function _getsigactionhandler(buf::Ptr{UInt8}, flags::_typeof_sigaction_flags)
    offset = ((flags & SA_SIGINFO) == SA_SIGINFO ?
              _offsetof_sigaction_action :
              _offsetof_sigaction_handler)
    return _peek(Ptr{Void}, buf + offset)
end

function _setsigactionhandler!(buf::Ptr{UInt8}, handler::Ptr{Void},
                               flags::_typeof_sigaction_flags)
    offset = ((flags & SA_SIGINFO) == SA_SIGINFO ?
              _offsetof_sigaction_action :
              _offsetof_sigaction_handler)
    _poke!(Ptr{Void}, buf + offset, handler)
end

_setsigactionaction!(buf::Ptr{UInt8}, ptr::Ptr{Void}) =
    _poke!(Ptr{Void}, buf + _offsetof_sigaction_action, ptr)

_getsigactionmask(buf::Ptr{UInt8}) =
    _peek(SigSet, buf + _offsetof_sigaction_mask)

_setsigactionmask!(buf::Ptr{UInt8}, mask::SigSet) =
    _poke!(SigSet, buf + _offsetof_sigaction_mask, mask)

_getsigactionflags(buf::Ptr{UInt8}) =
    _peek(_typeof_sigaction_flags, buf + _offsetof_sigaction_flags)

_setsigactionflags!(buf::Ptr{UInt8}, flags::Integer) =
    _poke!(_typeof_sigaction_flags, buf + _offsetof_sigaction_flags, flags)


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
IPC.siginfo_errno(ptr)  # If non-zero, an errno value associated with this signal.
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

@doc @doc(SigInfo) siginfo_signo
@doc @doc(SigInfo) siginfo_code
@doc @doc(SigInfo) siginfo_errno
@doc @doc(SigInfo) siginfo_pid
@doc @doc(SigInfo) siginfo_uid
@doc @doc(SigInfo) siginfo_status
@doc @doc(SigInfo) siginfo_value
@doc @doc(SigInfo) siginfo_addr
@doc @doc(SigInfo) siginfo_band

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
    _peek(Ptr{Void}, ptr + _offsetof_siginfo_addr)

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
#     _peek(Ptr{Void}, ptr + _offsetof_siginfo_ptr)
# siginfo_overrun(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_overrun)
# siginfo_timerid(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_timerid)
# siginfo_fd(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_fd)
# siginfo_addr_lsb(ptr::Ptr{SigInfo}) =
#     _peek(Cshort, ptr + _offsetof_siginfo_)
# siginfo_call_addr(ptr::Ptr{SigInfo}) =
#     _peek(Ptr{Void}, ptr + _offsetof_siginfo_)
# siginfo_syscall(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_)
# siginfo_arch(ptr::Ptr{SigInfo}) =
#     _peek(Cint, ptr + _offsetof_siginfo_)

# FIXME: not sure all are RT signals:
# FIXME: sigprocmask - examine and change blocked signals
# FIXME: sigreturn - return from signal handler and cleanup stack frame
# FIXME: sigsuspend - wait for a signal
# FIXME: siginterrupt - allow signals to interrupt system calls
