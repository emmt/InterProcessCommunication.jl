#
# wrappedarrays.jl --
#
# Management of object wrapped into Julia arrays.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

"""
```julia
WrappedArray(mem, [T [, dims...]]; offset=0)
```

yields a Julia array whose elements are stored in the "memory" object `mem`.
Argument `T` is the data type of the elements of the returned array and
argument(s) `dims` specify the dimensions of the array.  If `dims` is omitted
the result is a vector of maximal length (accounting for the offset and the
size of the `mem` object).  If `T` is omitted, `UInt8` is assumed.

Keyword `offset` may be used to specify the address (in bytes) relative to
`pointer(mem)` where is stored the first element of the array.

The size of the memory provided by `mem` must be sufficient to store all
elements (accounting for the offset) and the alignment of the elements in
memory must be a multiple of `Base.datatype_alignment(T)`.

Another possibility is:

```julia
WrappedArray(mem, dec)
```

where `mem` is the "memory" object and `dec` is a function in charge of
decoding the array type and layout given the memory object.  The decoder is
applied to the memory object as follow:

```julia
dec(mem) -> T, dims, offset
```

which must yield the data type `T` of the array elements, the dimensions `dims`
of the array and the offset of the first element relative to `pointer(mem)`.


## Restrictions

The `mem` object must extend the methods `pointer(mem)` and `sizeof(mem)` which
must respectively yield the base address of the memory provided by `mem` and the
number of available bytes.  Furthermore, this memory is assumed to be available
at least until object `mem` is reclaimed by the garbage collector.


## See Also

[`pointer`](@ref), [`sizeof`](@ref), [`Base.datatype_alignment`](@ref).

"""
function WrappedArray(mem::M, ::Type{T} = UInt8;
                      offset::Integer = 0)::WrappedArray{T,1,M} where {M,T}
    ptr, siz = _check_wrap_array_arguments(mem, T, offset)
    siz ≥ sizeof(T) ||
        throw(ArgumentError("insufficient memory for at least one element"))
    number = div(siz, sizeof(T))
    return WrappedArray{T,1,M}(ptr, (number,), mem)
end

WrappedArray(mem::M, ::Type{T}, dims::Integer...; kwds...) where {M,T} =
    WrappedArray(mem, T, dims; kwds...)

function WrappedArray(mem::M, ::Type{T}, dims::NTuple{N,<:Integer};
                      offset::Integer = 0)::WrappedArray{T,N,M} where {T,N,M}
    ptr, siz = _check_wrap_array_arguments(mem, T, offset)
    number = checkdims(dims)
    siz ≥ sizeof(T)*number ||
        throw(ArgumentError("insufficient memory for array"))
    return WrappedArray{T,N,M}(ptr, dims, mem)
end

function WrappedArray(mem, dec::Function)
    T, dims, offset = dec(mem)
    isa(T, DataType) || error("`dec(mem)[1]` must be a data type")
    isa(dims, Tuple{Vararg{<:Integer}}) ||
        error("`dec(mem)[2]` must be a tuple of dimensions")
    isa(offset, Integer) || error("`dec(mem)[3]` must be an integer")
    return WrappedArray(mem, T, dims; offset = offset)
end

function _check_wrap_array_arguments(mem::M, ::Type{T},
                                     offset::Integer) where {M,T}
    offset ≥ 0 || throw(ArgumentError("offset must be nonnegative"))
    isbits(T) || throw(ArgumentError("illegal element type ($T)"))
    ptr = pointer(mem)
    isa(ptr, Ptr) ||
        throw(ArgumentError("illegal type returned by `pointer(mem)` ($(typeof(ptr)))"))
    align = Base.datatype_alignment(T)
    addr = ptr + offset
    rem(convert(Int, addr), align) == 0 ||
        throw(ArgumentError("base address must be a multiple of $align bytes"))
    len = sizeof(mem)
    isa(len, Integer) ||
        throw(ArgumentError("illegal type returned by `sizeof(mem)` ($(typeof(len)))"))
    len ≥ 0 ||
        throw(ArgumentError("invalid value returned by `sizeof(mem)` ($len)"))
    return (convert(Ptr{T}, addr),
            convert(Int, len) - convert(Int, offset))
end

# FIXME: push!, pop!, append!, resize! cannot be extended for WrappedVectors
# unless it is possible to query the size of the memory object, in fact many
# things are doable if the address and size of memory object can be retrieved.
# However, push!, append!, resize!, ... would require to rewrap the buffer.

# The following methods come for free (with no performance penalties) because a
# WrappedArray is a subtype of DenseArray:
#
#    Base.eltype, Base.elsize, Base.ndims, Base.first, Base.endof,
#    Base.eachindex, ...

# FIXME: extend Base.view?

Base.length(obj::WrappedArray) = length(obj.arr)

Base.sizeof(obj::WrappedArray) = sizeof(obj.arr)

Base.size(obj::WrappedArray) = size(obj.arr)

Base.size(obj::WrappedArray, d::Number) = size(obj.arr, d)

Base.getindex(obj::WrappedArray, i) = getindex(obj.arr, i)

Base.getindex(obj::WrappedArray, i, inds...) = getindex(obj.arr, i, inds...)

Base.setindex!(obj::WrappedArray, value, i) = setindex!(obj.arr, value, i)

Base.setindex!(obj::WrappedArray, value, i, inds...) =
    setindex!(obj.arr, value, i, inds...)

Base.eachindex(obj::WrappedArray) = eachindex(obj.arr)

Base.IndexStyle(::Type{<:WrappedArray}) = Base.IndexLinear()

Base.stride(obj::WrappedArray, d::Integer) = stride(obj.arr, d)

Base.strides(obj::WrappedArray) = strides(obj.arr)

Base.copy(obj::WrappedArray) = copy(obj.arr)

Base.copy!(dest::WrappedArray, src::AbstractArray) =
    (copy!(dest.arr, src); dest)

Base.reinterpret(::Type{T}, obj::WrappedArray) where {T} =
    reinterpret(T, obj.arr)

Base.reshape(obj::WrappedArray, dims::Tuple{Vararg{Int}}) =
    reshape(obj.arr, dims)

# Extend `Base.unsafe_convert` for `ccall`.  Note that this also make `pointer`
# applicable and that the 2 following definitions are needed to avoid
# ambiguities and cover all cases.
unsafe_convert(::Type{Ptr{T}}, obj::WrappedArray{T}) where {T} =
    unsafe_convert(Ptr{T}, obj.arr)
unsafe_convert(::Type{Ptr{S}}, obj::WrappedArray{T}) where {S,T} =
    unsafe_convert(Ptr{S}, obj.arr)

# Make a wrapped array iterable:
Base.start(iter::WrappedArray) = start(iter.arr)
Base.next(iter::WrappedArray, state) = next(iter.arr, state)
Base.done(iter::WrappedArray, state) = done(iter.arr, state)

