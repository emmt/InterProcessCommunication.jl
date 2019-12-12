SOURCES = \
    Project.toml \
    make.jl \
    src/index.md \
    src/reference.md \
    src/sharedmemory.md \
    src/semaphores.md

default: build/index.html

clean:
	rm -f *~ */*~ */*/*~

build/index.html: $(SOURCES)
	julia --color=yes make.jl

.PHOONY: default clean
