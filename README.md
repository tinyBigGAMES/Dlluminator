<div align="center">

![Dlluminator](media/dlluminator.png)

<br>

[![Discord](https://img.shields.io/discord/1457450179254026250?style=for-the-badge&logo=discord&label=Discord)](https://discord.gg/Wb6z8Wam7p) [![Follow on Bluesky](https://img.shields.io/badge/Bluesky-tinyBigGAMES-blue?style=for-the-badge&logo=bluesky)](https://bsky.app/profile/tinybiggames.com) 

</div>

<div align="center">

### Load Win64 DLLs straight from memory 💻

</div>

### Overview

The **Dlluminator** unit provides advanced functionality for loading dynamic-link libraries (DLLs) directly from memory in Win64 environments. Unlike traditional methods that involve loading DLLs from the file system, **Dlluminator** allows you to load DLLs from byte arrays or memory streams, retrieve function addresses, and unload them—all in-memory. This library is ideal for Delphi developers who need to manage DLLs without relying on the filesystem, enhancing both performance and security.

**Dlluminator** also supports **cross-DLL dependency resolution** between memory-loaded modules. If DllB imports from DllA, and both are loaded from memory, Dlluminator resolves the dependency automatically — no manual ordering required. This works even on **Windows 11 24H2+**, where internal loader changes broke traditional name-patching approaches.

### Features

- **LoadLibrary** — Loads a DLL from a memory buffer without writing to the disk.
- **Named LoadLibrary** — Loads a DLL from memory and registers it under a module name, enabling other memory-loaded DLLs to import from it.
- **RegisterDllData** — Registers DLL data (from a pointer or an embedded resource) for deferred loading — nothing is loaded until you say so.
- **LoadAll** — Loads all registered DLLs in the correct dependency order automatically, using depth-first topological resolution.
- **FreeLibrary** — Unloads the DLL from memory, ensuring all associated resources are properly released.
- **GetProcAddress** — Retrieves the address of an exported function within the loaded DLL, enabling direct function calls.
- **Circular Dependency Detection** — Detects and reports circular dependency chains during auto-resolution.
- **Comprehensive Error Handling** — Manages issues such as invalid DLL data, memory allocation failures, and function resolution issues.

### Key Benefits

- **Increased Security 🔒** — By eliminating the need to store DLLs on disk, **Dlluminator** reduces the risk of DLL hijacking and unauthorized access.
- **Performance Improvement ⚡** — Since DLLs are handled in-memory, the overhead of disk I/O operations is avoided, resulting in faster execution.
- **Flexibility** — Suitable for embedding DLLs in the main executable, loading encrypted or obfuscated DLLs, and supporting dynamic plugin systems where plugins are provided as in-memory modules.
- **Cross-DLL Dependencies 🔗** — Load multiple DLLs from memory where one depends on another. Dlluminator resolves imports between memory-loaded modules using manual IAT resolution.
- **Auto-Dependency Resolution** — Register all your DLLs upfront, call `LoadAll`, and Dlluminator figures out the correct loading order by parsing PE import tables.
- **Windows 11 24H2+ Compatible** — Works around internal loader changes in Windows 11 build 26200+ that broke traditional approaches. Uses `LdrGetDllHandle` and `LdrLoadDll` hooks for robust module lookup.
- **Compatibility** — Compatible with standard DLL interfaces, allowing for easy integration with existing applications.

### Usage Scenarios

#### Embedding DLLs 📦

Embed DLLs directly within your executable. **Dlluminator** allows you to store DLLs as resources, static byte arrays or encrypted data and load them into memory at runtime, removing the need to distribute them as separate files.

#### Encrypted DLL Loading 🔐

Enhance application security by storing DLLs in an encrypted form, which can then be decrypted into memory before loading with **Dlluminator**. This reduces the risk of reverse engineering.

#### Dynamic Plugin Systems 🔌

Load plugins dynamically as in-memory DLLs. This approach provides a clean and secure method of extending application functionality without relying on the filesystem.

#### Multi-DLL Frameworks 🔗

Load an entire framework of interdependent DLLs from memory. Register all modules upfront with `RegisterDllData`, call `LoadAll`, and Dlluminator loads them in the correct order — even if DllC depends on DllB which depends on DllA.

### Public Functions

#### LoadLibrary (basic)

Loads a DLL from a memory buffer without writing to disk. Returns a standard `HMODULE` handle compatible with `GetProcAddress` and `FreeLibrary`.

- **Parameters**: `AData: Pointer` — Pointer to the raw DLL binary data. `ASize: NativeUInt` — Size in bytes.
- **Returns**: `THandle` — Module handle, or `0` on failure.

#### LoadLibrary (named)

Loads a DLL from memory and registers it under a module name, enabling other memory-loaded DLLs to import from it. Dependencies must be loaded before dependents when using this overload directly.

- **Parameters**: `AData: Pointer` — Pointer to the raw DLL binary data. `ASize: NativeUInt` — Size in bytes. `AModuleName: string` — Name to register (e.g., `'DllA.dll'`).
- **Returns**: `THandle` — Module handle, or `0` on failure.

#### RegisterDllData (pointer)

Registers raw DLL data for deferred loading. Does NOT load the DLL — just stores a reference. The caller owns the memory and must keep it valid until loading occurs.

- **Parameters**: `AModuleName: string` — Module name (e.g., `'DllA.dll'`). `AData: Pointer` — Pointer to raw DLL bytes. `ASize: NativeUInt` — Size in bytes.

#### RegisterDllData (resource)

Registers a DLL from an embedded `RT_RCDATA` resource for deferred loading. The resource is read on demand when `LoadLibrary` or `LoadAll` is called — no data is held in memory until then.

- **Parameters**: `AModuleName: string` — Module name (e.g., `'DllA.dll'`). `AResName: string` — Resource name in the executable.

#### LoadLibrary (by name)

Loads a previously registered DLL by name, automatically resolving and loading all dependencies first (depth-first topological sort). If the module is already loaded, returns the existing handle.

- **Parameters**: `AModuleName: string` — Name of a registered module.
- **Returns**: `THandle` — Module handle, or `0` on failure.

#### LoadAll

Loads all registered DLLs in the correct dependency order. Iterates the data registry and calls `LoadLibrary(AModuleName)` for each entry — dependency ordering is handled automatically.

- **Returns**: `Boolean` — `True` if all modules loaded successfully, `False` on first failure.

### Example: Single DLL

Load a single DLL from an embedded resource:

```delphi
uses
  WinApi.Windows,
  Dlluminator;

var
  LDllHandle: THandle;
  LResStream: TResourceStream;
begin
  LResStream := TResourceStream.Create(HInstance, 'MyDllResource', RT_RCDATA);
  try
    LDllHandle := Dlluminator.LoadLibrary(LResStream.Memory, LResStream.Size);
    if LDllHandle <> 0 then
    try
      // Use GetProcAddress / FreeLibrary as normal
      MyFunc := GetProcAddress(LDllHandle, 'MyFunction');
    finally
      FreeLibrary(LDllHandle);
    end;
  finally
    LResStream.Free();
  end;
end;
```

### Example: Multiple DLLs with Auto-Dependency Resolution

Register DLLs from embedded resources in any order, then load everything with a single call. Dlluminator parses import tables and loads dependencies first automatically:

```delphi
uses
  WinApi.Windows,
  Dlluminator;

var
  LDllBHandle: THandle;
begin
  // Register DLLs from resources — order doesn't matter.
  // DllB imports from DllA.dll, but we register DllB first.
  RegisterDllData('DllB.dll', 'f8e7d6c5b4a3219087654321fedcba98');
  RegisterDllData('DllA.dll', 'a1b2c3d4e5f6478890abcdef12345678');

  // Load everything — DllA is loaded first (dependency), then DllB.
  if LoadAll() then
  begin
    // Retrieve handles for individual modules.
    LDllBHandle := LoadLibrary('DllB.dll');

    // DllB can call DllA's exports — cross-DLL calls work.
    GetCombinedValue := GetProcAddress(LDllBHandle, 'GetCombinedValue');
  end;
end;
```

### Example: Manual Dependency Ordering (Advanced)

If you prefer explicit control over loading order, use the named `LoadLibrary` overload directly:

```delphi
uses
  WinApi.Windows,
  Dlluminator;

var
  LDllAHandle: THandle;
  LDllBHandle: THandle;
  LResStream: TResourceStream;
begin
  // Step 1: Load the dependency first and register its name.
  LResStream := TResourceStream.Create(HInstance, 'DllAResource', RT_RCDATA);
  try
    LDllAHandle := LoadLibrary(LResStream.Memory, LResStream.Size, 'DllA.dll');
  finally
    LResStream.Free();
  end;

  // Step 2: Load the dependent DLL. Its import table references
  // 'DllA.dll', which is resolved against the registered module.
  LResStream := TResourceStream.Create(HInstance, 'DllBResource', RT_RCDATA);
  try
    LDllBHandle := LoadLibrary(LResStream.Memory, LResStream.Size, 'DllB.dll');
  finally
    LResStream.Free();
  end;

  // Both are now fully functional — DllB can call DllA's exports.
  MyFunc := GetProcAddress(LDllBHandle, 'MyFunction');
end;
```

### Installation

1. **Download** — Visit the official **Dlluminator** repository and download the <a href="https://github.com/tinyBigGAMES/Dlluminator/archive/refs/heads/main.zip" target="_blank">latest release</a>.

2. **Extract** — Unzip the contents to a convenient location on your filesystem.

3. **Add to Project** — Add **Dlluminator** to your project's `uses` section. Ensure the path to the source file is correctly configured in your project settings.

4. **Integration** — **Dlluminator** provides `LoadLibrary` to load DLLs directly from memory. Once loaded, standard Windows API calls such as `FreeLibrary` and `GetProcAddress` work as if the DLL were loaded from the filesystem. For cross-DLL dependencies, use `RegisterDllData` + `LoadAll` for automatic resolution, or the named `LoadLibrary` overload for manual control.

5. **Test** — Thoroughly test your project after integrating to ensure all DLLs are correctly loaded, utilized, and unloaded. Created/tested with Delphi 12.3, on Windows 11, 64-bit (version 24H2).

### Acknowledgments

This project was inspired by:
  * perfect-loader - https://github.com/EvanMcBroom/perfect-loader

## Contributing

Dlluminator is an open project. Whether you are fixing a bug, improving documentation, or proposing a feature, contributions are welcome.

- **Report bugs**: Open an issue with a minimal reproduction. The smaller the example, the faster the fix.
- **Suggest features**: Describe the use case first. Features that emerge from real problems get traction fastest.
- **Submit pull requests**: Bug fixes, documentation improvements, and well-scoped features are all welcome. Keep changes focused.

### Contributors

<a href="https://github.com/tinyBigGAMES/Dlluminator/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=tinyBigGAMES/Dlluminator&max=500&columns=20&anon=1" />
</a>

Join the [Discord](https://discord.gg/Wb6z8Wam7p) to discuss development, ask questions, and share what you are building.

## Support the Project

Dlluminator is built in the open. If it saves you time or sparks something useful:

- ⭐ **Star the repo**: it costs nothing and helps others find the project
- 🗣️ **Spread the word**: write a post, mention it in a community you are part of
- 💬 **[Join us on Discord](https://discord.gg/Wb6z8Wam7p)**: share what you are building and help shape what comes next
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)**: sponsorship directly funds development and documentation
- 🦋 **[Follow on Bluesky](https://bsky.app/profile/tinybiggames.com)**: stay in the loop on releases and development

## License

Dlluminator is licensed under the **Apache License 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/Dlluminator/tree/main?tab=License-1-ov-file#readme) for details.

Apache 2.0 is a permissive open source license that lets you use, modify, and distribute Dlluminator freely in both open source and commercial projects. You are not required to release your own source code. The license includes an explicit patent grant. Attribution is required; keep the copyright notice and license file in place.

## Links

- [Discord](https://discord.gg/Wb6z8Wam7p)
- [Bluesky](https://bsky.app/profile/tinybiggames.com)
- [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**Dlluminator™** - Load Win64 DLLs straight from memory

Copyright &copy; 2025-present tinyBigGAMES™ LLC<br/>All Rights Reserved.

</div>
