module IPCTests

using Test

using InterProcessCommunication

@testset "Basic Functions       " begin
    pid = IPC.getpid()
    @test pid.value == getpid()
    @test isa(string(pid), String)
    @test isa(string(IPC.getppid()), String)
    @test isa(string(IPC.getuid()), String)
    @test isa(string(IPC.geteuid()), String)
end

@testset "File Functions        " begin
    path = "/tmp/test-$(getpid())"
    data = rand(10)
    open(path, "w") do io
        write(io, data)
    end
    f = open(IPC.FileDescriptor, path, "r")
    @test fd(f) ≥ 0
    @test filesize(f) == sizeof(data)
    @test position(f) == 0
    @test seekend(f) == position(f) == sizeof(data)
    @test seekstart(f) == position(f) == 0
    pos = (sizeof(data)>>1)
    @test seek(f, pos) == position(f) == pos
    close(f)
    @test fd(f) == -1
end

@testset "Time Functions        " begin
    # compile and warmup
    for ts in (time(TimeSpec), now(TimeSpec))
        @test ts ≈ ts
        @test (ts != ts) == false
        @test ts ≤ ts
        @test ts ≥ ts
        @test (ts < ts) == false
        @test (ts > ts) == false
    end
    for tv in (time(TimeVal), now(TimeVal))
        @test tv ≈ tv
        @test tv == tv
        @test (tv != tv) == false
        @test tv ≤ tv
        @test tv ≥ tv
        @test (tv < tv) == false
        @test (tv > tv) == false
    end
    float(gettimeofday())
    float(clock_gettime(CLOCK_MONOTONIC))
    float(clock_gettime(CLOCK_REALTIME))
    float(clock_getres(CLOCK_MONOTONIC))
    float(clock_getres(CLOCK_REALTIME))

    # compare times
    ms = 0.001
    µs = 0.000_001
    ns = 0.000_000_001
    @test abs(time() - float(gettimeofday())) ≤ 1ms
    @test abs(time() - float(clock_gettime(CLOCK_REALTIME))) ≤ 1ms
    @test float(clock_getres(CLOCK_MONOTONIC)) ≤ 1ms
    @test float(clock_getres(CLOCK_REALTIME)) ≤ 1ms
    @test float(nanosleep(0.01)) == 0
    s = 10ms
    t0 = float(clock_gettime(CLOCK_MONOTONIC))
    nanosleep(s)
    t1 = float(clock_gettime(CLOCK_MONOTONIC))
    @test abs(t1 - (t0 + s)) ≤ 4ms
end

@testset "Signals               " begin
    # Sanity check:
    @test isbitstype(IPC._typeof_sigset)
    @test sizeof(IPC._typeof_sigset) == IPC._sizeof_sigset
    @test isbitstype(IPC._typeof_siginfo)
    @test sizeof(IPC._typeof_siginfo) == IPC._sizeof_siginfo

    # SigSet:
    set = SigSet()
    sigrtmin = (isdefined(IPC, :SIGRTMIN) ? IPC.SIGRTMIN : 1)
    sigrtmax = (isdefined(IPC, :SIGRTMAX) ? IPC.SIGRTMAX : 8*sizeof(set))
    @test all(set[i] == false for i in sigrtmin:sigrtmax)
    fill!(set, true)
    @test all(set[i] for i in sigrtmin:sigrtmax)
    i = rand(sigrtmin:sigrtmax)
    set[i] = false
    @test !set[i]
    set[i] = true
    @test set[i]
    set = sigpending()
    @test all(set[i] == false for i in 1:sigrtmax)

    # SigInfo:
    si = SigInfo()

    # SigAction:
    sa = SigAction()
end

@testset "BSD System V Keys     " begin
    path = "/tmp"
    key1 = IPC.Key(path, '1')
    key2 = IPC.Key(key1.value)
    @test key1 == key2
    shmds = ShmInfo()
    semds = IPC.SemInfo()
end

# Skip semaphore tests for Apple.
@static if !Sys.isapple()

    @testset "Named Semaphores      " begin
        begin
            name = "/sem-$(getpid())"
            rm(Semaphore, name)
            @test_throws SystemError Semaphore(name)
            sem1 = Semaphore(name, 0)
            sem2 = Semaphore(name)
            @test sem1[] == 0
            @test sem2[] == 0
            post(sem1)
            @test sem2[] == 1
            post(sem1)
            @test sem2[] == 2
            wait(sem2)
            @test sem2[] == 1
            @test trywait(sem2) == true
            @test trywait(sem2) == false
            @test_throws TimeoutError timedwait(sem2, 0.1)
        end
        GC.gc() # call garbage collector to exercise the finalizers
    end

    @testset "Anonymous Semaphores  " begin
        begin
            buf = DynamicMemory(sizeof(Semaphore))
            sem1 = Semaphore(buf, 0)
            sem2 = Semaphore(buf)
            @test sem1[] == 0
            @test sem2[] == 0
            post(sem1)
            @test sem2[] == 1
            post(sem1)
            @test sem2[] == 2
            wait(sem2)
            @test sem2[] == 1
            @test trywait(sem2) == true
            @test trywait(sem2) == false
            @test_throws TimeoutError timedwait(sem2, 0.1)
        end
        GC.gc() # call garbage collector to exercise the finalizers
    end

