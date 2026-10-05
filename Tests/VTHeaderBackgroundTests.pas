unit VTHeaderBackgroundTests;

// Regression test for the classic (non-themed) header paint path ignoring Header.Background
// inside the column cells.
//
// DrawBackground fills the area right of the last column with Header.Background, but
// PaintColumnHeader painted the cells themselves via DrawEdge with BF_MIDDLE, which always
// fills with clBtnFace - so a custom Header.Background only ever showed up in the filler
// area. The fix fills the cell interior explicitly with Header.Background before drawing
// the edges, which is pixel-identical for the default clBtnFace.

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
  TVTHeaderBackgroundTests = class(TTestCase)
  strict private

    fForm: TForm;

    fTree: TVirtualStringTree;

    /// Renders the header offscreen and counts the pixels of the given color in the
    /// horizontal range [FromX, ToX) of the header band (edges excluded).
    /// NearCount returns pixels within a small tolerance, CenterPixel the color
    /// found in the middle of the band, Bounds the area covered by the exact
    /// matches - all for diagnostics on backends that reproduce fills differently.
    /// FillSample receives an interior pixel of the scanned range: the color the
    /// header fill really produced on this backend (same render, same canvas).
    /// ResolvedColor is what the requested color becomes through this backend's
    /// canvas; DominantColor/DominantCount describe the most frequent color in
    /// the scanned range (what the band actually looks like). GroundColor is
    /// the neutral ground the header is rendered on (must clash with nothing
    /// under test; varying it tells translucent fills from opaque ones).
    function CountHeaderPixels(Color: TColor; FromX, ToX: Integer; GroundColor: TColor;
      out NearCount: Integer;
      out CenterPixel: TColor; out Bounds: TRect; out FillSample: TColor;
      out ResolvedColor: TColor; out DominantColor: TColor; out DominantCount: Integer): Integer;

    function BandArea(FromX, ToX: Integer): Integer;

    /// What the given color actually paints as on this backend: system colors
    /// (e.g. clBtnFace) are resolved by the canvas palette (Qt: QPalette),
    /// which may differ from ColorToRGB.
    function ResolveLikeCanvas(Color: TColor): TColor;

  public

  protected



    procedure SetUp; override;



    procedure TearDown; override;





    /// In classic mode the column cells must be filled with Header.Background.

  published

    procedure ClassicCellsUseHeaderBackground;

    /// With the default Header.Background the classic cells keep the clBtnFace look.

    procedure DefaultRenderingKeepsButtonFace;
  end;

implementation

uses
  SysUtils,
  VirtualTrees.Types,
  VirtualTrees.BaseTree;

type
  TTreeCracker = class(TBaseVirtualTree); // for DoStateChange

const
  BackColor = clRed;
  ColumnWidth = 120;
  ColumnCount = 2;

procedure TVTHeaderBackgroundTests.SetUp;
var
  I: Integer;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 420, 300);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(10, 10, 380, 240);
  for I := 1 to ColumnCount do
    fTree.Header.Columns.Add.Width := ColumnWidth; // no captions: no text pixels in the band
  fTree.Header.Options := fTree.Header.Options + [hoVisible];
  fForm.Show;
  Application.ProcessMessages;

  // Force the classic (non-themed) paint path regardless of the OS theme state.
  TTreeCracker(fTree).DoStateChange([], [tsUseThemes]);
end;

procedure TVTHeaderBackgroundTests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

function TVTHeaderBackgroundTests.ResolveLikeCanvas(Color: TColor): TColor;
var
  Bmp: Graphics.TBitmap;
begin
  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(4, 4);
    Bmp.Canvas.Brush.Color := Color;
    Bmp.Canvas.FillRect(Rect(0, 0, 4, 4));
    Result := Bmp.Canvas.Pixels[1, 1];
  finally
    Bmp.Free;
  end;
end;

function TVTHeaderBackgroundTests.CountHeaderPixels(Color: TColor; FromX, ToX: Integer; GroundColor: TColor;
  out NearCount: Integer; out CenterPixel: TColor; out Bounds: TRect; out FillSample: TColor;
  out ResolvedColor: TColor; out DominantColor: TColor; out DominantCount: Integer): Integer;
