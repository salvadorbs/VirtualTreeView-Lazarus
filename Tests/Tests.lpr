program Tests;

{$MODE Delphi}
{$H+}

{$APPTYPE CONSOLE}
uses
  Interfaces,
  SysUtils,
  Forms,
  consoletestrunner,
  VirtualTreeTests in 'VirtualTreeTests.pas',
  VirtualStringTreeTests in 'VirtualStringTreeTests.pas',
  VTOnEditCancelledTests in 'VTOnEditCancelledTests.pas',
  VTOnDrawTextTests in 'VTOnDrawTextTests.pas';

var
  TestRunner: TTestRunner;
begin
  try
    Application.Initialize;
    TestRunner := TTestRunner.Create(nil);
    try
      TestRunner.Initialize;
      TestRunner.Run;
    finally
      TestRunner.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
