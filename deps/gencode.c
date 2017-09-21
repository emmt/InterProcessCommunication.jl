#include <fcntl.h>
#include <pthread.h>
#include <semaphore.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>

#define OFFSET_OF(type, field) ((char*)&((type*)0)->field - (char*)0)
#define IS_SIGNED(type)        ((type)(~(type)0) < (type)0)

#define MAXLEN 100

#define DEF_CONST(name, format) \
  fprintf(output, "const " #name format "\n", name)

int main(int argc, char* argv[])
{
  int status = 0, info = 0;
  FILE* output = stdout;

  if (argc == 2 && (strcmp(argv[1], "--help") == 0 ||
		    strcmp(argv[1], "-h") == 0)) {
  usage:
    fprintf(stderr, "Usage: %s [--help|-h|--info|-i]\n", argv[0]);
    return status;
  } else if (argc == 2 && (strcmp(argv[1], "--info") == 0 ||
		    strcmp(argv[1], "-i") == 0)) {
    info = 1;
  } else if (argc > 1) {
    status = 1;
    goto usage;
  }

  fprintf(output, "\n# Bits for creating/opening a file:\n");
  DEF_CONST(O_RDONLY, " = Cint(%06o)");
  DEF_CONST(O_RDWR, "   = Cint(%06o)");
  DEF_CONST(O_CREAT, "  = Cint(%06o)");
  DEF_CONST(O_EXCL, "   = Cint(%06o)");
  DEF_CONST(O_TRUNC, "  = Cint(%06o)");

  fprintf(output, "\n# Bits for file permissions:\n");
  DEF_CONST(S_IRWXU, " = Cint(%06o); # user has read, write, and execute permission");
  DEF_CONST(S_IRUSR, " = Cint(%06o); # user has read permission");
  DEF_CONST(S_IWUSR, " = Cint(%06o); # user has write permission");
  DEF_CONST(S_IXUSR, " = Cint(%06o); # user has execute permission");
  DEF_CONST(S_IRWXG, " = Cint(%06o); # group has read, write, and execute permission");
  DEF_CONST(S_IRGRP, " = Cint(%06o); # group has read permission");
  DEF_CONST(S_IWGRP, " = Cint(%06o); # group has write permission");
  DEF_CONST(S_IXGRP, " = Cint(%06o); # group has execute permission");
  DEF_CONST(S_IRWXO, " = Cint(%06o); # others have read, write, and execute permission");
  DEF_CONST(S_IROTH, " = Cint(%06o); # others have read permission");
  DEF_CONST(S_IWOTH, " = Cint(%06o); # others have write permission");
  DEF_CONST(S_IXOTH, " = Cint(%06o); # others have execute permission");

  return 0;
}
