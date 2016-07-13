/*
 * swl.h --
 *
 * Definitions for the Simple Wrapper Library.
 *
 */

#ifndef _SWL_H
#define _SWL_H 1

#define SWL_SUCCESS   0
#define SWL_FAILURE (-1)


#define SWL_PRIVATE 0

/* For SWL_GetSharedMemory */
#define SWL_CREAT   0001000U /* Create a new entry for the key if none already
                                exists. */
#define SWL_EXCL    0002000U /* Generate an error if there already exists an
                                entry for the key. */

/* For SWL_AttachSharedMemory */
#define SWL_RDONLY  0010000U /* read-only access */


#include <stdlib.h>
#include <stdint.h>

/**
 * Generate a System V IPC key from a pathname and a project identifier.
 *
 * This routines generates a key that is suitable for System V Inter-Process
 * Communication (IPC) facilities (message queues, semaphores and shared
 * memory).
 *
 * @param path - a path to an existing acessible file.
 * @param proj - a project identifer, only the least significant 8 bits
 *               (which must be nonzero) are significant.
 *
 * @return On success, the generated System V IPC key is returned.  On failure,
 *         -1 is returned, with `errno` indicating the error.
 */
extern int SWL_GenerateKey(const char* path, int proj);

/*--------------------------------------------------------------------------*/
/* SHARED MEMORY */

/**
 * Allocate a shared memory segment.
 *
 * This function returns the identifier of the shared memory segment associated
 * with the value of the argument `key`.  A new shared memory segment, with
 * size equal to the value of `siz` (possibly rounded up to a multiple of the
 * memory page size), is created if `key` has the value `SWL_PRIVATE` or `key`
 * isn't `SWL_PRIVATE`, no shared memory segment corresponding to `key` exists,
 * and `SWL_CREAT` is specified in argument `flg`.
 *
 * Any process which need to access to a shared memory segment must attach this
 * segment to its address space with `SWL_AttachSharedMemory` and detach the
 * shared memory segment when access is no longer needed.  To attach a shared
 * memory segment, a process must have access granted for this segment.  These
 * permissions are specified by the least significant bits of argument `flg`
 * and can be changed by calling `SWL_ConfigureSharedMemory`.  When a process
 * exits, its attached memory segments are automatically detached but, by
 * default, a created shared memory segment exists forever.  Call
 * `SWL_DestroySharedMemory` to ensure that a shared memory segment be
 * destroyed when no more processes are attached to it.  Make sure to have at
 * least one attched process before calling `SWL_DestroySharedMemory` otherwise
 * the shared memory segment will be immediately destroyed.
 *
 * @param key - The System V IPC key associated with the shared memory
 *              segment.  Can be `SWL_PRIVATE` to create a new shared memory
 *              segment.
 *
 * @param siz - The size (in bytes) of the shared memory segment (may be
 *              rounded up to multiple of the memory page size).
 *
 * @param flg - Some bitwise flags.  The least significant 9 bits specify the
 *              permissions granted to the owner, group, and others.  These
 *              bits have the same format, and the same meaning, as the mode
 *              argument of `chmod`.  Bit `SWL_CREAT` can be set to create a
 *              new segment.  If this flag is not used, then
 *              `SWL_GetSharedMemory` will find the segment associated with
 *              `key` and check to see if the user has permission to access the
 *              segment.  Bit `SWL_EXCL` can be set in addition to `SWL_CREAT`
 *              to ensure that this call creates the segment.  If the segment
 *              already exists, the call fails.
 *
 * @return On success, a valid shared memory identifier is returned.  On error,
 *         -1 is returned, and `errno` is set to indicate the error.
 *
 * Example:
 *     id = SWL_GetSharedMemory(SWL_PRIVATE, siz, 0640);
 *     ptr = SWL_AttachSharedMemory(id, 0, NULL);
 */
extern int SWL_GetSharedMemory(int key, size_t siz, unsigned int flg);

/* Structure to store shared memory information (members in decreasing order of
   size). */
