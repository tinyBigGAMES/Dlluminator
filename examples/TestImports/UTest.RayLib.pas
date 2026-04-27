{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.RayLib;

interface

procedure TestRayLib(const ANum: Integer);

implementation

uses
  System.SysUtils,
  Dlluminator.Utils,
  raylib_static;

procedure Test01();
begin
  InitWindow(800, 450, 'Dlluminator - Raylib Test');
  SetTargetFPS(60);
  while not WindowShouldClose() do
  begin
    BeginDrawing();
      ClearBackground(RAYWHITE);
      DrawText('Hello from Dlluminator!', 280, 200, 20, DARKGREEN);
    EndDrawing();
  end;
  CloseWindow();
end;

procedure TestRayLib(const ANum: Integer);
begin
  case ANum of
    01: Test01();
  end;
end;

end.
