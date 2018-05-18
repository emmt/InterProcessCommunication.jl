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
Base.convert(::Type{T}, ipckey::Key) where {T<:Integer} =
    convert(T, ipckey.value)
Base.convert(::Type{String}, key::Key) = string(key)

Base.string(key::Key) = dec(key.value)
Base.show(io::IO, key::Key) = (write(io, "IPC.Key: ", dec(key.value)); nothing)


"""

`IPC_NEW` is a special IPC key (of type `IPC.Key`) which indicates that a new
key should be created.

"""
const IPC_NEW = Key(IPC_PRIVATE)

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

The special IPC key [`IPC_NEW`](@ref) is also available to indicate that a new
key should be created.
"""
function Key(path::AbstractString, proj::Char)
    isascii(proj) || throw(ArgumentError("`proj` must be an ASCII character"))
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

See also: [`IPC.TimeVal`](@ref), [`nanosleep`](@ref).

"""
function gettimeofday()
    ref = Ref(TimeVal(0, 0))
    # `gettimeofday` should not fail in this case
    ccall(:gettimeofday, Cint, (Ptr{TimeVal}, Ptr{Void}), ref, C_NULL)
    return ref[]
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
    rem = Ref(TimeSpec(0, 0))
    ccall(:nanosleep, Cint, (Ptr{TimeSpec}, Ptr{TimeSpec}), Ref(ts), rem)
    return rem[]
end

Base.float(tv::TimeVal) = tv.tv_sec + tv.tv_usec/1_000_000

Base.float(ts::TimeSpec) = ts.tv_sec + ts.tv_nsec/1_000_000_000

Base.convert(::Type{T}, tv::TimeVal) where {T<:AbstractFloat} =
    convert(T, tv.tv_sec + tv.tv_usec*convert(T, 1E-6))

Base.convert(::Type{T}, ts::TimeSpec) where {T<:AbstractFloat} =
    convert(T, ts.tv_sec + ts.tv_nsec*convert(T, 1E-9))

# FIXME: rounding may yield tv_usec = 1E6 or tv_nsec = 1E9
# FIXME: floor or trunc?
Base.convert(::Type{TimeVal}, sec::T) where {T<:AbstractFloat} =
    TimeVal(trunc(_typeof_tv_sec, sec),
            round(_typeof_tv_usec,
                  (sec - trunc(sec))*convert(T, 1_000_000)))

Base.convert(::Type{TimeSpec}, sec::T) where {T<:AbstractFloat} =
    TimeSpec(trunc(_typeof_tv_sec, sec),
             round(_typeof_tv_nsec,
                   (sec - trunc(sec))*convert(T, 1_000_000_000)))

Base.convert(::Type{TimeVal}, sec::Integer) = TimeVal(sec, 0)

Base.convert(::Type{TimeSpec}, sec::Integer) = TimeSpec(sec, 0)

Base.convert(::Type{TimeSpec}, tv::TimeVal) =
    TimeSpec(tv.tv_sec, 1_000*tv.tv_usec)

Base.convert(::Type{TimeVal}, ts::TimeSpec) =
    TimeVal(ts.tv_sec, round(_typeof_tv_usec, ts.ts_nsec/1_000))

syserrmsg(msg::AbstractString, code::Integer=Libc.errno()) =
    string(msg," [",Libc.strerror(code),"]")

makedims(dims::NTuple{N,Int}) where {N} = dims
makedims(dims::NTuple{N,Integer}) where {N} =
    ntuple(i -> Int(dims[i]), N)
makedims(dims::AbstractVector{<:Integer}) =
    ntuple(i -> Int(dims[i]), length(dims))

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

