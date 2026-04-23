program TestDeps;

{$APPTYPE CONSOLE}

{$R *.res}

{$R *.dres}

uses
  System.SysUtils,
  UTestDeps in 'UTestDeps.pas',
  Dlluminator in '..\..\..\src\Dlluminator.pas';

var
  LValue: Integer;

begin
  try

    // Test 1: Direct call to DllA
    LValue := GetValueFromA();
    WriteLn('GetValueFromA() = ', LValue, ' (expected 42)');

    // Test 2: Call DllB which internally calls DllA
    LValue := GetCombinedValue();
    WriteLn('GetCombinedValue() = ', LValue, ' (expected 142)');

    if LValue = 142 then
      WriteLn('SUCCESS: Dependency resolution works!')
    else
      WriteLn('FAILURE: Unexpected result.');

    Write('Press ANY key to continue...');
    ReadLn;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
