{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information

 Summary:
   Dlluminator loads Win64 DLLs directly from memory, bypassing the
   filesystem entirely. It supports loading single DLLs from raw byte
   buffers, loading multiple interdependent DLLs with automatic dependency
   resolution, and embedding DLLs as RT_RCDATA resources in the executable
   for zero-file deployment.

 Remarks:
   The unit hooks NT native API functions (NtMapViewOfSection,
   NtQueryVirtualMemory, NtManageHotPatch) to redirect the Windows loader
   into mapping a pre-allocated memory region instead of a file on disk.
   After loading, standard WinAPI calls (GetProcAddress, FreeLibrary) work
   as normal.

   For multi-DLL scenarios where one memory-loaded module imports from
   another (e.g. sdl3_image.dll importing from sdl3.dll), Dlluminator
   provides a data registry and automatic topological dependency resolution.
   DLLs can be registered in any order via RegisterDllData, then loaded
   with a single call to LoadAll. The loader parses each DLL's PE import
   table, recursively loads dependencies depth-first, resolves imports
   manually via the internal module registry, and calls each DLL's entry
   point in the correct order.

   On Windows 11 24H2+ (build 26200+), internal loader data structures
   changed in ways that broke traditional post-hoc name patching. Dlluminator
   works around this by hooking LdrGetDllHandle and LdrLoadDll to intercept
   module lookups, and by re-linking the LdrpHashTable entry to the correct
   bucket after patching BaseDllName and FullDllName.

 Key Features:
   - LoadLibrary (basic): Loads a DLL from a raw memory buffer without
     touching the disk. Returns a standard HMODULE compatible with
     GetProcAddress and FreeLibrary.
   - LoadLibrary (named): Loads a DLL from memory and registers it under a
     module name, enabling other memory-loaded DLLs to import from it.
   - RegisterDllData (pointer): Registers raw DLL bytes for deferred loading.
     Nothing is loaded until LoadLibrary(name) or LoadAll is called.
   - RegisterDllData (resource): Registers a DLL by RT_RCDATA resource name.
     The resource is read on demand during loading, then freed immediately.
   - LoadLibrary (by name): Loads a registered DLL by name, automatically
     resolving and loading all registered dependencies first using depth-first
     topological sorting of PE import tables.
   - LoadAll: Loads every registered DLL in the correct dependency order with
     a single call.
   - Circular dependency detection with ERROR_CIRCULAR_DEPENDENCY reporting.
   - Manual IAT resolution for memory-loaded module chains, falling back to
     the Windows API for system DLLs.
   - Module name patching with LdrpHashTable bucket re-linking so the Windows
     loader can find memory-loaded modules by name.
   - Persistent LdrGetDllHandle and LdrLoadDll hooks for robust module lookup
     on Windows 11 24H2+.
   - Post-load flags: NO_HEADERS (zero PE headers), NO_MODLIST (unlink from
     PEB loader lists), NO_THDCALL (disable thread callbacks), OVRHDRS
     (overwrite headers from the original file).
   - Companion CImporter tool (Dlluminator.CImporter unit) for converting C
     headers into Delphi import units that use Dlluminator for loading.

 Inspired by:
   perfect-loader - https://github.com/EvanMcBroom/perfect-loader

 Changelog:

   Version 0.2.0
     - Added named LoadLibrary overload with AModuleName parameter for
       cross-DLL dependency resolution between memory-loaded modules
     - Added RegisterDllData (pointer and resource overloads) for deferred
       DLL registration without immediate loading
     - Added LoadLibrary(AModuleName) with automatic depth-first topological
       dependency resolution by parsing raw PE import tables
     - Added LoadAll to load every registered DLL in correct dependency order
     - Added circular dependency detection and ERROR_CIRCULAR_DEPENDENCY
     - Added manual IAT resolution (ManualResolveImports) for resolving
       imports across memory-loaded modules
     - Added module name patching (PatchModuleName) with LdrpHashTable
       bucket re-linking using RtlHashUnicodeString
     - Added persistent LdrGetDllHandle hook for module lookup redirection
       on Windows 11 24H2+ where internal loader structures changed
     - Added persistent LdrLoadDll hook for import resolver redirection
     - Added NtQueryVirtualMemory hook for MemoryImageExtensionInformation
       compatibility on Windows 11 24H2+
     - Added NtManageHotPatch hook for hotpatch query compatibility
     - Added internal module registry (name-to-handle map, 64 entries)
     - Added internal data registry (name-to-data/resource map, 64 entries)
     - Added post-load flags: LOAD_FLAGS_NO_HEADERS, LOAD_FLAGS_NO_MODLIST,
       LOAD_FLAGS_NO_THDCALL, LOAD_FLAGS_OVRHDRS
     - Added ParseImportsFromRawPE and RvaToFileOffset for reading import
       tables from unmapped PE data
     - Added HasRegisteredDependencies check
     - Added CallModuleEntryPoint for manual DllMain invocation

   Version 0.1.0
     - Initial release with basic memory DLL loading via NtMapViewOfSection
       hook and LoadLibraryExW redirection

===============================================================================}


unit Dlluminator;

// Platform directive: Ensures this unit is compiled only for Win64 targets.
{$IFNDEF WIN64}
  // Generates a compile-time error if the target platform is not Win64
  {$MESSAGE Error 'Unsupported platform'}
{$ENDIF}

{$Z4}  // Sets the default enumeration size to 4 bytes (DWORD).
{$A8}  // Sets the alignment for record fields to 8 bytes (important for x64 structures).

interface

// --- Version Constants ---

const
  /// <summary>
  /// Major version of the Dlluminator library.
  /// </summary>
  /// <remarks>
  /// This represents the main version number, typically updated for significant changes or milestones.
  /// </remarks>
  DLLUMINATOR_MAJOR_VERSION = '0';

  /// <summary>
  /// Minor version of the Dlluminator library.
  /// </summary>
  /// <remarks>
  /// This is incremented for smaller, incremental improvements or updates.
  /// </remarks>
  DLLUMINATOR_MINOR_VERSION = '2';

  /// <summary>
  /// Patch version of the Dlluminator library.
  /// </summary>
  /// <remarks>
  /// This number increases for bug fixes or minor improvements that do not affect major or minor versions.
  /// </remarks>
  DLLUMINATOR_PATCH_VERSION = '0';

  /// <summary>
  /// Full version string of the Dlluminator library, formatted as Major.Minor.Patch.
  /// </summary>
  /// <remarks>
  /// This combines the major, minor, and patch versions into a single version string.
  /// </remarks>
  DLLUMINATOR_VERSION = DLLUMINATOR_MAJOR_VERSION + '.' + DLLUMINATOR_MINOR_VERSION + '.' + DLLUMINATOR_PATCH_VERSION;

// --- Public Functions ---

/// <summary>
///   Loads a DLL directly from a memory buffer into the current process's address space.
/// </summary>
/// <param name="AData">
///   Pointer to the memory block containing the raw binary data of the DLL. This memory block must contain
///   the complete and valid Win64 DLL image.
/// </param>
/// <param name="ASize">
///   The size, in bytes, of the DLL binary data pointed to by <c>AData</c>.
/// </param>
/// <returns>
///   Returns a handle (<c>HMODULE</c>) to the loaded DLL module if successful. If the function fails, it returns <c>0</c>.
///   The returned handle can be used with standard WinAPI functions like <c>GetProcAddress</c> and <c>FreeLibrary</c>.
/// </returns>
/// <remarks>
///   This function serves as a memory-based replacement for the standard WinAPI <c>LoadLibrary</c> function.
///   It manually maps the DLL image from the provided buffer into memory, resolves imports (implicitly via a hooked LoadLibraryEx call),
///   and returns a handle that behaves like a standard module handle. It bypasses the need for the DLL file to exist on the disk.
///   The underlying mechanism involves manually mapping the PE structure, hooking `NtMapViewOfSection`, calling `LoadLibraryExW` on a dummy file
///   to trigger the Windows loader's import resolution and initialization, intercepting the mapping call to provide the manually mapped image,
///   and then unhooking.
/// </remarks>
/// <exception>
///   If the function fails, the Windows error code can be retrieved using <c>GetLastError</c>.
///   Common failure reasons include invalid or corrupted DLL data (not a valid PE image), insufficient memory,
///   failure to hook necessary API functions, or internal loader errors during the `LoadLibraryExW` call.
/// </exception>
/// <preconditions>
///   <list type="bullet">
///     <item><description>The memory block pointed to by <c>AData</c> must contain a valid Win64 PE DLL image.</description></item>
///     <item><description>The size specified in <c>ASize</c> must accurately reflect the size of the DLL data in the buffer.</description></item>
///     <item><description>The application must have sufficient permissions to allocate memory (`VirtualAlloc`), modify memory protection (`VirtualProtect`), and potentially hook API functions.</description></item>
///   </list>
/// </preconditions>
/// <postconditions>
///   <list type="bullet">
///     <item><description>If successful, the DLL is loaded into the process's address space, and its DllMain (if present) has been called for process attach.</description></item>
///     <item><description>The returned handle (<c>HMODULE</c>) can be used with <c>GetProcAddress</c> to find exported functions.</description></item>
///     <item><description><c>FreeLibrary</c> should be called on the returned handle when the DLL is no longer needed to properly unload it.</description></item>
///   </list>
/// </postconditions>
/// <seealso>
///   <c>FreeLibrary</c>, <c>GetProcAddress</c>
/// </seealso>
function LoadLibrary(const AData: Pointer; const ASize: NativeUInt): THandle; overload;

/// <summary>
///   Loads a DLL from memory and registers it under a specified module name,
///   enabling dependency resolution between memory-loaded DLLs.
/// </summary>
/// <param name="AData">
///   Pointer to the raw DLL binary data in memory.
/// </param>
/// <param name="ASize">
///   Size in bytes of the DLL data pointed to by <c>AData</c>.
/// </param>
/// <param name="AModuleName">
///   The module name to register (e.g., <c>'MyLib.dll'</c>). This is the
///   name that other DLLs will reference in their import tables when they
///   depend on this module. Must include the <c>.dll</c> extension and match
///   the exact name used in the dependent DLL's <c>external</c> declaration.
/// </param>
/// <returns>
///   Returns an <c>HMODULE</c> handle if successful, or <c>0</c> on failure.
///   Use <c>GetProcAddress</c> with the returned handle to resolve exports.
///   Call <c>FreeLibrary</c> when the module is no longer needed.
/// </returns>
/// <remarks>
///   <para>
///     <b>Loading Order:</b> Dependencies must be loaded <b>before</b> the
///     DLLs that import from them. For example, if DllB imports from DllA,
///     load DllA first with its registered name, then load DllB:
///   </para>
///   <code>
///     // Step 1: Load the dependency first and register its name.
///     DllAHandle := LoadLibrary(DllAData, DllASize, 'DllA.dll');
///
///     // Step 2: Load the dependent DLL. Its import table references
///     // 'DllA.dll', which is resolved against the registered module.
///     DllBHandle := LoadLibrary(DllBData, DllBSize, 'DllB.dll');
///
///     // Both are now fully functional — DllB can call DllA's exports.
///     MyFunc := GetProcAddress(DllBHandle, 'MyFunction');
///   </code>
///   <para>
///     <b>How It Works:</b> When the loaded DLL has dependencies on previously
///     registered modules, this function uses manual import resolution. The
///     DLL is mapped into memory with relocations applied but without the
///     Windows loader resolving imports. Dlluminator then walks the DLL's
///     import table, resolving each imported function — using the internal
///     module registry for memory-loaded DLLs and the standard Windows API
///     for system DLLs. Finally, the DLL's entry point (DllMain) is called.
///   </para>
///   <para>
///     This approach is required because Windows 11 24H2 changed internal
///     loader data structures, making post-hoc module name patching
///     insufficient for the loader's own import resolver.
///   </para>
/// </remarks>
function LoadLibrary(const AData: Pointer; const ASize: NativeUInt;
  const AModuleName: string): THandle; overload;

/// <summary>
///   Registers raw DLL binary data for deferred loading into the internal data registry.
///   This function does NOT load the DLL — it only stores a reference to the data so that
///   it can be loaded later by <c>LoadLibrary(AModuleName)</c> or <c>LoadAll</c>.
/// </summary>
/// <param name="AModuleName">
///   The module name to associate with this DLL data (e.g., <c>'MyLib.dll'</c>). This name
///   must match the exact name used in dependent DLLs' <c>external</c> declarations, including
///   the <c>.dll</c> extension. The name is case-insensitive.
/// </param>
/// <param name="AData">
///   Pointer to the memory block containing the complete raw binary data of the DLL.
///   The caller retains ownership of this memory and must ensure it remains valid and
///   unmodified until <c>LoadLibrary(AModuleName)</c> or <c>LoadAll</c> is called for this
///   module. After loading completes, the original data is no longer needed.
/// </param>
/// <param name="ASize">
///   The size, in bytes, of the DLL binary data pointed to by <c>AData</c>. Must accurately
///   reflect the size of the complete DLL image.
/// </param>
/// <remarks>
///   <para>
///     This is the pointer-based registration overload. Use it when you already have the DLL
///     data in memory (e.g., from a custom resource loader, decryption routine, or network
///     download). For DLLs embedded as <c>RT_RCDATA</c> resources in the executable, the
///     resource-based overload <c>RegisterDllData(AModuleName, AResName)</c> is more convenient.
///   </para>
///   <para>
///     Multiple DLLs can be registered in any order — dependency ordering is resolved
///     automatically when <c>LoadLibrary(AModuleName)</c> or <c>LoadAll</c> is called.
///     If a module with the same name is already registered, its data reference is updated.
///   </para>
///   <para>
///     The data registry has a fixed capacity of 64 entries. If the registry is full,
///     the registration is silently ignored and a debug message is emitted via
///     <c>OutputDebugString</c>.
///   </para>
/// </remarks>
/// <preconditions>
///   <list type="bullet">
///     <item><description><c>AData</c> must point to a valid, complete Win64 PE DLL image.</description></item>
///     <item><description><c>ASize</c> must accurately reflect the size of the data at <c>AData</c>.</description></item>
///     <item><description>The memory at <c>AData</c> must remain valid until the module is loaded.</description></item>
///   </list>
/// </preconditions>
/// <postconditions>
///   <list type="bullet">
///     <item><description>The module name and data reference are stored in the internal data registry.</description></item>
///     <item><description>No DLL loading, mapping, or import resolution occurs.</description></item>
///   </list>
/// </postconditions>
/// <seealso>
///   <c>RegisterDllData(AModuleName, AResName)</c>, <c>LoadLibrary(AModuleName)</c>, <c>LoadAll</c>
/// </seealso>
procedure RegisterDllData(const AModuleName: string; const AData: Pointer;
  const ASize: NativeUInt); overload;

/// <summary>
///   Registers a DLL for deferred loading by referencing an embedded <c>RT_RCDATA</c>
///   resource in the executable. This function does NOT load the DLL — it only stores the
///   resource name so that the resource can be read and loaded on demand when
///   <c>LoadLibrary(AModuleName)</c> or <c>LoadAll</c> is called.
/// </summary>
/// <param name="AModuleName">
///   The module name to associate with this DLL (e.g., <c>'MyLib.dll'</c>). This name
///   must match the exact name used in dependent DLLs' <c>external</c> declarations, including
///   the <c>.dll</c> extension. The name is case-insensitive.
/// </param>
/// <param name="AResName">
///   The name of the <c>RT_RCDATA</c> resource containing the DLL binary data, as it appears
///   in the executable's resource table. This can be a descriptive name or an obfuscated
///   identifier (e.g., a GUID-like string) to avoid exposing DLL names in the binary.
/// </param>
/// <remarks>
///   <para>
///     This is the resource-based registration overload. It validates that the specified
///     resource exists at registration time via <c>FindResource</c>, but does not read or
///     copy the resource data. When <c>LoadLibrary(AModuleName)</c> or <c>LoadAll</c> is
///     called, a <c>TResourceStream</c> is created on demand to read the resource data,
///     the DLL is loaded from that data, and the stream is freed immediately afterwards.
///     This avoids holding resource data in memory longer than necessary.
///   </para>
///   <para>
///     Multiple DLLs can be registered in any order — dependency ordering is resolved
///     automatically when <c>LoadLibrary(AModuleName)</c> or <c>LoadAll</c> is called.
///     If a module with the same name is already registered, its resource reference is updated.
///   </para>
///   <code>
///     // Register DLLs from resources (order doesn't matter).
///     RegisterDllData('DllA.dll', 'a1b2c3d4e5f6478890abcdef12345678');
///     RegisterDllData('DllB.dll', 'f8e7d6c5b4a3219087654321fedcba98');
///
///     // Load everything — dependencies resolved automatically.
///     LoadAll();
///   </code>
///   <para>
///     The data registry has a fixed capacity of 64 entries. If the registry is full,
///     the registration is silently ignored and a debug message is emitted via
///     <c>OutputDebugString</c>.
///   </para>
/// </remarks>
/// <exception>
///   If the resource specified by <c>AResName</c> does not exist in the executable,
///   the registration is silently skipped and a debug message is emitted. No exception
///   is raised. The subsequent <c>LoadLibrary</c> or <c>LoadAll</c> call will fail for
///   this module with <c>ERROR_FILE_NOT_FOUND</c>.
/// </exception>
/// <preconditions>
///   <list type="bullet">
///     <item><description>The resource identified by <c>AResName</c> must exist as <c>RT_RCDATA</c> in the current module (<c>HInstance</c>).</description></item>
///     <item><description>The resource must contain a valid, complete Win64 PE DLL image.</description></item>
///   </list>
/// </preconditions>
/// <postconditions>
///   <list type="bullet">
///     <item><description>The module name and resource name are stored in the internal data registry.</description></item>
///     <item><description>No DLL loading, resource reading, mapping, or import resolution occurs.</description></item>
///   </list>
/// </postconditions>
/// <seealso>
///   <c>RegisterDllData(AModuleName, AData, ASize)</c>, <c>LoadLibrary(AModuleName)</c>, <c>LoadAll</c>
/// </seealso>
procedure RegisterDllData(const AModuleName: string;
  const AResName: string); overload;

/// <summary>
///   Loads a DLL by name from the internal data registry, automatically resolving
///   and loading all dependencies in the correct order before loading the requested module.
/// </summary>
/// <param name="AModuleName">
///   The module name to load (e.g., <c>'MyLib.dll'</c>). This must match a name previously
///   registered via <c>RegisterDllData</c>. The name is case-insensitive.
/// </param>
/// <returns>
///   Returns an <c>HMODULE</c> handle to the loaded DLL module if successful, or <c>0</c>
///   on failure. If the module was already loaded by a previous call, the existing handle
///   is returned immediately without reloading. The returned handle can be used with
///   <c>GetProcAddress</c> and <c>FreeLibrary</c>.
/// </returns>
/// <remarks>
///   <para>
///     <b>Automatic Dependency Resolution:</b> This function parses the raw PE import table
///     of the requested DLL to discover its dependencies. For each dependency that is also
///     present in the data registry but not yet loaded, it recursively calls itself to load
///     that dependency first (depth-first topological sort). Dependencies not found in the
///     data registry are assumed to be system DLLs and are resolved later by
///     <c>ManualResolveImports</c> via <c>GetModuleHandle</c> / standard <c>LoadLibrary</c>.
///   </para>
///   <para>
///     <b>Resource-Based Entries:</b> For modules registered via the resource-based
///     <c>RegisterDllData(AModuleName, AResName)</c> overload, a <c>TResourceStream</c> is
///     created on demand to read the resource data, used for import parsing and loading,
///     then freed immediately. The resource data is not held in memory beyond what is needed.
///   </para>
///   <para>
///     <b>Circular Dependency Protection:</b> An internal stack tracks which modules are
///     currently in the process of being loaded. If a circular dependency is detected
///     (e.g., A imports B, B imports A), the function fails immediately with
///     <c>ERROR_CIRCULAR_DEPENDENCY</c> (1059) and returns <c>0</c>.
///   </para>
///   <para>
///     <b>Idempotent:</b> Calling this function for an already-loaded module is safe and
///     returns the existing handle from the module registry without any side effects.
///     This makes it suitable for use after <c>LoadAll</c> to retrieve handles.
///   </para>
///   <code>
///     // Register DLLs (order doesn't matter).
///     RegisterDllData('DllA.dll', ResNameDllA());
///     RegisterDllData('DllB.dll', ResNameDllB());
///
///     // Load DllB — DllA is loaded automatically as a dependency.
///     DllBHandle := LoadLibrary('DllB.dll');
///
///     // Or retrieve a handle after LoadAll has already loaded everything.
///     DllAHandle := LoadLibrary('DllA.dll'); // Returns existing handle.
///   </code>
/// </remarks>
/// <exception>
///   If the function fails, the Windows error code can be retrieved using <c>GetLastError</c>.
///   Possible error codes include:
///   <list type="bullet">
///     <item><description><c>ERROR_FILE_NOT_FOUND</c> — The module name was not found in the data registry.</description></item>
///     <item><description><c>ERROR_CIRCULAR_DEPENDENCY</c> (1059) — A circular dependency chain was detected.</description></item>
///     <item><description>Other codes may be set by the underlying <c>LoadLibrary(AData, ASize, AModuleName)</c> call if mapping or import resolution fails.</description></item>
///   </list>
/// </exception>
/// <preconditions>
///   <list type="bullet">
///     <item><description>The module must have been previously registered via <c>RegisterDllData</c>.</description></item>
///     <item><description>For pointer-based registrations, the data pointer must still be valid.</description></item>
///     <item><description>For resource-based registrations, the resource must still be accessible.</description></item>
///   </list>
/// </preconditions>
/// <postconditions>
///   <list type="bullet">
///     <item><description>If successful, the DLL and all its registered dependencies are loaded into the process's address space with DllMain called for process attach.</description></item>
///     <item><description>The module is registered in the internal module registry and can be found by subsequent calls or by other DLLs' import tables.</description></item>
///     <item><description><c>FreeLibrary</c> should be called on the returned handle when the DLL is no longer needed.</description></item>
///   </list>
/// </postconditions>
/// <seealso>
///   <c>RegisterDllData</c>, <c>LoadAll</c>, <c>GetProcAddress</c>, <c>FreeLibrary</c>
/// </seealso>
function LoadLibrary(const AModuleName: string): THandle; overload;