end

@testset "Wrapped Arrays        " begin
    begin
        T = Float32
        dims = (5,6)
        buf = DynamicMemory(sizeof(T)*prod(dims))
        A = WrappedArray(buf, T, dims)
        B = WrappedArray(buf) # indexable byte buffer
        C = WrappedArray(buf, T) # indexable byte buffer
        D = WrappedArray(buf, b -> (T, dims, 0)) # all parameters provided by a function
        A[:] = 1:length(A) # fill A before the copy
        E = copy(A)
        n = prod(dims)
        @test ndims(A) == ndims(D) == ndims(E) == length(dims)
        @test size(A) == size(D) == size(E) == dims
        @test all(size(A,i) == size(D,i) == dims[i] for i in 1:length(dims))
        @test eltype(A) == eltype(C) == eltype(D) == T
        @test Base.elsize(A) == Base.sizeof(T)
        @test length(A) == length(C) == div(length(B), sizeof(T)) == length(D) == n
        @test sizeof(A) == sizeof(B) == sizeof(C) == sizeof(D) == sizeof(buf)
        @test pointer(A) == pointer(B) == pointer(C) == pointer(D) == pointer(buf)
        @test isa(A.arr, Array{T,length(dims)})
        @test A[1] == 1 && A[end] == prod(dims)
        @test all(A[i] == i for i in 1:n)
        @test all(C[i] == i for i in 1:n)
        @test all(D[i] == i for i in 1:n)
        @test all(E[i] == i for i in 1:n)
        B[:] .= 0
        @test all(A[i] == 0 for i in 1:n)
        C[:] = randn(T, n)
        flag = true
        for i in eachindex(A, D)
            if A[i] != D[i]
                flag = false
            end
        end
        @test flag
        B[:] .= 0
        A[2,3] = 23
        A[3,2] = 32
        @test D[2,3] == 23 && D[3,2] == 32
        # Test copy back.
        copyto!(A, E)
        @test all(A[i] == E[i] for i in 1:n)
    end
    GC.gc() # call garbage collector to exercise the finalizers
end

@testset "Shared Memory (BSD)   " begin
    begin
        T = Int
        n = 10
        len = n*sizeof(Int)
        A = SharedMemory(IPC.PRIVATE, len)
        id = shmid(A)
        @test isa(id, ShmId)
        @test id == ShmId(A)
        @test "$id" == "ShmId($(id.value))"
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
        @test ccall(:memset, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Csize_t),
                    Aptr, 0, len) == Aptr
        @test all(unsafe_load(Cptr, i) == 0 for i in 1:n)
    end
    GC.gc() # call garbage collector to exercise the finalizers
end

@testset "Shared Memory (POSIX) " begin
    begin
        T = Int
        n = 10
        len = n*sizeof(Int)
        name = "/shm-$(getpid())"
        rm(SharedMemory, name)
        @test_throws SystemError SharedMemory(name)
        A = SharedMemory(name, len)
        id = shmid(A)
        @test isa(id, String)
        @test id == name
        B = SharedMemory(id; readonly=false)
        C = SharedMemory(id; readonly=true)
        @test shmid(A) == shmid(B) == shmid(C) == name
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
        @test ccall(:memset, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Csize_t),
                    Aptr, 0, len) == Aptr
        @test all(unsafe_load(Cptr, i) == 0 for i in 1:n)
    end
    GC.gc() # call garbage collector to exercise the finalizers
end

@testset "Wrapped Shared Arrays " begin
    begin
        T = Float32
        dims = (3,4,5)
        for key in (IPC.PRIVATE, "/wrsharr-$(getpid())")
            if isa(key, String)
                try; shmrm(key); catch err; end
            end
            A = WrappedArray(key, T, dims)
            id = shmid(A)
            if isa(id, ShmId)
                info = ShmInfo(id)
                @test info.segsz ≥ sizeof(A) + 64
            end
            B = WrappedArray(id; readonly=false)
            C = WrappedArray(id; readonly=true)
            n = length(A)
            @test shmid(A) == shmid(B) == shmid(C) == id
            @test sizeof(A) == sizeof(B) == sizeof(C) == n*sizeof(T)
            @test eltype(A) == eltype(B) == eltype(C) == T
            @test size(A) == size(B) == size(C) == dims
            @test length(A) == length(B) == length(C) == prod(dims)
            @test all(size(A,i) == size(B,i) == size(C,i) == dims[i] for i in 1:length(dims))
            A[:] = 1:n
            @test first(A) == 1
            @test last(A) == n
            @test A[end] == n
            @test all(B[i] == i for i in 1:n)
            @test all(C[i] == i for i in 1:n)
            B[:] = -(1:n)
            @test extrema(A[:] + (1:n)) == (0, 0)
            @test all(C[i] == -i for i in 1:n)
            @test_throws ReadOnlyMemoryError C[end] = 42
            @test ccall(:memset, Ptr{Cvoid}, (Ptr{Cvoid}, Cint, Csize_t),
                        A, 0, sizeof(A)) == pointer(A)
            @test extrema(C) == (0, 0)
        end
    end
    GC.gc() # call garbage collector to exercise the finalizers
end

end # module
