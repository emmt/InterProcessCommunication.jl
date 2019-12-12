# Inter-Process Communication for Julia

| **Documentation**               | **License**                     | **Build Status**              | **Code Coverage**                                                   |
|:--------------------------------|:--------------------------------|:------------------------------|:--------------------------------------------------------------------|
| [![][doc-dev-img]][doc-dev-url] | [![][license-img]][license-url] | [![][travis-img]][travis-url] | [![][coveralls-img]][coveralls-url] [![][codecov-img]][codecov-url] |

Julia has already many methods for inter-process communication (IPC): sockets,
semaphores, memory mapped files, etc.  You may however want to have Julia
interacts with other processes or threads by means of BSD (System V) IPC or
POSIX shared memory, semaphores, message queues or mutexes and condition
variables.  Package `IPC.jl` intends to provide such facilities.

Julia `IPC.jl` package provides:

* Two kinds of **shared memory** objects: *named shared memory* which are
  identified by their name and old-style (BSD System V) *shared memory
  segments* which are identified by a key.

* Two kinds of **semaphores**: *named semaphores* which are identified by their
  name and *anonymous semaphores* which are backed by *memory* objects (usually
  shared memory) providing the necessary storage.

* Management of **signals** including so called real-time signals.

* Array-like objects stored in shared memory.


## Installation

Installation is not yet fully automated in the spirit of official Julia
packages but is rather easy.  It is sufficient to:

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/emmt/IPC.jl.git"))
Pkg.build("IPC")
```

Optionally, you may test the package:

```julia
Pkg.test("IPC")
```

Later, it is sufficient to do:

```julia
Pkg.update("IPC")
Pkg.build("IPC")
```

to pull the latest version and rebuild the dependencies.

All these can be done at the prompt of Julia's package manager:


```julia
... pkg> add https://github.com/emmt/IPC.jl.git"
... pkg> build IPC
... pkg> test IPC
... pkg> update IPC
... pkg> build IPC
```

[doc-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[doc-stable-url]: https://emmt.github.io/IPC.jl/stable

[doc-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[doc-dev-url]: https://emmt.github.io/IPC.jl/dev

[license-url]: ./LICENSE.md
[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat

[travis-img]: https://travis-ci.org/emmt/IPC.jl.svg?branch=master
[travis-url]: https://travis-ci.org/emmt/IPC.jl

[appveyor-img]: https://ci.appveyor.com/api/projects/status/github/emmt/IPC.jl?branch=master
[appveyor-url]: https://ci.appveyor.com/project/emmt/IPC-jl/branch/master

[coveralls-img]: https://coveralls.io/repos/emmt/IPC.jl/badge.svg?branch=master&service=github
[coveralls-url]: https://coveralls.io/github/emmt/IPC.jl?branch=master

[codecov-img]: http://codecov.io/github/emmt/IPC.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/emmt/IPC.jl?branch=master
