{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UImportLibs;

interface


procedure RunImportLibs();


implementation

uses
  System.SysUtils,
  Dlluminator.Utils,
  Dlluminator.CImporter;

procedure ImportRaylib();
var
  LImporter: TDlmCImporter;
begin
  TDlmUtils.PrintLn('=== Import raylib.h ===');
  TDlmUtils.PrintLn('');

  LImporter := TDlmCImporter.Create();
  try
    LImporter.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        TDlmUtils.PrintLn(AText);
      end
    );
    LImporter.SetSavePreprocessed(True);
    LImporter.SetModuleName('raylib');
    LImporter.SetDllName('raylib');
    LImporter.SetOutputPath('..\imports');
    LImporter.SetDllPath('..\libs\raylib\bin\raylib.dll');
    LImporter.AddIncludePath('..\libs\raylib\include');
    LImporter.AddSourcePath('..\libs\raylib\include');
    LImporter.AddExcludedType('va_list');
    LImporter.SetHeader('..\libs\raylib\include\raylib.h');
    LImporter.SaveToConfig('..\libs\raylib\raylib.toml');
    if LImporter.Process() then
      TDlmUtils.PrintLn(COLOR_CYAN + 'Success')
    else
      TDlmUtils.PrintLn(COLOR_RED + 'Failed: %s', [LImporter.GetLastError()]);
  finally
    LImporter.Free();
  end;

  TDlmUtils.PrintLn('');
  TDlmUtils.PrintLn('=== Done ===');
end;

procedure ImportSDL3();
var
  LImporter: TDlmCImporter;
begin
  TDlmUtils.PrintLn('');
  TDlmUtils.PrintLn('=== Import SDL3 ===');
  TDlmUtils.PrintLn('');

  LImporter := TDlmCImporter.Create();
  try
    LImporter.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        TDlmUtils.PrintLn(AText);
      end
    );

    LImporter.AddExcludedType('SDL_PRIX64');
    LImporter.AddFunctionRename('SDL_Log', 'SDL_Log_');

    LImporter.SetSavePreprocessed(True);
    LImporter.SetModuleName('sdl3');
    LImporter.SetDllName('sdl3');
    LImporter.SetOutputPath('..\imports');
    LImporter.SetDllPath('..\libs\sdl3\bin\SDL3.dll');
    LImporter.AddIncludePath('..\libs\sdl3\include');
    LImporter.AddSourcePath('..\libs\sdl3\include\SDL3');
    LImporter.AddExcludedType('va_list');
    LImporter.SetHeader('..\libs\sdl3\include\SDL3\SDL.h');
    LImporter.SaveToConfig('..\libs\sdl3\sdl3.toml');
    if LImporter.Process() then
      TDlmUtils.PrintLn(COLOR_CYAN + 'Success')
    else
      TDlmUtils.PrintLn(COLOR_RED + 'Failed: %s', [LImporter.GetLastError()]);
  finally
    LImporter.Free();
  end;

  TDlmUtils.PrintLn('=== Done ===');
end;

procedure ImportSDL3Image();
var
  LImporter: TDlmCImporter;
begin
  TDlmUtils.PrintLn('');
  TDlmUtils.PrintLn('=== Import SDL3_Image ===');
  TDlmUtils.PrintLn('');

  LImporter := TDlmCImporter.Create();
  try
    LImporter.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        TDlmUtils.PrintLn(AText);
      end
    );
    LImporter.SetSavePreprocessed(True);
    LImporter.SetModuleName('sdl3_image');
    LImporter.SetDllName('sdl3_image');
    LImporter.SetOutputPath('..\imports');
    LImporter.SetDllPath('..\libs\sdl3_image\bin\SDL3_image.dll');
    LImporter.AddIncludePath('..\libs\sdl3_image\include');
    LImporter.AddIncludePath('..\libs\sdl3\include', 'sdl3');
    LImporter.AddSourcePath('..\libs\sdl3_image\include\SDL3');
    LImporter.AddUsesUnit('sdl3');
    LImporter.AddExcludedType('va_list');
    LImporter.SetHeader('..\libs\sdl3_image\include\SDL3\SDL_image.h');
    LImporter.SaveToConfig('..\libs\sdl3_image\sdl3_image.toml');
    if LImporter.Process() then
      TDlmUtils.PrintLn(COLOR_CYAN + 'Success')
    else
      TDlmUtils.PrintLn(COLOR_RED + 'Failed: %s', [LImporter.GetLastError()]);
  finally
    LImporter.Free();
  end;
  TDlmUtils.PrintLn('=== Done ===');
end;

procedure ImportSDL3Mixer();
var
  LImporter: TDlmCImporter;
begin
  TDlmUtils.PrintLn('');
  TDlmUtils.PrintLn('=== Import SDL3_Mixer ===');
  TDlmUtils.PrintLn('');

  LImporter := TDlmCImporter.Create();
  try
    LImporter.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        TDlmUtils.PrintLn(AText);
      end
    );
    LImporter.SetSavePreprocessed(True);
    LImporter.SetModuleName('sdl3_mixer');
    LImporter.SetDllName('sdl3_mixer');
    LImporter.SetOutputPath('..\imports');
    LImporter.SetDllPath('..\libs\sdl3_mixer\bin\SDL3_mixer.dll');
    LImporter.AddIncludePath('..\libs\sdl3_mixer\include');
    LImporter.AddIncludePath('..\libs\sdl3\include', 'sdl3');
    LImporter.AddSourcePath('..\libs\sdl3_mixer\include\SDL3');
    LImporter.AddUsesUnit('sdl3');
    LImporter.AddExcludedType('va_list');
    LImporter.SetHeader('..\libs\sdl3_mixer\include\SDL3\SDL_mixer.h');
    LImporter.SaveToConfig('..\libs\sdl3_mixer\sdl3_mixer.toml');
    if LImporter.Process() then
      TDlmUtils.PrintLn(COLOR_CYAN + 'Success')
    else
      TDlmUtils.PrintLn(COLOR_RED + 'Failed: %s', [LImporter.GetLastError()]);
  finally
    LImporter.Free();
  end;

  TDlmUtils.PrintLn('=== Done ===');
end;

procedure RunImportLibs();
var
  LIndex: Integer;
begin
  try
    LIndex := 0;

    case LIndex of
      01: ImportRaylib();
      02: ImportSDL3();
      03: ImportSDL3Image();
      04: ImportSDL3Mixer();
    else
      ImportRaylib();
      ImportSDL3();
      ImportSDL3Image();
      ImportSDL3Mixer();
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
