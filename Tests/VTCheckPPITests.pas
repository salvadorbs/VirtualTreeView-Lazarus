unit VTCheckPPITests;

// Regression test for issue #42717 "Fix incorrect per-monitor scaling of
// checkboxes in TLazVirtualTreeView".
//
// PaintCheckImage sized the themed check box with GetDetailSizeForPPI but drew
// it with ThemeServices.DrawElement, which uses the screen PPI. On a monitor
// whose scaling differs from the screen the glyph therefore kept its 96 DPI
// size. The fix uses DrawElementForPPI with the tree font PPI (LCL 5.99+);
// older LCL versions keep DrawElement, where the fix cannot be compiled.
//
// The test paints the themed checked-checkbox glyph at 96 and 168 PPI and
// compares the resulting pixel bounds. Only the Win32 theme backend selects a
// PPI-specific theme handle: on GTK the glyph is already stretched to the
// scaled rect from PaintCheckImage, so the check would pass without the fix.
// The test therefore runs on Windows only and documents the skip elsewhere.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  SysUtils,
  Controls,
  Forms,
  Graphics,
  LCLVersion,
  VirtualTrees,
  VirtualTrees.Types;

type
  /// Exposes the protected check glyph painter.
  TVTCheckPPITreeCracker = class(TVirtualStringTree)
  public
    procedure PaintThemedCheck(ACanvas: TCanvas; X, Y: Integer);
  end;

  TVTCheckPPITests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// The themed check glyph must grow with the tree font PPI.
    procedure ThemedCheckGlyphUsesTreeFontPPI;
  end;

implementation

procedure TVTCheckPPITreeCracker.PaintThemedCheck(ACanvas: TCanvas; X, Y: Integer);
var
  Info: TVTImageInfo;
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.Index := 9; // 9..20 select a themed check box; 9 is "checked normal"
  Info.XPos := X;
  Info.YPos := Y;
  PaintCheckImage(ACanvas, Info, False);
end;

{$IFDEF Windows}
{$IF LCL_FullVersion >= 5990000}
const
  CanvasSize = 64;
  PaintOrigin = 8;
function RenderCheckBounds(ATree: TVirtualStringTree; APPI: Integer): TRect;
var
  Bmp: Graphics.TBitmap;
  X, Y: Integer;
begin
  Result := Rect(MaxInt, MaxInt, -1, -1);

  ATree.Font.PixelsPerInch := APPI;
  Application.ProcessMessages;

  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(CanvasSize, CanvasSize);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(0, 0, CanvasSize, CanvasSize);

    TVTCheckPPITreeCracker(ATree).PaintThemedCheck(Bmp.Canvas, PaintOrigin, PaintOrigin);

    for Y := 0 to CanvasSize - 1 do
      for X := 0 to CanvasSize - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
        begin
          if X < Result.Left then Result.Left := X;
          if Y < Result.Top then Result.Top := Y;
          if X > Result.Right then Result.Right := X;
          if Y > Result.Bottom then Result.Bottom := Y;
        end;
  finally
    Bmp.Free;
  end;
end;

function HasGlyph(const R: TRect): Boolean;
begin
  Result := (R.Right >= R.Left) and (R.Bottom >= R.Top);
end;

function GlyphWidth(const R: TRect): Integer;
begin
  Result := R.Right - R.Left + 1;
end;
{$ENDIF}
{$ENDIF}

procedure TVTCheckPPITests.SetUp;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 320, 200);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.Align := alClient;
  // Themed system check boxes, so PaintCheckImage takes the theme branch.
  fTree.CheckImageKind := ckSystemDefault;
  fTree.TreeStates := fTree.TreeStates + [tsUseThemes];
  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTCheckPPITests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

procedure TVTCheckPPITests.ThemedCheckGlyphUsesTreeFontPPI;
{$IFDEF Windows}
  {$IF LCL_FullVersion >= 5990000}
var
  Small, Large: TRect;
  {$ENDIF}
{$ENDIF}
begin
{$IFNDEF Windows}
  // The GTK theme services stretch the glyph to the rect that PaintCheckImage
  // already scales through GetDetailSizeForPPI, so this test would pass even
  // without DrawElementForPPI. Only the Win32 override selects a theme handle
  // for the requested PPI.
  WriteLn('NOTE: only the Win32 theme backend scales the themed check glyph; ' +
    'the PPI fix of issue #42717 is not observable on this widgetset.');
{$ELSE}
  {$IF LCL_FullVersion < 5990000}
  WriteLn('NOTE: ThemeServices.DrawElementForPPI requires LCL 5.99; the themed ' +
    'check glyph PPI fix of issue #42717 is not compiled on this LCL version.');
  {$ELSE}
  Small := RenderCheckBounds(fTree, 96);
  if not HasGlyph(Small) then
  begin
    WriteLn('NOTE: this backend does not paint the themed check glyph; the ' +
      'PPI scaling of issue #42717 is not observable here.');
    Exit;
  end;

  Large := RenderCheckBounds(fTree, 168);
  AssertTrue('The themed check glyph must also be painted at 168 PPI.', HasGlyph(Large));
  AssertTrue(Format('The themed check glyph must grow with the font PPI: ' +
    '%d px at 96 PPI, %d px at 168 PPI.',
    [GlyphWidth(Small), GlyphWidth(Large)]),
    GlyphWidth(Large) > GlyphWidth(Small));
  {$ENDIF}
{$ENDIF}
end;

initialization
  RegisterTest(TVTCheckPPITests);

end.
