#ifndef CXLoad_h
#define CXLoad_h

// MARK: - declared in Swift

void xload_load();
// Swift also declares `xload_wrap_view` but it's not cdecl

// MARK: - declared in C
void xload_install_hooks();

#endif
