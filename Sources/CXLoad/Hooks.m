#import <dispatch/dispatch.h>
#import <os/lock.h>
#import "CXLoad.h"

typedef void *OpaqueValue;
typedef const void *SwiftMetadata;
typedef const void *SwiftWitnessTable;

typedef struct {
    void *storage;
} AnyView; // observed as one word on arm64 here

typedef AnyView __attribute__((swiftcall)) (*AnyViewInitFn)(
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
);

typedef void __attribute__((swiftcall)) (*DebugReplaceableInitFn)(
    OpaqueValue result __attribute__((swift_indirect_result)),
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
);

AnyView __attribute__((swiftcall)) xload_wrap_view(
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
);

extern const void $s7SwiftUI7AnyViewVN;
extern const void $s7SwiftUI7AnyViewVAA0D0AAWP;

extern void MSHookFunction(void *symbol, void *hook, void **old);

static os_unfair_lock hookLock = OS_UNFAIR_LOCK_INIT;
static AnyViewInitFn orig_AnyView_init;
static DebugReplaceableInitFn orig_DebugReplaceableView_init;

// MARK: - AnyView hook

// AnyView.init<V: View>(_: V)
extern void $s7SwiftUI7AnyViewVyACxcAA0D0RzlufC(void);

static __thread bool wants_original_AnyView_init = false;

__attribute__((swiftcall))
static AnyView shim_AnyView_init(
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
) {
    if (wants_original_AnyView_init) {
        wants_original_AnyView_init = false;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            os_unfair_lock_lock(&hookLock);
            os_unfair_lock_unlock(&hookLock);
        });
        return orig_AnyView_init(view, viewType, viewWitness);
    } else {
        wants_original_AnyView_init = true;
        return xload_wrap_view(view, viewType, viewWitness);
    }
}

// MARK: - DebugReplaceableView hook

// DebugReplaceableView.init<V: View>(_erasing: V)
API_AVAILABLE(ios(26), macos(26))
extern void $s7SwiftUI20DebugReplaceableViewV8_erasingACx_tcAA0E0RzlufC(void);

__attribute__((swiftcall))
static void shim_DebugReplaceableView_init(
    OpaqueValue result __attribute__((swift_indirect_result)),
    OpaqueValue view,
    SwiftMetadata viewType,
    SwiftWitnessTable viewWitness
) {
    wants_original_AnyView_init = true;
    AnyView wrapped = xload_wrap_view(view, viewType, viewWitness);

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        os_unfair_lock_lock(&hookLock);
        os_unfair_lock_unlock(&hookLock);
    });

    orig_DebugReplaceableView_init(result, &wrapped, &$s7SwiftUI7AnyViewVN, &$s7SwiftUI7AnyViewVAA0D0AAWP);
}

// MARK: - Install

void xload_install_hooks(void) {
    // the hook functions aren't guaranteed to be atomic:
    // it's possible that the hooks are applied *before*
    // the orig values are stored. so we need to protect
    // the entire operation with a lock.

    os_unfair_lock_lock(&hookLock);

    MSHookFunction(&$s7SwiftUI7AnyViewVyACxcAA0D0RzlufC,
                   shim_AnyView_init,
                   (void **)&orig_AnyView_init);

    if (@available(iOS 26, macOS 26, *)) {
        MSHookFunction(&$s7SwiftUI20DebugReplaceableViewV8_erasingACx_tcAA0E0RzlufC,
                       shim_DebugReplaceableView_init,
                       (void **)&orig_DebugReplaceableView_init);
    }

    os_unfair_lock_unlock(&hookLock);
}
