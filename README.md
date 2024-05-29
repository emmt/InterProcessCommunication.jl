# Inter-Process Communication for Julia

[![License][license-img]][license-url]
[![Documentation][doc-dev-img]][doc-dev-url]
[![Build Status][github-ci-img]][github-ci-url]
[![Coverage][coveralls-img]][coveralls-url]
[![Coverage][codecov-img]][codecov-url]

Julia has already many methods for inter-process communication (IPC): sockets,
semaphores, memory mapped files, etc.  You may however want to have Julia
interacts with other processes or threads by means of BSD (System V) IPC or
POSIX shared memory, semaphores, message queues or mutexes, condition variables
and read/write locks.  Package `InterProcessCommunication.jl` (*IPC* for short)
intends to provide such facilities.

The `InterProcessCommunication` package provides:

* Two kinds of **shared memory** objects: *named shared memory* which are
  identified by their name and old-style (BSD System V) *shared memory
  segments* which are identified by a key.

* Two kinds of **semaphores**: *named semaphores* which are identified by their
  name and *anonymous semaphores* which are backed by *memory* objects (usually
  shared memory) providing the necessary storage.

* Management of **signals** including so called real-time signals.

* Array-like objects stored in shared memory.

* Access to POSIX **mutexes**, **condition variables** and **read/write
  locks**.  These objects can optionally be stored in shared memory and shared
  between processes.


## Documentation

The documentation for `InterProcessCommunication` package is
[here](https://emmt.github.io/InterProcessCommunication.jl/dev).


## Installation

Installation is not yet fully automated in the spirit of official Julia
packages but is rather easy.  It is sufficient to:

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/emmt/InterProcessCommunication.jl.git"))
Pkg.build("InterProcessCommunication")
```

Optionally, you may test the package:

```julia
Pkg.test("InterProcessCommunication")
```

Later, it is sufficient to do:

```julia
Pkg.update("InterProcessCommunication")
Pkg.build("InterProcessCommunication")
```

to pull the latest version and rebuild the dependencies.

All these can be done at the prompt of Julia's package manager:


```julia
... pkg> add https://github.com/emmt/InterProcessCommunication.jl.git"
... pkg> build InterProcessCommunication
... pkg> test InterProcessCommunication
... pkg> update InterProcessCommunication
... pkg> build InterProcessCommunication
```

[doc-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[doc-stable-url]: https://emmt.github.io/InterProcessCommunication.jl/stable

[doc-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[doc-dev-url]: https://emmt.github.io/InterProcessCommunication.jl/dev

[license-url]: ./LICENSE.md
[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat

[github-ci-img]: https://github.com/emmt/InterProcessCommunication.jl/actions/workflows/CI.yml/badge.svg?branch=master
[github-ci-url]: https://github.com/emmt/InterProcessCommunication.jl/actions/workflows/CI.yml?query=branch%3Amaster

[appveyor-img]: https://ci.appveyor.com/api/projects/status/github/emmt/InterProcessCommunication.jl?branch=master
[appveyor-url]: https://ci.appveyor.com/project/emmt/InterProcessCommunication-jl/branch/master

[coveralls-img]: https://coveralls.io/repos/emmt/InterProcessCommunication.jl/badge.svg?branch=master&service=github
[coveralls-url]: https://coveralls.io/github/emmt/InterProcessCommunication.jl?branch=master

[codecov-img]: http://codecov.io/github/emmt/InterProcessCommunication.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/emmt/InterProcessCommunication.jl?branch=master
