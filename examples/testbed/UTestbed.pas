{===============================================================================
   ___  _ _            _           _
  |   \| | |_  _ _ __ (_)_ _  __ _| |_ ___ _ _ ™
  | |) | | | || | '  \| | ' \/ _` |  _/ _ | '_|
  |___/|_|_|\_,_|_|_|_|_|_||_\__,_|\__\___|_|
     Load Win64 DLLs from memory in Delphi

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/Dlluminator
===============================================================================}

unit UTestbed;

interface

uses
  WinApi.Windows,
  System.Classes,
  Dlluminator;

var
  Test01: procedure();

implementation

{
  This code is an example of using Dlluminator to load an embedded a DLL directly
  from an embedded resource in memory, ensuring that no filesystem access is
  required. It includes methods for loading, initializing, and unloading the
  DLL. The DLL is loaded from a resource with a GUID name, providing a measure
  of security by obfuscating the resource’s identity.

  Variables:
    - DLLHandle: THandle
        - A handle to the loaded DLL. Initialized to 0, indicating the DLL has
          not been loaded. It is updated with the handle returned from
          LoadLibrary when the DLL is successfullyloaded from memory.

  Functions:
    - LoadDLL: Boolean
        - Loads the DLL from an embedded resource and initializes it by
          retrieving necessary exported functions. Returns True if the DLL is
          loaded successfully, otherwise False.

    - b6eb28fd6ebe48359ef93aef774b78d1: string
        - A GUID-named helper function that returns the resource name for the DLL.
          This GUID-like name helps avoid easy detection of the resource.

    - UnloadDLL: procedure
        - Unloads the DLL by freeing the library associated with DLLHandle. Resets
          DLLHandle to 0 to indicate the DLL is unloaded.

  Initialization:
    - The LoadDLL function is called during initialization, and the program will
      terminate with code 1 if the DLL fails to load.

  Finalization:
    - The UnloadDLL procedure is called upon finalization, ensuring the DLL is
      unloaded before program termination.

}

var
  DLLHandle: THandle = 0; // Global handle to the loaded DLL, 0 when not loaded.

{
  LoadDLL
  --------
  Attempts to load a DLL directly from a resource embedded within the executable
  file. This DLL is expected to be stored as an RCDATA resource under a specific
  GUID-like name.

  Returns:
    Boolean - True if the DLL is successfully loaded, False otherwise.
}
function LoadDLL(): Boolean;
var
  LResStream: TResourceStream; // Stream to access the DLL data stored in the resource.

  {
    b6eb28fd6ebe48359ef93aef774b78d1
    ---------------------------------
    Returns the name of the embedded DLL resource. Uses a GUID-like name for
    obfuscation.

    Returns:
      string - The name of the resource containing the DLL data.
  }
  function b6eb28fd6ebe48359ef93aef774b78d1(): string;
  const
    // GUID-like resource name for the embedded DLL.
    CValue = 'b87deef5bbfd43c3a07379e26f4dec9b';
  begin
    Result := CValue;
  end;

begin
  Result := False;

  // Check if the DLL is already loaded.
  if DLLHandle <> 0 then Exit;

  // Ensure the DLL resource exists.
  if not Boolean((FindResource(HInstance,
    PChar(b6eb28fd6ebe48359ef93aef774b78d1()), RT_RCDATA) <> 0)) then Exit;

  // Create a stream for the DLL resource data.
  LResStream := TResourceStream.Create(HInstance,
    b6eb28fd6ebe48359ef93aef774b78d1(), RT_RCDATA);

  try
    // Attempt to load the DLL from the resource stream.
    DLLHandle := LoadLibrary(LResStream.Memory, LResStream.Size);
    if DLLHandle = 0 then Exit; // Loading failed.

    // Retrieve and initialize any necessary function exports from the DLL.
    Test01 := GetProcAddress(DLLHandle, 'Test01');

    Result := True; // Successful load and initialization.
  finally
    LResStream.Free(); // Release the resource stream.
  end;
end;

{
  UnloadDLL
  ---------
  Frees the loaded DLL, releasing any resources associated with DLLHandle,
  and resets DLLHandle to 0.
}
procedure UnloadDLL();
begin
  if DLLHandle <> 0 then
  begin
    FreeLibrary(DLLHandle); // Unload the DLL.
    DLLHandle := 0; // Reset DLLHandle to indicate the DLL is no longer loaded.
  end;
end;

initialization
  // Attempt to load the DLL upon program startup. Halt execution with error
  // code 1 if it fails.
  if not LoadDLL() then
  begin
    Halt(1);
  end;

finalization
  // Ensure the DLL is unloaded upon program termination.
  UnloadDLL();

end.

