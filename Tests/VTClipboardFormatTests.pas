unit VTClipboardFormatTests;

// Regression test for issue #42713 "RegisterVTClipboardFormat returns
// TClipboardFormat instead of Word".
//
// ClipboardRegisterFormat returns a TClipboardFormat, which is PtrUInt (wider
// than 16 bits on 64 bit platforms and used for atoms on the non-Windows
// widgetsets). RegisterVTClipboardFormat declared its result as Word, so the
// registered format could be truncated before it reached the caller.
//
// The test compares the value returned by RegisterVTClipboardFormat with the
// one returned by the LCL for the same format name: a Word result cannot match
// a format id that does not fit into 16 bits.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  LCLIntf,
  LCLType,
  VirtualTrees,
  VirtualTrees.BaseTree,
  VirtualTrees.ClipBoard;

type
  TVTClipboardFormatTests = class(TTestCase)
  published
    /// The returned id must be the untruncated TClipboardFormat of the LCL.
    procedure RegisterReturnsFullClipboardFormat;
  end;

implementation

uses
  SysUtils;

const
  FormatName = 'application/x-vtv-issue42713';

procedure TVTClipboardFormatTests.RegisterReturnsFullClipboardFormat;
var
  Expected, Actual: TClipboardFormat;
begin
  Expected := ClipboardRegisterFormat(FormatName);
  AssertTrue('Sanity: the LCL must register the test clipboard format.',
    Expected <> 0);

  Actual := RegisterVTClipboardFormat(FormatName, TVirtualStringTree, 1);

  // On backends whose format ids fit into 16 bits (e.g. gdk quarks on GTK2)
  // the Word truncation is not observable; on others (GTK3, 64 bit atoms) it is.
  if PtrUInt(Expected) <= $FFFF then
  begin
    WriteLn('NOTE: this backend returns 16 bit clipboard format ids; the ' +
      'truncation of issue #42713 is not observable here.');
    Exit;
  end;
  AssertTrue(Format('RegisterVTClipboardFormat returned $%x, the LCL returned $%x ' +
    '(issue #42713).', [PtrUInt(Actual), PtrUInt(Expected)]),
    Actual = Expected);
end;

initialization
  RegisterTest(TVTClipboardFormatTests);

end.
