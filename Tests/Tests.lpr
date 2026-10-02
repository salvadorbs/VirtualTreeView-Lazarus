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
  VTOnDrawTextTests in 'VTOnDrawTextTests.pas',
  VTWorkerThreadIssue1001Tests in 'VTWorkerThreadIssue1001Tests.pas',
  VTCellSelectionTests in 'VTCellSelectionTests.pas',
  VirtualTrees.MouseUtils in 'VirtualTrees.MouseUtils.pas',
  VTBandsIssue1091Tests in 'VTBandsIssue1091Tests.pas',
  VTFocusChangedIssue1379Tests in 'VTFocusChangedIssue1379Tests.pas',
  VTHeaderBackgroundTests in 'VTHeaderBackgroundTests.pas',
  VTSelectedCountIssue1197Tests in 'VTSelectedCountIssue1197Tests.pas';

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
