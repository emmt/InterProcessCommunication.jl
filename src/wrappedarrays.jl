#
# wrappedarrays.jl --
#
# Management of object wrapped into Julia arrays.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/IPC.jl).
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


## Shared Memory Arrays

```julia
WrappedArray(id, T, dims; perms=0o600, volatile=true)
```

creates a new wrapped array whose elements (and a header) are stored in shared
memory identified by `id` (see [`SharedMemory`](@ref) for a description of `id`
and for keywords).  To retrieve this array in another process, just do:

```julia
WrappedArray(id; readonly=false)
```


## See Also

[`pointer`](@ref), [`sizeof`](@ref), [`Base.datatype_alignment`](@ref),
[`SharedMemory`](@ref).

"""
function WrappedArray(mem::M, ::Type{T} = UInt8;
                      offset::Integer = 0) where {M,T}
    ptr, siz = _check_wrapped_array_arguments(mem, T, offset)
    siz ≥ sizeof(T) ||
        throw_argument_error("insufficient memory for at least one element")
    number = div(siz, sizeof(T))
    return WrappedArray{T,1,M}(ptr, (number,), mem)
end

WrappedArray(mem::M, ::Type{T}, dims::Integer...; kwds...) where {M,T} =
    WrappedArray(mem, T, dims; kwds...)

function WrappedArray(mem::M, ::Type{T}, dims::NTuple{N,Integer};
                      offset::Integer = 0) where {T,N,M}
    ptr, siz = _check_wrapped_array_arguments(mem, T, offset)
    number = checkdims(dims)
    siz ≥ sizeof(T)*number ||
        throw_argument_error("insufficient memory for array")
    return WrappedArray{T,N,M}(ptr, dims, mem)
end

function WrappedArray(mem, dec::Function)
    T, dims, offset = dec(mem)
    isa(T, DataType) || error("`dec(mem)[1]` must be a data type")
    isa(dims, Tuple{Vararg{Integer}}) ||
        error("`dec(mem)[2]` must be a tuple of dimensions")
    isa(offset, Integer) || error("`dec(mem)[3]` must be an integer")
    return WrappedArray(mem, T, dims; offset = offset)
end

function WrappedArray(id::Union{AbstractString,ShmId,Key},
                      ::Type{T}, dims::Vararg{Integer,N}; kwds...) where {T,N}
    return WrappedArray(id, T, convert(NTuple{N,Int}, dims); kwds...)
end

function WrappedArray(id::Union{AbstractString,ShmId,Key},
                      ::Type{T}, dims::NTuple{N,Integer}; kwds...) where {T,N}
    return WrappedArray(id, T, convert(NTuple{N,Int}, dims); kwds...)
end

function WrappedArray(id::Union{AbstractString,ShmId,Key},
                      ::Type{T}, dims::NTuple{N,Int};
                      kwds...) where {T,N}
    num = checkdims(dims)
    off = _wrapped_array_header_size(N)
    siz = off + sizeof(T)*num
    mem = SharedMemory(id, siz; kwds...)
    write(mem, WrappedArrayHeader, T, dims)
    return WrappedArray(mem, T, dims; offset=off)
end

function WrappedArray(id::Union{AbstractString,ShmId,Key}; kwds...)
    mem = SharedMemory(id; kwds...)
    T, dims, off = read(mem, WrappedArrayHeader)
    return WrappedArray(mem, T, dims; offset=off)
end

function _check_wrapped_array_arguments(mem::M, ::Type{T},
                                        offset::Integer) where {M,T}
    offset ≥ 0 || throw_argument_error("offset must be nonnegative")
    isbitstype(T) || throw_argument_error("illegal element type (", T, ")")
    ptr, len = get_memory_parameters(mem)
    align = Base.datatype_alignment(T)
    addr = ptr + offset
    rem(convert(Int, addr), align) == 0 ||
        throw_argument_error("base address must be a multiple of ",
                             align, " bytes")
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

@inline Base.parent(obj::WrappedArray) = obj.arr

Base.length(obj::WrappedArray) = length(parent(obj))
Base.sizeof(obj::WrappedArray) = sizeof(parent(obj))
Base.size(obj::WrappedArray) = size(parent(obj))
Base.size(obj::WrappedArray, d::Integer) = size(parent(obj), d)
Base.axes(obj::WrappedArray) = axes(parent(obj))
Base.axes(obj::WrappedArray, d::Integer) = axes(parent(obj), d)
@inline Base.axes1(obj::WrappedArray) = Base.axes1(parent(obj))
Base.strides(obj::WrappedArray) = strides(parent(obj))
Base.stride(obj::WrappedArray, d::Integer) = stride(parent(obj), d)
Base.elsize(::Type{WrappedArray{T,N,M}}) where {T,N,M} = elsize(Array{T,N})

Base.IndexStyle(::Type{<:WrappedArray}) = Base.IndexLinear()

@inline @propagate_inbounds Base.getindex(obj::WrappedArray, i::Int) =
    (@boundscheck checkbounds(obj, i);
     @inbounds getindex(parent(obj), i))

@inline @propagate_inbounds Base.setindex!(obj::WrappedArray, x, i::Int) =
    (@boundscheck checkbounds(obj, i);
     @inbounds setindex!(parent(obj), x, i))

@inline Base.checkbounds(::Type{Bool}, obj::WrappedArray, i::Int) =
    (i % UInt) - 1 < length(obj)

Base.copy(obj::WrappedArray) = copy(parent(obj))

Base.copyto!(dest::WrappedArray, src::AbstractArray) =
    (copyto!(dest.arr, src); dest)

Base.reinterpret(::Type{T}, obj::WrappedArray) where {T} =
    reinterpret(T, parent(obj))

Base.reshape(obj::WrappedArray, dims::Tuple{Vararg{Int}}) =
    reshape(parent(obj), dims)

# Extend `Base.unsafe_convert` for `ccall`.  Note that this also make `pointer`
# applicable and that the 2 following definitions are needed to avoid
# ambiguities and cover all cases.
unsafe_convert(::Type{Ptr{T}}, obj::WrappedArray{T}) where {T} =
    unsafe_convert(Ptr{T}, parent(obj))
unsafe_convert(::Type{Ptr{S}}, obj::WrappedArray{T}) where {S,T} =
    unsafe_convert(Ptr{S}, parent(obj))

# Make a wrapped array iterable:
@static if isdefined(Base, :iterate) # VERSION ≥ v"0.7-alpha"
    Base.iterate(iter::WrappedArray) = iterate(iter.arr)
    Base.iterate(iter::WrappedArray, state) = iterate(iter.arr, state)
    Base.IteratorSize(iter::WrappedArray) = Base.IteratorSize(iter.arr)
    Base.IteratorEltype(iter::WrappedArray) = Base.IteratorEltype(iter.arr)
else
    Base.start(iter::WrappedArray) = start(iter.arr)
    Base.next(iter::WrappedArray, state) = next(iter.arr, state)
    Base.done(iter::WrappedArray, state) = done(iter.arr, state)
    Base.iteratorsize(iter::WrappedArray) = Base.iteratorsize(iter.arr)
    Base.iteratoreltype(iter::WrappedArray) = Base.iteratoreltype(iter.arr)
end

#------------------------------------------------------------------------------
# WRAPPED ARRAYS WITH HEADER

# Magic number
const _WA_MAGIC = UInt32(0x57412D31) # "WA-1" = Wrapped Array version 1

# We require at least 64 bytes (512 bits) alignment for the first element of
# the array (to warrant that SIMD vectors are correctly aligned), this value is
# equal to the constant JL_CACHE_BYTE_ALIGNMENT used for the elements of Julia
# arrays.
const _WA_ALIGN = 64

const _WA_TYPES = (( 1, Int8,       "signed 8-bit integer"),
                   ( 2, UInt8,      "unsigned 8-bit integer"),
                   ( 3, Int16,      "signed 16-bit integer"),
                   ( 4, UInt16,     "unsigned 16-bit integer"),
                   ( 5, Int32,      "signed 32-bit integer"),
                   ( 6, UInt32,     "unsigned 32-bit integer"),
                   ( 7, Int64,      "signed 64-bit integer"),
                   ( 8, UInt64,     "unsigned 64-bit integer"),
                   ( 9, Float32,    "32-bit floating-point"),
                   (10, Float64,    "64-bit floating-point"),
                   (11, ComplexF32,  "64-bit complex"),
                   (12, ComplexF64, "128-bit complex"))

const _WA_ETYPES = DataType[T for (i, T, str) in _WA_TYPES]
const _WA_DESCRS = String[str for (i, T, str) in _WA_TYPES]
const _WA_IDENTS = Dict(T => i for (i, T, str) in _WA_TYPES)


"""
```julia
WrappedArrayHeader(T, N)
```

