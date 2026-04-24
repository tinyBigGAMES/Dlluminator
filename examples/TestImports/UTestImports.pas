{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTestImports;

interface

procedure RunTestImports();

implementation

uses
  System.SysUtils,
  Dlluminator.Utils,
  UTest.RayLib,
  UTest.SDL3;

procedure RunTestImports();
var
  LIndex: Integer;
begin
  try
    LIndex := 0;

    case LIndex of
      01: TestRayLib(1);
      02: TestSDL3(1);
      03: TestSDL3(2);
      04: TestSDL3(3);
    else
     TestRayLib(1);
     TestSDL3(1);
     TestSDL3(2);
     TestSDL3(3);
    end;
  except
    on E: Exception do
    begin
      TDlmUtils.PrintLn('');
      TDlmUtils.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);
    end;
  end;

  if TDlmUtils.RunFromIDE() then
    TDlmUtils.Pause();
end;

end.
