/*
 * gencode.c --
 *
 * Generate constants definitions for Julia.
 *
 *------------------------------------------------------------------------------
 *
 * This file is part of IPC.jl released under the MIT "expat" license.
 * Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/IPC.jl).
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/shm.h>
#include <fcntl.h>
#include <pthread.h>
#include <semaphore.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#ifdef __APPLE__
# define st_atim st_atimespec
# define st_mtim st_mtimespec
# define st_ctim st_ctimespec
#endif

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

  fprintf(output, "\n# Some standard C-types:\n");
  DEF_TYPEOF_TYPE(time_t, "   ");
  DEF_TYPEOF_TYPE(size_t, "   ");
  DEF_TYPEOF_TYPE(ssize_t, "  ");
  DEF_TYPEOF_TYPE(mode_t, "   ");
  DEF_TYPEOF_TYPE(dev_t, "    ");
  DEF_TYPEOF_TYPE(ino_t, "    ");
  DEF_TYPEOF_TYPE(pid_t, "    ");
  DEF_TYPEOF_TYPE(uid_t, "    ");
  DEF_TYPEOF_TYPE(gid_t, "    ");
  DEF_TYPEOF_TYPE(key_t, "    ");
  DEF_TYPEOF_TYPE(nlink_t, "  ");
  DEF_TYPEOF_TYPE(shmatt_t, " ");
  DEF_TYPEOF_TYPE(off_t, "    ");
  DEF_TYPEOF_TYPE(blksize_t, "");
  DEF_TYPEOF_TYPE(blkcnt_t, " ");

  fprintf(output, "\n# Bits for creating/opening a file:\n");
  DEF_CONST(O_RDONLY, " = Cint(0o%04o)");
  DEF_CONST(O_WRONLY, " = Cint(0o%04o)");
  DEF_CONST(O_RDWR, "   = Cint(0o%04o)");
  DEF_CONST(O_CREAT, "  = Cint(0o%04o)");
  DEF_CONST(O_EXCL, "   = Cint(0o%04o)");
  DEF_CONST(O_TRUNC, "  = Cint(0o%04o)");

  fprintf(output, "\n# Bits for file permissions:\n");
  DEF_CONST(S_IRWXU, " = _typeof_mode_t(0o%04o) # user has read, write, and execute permission");
  DEF_CONST(S_IRUSR, " = _typeof_mode_t(0o%04o) # user has read permission");
  DEF_CONST(S_IWUSR, " = _typeof_mode_t(0o%04o) # user has write permission");
  DEF_CONST(S_IXUSR, " = _typeof_mode_t(0o%04o) # user has execute permission");
  DEF_CONST(S_IRWXG, " = _typeof_mode_t(0o%04o) # group has read, write, and execute permission");
  DEF_CONST(S_IRGRP, " = _typeof_mode_t(0o%04o) # group has read permission");
  DEF_CONST(S_IWGRP, " = _typeof_mode_t(0o%04o) # group has write permission");
  DEF_CONST(S_IXGRP, " = _typeof_mode_t(0o%04o) # group has execute permission");
  DEF_CONST(S_IRWXO, " = _typeof_mode_t(0o%04o) # others have read, write, and execute permission");
  DEF_CONST(S_IROTH, " = _typeof_mode_t(0o%04o) # others have read permission");
  DEF_CONST(S_IWOTH, " = _typeof_mode_t(0o%04o) # others have write permission");
  DEF_CONST(S_IXOTH, " = _typeof_mode_t(0o%04o) # others have execute permission");

  fprintf(output, "\n# Argument for `lseek`:\n");
  DEF_CONST(SEEK_SET, " = Cint(%d) # offset is relative to the beginning");
  DEF_CONST(SEEK_CUR, " = Cint(%d) # offset is relative to current position");
  DEF_CONST(SEEK_END, " = Cint(%d) # offset is relative to the end");

  fprintf(output, "\n# Commands for `shmctl`, `semctl` and `msgctl`:\n");
  DEF_CONST(IPC_STAT, " = Cint(%d)");
  DEF_CONST(IPC_SET, "  = Cint(%d)");
  DEF_CONST(IPC_RMID, " = Cint(%d)");

  fprintf(output, "\n# Bits for `shmget`:\n");
  DEF_CONST(IPC_CREAT, " = Cint(0o%04o)");
  DEF_CONST(IPC_EXCL, "  = Cint(0o%04o)");

  fprintf(output, "\n# Flags for `shmdt`:\n");
#ifdef SHM_EXEC
  DEF_CONST(SHM_EXEC, "   = Cint(%d)");
#endif
  DEF_CONST(SHM_RDONLY, " = Cint(%d)");
#ifdef SHM_EXEC
  DEF_CONST(SHM_REMAP, "  = Cint(%d)");
#endif

  fprintf(output, "\n# Constants for `mmap`, `msync`, etc.:\n");
  DEF_CONST(PROT_NONE, "     = Cint(%d)");
  DEF_CONST(PROT_READ, "     = Cint(%d)");
  DEF_CONST(PROT_WRITE, "    = Cint(%d)");
  DEF_CONST(PROT_EXEC, "     = Cint(%d)");
  DEF_CONST(MAP_SHARED, "    = Cint(%d)");
  DEF_CONST(MAP_PRIVATE, "   = Cint(%d)");
  DEF_CONST(MAP_ANONYMOUS, " = Cint(%d)"); /* FIXME: non-POSIX? */
  DEF_CONST(MAP_FIXED, "     = Cint(%d)");
  fprintf(output, "const MAP_FAILED    = Ptr{Void}(%ld)\n", (long)MAP_FAILED);
  DEF_CONST(MS_ASYNC, "      = Cint(%d)");
  DEF_CONST(MS_SYNC, "       = Cint(%d)");
  DEF_CONST(MS_INVALIDATE, " = Cint(%d)");

  fprintf(output, "\n# Memory page size:\n");
  fprintf(output, "PAGE_SIZE = %ld\n", (long)sysconf(_SC_PAGESIZE));

  fprintf(output, "\n# Fields of `struct timeval` and `struct timespec`:\n");
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
    if (OFFSET_OF(struct timeval, tv_sec) != 0) {
      error("Field `tv_sec` in `struct timeval` is not the first one");
    }
    if (sizeof(ts.tv_sec) != sizeof(t) || (ts.tv_sec < 0) != (t < 0)) {
      error("Field `tv_sec` in `struct timespec` is not of type `time_t`");
    }
    if (OFFSET_OF(struct timespec, tv_sec) != 0) {
      error("Field `tv_sec` in `struct timespec` is not the first one");
    }
    DEF_TYPEOF_LVALUE("timeval_sec  ", tv.tv_sec);
    DEF_TYPEOF_LVALUE("timeval_usec ", tv.tv_usec);
    DEF_TYPEOF_LVALUE("timespec_sec ", ts.tv_sec);
    DEF_TYPEOF_LVALUE("timespec_nsec", ts.tv_nsec);
  }

  fprintf(output, "\n# Definitions for the POSIX `clock_*` functions:\n");
  DEF_TYPEOF_TYPE(clockid_t, "");
  DEF_CONST(CLOCK_REALTIME, "  = convert(_typeof_clockid_t, %d)");
  DEF_CONST(CLOCK_MONOTONIC, " = convert(_typeof_clockid_t, %d)");

  fprintf(output, "\n# Sizes of some standard C types:\n");
  DEF_SIZEOF_TYPE("pthread_mutex_t ", pthread_mutex_t);
  DEF_SIZEOF_TYPE("pthread_cond_t  ", pthread_cond_t);

  fprintf(output, "\n# Definitions for `struct stat`:\n");
  DEF_SIZEOF_TYPE("struct_stat       ", struct stat);
  DEF_OFFSETOF("stat_dev     ", struct stat, st_dev);
  DEF_OFFSETOF("stat_ino     ", struct stat, st_ino);
  DEF_OFFSETOF("stat_mode    ", struct stat, st_mode);
  DEF_OFFSETOF("stat_nlink   ", struct stat, st_nlink);
  DEF_OFFSETOF("stat_uid     ", struct stat, st_uid);
  DEF_OFFSETOF("stat_gid     ", struct stat, st_gid);
  DEF_OFFSETOF("stat_rdev    ", struct stat, st_rdev);
  DEF_OFFSETOF("stat_size    ", struct stat, st_size);
  DEF_OFFSETOF("stat_blksize ", struct stat, st_blksize);
  DEF_OFFSETOF("stat_blocks  ", struct stat, st_blocks);
  DEF_OFFSETOF("stat_atime   ", struct stat, st_atim);
  DEF_OFFSETOF("stat_mtime   ", struct stat, st_mtim);
  DEF_OFFSETOF("stat_ctime   ", struct stat, st_ctim);

  fprintf(output, "\n# Definitions for `struct shmid_ds`:\n");
  DEF_SIZEOF_TYPE("struct_shmid_ds", struct shmid_ds);
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
  {
    struct shmid_ds ds;
    DEF_TYPEOF_LVALUE("shm_segsz      ", ds.shm_segsz);
    DEF_TYPEOF_LVALUE("shm_perm_mode  ", ds.shm_perm.mode);
  }

  fprintf(output, "\n# Definitions for `struct semid_ds`:\n");
  DEF_SIZEOF_TYPE("struct_semid_ds", struct semid_ds);
  DEF_OFFSETOF("sem_perm_uid ", struct semid_ds, sem_perm.uid);
  DEF_OFFSETOF("sem_perm_gid ", struct semid_ds, sem_perm.gid);
  DEF_OFFSETOF("sem_perm_cuid", struct semid_ds, sem_perm.cuid);
  DEF_OFFSETOF("sem_perm_cgid", struct semid_ds, sem_perm.cgid);
  DEF_OFFSETOF("sem_perm_mode", struct semid_ds, sem_perm.mode);
  DEF_OFFSETOF("sem_otime    ", struct semid_ds, sem_otime);
  DEF_OFFSETOF("sem_ctime    ", struct semid_ds, sem_ctime);
  DEF_OFFSETOF("sem_nsems    ", struct semid_ds, sem_nsems);
  {
    struct semid_ds ds;
    DEF_TYPEOF_LVALUE("sem_nsems      ", ds.sem_nsems);
    DEF_TYPEOF_LVALUE("sem_perm_mode  ", ds.sem_perm.mode);
  }

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

  fprintf(output, "\n# Definitions for POSIX semaphores:\n");
  DEF_SIZEOF_TYPE("sem_t", sem_t);
  fprintf(output, "const SEM_FAILED    = Ptr{Void}(%ld)\n", (long)SEM_FAILED);
  {
    long val = -1;
#ifdef _SC_SEM_VALUE_MAX
    if (val < 0) {
      val = sysconf(_SC_SEM_VALUE_MAX);
    }
#endif
#ifdef SEM_VALUE_MAX
    if (val < 0) {
      val = SEM_VALUE_MAX;
    }
#endif
    if (val > 0) {
      fprintf(output, "const SEM_VALUE_MAX = Cuint(%ld)\n", val);
    } else {
      fprintf(output, "const SEM_VALUE_MAX = typemax(Cuint)\n");
    }
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

  fprintf(output, "\n# Constants for POSIX semaphores:\n");
  DEF_CONST(SEM_FAILED, "    = Cint(%p)");
#endif

  return 0;
}
