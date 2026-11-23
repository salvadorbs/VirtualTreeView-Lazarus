unit VTFakeMMSystemTests;

interface

uses
  fpcunit,
  testregistry;

type
  TFakeMMSystemTests = class(TTestCase)
  published
    procedure TestTimeGetTimeAdvancesBeyondOneSecond;
  end;

implementation

uses
  SysUtils,
  LCLIntf,
  {$ifdef Windows}
  MMSystem
  {$else}
  FakeMMSystem
  {$endif}
  ;

procedure TFakeMMSystemTests.TestTimeGetTimeAdvancesBeyondOneSecond;
var
  StartTime: DWORD;
  Elapsed: Int64;
  StartTick: QWord;
begin
  StartTick := GetTickCount64;
  StartTime := timeGetTime;
  // Wait until the timer advanced by at least one second. The wall clock guard
  // keeps the test finite if timeGetTime is broken (for example when it wraps
  // every second instead of counting the elapsed milliseconds).
  while (GetTickCount64 - StartTick < 3000) and
    (Int64(timeGetTime) - Int64(StartTime) < 1000) do
    Sleep(10);
  Elapsed := Int64(timeGetTime) - Int64(StartTime);
  AssertTrue('timeGetTime must return elapsed milliseconds, not the millisecond of the current second',
    Elapsed >= 1000);
end;

initialization
  RegisterTest(TFakeMMSystemTests);
end.
