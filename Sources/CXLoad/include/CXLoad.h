#ifndef CXLoad_h
#define CXLoad_h

#include <stdint.h>

typedef struct {
    const void *value;
    uint8_t state;
} AGValue;

void xload_load();

#endif
