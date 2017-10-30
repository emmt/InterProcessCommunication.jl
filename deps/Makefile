CC = gcc
CFLAGS = -O -Wall
CPPFLAGS =
LDFLAGS =

all: ../src/constants.jl

clean:
	rm -f *~ core gencode

gencode: gencode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" "$<" $(LDFLAGS)

../src/constants.jl: constants-header.jl gencode
	rm -f "$@"
	cat constants-header.jl >"$@"
	./gencode >>"$@"
	chmod 444 "$@"
