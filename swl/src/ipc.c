/*
 * ipc.c --
 *
 * Simple wrappers for System V Inter-Process Communication (IPC).
 *
 */

#include "swl.h"
#include <errno.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#define BITCONV(flg, bit, val)  (((flg)&(bit)) == (bit) ? (val) : 0U)

#define MODE_MASK 0777U

int SWL_GenerateKey(const char* path, int proj)
{
  key_t key;
  int res;

  if ((proj & 255) == 0) {
    errno = EINVAL;
    return -1;
  }
  key = ftok(path, proj);
  if (key == -1) {
    return -1;
  }
  res = (int)key;
  if (res != key) {
    errno = EINVAL;
    return -1;
  }
  return res;
}

/*--------------------------------------------------------------------------*/
/* SHARED MEMORY */

int SWL_GetSharedMemory(int key, size_t siz, unsigned int flg)
{
  int shmflg;

  shmflg = ((flg & MODE_MASK) |
            BITCONV(flg, SWL_CREAT, IPC_CREAT) |
            BITCONV(flg, SWL_EXCL,  IPC_EXCL));
  if (key == SWL_PRIVATE) {
    key = IPC_PRIVATE;
  }
  return shmget(key, siz, shmflg);
}

void* SWL_AttachSharedMemory(int id, unsigned int flg,
                             SWL_SharedMemoryInfo* info)
{
  void* ptr;
  int shmflg;

  shmflg = BITCONV(flg, SWL_RDONLY, SHM_RDONLY);
  ptr = shmat(id, NULL, shmflg);
  if (ptr != (void*)-1 && info != NULL &&
      SWL_QuerySharedMemoryInfo(id, info) != SWL_SUCCESS) {
    (void)shmdt(ptr);
    ptr = (void*)-1;
  }
  return ptr;
}

int SWL_DetachSharedMemory(void* ptr)
{
  return (shmdt(ptr) == 0 ? SWL_SUCCESS : SWL_FAILURE);
}

int SWL_DestroySharedMemory(int id)
{
  return (shmctl(id, IPC_RMID, NULL) == 0 ? SWL_SUCCESS : SWL_FAILURE);
}

int SWL_QuerySharedMemoryInfo(int id, SWL_SharedMemoryInfo* info)
{
  struct shmid_ds ds;

  if (shmctl(id, IPC_STAT, &ds) == -1) {
    return SWL_FAILURE;
  }
  if (info != NULL) {
    info->atime  = ds.shm_atime;
    info->dtime	 = ds.shm_dtime;
    info->ctime	 = ds.shm_ctime;
    info->id	 = id;
    info->cpid   = ds.shm_cpid;
    info->lpid   = ds.shm_lpid;
    info->segsz  = ds.shm_segsz;
    info->nattch = ds.shm_nattch;
    info->mode	 = ds.shm_perm.mode;
    info->uid	 = ds.shm_perm.uid;
    info->gid	 = ds.shm_perm.gid;
    info->cuid   = ds.shm_perm.cuid;
    info->cgid   = ds.shm_perm.cuid;
  }
  return SWL_SUCCESS;
}

int SWL_ConfigureSharedMemory(int id, unsigned int flg)
{
  struct shmid_ds ds;

  if (shmctl(id, IPC_STAT, &ds) == -1) {
    return SWL_FAILURE;
  }
  if ((ds.shm_perm.mode & MODE_MASK) != (flg & MODE_MASK)) {
    ds.shm_perm.mode = (ds.shm_perm.mode & ~MODE_MASK) | (flg & MODE_MASK);
    if (shmctl(id, IPC_SET, &ds) == -1) {
      return SWL_FAILURE;
    }
  }
  return SWL_SUCCESS;
}