/// <summary>
///   Loads all DLLs previously registered via <c>RegisterDllData</c> in the correct
///   dependency order. This is a convenience function that iterates the entire data
///   registry and calls <c>LoadLibrary(AModuleName)</c> for each registered module.
/// </summary>
/// <returns>
///   Returns <c>True</c> if all registered DLLs were loaded successfully. Returns
///   <c>False</c> if any module fails to load, in which case loading stops immediately
///   at the first failure. Modules that were successfully loaded before the failure
///   remain loaded.
/// </returns>
/// <remarks>
///   <para>
///     <b>Dependency ordering is automatic.</b> Because <c>LoadLibrary(AModuleName)</c>
///     recursively loads dependencies before the requested module, and skips modules that
///     are already loaded, the iteration order through the data registry does not matter.
///     The correct topological loading order is determined at runtime by parsing each
///     DLL's import table.
///   </para>
///   <para>
///     After <c>LoadAll</c> completes successfully, handles to individual modules can be
///     retrieved by calling <c>LoadLibrary(AModuleName)</c> which returns the existing
///     handle from the module registry without reloading.
///   </para>
///   <code>
///     // Register DLLs from resources (any order).
///     RegisterDllData('DllC.dll', ResNameDllC());
///     RegisterDllData('DllA.dll', ResNameDllA());
///     RegisterDllData('DllB.dll', ResNameDllB());
///
///     // Load everything. If DllC depends on DllB, which depends on DllA,
///     // they are loaded in order: DllA, DllB, DllC — regardless of
///     // registration order.
///     if not LoadAll() then
///     begin
///       WriteLn('Failed to load DLLs.');
///       Halt(1);
///     end;
///
///     // Retrieve handles for individual modules.
///     DllCHandle := LoadLibrary('DllC.dll');
///     MyFunc := GetProcAddress(DllCHandle, 'MyFunction');
///   </code>
/// </remarks>
/// <exception>
///   If any module fails to load, the error code from the failed <c>LoadLibrary(AModuleName)</c>
///   call can be retrieved using <c>GetLastError</c>. A debug message identifying the failed
///   module is emitted via <c>OutputDebugString</c>.
/// </exception>
/// <preconditions>
///   <list type="bullet">
///     <item><description>At least one module must have been registered via <c>RegisterDllData</c>.</description></item>
///     <item><description>All registered data pointers (for pointer-based registrations) must still be valid.</description></item>
///     <item><description>All registered resources (for resource-based registrations) must still be accessible.</description></item>
///     <item><description>The dependency graph must be acyclic (no circular dependencies).</description></item>
///   </list>
/// </preconditions>
/// <postconditions>
///   <list type="bullet">
///     <item><description>If <c>True</c> is returned, every registered DLL is loaded, initialized (DllMain called), and available in the module registry.</description></item>
///     <item><description>Handles can be retrieved via <c>LoadLibrary(AModuleName)</c> or used with <c>GetProcAddress</c>.</description></item>
///     <item><description><c>FreeLibrary</c> should be called for each loaded module when no longer needed, in reverse dependency order.</description></item>
///   </list>
/// </postconditions>
/// <seealso>
///   <c>RegisterDllData</c>, <c>LoadLibrary(AModuleName)</c>, <c>GetProcAddress</c>, <c>FreeLibrary</c>
/// </seealso>
function LoadAll(): Boolean;

implementation

uses
  // Standard Windows API units
  Winapi.Windows,
  // Delphi system utilities
  System.SysUtils,
  System.Math,
  System.Classes;

// --- Internal Constants ---
const
  // NTSTATUS Codes: Used by NT Native API functions.
  STATUS_SUCCESS               = $00000000; // Operation completed successfully.
  STATUS_IMAGE_NOT_AT_BASE     = $40000003; // Image was loaded but not at its preferred base address. Used by the hook to signal success with redirection.
  STATUS_NOT_SUPPORTED         = $C00000BB; // The request is not supported. Used by hooks for 24H2 compatibility.
  STATUS_ACCESS_DENIED         = $C0000022; // Access denied.
  STATUS_DLL_NOT_FOUND         = NTSTATUS($C0000135); // DLL not found.
  STATUS_PROCEDURE_NOT_FOUND   = $C000007A; // The specified procedure could not be found (e.g., missing NT function).
  STATUS_UNSUCCESSFUL          = $C0000001; // Generic unsuccessful status.

  // Memory Allocation Flags: Used with VirtualAlloc.
  MEM_COMMIT   = $00001000; // Allocates physical storage in memory or paging file on disk for the specified reserved memory pages.
  MEM_RESERVE  = $00002000; // Reserves a range of the process's virtual address space without allocating any physical storage.
  MEM_RELEASE  = $00008000; // Releases the specified region of pages.

  // Page Protection Constants: Used with VirtualAlloc and VirtualProtect.
  PAGE_NOACCESS          = $01; // Disables all access to the committed region of pages.
  PAGE_READONLY          = $02; // Enables read-only access.
  PAGE_READWRITE         = $04; // Enables read-write access.
  PAGE_WRITECOPY         = $08; // Enables copy-on-write access.
  PAGE_EXECUTE           = $10; // Enables execute access.
  PAGE_EXECUTE_READ      = $20; // Enables execute and read access.
  PAGE_EXECUTE_READWRITE = $40; // Enables execute, read, and write access.
  PAGE_EXECUTE_WRITECOPY = $80; // Enables execute and copy-on-write access.

  // Section Flags
  SEC_IMAGE = $1000000; // Indicates the section is an image section (used for PE files).

  // LDR Flags: Internal Windows Loader flags for module entries.
  LDRP_DONT_CALL_FOR_THREADS = $00040000; // Flag to prevent DllMain calls for thread attach/detach after initial process attach.
  LDRP_HASH_TABLE_SIZE       = 32;        // Number of buckets in the LdrpHashTable array inside ntdll.
  IMAGE_ORDINAL_FLAG64       = NativeUInt($8000000000000000); // High bit = import by ordinal on x64.

  // Section Access Rights: Used with NT section objects.
  SECTION_QUERY          = $0001; // Required to query a section object.
  SECTION_MAP_WRITE      = $0002; // Required to map a view of a section for write access.
  SECTION_MAP_READ       = $0004; // Required to map a view of a section for read access.
  SECTION_MAP_EXECUTE    = $0008; // Required to map a view of a section for execute access.

  // Image Section Characteristics: Flags found in PE section headers.
  IMAGE_SCN_MEM_EXECUTE = $20000000; // Section contains executable code.
  IMAGE_SCN_MEM_READ    = $40000000; // Section can be read.
  IMAGE_SCN_MEM_WRITE   = $80000000; // Section can be written to.

  // Image File Header Characteristics: Flags found in PE file header.
  IMAGE_FILE_EXECUTABLE_IMAGE = $0002; // File is executable (not an object file or library).

  // WinError Codes: Standard Windows error codes.
  ERROR_HOOK_NOT_INSTALLED = 1381; // ($565) Used when API hooking fails.
  ERROR_INVALID_DATA       = 13;   // Data is invalid (e.g., corrupted PE).
  ERROR_CANTREAD           = 1385; // ($569) Cannot read from source (potentially relevant for file ops, though not used directly here).

// Custom Loader Flags (used by MapAndResolve `APlFlags` parameter)
const
  LOAD_FLAGS_NONE       = $00; // No special post-load actions.
  LOAD_FLAGS_NO_HEADERS = $01; // Implemented: Zero out the PE headers in memory after loading.
  LOAD_FLAGS_NO_MODLIST = $02; // Implemented: Remove the loaded module from the PEB loader lists (InLoadOrder, InMemoryOrder, etc.).
  LOAD_FLAGS_NO_NOTIFS  = $04; // Defined but NOT implemented: Intended to block loader notifications (requires deeper hooking).
  LOAD_FLAGS_NO_THDCALL = $08; // Implemented: Set the LDRP_DONT_CALL_FOR_THREADS flag in the LDR entry to disable DllMain calls for new threads.
  LOAD_FLAGS_OVRHDRS    = $10; // Implemented: Overwrite the in-memory PE headers with the headers from the original (dummy) file path provided to LoadLibraryEx.
  LOAD_FLAGS_USEHBP     = $20; // Defined but NOT implemented: Intended for hardware breakpoint based hooking.
  LOAD_FLAGS_USETXF     = $40; // Defined but NOT implemented: Intended for loading via Transactional NTFS (TxF).
  LOAD_FLAGS_ALLFLAGS   = $FF; // Meta-flag representing all defined flags (including non-implemented).

// --- Type Definitions ---
type
  // Basic NT Types (redefined for clarity or completeness)
  ULONG = Cardinal;           // Unsigned 32-bit integer.
  ULONG_PTR = NativeUInt;     // Unsigned integer type whose size matches the pointer size (64-bit on Win64).
  SIZE_T = NativeUInt;        // Unsigned integer type used for sizes (matches pointer size).
  ACCESS_MASK = Cardinal;     // 32-bit type used for access rights.
  NTSTATUS = LongWord;        // 32-bit signed integer used for NT function return status codes.
  PVOID = Pointer;            // Generic pointer type.
  PPEB = ^_PEB;               // Pointer to a Process Environment Block structure (forward declaration).
  PTEB = Pointer;             // Simplified pointer to Thread Environment Block (TEB). Full structure not needed here.

  // String/List Structures used in PEB/LDR
  _UNICODE_STRING = record    // Structure representing a Unicode string buffer with length.
    Length: Word;             // Length of the string in bytes, not including null terminator.
    MaximumLength: Word;      // Total allocated size of the buffer in bytes.
    Buffer: PWideChar;        // Pointer to the wide character string buffer.
  end;
  UNICODE_STRING = _UNICODE_STRING;
  PUNICODE_STRING = ^UNICODE_STRING; // Pointer to a UNICODE_STRING.

  _LIST_ENTRY = record        // Standard Windows structure for doubly-linked list nodes.
    Flink: ^_LIST_ENTRY;      // Pointer to the next entry in the list (Forward link).
    Blink: ^_LIST_ENTRY;      // Pointer to the previous entry in the list (Backward link).
  end;
  LIST_ENTRY = _LIST_ENTRY;
  PLIST_ENTRY = ^LIST_ENTRY;  // Pointer to a LIST_ENTRY.

  // Partial PEB/LDR Structures (containing only fields relevant to this unit)
  _PEB_LDR_DATA = record      // Process Environment Block Loader Data structure.
    Length: ULONG;            // Size of this structure.
    Initialized: Byte;        // Boolean flag indicating if the loader data is initialized.
    SsHandle: THandle;        // Handle (usage varies, often related to subsystems).
    InLoadOrderModuleList: LIST_ENTRY; // Head of the linked list of modules in the order they were loaded.
    InMemoryOrderModuleList: LIST_ENTRY; // Head of the linked list of modules in memory address order.
    InInitializationOrderModuleList: LIST_ENTRY; // Head of the linked list of modules in initialization order.
    // ... other fields are omitted as they are not used here.
  end;
  PEB_LDR_DATA = _PEB_LDR_DATA;
  PPEB_LDR_DATA = ^PEB_LDR_DATA; // Pointer to PEB_LDR_DATA.

  _PEB = record               // Process Environment Block structure.
    InheritedAddressSpace: Byte; // Boolean flag.
    ReadImageFileExecOptions: Byte; // Boolean flag.
    BeingDebugged: Byte;      // Boolean flag indicating if the process is being debugged.
    BitField: Byte;           // Contains several bit flags (e.g., ImageUsesLargePages). Was originally a union.
    Mutant: THandle;          // Handle to the process heap synchronization object.
    ImageBaseAddress: PVOID;  // Base address of the main executable module (EXE).
    Ldr: PPEB_LDR_DATA;       // Pointer to the PEB_LDR_DATA structure.
    // ... other fields are omitted.
  end;
  PEB = _PEB;
  // PPEB defined earlier as ^_PEB.

// Enable pointer math for calculating offsets within LDR_DATA_TABLE_ENTRY
{$POINTERMATH ON}
  _LDR_DATA_TABLE_ENTRY = record // Represents a loaded module (DLL or EXE) in the PEB loader lists.
    InLoadOrderLinks: LIST_ENTRY;           // Links for the InLoadOrderModuleList.
    InMemoryOrderLinks: LIST_ENTRY;         // Links for the InMemoryOrderModuleList.
    InInitializationOrderLinks: LIST_ENTRY; // Links for the InInitializationOrderModuleList.
    DllBase: PVOID;                         // Base address where the module is loaded in memory.
    EntryPoint: PVOID;                      // Address of the module's entry point function (e.g., DllMain).
    SizeOfImage: ULONG;                     // Total size of the module image in memory, in bytes.
    FullDllName: UNICODE_STRING;            // Full path and filename of the DLL.
    BaseDllName: UNICODE_STRING;            // Filename part of the DLL only.
    Flags: ULONG;                           // Various loader flags (e.g., LDRP_DONT_CALL_FOR_THREADS).
    LoadCount: Word;                        // Reference count for static loads (obsolete, often -1).
    TlsIndex: Word;                         // Thread Local Storage index assigned to the module.
    HashLinks: LIST_ENTRY;                  // LIST_ENTRY for the LdrpHashTable (offset 0x70 on x64).
    CheckSum: ULONG;                        // Checksum from the PE header.
    TimeDateStamp: ULONG;                   // Time/date stamp from the PE header.
    // ... many other fields related to imports, TLS, etc., are omitted.
  end;
  LDR_DATA_TABLE_ENTRY = _LDR_DATA_TABLE_ENTRY;
  PLDR_DATA_TABLE_ENTRY = ^LDR_DATA_TABLE_ENTRY; // Pointer to LDR_DATA_TABLE_ENTRY.
{$POINTERMATH OFF}

  // Structures used as parameters for NT Native API functions.
  _OBJECT_ATTRIBUTES = record // Defines attributes for an object being created or opened by NT functions.
    Length: ULONG;            // Size of this structure.
    RootDirectory: THandle;   // Optional handle to a root directory for relative names.
    ObjectName: PUNICODE_STRING; // Pointer to the object's name (e.g., device path).
    Attributes: ULONG;        // Object attributes (e.g., OBJ_CASE_INSENSITIVE).
    SecurityDescriptor: PVOID; // Optional security descriptor.
    SecurityQualityOfService: PVOID; // Optional Quality of Service parameters.
  end;
  OBJECT_ATTRIBUTES = _OBJECT_ATTRIBUTES;
  POBJECT_ATTRIBUTES = ^OBJECT_ATTRIBUTES; // Pointer to OBJECT_ATTRIBUTES.

  _IO_STATUS_BLOCK = record   // Receives the final status and information about a requested I/O operation.
    // The first field is a union in C: { Status: NTSTATUS; Pointer: PVOID; }
    Status: NTSTATUS;         // Final completion status of the operation. Simplified here, assuming Status is primary use.
    Information: ULONG_PTR;   // Receives operation-dependent information (e.g., number of bytes transferred).
  end;
  IO_STATUS_BLOCK = _IO_STATUS_BLOCK;
  PIO_STATUS_BLOCK = ^IO_STATUS_BLOCK; // Pointer to IO_STATUS_BLOCK.

  // Enumerations for NT Function Parameters
  SECTION_INFORMATION_CLASS = ( // Used with NtQuerySection to specify the type of information requested.
    SectionBasicInformation,    // Retrieve basic section attributes.
    SectionImageInformation     // Retrieve information specific to image sections (PE files).
    // ... other values exist but are not used here.
  );

  SECTION_INHERIT = (         // Used with NtMapViewOfSection to specify how the view is inherited by child processes.
    ViewShare = 1,            // Share the view with child processes.
    ViewUnmap = 2             // Do not map the view into child processes (typically used).
  );

  _SECTION_IMAGE_INFORMATION = record // Structure filled by NtQuerySection when requesting SectionImageInformation. (Partial definition)
    TransferAddress: PVOID;       // Preferred execution start address (usually EntryPoint).
    ZeroBits: ULONG;              // Number of leading zero bits in the base address (relevant for alignment).
    MaximumStackSize: SIZE_T;     // Maximum stack size required by the image.
    CommittedStackSize: SIZE_T;   // Initially committed stack size.
    SubSystemType: ULONG;         // Subsystem required (e.g., Windows GUI, Console).
    SubSystemMinorVersion: Word;  // Minor version of the required subsystem.
    SubSystemMajorVersion: Word;  // Major version of the required subsystem.
    OperatingSystemVersion: ULONG;// Deprecated OS version field.
    ImageCharacteristics: Word;   // PE File Header Characteristics flags.
    DllCharacteristics: Word;     // PE Optional Header DllCharacteristics flags.
    Machine: Word;                // Architecture type (e.g., IMAGE_FILE_MACHINE_AMD64).
    ImageContainsCode: Byte;      // Boolean flag indicating if the image contains executable code.
    // The ImageFlags field is a union/bitfield in C, approximated here.
    ImageFlags: Byte;             // Flags like COMIMAGE_FLAGS_ILONLY, etc.
    LoaderFlags: ULONG;           // Flags influencing loader behavior.
    ImageFileSize: ULONG;         // Size of the image file on disk. *Crucial field used by the hook*.
    CheckSum: ULONG;              // Checksum from the PE header.
    // ... more fields related to code integrity, etc., are omitted.
  end;
  SECTION_IMAGE_INFORMATION = _SECTION_IMAGE_INFORMATION;
  PSECTION_IMAGE_INFORMATION = ^SECTION_IMAGE_INFORMATION; // Pointer to SECTION_IMAGE_INFORMATION.

  // Memory Information Class (for NtQueryVirtualMemory, particularly for 24H2+ compatibility)
  MEMORY_INFORMATION_CLASS = (
    MemoryBasicInformation,            // 0: Basic allocation info (base, size, state, protect).
    MemoryWorkingSetInformation,       // 1: Working set info.
    MemoryMappedFilenameInformation,   // 2: Get filename for mapped views.
    MemoryRegionInformation,           // 3: VAD info.
    MemoryWorkingSetExInformation,     // 4: Extended working set info.
    MemorySharedCommitInformation,     // 5: Shared commit info.
    MemoryImageInformation,            // 6: Basic image info (similar to SEC_IMAGE info).
    MemoryRegionInformationEx,         // 7: Extended region info.
    MemoryPrivilegedBasicInformation,  // 8: Privileged basic info.
    MemoryEnclaveImageInformation,     // 9: Enclave info.
    MemoryBasicInformationCapped,      // 10: Capped basic info.
    MemoryPhysicalContiguityInformation, // 11: Physical contiguity info.
    MemoryBadInformation,              // 12: Bad memory info.
    MemoryBadInformationAllProcesses,  // 13: Bad memory info (all processes).
    MemoryImageExtensionInformation,   // 14: *Important for 24H2+ compatibility hook*.
    MaxMemoryInfoClass                 // 15: Marks the end of the enumeration.
  );

  // --- NT Function Pointer Types ---
  // Define function pointer types matching the signatures of NT Native API functions used.
  PLARGE_INTEGER = PLargeInteger; // Use standard Delphi PLargeInteger for section offsets.

  // Function pointer type for NtQuerySection.
  TNtQuerySection = function(SectionHandle: THandle; SectionInformationClass: SECTION_INFORMATION_CLASS;
    SectionInformation: PVOID; SectionInformationLength: SIZE_T; ReturnLength: PSIZE_T): NTSTATUS; stdcall;

  // Function pointer type for NtMapViewOfSection (the primary function to hook).
  TNtMapViewOfSection = function(SectionHandle: THandle; ProcessHandle: THandle; BaseAddress: PPointer; // Note: BaseAddress is PPointer (^Pointer)
    ZeroBits: ULONG_PTR; CommitSize: SIZE_T; SectionOffset: PLARGE_INTEGER; ViewSize: PSIZE_T;
    InheritDisposition: SECTION_INHERIT; AllocationType: ULONG; Win32Protect: ULONG): NTSTATUS; stdcall;

  // Function pointer type for NtQueryVirtualMemory (hooked for 24H2+ compatibility).
  TNtQueryVirtualMemory = function(ProcessHandle: THandle; BaseAddress: PVOID;
    MemoryInformationClass: MEMORY_INFORMATION_CLASS; MemoryInformation: PVOID;
    MemoryInformationLength: SIZE_T; ReturnLength: PSIZE_T): NTSTATUS; stdcall;

  // Function pointer type for NtManageHotPatch (hooked for 24H2+ compatibility).
  TNtManageHotPatch = function(Operation: ULONG; SubmitBuffer: PVOID; SubmitBufferLength: ULONG;
    OperationStatus: PNTSTATUS): NTSTATUS; stdcall;

  // Function pointer type for LdrLockLoaderLock (used for safe modification of LDR data).
  TLdrLockLoaderLock = function(Flags: ULONG; State: PULONG; Cookie: PSIZE_T): NTSTATUS; stdcall; // Cookie is PSIZE_T (^NativeUInt)

  // Function pointer type for LdrUnlockLoaderLock.
  TLdrUnlockLoaderLock = function(Flags: ULONG; Cookie: SIZE_T): NTSTATUS; stdcall; // Cookie is SIZE_T (NativeUInt)

  // Function pointer type for RtlNtStatusToDosError (to convert NTSTATUS codes to Win32 error codes).
  TRtlNtStatusToDosError = function(Status: NTSTATUS): DWORD; stdcall;

  // Function pointer type for LdrGetDllHandle (hooked for named module lookup on Win11 24H2+).
  TLdrGetDllHandle = function(
    DllPath: PWideChar;
    DllCharacteristics: Pointer;
    DllName: PUNICODE_STRING;
    DllHandle: Pointer
  ): NTSTATUS; stdcall;

  // --- PE Structure Pointer Types ---
  // Standard PE structures are defined in Winapi.Windows, use pointers to them.
  PImageDosHeader = ^TImageDosHeader;           // Pointer to the DOS header ("MZ").
  PImageNtHeaders64 = ^TImageNtHeaders64;       // Pointer to the 64-bit NT headers (PE signature, File Header, Optional Header).
  PImageSectionHeader = ^TImageSectionHeader;   // Pointer to a section header entry.
  PImageDataDirectory = ^TImageDataDirectory;   // Pointer to a data directory entry.

  // PE Import Table structures (not in Delphi's standard units).
  TImageImportDescriptor = packed record
    OriginalFirstThunk: DWORD; // RVA to INT (Import Name Table) / Import Lookup Table
    TimeDateStamp: DWORD;
    ForwarderChain: DWORD;
    Name: DWORD;               // RVA to the DLL name string
    FirstThunk: DWORD;         // RVA to IAT (Import Address Table)
  end;
  PImageImportDescriptor = ^TImageImportDescriptor;

  TImageImportByName = packed record
    Hint: Word;
    Name: array[0..0] of AnsiChar; // Variable-length name follows
  end;
  PImageImportByName = ^TImageImportByName;

