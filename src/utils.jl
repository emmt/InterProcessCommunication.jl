#
# utils.jl --
#
# Useful methods and constants for InterProcessCommunication (IPC) package of
# Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of InterProcessCommunication.jl released under the MIT
# "expat" license.
#
# Copyright (C) 2016-2019, Éric Thiébaut
# (https://github.com/emmt/InterProcessCommunication.jl).
#

# A bit of magic for calling C-code:
Base.convert(::Type{_typeof_key_t}, key::Key) = key.value
Base.convert(::Type{T}, key::Key) where {T<:Integer} = convert(T, key.value)

# The short version of `show` if also used for string interpolation in
# scripts so that extending methods:
#     Base.convert(::Type{String}, obj::T)
#     Base.string(obj::T)
# is not necessary.
Base.show(io::IO, ::MIME"text/plain", arg::Key) = show(io, arg)
Base.show(io::IO, key::Key) =
    print(io, "IPC.Key(", string(key.value, base=10), ")")

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
    1 ≤ proj ≤ 255 || throw_argument_error("`proj` must be in the range 1:255")
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
    ccall(:gettimeofday, Cint, (Ptr{TimeVal}, Ptr{Cvoid}), tv, C_NULL)
    return tv[]
end

"""

```julia
now(T)
```

yields the current time since the Epoch as an instance of type `T`, which can
be [`TimeVal`](@ref) or [`TimeSpec`](@ref).

See also: [`gettimeofday`](@ref),  [`clock_gettime`](@ref).

"""
now(::Type{TimeVal}) = gettimeofday()
now(::Type{TimeSpec}) = clock_gettime(CLOCK_REALTIME)

"""

```julia
nanosleep(t) -> rem
```

sleeps for `t` seconds with nanosecond precision and returns the remaining time
(in case of interrupts) as an instance of `IPC.TimeSpec`.  Argument can be a
(fractional) number of seconds or an instance of `IPC.TimeSpec` or
`IPC.TimeVal`.

The `sleep` method provided by Julia has only millisecond precision.

See also [`gettimeofday`](@ref), [`IPC.TimeSpec`](@ref) and
[`IPC.TimeVal`](@ref).

"""
nanosleep(t::Union{Real,TimeVal,Libc.TimeVal}) = nanosleep(TimeSpec(t))

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

See also [`clock_gettime`](@ref), [`clock_settime`](@ref),
[`gettimeofday`](@ref), [`nanosleep`](@ref), [`IPC.TimeSpec`](@ref) and
[`IPC.TimeVal`](@ref).

""" clock_getres

@static if Sys.islinux()
    function clock_getres(id::Integer)
        res = Ref(TimeSpec(0,0))
        systemerror("clock_getres",
                    ccall(:clock_getres, Cint,
                          (_typeof_clockid_t, Ptr{TimeSpec}),
                          id, res) != SUCCESS)
        return res[]
    end
else
    # Assume the same resolution as gettimeofday which is used as a substitute
    # to clock_gettime.
    clock_getres(id::Integer) = TimeSpec(0, 1_000)
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

See also [`clock_getres`](@ref), [`clock_settime`](@ref),
[`gettimeofday`](@ref), [`nanosleep`](@ref), [`IPC.TimeSpec`](@ref) and
[`IPC.TimeVal`](@ref).

""" clock_gettime

@static if Sys.islinux()
    function clock_gettime(id::Integer)
        ts = Ref(TimeSpec(0,0))
        systemerror("clock_gettime",
                    ccall(:clock_gettime, Cint,
                          (_typeof_clockid_t, Ptr{TimeSpec}),
                          id, ts) != SUCCESS)
        return ts[]
    end
else
    # Use clock_gettime as a substitute.
    clock_gettime(id::Integer) = TimeSpec(gettimeofday())
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

