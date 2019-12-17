/*
 * gendeps.c --
 *
 * Generate definitions for the IPC.jl package.
 *
 *------------------------------------------------------------------------------
 *
 * This file is part of IPC.jl released under the MIT "expat" license.
 * Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/IPC.jl).
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
#include <signal.h>

#define TRUE  1
#define FALSE 0

#ifdef __APPLE__
# define st_atim st_atimespec
# define st_mtim st_mtimespec
# define st_ctim st_ctimespec
# define sigval_t union sigval
# define clockid_t uint32_t
#endif
#ifndef CLOCK_REALTIME
# define CLOCK_REALTIME 0
#endif
#ifndef CLOCK_MONOTONIC
# define CLOCK_MONOTONIC 1
#endif


/* Determine the offset of a field in a structure. */
#define OFFSET_OF(type, field) ((char*)&((type*)0)->field - (char*)0)

/* Determine whether an integer type is signed. */
#define IS_SIGNED(type)        ((type)(~(type)0) < (type)0)

/* Compare 2 integer types. */
#define SAME_INTEGER_TYPE(a, b) (sizeof(a) == sizeof(b) && \
                                 IS_SIGNED(a) == IS_SIGNED(b))

/* Set all the bits of an L-value. */
#define SET_ALL_BITS(lval) lval = 0; lval = ~lval