// --- Global Variables for the Unit ---
var
  // Synchronization: Protects access to global hooking state variables.
  GRedirectCritSect: TRTLCriticalSection;

  // Redirection State: Managed within the critical section.
  GRedirectionActive: Boolean = False;            // Flag: True if hooks are installed and redirection might occur.
  GInterceptNextMapView: Boolean = False;         // Flag: Set to True just before calling LoadLibraryExW, telling the NtMapView hook to intercept the *next* call.
  GMappedBaseAddress: Pointer = nil;              // Stores the base address of the manually mapped DLL image, provided to the hooked NtMapView.
  GMappedSize: SIZE_T = 0;                        // Stores the size of the manually mapped DLL image.
  GOriginalFileSize: Int64 = 0;                   // Used by older hook logic (now less relevant) to identify target section based on file size.

  // Original NT Function Pointers: Store the original entry points before hooking.
  GOrigNtMapViewOfSection: TNtMapViewOfSection = nil;   // Stores the original address of NtMapViewOfSection.
  GOrigNtQueryVirtualMemory: TNtQueryVirtualMemory = nil; // Stores the original address of NtQueryVirtualMemory.
  GOrigNtManageHotPatch: TNtManageHotPatch = nil;       // Stores the original address of NtManageHotPatch.

  // Addresses of NT Functions to Hook: Resolved using GetProcAddress.
  GNtMapViewOfSectionAddr: Pointer = nil;         // Address of NtMapViewOfSection in ntdll.
  GNtQueryVirtualMemoryAddr: Pointer = nil;       // Address of NtQueryVirtualMemory in ntdll (may be nil on older OS).
  GNtManageHotPatchAddr: Pointer = nil;           // Address of NtManageHotPatch in ntdll (may be nil on older OS).

  // Buffers for Original Bytes at Hook Points: Store the original machine code bytes overwritten by the hook.
  GOrigBytesNtMapView: TBytes;                    // Original bytes at NtMapViewOfSection entry point.
  GOrigBytesNtQueryVirtualMemory: TBytes;         // Original bytes at NtQueryVirtualMemory entry point.
  GOrigBytesNtManageHotPatch: TBytes;             // Original bytes at NtManageHotPatch entry point.

  // NT Function Pointers: For functions called directly (not hooked). Resolved using GetProcAddress.
  FNtQuerySection: TNtQuerySection = nil;           // Pointer to NtQuerySection.
  FLdrLockLoaderLock: TLdrLockLoaderLock = nil;     // Pointer to LdrLockLoaderLock.
  FLdrUnlockLoaderLock: TLdrUnlockLoaderLock = nil; // Pointer to LdrUnlockLoaderLock.
  FRtlNtStatusToDosError: TRtlNtStatusToDosError = nil; // Pointer to RtlNtStatusToDosError.

  // LDR Hash Table: Cached base address of ntdll's LdrpHashTable array.
  GLdrpHashTable: Pointer = nil;

  // LdrGetDllHandle Hook: Persistent hook for module name lookup redirection.
  // On Windows 11 24H2+, patching BaseDllName/FullDllName strings in the LDR entry
  // is insufficient because the loader uses internal name-indexed data structures
  // that are not updated by string patching. This hook intercepts LdrGetDllHandle
  // and checks our module registry when the original function returns NOT_FOUND.
  GLdrGetDllHandleAddr: Pointer = nil;
  GOrigLdrGetDllHandle: TLdrGetDllHandle = nil;
  GOrigBytesLdrGetDllHandle: TBytes;
  GLdrHookInstalled: Boolean = False;

  // LdrLoadDll Hook: Persistent hook for import resolution redirection.
  // When the import resolver can't find a module and tries to load it from disk,
  // this hook intercepts and returns the existing handle from our registry.
  GLdrLoadDllAddr: Pointer = nil;
  GOrigLdrLoadDll: TLdrGetDllHandle = nil; // Same signature as LdrGetDllHandle
  GOrigBytesLdrLoadDll: TBytes;
  GLdrLoadDllHookInstalled: Boolean = False;

  // Module Registry: Simple name→handle map for memory-loaded DLLs.
  GRegisteredModuleCount: Integer = 0;
  GRegisteredModuleNames: array[0..63] of string;
  GRegisteredModuleHandles: array[0..63] of THandle;

  // Data Registry: Stores raw PE data or resource names registered by the user
  // for deferred loading. LoadLibrary(AModuleName) and LoadAll use this.
  GDataRegistryCount: Integer = 0;
  GDataRegistryNames: array[0..63] of string;     // Module name, e.g. 'DllA.dll'
  GDataRegistryPtrs: array[0..63] of Pointer;     // Raw PE bytes (nil if resource-based)
  GDataRegistrySizes: array[0..63] of NativeUInt;  // Size of raw PE bytes (0 if resource-based)
  GDataRegistryResNames: array[0..63] of string;   // Resource name (empty if pointer-based)

  // Circular dependency protection: tracks modules currently being loaded.
  GLoadingInProgressCount: Integer = 0;
  GLoadingInProgress: array[0..63] of string;

// --- Helper: OutputDebugStringFmt ---
// Formats a string with arguments and sends it to the debugger output.
procedure OutputDebugStringFmt(const AFormat: string; const AArgs: array of const);
var
  LFormattedString: string;
begin
  // Use standard Delphi Format function.
  LFormattedString := System.SysUtils.Format(AFormat, AArgs);
  // Call Windows API OutputDebugStringW to output the Unicode string.
  OutputDebugStringW(PWideChar(LFormattedString));
end;

// --- Helper Function: InitializeNtFunctions ---
// Resolves addresses of required NTDLL functions using GetProcAddress.
procedure InitializeNtFunctions();
var
  LNtdll: HMODULE; // Handle to ntdll.dll module.
begin
  // Get a handle to the already loaded ntdll.dll.
  LNtdll := GetModuleHandle(PWideChar('ntdll.dll'));
  if LNtdll = 0 then
  begin
    // Critical error if ntdll cannot be found.
    OutputDebugStringFmt('CRITICAL: Failed to get handle for ntdll.dll', []);
    Exit; // Or raise an exception.
  end;

  // Get addresses of functions we might hook. Store them in global variables.
  GNtMapViewOfSectionAddr := GetProcAddress(LNtdll, 'NtMapViewOfSection');
  GNtQueryVirtualMemoryAddr := GetProcAddress(LNtdll, 'NtQueryVirtualMemory'); // Needed for 24H2+ compatibility hook.
  GNtManageHotPatchAddr := GetProcAddress(LNtdll, 'NtManageHotPatch');       // Needed for 24H2+ compatibility hook.

  // Get addresses of functions we call directly. Store them in global variables.
  FNtQuerySection := GetProcAddress(LNtdll, 'NtQuerySection');
  FLdrLockLoaderLock := GetProcAddress(LNtdll, 'LdrLockLoaderLock');
  FLdrUnlockLoaderLock := GetProcAddress(LNtdll, 'LdrUnlockLoaderLock');
  FRtlNtStatusToDosError := GetProcAddress(LNtdll, 'RtlNtStatusToDosError');

  // Log status of function resolution.
  // Check for essential functions.
  if not Assigned(GNtMapViewOfSectionAddr) then
    OutputDebugStringFmt('ERROR: NtMapViewOfSection address not found in ntdll. Cannot perform redirection.', []);
  if not Assigned(FNtQuerySection) then
    OutputDebugStringFmt('ERROR: NtQuerySection address not found in ntdll.', []); // May impact some operations.
  if not Assigned(FLdrLockLoaderLock) or not Assigned(FLdrUnlockLoaderLock) then
    OutputDebugStringFmt('WARNING: Loader Lock functions (LdrLockLoaderLock/LdrUnlockLoaderLock) not found in ntdll. Post-load flags (NO_MODLIST, NO_THDCALL, OVRHDRS) may fail.', []);

  // Log info about optional hook targets (may not exist on all Windows versions).
  if not Assigned(GNtQueryVirtualMemoryAddr) then
    OutputDebugStringFmt('INFO: NtQueryVirtualMemory not found in ntdll (may not exist on this OS version). 24H2+ compatibility hook inactive.', []);
  if not Assigned(GNtManageHotPatchAddr) then
    OutputDebugStringFmt('INFO: NtManageHotPatch not found in ntdll (may not exist on this OS version). 24H2+ compatibility hook inactive.', []);
end;

// --- Helper Function: GetPEB ---
// Retrieves a pointer to the current process's Process Environment Block (PEB).
function GetPEB(): PPEB;
// Uses inline assembly for direct access on x64.
asm
  // The Thread Environment Block (TEB) on x64 is accessible via the GS segment register.
  // The PEB pointer is located at offset 0x60 within the TEB.
  MOV RAX, GS:[030h]  // Load the TEB address from GS:[0x30] into RAX.
  MOV RAX, [RAX+060h] // Load the PEB address from TEB+0x60 into RAX.
  // Result is returned in RAX.
end;

// --- Helper Function: GetLdrDataTableEntry ---
// Finds the LDR_DATA_TABLE_ENTRY for a given module base address by traversing the PEB loader lists.
function GetLdrDataTableEntry(const APeBase: Pointer): PLDR_DATA_TABLE_ENTRY;
var
  LPeb: PPEB;                  // Pointer to the Process Environment Block.
  LLdr: PPEB_LDR_DATA;         // Pointer to the loader data within PEB.
  LModuleList: PLIST_ENTRY;    // Pointer to the head of a module list (e.g., InLoadOrderModuleList).
  LCurrentEntry: PLIST_ENTRY;  // Pointer to the current list entry being examined.
  LLdrEntry: PLDR_DATA_TABLE_ENTRY; // Pointer to the LDR_DATA_TABLE_ENTRY derived from LCurrentEntry.
begin
  Result := nil; // Assume failure.
  try
    // Get the PEB.
    LPeb := GetPEB();
    if LPeb = nil then
      Exit; // Exit if PEB cannot be retrieved.

    // Get the LDR data pointer from PEB.
    LLdr := LPeb^.Ldr;
    if LLdr = nil then
      Exit; // Exit if LDR pointer is nil.

    // Get the head of the 'InLoadOrderModuleList'. This list contains modules in the order they were loaded.
    LModuleList := @(LLdr^.InLoadOrderModuleList);
    if LModuleList = nil then // Should not happen if Ldr is valid, but check anyway.
      Exit;

    // Start traversal from the first actual entry in the list (Flink points to the first item).
    LCurrentEntry := PLIST_ENTRY(LModuleList^.Flink); // Cast needed as Flink is ^_LIST_ENTRY.

    // Traverse the doubly linked list until we loop back to the list head.
    while (LCurrentEntry <> nil) and (LCurrentEntry <> LModuleList) do
    begin
      // Calculate the base address of the containing LDR_DATA_TABLE_ENTRY structure.
      // This uses pointer arithmetic: the address of the structure is the address of the
      // 'InLoadOrderLinks' field minus the offset of that field within the structure.
      {$POINTERMATH ON}
      LLdrEntry := PLDR_DATA_TABLE_ENTRY(PByte(LCurrentEntry) - NativeUInt(@PLDR_DATA_TABLE_ENTRY(nil)^.InLoadOrderLinks));
      {$POINTERMATH OFF}

      // Check if the DllBase field of this entry matches the target base address.
      // Include nil check for safety before dereferencing LLdrEntry.
      if Assigned(LLdrEntry) and (LLdrEntry^.DllBase = APeBase) then
      begin
        // Found the matching entry.
        Result := LLdrEntry;
        Exit; // Return the found pointer.
      end;

      // Move to the next entry in the list using the forward link.
      LCurrentEntry := PLIST_ENTRY(LCurrentEntry^.Flink); // Cast needed.
    end;

  except
    // Catch potential access violations if PEB/LDR structures are corrupt or pointers are invalid.
    on E: Exception do
    begin
      OutputDebugStringFmt('GetLdrDataTableEntry Exception: %s while traversing LDR list. PEB/LDR structure might be unexpected.', [E.Message]);
      Result := nil; // Ensure nil is returned on error.
    end;
  end;
end;

// --- Helper Functions: LockLoader / UnlockLoader ---
// Acquire the Windows loader lock to safely access/modify PEB loader data structures.
function LockLoader(): NativeUInt; // Returns a cookie to be used with UnlockLoader.
var
  LStatus: NTSTATUS;
  LCookie: NativeUInt; // SIZE_T is NativeUInt on Win64.
begin
  Result := 0; // Default to 0 (failure or lock not acquired).
  LCookie := 0;

  // Check if the LdrLockLoaderLock function pointer was resolved.
  if Assigned(FLdrLockLoaderLock) then
  begin
    // Call the NT function.
    // Flags = 0: Standard lock request.
    // State = nil: Don't care about previous state.
    // Cookie = @LCookie: Receives the lock cookie if successful.
    LStatus := FLdrLockLoaderLock(0, nil, @LCookie);
    if LStatus = STATUS_SUCCESS then
      Result := LCookie // Return the non-zero cookie on success.
    else
      OutputDebugStringFmt('Warning: LdrLockLoaderLock failed with status 0x%X.', [LStatus]);
  end else
    OutputDebugStringFmt('Warning: LdrLockLoaderLock function pointer is not available. Cannot acquire loader lock.', []);
end;

// Release the Windows loader lock using the cookie obtained from LockLoader.
procedure UnlockLoader(const ACookie: NativeUInt);
begin
  // Check if a valid cookie was provided and the unlock function pointer is resolved.
  if (ACookie <> 0) and Assigned(FLdrUnlockLoaderLock) then
  begin
    // Call the NT function.
    // Flags = 0: Standard unlock.
    // Cookie = ACookie: The cookie returned by LdrLockLoaderLock.
    FLdrUnlockLoaderLock(0, ACookie);
  end;
end;

// --- Hooking Implementation ---
const
  // Size of the x64 JMP hook trampoline.
  // JMP [rip+0] = FF 25 00 00 00 00, followed by 8-byte absolute target address. Total 14 bytes.
  HOOK_SIZE = 14;
  // Opcode sequence for JMP QWORD PTR [rip+0]. The address follows immediately after this sequence.
  JMP_REL_OPCODE: array[0..5] of Byte = ($FF, $25, $00, $00, $00, $00);

// Installs a JMP hook at the target function, redirecting execution to the hook function.
function InstallHook(
  const ATargetFunc: Pointer;   // Address of the function to hook.
  const AHookFunc: Pointer;     // Address of the function to jump to.
  out AOrigBytes: TBytes        // Output: Stores the original bytes overwritten by the hook.
): Boolean;
var
  LOldProtect: DWORD;           // Stores original memory protection flags.
  LHookData: array[0..HOOK_SIZE - 1] of Byte; // Buffer to build the hook machine code.
  P: PByte;                     // Pointer used for writing the target address into LHookData.
begin
  Result := False; // Assume failure.

  // Validate input pointers.
  if (ATargetFunc = nil) or (AHookFunc = nil) then
  begin
    OutputDebugStringFmt('InstallHook Error: TargetFunc (%p) or HookFunc (%p) is nil.', [ATargetFunc, AHookFunc]);
    Exit;
  end;

  OutputDebugStringFmt('Attempting to install hook at %p pointing to %p', [ATargetFunc, AHookFunc]);
  SetLength(AOrigBytes, HOOK_SIZE); // Ensure output buffer is correct size.

  // 1. Prepare the JMP hook machine code in LHookData.
  // Copy the JMP [rip+0] opcode.
  Move(JMP_REL_OPCODE[0], LHookData[0], SizeOf(JMP_REL_OPCODE));
  // Get pointer to the position immediately after the opcode where the address goes.
  P := @LHookData[SizeOf(JMP_REL_OPCODE)];
  // Write the absolute 64-bit address of the hook function.
  PPointer(P)^ := AHookFunc;

  // 2. Make the target function's memory writable and executable.
  // Need PAGE_EXECUTE_READWRITE to overwrite the code.
  if VirtualProtect(ATargetFunc, HOOK_SIZE, PAGE_EXECUTE_READWRITE, LOldProtect) then
  try
    // 3. Save the original bytes from the target function's entry point.
    Move(ATargetFunc^, AOrigBytes[0], HOOK_SIZE);

    // 4. Write the hook bytes (JMP instruction + address) to the target function's entry point.
    Move(LHookData[0], ATargetFunc^, HOOK_SIZE);

    // 5. Flush the CPU's instruction cache for the modified memory range.
    // This ensures that the CPU fetches the new (hooked) instructions, not cached old ones.
    FlushInstructionCache(GetCurrentProcess, ATargetFunc, HOOK_SIZE);

    Result := True; // Hook installation successful.
    OutputDebugStringFmt('Hook installed successfully at %p', [ATargetFunc]);
  finally
    // 6. Restore the original memory protection flags.
    // Important for security and stability. Even if we wrote executable code,
    // the original protection might have been more restrictive (e.g., PAGE_EXECUTE_READ).
    VirtualProtect(ATargetFunc, HOOK_SIZE, LOldProtect, LOldProtect); // Use a dummy variable for the last param as we don't need the 'old' protection again.
  end
  else
  begin
    // VirtualProtect failed. Log error.
    OutputDebugStringFmt('InstallHook Error: VirtualProtect PAGE_EXECUTE_READWRITE failed for %p. Error: %d', [ATargetFunc, GetLastError]);
    SetLength(AOrigBytes, 0); // Clear output buffer on failure.
  end;
end;

// Uninstalls a hook by restoring the original bytes.
function UninstallHook(
  const ATargetFunc: Pointer;   // Address of the hooked function.
  const AOrigBytes: TBytes      // The original bytes saved during InstallHook.
): Boolean;
var
  LOldProtect: DWORD;           // Stores original memory protection flags.
begin
  Result := False; // Assume failure.

  // Validate input pointer and original bytes length.
  if (ATargetFunc = nil) or (Length(AOrigBytes) <> HOOK_SIZE) then
  begin
    OutputDebugStringFmt('UninstallHook Error: TargetFunc (%p) is nil or OrigBytes length mismatch (%d vs %d).', [ATargetFunc, Length(AOrigBytes), HOOK_SIZE]);
    Exit;
  end;

  OutputDebugStringFmt('Attempting to uninstall hook at %p', [ATargetFunc]);

  // 1. Make the target function's memory writable and executable.
  if VirtualProtect(ATargetFunc, HOOK_SIZE, PAGE_EXECUTE_READWRITE, LOldProtect) then
  try
    // 2. Write the saved original bytes back to the target function's entry point.
    Move(AOrigBytes[0], ATargetFunc^, HOOK_SIZE);

    // 3. Flush the CPU's instruction cache for the modified memory range.
    FlushInstructionCache(GetCurrentProcess, ATargetFunc, HOOK_SIZE);

    Result := True; // Hook removal successful.
    OutputDebugStringFmt('Hook uninstalled successfully at %p', [ATargetFunc]);
  finally
    // 4. Restore the original memory protection flags.
    VirtualProtect(ATargetFunc, HOOK_SIZE, LOldProtect, LOldProtect);
  end
  else
  begin
    // VirtualProtect failed. Log error.
    OutputDebugStringFmt('UninstallHook Error: VirtualProtect PAGE_EXECUTE_READWRITE failed for %p. Error: %d', [ATargetFunc, GetLastError]);
  end;
end;

// --- Hook Handler Functions ---

