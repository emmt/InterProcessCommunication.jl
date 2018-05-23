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

Base.pointer(obj::WrappedArray) = pointer(obj.arr)

Base.reinterpret(::Type{T}, obj::WrappedArray) where {T} =
    reinterpret(T, obj.arr)

Base.reshape(obj::WrappedArray, dims::Tuple{Vararg{Int}}) =
    reshape(obj.arr, dims)

# Make a wrapped array iterable:
Base.start(iter::WrappedArray) = start(iter.arr)
Base.next(iter::WrappedArray, state) = next(iter.arr, state)
Base.done(iter::WrappedArray, state) = done(iter.arr, state)
