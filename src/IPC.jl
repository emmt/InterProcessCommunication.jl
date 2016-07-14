#
# IPC.jl --
#
# Inter-Process Communication for Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016, Éric Thiébaut (https://github.com/emmt).
#

module IPC

import Base: convert, getindex, setindex!, eltype, length, ndims, sizeof,
             size, eachindex, linearindexing, stride, strides,
             reinterpret, reshape, copy, copy!, show, string, pointer

export ShmArray, shmget, shmid, shmat, shmdt, shmrm, shmcfg, shminfo, shminfo!


# ~/.julia/modules/IPC/deps/lib/libswl.so
const libswl = joinpath(homedir(), ".julia", "modules", "IPC", "deps", "lib",
                        "libswl."*Libdl.dlext)

const SUCCESS = Cint( 0)
const FAILURE = Cint(-1)

const CREAT   = Cuint(0001000)
const EXCL    = Cuint(0002000)
const RDONLY  = Cuint(0010000)

const IRWXU = Cuint(00700) # user (file owner) has read, write, and execute permission
const IRUSR = Cuint(00400) # user has read permission
const IWUSR = Cuint(00200) # user has write permission
const IXUSR = Cuint(00100) # user has execute permission
const IRWXG = Cuint(00070) # group has read, write, and execute permission
const IRGRP = Cuint(00040) # group has read permission
const IWGRP = Cuint(00020) # group has write permission
const IXGRP = Cuint(00010) # group has execute permission
const IRWXO = Cuint(00007) # others have read, write, and execute permission
const IROTH = Cuint(00004) # others have read permission
const IWOTH = Cuint(00002) # others have write permission
const IXOTH = Cuint(00001) # others have execute permission

immutable Key
    value::Cint
end

const PRIVATE = Key(0)

# a bit of magic for calling C-code:
convert(::Type{Cint}, key::Key) = key.value
#convert{T<:Integer}(::Type{T}, ipckey::Key) = convert(T, ipckey.value)
convert(::Type{ASCIIString}, key::Key) = string(key)

string(key::Key) = dec(key.value)
show(io::IO, key::Key) = (write(io, "IPC.Key: "*dec(key.value)); nothing)


"""

Immutable type `IPC.Key` stores a System V IPC key.  The call:

    IPC.Key(path, proj)

generates a System V IPC key from pathname `path` and a project identifier
`proj` (a single character).  The key is suitable for System V Inter-Process
Communication (IPC) facilities (message queues, semaphores and shared memory).
For instance:

    key = IPC.Key(".", 'a')

The special IPC key `IPC.PRIVATE` is also available.
"""
function Key(path::AbstractString, proj::Char)
    key = ccall((:SWL_GenerateKey, libswl), Cint,
                (Ptr{UInt8}, Cint), path, proj)
    if key == -1
        error(syserrmsg("failed to create IPC key"))
    end
    return Key(key)
end

syserrmsg(msg::AbstractString, code::Integer=Libc.errno()) =
    string(msg," [",Libc.strerror(code),"]")

makedims{N}(dims::NTuple{N,Integer}) = ntuple(i -> Int(dims[i]), N)
makedims{T<:Integer}(dims::Array{T,1}) = ntuple(i -> Int(dims[i]), length(dims))

include("shm.jl")

end # module IPC