// Hook handler for NtMapViewOfSection. This is the core of the redirection mechanism.
function HookedNtMapViewOfSection(
  SectionHandle: THandle;         // Handle to the section object being mapped (from CreateFileMapping/NtCreateSection).
  ProcessHandle: THandle;         // Handle to the process where the view will be mapped (usually current process).
  BaseAddress: PPointer;          // Input/Output: Preferred base address / Actual mapped base address.
  ZeroBits: ULONG_PTR;            // Number of high-order address bits that must be zero.
  CommitSize: SIZE_T;             // Initial commit size (usually 0 for image mapping).
  SectionOffset: PLARGE_INTEGER;  // Offset within the section where mapping should begin (usually 0 for image).
  ViewSize: PSIZE_T;              // Input/Output: Size of view to map / Actual size mapped.
  InheritDisposition: SECTION_INHERIT; // How the view should be inherited by child processes.
  AllocationType: ULONG;          // Memory allocation type flags (e.g., MEM_RESERVE).
  Win32Protect: ULONG             // Initial memory protection for the mapped view (e.g., PAGE_READONLY).
): NTSTATUS; stdcall;
begin
  // --- PRIMARY REDIRECTION LOGIC ---
  // Check if redirection is globally active AND the specific flag to intercept the *next* call is set.
  // This ensures we only intercept the NtMapViewOfSection call originating from our targeted LoadLibraryExW call.
  if GRedirectionActive and GInterceptNextMapView then
  begin
    OutputDebugStringFmt('HookedNtMapViewOfSection: Intercepting map view for SectionHandle 0x%p. Redirecting to manually mapped base %p.', [Pointer(SectionHandle), GMappedBaseAddress]);

    // Modify the output parameters to return our manually mapped region instead of letting Windows map the dummy file.
    BaseAddress^ := GMappedBaseAddress; // Set the returned base address to our pre-allocated buffer.
    if Assigned(ViewSize) then
      ViewSize^ := GMappedSize; // Set the returned size to the size of our mapped image.

    // IMPORTANT: Reset the intercept flag immediately after interception.
    // This prevents the hook from intercepting subsequent NtMapViewOfSection calls unintentionally.
    GInterceptNextMapView := False;

    // Return STATUS_IMAGE_NOT_AT_BASE. This status code signals to the Windows loader
    // that the image was successfully "mapped" (even though we provided it) but potentially
    // not at its preferred base address. This allows the loader to proceed with relocation
    // processing if necessary, using the BaseAddress we provided.
    Result := STATUS_IMAGE_NOT_AT_BASE;
    Exit; // Do not call the original NtMapViewOfSection.
  end;

  // --- NOT THE EXPECTED CALL or REDIRECTION INACTIVE: Call the original NtMapViewOfSection ---
  // This path is taken for all other NtMapViewOfSection calls made by the process while the hook might be temporarily active,
  // or if GInterceptNextMapView was false.
  OutputDebugStringFmt('HookedNtMapViewOfSection: Call not intercepted (RedirectionActive=%s, InterceptNext=%s). Calling original function.', [BoolToStr(GRedirectionActive, True), BoolToStr(GInterceptNextMapView, True)]);

  // Ensure the pointer to the original function is valid.
  if not Assigned(GOrigNtMapViewOfSection) then
  begin
    // This should ideally never happen if hooking was successful.
    OutputDebugString('CRITICAL: Original NtMapViewOfSection pointer (GOrigNtMapViewOfSection) is nil in hook handler!');
    Result := STATUS_PROCEDURE_NOT_FOUND; // Indicate the original function is missing.
    Exit;
  end;

  // To safely call the original function, we must temporarily remove the hook,
  // make the call, and then reinstall the hook. This prevents infinite recursion
  // if the original function somehow calls itself indirectly.
  // This entire sequence must be protected by a critical section to prevent race conditions
  // if multiple threads attempt this simultaneously.
  EnterCriticalSection(GRedirectCritSect);
  try
    // Uninstall the hook using the saved original bytes.
    if UninstallHook(GNtMapViewOfSectionAddr, GOrigBytesNtMapView) then
    try
      // Call the original NtMapViewOfSection function with the original parameters.
      Result := GOrigNtMapViewOfSection(SectionHandle, ProcessHandle, BaseAddress, ZeroBits, CommitSize,
                                         SectionOffset, ViewSize, InheritDisposition, AllocationType, Win32Protect);
    finally
      // ALWAYS attempt to reinstall the hook, regardless of the original function's return value.
      if not InstallHook(GNtMapViewOfSectionAddr, @HookedNtMapViewOfSection, GOrigBytesNtMapView) then
      begin
        // This is a critical failure state. The hook could not be re-applied.
        OutputDebugString('CRITICAL: Failed to re-install NtMapViewOfSection hook after calling original function!');
        // Application might become unstable.
      end;
    end
    else
    begin
      // Failed to uninstall the hook before calling the original. This is also critical.
      // Avoid calling the original if unhooking failed, as it would likely recurse.
      OutputDebugString('CRITICAL: Failed to uninstall NtMapViewOfSection hook before calling original function!');
      Result := STATUS_ACCESS_DENIED; // Return an error status.
    end;
  finally
    // Release the critical section lock.
    LeaveCriticalSection(GRedirectCritSect);
  end;
end;

// Hook handler for NtQueryVirtualMemory.
// Intercepts specific queries related to image information, mainly for Windows 11 24H2+ compatibility.
function HookedNtQueryVirtualMemory(
  ProcessHandle: THandle;             // Handle to the process whose memory is being queried.
  BaseAddress_: PVOID;                // Base address of the region to query.
  MemoryInformationClass: MEMORY_INFORMATION_CLASS; // Type of information requested.
  MemoryInformation: PVOID;           // Buffer to receive the information.
  MemoryInformationLength: SIZE_T;    // Size of the MemoryInformation buffer.
  ReturnLength: PSIZE_T               // Output: Actual size of information returned.
): NTSTATUS; stdcall;
begin
  // Check if redirection is active and if this query matches the specific pattern we want to block/modify.
  // The target pattern is a query for MemoryImageExtensionInformation (introduced later, potentially 24H2+)
  // specifically for the base address of our manually mapped module.
  // Blocking this query seems to prevent some compatibility issues observed with manual mapping on newer Windows builds.
  if GRedirectionActive and (BaseAddress_ = GMappedBaseAddress) and
     (MemoryInformationClass = MemoryImageExtensionInformation) then
  begin
    OutputDebugStringFmt('HookedNtQueryVirtualMemory: Intercepted MemoryImageExtensionInformation query for manually mapped base %p. Returning STATUS_NOT_SUPPORTED.', [BaseAddress_]);
    // Indicate no information is returned.
    if Assigned(ReturnLength) then
      ReturnLength^ := 0;
    // Return STATUS_NOT_SUPPORTED to indicate this query type isn't handled for this memory region.
    Result := STATUS_NOT_SUPPORTED;
    Exit; // Do not call the original function.
  end;

  // --- Query not intercepted: Call the original function ---
  // Ensure the pointer to the original function is valid.
  if not Assigned(GOrigNtQueryVirtualMemory) then
  begin
    OutputDebugString('CRITICAL: Original NtQueryVirtualMemory pointer (GOrigNtQueryVirtualMemory) is nil in hook handler!');
    Result := STATUS_PROCEDURE_NOT_FOUND;
    Exit;
  end;

  // Use the same unhook/call/rehook pattern as NtMapViewOfSection, protected by the critical section.
  EnterCriticalSection(GRedirectCritSect);
  try
    if UninstallHook(GNtQueryVirtualMemoryAddr, GOrigBytesNtQueryVirtualMemory) then
    try
      // Call the original NtQueryVirtualMemory.
      Result := GOrigNtQueryVirtualMemory(ProcessHandle, BaseAddress_, MemoryInformationClass,
                                           MemoryInformation, MemoryInformationLength, ReturnLength);
    finally
      // Attempt to reinstall the hook.
      if not InstallHook(GNtQueryVirtualMemoryAddr, @HookedNtQueryVirtualMemory, GOrigBytesNtQueryVirtualMemory) then
        OutputDebugString('CRITICAL: Failed to re-install NtQueryVirtualMemory hook after calling original!');
    end
    else
    begin
      OutputDebugString('CRITICAL: Failed to uninstall NtQueryVirtualMemory hook before calling original!');
      Result := STATUS_ACCESS_DENIED; // Return error if unhook failed.
    end;
  finally
    LeaveCriticalSection(GRedirectCritSect);
  end;
end;

// Hook handler for NtManageHotPatch.
// Intercepts specific operations related to hotpatching, potentially for Windows 11 24H2+ compatibility.
function HookedNtManageHotPatch(
  const AOperation: ULONG;          // Operation code requested.
  const ASubmitBuffer: PVOID;       // Input/Output buffer depending on operation.
  const ASubmitBufferLength: ULONG; // Size of the buffer.
  const AOperationStatus: PNTSTATUS // Output: Status of the hotpatch operation.
): NTSTATUS; stdcall;
const
  // Operation code identified in perfect-loader as relevant for compatibility.
  OPERATION_QUERY_SINGLE_LOADED_PATCH = 8;
begin
  // Check if redirection is active and if this call matches the specific operation we want to intercept.
  // Intercepting OPERATION_QUERY_SINGLE_LOADED_PATCH and returning success seems to bypass potential issues
  // on newer Windows builds related to verifying code integrity or patch status for manually mapped modules.
  if GRedirectionActive and (AOperation = OPERATION_QUERY_SINGLE_LOADED_PATCH) then
  begin
    OutputDebugStringFmt('HookedNtManageHotPatch: Intercepted operation %d (OPERATION_QUERY_SINGLE_LOADED_PATCH). Returning STATUS_SUCCESS.', [AOperation]);

    // Optionally zero the output buffer if provided.
    if Assigned(ASubmitBuffer) and (ASubmitBufferLength > 0) then
      ZeroMemory(ASubmitBuffer, ASubmitBufferLength);

    // Set the operation status to success.
    if Assigned(AOperationStatus) then
      AOperationStatus^ := STATUS_SUCCESS;

    // Return overall success for the NtManageHotPatch call itself.
    Result := STATUS_SUCCESS;
    Exit; // Do not call the original function.
  end;

  // --- Operation not intercepted: Call the original function ---
  // Ensure the pointer to the original function is valid.
  if not Assigned(GOrigNtManageHotPatch) then
  begin
    // Note: This function might not exist on older Windows, so GOrigNtManageHotPatch could legitimately be nil.
    // Only log critically if the hook was expected to be active (i.e., GOrigNtManageHotPatch was assigned during init).
    OutputDebugString('WARNING/CRITICAL: Original NtManageHotPatch pointer (GOrigNtManageHotPatch) is nil in hook handler!');
    Result := STATUS_PROCEDURE_NOT_FOUND; // Or STATUS_NOT_SUPPORTED if it's expected to be missing.
    Exit;
  end;

  // Use the same unhook/call/rehook pattern, protected by the critical section.
  EnterCriticalSection(GRedirectCritSect);
  try
    if UninstallHook(GNtManageHotPatchAddr, GOrigBytesNtManageHotPatch) then
    try
      // Call the original NtManageHotPatch.
      Result := GOrigNtManageHotPatch(AOperation, ASubmitBuffer, ASubmitBufferLength, AOperationStatus);
    finally
      // Attempt to reinstall the hook.
      if not InstallHook(GNtManageHotPatchAddr, @HookedNtManageHotPatch, GOrigBytesNtManageHotPatch) then
        OutputDebugString('CRITICAL: Failed to re-install NtManageHotPatch hook after calling original!');
    end
    else
    begin
      OutputDebugString('CRITICAL: Failed to uninstall NtManageHotPatch hook before calling original!');
      Result := STATUS_ACCESS_DENIED; // Return error if unhook failed.
    end;
  finally
    LeaveCriticalSection(GRedirectCritSect);
  end;
end;

// --- PE Manipulation / Manual Mapping Functions ---

// Helper function to translate PE section characteristics flags to Windows memory protection constants.
function GetProtection(const ACharacteristics: DWORD): DWORD;
begin
  // Check for EXECUTE flag.
  if (ACharacteristics and IMAGE_SCN_MEM_EXECUTE) <> 0 then
  begin
    // Check for READ flag.
    if (ACharacteristics and IMAGE_SCN_MEM_READ) <> 0 then
    begin
      // Check for WRITE flag.
      if (ACharacteristics and IMAGE_SCN_MEM_WRITE) <> 0 then
        Result := PAGE_EXECUTE_READWRITE // Execute + Read + Write
      else
        Result := PAGE_EXECUTE_READ;      // Execute + Read
    end
    else // Not READ
    begin
      // Check for WRITE flag.
      if (ACharacteristics and IMAGE_SCN_MEM_WRITE) <> 0 then
        // Note: Execute + Write (without Read) often maps to Execute + WriteCopy.
        Result := PAGE_EXECUTE_WRITECOPY
      else
        Result := PAGE_EXECUTE;           // Execute only
    end;
  end
  else // Not EXECUTE
  begin
    // Check for READ flag.
    if (ACharacteristics and IMAGE_SCN_MEM_READ) <> 0 then
    begin
      // Check for WRITE flag.
      if (ACharacteristics and IMAGE_SCN_MEM_WRITE) <> 0 then
        Result := PAGE_READWRITE          // Read + Write
      else
        Result := PAGE_READONLY;          // Read only
    end
    else // Not READ
    begin
      // Check for WRITE flag.
      if (ACharacteristics and IMAGE_SCN_MEM_WRITE) <> 0 then
        // Note: Write (without Read) often maps to WriteCopy.
        Result := PAGE_WRITECOPY
      else
        Result := PAGE_NOACCESS;          // No access
    end;
  end;
end;

// Performs basic validation checks on the raw DLL data to ensure it looks like a valid PE image.
function VerifyImage(const AImageBase: Pointer): Boolean;
var
  LDosHeader: PImageDosHeader;    // Pointer to the DOS header.
  LNtHeaders: PImageNtHeaders64;  // Pointer to the NT headers.
