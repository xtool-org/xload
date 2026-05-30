#import <dispatch/dispatch.h>
#import "CXLoad.h"

typedef void *OpaqueValue;
typedef const void *SwiftMetadata;
typedef const void *SwiftWitnessTable;

typedef struct {
    void *storage;
} AnyView; // observed as one word on arm64 here

typedef void __attribute__((swiftcall)) (*DebugReplaceableInitFn)(
    OpaqueValue result __attribute__((swift_indirect_result)),
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
);

extern const void $s7SwiftUI7AnyViewVN;
extern const void $s7SwiftUI7AnyViewVAA0D0AAWP;

AnyView __attribute__((swiftcall)) xload_wrap_DebugReplaceableView(
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
);

__attribute__((swiftcall))
static void shim_DebugReplaceableView_init(
    OpaqueValue result __attribute__((swift_indirect_result)),
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
) {
    AnyView wrapped = xload_wrap_DebugReplaceableView(view, viewType, viewWitness);

    static DebugReplaceableInitFn orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        orig = xload_get_DebugReplaceableView_init_orig();
    });

    orig(result,
         &wrapped,
         (SwiftMetadata)&$s7SwiftUI7AnyViewVN,
         (SwiftWitnessTable)&$s7SwiftUI7AnyViewVAA0D0AAWP);

    // Do not destroy `wrapped` here. The original initializer destroys
    // the generic argument it receives, so it consumes this local AnyView.
}

const void *xload_get_DebugReplaceableView_init_hook(void) {
    return shim_DebugReplaceableView_init;
}
