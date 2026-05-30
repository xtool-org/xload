#ifndef CXLoad_h
#define CXLoad_h

#import <stdint.h>

typedef struct {
    const void * _Nullable value;
    uint8_t state;
} AGValue;

// MARK: - declared in Swift

void xload_load();
const void * _Nonnull xload_get_DebugReplaceableView_init_orig(void);
// Swift also declares `xload_wrap_DebugReplaceableView` but it's not cdecl

// MARK: - declared in C
const void * _Nonnull xload_get_DebugReplaceableView_init_hook(void);

#endif