begin
  Result := False; // Assume invalid.

  // Check for nil pointer.
  if AImageBase = nil then Exit;

  try
    // 1. Check DOS Header ('MZ' signature).
    LDosHeader := PImageDosHeader(AImageBase);
    if LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then
    begin
      OutputDebugStringFmt('VerifyImage Error: Invalid DOS signature (Expected %X, Got %X)', [IMAGE_DOS_SIGNATURE, LDosHeader^.e_magic]);
      Exit;
    end;

    // 2. Basic sanity check on the offset to NT headers (e_lfanew).
    // Avoid excessively large offsets that might point outside reasonable header area.
    if Cardinal(LDosHeader^._lfanew) > 1024 then
    begin
       OutputDebugStringFmt('VerifyImage Error: Offset to NT Headers (e_lfanew = %d) seems too large.', [LDosHeader^._lfanew]);
       Exit; // Basic sanity check on offset
    end;

    // 3. Calculate pointer to NT Headers and check PE signature ('PE\0\0').
    LNtHeaders := PImageNtHeaders64(PByte(AImageBase) + LDosHeader^._lfanew);
    if LNtHeaders^.Signature <> IMAGE_NT_SIGNATURE then
    begin
      OutputDebugStringFmt('VerifyImage Error: Invalid NT signature (Expected %X, Got %X)', [IMAGE_NT_SIGNATURE, LNtHeaders^.Signature]);
      Exit;
    end;

    // 4. Check Machine field in File Header (ensure it's AMD64/x64).
    if LNtHeaders^.FileHeader.Machine <> IMAGE_FILE_MACHINE_AMD64 then
    begin
      OutputDebugStringFmt('VerifyImage Error: Incorrect machine type (Expected %X for AMD64, Got %X)', [IMAGE_FILE_MACHINE_AMD64, LNtHeaders^.FileHeader.Machine]);
      Exit;
    end;

    // 5. Check Magic field in Optional Header (ensure it's PE32+ for 64-bit).
    if LNtHeaders^.OptionalHeader.Magic <> IMAGE_NT_OPTIONAL_HDR64_MAGIC then
    begin
      OutputDebugStringFmt('VerifyImage Error: Incorrect Optional Header magic (Expected %X for PE32+, Got %X)', [IMAGE_NT_OPTIONAL_HDR64_MAGIC, LNtHeaders^.OptionalHeader.Magic]);
      Exit;
    end;

    // 6. Check Characteristics in File Header (ensure it's marked as an executable image, not an object file).
    if (LNtHeaders^.FileHeader.Characteristics and IMAGE_FILE_EXECUTABLE_IMAGE) = 0 then
    begin
       OutputDebugStringFmt('VerifyImage Error: Image file characteristics do not include IMAGE_FILE_EXECUTABLE_IMAGE.', []);
       Exit;
    end;

    // If all checks passed, the image seems valid enough to proceed.
    Result := True;
  except
    // Catch potential access violations if pointers derived from headers are invalid.
    on E: Exception do
    begin
      OutputDebugStringFmt('VerifyImage: Exception occurred during validation at offset derived from headers. Likely invalid PE structure. Error: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

// Converts a Windows memory protection constant (DWORD) into its human-readable
function GetProtectionString(const AProtection: DWORD): string;
begin
  // Evaluate the input protection constant using a case statement.
  case AProtection of
    // Match known Windows memory protection constants and assign their string name to the Result.
    PAGE_NOACCESS: Result := 'PAGE_NOACCESS';           // Maps to value $01. Disables all access to the committed region of pages.
    PAGE_READONLY: Result := 'PAGE_READONLY';           // Maps to value $02. Enables read-only access to the committed region of pages.
    PAGE_READWRITE: Result := 'PAGE_READWRITE';         // Maps to value $04. Enables read-write access to the committed region of pages.
    PAGE_WRITECOPY: Result := 'PAGE_WRITECOPY';         // Maps to value $08. Enables copy-on-write access to the committed region of pages.
    PAGE_EXECUTE: Result := 'PAGE_EXECUTE';             // Maps to value $10. Enables execute access to the committed region of pages.
    PAGE_EXECUTE_READ: Result := 'PAGE_EXECUTE_READ';   // Maps to value $20. Enables execute and read access.
    PAGE_EXECUTE_READWRITE: Result := 'PAGE_EXECUTE_READWRITE'; // Maps to value $40. Enables execute, read, and write access.
    PAGE_EXECUTE_WRITECOPY: Result := 'PAGE_EXECUTE_WRITECOPY'; // Maps to value $80. Enables execute and copy-on-write access.

  // Note: Combinations with PAGE_GUARD, PAGE_NOCACHE, etc., are not handled here.
  // Add other relevant protection constants if needed (e.g., PAGE_GUARD would be combined with a base protection)
  else
    // If the constant doesn't match any of the specific cases above...
    // Return a string indicating the value is unknown, including its hexadecimal representation for reference.
    Result := Format('Unknown (0x%X)', [AProtection]);
  end; // End of the case statement
end;

// Manually maps the DLL from the byte array into a newly allocated memory region.
function MapModule(
  const ADllBytes: TBytes;      // Input: Raw bytes of the DLL.
  out ABaseAddress: Pointer;    // Output: Base address of the allocated and mapped region.
  out AMappedSize: SIZE_T       // Output: Total size of the allocated region (SizeOfImage).
): Boolean;
var
  LDosHeader: PImageDosHeader;      // Pointer to DOS header within ADllBytes.
  LNtHeaders: PImageNtHeaders64;    // Pointer to NT headers within ADllBytes.
  LSectionHeaders: PImageSectionHeader; // Pointer to the first section header within ADllBytes.
  LSizeOfHeaders: Cardinal;         // Size of PE headers from OptionalHeader.
  LSectionCount: Word;              // Number of sections from FileHeader.
  I: Integer;                       // Loop counter for sections.
  LSectionAddr: Pointer;            // Destination address for the current section in allocated memory.
  LOldProtect: DWORD;               // Dummy variable for VirtualProtect calls.
  LBytesToCopy: NativeUInt;         // Number of bytes to copy for the current section.
  LImageBase: Pointer;              // Pointer to the start of ADllBytes (used as the source PE image base).
  LLastError: DWORD;                // Stores GetLastError value.
  LSectionProtection: DWORD;        // Calculated memory protection for the current section.
begin
  // Initialize outputs and assume failure.
  Result := False;
  ABaseAddress := nil;
  AMappedSize := 0;

  // Validate input array.
  if Length(ADllBytes) = 0 then
  begin
    OutputDebugStringFmt('MapModule Error: Input DllBytes is empty.', []);
    SetLastError(ERROR_INVALID_PARAMETER); // Use appropriate error code.
    Exit;
  end;

  // Get a pointer to the start of the byte array data.
  LImageBase := @ADllBytes[0];

  // Verify if the data looks like a valid PE image.
  if not VerifyImage(LImageBase) then
  begin
    OutputDebugStringFmt('MapModule Error: VerifyImage failed. Input data is not a valid PE image.', []);
    // VerifyImage might set its own error, but set a fallback.
    if GetLastError = 0 then SetLastError(ERROR_INVALID_DATA);
    Exit;
  end;

  try
    // Parse PE headers from the input byte array.
    LDosHeader := PImageDosHeader(LImageBase);
    LNtHeaders := PImageNtHeaders64(PByte(LImageBase) + LDosHeader^._lfanew);

    // Get required size and section info from NT headers.
    AMappedSize := LNtHeaders^.OptionalHeader.SizeOfImage;    // Total virtual size needed for the image.
    LSectionCount := LNtHeaders^.FileHeader.NumberOfSections; // Number of sections to process.
    LSizeOfHeaders := LNtHeaders^.OptionalHeader.SizeOfHeaders; // Size of the PE headers block.

    OutputDebugStringFmt('MapModule: ImageSize=%d (0x%X), NumSections=%d, SizeOfHeaders=%d (0x%X)',
      [AMappedSize, AMappedSize, LSectionCount, LSizeOfHeaders, LSizeOfHeaders]);

    // 1. Allocate virtual memory for the entire image.
    // Use nil for BaseAddress to let the OS choose a suitable location.
    // Allocate with MEM_COMMIT | MEM_RESERVE and initial PAGE_READWRITE protection.
    ABaseAddress := VirtualAlloc(nil, AMappedSize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
    if ABaseAddress = nil then
    begin
      LLastError := GetLastError;
      OutputDebugStringFmt('MapModule Error: VirtualAlloc failed to allocate %d bytes. Error: %d', [AMappedSize, LLastError]);
      SetLastError(LLastError);
      Exit;
    end;
    OutputDebugStringFmt('MapModule: Allocated memory for image at %p (Size: %d)', [ABaseAddress, AMappedSize]);

    // 2. Copy the PE headers from the input buffer to the allocated memory.
    // Check if header size exceeds the input buffer size (indicates corrupt PE).
    if LSizeOfHeaders > Length(ADllBytes) then
    begin
      OutputDebugStringFmt('MapModule Error: SizeOfHeaders (%d) exceeds input DllSize (%d). Corrupt PE.', [LSizeOfHeaders, Length(ADllBytes)]);
      raise Exception.Create('Invalid PE: SizeOfHeaders > DllSize'); // Raise exception to trigger cleanup.
    end;
    Move(LImageBase^, ABaseAddress^, LSizeOfHeaders);
    OutputDebugStringFmt('MapModule: Copied %d header bytes from %p to %p.', [LSizeOfHeaders, LImageBase, ABaseAddress]);

    // Optional: Change protection of the copied headers to PAGE_READONLY.
    // Some security software might flag writable headers. Ignore failure if it occurs.
    if not VirtualProtect(ABaseAddress, LSizeOfHeaders, PAGE_READONLY, LOldProtect) then
      OutputDebugStringFmt('MapModule Warning: Failed to set header protection to READONLY at %p. Error: %d', [ABaseAddress, GetLastError]);

    // 3. Find the location of the first section header.
    // It follows immediately after the Optional Header.
    {$POINTERMATH ON}
    LSectionHeaders := PImageSectionHeader(
      PByte(LNtHeaders)                      // Start at NT Headers
      + SizeOf(DWORD)                        // Add size of Signature ('PE\0\0')
      + SizeOf(TImageFileHeader)             // Add size of File Header
      + LNtHeaders^.FileHeader.SizeOfOptionalHeader // Add size of Optional Header (variable size)
    );
    {$POINTERMATH OFF}

    // 4. Iterate through each section, copy its data, and set its memory protection.
    for I := 0 to LSectionCount - 1 do
    begin
      // Log section details (use PAnsiChar for name as it's defined as AnsiChar[8]).
      OutputDebugStringFmt('MapModule: Processing section %d: Name="%.*s", VA=0x%X, VSize=%d, RawPtr=0x%X, RawSize=%d, Char=0x%X', [
          I, IMAGE_SIZEOF_SHORT_NAME, PAnsiChar(@LSectionHeaders^.Name[0]),
          LSectionHeaders^.VirtualAddress, LSectionHeaders^.Misc.VirtualSize,
          LSectionHeaders^.PointerToRawData, LSectionHeaders^.SizeOfRawData,
          LSectionHeaders^.Characteristics]);

      // Calculate the destination address for this section's data within the allocated memory block.
      // Destination Address = Allocated Base Address + Section's Virtual Address (RVA).
      LSectionAddr := PByte(ABaseAddress) + LSectionHeaders^.VirtualAddress;

      // Copy the section's raw data from the input buffer (ADllBytes) if SizeOfRawData > 0.
      if LSectionHeaders^.SizeOfRawData > 0 then
      begin
        // Sanity check: Ensure the raw data range [PointerToRawData, PointerToRawData + SizeOfRawData]
        // is within the bounds of the input DllBytes array.
        if (LSectionHeaders^.PointerToRawData + LSectionHeaders^.SizeOfRawData) > NativeUInt(Length(ADllBytes)) then
        begin
           OutputDebugStringFmt('MapModule Error: Section %d raw data range (Offset=%d, Size=%d) exceeds input DllSize (%d). Corrupt PE.',
                                [I, LSectionHeaders^.PointerToRawData, LSectionHeaders^.SizeOfRawData, Length(ADllBytes)]);
           raise Exception.CreateFmt('Invalid PE: Section %d raw data out of bounds', [I]);
        end;

        // Determine the number of bytes to copy. Usually, this is the minimum of the raw data size
        // and the virtual size. Copying more than the virtual size would write past the section's intended bounds.
        // Copying more than the raw size (if VirtualSize > RawSize) is unnecessary; the extra space should be zero-filled implicitly
        // by VirtualAlloc or handled by the loader later (e.g., for .bss sections).
        LBytesToCopy := Min(NativeUInt(LSectionHeaders^.SizeOfRawData), NativeUInt(LSectionHeaders^.Misc.VirtualSize));

        if LBytesToCopy > 0 then
        begin
          // Perform the copy from (Input Buffer + RawDataOffset) to (Allocated Memory + VirtualAddress).
          Move((PByte(LImageBase) + LSectionHeaders^.PointerToRawData)^, LSectionAddr^, LBytesToCopy);
          OutputDebugStringFmt('MapModule: Copied %d bytes for section %d from offset %d to VA 0x%X.',
             [LBytesToCopy, I, LSectionHeaders^.PointerToRawData, NativeUInt(LSectionAddr) - NativeUInt(ABaseAddress)]);
        end
        else
           OutputDebugStringFmt('MapModule: Section %d has SizeOfRawData > 0 but LBytesToCopy is 0 (likely VirtualSize is 0). Skipping copy.', [I]);
      end
      else
      begin
          // Section has no raw data (e.g., .bss). The memory allocated by VirtualAlloc is already zeroed.
          OutputDebugStringFmt('MapModule: Section %d has SizeOfRawData = 0. Skipping copy.', [I]);
      end;

      // 5. Set the memory protection for this section based on its characteristics.
      // Only apply protection if the virtual size is greater than zero.
      if LSectionHeaders^.Misc.VirtualSize > 0 then
      begin
        // Calculate the required Windows page protection flags (e.g., PAGE_EXECUTE_READ).
        LSectionProtection := GetProtection(LSectionHeaders^.Characteristics);
        OutputDebugStringFmt('MapModule: Setting protection 0x%X (%s) for section %d at %p (Size: %d).',
          [LSectionProtection, GetProtectionString(LSectionProtection), I, LSectionAddr, LSectionHeaders^.Misc.VirtualSize]);

        // Apply the protection to the section's memory region.
        if not VirtualProtect(LSectionAddr, LSectionHeaders^.Misc.VirtualSize, LSectionProtection, LOldProtect) then
        begin
          // Log a warning if VirtualProtect fails. This might happen for various reasons
          // (e.g., conflicting protections, invalid parameters) but might not always be fatal.
          OutputDebugStringFmt('MapModule Warning: VirtualProtect failed for section %d (VA=0x%X, Size=%d, Protection=0x%X). Error: %d',
                                [I, LSectionHeaders^.VirtualAddress, LSectionHeaders^.Misc.VirtualSize, LSectionProtection, GetLastError]);
        end;
      end
      else
         OutputDebugStringFmt('MapModule: Section %d has VirtualSize = 0. Skipping VirtualProtect.', [I]);

      // Move the pointer to the next section header structure in the PE header data.
      {$POINTERMATH ON}
      Inc(PByte(LSectionHeaders), SizeOf(TImageSectionHeader));
      {$POINTERMATH OFF}
    end;

    // If we reached here without exceptions, mapping was successful.
    Result := True;
    OutputDebugStringFmt('MapModule: Successfully mapped all sections.', []);

  except
    // Catch any exceptions during mapping (e.g., access violations, raised exceptions from checks).
    on E: Exception do
    begin
      OutputDebugStringFmt('MapModule Exception: %s. Rolling back.', [E.Message]);
      // Clean up: Release the allocated memory block if allocation was successful but mapping failed afterwards.
      if ABaseAddress <> nil then
      begin
        OutputDebugStringFmt('MapModule: Releasing allocated memory at %p due to exception.', [ABaseAddress]);
        VirtualFree(ABaseAddress, 0, MEM_RELEASE);
      end;
      // Reset output parameters.
      ABaseAddress := nil;
      AMappedSize := 0;
      Result := False;
      // Set a generic error code if none was set previously.
      if GetLastError = 0 then SetLastError(ERROR_INVALID_DATA);
    end;
  end;
end;

// --- Post-Load Operation Functions (using PlFlags) ---

// Sets the LDRP_DONT_CALL_FOR_THREADS flag in the module's LDR_DATA_TABLE_ENTRY.
// This prevents DllMain from being called for THREAD_ATTACH/THREAD_DETACH notifications.
function DisableThreadCallbacks(const APeBase: Pointer): Boolean;
var
  LLdrEntry: PLDR_DATA_TABLE_ENTRY; // Pointer to the module's loader entry.
  LCookie: NativeUInt;             // Cookie for loader lock.
begin
  Result := False; // Assume failure.

  // Acquire the loader lock for safe access to LDR data.
  LCookie := LockLoader();
  if LCookie = 0 then
  begin
    OutputDebugStringFmt('DisableThreadCallbacks Error: Failed to acquire loader lock.', []);
    Exit; // Exit if lock could not be acquired.
  end;
  try
    // Find the LDR entry corresponding to the loaded module's base address.
    LLdrEntry := GetLdrDataTableEntry(APeBase);
    if LLdrEntry <> nil then
    begin
      OutputDebugStringFmt('DisableThreadCallbacks: Found LDR entry for module at %p. Setting LDRP_DONT_CALL_FOR_THREADS flag (current flags: 0x%X).',
        [APeBase, LLdrEntry^.Flags]);
      // Set the flag using a bitwise OR operation.
      LLdrEntry^.Flags := LLdrEntry^.Flags or LDRP_DONT_CALL_FOR_THREADS;
      Result := True; // Operation successful.
       OutputDebugStringFmt('DisableThreadCallbacks: New flags: 0x%X.', [LLdrEntry^.Flags]);
    end else
       OutputDebugStringFmt('DisableThreadCallbacks Error: Could not find LDR entry for module at %p.', [APeBase]);
  finally
    // Release the loader lock.
    UnlockLoader(LCookie);
  end;
end;

// Overwrites the PE headers of the loaded module in memory with the headers read from a specified file.
// This can be used for obfuscation or anti-analysis techniques.
function OverwriteHeaders(const APeBase: Pointer; const AFilename: WideString): Boolean;
var
  LFile: THandle;           // Handle to the file specified by AFilename.
  LDosHeader: PImageDosHeader; // Pointer to DOS header of the in-memory module.
  LNtHeaders: PImageNtHeaders64; // Pointer to NT headers of the in-memory module.
  LSizeOfHeaders: Cardinal; // Size of headers to read/write.
  LOldProtect: DWORD;       // Stores original memory protection.
  LBytesRead: DWORD;        // Number of bytes actually read from the file.
  LTempBytes: TBytes;       // Temporary buffer to hold headers read from the file.
  LLastError: DWORD;        // Stores GetLastError value.
begin
  Result := False; // Assume failure.

  // Validate inputs.
  if (APeBase = nil) or (AFilename = '') then
  begin
     OutputDebugStringFmt('OverwriteHeaders Error: APeBase is nil or AFilename is empty.', []);
     Exit;
  end;

  OutputDebugStringFmt('OverwriteHeaders: Attempting to overwrite headers at %p using header data from file "%s"', [APeBase, AFilename]);

  // 1. Open the specified file for reading.
  LFile := CreateFileW(PWideChar(AFilename), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if LFile = INVALID_HANDLE_VALUE then
  begin
     LLastError := GetLastError;
     OutputDebugStringFmt('OverwriteHeaders Error: CreateFileW failed to open "%s". Error: %d', [AFilename, LLastError]);
     Exit;
  end;
  try
    // 2. Determine the size of headers from the *in-memory* module.
    // We need this to know how many bytes to read from the file and overwrite in memory.
    try
      LDosHeader := PImageDosHeader(APeBase);
      // Basic validation of in-memory headers before proceeding.
      if LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then raise Exception.Create('Invalid DOS signature found in memory at APeBase');
      LNtHeaders := PImageNtHeaders64(PByte(APeBase) + LDosHeader^._lfanew);
      if LNtHeaders^.Signature <> IMAGE_NT_SIGNATURE then raise Exception.Create('Invalid NT signature found in memory at APeBase');
      LSizeOfHeaders := LNtHeaders^.OptionalHeader.SizeOfHeaders;
    except
      // Catch access violations if APeBase doesn't point to valid PE headers.
      on E: Exception do
      begin
        OutputDebugStringFmt('OverwriteHeaders Error: Failed to read headers from memory at %p to determine size. Exception: %s', [APeBase, E.Message]);
        Exit; // Exit without closing handle (done in finally).
      end;
    end;

    // Ensure SizeOfHeaders is valid.
    if LSizeOfHeaders = 0 then
    begin
      OutputDebugStringFmt('OverwriteHeaders Error: SizeOfHeaders determined from memory at %p is zero.', [APeBase]);
      Exit;
    end;
    OutputDebugStringFmt('OverwriteHeaders: SizeOfHeaders in memory is %d bytes.', [LSizeOfHeaders]);

    // 3. Read the header data from the file into a temporary buffer.
    SetLength(LTempBytes, LSizeOfHeaders); // Allocate buffer.
    if not ReadFile(LFile, LTempBytes[0], LSizeOfHeaders, LBytesRead, nil) or (LBytesRead <> LSizeOfHeaders) then
    begin
      LLastError := GetLastError;
      OutputDebugStringFmt('OverwriteHeaders Error: ReadFile failed or read incorrect size (%d bytes read, expected %d) for "%s". Error: %d', [LBytesRead, LSizeOfHeaders, AFilename, LLastError]);
      Exit;
    end;
    OutputDebugStringFmt('OverwriteHeaders: Successfully read %d header bytes from file "%s".', [LBytesRead, AFilename]);

    // 4. Make the header region of the in-memory module writable.
    if VirtualProtect(APeBase, LSizeOfHeaders, PAGE_READWRITE, LOldProtect) then
    try
      // 5. Overwrite the in-memory headers with the bytes read from the file.
      Move(LTempBytes[0], APeBase^, LSizeOfHeaders);
      Result := True; // Overwrite successful.
      OutputDebugStringFmt('OverwriteHeaders: Successfully overwrote %d header bytes at %p.', [LSizeOfHeaders, APeBase]);
    finally
      // 6. Restore the original memory protection.
      VirtualProtect(APeBase, LSizeOfHeaders, LOldProtect, LOldProtect); // Use dummy for last param.
    end
    else
    begin
      // VirtualProtect failed.
      LLastError := GetLastError;
      OutputDebugStringFmt('OverwriteHeaders Error: VirtualProtect PAGE_READWRITE failed for memory at %p (size %d). Error: %d', [APeBase, LSizeOfHeaders, LLastError]);
    end;

  finally
    // 7. Close the file handle.
    CloseHandle(LFile);
  end;
end;

// Helper function to safely unlink a LIST_ENTRY node from its doubly linked list.
procedure UnlinkEntry(const AListEntry: PLIST_ENTRY);
begin
  // Basic validation to prevent crashes if pointers are invalid or list is corrupted.
  if (AListEntry = nil) or (AListEntry^.Flink = nil) or (AListEntry^.Blink = nil) then
  begin
    OutputDebugStringFmt('UnlinkEntry Warning: Attempted to unlink nil entry or entry with nil Flink/Blink at %p.', [AListEntry]);
    Exit;
  end;

  // Check for self-referencing loops, which indicate corruption.
  // Cast Flink/Blink to PLIST_ENTRY before comparing pointers.
  if (PLIST_ENTRY(AListEntry^.Flink) = AListEntry) or (PLIST_ENTRY(AListEntry^.Blink) = AListEntry) then
  begin
     OutputDebugStringFmt('UnlinkEntry Warning: List entry at %p points to itself (corrupted list?). Skipping unlink.', [AListEntry]);
     Exit;
  end;

  // Perform the unlink operation:
  // - Set the Flink of the previous node (Blink) to point to the next node (Flink).
  // - Set the Blink of the next node (Flink) to point to the previous node (Blink).
  try
    // Ensure Blink's Flink and Flink's Blink are valid pointers before dereferencing *them*.
    // (We already checked AListEntry.Flink and AListEntry.Blink are not nil)
    if (AListEntry^.Blink^.Flink <> nil) and (AListEntry^.Flink^.Blink <> nil) then
    begin
      AListEntry^.Blink^.Flink := AListEntry^.Flink;
      AListEntry^.Flink^.Blink := AListEntry^.Blink;
      OutputDebugStringFmt('UnlinkEntry: Unlinked entry at %p.', [AListEntry]);
    end else
       OutputDebugStringFmt('UnlinkEntry Warning: Neighbor pointers (Blink->Flink or Flink->Blink) are nil for entry at %p. Cannot safely complete unlink.', [AListEntry]);
  except
     // Catch potential Access Violation during pointer dereferencing if list is severely corrupted.
     on E: Exception do
       OutputDebugStringFmt('UnlinkEntry Exception: Access violation while unlinking entry at %p. Error: %s. List may be corrupted.', [AListEntry, E.Message]);
  end;
end;

// Removes the loaded module's LDR_DATA_TABLE_ENTRY from the PEB's loader lists.
// This effectively hides the module from standard enumeration methods (e.g., Toolhelp32Snapshot).
function UnlinkModule(const APeBase: Pointer): Boolean;
var
  LLdrEntry: PLDR_DATA_TABLE_ENTRY; // Pointer to the module's loader entry.
  LCookie: NativeUInt;             // Cookie for loader lock.
  LHashLinksPtr: PLIST_ENTRY;      // Pointer to the HashLinks list entry field.
begin
  Result := False; // Assume failure.

  // Acquire the loader lock for safe access to LDR data.
  LCookie := LockLoader();
  if LCookie = 0 then
  begin
    OutputDebugStringFmt('UnlinkModule Error: Failed to acquire loader lock.', []);
    Exit;
  end;
  try
    // Find the LDR entry for the module.
    LLdrEntry := GetLdrDataTableEntry(APeBase);
    if LLdrEntry <> nil then
    begin
      // Log the operation, including the base DLL name if available.
      OutputDebugStringFmt('UnlinkModule: Found LDR entry for module at %p. Attempting to unlink from lists. BaseName: "%.*s"', [
          APeBase,
          LLdrEntry^.BaseDllName.Length div SizeOf(WideChar), // Length is in bytes, divide by 2 for char count.
          LLdrEntry^.BaseDllName.Buffer]); // Buffer points to the wide char string.

      // Unlink the entry from the three main doubly linked lists.
      UnlinkEntry(@LLdrEntry^.InLoadOrderLinks);
      UnlinkEntry(@LLdrEntry^.InMemoryOrderLinks);
      UnlinkEntry(@LLdrEntry^.InInitializationOrderLinks);

      // Unlink from the HashLinks list. The HashLinks field is part of a union
      // and typically follows the TlsIndex field in the structure layout.
      // Use pointer arithmetic based on the assumed structure layout. This is potentially fragile.
      {$POINTERMATH ON}
      LHashLinksPtr := PLIST_ENTRY(NativeUInt(@LLdrEntry^.TlsIndex) + SizeOf(LLdrEntry^.TlsIndex));
      {$POINTERMATH OFF}
      OutputDebugStringFmt('UnlinkModule: Attempting to unlink HashLinks entry at derived address %p.', [LHashLinksPtr]);
      UnlinkEntry(LHashLinksPtr);

      Result := True; // Unlinking successful.
      OutputDebugStringFmt('UnlinkModule: Finished unlinking attempts for module at %p.', [APeBase]);
    end else
      OutputDebugStringFmt('UnlinkModule Error: Could not find LDR entry for module at %p. Cannot unlink.', [APeBase]);
  finally
    // Release the loader lock.
    UnlockLoader(LCookie);
  end;
end;

// Zeroes out the PE header region of the loaded module in memory.
// This can hinder memory analysis and dumping tools.
function RemoveHeaders(const APeBase: Pointer): Boolean;
var
  LDosHeader: PImageDosHeader; // Pointer to DOS header of the in-memory module.
  LNtHeaders: PImageNtHeaders64; // Pointer to NT headers of the in-memory module.
  LSizeOfHeaders: Cardinal; // Size of headers to zero out.
  LOldProtect: DWORD;       // Stores original memory protection.
  LLastError: DWORD;        // Stores GetLastError value.
begin
  Result := False; // Assume failure.

  // Validate input.
  if APeBase = nil then
  begin
    OutputDebugStringFmt('RemoveHeaders Error: APeBase is nil.', []);
    Exit;
  end;

  OutputDebugStringFmt('RemoveHeaders: Attempting to zero PE headers at %p', [APeBase]);
  try
    // 1. Determine the size of headers from the in-memory module.
    LDosHeader := PImageDosHeader(APeBase);
    // Basic validation.
    if LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then raise Exception.Create('Invalid DOS signature found in memory at APeBase');
    LNtHeaders := PImageNtHeaders64(PByte(APeBase) + LDosHeader^._lfanew);
    if LNtHeaders^.Signature <> IMAGE_NT_SIGNATURE then raise Exception.Create('Invalid NT signature found in memory at APeBase');
    LSizeOfHeaders := LNtHeaders^.OptionalHeader.SizeOfHeaders;

    // Ensure SizeOfHeaders is valid.
    if LSizeOfHeaders = 0 then
    begin
      OutputDebugStringFmt('RemoveHeaders Error: SizeOfHeaders determined from memory at %p is zero.', [APeBase]);
      Exit;
    end;
    OutputDebugStringFmt('RemoveHeaders: SizeOfHeaders is %d bytes.', [LSizeOfHeaders]);

    // 2. Make the header region writable.
    if VirtualProtect(APeBase, LSizeOfHeaders, PAGE_READWRITE, LOldProtect) then
    try
      // 3. Zero out the memory region occupied by the headers.
      ZeroMemory(APeBase, LSizeOfHeaders);
      Result := True; // Zeroing successful.
      OutputDebugStringFmt('RemoveHeaders: Successfully zeroed %d header bytes at %p.', [LSizeOfHeaders, APeBase]);
    finally
      // 4. Restore the original memory protection (or try to set to PAGE_READONLY).
      // Note: Restoring LOldProtect might make it writable again if it was originally.
      // Consider setting to a more restrictive protection like PAGE_READONLY or even PAGE_NOACCESS if appropriate.
      // Using LOldProtect for now to match OverwriteHeaders behavior.
      VirtualProtect(APeBase, LSizeOfHeaders, LOldProtect, LOldProtect);
    end
    else
    begin
      // VirtualProtect failed.
      LLastError := GetLastError;
      OutputDebugStringFmt('RemoveHeaders Error: VirtualProtect PAGE_READWRITE failed for memory at %p (size %d). Error: %d', [APeBase, LSizeOfHeaders, LLastError]);
    end;
  except
    // Catch exceptions during header access.
     on E: Exception do
     begin
       OutputDebugStringFmt('RemoveHeaders Error: Failed to access headers in memory at %p. Exception: %s', [APeBase, E.Message]);
     end;
  end;
end;

// --- Core Function: MapAndResolve ---
// Orchestrates the entire memory loading process:
// 1. Manually maps the DLL from `ADllBase` into memory (`MapModule`).
// 2. Installs hooks on `NtMapViewOfSection` (and optionally `NtQueryVirtualMemory`, `NtManageHotPatch`).
// 3. Calls the standard `LoadLibraryExW` on a *dummy* existing file (`AFilename`).
// 4. The hook intercepts the `NtMapViewOfSection` call made by `LoadLibraryExW`, preventing it from mapping the dummy file
//    and instead providing the address of the manually mapped DLL.
// 5. `LoadLibraryExW` then proceeds with the rest of the loading process (relocations, import resolution, DllMain call) using the manually mapped image.
// 6. Uninstalls the hooks.
// 7. Performs optional post-load operations based on `APlFlags`.
function MapAndResolve(
  const ADllBase: Pointer;             // Input: Pointer to the raw DLL bytes in memory.
  const ADllSize: NativeUInt;          // Input: Size of the raw DLL bytes.
  const AFlags: DWORD = 0;             // Input: Standard flags for LoadLibraryExW (e.g., DONT_RESOLVE_DLL_REFERENCES). Usually 0.
  const AFilename: PWideChar = nil;    // Input: REQUIRED. Full path to an *existing* file on disk. The content doesn't matter, but the file must exist for LoadLibraryExW to proceed far enough to call NtMapViewOfSection. A system DLL like "advapi32res.dll" is often used.
  const APlFlags: DWORD = 0;           // Input: Optional custom flags (LOAD_FLAGS_*) for post-load operations (e.g., LOAD_FLAGS_NO_HEADERS).
  const AModListName: PWideChar = nil  // Input: Optional. Ignored in this implementation (relevant for TxF loading).
    ): HMODULE; stdcall;               // Output: HMODULE handle to the loaded library, or 0 on failure.
var
  LBytes: TBytes;                     // Local copy of the input DLL bytes.
  LMappedAddress: Pointer;            // Base address where MapModule allocated memory.
  LCurrentMappedSize: SIZE_T;         // Size of the memory allocated by MapModule.
  LLib: HMODULE;                      // Result handle from LoadLibraryExW.
  LWideFileName: WideString;          // Delphi string copy of AFilename.
  LHooksInstalledNtMapView: Boolean;  // Flag: True if NtMapView hook was successfully installed.
  LHooksInstalledNtQueryVM: Boolean;  // Flag: True if NtQueryVirtualMemory hook was installed.
  LHooksInstalledNtManageHP: Boolean; // Flag: True if NtManageHotPatch hook was installed.
  LLdrEntryName: WideString;          // Stores the FullDllName from the LDR entry for OverwriteHeaders.
  LCookie: NativeUInt;                // Cookie for loader lock.
  LLastErrorValue: DWORD;             // Stores GetLastError at critical points.
  LErrorMsg: String;                  // Temporary error message string.
  LLdrEntry: PLDR_DATA_TABLE_ENTRY;   // Pointer for LDR entry lookup.
begin
  // Initialize results and state variables.
  Result := 0;
  LMappedAddress := nil;
  LCurrentMappedSize := 0;
  LHooksInstalledNtQueryVM := False;
  LHooksInstalledNtManageHP := False;

  OutputDebugStringFmt('MapAndResolve: Starting process. Input DllSize=%d, PlFlags=0x%X', [ADllSize, APlFlags]);

  // --- Step 0: Basic Validation and Copy DLL Data ---
  // Ensure input pointer and size are valid.
  if (ADllBase = nil) or (ADllSize = 0) then
  begin
    OutputDebugStringFmt('MapAndResolve Error: ADllBase is nil or ADllSize is zero.', []);
    SetLastError(ERROR_INVALID_PARAMETER);
    Exit;
  end;
  // Make a local copy of the DLL bytes to work with.
  SetLength(LBytes, ADllSize);
  Move(ADllBase^, LBytes[0], ADllSize);

  // --- Step 1: Validate Dummy FileName Parameter ---
  // AFilename is crucial. It must point to a real, accessible file.
  if (AFilename = nil) or (AFilename^ = #0) then
  begin
    OutputDebugStringFmt('MapAndResolve Error: AFilename parameter is required and must point to an existing file path.', []);
    SetLastError(ERROR_INVALID_PARAMETER);
    Exit;
  end;
  LWideFileName := AFilename; // Copy PWideChar to Delphi WideString.

  // Check if the dummy file actually exists. LoadLibraryExW checks this early on.
  if GetFileAttributesW(PWideChar(LWideFileName)) = INVALID_FILE_ATTRIBUTES then
  begin
    LLastErrorValue := GetLastError;
    OutputDebugStringFmt('MapAndResolve Error: Specified dummy FileName "%s" does not exist or is inaccessible. GetFileAttributesW Error: %d', [LWideFileName, LLastErrorValue]);
    SetLastError(LLastErrorValue); // Preserve the error from GetFileAttributesW.
    Exit;
  end;
  OutputDebugStringFmt('MapAndResolve: Using dummy FileName "%s" for LoadLibraryExW call.', [LWideFileName]);

  // --- Step 2: Manually Map the DLL from Memory ---
  // Allocate memory and copy PE headers and sections into it.
  if not MapModule(LBytes, LMappedAddress, LCurrentMappedSize) then
  begin
    // MapModule logs details and should set GetLastError appropriately.
    LLastErrorValue := GetLastError;
    OutputDebugStringFmt('MapAndResolve Error: MapModule failed. Aborting. LastError=%d', [LLastErrorValue]);
    // Ensure an error code is set if MapModule didn't set one.
    if LLastErrorValue = 0 then SetLastError(ERROR_INVALID_DATA);
    Exit; // Exit without freeing LMappedAddress, as MapModule should have cleaned up on failure.
  end;
  // At this point, LMappedAddress points to the manually mapped image in memory.

  // --- Step 3: Initialize NT Function Pointers ---
  // Ensure pointers to NTDLL functions (both hooked and called directly) are resolved.
  InitializeNtFunctions(); // Safe to call multiple times.

  // --- Step 4: Install Hooks ---
  // Install hooks within a critical section to ensure thread safety during hook setup and state modification.
  EnterCriticalSection(GRedirectCritSect);
  try
    // Configure global state variables used by the hook handlers.
    GMappedBaseAddress := LMappedAddress;      // The address the NtMapView hook should return.
    GMappedSize := LCurrentMappedSize;         // The size the NtMapView hook should return.
    GInterceptNextMapView := False;            // Ensure the intercept flag is initially FALSE. It will be set TRUE just before LoadLibraryExW.
    GRedirectionActive := True;                // Globally enable checks within hook handlers.

    // Install NtMapViewOfSection Hook (Essential for redirection).
    if Assigned(GNtMapViewOfSectionAddr) then
    begin
      // Store the original function address before hooking.
      GOrigNtMapViewOfSection := TNtMapViewOfSection(GNtMapViewOfSectionAddr);
      // Attempt to install the JMP hook.
      LHooksInstalledNtMapView := InstallHook(GNtMapViewOfSectionAddr, @HookedNtMapViewOfSection, GOrigBytesNtMapView);
    end else begin
      // If NtMapViewOfSection address wasn't found, we cannot proceed.
      OutputDebugStringFmt('MapAndResolve Error: NtMapViewOfSection address is not resolved (GNtMapViewOfSectionAddr=nil). Cannot install essential hook.', []);
      // Set flag to indicate failure; checked below.
      LHooksInstalledNtMapView := False;
    end;

    // Install NtQueryVirtualMemory Hook (Optional, for 24H2+ compatibility).
    if Assigned(GNtQueryVirtualMemoryAddr) then
    begin
      GOrigNtQueryVirtualMemory := TNtQueryVirtualMemory(GNtQueryVirtualMemoryAddr);
      LHooksInstalledNtQueryVM := InstallHook(GNtQueryVirtualMemoryAddr, @HookedNtQueryVirtualMemory, GOrigBytesNtQueryVirtualMemory);
      OutputDebugStringFmt('MapAndResolve: NtQueryVirtualMemory hook installed status: %s', [BoolToStr(LHooksInstalledNtQueryVM, True)]);
    end else
        OutputDebugStringFmt('MapAndResolve: NtQueryVirtualMemory address not resolved. Skipping hook installation.', []);


    // Install NtManageHotPatch Hook (Optional, for 24H2+ compatibility).
    if Assigned(GNtManageHotPatchAddr) then
    begin
      GOrigNtManageHotPatch := TNtManageHotPatch(GNtManageHotPatchAddr);
      LHooksInstalledNtManageHP := InstallHook(GNtManageHotPatchAddr, @HookedNtManageHotPatch, GOrigBytesNtManageHotPatch);
      OutputDebugStringFmt('MapAndResolve: NtManageHotPatch hook installed status: %s', [BoolToStr(LHooksInstalledNtManageHP, True)]);
    end else
      OutputDebugStringFmt('MapAndResolve: NtManageHotPatch address not resolved. Skipping hook installation.', []);


    // CRITICAL CHECK: Ensure the essential NtMapViewOfSection hook was successfully installed.
    if not LHooksInstalledNtMapView then
    begin
      LErrorMsg := 'MapAndResolve Error: Failed to install the essential NtMapViewOfSection hook. Aborting process.';
      OutputDebugString(PChar(LErrorMsg));
      // Clean up the manually mapped memory since the process will fail.
      if LMappedAddress <> nil then
      begin
        OutputDebugStringFmt('MapAndResolve: Releasing manually mapped memory at %p due to hook install failure.', [LMappedAddress]);
        VirtualFree(LMappedAddress, 0, MEM_RELEASE);
        LMappedAddress := nil; // Prevent accidental use later.
      end;
      // Reset redirection state.
      GRedirectionActive := False;
      GMappedBaseAddress := nil;
      SetLastError(ERROR_HOOK_NOT_INSTALLED); // Set specific error code.
      // Leave critical section before exiting the function.
      LeaveCriticalSection(GRedirectCritSect);
      Exit; // Abort MapAndResolve.
    end;
    OutputDebugStringFmt('MapAndResolve: Essential NtMapViewOfSection hook installed successfully.', []);

  finally
    // Release the critical section. Hooks remain active for the LoadLibrary call.
    LeaveCriticalSection(GRedirectCritSect);
  end;

  // --- Step 5: Call LoadLibraryExW to Trigger Loader ---
  // This is the key step where we leverage the Windows loader.
  OutputDebugStringFmt('MapAndResolve: Setting GInterceptNextMapView=True and calling LoadLibraryExW("%s", Flags=0x%X)...', [LWideFileName, AFlags]);
  SetLastError(0); // Clear any previous errors before the call.

  // Set the flag to signal the NtMapView hook to intercept the *very next* call it receives.
  GInterceptNextMapView := True;

  try
    // Call LoadLibraryExW using the dummy filename.
    // The loader will:
    // - Check the file exists (passed earlier).
    // - Attempt to create a section object for the file.
    // - Call NtMapViewOfSection to map the section.
    // - Our hook intercepts NtMapViewOfSection, prevents mapping the file, and returns our LMappedAddress.
    // - The loader receives STATUS_IMAGE_NOT_AT_BASE and the LMappedAddress.
    // - The loader proceeds with relocations (if needed), import resolution, TLS setup, and DllMain call, all using the memory at LMappedAddress.
    LLib := LoadLibraryExW(PWideChar(LWideFileName), 0, AFlags); // Second param (hFile) must be 0.
  finally
    // Ensure the intercept flag is reset, even if LoadLibraryExW raises an exception.
    // The hook handler *should* reset it on successful interception, but this is a safety measure.
    GInterceptNextMapView := False;
    OutputDebugStringFmt('MapAndResolve: GInterceptNextMapView reset to False.', []);
  end;

  // Capture the result and error code immediately after LoadLibraryExW returns.
  LLastErrorValue := GetLastError();
  Result := LLib; // Store the potential HMODULE in the function result.

  OutputDebugStringFmt('MapAndResolve: LoadLibraryExW returned handle 0x%p. LastError=%d (%s)',
    [Pointer(LLib), LLastErrorValue, SysErrorMessage(LLastErrorValue)]);

  // --- Step 6: Uninstall Hooks ---
  // Hooks are no longer needed after LoadLibraryExW has completed (successfully or not).
  OutputDebugStringFmt('MapAndResolve: Uninstalling hooks...', []);
  EnterCriticalSection(GRedirectCritSect);
  try
    // Uninstall hooks in reverse order of installation (optional, but good practice).
    if LHooksInstalledNtManageHP and Assigned(GNtManageHotPatchAddr) then
      if not UninstallHook(GNtManageHotPatchAddr, GOrigBytesNtManageHotPatch) then
        OutputDebugStringFmt('MapAndResolve Warning: Failed to uninstall NtManageHotPatch hook.', []);

    if LHooksInstalledNtQueryVM and Assigned(GNtQueryVirtualMemoryAddr) then
      if not UninstallHook(GNtQueryVirtualMemoryAddr, GOrigBytesNtQueryVirtualMemory) then
         OutputDebugStringFmt('MapAndResolve Warning: Failed to uninstall NtQueryVirtualMemory hook.', []);

    // Uninstall the essential NtMapView hook.
    if LHooksInstalledNtMapView and Assigned(GNtMapViewOfSectionAddr) then
      if not UninstallHook(GNtMapViewOfSectionAddr, GOrigBytesNtMapView) then
        OutputDebugStringFmt('MapAndResolve Warning: Failed to uninstall NtMapViewOfSection hook.', []); // More critical warning.

    // Reset global state variables related to hooking and redirection.
    GRedirectionActive := False;
    // If LoadLibraryExW succeeded (LLib <> 0), the OS loader now "owns" the memory region.
    // If LoadLibraryExW failed (LLib = 0), we will free LMappedAddress later.
    // Do not reset GMappedBaseAddress here yet, needed for potential cleanup.
    // GMappedBaseAddress := nil;
    GMappedSize := 0;
    // GOriginalFileSize := 0; // No longer used directly.

    // Clear original byte buffers and function pointers.
    SetLength(GOrigBytesNtMapView, 0);
    SetLength(GOrigBytesNtQueryVirtualMemory, 0);
    SetLength(GOrigBytesNtManageHotPatch, 0);
    GOrigNtMapViewOfSection := nil;
    GOrigNtQueryVirtualMemory := nil;
    GOrigNtManageHotPatch := nil;
  finally
    LeaveCriticalSection(GRedirectCritSect);
  end;
  OutputDebugStringFmt('MapAndResolve: Hook uninstallation process completed.', []);

  // --- Step 7: Post-processing and Cleanup ---
  if LLib <> 0 then // LoadLibraryExW Succeeded
  begin
    OutputDebugStringFmt('MapAndResolve: LoadLibraryExW succeeded (HMODULE=0x%p). Performing post-load operations (PlFlags=0x%X)...', [Pointer(LLib), APlFlags]);

    // Important: Since LoadLibraryExW succeeded, the memory region at LMappedAddress is now managed by the OS loader.
    // We must NOT free it here. Set our local variable LMappedAddress to nil to prevent accidental freeing later.
    OutputDebugStringFmt('MapAndResolve: OS Loader owns memory at %p now. Setting LMappedAddress to nil.', [LMappedAddress]);
    LMappedAddress := nil; // Release our reference.

    try // Wrap post-processing operations in a try block.
      // Apply optional post-load modifications based on APlFlags.

      // LOAD_FLAGS_NO_THDCALL: Disable thread notifications.
      if (APlFlags and LOAD_FLAGS_NO_THDCALL) <> 0 then
      begin
         OutputDebugStringFmt('MapAndResolve: Applying LOAD_FLAGS_NO_THDCALL.', []);
         if not DisableThreadCallbacks(Pointer(LLib)) then
           OutputDebugStringFmt('MapAndResolve Warning: DisableThreadCallbacks failed for module 0x%p.', [Pointer(LLib)]);
      end;

      // LOAD_FLAGS_OVRHDRS: Overwrite in-memory headers.
      // This should happen *before* LOAD_FLAGS_NO_HEADERS if both are specified.
      if ((APlFlags and LOAD_FLAGS_OVRHDRS) <> 0) and ((APlFlags and LOAD_FLAGS_NO_HEADERS) = 0) then // Only overwrite if not removing headers.
      begin
        OutputDebugStringFmt('MapAndResolve: Applying LOAD_FLAGS_OVRHDRS.', []);
        // Try to get the actual DLL path stored in the LDR entry first.
        LLdrEntryName := '';
        LCookie := LockLoader();
        if LCookie <> 0 then
        try
          LLdrEntry := GetLdrDataTableEntry(Pointer(LLib));
          if (LLdrEntry <> nil) and (LLdrEntry^.FullDllName.Buffer <> nil) then
          begin
            // Copy the name from the UNICODE_STRING buffer.
            LLdrEntryName := Copy(LLdrEntry^.FullDllName.Buffer, 1, LLdrEntry^.FullDllName.Length div SizeOf(WideChar));
             OutputDebugStringFmt('MapAndResolve: Found LDR entry FullDllName: "%s"', [LLdrEntryName]);
          end else
             OutputDebugStringFmt('MapAndResolve: Could not get FullDllName from LDR entry for OverwriteHeaders.', []);
        finally
          UnlockLoader(LCookie);
        end;

        // Attempt overwrite using LdrEntry name if found, otherwise fall back to the original dummy FileName.
        if (LLdrEntryName <> '') and OverwriteHeaders(Pointer(LLib), LLdrEntryName) then
        begin
          // Success using LDR name.
          OutputDebugStringFmt('MapAndResolve: OverwriteHeaders succeeded using LDR entry name.', []);
        end
        else if OverwriteHeaders(Pointer(LLib), LWideFileName) then // Use LWideFileName (original AFilename) as fallback.
        begin
          // Success using fallback dummy name.
          OutputDebugStringFmt('MapAndResolve: OverwriteHeaders succeeded using fallback dummy filename "%s".', [LWideFileName]);
        end else
          // Both attempts failed.
          OutputDebugStringFmt('MapAndResolve Warning: Failed to overwrite headers using both LdrEntry name ("%s") and fallback dummy filename ("%s").', [LLdrEntryName, LWideFileName]);
      end;

      // LOAD_FLAGS_NO_MODLIST: Unlink from PEB loader lists.
      if (APlFlags and LOAD_FLAGS_NO_MODLIST) <> 0 then
      begin
        OutputDebugStringFmt('MapAndResolve: Applying LOAD_FLAGS_NO_MODLIST.', []);
        if not UnlinkModule(Pointer(LLib)) then
         OutputDebugStringFmt('MapAndResolve Warning: Failed to unlink module 0x%p from LDR lists.', [Pointer(LLib)]);
      end;

      // LOAD_FLAGS_NO_HEADERS: Zero out PE headers in memory.
      // Do this *after* OverwriteHeaders if both were specified.
      if (APlFlags and LOAD_FLAGS_NO_HEADERS) <> 0 then
      begin
        OutputDebugStringFmt('MapAndResolve: Applying LOAD_FLAGS_NO_HEADERS.', []);
        if not RemoveHeaders(Pointer(LLib)) then
          OutputDebugStringFmt('MapAndResolve Warning: Failed to remove (zero) PE headers for module 0x%p.', [Pointer(LLib)]);
      end;

    except
      // Catch potential errors during post-processing. The library is loaded, but modifications might have failed.
      on E: Exception do
      begin
        OutputDebugStringFmt('MapAndResolve Exception during post-processing operations for module 0x%p: %s', [Pointer(LLib), E.Message]);
        // Continue, as the library handle LLib is still valid.
      end;
    end;
    OutputDebugStringFmt('MapAndResolve: Post-load operations finished for module 0x%p.', [Pointer(LLib)]);
  end
  else // LoadLibraryExW failed
  begin
    OutputDebugStringFmt('MapAndResolve: LoadLibraryExW failed (returned 0). Cleaning up manually mapped memory.', []);
    // Since the OS loader did not take ownership, we MUST free the memory we allocated with VirtualAlloc.
    if LMappedAddress <> nil then
    begin
      OutputDebugStringFmt('MapAndResolve: Releasing manually mapped memory at %p.', [LMappedAddress]);
      VirtualFree(LMappedAddress, 0, MEM_RELEASE);
      LMappedAddress := nil; // Clear pointer after freeing.
    end else
       OutputDebugStringFmt('MapAndResolve: Warning - LoadLibraryExW failed, but LMappedAddress was already nil?', []);

    // Restore the error code that LoadLibraryExW returned.
    SetLastError(LLastErrorValue);
    // Result is already 0.
  end;

  OutputDebugStringFmt('MapAndResolve: Process finished. Returning handle 0x%p.', [Pointer(Result)]);
end;

// --- Module Registry & LdrGetDllHandle Hook ---
// On Windows 11 24H2+, the internal loader lookup (LdrpFindLoadedDllByNameLockHeld)
// uses data structures beyond LdrpHashTable that cannot be patched post-hoc.
// This hook intercepts LdrGetDllHandle and falls back to our registry when the
// original function returns STATUS_DLL_NOT_FOUND for a memory-loaded module.

// Registers a memory-loaded module in our lookup registry.
procedure RegisterModule(const AName: string; const AHandle: THandle);
var
  I: Integer;
begin
  // Check for existing entry with the same name and update it.
  for I := 0 to GRegisteredModuleCount - 1 do
  begin
    if SameText(GRegisteredModuleNames[I], AName) then
    begin
      GRegisteredModuleHandles[I] := AHandle;
      Exit;
    end;
  end;
  // Add new entry if space available.
  if GRegisteredModuleCount < Length(GRegisteredModuleNames) then
  begin
    GRegisteredModuleNames[GRegisteredModuleCount] := AName;
    GRegisteredModuleHandles[GRegisteredModuleCount] := AHandle;
    Inc(GRegisteredModuleCount);
  end
  else
    OutputDebugStringFmt('RegisterModule: Registry full, cannot register "%s".', [AName]);
end;

// Looks up a UNICODE_STRING name in the module registry.
// Returns the handle if found, 0 otherwise.
function FindRegisteredModule(const ADllName: PUNICODE_STRING): THandle;
var
  I: Integer;
  LName: string;
  LLen: Integer;
begin
  Result := 0;
  if (ADllName = nil) or (ADllName^.Buffer = nil) or (ADllName^.Length = 0) then
    Exit;
  LLen := ADllName^.Length div SizeOf(WideChar);
  LName := WideCharLenToString(ADllName^.Buffer, LLen);
  for I := 0 to GRegisteredModuleCount - 1 do
  begin
    if SameText(GRegisteredModuleNames[I], LName) then
    begin
      Result := GRegisteredModuleHandles[I];
      Exit;
    end;
  end;
end;

// Hook handler for LdrGetDllHandle. Calls the original, and if it returns
// STATUS_DLL_NOT_FOUND, checks our module registry for memory-loaded DLLs.
function HookedLdrGetDllHandle(
  DllPath: PWideChar;
  DllCharacteristics: Pointer;
  DllName: PUNICODE_STRING;
  DllHandle: Pointer // PHandle
): NTSTATUS; stdcall;
var
  LFoundHandle: THandle;
begin
  // Call the original function first (requires unhook/rehook pattern).
  EnterCriticalSection(GRedirectCritSect);
  try
    if UninstallHook(GLdrGetDllHandleAddr, GOrigBytesLdrGetDllHandle) then
    try
      Result := GOrigLdrGetDllHandle(DllPath, DllCharacteristics, DllName, DllHandle);
    finally
      InstallHook(GLdrGetDllHandleAddr, @HookedLdrGetDllHandle, GOrigBytesLdrGetDllHandle);
    end
    else
    begin
      // Unhook failed — call original directly (may recurse if hook still active)
      Result := GOrigLdrGetDllHandle(DllPath, DllCharacteristics, DllName, DllHandle);
    end;
  finally
    LeaveCriticalSection(GRedirectCritSect);
  end;

  // If the original returned DLL_NOT_FOUND ($C0000135), check our registry.
  if Result = NTSTATUS($C0000135) then
  begin
    LFoundHandle := FindRegisteredModule(DllName);
    if LFoundHandle <> 0 then
    begin
      // Found in our registry — set the output handle and return success.
      PHandle(DllHandle)^ := LFoundHandle;
      Result := STATUS_SUCCESS;
    end;
  end;
end;

// Hook handler for LdrLoadDll. When the import resolver tries to load a DLL
// from disk that we've already loaded from memory, return the existing handle.
function HookedLdrLoadDll(
  DllPath: PWideChar;
  DllCharacteristics: Pointer;
  DllName: PUNICODE_STRING;
  DllHandle: Pointer
): NTSTATUS; stdcall;
var
  LFoundHandle: THandle;
  LNameStr: string;
begin
  // Trace all calls to see if we're being invoked during import resolution
  if (DllName <> nil) and (DllName^.Buffer <> nil) and (DllName^.Length > 0) then
    LNameStr := WideCharLenToString(DllName^.Buffer, DllName^.Length div SizeOf(WideChar))
  else
    LNameStr := '(null)';

  // Check our registry FIRST — if we have it, no need to call the original.
  LFoundHandle := FindRegisteredModule(DllName);
  if LFoundHandle <> 0 then
  begin
    PHandle(DllHandle)^ := LFoundHandle;
    Result := STATUS_SUCCESS;
    Exit;
  end;

  // Not one of ours — call the original LdrLoadDll.
  EnterCriticalSection(GRedirectCritSect);
  try
    if UninstallHook(GLdrLoadDllAddr, GOrigBytesLdrLoadDll) then
    try
      Result := GOrigLdrLoadDll(DllPath, DllCharacteristics, DllName, DllHandle);
    finally
      InstallHook(GLdrLoadDllAddr, @HookedLdrLoadDll, GOrigBytesLdrLoadDll);
    end
    else
      Result := GOrigLdrLoadDll(DllPath, DllCharacteristics, DllName, DllHandle);
  finally
    LeaveCriticalSection(GRedirectCritSect);
  end;
end;

// Installs the persistent LdrGetDllHandle hook if not already installed.
procedure EnsureLdrGetDllHandleHooked();
begin
  if GLdrHookInstalled then
    Exit;

  GLdrGetDllHandleAddr := GetProcAddress(GetModuleHandle('ntdll.dll'), 'LdrGetDllHandle');
  if GLdrGetDllHandleAddr = nil then
  begin
    OutputDebugStringFmt('EnsureLdrGetDllHandleHooked: Could not find LdrGetDllHandle in ntdll.', []);
    Exit;
  end;

  GOrigLdrGetDllHandle := TLdrGetDllHandle(GLdrGetDllHandleAddr);

  EnterCriticalSection(GRedirectCritSect);
  try
    GLdrHookInstalled := InstallHook(GLdrGetDllHandleAddr, @HookedLdrGetDllHandle, GOrigBytesLdrGetDllHandle);
  finally
    LeaveCriticalSection(GRedirectCritSect);
  end;

  if GLdrHookInstalled then
  else

  // Also hook LdrLoadDll — the import resolver calls this directly when it
  // can't find a module, bypassing LdrGetDllHandle entirely.
  if not GLdrLoadDllHookInstalled then
  begin
    GLdrLoadDllAddr := GetProcAddress(GetModuleHandle('ntdll.dll'), 'LdrLoadDll');
    if GLdrLoadDllAddr <> nil then
    begin
      GOrigLdrLoadDll := TLdrGetDllHandle(GLdrLoadDllAddr);
      EnterCriticalSection(GRedirectCritSect);
      try
        GLdrLoadDllHookInstalled := InstallHook(GLdrLoadDllAddr, @HookedLdrLoadDll, GOrigBytesLdrLoadDll);
      finally
        LeaveCriticalSection(GRedirectCritSect);
      end;
      if GLdrLoadDllHookInstalled then
      else
    end;
  end;
end;

// --- Module Name Patching ---

// Computes the LDR hash bucket index for a module name.
// Calls ntdll's RtlHashUnicodeString to match the exact algorithm used by the
// Windows loader, then masks to 32 buckets (AND $1F).
function LdrHashModuleName(const AName: string): ULONG;
type
  TRtlHashUnicodeString = function(
    const AString: PUNICODE_STRING;
    ACaseInSensitive: BOOLEAN;
    AHashAlgorithm: ULONG;
    AHashValue: PULONG
  ): NTSTATUS; stdcall;
var
  LNtdll: HMODULE;
  LFunc: TRtlHashUnicodeString;
  LUniStr: UNICODE_STRING;
  LWideName: UnicodeString;
  LHashValue: ULONG;
begin
  Result := 0;
  LWideName := AName;

  LNtdll := GetModuleHandle('ntdll.dll');
  if LNtdll = 0 then Exit;

  @LFunc := GetProcAddress(LNtdll, 'RtlHashUnicodeString');
  if @LFunc = nil then Exit;

  LUniStr.Length := Length(LWideName) * SizeOf(WideChar);
  LUniStr.MaximumLength := LUniStr.Length + SizeOf(WideChar);
  LUniStr.Buffer := PWideChar(LWideName);

  // HashAlgorithm 0 = HASH_STRING_ALGORITHM_DEFAULT (x65599)
  // CaseInSensitive = True
  if LFunc(@LUniStr, True, 0, @LHashValue) = 0 then
    Result := LHashValue and (LDRP_HASH_TABLE_SIZE - 1);
end;

// Returns a pointer to the HashLinks LIST_ENTRY within an LDR_DATA_TABLE_ENTRY.
// Now directly references the correctly declared HashLinks field.
function GetHashLinksPtr(const ALdrEntry: PLDR_DATA_TABLE_ENTRY): PLIST_ENTRY;
begin
  Result := @ALdrEntry^.HashLinks;
end;

// Locates the base address of ntdll's LdrpHashTable static array by walking
// ntdll's HashLinks chain to find the bucket head (which resides in ntdll's
// .data section). Must be called while holding the loader lock.
function FindLdrpHashTable(): Pointer;
var
  LNtdllHandle: HMODULE;
  LNtdllEntry: PLDR_DATA_TABLE_ENTRY;
  LNtdllBase: NativeUInt;
  LNtdllEnd: NativeUInt;
  LHash: ULONG;
  LHashLinks: PLIST_ENTRY;
  LCurrent: PLIST_ENTRY;
begin
  // Return cached value if available.
  Result := GLdrpHashTable;
  if Result <> nil then Exit;

  LNtdllHandle := GetModuleHandle('ntdll.dll');
  if LNtdllHandle = 0 then
  begin
    OutputDebugStringFmt('FindLdrpHashTable: GetModuleHandle for ntdll.dll failed.', []);
    Exit;
  end;

  LNtdllEntry := GetLdrDataTableEntry(Pointer(LNtdllHandle));
  if LNtdllEntry = nil then
  begin
    OutputDebugStringFmt('FindLdrpHashTable: Could not find LDR entry for ntdll.dll.', []);
    Exit;
  end;

  LNtdllBase := NativeUInt(LNtdllEntry^.DllBase);
  LNtdllEnd := LNtdllBase + LNtdllEntry^.SizeOfImage;

  // Hash "ntdll.dll" to determine which bucket it belongs to.
  LHash := LdrHashModuleName('ntdll.dll');

  // Get ntdll's HashLinks pointer.
  LHashLinks := GetHashLinksPtr(LNtdllEntry);

  // Walk backward through the hash chain. The bucket head is a static
  // LIST_ENTRY inside ntdll's address range, while module LDR entries
  // are heap-allocated and outside that range.
  LCurrent := PLIST_ENTRY(LHashLinks^.Blink);
  while LCurrent <> LHashLinks do
  begin
    if (NativeUInt(LCurrent) >= LNtdllBase) and
       (NativeUInt(LCurrent) < LNtdllEnd) then
    begin
      // Found the bucket head for index LHash. Compute the array base.
      Result := Pointer(NativeUInt(LCurrent) - LHash * SizeOf(LIST_ENTRY));
      GLdrpHashTable := Result;
      OutputDebugStringFmt('FindLdrpHashTable: Located at %p (bucket %d head at %p).',
        [Result, LHash, LCurrent]);
      Exit;
    end;
    LCurrent := PLIST_ENTRY(LCurrent^.Blink);
  end;

  OutputDebugStringFmt('FindLdrpHashTable: Could not locate LdrpHashTable base.', []);
end;

// Patches the BaseDllName and FullDllName in the module's LDR_DATA_TABLE_ENTRY
// OS loader can resolve imports by the given module name. The name buffer is
// allocated on the process heap and persists for the lifetime of the process.
function PatchModuleName(const AModuleHandle: HMODULE;
  const AModuleName: string): Boolean;
var
  LCookie: NativeUInt;
  LLdrEntry: PLDR_DATA_TABLE_ENTRY;
  LWideName: WideString;
  LBufferSize: Word;
  LBuffer: PWideChar;
  LFullBuffer: PWideChar;
  LHeap: THandle;
  LHashTable: Pointer;
  LHashLinksPtr: PLIST_ENTRY;
  LNewHash: ULONG;
  LNewBucket: PLIST_ENTRY;
begin
  Result := False;

  if (AModuleHandle = 0) or (AModuleName = '') then
  begin
    OutputDebugStringFmt('PatchModuleName Error: Invalid handle or empty module name.', []);
    Exit;
  end;

  LWideName := AModuleName;
  LBufferSize := Length(LWideName) * SizeOf(WideChar);

  // Allocate persistent memory from the process heap for the name buffer.
  // This must outlive the function — the LDR entry will point to it permanently.
  LHeap := GetProcessHeap();
  LBuffer := HeapAlloc(LHeap, 0, LBufferSize + SizeOf(WideChar));
  if LBuffer = nil then
  begin
    OutputDebugStringFmt('PatchModuleName Error: HeapAlloc failed for %d bytes. Error: %d',
      [LBufferSize + SizeOf(WideChar), GetLastError()]);
    Exit;
  end;

  // Copy the wide string into the heap buffer, including null terminator.
  Move(PWideChar(LWideName)^, LBuffer^, LBufferSize + SizeOf(WideChar));

  LCookie := LockLoader();
  if LCookie = 0 then
  begin
    OutputDebugStringFmt('PatchModuleName Error: Failed to acquire loader lock.', []);
    HeapFree(LHeap, 0, LBuffer);
    Exit;
  end;
  try
    LLdrEntry := GetLdrDataTableEntry(Pointer(AModuleHandle));
    if LLdrEntry = nil then
    begin
      OutputDebugStringFmt('PatchModuleName Error: Could not find LDR entry for module 0x%p.',
        [Pointer(AModuleHandle)]);
      HeapFree(LHeap, 0, LBuffer);
      Exit;
    end;

    // Patch BaseDllName — this is what the loader searches by when resolving imports.
    LLdrEntry^.BaseDllName.Buffer := LBuffer;
    LLdrEntry^.BaseDllName.Length := LBufferSize;
    LLdrEntry^.BaseDllName.MaximumLength := LBufferSize + SizeOf(WideChar);

    // Patch FullDllName — this is what LoadLibraryExW checks to detect
    // already-loaded modules. Without patching this, subsequent loads using
    // the same dummy file path will collide and return the existing handle
    // instead of triggering the NtMapViewOfSection hook.
    LFullBuffer := HeapAlloc(LHeap, 0, LBufferSize + SizeOf(WideChar));
    if LFullBuffer <> nil then
    begin
      Move(PWideChar(LWideName)^, LFullBuffer^, LBufferSize + SizeOf(WideChar));
      LLdrEntry^.FullDllName.Buffer := LFullBuffer;
      LLdrEntry^.FullDllName.Length := LBufferSize;
      LLdrEntry^.FullDllName.MaximumLength := LBufferSize + SizeOf(WideChar);
      OutputDebugStringFmt('PatchModuleName: Patched FullDllName to "%s" for module 0x%p.',
        [AModuleName, Pointer(AModuleHandle)]);
    end
    else
      OutputDebugStringFmt('PatchModuleName Warning: HeapAlloc failed for FullDllName buffer.', []);

    OutputDebugStringFmt('PatchModuleName: Patched BaseDllName to "%s" for module 0x%p.',
      [AModuleName, Pointer(AModuleHandle)]);

    // Re-link the HashLinks entry from the old hash bucket to the new one.
    // The loader uses a 32-bucket hash table (LdrpHashTable) keyed on
    // BaseDllName to quickly find loaded modules. After patching the name,
    // the entry is still in the old bucket, so lookups for the new name
    // would miss it. We must move it to the correct bucket.
    LHashTable := FindLdrpHashTable();
    if LHashTable <> nil then
    begin
      LHashLinksPtr := GetHashLinksPtr(LLdrEntry);

      // Unlink from old bucket.
      if (LHashLinksPtr^.Flink <> nil) and (LHashLinksPtr^.Blink <> nil) then
      begin
        PLIST_ENTRY(LHashLinksPtr^.Blink)^.Flink := LHashLinksPtr^.Flink;
        PLIST_ENTRY(LHashLinksPtr^.Flink)^.Blink := LHashLinksPtr^.Blink;
      end;

      // Compute new hash and get the target bucket head.
      LNewHash := LdrHashModuleName(AModuleName);
      LNewBucket := PLIST_ENTRY(NativeUInt(LHashTable) + LNewHash * SizeOf(LIST_ENTRY));

      // Guard against nil Flink before insert.
      if (LNewBucket^.Flink = nil) or (LNewBucket^.Blink = nil) then
      begin
        OutputDebugStringFmt('PatchModuleName: ERROR bucket %d has nil links. HashTable may be wrong.', [LNewHash]);
      end
      else
      begin
        // Insert at the front of the new bucket (after the head).
        LHashLinksPtr^.Flink := LNewBucket^.Flink;
        LHashLinksPtr^.Blink := Pointer(LNewBucket);
        PLIST_ENTRY(LNewBucket^.Flink)^.Blink := Pointer(LHashLinksPtr);
        LNewBucket^.Flink := Pointer(LHashLinksPtr);
      end;

      OutputDebugStringFmt('PatchModuleName: Re-linked HashLinks from old bucket to bucket %d for "%s".',
        [LNewHash, AModuleName]);
    end
    else
      OutputDebugStringFmt('PatchModuleName Warning: Could not locate LdrpHashTable. Hash re-linking skipped.', []);

    // Register this module in our lookup registry and ensure the
    // LdrGetDllHandle hook is active so the loader can find it by name.
    RegisterModule(AModuleName, AModuleHandle);
    EnsureLdrGetDllHandleHooked();

    Result := True;
  finally
    UnlockLoader(LCookie);
  end;
end;

// --- Public Function Implementation ---

// The main public function exposed by the unit. Loads a DLL from memory.
function LoadLibrary(const AData: Pointer; const ASize: NativeUInt): THandle;
var
  LPath: string; // Stores the path to the dummy DLL.
  LGuid: TGUID;
  LUniqueName: string;

  // Helper function to get the full path of an existing system DLL.
  // Used to find a suitable dummy file for the MapAndResolve AFilename parameter.
  function GetFullPathToDll(const DllName: string): string;
  var
    Handle: HMODULE;
    Buffer: array[0..MAX_PATH - 1] of Char; // TCHAR buffer for path.
    LCharsCopied: DWORD;
  begin
    Result := ''; // Default to empty string.
    // Temporarily load the library just to get its path.
    // Use standard LoadLibrary for this helper.
    Handle := Winapi.Windows.LoadLibrary(PChar(DllName)); // Use PChar for WinAPI.
    if Handle <> 0 then
    try
      // Get the full path of the loaded module.
      LCharsCopied := GetModuleFileName(Handle, Buffer, MAX_PATH);
      if LCharsCopied > 0 then
      begin
        // Ensure null termination just in case (though GetModuleFileName should handle it).
        Buffer[LCharsCopied] := #0;
        Result := Buffer; // Assign the buffer content to the result string.
      end
      else
        OutputDebugStringFmt('GetFullPathToDll: GetModuleFileName failed for "%s". Error: %d', [DllName, GetLastError]);
    finally
      // Unload the temporarily loaded library.
      FreeLibrary(Handle);
    end
    else
      OutputDebugStringFmt('GetFullPathToDll: LoadLibrary failed for "%s". Error: %d', [DllName, GetLastError]);
  end;

begin
  // 1. Find a suitable dummy file path.
  // 'advapi32res.dll' is chosen as it's a common system DLL likely to exist and be accessible.
  // Any existing, accessible file path would work.
  LPath := GetFullPathToDll('advapi32res.dll'); // Tries to find path like C:\Windows\System32\advapi32res.dll
  if LPath = '' then
  begin
    OutputDebugStringFmt('Dlluminator.LoadLibrary Error: Could not find path to dummy DLL "advapi32res.dll". Cannot proceed.', []);
    SetLastError(ERROR_FILE_NOT_FOUND); // Indicate failure to find necessary file.
    Result := 0;
    Exit;
  end;
  OutputDebugStringFmt('Dlluminator.LoadLibrary: Using dummy path "%s".', [LPath]);

  // 2. Call the core MapAndResolve function.
  // Pass the user's DLL data (AData, ASize), standard flags (0), the dummy path, and default PlFlags (0).
  Result := MapAndResolve(AData, ASize, 0, PWideChar(LPath), LOAD_FLAGS_NONE);

  // 3. Patch the LDR entry names to free the dummy path for reuse.
  // Without this, subsequent loads will find the dummy path already in the
  // LDR list and return the existing handle instead of loading a new module.
  if Result <> 0 then
  begin
    CreateGUID(LGuid);
    LUniqueName := GUIDToString(LGuid) + '.dll';
    PatchModuleName(Result, LUniqueName);
  end;
end;

// Manually resolves all imports for a loaded module.
// Walks the PE import directory and fixes up the IAT entries.
// Uses our module registry for memory-loaded DLLs, and the standard
// Windows API for system DLLs.
function ManualResolveImports(const AModuleBase: Pointer): Boolean;
type
  TDllEntryPoint = function(AInstance: HINST; AReason: DWORD; AReserved: Pointer): BOOL; stdcall;
var
  LDosHeader: PImageDosHeader;
  LNtHeaders: PImageNtHeaders64;
  LImportDir: PImageDataDirectory;
  LImportDesc: PImageImportDescriptor;
  LDllName: PAnsiChar;
  LDllNameStr: string;
  LDllHandle: HMODULE;
  LThunkRef: PNativeUInt;  // INT (Original First Thunk)
  LFuncRef: PNativeUInt;   // IAT (First Thunk)
  LOrdinal: Word;
  LHintName: PImageImportByName;
  LFuncAddr: Pointer;
  LBase: NativeUInt;
  LRegistryIdx: Integer;
  LOldProtect: DWORD;
begin
  Result := False;
  LBase := NativeUInt(AModuleBase);

  // Parse PE headers
  LDosHeader := PImageDosHeader(LBase);
  if LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then Exit;

  LNtHeaders := PImageNtHeaders64(LBase + NativeUInt(LDosHeader^._lfanew));
  if LNtHeaders^.Signature <> IMAGE_NT_SIGNATURE then Exit;

  // Get import directory
  LImportDir := @LNtHeaders^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (LImportDir^.VirtualAddress = 0) or (LImportDir^.Size = 0) then
  begin
    Result := True; // No imports — nothing to resolve
    Exit;
  end;

  LImportDesc := PImageImportDescriptor(LBase + LImportDir^.VirtualAddress);

  // Walk each import descriptor
  while LImportDesc^.Name <> 0 do
  begin
    LDllName := PAnsiChar(LBase + LImportDesc^.Name);
    LDllNameStr := string(AnsiString(LDllName));

    // Resolve the imported DLL handle
    LDllHandle := 0;

    // Check our registry first (memory-loaded modules)
    for LRegistryIdx := 0 to GRegisteredModuleCount - 1 do
    begin
      if SameText(GRegisteredModuleNames[LRegistryIdx], LDllNameStr) then
      begin
        LDllHandle := GRegisteredModuleHandles[LRegistryIdx];
        Break;
      end;
    end;

    // Fall back to Windows API for system DLLs
    if LDllHandle = 0 then
    begin
      LDllHandle := GetModuleHandle(PChar(LDllNameStr));
      if LDllHandle = 0 then
        LDllHandle := Winapi.Windows.LoadLibrary(PChar(LDllNameStr));
      if LDllHandle = 0 then
      begin
        Exit;
      end;
    end;

    // Resolve each function in this import's IAT
    // Use OriginalFirstThunk (INT) for names, FirstThunk (IAT) for writing addresses
    if LImportDesc^.OriginalFirstThunk <> 0 then
      LThunkRef := PNativeUInt(LBase + LImportDesc^.OriginalFirstThunk)
    else
      LThunkRef := PNativeUInt(LBase + LImportDesc^.FirstThunk);
    LFuncRef := PNativeUInt(LBase + LImportDesc^.FirstThunk);

    while LThunkRef^ <> 0 do
    begin
      // Check if import is by ordinal (high bit set on x64)
      if (LThunkRef^ and IMAGE_ORDINAL_FLAG64) <> 0 then
      begin
        LOrdinal := Word(LThunkRef^ and $FFFF);
        LFuncAddr := GetProcAddress(LDllHandle, PChar(LOrdinal));
      end
      else
      begin
        // Import by name
        LHintName := PImageImportByName(LBase + LThunkRef^);
        LFuncAddr := GetProcAddress(LDllHandle, PAnsiChar(@LHintName^.Name));
      end;

      if LFuncAddr = nil then
      begin
        Exit;
      end;

      // Write the resolved address to the IAT
      VirtualProtect(LFuncRef, SizeOf(NativeUInt), PAGE_READWRITE, @LOldProtect);
      LFuncRef^ := NativeUInt(LFuncAddr);

      Inc(LThunkRef);
      Inc(LFuncRef);
    end;

    // Move to next import descriptor
    LImportDesc := PImageImportDescriptor(NativeUInt(LImportDesc) + SizeOf(TImageImportDescriptor));
  end;

  Result := True;
end;

// Calls a module's entry point (DllMain) with DLL_PROCESS_ATTACH.
function CallModuleEntryPoint(const AModuleBase: Pointer): Boolean;
type
  TDllEntryPoint = function(AInstance: HINST; AReason: DWORD; AReserved: Pointer): BOOL; stdcall;
var
  LDosHeader: PImageDosHeader;
  LNtHeaders: PImageNtHeaders64;
  LEntryRVA: DWORD;
  LEntryPoint: TDllEntryPoint;
begin
  Result := False;

  LDosHeader := PImageDosHeader(AModuleBase);
  if LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then Exit;

  LNtHeaders := PImageNtHeaders64(NativeUInt(AModuleBase) + NativeUInt(LDosHeader^._lfanew));
  if LNtHeaders^.Signature <> IMAGE_NT_SIGNATURE then Exit;

  LEntryRVA := LNtHeaders^.OptionalHeader.AddressOfEntryPoint;
  if LEntryRVA = 0 then
  begin
    Result := True; // No entry point — that's OK
    Exit;
  end;

  LEntryPoint := TDllEntryPoint(NativeUInt(AModuleBase) + LEntryRVA);

  Result := LEntryPoint(HINST(AModuleBase), DLL_PROCESS_ATTACH, nil);
end;

// Checks if a PE image imports from any of our registered modules.
function HasRegisteredDependencies(const AData: Pointer; const ASize: NativeUInt): Boolean;
var
  LDosHeader: PImageDosHeader;
  LNtHeaders: PImageNtHeaders64;
  LImportDir: PImageDataDirectory;
  LImportDesc: PImageImportDescriptor;
  LDllName: PAnsiChar;
  LDllNameStr: string;
  LBase: NativeUInt;
  I: Integer;
begin
  Result := False;
  LBase := NativeUInt(AData);

  LDosHeader := PImageDosHeader(LBase);
  if LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then Exit;

  LNtHeaders := PImageNtHeaders64(LBase + NativeUInt(LDosHeader^._lfanew));
  if LNtHeaders^.Signature <> IMAGE_NT_SIGNATURE then Exit;

  LImportDir := @LNtHeaders^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (LImportDir^.VirtualAddress = 0) or (LImportDir^.Size = 0) then Exit;

  LImportDesc := PImageImportDescriptor(LBase + LImportDir^.VirtualAddress);
  while LImportDesc^.Name <> 0 do
  begin
    LDllName := PAnsiChar(LBase + LImportDesc^.Name);
    LDllNameStr := string(AnsiString(LDllName));
    for I := 0 to GRegisteredModuleCount - 1 do
    begin
      if SameText(GRegisteredModuleNames[I], LDllNameStr) then
      begin
        Result := True;
        Exit;
      end;
    end;
    LImportDesc := PImageImportDescriptor(NativeUInt(LImportDesc) + SizeOf(TImageImportDescriptor));
  end;
end;

// Overloaded version that registers the module under a specified name,
// enabling dependency resolution between memory-loaded DLLs.
// Dependencies must be loaded before dependents. For example, load SDL3.dll
// first, then SDL3_image.dll which imports from SDL3.dll.
function LoadLibrary(const AData: Pointer; const ASize: NativeUInt;
  const AModuleName: string): THandle;
var
  LHasRegDeps: Boolean;
  LPath: string;
  LGuid: TGUID;
  LUniqueName: string;

  function GetFullPathToDll(const ADllName: string): string;
  var
    LHandle: HMODULE;
    LBuffer: array[0..MAX_PATH - 1] of Char;
    LCharsCopied: DWORD;
  begin
    Result := '';
    LHandle := Winapi.Windows.LoadLibrary(PChar(ADllName));
    if LHandle <> 0 then
    try
      LCharsCopied := GetModuleFileName(LHandle, LBuffer, MAX_PATH);
      if LCharsCopied > 0 then
        Result := LBuffer;
    finally
      FreeLibrary(LHandle);
    end;
  end;

begin
  Result := 0;

  // If we have any registered modules, use manual import resolution.
  // This is required because Windows 11 24H2+ can't find our memory-loaded
  // modules via its internal name lookup during import resolution.
  LHasRegDeps := GRegisteredModuleCount > 0;

  if LHasRegDeps then
  begin

    // Get dummy path for MapAndResolve
    LPath := GetFullPathToDll('advapi32res.dll');
    if LPath = '' then
    begin
      SetLastError(ERROR_FILE_NOT_FOUND);
      Exit;
    end;

    // Load with DONT_RESOLVE_DLL_REFERENCES — the loader will map and relocate
    // the DLL but will NOT resolve imports or call DllMain.
    Result := MapAndResolve(AData, ASize, DONT_RESOLVE_DLL_REFERENCES, PWideChar(LPath), LOAD_FLAGS_NONE);
    if Result = 0 then
    begin
      Exit;
    end;

    // Patch names and register
    CreateGUID(LGuid);
    LUniqueName := GUIDToString(LGuid) + '.dll';
    PatchModuleName(Result, LUniqueName);

    if AModuleName <> '' then
    begin
      RegisterModule(AModuleName, Result);
      PatchModuleName(Result, AModuleName);
    end;

    // Manually resolve all imports using our registry + Windows API
    if not ManualResolveImports(Pointer(Result)) then
    begin
      FreeLibrary(Result);
      Result := 0;
      Exit;
    end;

    // Call the entry point (DllMain with DLL_PROCESS_ATTACH)
    if not CallModuleEntryPoint(Pointer(Result)) then
    begin
      FreeLibrary(Result);
      Result := 0;
      Exit;
    end;

  end
  else
  begin
    // No registered dependencies — load normally via the base LoadLibrary.
    // The Windows loader handles import resolution natively.
    if AModuleName <> '' then
      EnsureLdrGetDllHandleHooked();

    Result := LoadLibrary(AData, ASize);

    if (Result <> 0) and (AModuleName <> '') then
    begin
      RegisterModule(AModuleName, Result);
      if not PatchModuleName(Result, AModuleName) then
        OutputDebugStringFmt('Dlluminator.LoadLibrary: Warning - Failed to patch name to "%s".', [AModuleName]);
    end;
  end;
end;

// --- Data Registry & Auto-Dependency Resolution ---

const
  ERROR_CIRCULAR_DEPENDENCY = 1059; // Standard Windows error code.

// Registers raw DLL data for deferred loading. The caller owns the memory.
procedure RegisterDllData(const AModuleName: string; const AData: Pointer;
  const ASize: NativeUInt);
var
  I: Integer;
begin
  // Update existing entry if name already registered.
  for I := 0 to GDataRegistryCount - 1 do
  begin
    if SameText(GDataRegistryNames[I], AModuleName) then
    begin
      GDataRegistryPtrs[I] := AData;
      GDataRegistrySizes[I] := ASize;
      GDataRegistryResNames[I] := '';
      Exit;
    end;
  end;
  // Add new entry.
  if GDataRegistryCount < Length(GDataRegistryNames) then
  begin
    GDataRegistryNames[GDataRegistryCount] := AModuleName;
    GDataRegistryPtrs[GDataRegistryCount] := AData;
    GDataRegistrySizes[GDataRegistryCount] := ASize;
    GDataRegistryResNames[GDataRegistryCount] := '';
    Inc(GDataRegistryCount);
  end
  else
    OutputDebugStringFmt('RegisterDllData: Data registry full, cannot register "%s".', [AModuleName]);
end;

// Registers a DLL by resource name for deferred loading. The resource is
// loaded on demand when LoadLibrary(AModuleName) or LoadAll is called.
procedure RegisterDllData(const AModuleName: string;
  const AResName: string);
var
  I: Integer;
begin
  // Validate the resource exists upfront.
  if FindResource(HInstance, PChar(AResName), RT_RCDATA) = 0 then
  begin
    OutputDebugStringFmt('RegisterDllData: Resource "%s" not found.', [AResName]);
    Exit;
  end;

  // Update existing entry if name already registered.
  for I := 0 to GDataRegistryCount - 1 do
  begin
    if SameText(GDataRegistryNames[I], AModuleName) then
    begin
      GDataRegistryResNames[I] := AResName;
      GDataRegistryPtrs[I] := nil;
      GDataRegistrySizes[I] := 0;
      Exit;
    end;
  end;

  // Add new entry.
  if GDataRegistryCount < Length(GDataRegistryNames) then
  begin
    GDataRegistryNames[GDataRegistryCount] := AModuleName;
    GDataRegistryResNames[GDataRegistryCount] := AResName;
    GDataRegistryPtrs[GDataRegistryCount] := nil;
    GDataRegistrySizes[GDataRegistryCount] := 0;
    Inc(GDataRegistryCount);
  end
  else
    OutputDebugStringFmt('RegisterDllData: Data registry full, cannot register "%s".', [AModuleName]);
end;

// Converts an RVA to a file offset by walking section headers in raw PE data.
function RvaToFileOffset(const AData: Pointer; const ARva: DWORD): DWORD;
var
  LDosHeader: PImageDosHeader;
  LNtHeaders: PImageNtHeaders64;
  LSectionHeaders: PImageSectionHeader;
  LSectionCount: Word;
  I: Integer;
  LSectVA: DWORD;
  LSectSize: DWORD;
begin
  Result := 0;
  LDosHeader := PImageDosHeader(AData);
  LNtHeaders := PImageNtHeaders64(PByte(AData) + LDosHeader^._lfanew);
  LSectionCount := LNtHeaders^.FileHeader.NumberOfSections;

  {$POINTERMATH ON}
  LSectionHeaders := PImageSectionHeader(
    PByte(LNtHeaders)
    + SizeOf(DWORD)
    + SizeOf(TImageFileHeader)
    + LNtHeaders^.FileHeader.SizeOfOptionalHeader
  );
  {$POINTERMATH OFF}

  for I := 0 to LSectionCount - 1 do
  begin
    LSectVA := LSectionHeaders^.VirtualAddress;
    LSectSize := LSectionHeaders^.SizeOfRawData;
    if (ARva >= LSectVA) and (ARva < LSectVA + LSectSize) then
    begin
      Result := LSectionHeaders^.PointerToRawData + (ARva - LSectVA);
      Exit;
    end;
    {$POINTERMATH ON}
    Inc(PByte(LSectionHeaders), SizeOf(TImageSectionHeader));
    {$POINTERMATH OFF}
  end;
end;

// Parses import DLL names from raw (unmapped) PE data using file offsets.
procedure ParseImportsFromRawPE(const AData: Pointer; const ASize: NativeUInt;
  out AImports: TArray<string>);
var
  LDosHeader: PImageDosHeader;
  LNtHeaders: PImageNtHeaders64;
  LImportDir: PImageDataDirectory;
  LImportDirFileOfs: DWORD;
  LImportDesc: PImageImportDescriptor;
  LNameFileOfs: DWORD;
  LDllName: PAnsiChar;
  LCount: Integer;
begin
  SetLength(AImports, 0);
  LCount := 0;

  LDosHeader := PImageDosHeader(AData);
  if LDosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then Exit;

  LNtHeaders := PImageNtHeaders64(PByte(AData) + LDosHeader^._lfanew);
  if LNtHeaders^.Signature <> IMAGE_NT_SIGNATURE then Exit;

  LImportDir := @LNtHeaders^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (LImportDir^.VirtualAddress = 0) or (LImportDir^.Size = 0) then
    Exit; // No imports

  // Convert the import directory RVA to a file offset
  LImportDirFileOfs := RvaToFileOffset(AData, LImportDir^.VirtualAddress);
  if LImportDirFileOfs = 0 then Exit;

  LImportDesc := PImageImportDescriptor(PByte(AData) + LImportDirFileOfs);

  while LImportDesc^.Name <> 0 do
  begin
    LNameFileOfs := RvaToFileOffset(AData, LImportDesc^.Name);
    if LNameFileOfs = 0 then
    begin
      // Skip this descriptor if we can't resolve the name offset
      LImportDesc := PImageImportDescriptor(NativeUInt(LImportDesc) + SizeOf(TImageImportDescriptor));
      Continue;
    end;

    LDllName := PAnsiChar(PByte(AData) + LNameFileOfs);

    // Grow the array and add the name
    Inc(LCount);
    SetLength(AImports, LCount);
    AImports[LCount - 1] := string(AnsiString(LDllName));

    LImportDesc := PImageImportDescriptor(NativeUInt(LImportDesc) + SizeOf(TImageImportDescriptor));
  end;
end;

// Loads a DLL by name from the data registry, automatically resolving
// dependencies depth-first. Resource-based entries create a TResourceStream
// on demand, use it for loading, then free it immediately.
function LoadLibrary(const AModuleName: string): THandle;
var
  I: Integer;
  LDataIdx: Integer;
  LImports: TArray<string>;
  J: Integer;
  LDepName: string;
  LFoundInData: Boolean;
  LAlreadyLoaded: Boolean;
  LLoadingIdx: Integer;
  LResStream: TResourceStream;
begin
  Result := 0;

  // 1. Already loaded in the module registry? Return existing handle.
  for I := 0 to GRegisteredModuleCount - 1 do
  begin
    if SameText(GRegisteredModuleNames[I], AModuleName) then
    begin
      Result := GRegisteredModuleHandles[I];
      Exit;
    end;
  end;

  // 2. Find in the data registry.
  LDataIdx := -1;
  for I := 0 to GDataRegistryCount - 1 do
  begin
    if SameText(GDataRegistryNames[I], AModuleName) then
    begin
      LDataIdx := I;
      Break;
    end;
  end;

  if LDataIdx < 0 then
  begin
    OutputDebugStringFmt('LoadLibrary(name): "%s" not found in data registry.', [AModuleName]);
    SetLastError(ERROR_FILE_NOT_FOUND);
    Exit;
  end;

  // 3. Circular dependency check.
  for I := 0 to GLoadingInProgressCount - 1 do
  begin
    if SameText(GLoadingInProgress[I], AModuleName) then
    begin
      OutputDebugStringFmt('LoadLibrary(name): Circular dependency detected for "%s".', [AModuleName]);
      SetLastError(ERROR_CIRCULAR_DEPENDENCY);
      Exit;
    end;
  end;

  // 4. Mark as loading in progress.
  if GLoadingInProgressCount < Length(GLoadingInProgress) then
  begin
    GLoadingInProgress[GLoadingInProgressCount] := AModuleName;
    Inc(GLoadingInProgressCount);
    LLoadingIdx := GLoadingInProgressCount - 1;
  end
  else
  begin
    OutputDebugStringFmt('LoadLibrary(name): Loading stack full for "%s".', [AModuleName]);
    Exit;
  end;

  try
    // 5. Parse imports to discover dependencies.
    //    For resource-based entries, we need to create a stream temporarily
    //    just to parse the import table, then free it.
    if GDataRegistryResNames[LDataIdx] <> '' then
    begin
      LResStream := TResourceStream.Create(HInstance,
        GDataRegistryResNames[LDataIdx], RT_RCDATA);
      try
        ParseImportsFromRawPE(LResStream.Memory, LResStream.Size, LImports);
      finally
        LResStream.Free();
      end;
    end
    else
      ParseImportsFromRawPE(GDataRegistryPtrs[LDataIdx],
        GDataRegistrySizes[LDataIdx], LImports);

    // 6. Recursively load each dependency that is in our data registry
    //    and not yet loaded.
    for J := 0 to Length(LImports) - 1 do
    begin
      LDepName := LImports[J];

      // Check if already loaded in module registry.
      LAlreadyLoaded := False;
      for I := 0 to GRegisteredModuleCount - 1 do
      begin
        if SameText(GRegisteredModuleNames[I], LDepName) then
        begin
          LAlreadyLoaded := True;
          Break;
        end;
      end;
      if LAlreadyLoaded then
        Continue;

      // Check if it's in the data registry (one of ours).
      LFoundInData := False;
      for I := 0 to GDataRegistryCount - 1 do
      begin
        if SameText(GDataRegistryNames[I], LDepName) then
        begin
          LFoundInData := True;
          Break;
        end;
      end;

      if LFoundInData then
      begin
        // Recursive call to load the dependency first.
        if LoadLibrary(LDepName) = 0 then
        begin
          OutputDebugStringFmt('LoadLibrary(name): Failed to load dependency "%s" for "%s".',
            [LDepName, AModuleName]);
          Exit; // Bail out — dependency failed
        end;
      end;
      // If not in data registry, it's a system DLL — ManualResolveImports
      // handles it later via GetModuleHandle/Windows.LoadLibrary.
    end;

    // 7. All dependencies loaded. Load this DLL.
    //    Create resource stream on demand if needed.
    if GDataRegistryResNames[LDataIdx] <> '' then
    begin
      LResStream := TResourceStream.Create(HInstance,
        GDataRegistryResNames[LDataIdx], RT_RCDATA);
      try
        Result := LoadLibrary(LResStream.Memory, LResStream.Size, AModuleName);
      finally
        LResStream.Free();
      end;
    end
    else
      Result := LoadLibrary(GDataRegistryPtrs[LDataIdx],
        GDataRegistrySizes[LDataIdx], AModuleName);

    if Result = 0 then
      OutputDebugStringFmt('LoadLibrary(name): Failed to load "%s" from data registry.',
        [AModuleName]);

  finally
    // 8. Remove from loading-in-progress stack.
    if (GLoadingInProgressCount > 0) and
       (LLoadingIdx = GLoadingInProgressCount - 1) then
      Dec(GLoadingInProgressCount);
  end;
end;

// Loads all registered DLLs in dependency order. The recursive
// LoadLibrary(AModuleName) handles the topological sort automatically —
// dependencies are loaded before dependents, and already-loaded modules
// are skipped.
function LoadAll(): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to GDataRegistryCount - 1 do
  begin
    if LoadLibrary(GDataRegistryNames[I]) = 0 then
    begin
      OutputDebugStringFmt('LoadAll: Failed to load "%s".', [GDataRegistryNames[I]]);
      Result := False;
      Exit;
    end;
  end;
end;

// --- Unit Initialization and Finalization ---

initialization
  // Initialize the critical section used for synchronizing hook installation/uninstallation
  // and access to global redirection state variables when the unit is loaded.
  InitializeCriticalSection(GRedirectCritSect);
  OutputDebugStringFmt('Dlluminator unit: Initialized critical section.', []);
  // Optionally resolve NT function pointers here if preferred over lazy initialization.
  // InitializeNtFunctions();

finalization
  // Uninstall the persistent LdrGetDllHandle hook if installed.
  if GLdrHookInstalled and (GLdrGetDllHandleAddr <> nil) then
  begin
    EnterCriticalSection(GRedirectCritSect);
    try
      UninstallHook(GLdrGetDllHandleAddr, GOrigBytesLdrGetDllHandle);
      GLdrHookInstalled := False;
    finally
      LeaveCriticalSection(GRedirectCritSect);
    end;
  end;

  // Delete the critical section object when the unit is unloaded to release system resources.
  DeleteCriticalSection(GRedirectCritSect);
  OutputDebugStringFmt('Dlluminator unit: Finalized (deleted critical section).', []);

end.