var
  Bmp: Graphics.TBitmap;
  Hist: Classes.TStringList;
  X, Y, I, Run, BestCount: Integer;
  Pixel: TColor;
  Cur: string;
begin
  Result := 0;
  NearCount := 0;
  CenterPixel := GroundColor;
  Bounds := Rect(MaxInt, MaxInt, -1, -1);
  FillSample := GroundColor;
  ResolvedColor := ResolveLikeCanvas(Color); // what the header fill will really paint
  DominantColor := GroundColor;
  DominantCount := 0;
  Color := ResolvedColor;
  // Re-assert classic mode before every render: theme state may be reapplied
  // by the environment between renders.
  TTreeCracker(fTree).DoStateChange([], [tsUseThemes]);
  Bmp := Graphics.TBitmap.Create;
  Hist := Classes.TStringList.Create;
  try
    Hist.Sorted := True;
    Hist.Duplicates := dupAccept;
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(fTree.ClientWidth, fTree.Header.Height);
    Bmp.Canvas.Brush.Color := GroundColor; // neutral ground, clashes with nothing under test
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));

    fTree.Header.Columns.PaintHeader(Bmp.Canvas, Rect(0, 0, Bmp.Width, Bmp.Height), Point(0, 0));

    CenterPixel := Bmp.Canvas.Pixels[(FromX + ToX) div 2, Bmp.Height div 2];
    // Interior sample of this range, a quarter in: bevels and column edges are a
    // couple of pixels wide, so the edge-adjacent pixels can be blends of the
    // fill with the ground while the bulk of the fill sits deeper inside.
    FillSample := Bmp.Canvas.Pixels[FromX + (ToX - FromX) div 4, Bmp.Height div 2];
    for Y := 2 to Bmp.Height - 3 do // skip the top/bottom bevel rows
      for X := FromX to ToX - 1 do
      begin
        Pixel := Bmp.Canvas.Pixels[X, Y];
        Hist.Add(IntToStr(Pixel));
        if Pixel = ColorToRGB(Color) then
        begin
          Inc(Result);
          if X < Bounds.Left then Bounds.Left := X;
          if Y < Bounds.Top then Bounds.Top := Y;
          if X > Bounds.Right then Bounds.Right := X;
          if Y > Bounds.Bottom then Bounds.Bottom := Y;
        end
        else if (Abs(Red(Pixel) - Red(ColorToRGB(Color))) <= 8)
          and (Abs(Green(Pixel) - Green(ColorToRGB(Color))) <= 8)
          and (Abs(Blue(Pixel) - Blue(ColorToRGB(Color))) <= 8) then
          Inc(NearCount);
      end;
    // Most frequent color in the scanned range: what the band actually is.
    BestCount := 0;
    DominantColor := GroundColor;
    if Hist.Count > 0 then
    begin
      Cur := Hist[0];
      Run := 1;
      for I := 1 to Hist.Count - 1 do
        if Hist[I] = Cur then
          Inc(Run)
        else
        begin
          if Run > BestCount then
          begin
            BestCount := Run;
            DominantColor := TColor(StrToInt(Cur));
          end;
          Cur := Hist[I];
          Run := 1;
        end;
      if Run > BestCount then
      begin
        BestCount := Run;
        DominantColor := TColor(StrToInt(Cur));
      end;
    end;
    DominantCount := BestCount;
  finally
    Hist.Free;
    Bmp.Free;
  end;
end;

function TVTHeaderBackgroundTests.BandArea(FromX, ToX: Integer): Integer;
begin
  Result := (fTree.Header.Height - 4) * (ToX - FromX);
end;

procedure TVTHeaderBackgroundTests.ClassicCellsUseHeaderBackground;
var
  CellPixels, FillerPixels, NearPixels: Integer;
  CenterPixel: TColor;
  Bounds: TRect;
  FillerSample, CellSample: TColor;
  FillerResolved, CellResolved, FillerDom, CellDom: TColor;
  FillerDomCount, CellDomCount: Integer;
