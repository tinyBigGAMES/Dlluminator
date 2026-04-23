{===============================================================================
   ___  _ _            _           _
  |   \| | |_  _ _ __ (_)_ _  __ _| |_ ___ _ _ ™
  | |) | | | || | '  \| | ' \/ _` |  _/ _ | '_|
  |___/|_|_|\_,_|_|_|_|_|_||_\__,_|\__\___|_|
     Load Win64 DLLs from memory in Delphi

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/Dlluminator

 TestDeps — Dependency Resolution Test
 ======================================
 Demonstrates how to load multiple DLLs from memory where one depends on the
 other. This is the core use case for Dlluminator's named LoadLibrary overload.

 Scenario:
   - DllA exports a function GetValueFromA() that returns 42.
   - DllB imports from 'DllA.dll' (via `external 'DllA.dll'`) and exports
     GetCombinedValue() which calls GetValueFromA() and adds 100, returning 142.
   - Both DLLs are embedded as RCDATA resources in the executable.
   - DllA is loaded first and registered under the name 'DllA.dll'.
   - DllB is loaded second. Because it imports from 'DllA.dll', Dlluminator
     detects the registered dependency and resolves DllB's import table
     against the already-loaded DllA module.

 Loading Order Matters:
   Dependencies MUST be loaded before the DLLs that import from them.
   If DllB imports from DllA.dll, then DllA must be loaded and registered
   first. Reversing the order will cause DllB's load to fail.

 How the DLL data is stored:
   Both DLLs are compiled separately (DllA.dproj, DllB.dproj) and linked
   into the test executable as RCDATA resources via the .dres file. The
   resource names are obfuscated GUID-like strings to avoid obvious DLL
   names in the binary.
===============================================================================}

unit UTestDeps;

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  Dlluminator;

var
  // Function pointers that will be resolved from the memory-loaded DLLs.
  // These are populated during initialization and used by the main program
  // (TestDeps.dpr) to verify that cross-DLL calls work correctly.
  GetValueFromA: function(): Integer;    // From DllA — should return 42
  GetCombinedValue: function(): Integer; // From DllB — calls DllA, should return 142

implementation

var
  // Handles to the memory-loaded DLL modules. Stored here so they can be
  // properly freed during finalization.
  DllAHandle: THandle = 0;
  DllBHandle: THandle = 0;

// Returns the obfuscated resource name for DllA's embedded data.
// Using a GUID-like string instead of 'DllA' avoids exposing the DLL
// name in the executable's resource table.
function ResNameDllA(): string;
const
  CValue = 'a1b2c3d4e5f6478890abcdef12345678';
begin
  Result := CValue;
end;

// Returns the obfuscated resource name for DllB's embedded data.
function ResNameDllB(): string;
const
  CValue = 'f8e7d6c5b4a3219087654321fedcba98';
begin
  Result := CValue;
end;

// Loads both DLLs using auto-dependency resolution.
// Registration order doesn't matter — LoadAll figures out the correct
// loading sequence by parsing import tables.
function LoadDLLs(): Boolean;
begin
  Result := False;

  // Guard against double-loading.
  if (DllAHandle <> 0) and (DllBHandle <> 0) then
    Exit(True);

  // Register both DLLs from embedded resources. Order doesn't matter.
  RegisterDllData('DllB.dll', ResNameDllB());
  RegisterDllData('DllA.dll', ResNameDllA());

  // Load everything — dependencies are resolved automatically.
  if not LoadAll() then
  begin
    WriteLn('ERROR: LoadAll failed.');
    Exit;
  end;

  // Retrieve handles — LoadLibrary(name) returns existing handles for
  // already-loaded modules from the module registry.
  DllAHandle := LoadLibrary('DllA.dll');
  DllBHandle := LoadLibrary('DllB.dll');

  // Resolve exports.
  GetValueFromA := GetProcAddress(DllAHandle, 'GetValueFromA');
  WriteLn('DllA loaded successfully. Handle: 0x', IntToHex(DllAHandle));

  GetCombinedValue := GetProcAddress(DllBHandle, 'GetCombinedValue');
  WriteLn('DllB loaded successfully. Handle: 0x', IntToHex(DllBHandle));

  Result := True;
end;

// Frees both memory-loaded DLLs in reverse dependency order.
// Dependents (DllB) must be freed before their dependencies (DllA).
procedure UnloadDLLs();
begin
  // Unload DllB first — it depends on DllA.
  if DllBHandle <> 0 then
  begin
    FreeLibrary(DllBHandle);
    DllBHandle := 0;
  end;

  // Then unload DllA — now safe since no other module references it.
  if DllAHandle <> 0 then
  begin
    FreeLibrary(DllAHandle);
    DllAHandle := 0;
  end;
end;

// Load both DLLs at unit initialization so the function pointers are
// available immediately when the main program starts.
initialization
  try
    if not LoadDLLs() then
    begin
      WriteLn('FATAL: Failed to load test DLLs. Halting.');
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION during LoadDLLs: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;

// Clean up when the program exits.
finalization
  UnloadDLLs();

end.
