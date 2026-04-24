{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

program TestImports;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UTestImports in 'UTestImports.pas',
  UTest.SDL3 in 'UTest.SDL3.pas',
  UTest.RayLib in 'UTest.RayLib.pas';

begin
  RunTestImports();
end.