/* Define a Julia constant. */
#define DEF_CONST(name, format) \
  fprintf(output, "const " #name format "\n", name)
#define DEF_CONST_CAST(name, format, type) \
  fprintf(output, "const " #name format "\n", (type)name)

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

static void setofbits(FILE* output, const char* name,
                      int size, int isunsigned)
{
  int nitems, nbits;

  if (size % 8 == 0) {
    nitems = size/8;
    nbits = 64;
  } else if (size % 4 == 0) {
    nitems = size/4;
    nbits = 32;
  } else if (size % 2 == 0) {
    nitems = size/2;
    nbits = 16;
  } else {
    nitems = size;
    nbits = 8;
  }
  fprintf(output, "const %s = NTuple{%d,%sInt%d}\n",
          name, nitems, (isunsigned ? "U" : ""), nbits);
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

#define PUTS(str) fputs(str "\n", output)
  PUTS("#");
  PUTS("# deps.jl --");
  PUTS("#");
  PUTS("# Definitions for the IPC.jl package.");
  PUTS("#");
  PUTS("# *IMPORTANT* This file has been automatically generated, do not edit it");
  PUTS("#             directly but rather modify the source in `../deps/gendeps.c`.");
  PUTS("#");
  PUTS("#------------------------------------------------------------------------------");
  PUTS("#");
  PUTS("# This file is part of IPC.jl released under the MIT \"expat\" license.");
  PUTS("# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/IPC.jl).");
  PUTS("#");
  PUTS("");
  PUTS("# Standard codes returned by many functions of the C library:");
  PUTS("const SUCCESS = Cint( 0)");
  PUTS("const FAILURE = Cint(-1)");

  PUTS("\n# Some standard C-types:");
  DEF_TYPEOF_TYPE(time_t, "   ");
  DEF_TYPEOF_TYPE(clock_t, "  ");
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

  PUTS("\n# Bits for creating/opening a file:");
  DEF_CONST(O_RDONLY, " = Cint(0o%04o)");
  DEF_CONST(O_WRONLY, " = Cint(0o%04o)");
  DEF_CONST(O_RDWR, "   = Cint(0o%04o)");
  DEF_CONST(O_CREAT, "  = Cint(0o%04o)");
  DEF_CONST(O_EXCL, "   = Cint(0o%04o)");
  DEF_CONST(O_TRUNC, "  = Cint(0o%04o)");

  PUTS("\n# Bits for file permissions:");
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

  PUTS("\n# Argument for `lseek`:");
  DEF_CONST(SEEK_SET, " = Cint(%d) # offset is relative to the beginning");
  DEF_CONST(SEEK_CUR, " = Cint(%d) # offset is relative to current position");
  DEF_CONST(SEEK_END, " = Cint(%d) # offset is relative to the end");

  PUTS("\n# Commands for `shmctl`, `semctl` and `msgctl`:");
  DEF_CONST(IPC_STAT, " = Cint(%d)");
  DEF_CONST(IPC_SET, "  = Cint(%d)");
  DEF_CONST(IPC_RMID, " = Cint(%d)");

  PUTS("\n# Bits for `shmget`:");
  DEF_CONST(IPC_CREAT, " = Cint(0o%04o)");
  DEF_CONST(IPC_EXCL, "  = Cint(0o%04o)");

  PUTS("\n# Flags for `shmdt`:");
#ifdef SHM_EXEC
  DEF_CONST(SHM_EXEC, "   = Cint(%d)");
#endif
  DEF_CONST(SHM_RDONLY, " = Cint(%d)");
#ifdef SHM_EXEC
  DEF_CONST(SHM_REMAP, "  = Cint(%d)");
#endif

  PUTS("\n# Constants for `mmap`, `msync`, etc.:");
  DEF_CONST(PROT_NONE, "     = Cint(%d)");
  DEF_CONST(PROT_READ, "     = Cint(%d)");
  DEF_CONST(PROT_WRITE, "    = Cint(%d)");
  DEF_CONST(PROT_EXEC, "     = Cint(%d)");
  DEF_CONST(MAP_SHARED, "    = Cint(%d)");
  DEF_CONST(MAP_PRIVATE, "   = Cint(%d)");
  DEF_CONST(MAP_ANONYMOUS, " = Cint(%d)"); /* FIXME: non-POSIX? */
  DEF_CONST(MAP_FIXED, "     = Cint(%d)");
  fprintf(output, "const MAP_FAILED    = Ptr{Cvoid}(%ld)\n", (long)MAP_FAILED);
  DEF_CONST(MS_ASYNC, "      = Cint(%d)");
  DEF_CONST(MS_SYNC, "       = Cint(%d)");
  DEF_CONST(MS_INVALIDATE, " = Cint(%d)");

  PUTS("\n# Memory page size:");
  fprintf(output, "PAGE_SIZE = %ld\n", (long)sysconf(_SC_PAGESIZE));

  PUTS("\n# Fields of `struct timeval` and `struct timespec`:");
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

  PUTS("\n# Definitions for the POSIX `clock_*` functions:");
  DEF_TYPEOF_TYPE(clockid_t, "");
  DEF_CONST(CLOCK_REALTIME, "  = convert(_typeof_clockid_t, %d)");
  DEF_CONST(CLOCK_MONOTONIC, " = convert(_typeof_clockid_t, %d)");

  PUTS("\n# Sizes and constants for POSIX thread functions:");
  DEF_SIZEOF_TYPE("pthread_mutex_t      ", pthread_mutex_t);
  DEF_SIZEOF_TYPE("pthread_mutexattr_t  ", pthread_mutexattr_t);
  DEF_SIZEOF_TYPE("pthread_cond_t       ", pthread_cond_t);
  DEF_SIZEOF_TYPE("pthread_condattr_t   ", pthread_condattr_t);
  DEF_SIZEOF_TYPE("pthread_rwlock_t     ", pthread_rwlock_t);
  DEF_SIZEOF_TYPE("pthread_rwlockattr_t ", pthread_rwlockattr_t);
  DEF_CONST(PTHREAD_PROCESS_SHARED, "  = %d");
  DEF_CONST(PTHREAD_PROCESS_PRIVATE, " = %d");

  PUTS("\n# Definitions for `struct stat`:");
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

  PUTS("\n# Definitions for `struct shmid_ds`:");
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

  PUTS("\n# Definitions for `struct semid_ds`:");
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

  PUTS("\n# Special IPC key:");
  DEF_CONST(IPC_PRIVATE, " = _typeof_key_t(%d)");

  PUTS("\n# Flags for `semctl`:");
  DEF_CONST(GETALL, "  = Cint(%d)");
  DEF_CONST(GETNCNT, " = Cint(%d)");
  DEF_CONST(GETPID, "  = Cint(%d)");
  DEF_CONST(GETVAL, "  = Cint(%d)");
  DEF_CONST(GETZCNT, " = Cint(%d)");
  DEF_CONST(SETALL, "  = Cint(%d)");
  DEF_CONST(SETVAL, "  = Cint(%d)");

  PUTS("\n# Flags for `semop`:");
  DEF_CONST(IPC_NOWAIT, " = Cshort(%d)");
  DEF_CONST(SEM_UNDO, "   = Cshort(%d)");

  PUTS("\n# Other constants for System V Semaphore Sets:");
#ifndef SEMVMX
# define SEMVMX  32767  /* FIXME: determine this automatically */
#endif
#ifdef SEMVMX
  DEF_CONST(SEMVMX, "= %d # semaphore maximum value");
#endif
#ifdef SEMMNI
  DEF_CONST(SEMMNI, "= %d # max. numb. of semaphore identifiers");
#endif
#ifdef SEMMSL
  DEF_CONST(SEMMSL, "= %d # max. numb. of semaphores per id");
#endif
#ifdef SEMMNS
  DEF_CONST(SEMMNS, "= %d # max. numb. of semaphores in system");
#endif
#ifdef SEMOPM
  DEF_CONST(SEMOPM, "= %d # max. numb. of ops per semop call");
#endif
#ifdef SEMAEM
  DEF_CONST(SEMAEM, "= %d # adjust on exit max value");
#endif

  PUTS("\n# Constants for `struct sembuf`:");
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

  PUTS("\n# Definitions for POSIX semaphores:");
  DEF_SIZEOF_TYPE("sem_t", sem_t);
  fprintf(output, "const SEM_FAILED    = Ptr{Cvoid}(%ld)\n", (long)SEM_FAILED);
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
      PUTS("const SEM_VALUE_MAX = typemax(Cuint)");
    }
  }

#if 0
  PUTS("\n# Constants for `union semnum`:");
  {
    union semnum {
      int val;
      void* ptr;
    } sn;
    DEF_SIZEOF_TYPE("union_semnum", union semnum);
    DEF_OFFSETOF("semnum_val", union semnum, val);
    DEF_OFFSETOF("semnum_ptr", union semnum, ptr);
  }

  PUTS("\n# Semaphore limits:");
  DEF_CONST(SEMMNI, "= %-6d # max. number of semaphore sets");
  DEF_CONST(SEMMSL, "= %-6d # max. number of semaphores per semaphore set");
  DEF_CONST(SEMMNS, "= %-6d # max. number of semaphores");

  PUTS("\n# Constants for POSIX semaphores:");
  DEF_CONST(SEM_FAILED, "    = Cint(%p)");
#endif

  PUTS("\n# Definitions for real-time signals:");
#ifdef SIGRTMIN
  DEF_CONST(SIGRTMIN, "    = Cint(%d)");
#endif
#ifdef SIGRTMAX
  DEF_CONST(SIGRTMAX, "    = Cint(%d)");
#endif
#ifdef SIG_BLOCK
  DEF_CONST(SIG_BLOCK, "   = Cint(%d)");
#endif
#ifdef SIG_UNBLOCK
  DEF_CONST(SIG_UNBLOCK, " = Cint(%d)");
#endif
#ifdef SIG_SETMASK
  DEF_CONST(SIG_SETMASK, " = Cint(%d)");
#endif
  fprintf(output, "const _typeof_sigval_t  = Int%d\n",
          8*(int)sizeof(sigval_t));

  setofbits(output, "_typeof_sigset", sizeof(sigset_t), TRUE);
  DEF_SIZEOF_TYPE("sigset   ", sigset_t);

  PUTS("\n# Definitions for `struct sigaction`:");
  {
    struct sigaction sa;
    DEF_SIZEOF_TYPE("sigaction", struct sigaction);
    DEF_OFFSETOF("sigaction_handler", struct sigaction, sa_handler);
    DEF_OFFSETOF("sigaction_action ", struct sigaction, sa_sigaction);
    DEF_OFFSETOF("sigaction_mask   ", struct sigaction, sa_mask);
    DEF_OFFSETOF("sigaction_flags  ", struct sigaction, sa_flags);
#if 0 /* non-POSIX */
    DEF_OFFSETOF("sigaction_restorer", struct sigaction, sa_restorer);
#endif
#if 1 /* force sigaction flags to be unsigned */
    fprintf(output, "const _typeof_sigaction_flags     = UInt%d\n",
            8*(int)sizeof(sa.sa_flags));
#else
    DEF_TYPEOF_LVALUE("sigaction_flags    ", sa.sa_flags);
#endif
  }

  DEF_CONST(SA_SIGINFO, "   = _typeof_sigaction_flags(0x%08x)");
  DEF_CONST(SA_NOCLDSTOP, " = _typeof_sigaction_flags(0x%08x)");
  DEF_CONST(SA_NOCLDWAIT, " = _typeof_sigaction_flags(0x%08x)");
  DEF_CONST(SA_NODEFER, "   = _typeof_sigaction_flags(0x%08x)");
  DEF_CONST(SA_ONSTACK, "   = _typeof_sigaction_flags(0x%08x)");
  DEF_CONST(SA_RESETHAND, " = _typeof_sigaction_flags(0x%08x)");
  DEF_CONST(SA_RESTART, "   = _typeof_sigaction_flags(0x%08x)");

  DEF_CONST_CAST(SIG_DFL, " = Ptr{Cvoid}(%lu)", unsigned long);
  DEF_CONST_CAST(SIG_IGN, " = Ptr{Cvoid}(%lu)", unsigned long);

  PUTS("\n# Definitions for `siginfo_t`:");
  {
    siginfo_t si;
    if (sizeof(si.si_signo) != sizeof(int)) {
      fprintf(stderr, "sizeof((siginfo_t).si_signo) != sizeof(int)\n");
      exit(1);
    }
    if (sizeof(si.si_code) != sizeof(int)) {
      fprintf(stderr, "sizeof((siginfo_t).si_code) != sizeof(int)\n");
      exit(1);
    }
    if (sizeof(si.si_errno) != sizeof(int)) {
      fprintf(stderr, "sizeof((siginfo_t).si_errno) != sizeof(int)\n");
      exit(1);
    }
    if (sizeof(si.si_pid) != sizeof(pid_t)) {
      fprintf(stderr, "sizeof((siginfo_t).si_pid) != sizeof(pid_t)\n");
      exit(1);
    }
    if (sizeof(si.si_uid) != sizeof(uid_t)) {
      fprintf(stderr, "sizeof((siginfo_t).si_uid) != sizeof(uid_t)\n");
      exit(1);
    }
    if (sizeof(si.si_status) != sizeof(int)) {
      fprintf(stderr, "sizeof((siginfo_t).si_status) != sizeof(int)\n");
      exit(1);
    }
    if (sizeof(si.si_value) != sizeof(sigval_t)) {
      fprintf(stderr, "sizeof((siginfo_t).si_value) != sizeof(sigval_t)\n");
      exit(1);
    }
    if (sizeof(si.si_addr) != sizeof(void*)) {
      fprintf(stderr, "sizeof((siginfo_t).si_addr) != sizeof(void*)\n");
      exit(1);
    }
    if (sizeof(si.si_band) != sizeof(long)) {
      fprintf(stderr, "sizeof((siginfo_t).si_band) != sizeof(long)\n");
      exit(1);
    }
#if 0 /* Ignore non-POSIX members */
    if (sizeof(si.si_utime) != sizeof(clock_t)) {
      fprintf(stderr, "sizeof((siginfo_t).si_utime) != sizeof(clock_t)\n");
      exit(1);
    }
    if (sizeof(si.si_stime) != sizeof(clock_t)) {
      fprintf(stderr, "sizeof((siginfo_t).si_stime) != sizeof(clock_t)\n");
      exit(1);
    }
#endif
  }
  setofbits(output, "_typeof_siginfo", sizeof(siginfo_t), TRUE);
  DEF_SIZEOF_TYPE("siginfo", siginfo_t);
  DEF_OFFSETOF("siginfo_signo  ", siginfo_t, si_signo);
  DEF_OFFSETOF("siginfo_code   ", siginfo_t, si_code);
  DEF_OFFSETOF("siginfo_errno  ", siginfo_t, si_errno);
  DEF_OFFSETOF("siginfo_pid    ", siginfo_t, si_pid);
  DEF_OFFSETOF("siginfo_uid    ", siginfo_t, si_uid);
  DEF_OFFSETOF("siginfo_status ", siginfo_t, si_status);
  DEF_OFFSETOF("siginfo_value  ", siginfo_t, si_value);
  DEF_OFFSETOF("siginfo_addr   ", siginfo_t, si_addr);
  DEF_OFFSETOF("siginfo_band   ", siginfo_t, si_band);
#if 0 /* Ignore non-POSIX members */
  DEF_OFFSETOF("siginfo_utime  ", siginfo_t, si_utime);
  DEF_OFFSETOF("siginfo_stime  ", siginfo_t, si_stime);
  DEF_OFFSETOF("siginfo_int    ", siginfo_t, si_int);
  DEF_OFFSETOF("siginfo_ptr    ", siginfo_t, si_ptr);
  DEF_OFFSETOF("siginfo_overrun", siginfo_t, si_overrun);
  DEF_OFFSETOF("siginfo_timerid", siginfo_t, si_timerid);
  DEF_OFFSETOF("siginfo_fd     ", siginfo_t, si_fd);
#endif

  PUTS("\n# Possible `si_code` values for regular signals:");
#ifdef SI_USER
  DEF_CONST(SI_USER, " = Cint(%d) # kill(2).");
#endif
#ifdef SI_KERNEL
    DEF_CONST(SI_KERNEL, " = Cint(%d) # Sent by the kernel.");
#endif
#ifdef SI_QUEUE
  DEF_CONST(SI_QUEUE, " = Cint(%d) # sigqueue(3).");
#endif
#ifdef SI_TIMER
  DEF_CONST(SI_TIMER, " = Cint(%d) # POSIX timer expired.");
#endif
#ifdef SI_MESGQ
  DEF_CONST(SI_MESGQ, " = Cint(%d) # POSIX message queue state changed; see mq_notify(3).");
#endif
#ifdef SI_ASYNCIO
  DEF_CONST(SI_ASYNCIO, " = Cint(%d) # AIO completed.");
#endif
#ifdef SI_SIGIO
  DEF_CONST(SI_SIGIO, " = Cint(%d) # Queued  SIGIO.");
#endif
#ifdef SI_TKILL
  DEF_CONST(SI_TKILL, " = Cint(%d) # tkill(2) or tgkill(2).");
#endif

  PUTS("\n# Possible `si_code` values for a SIGILL signal:");
#ifdef ILL_ILLOPC
  DEF_CONST(ILL_ILLOPC, " = Cint(%d) # Illegal opcode.");
#endif
#ifdef ILL_ILLOPN
  DEF_CONST(ILL_ILLOPN, " = Cint(%d) # Illegal operand.");
#endif
#ifdef ILL_ILLADR
  DEF_CONST(ILL_ILLADR, " = Cint(%d) # Illegal addressing mode.");
#endif
#ifdef ILL_ILLTRP
  DEF_CONST(ILL_ILLTRP, " = Cint(%d) # Illegal trap.");
#endif
#ifdef ILL_PRVOPC
  DEF_CONST(ILL_PRVOPC, " = Cint(%d) # Privileged opcode.");
#endif
#ifdef ILL_PRVREG
  DEF_CONST(ILL_PRVREG, " = Cint(%d) # Privileged register.");
#endif
#ifdef ILL_COPROC
  DEF_CONST(ILL_COPROC, " = Cint(%d) # Coprocessor error.");
#endif
#ifdef ILL_BADSTK
  DEF_CONST(ILL_BADSTK, " = Cint(%d) # Internal stack error.");
#endif

  PUTS("\n# Possible `si_code` values for a SIGFPE signal:");
#ifdef FPE_INTDIV
  DEF_CONST(FPE_INTDIV, " = Cint(%d) # Integer divide by zero.");
#endif
#ifdef FPE_INTOVF
  DEF_CONST(FPE_INTOVF, " = Cint(%d) # Integer overflow.");
#endif
#ifdef FPE_FLTDIV
  DEF_CONST(FPE_FLTDIV, " = Cint(%d) # Floating-point divide by zero.");
#endif
#ifdef FPE_FLTOVF
  DEF_CONST(FPE_FLTOVF, " = Cint(%d) # Floating-point overflow.");
#endif
#ifdef FPE_FLTUND
  DEF_CONST(FPE_FLTUND, " = Cint(%d) # Floating-point underflow.");
#endif
#ifdef FPE_FLTRES
  DEF_CONST(FPE_FLTRES, " = Cint(%d) # Floating-point inexact result.");
#endif
#ifdef FPE_FLTINV
  DEF_CONST(FPE_FLTINV, " = Cint(%d) # Floating-point invalid operation.");
#endif
#ifdef FPE_FLTSUB
  DEF_CONST(FPE_FLTSUB, " = Cint(%d) # Subscript out of range.");
#endif

  PUTS("\n# Possible `si_code` values for a SIGSEGV signal:");
#ifdef SEGV_MAPERR
  DEF_CONST(SEGV_MAPERR, " = Cint(%d) # Address not mapped to object.");
#endif
#ifdef SEGV_ACCERR
  DEF_CONST(SEGV_ACCERR, " = Cint(%d) # Invalid permissions for mapped object.");
#endif

  PUTS("\n# Possible `si_code` values for a SIGBUS signal:");
#ifdef BUS_ADRALN
  DEF_CONST(BUS_ADRALN, " = Cint(%d) # Invalid address alignment.");
#endif
#ifdef BUS_ADRERR
  DEF_CONST(BUS_ADRERR, " = Cint(%d) # Nonexistent physical address.");
#endif
#ifdef BUS_OBJERR
  DEF_CONST(BUS_OBJERR, " = Cint(%d) # Object-specific hardware error.");
#endif
#ifdef BUS_MCEERR_AR
  DEF_CONST(BUS_MCEERR_AR, " = Cint(%d) # Hardware memory error consumed on a machine check; action required.");
#endif
#ifdef BUS_MCEERR_AO
  DEF_CONST(BUS_MCEERR_AO, " = Cint(%d) # Hardware memory error detected in process but not consumed; action optional.");
#endif

  PUTS("\n# Possible `si_code` values for a SIGTRAP signal:");
#ifdef TRAP_BRKPT
  DEF_CONST(TRAP_BRKPT, " = Cint(%d) # Process breakpoint.");
#endif
#ifdef TRAP_TRACE
  DEF_CONST(TRAP_TRACE, " = Cint(%d) # Process trace trap.");
#endif
#ifdef TRAP_BRANCH
  DEF_CONST(TRAP_BRANCH, " = Cint(%d) # Process taken branch trap.");
#endif
#ifdef TRAP_HWBKPT
  DEF_CONST(TRAP_HWBKPT, " = Cint(%d) # Hardware breakpoint/watchpoint.");
#endif

  PUTS("\n# Possible `si_code` values for a SIGCHLD signal:");
#ifdef CLD_EXITED
  DEF_CONST(CLD_EXITED, " = Cint(%d) # Child has exited.");
#endif
#ifdef CLD_KILLED
  DEF_CONST(CLD_KILLED, " = Cint(%d) # Child was killed.");
#endif
#ifdef CLD_DUMPED
  DEF_CONST(CLD_DUMPED, " = Cint(%d) # Child terminated abnormally.");
#endif
#ifdef CLD_TRAPPED
  DEF_CONST(CLD_TRAPPED, " = Cint(%d) # Traced child has trapped.");
#endif
#ifdef CLD_STOPPED
  DEF_CONST(CLD_STOPPED, " = Cint(%d) # Child has stopped.");
#endif
#ifdef CLD_CONTINUED
  DEF_CONST(CLD_CONTINUED, " = Cint(%d) # Stopped child has continued.");
#endif

  PUTS("\n# Possible `si_code` values for a SIGIO/SIGPOLL signal:");
#ifdef POLL_IN
  DEF_CONST(POLL_IN, " = Cint(%d) # Data input available.");
#endif
#ifdef POLL_OUT
  DEF_CONST(POLL_OUT, " = Cint(%d) # Output buffers available.");
#endif
#ifdef POLL_MSG
  DEF_CONST(POLL_MSG, " = Cint(%d) # Input message available.");
#endif
#ifdef POLL_ERR
  DEF_CONST(POLL_ERR, " = Cint(%d) # I/O error.");
#endif
#ifdef POLL_PRI
  DEF_CONST(POLL_PRI, " = Cint(%d) # High priority input available.");
#endif
#ifdef POLL_HUP
  DEF_CONST(POLL_HUP, " = Cint(%d) # Device disconnected.");
#endif

#ifdef SYS_SECCOMP
  PUTS("\n# Possible `si_code` value for a SIGSYS signal:");
  DEF_CONST(SYS_SECCOMP, " = Cint(%d) # Triggered by a seccomp(2) filter rule.");
#endif

  PUTS("\n# Predefined signal numbers:");
#ifdef SIGHUP
  DEF_CONST(SIGHUP, "    = Cint(%2d) # Hangup detected on controlling terminal or death of controlling process");
#endif
#ifdef SIGINT
  DEF_CONST(SIGINT, "    = Cint(%2d) # Interrupt from keyboard");
#endif
#ifdef SIGQUIT
  DEF_CONST(SIGQUIT, "   = Cint(%2d) # Quit from keyboard");
#endif
#ifdef SIGILL
  DEF_CONST(SIGILL, "    = Cint(%2d) # Illegal Instruction");
#endif
#ifdef SIGABRT
  DEF_CONST(SIGABRT, "   = Cint(%2d) # Abort signal from abort(3)");
#endif
#ifdef SIGFPE
  DEF_CONST(SIGFPE, "    = Cint(%2d) # Floating point exception");
#endif
#ifdef SIGKILL
  DEF_CONST(SIGKILL, "   = Cint(%2d) # Kill signal");
#endif
#ifdef SIGSEGV
  DEF_CONST(SIGSEGV, "   = Cint(%2d) # Invalid memory reference");
#endif
#ifdef SIGPIPE
  DEF_CONST(SIGPIPE, "   = Cint(%2d) # Broken pipe: write to pipe with no readers");
#endif
#ifdef SIGALRM
  DEF_CONST(SIGALRM, "   = Cint(%2d) # Timer signal from alarm(2)");
#endif
#ifdef SIGTERM
  DEF_CONST(SIGTERM, "   = Cint(%2d) # Termination signal");
#endif
#ifdef SIGUSR
  DEF_CONST(SIGUSR1, "   = Cint(%2d) # User-defined signal 1");
#endif
#ifdef SIGUSR
  DEF_CONST(SIGUSR2, "   = Cint(%2d) # User-defined signal 2");
#endif
#ifdef SIGCHLD
  DEF_CONST(SIGCHLD, "   = Cint(%2d) # Child stopped or terminated");
#endif
#ifdef SIGCONT
  DEF_CONST(SIGCONT, "   = Cint(%2d) # Continue if stopped");
#endif
#ifdef SIGSTOP
  DEF_CONST(SIGSTOP, "   = Cint(%2d) # Stop process");
#endif
#ifdef SIGTSTP
  DEF_CONST(SIGTSTP, "   = Cint(%2d) # Stop typed at terminal");
#endif
#ifdef SIGTTIN
  DEF_CONST(SIGTTIN, "   = Cint(%2d) # Terminal input for background process");
#endif
#ifdef SIGTTOU
  DEF_CONST(SIGTTOU, "   = Cint(%2d) # Terminal output for background process");
#endif
#ifdef SIGBUS
  DEF_CONST(SIGBUS, "    = Cint(%2d) # Bus error (bad memory access)");
#endif
#ifdef SIGPOLL
  DEF_CONST(SIGPOLL, "   = Cint(%2d) # Pollable event (Sys V).  Synonym for SIGIO");
#endif
#ifdef SIGPROF
  DEF_CONST(SIGPROF, "   = Cint(%2d) # Profiling timer expired");
#endif
#ifdef SIGSYS
  DEF_CONST(SIGSYS, "    = Cint(%2d) # Bad argument to routine (SVr4)");
#endif
#ifdef SIGTRAP
  DEF_CONST(SIGTRAP, "   = Cint(%2d) # Trace/breakpoint trap");
#endif
#ifdef SIGURG
  DEF_CONST(SIGURG, "    = Cint(%2d) # Urgent condition on socket (4.2BSD)");
#endif
#ifdef SIGVTALRM
  DEF_CONST(SIGVTALRM, " = Cint(%2d) # Virtual alarm clock (4.2BSD)");
#endif
#ifdef SIGXCPU
  DEF_CONST(SIGXCPU, "   = Cint(%2d) # CPU time limit exceeded (4.2BSD)");
#endif
#ifdef SIGXFSZ
  DEF_CONST(SIGXFSZ, "   = Cint(%2d) # File size limit exceeded (4.2BSD)");
#endif
#ifdef SIGIOT
  DEF_CONST(SIGIOT, "    = Cint(%2d) # IOT trap. A synonym for SIGABRT");
#endif
#ifdef SIGEMT
  DEF_CONST(SIGEMT, "    = Cint(%2d) # ");
#endif
#ifdef SIGSTKFLT
  DEF_CONST(SIGSTKFLT, " = Cint(%2d) # Stack fault on coprocessor (unused)");
#endif
#ifdef SIGIO
  DEF_CONST(SIGIO, "     = Cint(%2d) # I/O now possible (4.2BSD)");
#endif
#ifdef SIGCLD
  DEF_CONST(SIGCLD, "    = Cint(%2d) # A synonym for SIGCHLD");
#endif
#ifdef SIGPWR
  DEF_CONST(SIGPWR, "    = Cint(%2d) # Power failure (System V)");
#endif
#ifdef SIGINFO
  DEF_CONST(SIGINFO, "   = Cint(%2d) # A synonym for SIGPWR");
#endif
#ifdef SIGLOST
  DEF_CONST(SIGLOST, "   = Cint(%2d) # File lock lost (unused)");
#endif
#ifdef SIGWINCH
  DEF_CONST(SIGWINCH, "  = Cint(%2d) # Window resize signal (4.3BSD, Sun)");
#endif
#ifdef SIGUNUSED
  DEF_CONST(SIGUNUSED, " = Cint(%2d) # Synonymous with SIGSYS");
#endif

  return 0;
}
