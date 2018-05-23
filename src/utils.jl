#
# utils.jl --
#
# Useful methods and constants for IPC module of Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

# A bit of magic for calling C-code:
Base.convert(::Type{_typeof_key_t}, key::Key) = key.value
Base.convert(::Type{T}, key::Key) where {T<:Integer} = convert(T, key.value)

# The short version of `show` if also used for string interpolation in
# scripts so that extending methods:
#     Base.convert(::Type{String}, obj::T)
#     Base.string(obj::T)
# is not necessary.
Base.show(io::IO, key::Key) = print(io, "IPC.Key(", dec(key.value), ")")
Base.show(io::IO, ::MIME"text/plain", arg::Key) = show(io, arg)

"""

`IPC.PRIVATE` is a special IPC key (of type `IPC.Key`) which indicates that a
new (private) key should be created.

"""
const PRIVATE = Key(IPC_PRIVATE)

"""
Immutable type `IPC.Key` stores a System V IPC key.  The call:

```julia
IPC.Key(path, proj)
```

generates a System V IPC key from pathname `path` and a project identifier
`proj` (a single character).  The key is suitable for System V Inter-Process
Communication (IPC) facilities (message queues, semaphores and shared memory).
For instance:

```julia
key = IPC.Key(".", 'a')
```

The special IPC key [`IPC.PRIVATE`](@ref) is also available to indicate that a
new (private) key should be created.

"""
Key(path::AbstractString, proj::Union{Char,Integer}) =
    Key(path, convert(Cint, proj))

function Key(path::AbstractString, proj::Cint)
    1 ≤ proj ≤ 255 || throw(ArgumentError("`proj` must be in the range 1:255"))
    key = ccall(:ftok, _typeof_key_t, (Cstring, Cint), path, proj)
    systemerror("ftok", key == -1)
    return Key(key)
end

"""
```julia
gettimeofday() -> tv
```

yields the current time as an instance of `IPC.TimeVal`.  The result can be
converted into a fractional number of seconds by calling `float(tv)`.

See also: [`IPC.TimeVal`](@ref), [`nanosleep`](@ref), [`clock_gettime`](@ref).

"""
function gettimeofday()
    tv = Ref(TimeVal(0, 0))
    # `gettimeofday` should not fail in this case
    ccall(:gettimeofday, Cint, (Ptr{TimeVal}, Ptr{Void}), tv, C_NULL)
    return tv[]
end

"""
```julia
nanosleep(t) -> rem
```

sleeps for `t` seconds with nanosecond precision and returns the remaining time
(in case of interrupts) as an instance of `IPC.TimeSpec`.  Argument can be a
(fractional) number of seconds or an instance of `IPC.TimeSpec` or
`IPC.TimeVal`.

The `sleep` method provided by Julia has only millisecond precision.

See also: [`gettimeofday`](@ref), [`sleep`](@ref), [`IPC.TimeSpec`](@ref),
          [`IPC.TimeVal`](@ref).

"""
nanosleep(t::Union{Real,TimeVal}) = nanosleep(TimeSpec(t))

function nanosleep(ts::TimeSpec)
    rem = Ref(TimeSpec(0,0))
    ccall(:nanosleep, Cint, (Ptr{TimeSpec}, Ptr{TimeSpec}), Ref(ts), rem)
    return rem[]
end

"""
```julia
clock_getres(id) -> ts
```

yields the resolution (precision) of the specified clock `id`. The result is an
instance of `IPC.TimeSpec`.  Clock identifier `id` can be `CLOCK_REALTIME` or
`CLOCK_MONOTONIC` (described in [`clock_gettime`](@ref)).

See also: [`clock_gettime`](@ref), [`clock_settime`](@ref),
          [`gettimeofday`](@ref), [`nanosleep`](@ref), [`IPC.TimeSpec`](@ref),
          [`IPC.TimeVal`](@ref).

"""
function clock_getres(id::Integer)
    res = Ref(TimeSpec(0,0))
    systemerror("clock_getres",
                ccall(:clock_getres, Cint, (_typeof_clockid_t, Ptr{TimeSpec}),
                      id, res) != SUCCESS)
    return res[]
end

"""
```julia
clock_gettime(id) -> ts
```

yields the time of the specified clock `id`.  The result is an instance of
`IPC.TimeSpec`.  Clock identifier `id` can be one of:

* `CLOCK_REALTIME`: System-wide clock that measures real (i.e., wall-clock)
  time.  This clock is affected by discontinuous jumps in the system time
  (e.g., if the system administrator manually changes the clock), and by the
  incremental adjustments performed by `adjtime` and NTP.

* `CLOCK_MONOTONIC`: Clock that cannot be set and represents monotonic time
  since some unspecified starting point.  This clock is not affected by
  discontinuous jumps in the system time.

See also: [`clock_getres`](@ref), [`clock_settime`](@ref),
          [`gettimeofday`](@ref), [`nanosleep`](@ref), [`IPC.TimeSpec`](@ref),
          [`IPC.TimeVal`](@ref).

"""
function clock_gettime(id::Integer)
    ts = Ref(TimeSpec(0,0))
    systemerror("clock_gettime",
                ccall(:clock_gettime, Cint, (_typeof_clockid_t, Ptr{TimeSpec}),
                      id, ts) != SUCCESS)
    return ts[]
