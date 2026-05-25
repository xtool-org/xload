#include "CXLoad.h"

__attribute__((constructor)) static void ctor() {
    xload_load();
}
