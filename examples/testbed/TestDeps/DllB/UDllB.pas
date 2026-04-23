{===============================================================================
   ___  _ _            _           _
  |   \| | |_  _ _ __ (_)_ _  __ _| |_ ___ _ _ ™
  | |) | | | || | '  \| | ' \/ _` |  _/ _ | '_|
  |___/|_|_|\_,_|_|_|_|_|_||_\__,_|\__\___|_|
     Load Win64 DLLs from memory in Delphi

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/Dlluminator

 TestDeps - DllB
 Dependent DLL. Imports GetValueFromA from DllA.dll and exports its own
 function that calls it. This tests that the Windows loader can resolve
 imports between memory-loaded DLLs via Dlluminator's module name patching.
===============================================================================}

unit UDllB;

interface

// Calls GetValueFromA() from DllA and adds 100 to it.
// Expected result: 42 + 100 = 142
function GetCombinedValue(): Integer; exports GetCombinedValue;

implementation

// Import from DllA.dll — this creates a PE import table entry for 'DllA.dll'.
// When loaded via Dlluminator with module name 'DllA.dll', the loader resolves
// this import against the patched LDR BaseDllName.
function GetValueFromA(): Integer; external 'DllA.dll';

function GetCombinedValue(): Integer;
begin
  Result := GetValueFromA() + 100;
end;

end.
