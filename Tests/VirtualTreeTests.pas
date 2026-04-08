unit VirtualTreeTests;

interface

uses
  fpcunit,
  testregistry,
  Forms,
  Graphics,
  LCLType,
  VirtualTrees,
  VirtualTrees.Utils;

type

  TVirtualTreeUtilsTests = class(TTestCase)
  strict private
    fBitmap: TBitmap;
    function GetHDC: HDC;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    procedure TestShortenString(const pLongString: string; const pWidth: Integer; const pShortString: string);
  published
    procedure TestOrderRect;
    procedure TestShortenString_Test1;
    procedure TestShortenString_Test2;
    procedure TestShortenString_Test3;
    procedure TestShortenString_Test4;
    procedure TestShortenString_Test5;
  end;

implementation

uses
  Types,
  SysUtils;

type
  TRectHelper = record helper for TRect
    function ToString: string;
  end;

function TRectHelper.ToString: string;
begin
  Result := Format('(%d,%d,%d,%d)', [Left, Top, Right, Bottom]);
end;

function TVirtualTreeUtilsTests.GetHDC: HDC;
begin
  Exit(fBitmap.Canvas.Handle);
end;

procedure TVirtualTreeUtilsTests.SetUp;
begin
  inherited SetUp;
  fBitmap := TBitmap.Create;
  fBitmap.Canvas.Font.Name := 'Tahoma';
  fBitmap.Canvas.Font.Size := 8;
  AssertEquals('PixelsPerInch of font does not match screen DPI', Screen.PixelsPerInch, fBitmap.Canvas.Font.PixelsPerInch);
end;

procedure TVirtualTreeUtilsTests.TearDown;
begin
  FreeAndNil(fBitmap);
  inherited TearDown;
end;

procedure TVirtualTreeUtilsTests.TestOrderRect;
var
  lRectUnordered: TRect;
  lRectOrderedExpected: TRect;
  lRectOrdered: TRect;
begin
  lRectUnordered := Rect(1,2,3,4);
  lRectOrderedExpected := lRectUnordered;
  lRectOrdered := OrderRect(lRectUnordered);
  AssertTrue(lRectUnordered.ToString + ' should be ordered to ' + lRectOrderedExpected.ToString + ' but was ' + lRectOrdered.ToString, lRectOrdered = lRectOrderedExpected);
  lRectUnordered := Rect(4,3,2,1);
  lRectOrderedExpected := Rect(2,1,4,3);
  lRectOrdered := OrderRect(lRectUnordered);
  AssertTrue(lRectUnordered.ToString + ' should be ordered to ' + lRectOrderedExpected.ToString + ' but was ' + lRectOrdered.ToString, lRectOrdered = lRectOrderedExpected);
end;

procedure TVirtualTreeUtilsTests.TestShortenString_Test1;
begin
  TestShortenString('Abc', 20, 'A...');
end;

procedure TVirtualTreeUtilsTests.TestShortenString_Test2;
begin
  TestShortenString('Abc', 100, 'Abc');
end;

procedure TVirtualTreeUtilsTests.TestShortenString_Test3;
begin
  TestShortenString('Abc', 10, '');
end;

procedure TVirtualTreeUtilsTests.TestShortenString_Test4;
begin
  TestShortenString('A', 100, 'A');
end;

procedure TVirtualTreeUtilsTests.TestShortenString_Test5;
begin
  TestShortenString('ii', 16, 'ii');
end;

procedure TVirtualTreeUtilsTests.TestShortenString(const pLongString: string; const pWidth: Integer; const pShortString: string);
var
  lShortenedString: string;
  lShortenedWidth: Integer;
begin
  lShortenedString := ShortenString(GetHDC, pLongString, pWidth);
  lShortenedWidth := fBitmap.Canvas.TextWidth(lShortenedString);

  AssertTrue(Format('The shortened string "%s" has a width of %d and does not fit into the requested %d pixels.', [lShortenedString, lShortenedWidth, pWidth]), lShortenedWidth <= pWidth);
end;

initialization
  RegisterTest(TVirtualTreeUtilsTests);
end.
