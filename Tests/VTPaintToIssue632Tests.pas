unit VTPaintToIssue632Tests;

// Regression test for issue #632 "Paint into device context via PrintTo or WM_PRINT".
//
// The header lives in the non-client area. Two bugs made rendering into a
// foreign DC useless:
//   1. WMPaint grabbed a window DC via GetDCEx for the header instead of using
//      the DC carried by the message. A copy via TWinControl.PaintTo therefore
//      got everything except the header - which landed on the screen instead.
//   2. WMPrint painted the header regardless of the PRF_ flags, even for a pure
//      PRF_CLIENT request, where it does not belong.
//
// Measured offscreen over the pixels of a strikingly colored header, so the
// result does not depend on window visibility or theme.
//
// FPCUnit/LCL port of the upstream DUnitX test. The LCL has no WM_PRINT message
// with PRF_CLIENT/PRF_NONCLIENT flags (the corresponding handler is compiled
// out of the port, see EnablePrintFunctions), so the two WM_PRINT variants have
// no subject here and are replaced by a geometry check: PaintTo must place the
// header where the header belongs - at the top, spanning the full width with
// the header height.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Types,
  Controls,
  Forms,
  Graphics,
  VirtualTrees;

type
  /// How the header pixels are produced for a measurement.
  TRenderKind = (
    rkPaintTo,      // the real code path under test (TWinControl.PaintTo)
    rkDirectCanvas, // direct header rendering via the TCanvas overload
    rkDirectDC      // direct header rendering via the DC overload - the very
                    // call Paint and WMPrint use for the header (#632)
  );

  TVTPaintToIssue632Tests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
    PaintToCenterPixel: TColor;
    PaintToRectVisible: Boolean;
    PaintToHeaderRect: TRect;
    PaintToBandNonWhite: Integer;
    PaintToBandDom: TColor;
    PaintToBandDomCount: Integer;
    /// Renders into a white bitmap and returns count and bounding box of the header pixels.
    function RenderAndMeasure(Kind: TRenderKind; out Bounds: TRect): Integer;
    /// Checks whether this backend reproduces control content through PaintTo
    /// (some backends screenshot the live widget or draw nothing into foreign
    /// bitmaps; then there is nothing VTV-side to verify).
    function PaintToViable: Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// PaintTo must copy the header along (the actual symptom of the issue).
    procedure PaintToIncludesHeader;

    /// And it must land where the header belongs: at the top, spanning the full
    /// width with the header height - not shifted or clipped.
    procedure PaintToPlacesHeaderAtHeaderGeometry;
  end;

implementation

uses
  SysUtils,
  LCLIntf,
  VirtualTrees.Types,
  VirtualTrees.Header,
  VirtualTrees.BaseTree;

type
  TTreeCracker = class(TBaseVirtualTree); // for DoStateChange

const
  HeaderColor = clRed;

procedure TVTPaintToIssue632Tests.SetUp;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 420, 300);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(10, 10, 380, 200);
  fTree.Header.Options := fTree.Header.Options + [hoVisible];
  fTree.Header.Background := HeaderColor;
  fTree.Header.Style := hsPlates; // unthemed, so the color really comes through
  if fTree.Header.Columns.Count = 0 then
    fTree.Header.Columns.Add.Width := 360;
  fTree.RootNodeCount := 5;
  fForm.Show;
  Application.ProcessMessages;

  // Force the classic (non-themed) paint path regardless of the OS theme state,
  // so the header background color really shows through on every widgetset.
  fTree.TreeStates := fTree.TreeStates - [tsUseThemes, tsUseExplorerTheme];

  // On backends where PaintTo captures the live widget (screenshot semantics)
  // repaint after forcing classic mode, so the capture cannot show a stale
  // themed frame.
  fTree.Invalidate;
  Application.ProcessMessages;
end;

procedure TVTPaintToIssue632Tests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

function TVTPaintToIssue632Tests.PaintToViable: Boolean;
var
  Attempt: Integer;

  function AnyContent: Boolean;
  var
    Bmp: Graphics.TBitmap;
    X, Y, Count: Integer;
  begin
    Count := 0;
    Bmp := Graphics.TBitmap.Create;
    try
      Bmp.PixelFormat := pf24bit;
      Bmp.SetSize(fTree.Width, fTree.Height);
      Bmp.Canvas.Brush.Color := clWhite;
      Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));

      fTree.PaintTo(Bmp.Canvas.Handle, 0, 0);

      for Y := 0 to Bmp.Height - 1 do
        for X := 0 to Bmp.Width - 1 do
          if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          begin
            Inc(Count);
            if Count > 1000 then
              Exit(True);
          end;
      Result := False;
    finally
      Bmp.Free;
    end;
  end;

