/*
 * part of downgr8 by throwaway96
 * licensed under AGPL 3.0 or later
 * https://github.com/throwaway96/downgr8
 */

/*
 * Exits with EXIT_SUCCESS if target is found and patched.
 * Exits with EXIT_FAILURE on error or if target not found.
 */

#include <stdlib.h>
#include <stddef.h>
#include <stdio.h>
#include <stdbool.h>
#include <inttypes.h> /* includes stdint.h */
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <limits.h>
#include <fcntl.h>
#include <sys/mman.h>

static const char target[] = "luna://com.webos.service.sm/accessusb/getStatus";
static const char replacement[] = "luna://" DEFAULT_APP_ID ".service/fakeusb/getStatus";

static_assert(sizeof(replacement) <= sizeof(target), "replacement longer than target");

static FILE *fp_maps = NULL;
static FILE *fp_mem = NULL;

static int process_maps(void);
static int process_range(uintptr_t start, uintptr_t end);
static ptrdiff_t find_target(const void *buf, size_t len);
static bool overwrite_target(uintptr_t addr);

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <pid>\n", argv[0]);
        return EXIT_FAILURE;
    }

    /* try to stop output from getting out of order */
    setvbuf(stdout, NULL, _IOLBF, 0);
    setvbuf(stderr, NULL, _IOLBF, 0);

    int pid = atoi(argv[1]);

    if (pid < 0) {
        fprintf(stderr, "error: pid can't be negative (%d)\n", pid);
        return EXIT_FAILURE;
    }

    char path_maps[PATH_MAX];
    char path_mem[PATH_MAX];

    snprintf(path_maps, sizeof(path_maps), "/proc/%d/maps", pid);
    snprintf(path_mem, sizeof(path_mem), "/proc/%d/mem", pid);

    if ((fp_maps = fopen(path_maps, "r")) == NULL) {
        perror("fopen");
        return EXIT_FAILURE;
    }

    /* it's not really necessary to track these separately right now... */
    bool error = false, found = false;

    if ((fp_mem = fopen(path_mem, "r+")) == NULL) {
        perror("fopen");
        error = true;
        goto cleanup_maps;
    }

    int ret = process_maps();

    if (ret == 1) {
        found = true;
    } else if (ret < 0) {
        error = true;
    }

    if (fclose(fp_mem) != 0) {
        perror("fclose");
        error = true;
    }

cleanup_maps:
    if (fclose(fp_maps) != 0) {
        perror("fclose");
        error = true;
    }

    return (error || !found) ? EXIT_FAILURE : EXIT_SUCCESS;
}

/* returns 1 when target found, 0 when not found, and -1 on error */
static int process_maps(void) {
    ssize_t bytes_read = 0;
    char *line = NULL;
    size_t line_len = 0;
    unsigned int line_num = 0;
    bool error = false, found = false;

    /*
     * getline() terminates the line, and we don't care about the possibility of
     * embedded null bytes
     */
    while ((bytes_read = getline(&line, &line_len, fp_maps)) >= 0) {
        line_num++;

        char *name = NULL;
        uintptr_t start = 0, end = 0;
        char perms[5] = { '\0' };

        int conv = sscanf(line, "%"SCNxPTR"-%"SCNxPTR" %4c %*x %*2x:%*2x %*u %ms", &start, &end, perms, &name);

        bool name_match = false;

        if (name != NULL) {
            name_match = (strcmp(name, "/usr/sbin/update") == 0);
            /* get this out of the way to simplify error handling later */
            free(name);
            name = NULL;
        }

        if ((perms[0] == 'r') && name_match) {
            int ret = process_range(start, end);

            if (ret == 1) {
                /* break because match found */
                found = true;
                break;
            } else if (ret < 0) {
                /* break on error */
                error = true;
                break;
            }
        } else if ((conv != 4) && (conv != 3)) {
            fprintf(stderr, "error on line %u: %d fields found\n", line_num, conv);
        }
    }

    /* don't complain on EOF */
    if ((bytes_read < 0) && (feof(fp_maps) == 0)) {
        perror("getline");
        error = true;
    }

    if (line != NULL) {
        free(line);
    }

    return error ? -1 : (found ? 1 : 0);
}

/* returns 1 when target found, 0 when not found, and -1 on error */
static int process_range(uintptr_t start, uintptr_t end) {
    assert(end >= start);

    size_t len = end - start;

#ifdef DEBUG
    printf("%#"PRIxPTR"-%#"PRIxPTR"\n", start, end);
#endif

    /* don't bother trying to read a length of 0 */
    if (len == 0) {
        return 0;
    }

    if (fseeko(fp_mem, start, SEEK_SET) != 0) {
        perror("fseeko");
        return -1;
    }

    void *buf = malloc(len);

    if (buf == NULL) {
        perror("malloc");
        return -1;
    }

    size_t bytes_read = fread(buf, 1, len, fp_mem);

    if (bytes_read != len) {
        if (feof(fp_mem) != 0) {
            fprintf(stderr, "unexpected EOF reading memory (%zu/%zu bytes read)\n", bytes_read, len);
        } else if (ferror(fp_mem) != 0) {
            fprintf(stderr, "error reading memory (%zu/%zu bytes read)\n", bytes_read, len);
        } else {
            fprintf(stderr, "short read from memory for unknown reason (%zu/%zu bytes read)\n", bytes_read, len);
        }

        free(buf);

        return -1;
    }

    ptrdiff_t diff = find_target(buf, len);

    free(buf);

    if (diff != -1) {
        assert(diff >= 0);

        uintptr_t offset = start + diff;
        printf("found diff %#08"PRIxPTR"; final offset %#08"PRIxPTR"\n", (uintptr_t) diff, offset);

        /* either successfully overwritten or error */
        return overwrite_target(offset) ? 1 : -1;
    }

    /* didn't find target */
    return 0;
}

/* returns offset of target in buf if found, -1 otherwise */
static ptrdiff_t find_target(const void *buf, size_t len) {
    assert(buf != NULL);

    const void *addr = memmem(buf, len, target, sizeof(target));

    if (addr != NULL) {
        assert(addr >= buf);

        return addr - buf;
    } else {
        return -1;
    }
}

static bool overwrite_target(uintptr_t addr) {
    assert(addr != 0);

    /* XXX: no easy way to get maximum off_t */
    off_t offset = addr;

    if (fseeko(fp_mem, offset, SEEK_SET) != 0) {
        perror("fseeko");
        return false;
    }

    size_t len = sizeof(replacement);

    size_t bytes_written = fwrite(replacement, 1, len, fp_mem);

    if (bytes_written != len) {
        if (ferror(fp_mem) != 0) {
            fprintf(stderr, "error writing replacement to memory (%zu/%zu bytes written)\n", bytes_written, len);
        } else if (feof(fp_mem) != 0) {
            fprintf(stderr, "unexpected EOF(?) writing memory (%zu/%zu bytes written)\n", bytes_written, len);
        } else {
            fprintf(stderr, "short write to memory for unknown reason (%zu/%zu bytes written)\n", bytes_written, len);
        }

        return false;
    }

    return true;
}
