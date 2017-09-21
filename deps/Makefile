CC = gcc
CFLAGS = -O
CPPFLAGS =
LDFLAGS =

all: constants.jl

clean:
	rm -f *~ core gencode

gencode: gencode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" "$<" $(LDFLAGS)

constants.jl: constants-header.jl gencode
	rm -f "$@"
	cat constants-header.jl >"$@"
	./gencode >>"$@"
	chmod 444 "$@"
