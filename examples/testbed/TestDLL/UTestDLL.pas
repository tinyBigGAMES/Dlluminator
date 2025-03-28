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

unit UTestDLL;

interface

uses
  WinApi.Windows;

procedure Test01(); exports Test01;

implementation

procedure Test01();
begin
  MessageBox(0, 'This is exported routine Test01()', 'TestDLL', MB_OK);
end;

end.
