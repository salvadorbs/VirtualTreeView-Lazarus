unit VTBandsIssue1091Tests;

// Regression test for issue #1091 "Drawing issue when LineMode = lmBands".
//
// With the explorer theme active, DetermineLineImageAndSelectLevel() suppresses the
// tree line under the expand button by overwriting the LAST entry of the line image
// with ltNone. The band conversion in PaintTreeLines() however documents and relies
// on the invariant that ltNone never appears as the last entry: on ltNone it copies
// the style of the entry to the RIGHT, which for the last entry is an out-of-bounds
// read of the dynamic array. The garbage styles made the bands of every collapsed
// node with children disappear.
//
// The fix skips that suppression in band mode - bands are box edges, not lines
// pointing at a button. Hence the assertion: with buttons hidden, the band rendering
// must be pixel-identical whether the explorer theme state is set or not.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Controls,
  Types,
  Forms,
  Graphics,
  VirtualTrees;

type
  TVTBandsIssue1091Tests = class(TTestCase)
  strict private

    fForm: TForm;

    fTree: TVirtualStringTree;

    /// Renders the tree offscreen and returns the band/grid pixels as count plus checksum.

    function RenderBands(out Checksum: Cardinal; out ContentPixels: Integer): Integer;

  public

  protected



    procedure SetUp; override;



    procedure TearDown; override;





    /// Bands must render identically with and without the explorer theme state.

  published

    procedure ExplorerThemeStateDoesNotChangeBands;
  end;

implementation

uses
  SysUtils,
  VirtualTrees.Types,
  VirtualTrees.BaseTree;

type
  TTreeCracker = class(TBaseVirtualTree); // for DoStateChange

const
  BandColor = clRed;

procedure TVTBandsIssue1091Tests.SetUp;
var
  Root0, Child0, Root1: PVirtualNode;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 420, 300);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(10, 10, 380, 240);
  fTree.LineMode := lmBands;
  fTree.LineStyle := lsSolid;
  fTree.Colors.GridLineColor := BandColor;
  // Buttons off: the plus/minus vs. chevron glyphs would differ between the two
  // renderings; the line suppression under test does not depend on them.
  fTree.TreeOptions.PaintOptions := fTree.TreeOptions.PaintOptions
    + [toShowTreeLines, toShowRoot, toShowHorzGridLines, toShowVertGridLines]
    - [toShowButtons];

  // The broken cases are collapsed nodes WITH children (their last line image entry
  // got overwritten): one at level 1 inside an expanded root, one at level 0.
  Root0 := fTree.AddChild(nil);
  Child0 := fTree.AddChild(Root0);
  fTree.AddChild(Child0);          // makes Child0 a collapsed parent
  fTree.AddChild(Root0);
  Root1 := fTree.AddChild(nil);
  fTree.AddChild(Root1);           // makes Root1 a collapsed parent
  fTree.AddChild(nil);
  fTree.Expanded[Root0] := True;

  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTBandsIssue1091Tests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

function TVTBandsIssue1091Tests.RenderBands(out Checksum: Cardinal;
  out ContentPixels: Integer): Integer;

var
  Bmp: Graphics.TBitmap;
  X, Y, Background, Pixel: Integer;
begin
  Result := 0;
  Checksum := 0;
  ContentPixels := 0;
  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(fTree.ClientWidth, fTree.ClientHeight);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));

    fTree.PaintTree(Bmp.Canvas, Rect(0, 0, Bmp.Width, Bmp.Height), Point(0, 0),
      [poBackground, poColumnColor, poGridLines]);

    // The bottom right corner is below the last node, so it holds the client
    // background. Everything else is content: lines, indents and text.
    // Counting it keeps the sanity check working on widgetsets that ignore
    // the bitmap brush used for the dotted band lines (see below).
    Background := Bmp.Canvas.Pixels[Bmp.Width - 1, Bmp.Height - 1];
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do
      begin
        Pixel := Bmp.Canvas.Pixels[X, Y];
        if Pixel = BandColor then
        begin
          Inc(Result);
          // Position-sensitive checksum so lines moving elsewhere cannot cancel out.
          Checksum := Checksum xor Cardinal(Y * 4096 + X);
        end
        else if Pixel <> Background then
        begin
          Inc(ContentPixels);
          // Full rendering checksum, also used where the band colour cannot
          // identify the lines. Band pixels are excluded so they keep their
          // position-only checksum above.
          Checksum := Checksum xor Cardinal(Y * 4096 + X) xor Cardinal(Pixel);
        end;
      end;
  finally
    Bmp.Free;
  end;
end;

procedure TVTBandsIssue1091Tests.ExplorerThemeStateDoesNotChangeBands;

var
  PlainCount, ThemedCount: Integer;
  PlainContent, ThemedContent: Integer;
  PlainSum, ThemedSum: Cardinal;

begin
  PlainCount := RenderBands(PlainSum, PlainContent);

  // The dotted band lines are painted with a bitmap brush. gtk3 does not
  // implement those (it fills with the brush colour instead), so on that
  // widgetset the band lines cannot be recognised by Colors.GridLineColor.
  // The regression itself is still observable: the two renderings must be
  // pixel-identical.
  if PlainCount = 0 then
    AssertTrue(Format('Sanity: the reference rendering must have content (%d pixels).',
      [PlainContent]), PlainContent > 100)
  else
    AssertTrue('Sanity: band lines expected in the reference rendering.', PlainCount > 0);

  TTreeCracker(fTree).DoStateChange([tsUseExplorerTheme]);
  try
    ThemedCount := RenderBands(ThemedSum, ThemedContent);
  finally
    TTreeCracker(fTree).DoStateChange([], [tsUseExplorerTheme]);
  end;

  if PlainCount > 0 then
  begin
    AssertEquals('Explorer theme state must not change the number of band line pixels (issue #1091).',
      PlainCount, ThemedCount);
    AssertEquals('Explorer theme state must not move band lines (issue #1091).', PlainSum, ThemedSum);
  end
  else
  begin
    AssertEquals(Format('Explorer theme state must not change the rendering ' +
      '(%d content pixels before, %d after; the backend does not colour band lines) (issue #1091).',
      [PlainContent, ThemedContent]), PlainContent, ThemedContent);
    AssertEquals('Explorer theme state must not change the rendering (issue #1091).',
      PlainSum, ThemedSum);
  end;
end;

initialization
  RegisterTest(TVTBandsIssue1091Tests);

end.