See also [`clock_getres`](@ref), [`clock_gettime`](@ref),
[`gettimeofday`](@ref), [`nanosleep`](@ref), [`IPC.TimeSpec`](@ref) and
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
"""

```julia
TimeSpec(sec, nsec)
```

yields an instance of `TimeSpec` for an integer number of seconds `sec` and an
integer number of nanoseconds `nsec` since the Epoch.

```julia
TimeSpec(sec)
```

yields an instance of `TimeSpec` for a, possibly fractional, number of seconds
`sec` since the Epoch.  Argument can also be an instance of [`TimeVal`](@ref).

Call `now(TimeSpec)` to get the current time as an instance of `TimeSpec`.

Addition and subtraction involving and instance of `TimeSpec` yield a
`TimeSpec` result.  For instance:

```julia
now(TimeSpec) + 3.4
```

yields a `TimeSpec` instance with the current time plus `3.4` seconds.

"""
TimeSpec(ts::TimeSpec) = ts
TimeSpec(secs::Integer) = TimeSpec(secs, 0)
TimeSpec(secs::Real) = TimeSpec(_splittime(secs, _time_t(1_000_000_000))...)
TimeSpec(tv::Union{TimeVal,Libc.TimeVal}) =
    _fixtime(TimeSpec, tv.sec, tv.usec*_time_t(1_000))

"""

```julia
TimeVal(sec, usec)
```

yields an instance of `TimeVal` for an integer number of seconds `sec` and an
integer number of microseconds `usec` since the Epoch.

```julia
TimeVal(sec)
```

yields an instance of `TimeVal` with a, possibly fractional, number of seconds
`sec` since the Epoch.  Argument can also be an instance of [`TimeSpec`](@ref).

Call `now(TimeVal)` to get the current time as an instance of `TimeVal`.

Addition and subtraction involving and instance of `TimeVal` yield a
`TimeVal` result.  For instance:

```julia
now(TimeVal) + 3.4
```

yields a `TimeVal` instance with the current time plus `3.4` seconds.

"""
TimeVal(tv::TimeVal) = tv
TimeVal(tv::Libc.TimeVal) = TimeVal(tv.sec, tv.usec)
TimeVal(secs::Integer) = TimeVal(secs, 0)
TimeVal(secs::Real) = TimeVal(_splittime(secs, _time_t(1_000_000))...)
TimeVal(ts::TimeSpec) = _fixtime(TimeVal, ts.sec, round(_time_t, 1e-3*ts.nsec))

_time_t(x::Integer) = convert(_typeof_time_t, x)
_time_t(x::Real) = round(_typeof_time_t, x)