begin
  fTree.Header.Background := BackColor;

  // Sanity: the filler area right of the last column already honored Header.Background.
  FillerPixels := CountHeaderPixels(BackColor, ColumnCount * ColumnWidth + 2, fTree.ClientWidth - 2, clFuchsia, NearPixels, CenterPixel, Bounds, FillerSample,
    FillerResolved, FillerDom, FillerDomCount);
  AssertTrue('Sanity: the filler area right of the columns must use Header.Background.', FillerPixels > BandArea(ColumnCount * ColumnWidth + 2, fTree.ClientWidth - 2) div 2);

  // The actual regression: the cells themselves must be filled with it too.
  CellPixels := CountHeaderPixels(BackColor, 2, ColumnCount * ColumnWidth - 2, clFuchsia, NearPixels, CenterPixel, Bounds, CellSample,
    CellResolved, CellDom, CellDomCount);
  AssertTrue(Format('Classic column cells must use Header.Background (%d of %d band pixels found, %d near matches, center pixel %s, filler sample %s, cell sample %s, match bounds %d,%d..%d,%d, themes=%s vclstyle=%s).',
    [CellPixels, BandArea(2, ColumnCount * ColumnWidth - 2), NearPixels, ColorToString(CenterPixel),
     ColorToString(FillerSample), ColorToString(CellSample),
     Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom,
     BoolToStr(tsUseThemes in fTree.TreeStates, True),
     BoolToStr(TTreeCracker(fTree).VclStyleEnabled, True)]), CellPixels > (BandArea(2, ColumnCount * ColumnWidth - 2) * 6) div 10);
end;

procedure TVTHeaderBackgroundTests.DefaultRenderingKeepsButtonFace;
var
  CellPixels, FillerPixels, NearPixels, FillerNear: Integer;
  CenterPixel, FillerCenter: TColor;
  Bounds, FillerBounds: TRect;
  FillerSample, CellSample: TColor;
  FillerResolved, CellResolved, FillerDom, CellDom: TColor;
  FillerDomCount, CellDomCount: Integer;
begin
  // Header.Background defaults to clBtnFace - the classic look must not change.
  // System colors are resolved by the canvas palette (Qt: QPalette), which can
  // differ from ColorToRGB, so the filler area of the same header - which has
  // always honored Header.Background - is the reference for what this backend
  // really paints clBtnFace as. Rendered on a lime ground: if the fills are
  // translucent, the samples go greenish; if they are opaque, they stay put.
  FillerPixels := CountHeaderPixels(clBtnFace, ColumnCount * ColumnWidth + 2, fTree.ClientWidth - 2, clLime,
    FillerNear, FillerCenter, FillerBounds, FillerSample,
    FillerResolved, FillerDom, FillerDomCount);
  AssertTrue(Format('Sanity: the filler area right of the columns must be painted (sample %s).',
    [ColorToString(FillerSample)]), FillerSample <> clLime);

  CellPixels := CountHeaderPixels(FillerSample, 2, ColumnCount * ColumnWidth - 2, clLime, NearPixels, CenterPixel, Bounds, CellSample,
    CellResolved, CellDom, CellDomCount);
  AssertTrue(Format('Default classic cells must keep the clBtnFace fill (%d of %d band pixels found, %d near matches, resolved %s filler sample %s filler dom %s(%d of band) cell sample %s cell dom %s(%d of band) center pixel %s, match bounds %d,%d..%d,%d, themes=%s vclstyle=%s).',
    [CellPixels, BandArea(2, ColumnCount * ColumnWidth - 2), NearPixels,
     ColorToString(CellResolved), ColorToString(FillerSample),
     ColorToString(FillerDom), FillerDomCount,
     ColorToString(CellSample), ColorToString(CellDom), CellDomCount,
     ColorToString(CenterPixel),
     Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom,
     BoolToStr(tsUseThemes in fTree.TreeStates, True),
     BoolToStr(TTreeCracker(fTree).VclStyleEnabled, True)]), CellPixels > (BandArea(2, ColumnCount * ColumnWidth - 2) * 6) div 10);
end;

initialization
  RegisterTest(TVTHeaderBackgroundTests);

end.
