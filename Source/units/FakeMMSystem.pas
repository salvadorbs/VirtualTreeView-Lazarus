unit FakeMMSystem;

{$mode objfpc}{$H+}

// Minimal replacement for the Windows MMSystem unit. It is used by the
// non-Windows builds of Virtual TreeView so that the shared code can keep
// calling the MMSystem timer API.

interface

uses
  Classes, SysUtils, Types, LCLIntf;

function timeBeginPeriod(x1: DWord): DWord;

function timeEndPeriod(x1: DWord): DWord;

function timeGetTime: DWORD;

implementation

function timeBeginPeriod(x1: DWord): DWord;
begin
  // The resolution of the timer cannot be changed on this platform. The function
  // is only implemented to let the code of the upstream work.
  Result := 0;
end;

function timeEndPeriod(x1: DWord): DWord;
begin
  Result := 0;
end;

function timeGetTime: DWORD;
begin
  // The same semantics as the Windows function: the number of milliseconds which
  // elapsed since the system was started. Like the Windows value it wraps around
  // after 49 days, so the difference of two values has to be calculated with an
  // unsigned arithmetic.
  Result := DWORD(GetTickCount64);
end;

end.
