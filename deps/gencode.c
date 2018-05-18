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
#include <sys/sem.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>

/* Determine the offset of a field in a structure. */
#define OFFSET_OF(type, field) ((char*)&((type*)0)->field - (char*)0)

/* Determine whether an integer type is signed. */
#define IS_SIGNED(type)        (~(type)0 < (type)0)

/* Set all the bits of an L-value. */
#define SET_ALL_BITS(lval) lval = 0; lval = ~lval

/* Define a Julia constant. */
#define DEF_CONST(name, format) \
  fprintf(output, "const " #name format "\n", name)

/* Define a Julia alias for a C integer, given an L-value of the corresponding
 * type. */
#define DEF_TYPEOF_LVALUE(name, lval)                   \
  do {                                                  \
    SET_ALL_BITS(lval);                                 \
    fprintf(output, "const _typeof_%s = %sInt%u\n",     \
            name, (lval < 0 ? "" : "U"),                \
            (unsigned)(8*sizeof(lval)));                \
                                                        \
  } while (0)

/* Define a Julia alias for a C integer, given its type (`space` is used for
 * alignment). */
#define DEF_TYPEOF_TYPE(type, space)                    \
  do {                                                  \
    type lval;                                          \
    SET_ALL_BITS(lval);                                 \
    fprintf(output, "const _typeof_%s%s = %sInt%u\n",   \
            #type, space, (lval < 0 ? "" : "U"),        \
            (unsigned)(8*sizeof(lval)));                \
                                                        \
  } while (0)

/* Define a Julia constant with the offset (in bytes) of a field of a
 * C-structure. */
#define DEF_OFFSETOF(ident, type, field)                \
  fprintf(output, "const _offsetof_" ident " = %3ld\n", \
          (long)OFFSET_OF(type, field))

/* Define a Julia constant with the size of a given C-type. */
#define DEF_SIZEOF_TYPE(name, type)             \
  fprintf(output, "const _sizeof_%s = %3lu\n",  \
          name, (unsigned long)sizeof(type))

static void error(const char* mesg)
{
  fprintf(stderr, "error: %s\n", mesg);
  exit(1);
}

int main(int argc, char* argv[])
{
  int status = 0;
  FILE* output = stdout;

  if (argc == 2 && (strcmp(argv[1], "--help") == 0 ||
                    strcmp(argv[1], "-h") == 0)) {
  usage:
    fprintf(stderr, "Usage: %s [--help|-h]\n", argv[0]);
    return status;
  } else if (argc > 1) {
    status = 1;
    goto usage;
  }

  fprintf(output, "\n# Bits for creating/opening a file:\n");
  DEF_CONST(O_RDONLY, " = Cint(0o%04o)");
  DEF_CONST(O_WRONLY, " = Cint(0o%04o)");
  DEF_CONST(O_RDWR, "   = Cint(0o%04o)");
  DEF_CONST(O_CREAT, "  = Cint(0o%04o)");
  DEF_CONST(O_EXCL, "   = Cint(0o%04o)");
  DEF_CONST(O_TRUNC, "  = Cint(0o%04o)");

  fprintf(output, "\n# Bits for file permissions:\n");
  DEF_CONST(S_IRWXU, " = Cint(0o%04o) # user has read, write, and execute permission");
  DEF_CONST(S_IRUSR, " = Cint(0o%04o) # user has read permission");
  DEF_CONST(S_IWUSR, " = Cint(0o%04o) # user has write permission");
  DEF_CONST(S_IXUSR, " = Cint(0o%04o) # user has execute permission");
  DEF_CONST(S_IRWXG, " = Cint(0o%04o) # group has read, write, and execute permission");
  DEF_CONST(S_IRGRP, " = Cint(0o%04o) # group has read permission");
  DEF_CONST(S_IWGRP, " = Cint(0o%04o) # group has write permission");
  DEF_CONST(S_IXGRP, " = Cint(0o%04o) # group has execute permission");
  DEF_CONST(S_IRWXO, " = Cint(0o%04o) # others have read, write, and execute permission");
  DEF_CONST(S_IROTH, " = Cint(0o%04o) # others have read permission");
  DEF_CONST(S_IWOTH, " = Cint(0o%04o) # others have write permission");
  DEF_CONST(S_IXOTH, " = Cint(0o%04o) # others have execute permission");

  fprintf(output, "\n# Commands for `shmctl`, `semctl` and `msgctl`:\n");
  DEF_CONST(IPC_STAT, " = Cint(%d)");
  DEF_CONST(IPC_SET, "  = Cint(%d)");
  DEF_CONST(IPC_RMID, " = Cint(%d)");

  fprintf(output, "\n# Bits for `shmget`:\n");
  DEF_CONST(IPC_CREAT, " = Cint(0o%04o)");
  DEF_CONST(IPC_EXCL, "  = Cint(0o%04o)");

  fprintf(output, "\n# Flags for `shmdt`:\n");
  DEF_CONST(SHM_EXEC, "   = Cint(%d)");
  DEF_CONST(SHM_RDONLY, " = Cint(%d)");
  /*DEF_CONST(SHM_REMAP, "  = Cint(%d)");*/

  fprintf(output, "\n# Some standard C-types:\n");
  {
    time_t t;
    struct timeval tv;
    struct timespec ts;

    SET_ALL_BITS(t);
    SET_ALL_BITS(tv.tv_sec);
    SET_ALL_BITS(tv.tv_usec);
    SET_ALL_BITS(ts.tv_sec);
    SET_ALL_BITS(ts.tv_nsec);

    if (sizeof(tv.tv_sec) != sizeof(t) || (tv.tv_sec < 0) != (t < 0)) {
      error("Field `tv_sec` in `struct timeval` is not of type `time_t`");
    }
    if (sizeof(ts.tv_sec) != sizeof(t) || (ts.tv_sec < 0) != (t < 0)) {
      error("Field `tv_sec` in `struct timespec` is not of type `time_t`");
    }
    DEF_TYPEOF_LVALUE("time_t  ", t);
    DEF_TYPEOF_LVALUE("tv_sec  ", tv.tv_sec);
    DEF_TYPEOF_LVALUE("tv_usec ", tv.tv_usec);
    DEF_TYPEOF_LVALUE("tv_nsec ", ts.tv_nsec);
  }
  DEF_TYPEOF_TYPE(mode_t, "  ");
  DEF_TYPEOF_TYPE(pid_t, "   ");
  DEF_TYPEOF_TYPE(uid_t, "   ");
  DEF_TYPEOF_TYPE(gid_t, "   ");
  DEF_TYPEOF_TYPE(key_t, "   ");
  DEF_TYPEOF_TYPE(nlink_t, " ");
  DEF_TYPEOF_TYPE(shmatt_t, "");

  fprintf(output, "\n# Sizes of some standard C types:\n");
  DEF_SIZEOF_TYPE("struct_stat     ", struct stat);
  DEF_SIZEOF_TYPE("struct_semid_ds ", struct semid_ds);
  DEF_SIZEOF_TYPE("pthread_mutex_t ", pthread_mutex_t);
  DEF_SIZEOF_TYPE("pthread_cond_t  ", pthread_cond_t);

  fprintf(output, "\n# Offsets of fields in `struct shmid_ds`:\n");
  DEF_OFFSETOF("shm_perm_uid ", struct shmid_ds, shm_perm.uid);
  DEF_OFFSETOF("shm_perm_gid ", struct shmid_ds, shm_perm.gid);
  DEF_OFFSETOF("shm_perm_cuid", struct shmid_ds, shm_perm.cuid);
  DEF_OFFSETOF("shm_perm_cgid", struct shmid_ds, shm_perm.cgid);
  DEF_OFFSETOF("shm_perm_mode", struct shmid_ds, shm_perm.mode);
  DEF_OFFSETOF("shm_segsz    ", struct shmid_ds, shm_segsz);
  DEF_OFFSETOF("shm_atime    ", struct shmid_ds, shm_atime);
  DEF_OFFSETOF("shm_dtime    ", struct shmid_ds, shm_dtime);
  DEF_OFFSETOF("shm_ctime    ", struct shmid_ds, shm_ctime);
  DEF_OFFSETOF("shm_cpid     ", struct shmid_ds, shm_cpid);
  DEF_OFFSETOF("shm_lpid     ", struct shmid_ds, shm_lpid);
  DEF_OFFSETOF("shm_nattch   ", struct shmid_ds, shm_nattch);

  fprintf(output, "\n# Special IPC key:\n");
  DEF_CONST(IPC_PRIVATE, " = _typeof_key_t(%d)");

  fprintf(output, "\n# Flags for `semctl`:\n");
  DEF_CONST(GETALL, "  = Cint(%d)");
  DEF_CONST(GETNCNT, " = Cint(%d)");
  DEF_CONST(GETPID, "  = Cint(%d)");
  DEF_CONST(GETVAL, "  = Cint(%d)");
  DEF_CONST(GETZCNT, " = Cint(%d)");
  DEF_CONST(SETALL, "  = Cint(%d)");
  DEF_CONST(SETVAL, "  = Cint(%d)");

  fprintf(output, "\n# Flags for `semop`:\n");
  DEF_CONST(IPC_NOWAIT, " = Cshort(%d)");
  DEF_CONST(SEM_UNDO, "   = Cshort(%d)");

  fprintf(output, "\n# Constants for `struct sembuf`:\n");
  {
    struct sembuf sb;
    DEF_SIZEOF_TYPE("struct_sembuf", struct sembuf);
    DEF_OFFSETOF("sem_num    ", struct sembuf, sem_num);
    DEF_OFFSETOF("sem_op     ", struct sembuf, sem_op);
    DEF_OFFSETOF("sem_flg    ", struct sembuf, sem_flg);
    DEF_TYPEOF_LVALUE("sem_num      ", sb.sem_num);
    DEF_TYPEOF_LVALUE("sem_op       ", sb.sem_op);
    DEF_TYPEOF_LVALUE("sem_flg      ", sb.sem_flg);
  }

#if 0
  fprintf(output, "\n# Constants for `union semnum`:\n");
  {
    union semnum {
      int val;
      void* ptr;
    } sn;
    DEF_SIZEOF_TYPE("union_semnum", union semnum);
    DEF_OFFSETOF("semnum_val", union semnum, val);
    DEF_OFFSETOF("semnum_ptr", union semnum, ptr);
  }

  fprintf(output, "\n# Semaphore limits:\n");
  DEF_CONST(SEMMNI, "= %-6d # max. number of semaphore sets");
  DEF_CONST(SEMMSL, "= %-6d # max. number of semaphores per semaphore set");
  DEF_CONST(SEMMNS, "= %-6d # max. number of semaphores");
#endif

  fprintf(output, "\n# Constants for POSIX semaphores:\n");
  DEF_CONST(SEM_FAILED, "    = Cint(%p)");
#ifdef SEM_VALUE_MAX
  DEF_CONST(SEM_VALUE_MAX, " = Cint(%d)");
#endif

  return 0;
}
