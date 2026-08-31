#ifndef C_HEADERS_H
#define C_HEADERS_H

#include <strophe.h>
#include <stdint.h>

struct handlist_t {
    /* common members */
    int user_handler;
    void *handler;
    void *userdata;
    int enabled; /* handlers are added disabled and enabled after the
                  * handler chain is processed to prevent stanzas from
                  * getting processed by newly added handlers */
    struct handlist_t *next;

    union {
        /* timed handlers */
        struct {
            unsigned long period;
            uint64_t last_stamp;
        };
        /* id handlers */
        struct {
            char *id;
        };
        /* normal handlers */
        struct {
            char *ns;
            char *name;
            char *type;
        };
    } u;
};

typedef enum {
    XMPP_LOOP_NOTSTARTED,
    XMPP_LOOP_RUNNING,
    XMPP_LOOP_QUIT
} loop_status_t;

typedef struct connlist_t {
    xmpp_conn_t *conn;
    struct connlist_t *next;
};

struct ctx_t {
    const xmpp_mem_t *mem;
    const xmpp_log_t *log;
    int verbosity;

    xmpp_rand_t *rand;
    loop_status_t loop_status;
    struct connlist_t *connlist;
    struct handlist_t *timed_handlers;

    unsigned long timeout;
};

#endif
