{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

program ImportLibs;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UImportLibs in 'UImportLibs.pas',
  Dlluminator.CImporter in '..\..\src\Dlluminator.CImporter.pas',
  Dlluminator.Config in '..\..\src\Dlluminator.Config.pas',
  Dlluminator in '..\..\src\Dlluminator.pas',
  Dlluminator.Resources in '..\..\src\Dlluminator.Resources.pas',
  Dlluminator.TOML in '..\..\src\Dlluminator.TOML.pas',
  Dlluminator.Utils in '..\..\src\Dlluminator.Utils.pas';

begin
  RunImportLibs();
end.
