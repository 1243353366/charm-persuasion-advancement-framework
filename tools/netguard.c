/*
 * netguard — LD_PRELOAD shim that makes all outbound networking fail.
 *
 * Purpose: a runtime proof that the scanners never use the network. Run a
 * scanner under this shim; if the report is unchanged, the tool made no
 * network call (a successful connection would have aborted the run).
 *
 * Applies to dynamically linked binaries: the C scanner, Python, Java.
 * Go's static binary does not honor LD_PRELOAD — it is covered by the
 * capability audit in tools/verify.sh and by the reproducible build instead.
 *
 * Build:   cc -shared -fPIC -O2 -o netguard.so netguard.c
 * Use:     LD_PRELOAD=./netguard.so ./darkscan input.txt
 */
#define _GNU_SOURCE
#include <errno.h>
#include <netdb.h>
#include <stddef.h>
#include <sys/socket.h>

int socket(int domain, int type, int protocol)
{
    (void)domain; (void)type; (void)protocol;
    errno = EAFNOSUPPORT;
    return -1;
}

int connect(int fd, const struct sockaddr *addr, socklen_t len)
{
    (void)fd; (void)addr; (void)len;
    errno = ENETUNREACH;
    return -1;
}

int getaddrinfo(const char *node, const char *service,
                const struct addrinfo *hints, struct addrinfo **res)
{
    (void)node; (void)service; (void)hints; (void)res;
    return EAI_FAIL;
}