begin
  // Backends that capture the live widget may need more than one paint cycle
  // before the content shows up; try twice before declaring PaintTo unusable.
  for Attempt := 1 to 2 do
  begin
    if AnyContent then
      Exit(True);
    fTree.Invalidate;
    Application.ProcessMessages;
  end;
  Result := False;
end;

function TVTPaintToIssue632Tests.RenderAndMeasure(Kind: TRenderKind;
  out Bounds: TRect): Integer;
var
  Bmp: Graphics.TBitmap;
  Hist: Classes.TStringList;
  X, Y, I, Run, BestCount: Integer;
  BestDom: TColor;
  Cur: string;
begin
  Result := 0;
  Bounds := Rect(MaxInt, MaxInt, -1, -1);
  PaintToCenterPixel := clFuchsia;
  PaintToBandNonWhite := 0;
  PaintToBandDom := clFuchsia;
  PaintToBandDomCount := 0;
  // Re-assert the classic path immediately before painting: on Windows a
  // WMThemeChanged delivered by a ProcessMessages in between re-enables the
  // theme state and would paint the header with theme colors (issue #632).
  fTree.TreeStates := fTree.TreeStates - [tsUseThemes, tsUseExplorerTheme];
  Bmp := Graphics.TBitmap.Create;
  Hist := Classes.TStringList.Create;
  try
    Hist.Sorted := True;
    Hist.Duplicates := dupAccept;
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(fTree.Width, fTree.Height);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));

    case Kind of
      rkPaintTo:
        fTree.PaintTo(Bmp.Canvas.Handle, 0, 0);
      rkDirectCanvas:
        // Same header, painted directly: used where the backend cannot
        // reproduce control content through PaintTo.
        fTree.Header.Columns.PaintHeader(Bmp.Canvas, Rect(0, 0, Bmp.Width, Bmp.Height), Point(0, 0));
      rkDirectDC:
        // Exactly the call shape of Paint/WMPaint: DC overload, header rect.
        fTree.Header.Columns.PaintHeader(Bmp.Canvas.Handle, TTreeCracker(fTree).HeaderRect, 0);
    end;

    PaintToCenterPixel := Bmp.Canvas.Pixels[Bmp.Width div 2, fTree.Header.Height div 2];
    // Diagnostics: does the same guard that Paint uses accept the header rect on
    // this target DC, and what rect does the tree believe the header occupies?
    // The dominant band color tells an empty band apart from a repainted one.
    PaintToRectVisible := RectVisible(Bmp.Canvas.Handle, TTreeCracker(fTree).HeaderRect);
    PaintToHeaderRect := TTreeCracker(fTree).HeaderRect;
    for Y := 0 to Bmp.Height - 1 do
    begin
      if Y >= fTree.Header.Height then
        Break;
      for X := 0 to Bmp.Width - 1 do
      begin
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          Inc(PaintToBandNonWhite);
        Hist.Add(IntToStr(Bmp.Canvas.Pixels[X, Y]));
      end;
    end;
    BestCount := 0;
    BestDom := clFuchsia;
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
            BestDom := TColor(StrToInt(Cur));
          end;
          Cur := Hist[I];
          Run := 1;
        end;
      if Run > BestCount then
      begin
        BestCount := Run;
        BestDom := TColor(StrToInt(Cur));
      end;
    end;
    PaintToBandDom := BestDom;
    PaintToBandDomCount := BestCount;
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do
        if Bmp.Canvas.Pixels[X, Y] = HeaderColor then
        begin
          Inc(Result);
          if X < Bounds.Left then Bounds.Left := X;
          if Y < Bounds.Top then Bounds.Top := Y;
          if X > Bounds.Right then Bounds.Right := X;
          if Y > Bounds.Bottom then Bounds.Bottom := Y;
        end;
  finally
    Hist.Free;
    Bmp.Free;
  end;
end;

procedure TVTPaintToIssue632Tests.PaintToIncludesHeader;
var
  Bounds: TRect;
  HeaderPixels: Integer;
