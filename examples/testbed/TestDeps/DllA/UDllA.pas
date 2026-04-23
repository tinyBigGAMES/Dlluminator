{===============================================================================
   ___  _ _            _           _
  |   \| | |_  _ _ __ (_)_ _  __ _| |_ ___ _ _ ™
  | |) | | | || | '  \| | ' \/ _` |  _/ _ | '_|
  |___/|_|_|\_,_|_|_|_|_|_||_\__,_|\__\___|_|
     Load Win64 DLLs from memory in Delphi

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/Dlluminator

 TestDeps - DllA
 Base dependency DLL. Exports GetValueFromA which returns a known value.
 DllB imports this function to test cross-DLL dependency resolution.
===============================================================================}

unit UDllA;

interface

// Returns a known integer value (42) for dependency chain verification.
function GetValueFromA(): Integer; exports GetValueFromA;

implementation

function GetValueFromA(): Integer;
begin
  Result := 42;
end;

end.