yields a structure `WrappedArrayHeader` instanciated for an array with `N`
dimensions and whose element type is `T`.


## Possible Usages

```julia
read(src, WrappedArrayHeader) -> T, dims, off
```

reads wrapped array header in `src` and yields the element type `T`, dimensions
`dims` and offset `off` of the first array element relative to the the base of
`src`.

```julia
write(dst, WrappedArrayHeader, T, dims)
```

writes wrapped array header in `dst` for element type `T` and dimensions
`dims`.


```julia
WrappedArray(mem, x -> read(x, WrappedArrayHeader)) -> arr
```

retrieves a wrapped array `arr` whose header and elements are stored in the
memory provided by object `mem`.

"""
function WrappedArrayHeader(::Type{T}, N::Int) where {T}
    N ≥ 1 || throw_argument_error("illegal number of dimensions (", N, ")")
    haskey(_WA_IDENTS, T) || throw_argument_error("unsupported data type (",
                                                  T, ")")
    off = _wrapped_array_header_size(N)
    return WrappedArrayHeader(_WA_MAGIC, _WA_IDENTS[T], N, off)
end

_wrapped_array_header_size(N::Integer) =
    roundup(sizeof(WrappedArrayHeader) + N*sizeof(Int64), _WA_ALIGN)

WrappedArrayHeader(::Type{T}, N::Integer) where {T} =
    WrappedArrayHeader(T, convert(Int, N))

function Base.write(mem, ::Type{WrappedArrayHeader},
                    ::Type{T}, dims::Vararg{<:Integer,N}) where {T,N}
    write(mem, WrappedArrayHeader, T, convert(NTuple{N,Int}, dims))
end

function Base.write(mem, ::Type{WrappedArrayHeader},
                    ::Type{T}, dims::NTuple{N,<:Integer}) where {T,N}
    write(mem, WrappedArrayHeader, T, convert(NTuple{N,Int}, dims))
end

function Base.write(mem, ::Type{WrappedArrayHeader},
                    ::Type{T}, dims::NTuple{N,Int}) where {T,N}
    # Check arguments, then write header and dimensions.
    hdr = WrappedArrayHeader(T, N)
    off = hdr.offset
    ptr, siz = get_memory_parameters(mem)
    num = checkdims(dims)
    siz ≥ off + sizeof(T)*num ||
        throw_argument_error("insufficient size of memory block")
    unsafe_store!(convert(Ptr{WrappedArrayHeader}, ptr), hdr)
    addr = convert(Ptr{Int64}, ptr + sizeof(WrappedArrayHeader))
    for i in 1:N
        unsafe_store!(addr, dims[i], i)
    end
end

function Base.read(mem, ::Type{WrappedArrayHeader})
    ptr, siz = get_memory_parameters(mem)
    siz ≥ sizeof(WrappedArrayHeader) ||
        throw_argument_error("insufficient size of memory block for header")
    hdr = unsafe_load(convert(Ptr{WrappedArrayHeader}, ptr))
    hdr.magic == _WA_MAGIC ||
        throw_error_exception("invalid magic number (0x",
                              string(hdr.magic, base=16), ")")
    etype = Int(hdr.etype)
    1 ≤ etype ≤ length(_WA_ETYPES) ||
        throw_error_exception("invalid element type identifier (", etype, ")")
    ndims = Int(hdr.ndims)
    1 ≤ ndims ||
        throw_error_exception("invalid number of dimensions (", ndims, ")")
    off = Int(hdr.offset)
    off == _wrapped_array_header_size(ndims) ||
        throw_error_exception("invalid offset (", off, ")")
    addr = convert(Ptr{Int64}, ptr + sizeof(WrappedArrayHeader))
    dims = ntuple(i -> convert(Int, unsafe_load(addr, i)), ndims)
    num = checkdims(dims)
    T = _WA_ETYPES[etype]
    siz ≥ off + sizeof(T)*num ||
        throw_error_exception("insufficient size of memory block (", Int(siz),
                              " < ", Int(off + sizeof(T)*num), ")")
    return T, dims, off
end
