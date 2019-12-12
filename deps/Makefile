all: deps.jl

clean:
	rm -f *~ core gendeps

man-fstat:
	LANG=C man fstat | cat

gendeps: gendeps.c Makefile
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" "$<" $(LDFLAGS)

deps.jl: gendeps
	rm -f "$@"
	./gendeps >>"$@"
	chmod 444 "$@"
