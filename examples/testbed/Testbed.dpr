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

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

{$R *.dres}

uses
  System.SysUtils,
  UTestbed in 'UTestbed.pas',
  Dlluminator in '..\..\src\Dlluminator.pas';

begin
  try
    // Run imported routine from TestDLL memory DLL.
    Test01();
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