Base.Float32(t::Union{TimeVal,TimeSpec}) = convert(Float32, t)
Base.Float64(t::Union{TimeVal,TimeSpec}) = convert(Float64, t)
Base.float(t::Union{TimeVal,TimeSpec}) = convert(Float64, t)
Base.convert(::Type{T}, tv::TimeVal) where {T<:AbstractFloat} =
    T(tv.sec + tv.usec//_time_t(1_000_000))
Base.convert(::Type{T}, ts::TimeSpec) where {T<:AbstractFloat} =
    T(ts.sec + ts.nsec//_time_t(1_000_000_000))
Base.convert(::Type{TimeSpec}, arg::Union{Real,TimeSpec,TimeVal,Libc.TimeVal}) =
    TimeSpec(arg)
Base.convert(::Type{TimeVal}, arg::Union{Real,TimeSpec,TimeVal,Libc.TimeVal}) =
    TimeVal(arg)

function _splittime(secs::Real, mlt::_typeof_time_t)
    s = floor(secs)
    ip = _time_t(s)
    fp = _time_t((secs - s)*mlt)
    if fp ≥ mlt
        fp -= mlt
        ip += one(_typeof_time_t)
    end
    return (ip, fp)
end

function _fixtime(ip::_typeof_time_t, fp::_typeof_time_t, mlt::_typeof_time_t)
    ip += div(fp, mlt)
    fp = rem(fp, mlt)
    if ip < 0
        ip += mtl
        fp -= one(_typeof_time_t)
    end
    return (ip, fp)
end

_fixtime(::Type{TimeSpec}, ip::_typeof_time_t, fp::_typeof_time_t) =
    TimeSpec(_fixtime(ip, fp, _time_t(1_000_000_000))...)

_fixtime(::Type{TimeVal}, ip::_typeof_time_t, fp::_typeof_time_t) =
    TimeVal(_fixtime(ip, fp, _time_t(1_000_000))...)

#
# Extend addition and subtraction for time structures.
#
Base.:(+)(a::TimeSpec, b::TimeSpec) =
    _fixtime(TimeSpec, a.sec + b.sec, a.nsec + b.nsec)
Base.:(-)(a::TimeSpec, b::TimeSpec) =
    _fixtime(TimeSpec, a.sec - b.sec, a.nsec - b.nsec)
Base.:(+)(a::TimeSpec, b::Union{Real,TimeVal,Libc.TimeVal}) = a + TimeSpec(b)
Base.:(-)(a::TimeSpec, b::Union{Real,TimeVal,Libc.TimeVal}) = a - TimeSpec(b)
Base.:(+)(a::Union{Real,TimeVal,Libc.TimeVal}, b::TimeSpec) = TimeSpec(a) + b
Base.:(-)(a::Union{Real,TimeVal,Libc.TimeVal}, b::TimeSpec) = TimeSpec(a) - b

Base.:(+)(a::TimeVal, b::TimeVal) =
    _fixtime(TimeVal, a.sec + b.sec, a.usec + b.usec)
Base.:(-)(a::TimeVal, b::TimeVal) =
    _fixtime(TimeVal, a.sec - b.sec, a.usec - b.usec)
Base.:(+)(a::TimeVal, b::Union{Real,Libc.TimeVal}) = a + TimeVal(b)
Base.:(-)(a::TimeVal, b::Union{Real,Libc.TimeVal}) = a - TimeVal(b)
Base.:(+)(a::Union{Real,Libc.TimeVal}, b::TimeVal) = TimeVal(a) + b
Base.:(-)(a::Union{Real,Libc.TimeVal}, b::TimeVal) = TimeVal(a) - b

# FIXME: unused
syserrmsg(msg::AbstractString, code::Integer=Libc.errno()) =
    string(msg," [",Libc.strerror(code),"]")

"""
```julia
error_message(args...)
```

yields a message string built from `args...`.  This string is meant to be used
as an error message.  The only difference between `string(args...)` and
`error_message(args...)` is that the latter is not inlined if the result has to
be dynamically created.  This is to avoid the caller function not being inlined
because the formatting of the error message involves too many operations.

See also  [`throw_argument_error`](@ref), [`throw_error_exception`](@ref).

"""
error_message(mesg::String) = mesg
@noinline error_message(args...) = string(args...)

"""
```julia
throw_argument_error(args...)
```

throws an `ArgumentError` exception with message built from `args...`.

See also [`error_message`](@ref), [`throw_error_exception`](@ref),
[`throw_system_error`](@ref).

"""
throw_argument_error(args...) = throw_argument_error(error_message(args...))

"""
```julia
throw_error_exception(args...)
```

throws an `ErrorException` with message built from `args...`.

See also [`error_message`](@ref), [`throw_argument_error`](@ref),
[`throw_system_error`](@ref).

"""
throw_error_exception(args...) = throw_error_exception(error_message(args...))

"""
```julia
throw_system_error(mesg, errno=Libc.errno())
```

throws an `SystemError` exception corresponding to error code number `errno`.
If `errno` is not specified the current value of the global `errno` variable in
the C library is used.

See also [`throw_argument_error`](@ref), [`throw_error_exception`](@ref).

"""
throw_system_error(mesg::AbstractString, errno::Integer = Libc.errno()) =
    throw(SystemError(mesg, errno))

makedims(dims::Tuple{Vararg{Int}}) = dims
makedims(dims::Tuple{Vararg{Integer}}) = map(Int, dims)
makedims(dims::AbstractVector{<:Integer}) = # FIXME: bad idea!
    ntuple(i -> Int(dims[i]), length(dims))

function checkdims(dims::NTuple{N,Integer}) where {N}
    number = one(Int)
    for i in 1:N
        dims[i] ≥ 1 || throw_error_exception("invalid dimension (dims[", i,
                                             "] = ", dims[i], ")")
        number *= convert(Int, dims[i])
    end
    return number
end

roundup(a::Integer, b::Integer) =
    roundup(convert(Int, a), convert(Int, b))

roundup(a::Int, b::Int) =
    div(a + (b - 1), b)*b

"""
```julia
get_memory_parameters(mem) -> ptr::Ptr{Cvoid}, siz::Int
```

yields the address and number of bytes of memory backed by `mem`.
The returned values arec checked for correctness.

See also: [`pointer`](@ref), [`sizeof`](@ref).

"""
function get_memory_parameters(mem)::Tuple{Ptr{Cvoid},Int}
    siz = sizeof(mem)
    isa(siz, Integer) || throw_argument_error("illegal type `", typeof(siz),
                                              "` for `sizeof(mem)`")
    siz ≥ 0 || throw_argument_error("invalid value `", siz,
                                    "` for `sizeof(mem)`")
    ptr = pointer(mem)
    isa(ptr, Ptr) || throw_argument_error("illegal type `", typeof(ptr),
                                          "` for `pointer(mem)`")
    return (convert(Ptr{Cvoid}, ptr), convert(Int, siz))
end

"""
```julia
_peek(T, buf, off) -> val
```

yields the value of type `T` stored at offset `off` (in bytes) in buffer
`buf` provided as a vector of bytes (`Uint8`).

```julia
_peek(T, ptr) -> val
```

yields the value of type `T` stored at address given by pointer `ptr`.

Also see: [`unsafe_load`](@ref), [`_poke!`](@ref).

"""
@inline _peek(::Type{T}, ptr::Ptr) where {T} =
    unsafe_load(convert(Ptr{T}, ptr))
@inline _peek(::Type{T}, buf::DenseVector{UInt8}, off::Integer) where {T} =
    _peek(T, pointer(buf) + off)

"""
```julia
_poke!(T, buf, off, val)
```

stores the value `val`, converted to type `T`, at offset `off` (in bytes) in
buffer `buf` provided as a vector of bytes (`Uint8`).

```julia
_poke!(T, ptr, val)
```

stores the value `val`, converted to type `T`, at address given by pointer
`ptr`.

Also see: [`unsafe_store!`](@ref), [`_peek`](@ref).

"""
@inline _poke!(::Type{T}, ptr::Ptr, val) where {T} =
    unsafe_store!(convert(Ptr{T}, ptr), val)
@inline _poke!(::Type{T}, buf::DenseVector{UInt8}, off::Integer, val) where {T} =
    _poke!(T, pointer(buf) + off, val)

#------------------------------------------------------------------------------
# DYNAMIC MEMORY OBJECTS

function _destroy(obj::DynamicMemory)
    if (ptr = obj.ptr) != C_NULL
        obj.len = 0
        obj.ptr = C_NULL
        Libc.free(ptr)
    end
end

Base.sizeof(obj::DynamicMemory) = obj.len
Base.pointer(obj::DynamicMemory) = obj.ptr
Base.convert(::Type{Ptr{Cvoid}}, obj::DynamicMemory) = obj.ptr
Base.convert(::Type{Ptr{T}}, obj::DynamicMemory) where {T} =
    convert(Ptr{T}, obj.ptr)
Base.unsafe_convert(::Type{Ptr{T}}, obj::DynamicMemory) where {T} =
    convert(Ptr{T}, obj.ptr)