end

@doc @doc(clock_gettime) CLOCK_REALTIME
@doc @doc(clock_gettime) CLOCK_MONOTONIC

"""
```julia
clock_settime(id, ts)
```

set the time of the specified clock `id` to `ts`.  Argument `ts` can be an
instance of `IPC.TimeSpec` or a number of seconds.  Clock identifier `id` can
be `CLOCK_REALTIME` or `CLOCK_MONOTONIC` (described in
[`clock_gettime`](@ref)).

See also: [`clock_getres`](@ref), [`clock_gettime`](@ref),
          [`gettimeofday`](@ref), [`nanosleep`](@ref), [`IPC.TimeSpec`](@ref),
          [`IPC.TimeVal`](@ref).

"""
clock_settime(id::Integer, sec::Real) =
    clock_settime(id, TimeSpec(sec))

clock_settime(id::Integer, ts::TimeSpec) =
    clock_settime(id, Ref{TimeSpec}(sec))

clock_settime(id::Integer, ts::Union{Ref{TimeSpec},Ptr{TimeSpec}}) =
    systemerror("clock_settime",
                ccall(:clock_settime, Cint, (_typeof_clockid_t, Ptr{TimeSpec}),
                      id, ts) != SUCCESS)

TimeSpec(sec::Real) = convert(TimeSpec, sec)

TimeVal(sec::Real) = convert(TimeVal, sec)

_time_t(x::Integer) = convert(_typeof_time_t, x)
_time_t(x::Real) = round(_typeof_time_t, x)

Base.float(t::Union{TimeVal,TimeSpec}) = convert(Float64, t)

Base.convert(::Type{T}, tv::TimeVal) where {T<:AbstractFloat} =
    convert(T, tv.sec + tv.usec//_time_t(1_000_000))

Base.convert(::Type{T}, ts::TimeSpec) where {T<:AbstractFloat} =
    convert(T, ts.sec + ts.nsec//_time_t(1_000_000_000))

Base.convert(::Type{TimeVal}, sec::T) where {T<:AbstractFloat} =
    TimeVal(_splittime(sec, _time_t(1_000_000))...)

Base.convert(::Type{TimeSpec}, sec::T) where {T<:AbstractFloat} =
    TimeSpec(_splittime(sec, _time_t(1_000_000_000))...)

function _splittime(sec::AbstractFloat, mlt::_typeof_time_t)
    s = floor(sec)
    ip = _time_t(s)
    fp = _time_t((sec - s)*mlt)
    if fp ≥ mlt
        fp -= mlt
        ip += one(_typeof_time_t)
    end
    return (ip, fp)
end

Base.convert(::Type{TimeVal}, sec::Integer) = TimeVal(sec, 0)

Base.convert(::Type{TimeSpec}, sec::Integer) = TimeSpec(sec, 0)

Base.convert(::Type{TimeSpec}, tv::TimeVal) =
    TimeSpec(_fixtime(tv.sec, tv.usec*_time_t(1_000),
                      _time_t(1_000_000_000))...)

Base.convert(::Type{TimeVal}, ts::TimeSpec) =
    TimeVal(_fixtime(ts.sec, _time_t(ts.nsec//_time_t(1_000)),
                      _time_t(1_000_000))...)

function _fixtime(ip::_typeof_time_t, fp::_typeof_time_t, mlt::_typeof_time_t)
    ip += div(fp, mlt)
    fp = rem(fp, mlt)
    if ip < 0
        ip += mtl
        fp -= one(_typeof_time_t)
    end
    return (ip, fp)
end

syserrmsg(msg::AbstractString, code::Integer=Libc.errno()) =
    string(msg," [",Libc.strerror(code),"]")

makedims(dims::NTuple{N,Int}) where {N} = dims
makedims(dims::NTuple{N,Integer}) where {N} =
    ntuple(i -> Int(dims[i]), N)
makedims(dims::AbstractVector{<:Integer}) =
    ntuple(i -> Int(dims[i]), length(dims))

function checkdims(dims::NTuple{N,<:Integer}) where {N}
    number = one(Int)
    for i in 1:N
        dims[i] ≥ 1 || error("invalid dimension (dims[$i] = $(dims[i]))")
        number *= convert(Int, dims[i])
    end
    return number
end

roundup(a::Integer, b::Integer) =
    roundup(convert(Int, a), convert(Int, b))

roundup(a::Int, b::Int) =
    div(a + (b - 1), b)*b

@inline _peek(ptr::Ptr{T}) where {T} =
    unsafe_load(ptr)
@inline _peek(::Type{T}, ptr::Ptr) where {T} =
    _peek(convert(Ptr{T}, ptr))
@inline _peek(::Type{T}, ptr::Ptr, off::Integer) where {T} =
    _peek(T, ptr + off)

@inline _poke!(ptr::Ptr{T}, val) where {T} =
    unsafe_store!(ptr, val)
@inline _poke!(::Type{T}, ptr::Ptr, val) where {T} =
    _poke!(convert(Ptr{T}, ptr), val)
@inline _poke!(::Type{T}, ptr::Ptr, off::Integer, val) where {T} =
    _poke!(T, ptr + off, val)
