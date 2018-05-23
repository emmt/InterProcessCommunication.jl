module IPCTests

using IPC

@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

mutable struct DynamicMemory
    ptr::Ptr{Void}
    len::Int
    function DynamicMemory(len::Integer)
        @assert len ≥ 1
        ptr = Libc.malloc(len)
        ptr != C_NULL || throw(OutOfMemoryError())
        obj = new(ptr, len)
        finalizer(obj, _destroy)
        return obj
    end
end

function _destroy(obj::DynamicMemory)
    if (ptr = obj.ptr) != C_NULL
        obj.len = 0
        obj.ptr = C_NULL
        Libc.free(ptr)
    end
end

Base.sizeof(obj::DynamicMemory) = obj.len
Base.convert(::Type{P}, obj::DynamicMemory) where {P<:Ptr} =
    convert(P, obj.ptr)
Base.unsafe_convert(::Type{P}, obj::DynamicMemory) where {P<:Ptr} =
    unsafe_convert(P, obj.ptr)
Base.pointer(obj::DynamicMemory) = obj.ptr

function IPC.WrappedArray(buf::DynamicMemory, ::Type{T},
                          dims::Union{Integer,NTuple{N,<:Integer}}) where {T,N}
    minimum(dims) ≥ 1 || throw(ArgumentError("invalid dimension(s)"))
    sizeof(buf) ≥ sizeof(T)*prod(dims) ||
        throw(ArgumentError("buffer is too small"))
    return IPC.WrappedArray{T,length(dims),typeof(buf)}(convert(Ptr{T}, buf),
                                                        dims, buf)
end

@testset "Wrapped Arrays        " begin
    T = Float32
    dims = (5,6)
    buf = DynamicMemory(sizeof(T)*prod(dims))
    A = IPC.WrappedArray(buf, T, dims)
    @test ndims(A) == 2
    @test size(A) == dims
    @test size(A,1) == dims[1] && size(A,2) == dims[2]
    @test eltype(A) == T
    @test Base.elsize(A) == Base.sizeof(T)
    @test sizeof(A) == sizeof(buf)
    @test pointer(A) == pointer(buf)
    @test isa(A.arr, Array{T,length(dims)})
    A[:] = 1:length(A)
    @test A[1] == 1 && A[end] == prod(dims)
end

@testset "Shared Memory (Sys. V)" begin
    T = Int
    n = 10
    len = n*sizeof(Int)
    A = SharedMemory(IPC.PRIVATE, len)
    id = shmid(A)
    @test isa(id, ShmId)
    @test id == ShmId(A)
    @test "$id" == "ShmId($(dec(id.value)))"
    @test id.value == convert(Int64, id)
    @test id.value == convert(Int32, id)
    B = SharedMemory(id; readonly=false)
    C = SharedMemory(id; readonly=true)
    @test shmid(A) == shmid(B) == shmid(C)
    @test sizeof(A) == sizeof(B) == sizeof(C) == len
    Aptr = convert(Ptr{T},pointer(A))
    Bptr = convert(Ptr{T},pointer(B))
    Cptr = convert(Ptr{T},pointer(C))
    for i in 1:n
        unsafe_store!(Aptr,i,i)
    end
    @test all(unsafe_load(Bptr, i) == i for i in 1:n)
    @test all(unsafe_load(Cptr, i) == i for i in 1:n)
    for i in 1:n
        unsafe_store!(Bptr,-i,i)
    end
    @test all(unsafe_load(Aptr, i) == -i for i in 1:n)
    @test all(unsafe_load(Cptr, i) == -i for i in 1:n)
    @test_throws ReadOnlyMemoryError unsafe_store!(Cptr,42)
    @test ccall(:memset, Ptr{Void}, (Ptr{Void}, Cint, Csize_t),
                Aptr, 0, len) == Aptr
    @test all(unsafe_load(Cptr, i) == 0 for i in 1:n)
end

@testset "Shared Memory (POSIX) " begin
    T = Int
    n = 10
    len = n*sizeof(Int)
    path = "/shm-$(getpid())"
    try; shmrm(path); end
    A = SharedMemory(path, len)
    id = shmid(A)
    @test isa(id, String)
    B = SharedMemory(id; readonly=false)
    C = SharedMemory(id; readonly=true)
    @test shmid(A) == shmid(B) == shmid(C) == path
    @test sizeof(A) == sizeof(B) == sizeof(C) == len
    Aptr = convert(Ptr{T},pointer(A))
    Bptr = convert(Ptr{T},pointer(B))
    Cptr = convert(Ptr{T},pointer(C))
    for i in 1:n
        unsafe_store!(Aptr,i,i)
    end
    @test all(unsafe_load(Bptr, i) == i for i in 1:n)
    @test all(unsafe_load(Cptr, i) == i for i in 1:n)
    for i in 1:n
        unsafe_store!(Bptr,-i,i)
    end
    @test all(unsafe_load(Aptr, i) == -i for i in 1:n)
    @test all(unsafe_load(Cptr, i) == -i for i in 1:n)
    @test_throws ReadOnlyMemoryError unsafe_store!(Cptr,42)
    @test ccall(:memset, Ptr{Void}, (Ptr{Void}, Cint, Csize_t),
                Aptr, 0, len) == Aptr
    @test all(unsafe_load(Cptr, i) == 0 for i in 1:n)
end

end