begin
  HeaderPixels := RenderAndMeasure(rkPaintTo, Bounds);
  if (HeaderPixels <= 100) and not PaintToViable then
  begin
    WriteLn('NOTE: this backend does not reproduce control content through PaintTo; ' +
      'nothing VTV-side to verify here (issue #632).');
    Exit;
  end;
  if HeaderPixels <= 100 then
  begin
    // Backends that capture the live widget may still hold a frame from before
    // the classic-mode switch; give the control one more paint cycle.
    fTree.Invalidate;
    Application.ProcessMessages;
    HeaderPixels := RenderAndMeasure(rkPaintTo, Bounds);
  end;
  AssertTrue(Format('PaintTo did not copy the header along (%d header pixels, band non-white %d, band dom %s (%d of band), center pixel %s, ' +
    'headerrect=%d,%d..%d,%d height=%d rectvisible=%s themes=%s explorer=%s).',
    [HeaderPixels, PaintToBandNonWhite, ColorToString(PaintToBandDom), PaintToBandDomCount,
     ColorToString(PaintToCenterPixel),
     PaintToHeaderRect.Left, PaintToHeaderRect.Top, PaintToHeaderRect.Right, PaintToHeaderRect.Bottom,
     fTree.Header.Height, BoolToStr(PaintToRectVisible, True),
     BoolToStr(tsUseThemes in fTree.TreeStates, True),
     BoolToStr(tsUseExplorerTheme in fTree.TreeStates, True)]), HeaderPixels > 100);
end;

procedure TVTPaintToIssue632Tests.PaintToPlacesHeaderAtHeaderGeometry;
var
  Bounds, DcBounds, DcBounds2: TRect;
  DcPixels, DcPixels2: Integer;
begin
  // The placement logic under test is backend-independent, so it is always
  // verified through a direct header rendering (deterministic on every
  // widgetset); the PaintTo routing itself is covered by PaintToIncludesHeader
  // where the backend supports it.
  AssertTrue('Sanity: header pixels expected.', RenderAndMeasure(rkDirectCanvas, Bounds) > 0);
  AssertTrue(Format('Header must start at the left edge, starts at %d (issue #632).', [Bounds.Left]),
    Bounds.Left <= 1);
  AssertTrue(Format('Header must start at the top edge, starts at %d (issue #632).', [Bounds.Top]),
    Bounds.Top <= 1);
  AssertTrue(Format('Header must span the full width, ends at %d of %d (issue #632).',
    [Bounds.Right, fTree.Width - 1]), Bounds.Right >= fTree.Width - 2);
  AssertTrue(Format('Header must cover the header height, ends at %d of %d (issue #632).',
    [Bounds.Bottom, fTree.Header.Height - 1]), Bounds.Bottom >= fTree.Header.Height - 2);

  // Paint and WMPaint render the header through the DC overload of PaintHeader
  // (header rect into a foreign DC). If that overload does not produce the
  // header pixels by itself, a PaintTo copy can never contain it (#632).
  DcPixels := RenderAndMeasure(rkDirectDC, DcBounds);
  AssertTrue(Format('The DC overload of PaintHeader (the call shape Paint uses) must paint the header ' +
    '(%d header pixels, band non-white %d, band dom %s (%d of band), center pixel %s, rectvisible=%s) (issue #632).',
    [DcPixels, PaintToBandNonWhite, ColorToString(PaintToBandDom), PaintToBandDomCount,
     ColorToString(PaintToCenterPixel),
     BoolToStr(PaintToRectVisible, True)]), DcPixels > 100);

  // The overload paints through a shared back buffer: render twice, so a state
  // leak from the first pass (brush, clip, palette) cannot hide behind a fresh
  // buffer - the PaintTo path always reuses it (#632).
  DcPixels2 := RenderAndMeasure(rkDirectDC, DcBounds2);
  AssertTrue(Format('The DC overload of PaintHeader must paint the header on reuse too ' +
    '(%d header pixels after %d, band dom %s (%d of band), center pixel %s) (issue #632).',
    [DcPixels2, DcPixels, ColorToString(PaintToBandDom), PaintToBandDomCount,
     ColorToString(PaintToCenterPixel)]), DcPixels2 > 100);
end;

initialization
  RegisterTest(TVTPaintToIssue632Tests);

end.