typedef struct _SWL_SharedMemoryInfo {
    uint64_t atime;  /* last attach time */
    uint64_t dtime;  /* last detach time */
    uint64_t ctime;  /* last change time */
    uint64_t segsz;  /* size of the public area */
    int32_t  id;     /* shared memory identifier */
    int32_t  cpid;   /* process ID of creator */
    int32_t  lpid;   /* process ID of last operator */
    int32_t  nattch; /* no. of current attaches */
    uint32_t mode;   /* lower 9 bits of access modes */
    uint32_t uid;    /* effective user ID of owner */
    uint32_t gid;    /* effective group ID of owner */
    uint32_t cuid;   /* effective user ID of creator */
    uint32_t cgid;   /* effective group ID of creator */
} SWL_SharedMemoryInfo;

/**
 * Attach a shared memory segment to the address space of the calling process.
 *
 * The caller get an address to access the shared memory and should call
 * `SWL_DetachSharedMemory` when access to the shared memory is no longer
 * needed.
 *
 * @param id   - The identifier of the shared memory segment.
 *
 * @param flg  - Some bitwise flags.  The only available flag is `SWL_RDONLY`
 *               to attach the segment for read-only access.  If this flag is
 *               not specified, the segment is attached for read and write
 *               access, and the process must have read and write permission
 *               for the segment.
 *
 * @param info - The address of a structure to retrieve shared memory
 *               information, can be `NULL` to not retrieve any information.
 *               The contents of `info` is undetermined in case of error.
 *
 * @return On success, the address to the attached memory.  On error,
 *         `(void*)-1` -1 is returned, and `errno` is set to indicate the
 *         error.
 */
extern void* SWL_AttachSharedMemory(int id, unsigned int flg,
                                    SWL_SharedMemoryInfo* info);

/**
 * Detach a shared memory segment from the address space of the calling
 * process.
 *
 * @param ptr  - The address to which the shared memory segment is attached.
 *
 * @return On success, `SWL_SUCCESS` is returned.  On error, `SWL_ERROR`
 *         is returned, and `errno` is set to indicate the error.
 */
extern int SWL_DetachSharedMemory(void* ptr);

/**
 * Mark a shared memory segment to be destroyed.
 *
 * Insure that a shared memory segment is eventually destroyed when it is no
 * longer attached to any process.  The caller must be the owner or creator of
 * the segment, or be privileged.  Make sure to have at least one attched
 * process before calling this function, otherwise the shared memory segment
 * will be immediately destroyed.
 *
 * @param id  - The identifier of the shared memory segment.
 *
 * @return On success, `SWL_SUCCESS` is returned.  On error, `SWL_ERROR`
 *         is returned, and `errno` is set to indicate the error.
 */
extern int SWL_DestroySharedMemory(int id);

/**
 * Retrieve information about a shared memory segment.
 *
 * @param id   - The identifier of the shared memory segment.
 *
 * @param info - The address of a structure to retrieve information about the
 *               shared memory segment, can be `NULL` to not retrieve any
 *               information (for instance, to check the validity of `id`).
 *               The contents of `info` is undetermined in case of error.
 *
 * @return On success, `SWL_SUCCESS` is returned.  On error, `SWL_ERROR`
 *         is returned, and `errno` is set to indicate the error.
 */
extern int SWL_QuerySharedMemoryInfo(int id, SWL_SharedMemoryInfo *info);

/**
 * Configure a shared memory segment.
 *
 * @param id  - The identifier of the shared memory segment.
 *
 * @param flg - Some bitwise flags.  The least significant 9 bits specify the
 *              permissions granted to the owner, group, and others.  These
 *              bits have the same format, and the same meaning, as the mode
 *              argument of `chmod`.
 *
 * @return On success, `SWL_SUCCESS` is returned.  On error, `SWL_ERROR`
 *         is returned, and `errno` is set to indicate the error.
 */
extern int SWL_ConfigureSharedMemory(int id, unsigned int flg);

#endif /* _SWL_H */
