unit fakemmsystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, LCLIntf;

function timeBeginPeriod(x1: DWord): DWord;

function timeEndPeriod(x1: DWord): DWord;

function timeGetTime: DWORD;

implementation

function timeBeginPeriod(x1: DWord): DWord;
begin
  // There is no system-wide timer resolution to change on this platform.
end;

function timeEndPeriod(x1: DWord): DWord;
begin
  // There is no system-wide timer resolution to change on this platform.
end;

function timeGetTime: DWORD;
begin
  // Monotonic milliseconds since system start, matching MMSystem's timeGetTime().
  Result := GetTickCount;
end;

end.
