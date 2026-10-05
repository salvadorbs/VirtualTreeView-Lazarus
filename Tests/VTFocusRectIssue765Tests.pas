unit VTFocusRectIssue765Tests;

// Regression test for issue #765 "FocusRect should extend to RowRect when
// toFullRowSelect, independent of tsUseExplorerTheme".
//
// Without the explorer theme the focus rect was drawn around InnerRect (or
// CellRect) only, although the selection covers the whole row. Additionally
// RowRect was only computed when the explorer theme was active.
//
// The test renders offscreen with toPopupMode (so no real window focus is
// needed), an empty cell text and no tree lines or buttons - every non-white
// pixel in the focused row is therefore part of the focus rectangle - and
// asserts that the dotted rectangle spans the whole row.
//
// FPCUnit/LCL port of the upstream DUnitX test.

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
  TVTFocusRectIssue765Tests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
    FocusBandInfo: string;
    FocusTotalInfo: string;
    FocusUnbufCount: Integer;
    FocusSelCount: Integer;
    FocusAfterCount: Integer;
    FocusAfterTotal: Integer;
    FocusAfterResetCount: Integer;
    FocusProbeColors: Integer;
    procedure OnGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType; var CellText: string);
    /// Renders offscreen and returns count and horizontal span of the focus rect pixels
    /// in the focused (second) row.
    function RenderAndMeasure(out MinX, MaxX: Integer): Integer;
    /// Checks whether this backend renders a focus rectangle at all. Some
    /// platform styles (Qt on Windows) swallow the stateless focus frame, so
    /// there is nothing to measure there.
    function BackendRendersFocusRect: Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// Without columns the focus rect must span the whole client width.
    procedure FocusRectSpansRowWithoutColumns;

    /// With columns it must span all columns, not just the focused one.
    procedure FocusRectSpansRowAcrossColumns;
  end;

implementation

uses
  SysUtils,
  Math,
  LCLIntf,
  VirtualTrees.Types;

const
  cNodeHeight = 18;

procedure TVTFocusRectIssue765Tests.SetUp;
var
  I: Integer;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 520, 420);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(0, 0, 420, 320);
  fTree.BorderStyle := bsNone;
  fTree.DefaultNodeHeight := cNodeHeight;
  fTree.OnGetText := OnGetText;
  fTree.TreeOptions.SelectionOptions := fTree.TreeOptions.SelectionOptions + [toFullRowSelect];
  // toPopupMode draws the focus rect without real window focus; lines, buttons and
  // text are switched off so that only the focus rect produces non-white pixels.
  fTree.TreeOptions.PaintOptions := fTree.TreeOptions.PaintOptions + [toPopupMode]
    - [toShowTreeLines, toShowButtons, toShowRoot];
  for I := 1 to 3 do
    fTree.AddChild(nil);
  fTree.FocusedNode := fTree.GetNextSibling(fTree.GetFirst);
  fForm.Show;
  Application.ProcessMessages;

  FocusProbeColors := -1;

  // The explorer theme routes the focus rect through the UxTheme renderer,
  // which does not work on foreign (memory) DCs of some widgetsets - measure
  // the plain DrawFocusRect path on every platform instead.
  fTree.TreeStates := fTree.TreeStates - [tsUseThemes, tsUseExplorerTheme];
end;

procedure TVTFocusRectIssue765Tests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

procedure TVTFocusRectIssue765Tests.OnGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
begin
  CellText := '';
end;

function TVTFocusRectIssue765Tests.RenderAndMeasure(out MinX, MaxX: Integer): Integer;
var
  Bmp: Graphics.TBitmap;
  X, Y, TopRow, BottomRow, Total: Integer;
  RowRect: TRect;

  function CountBand(Bmp: Graphics.TBitmap): Integer;
  var
    X, Y: Integer;
  begin
    Result := 0;
    for Y := TopRow to BottomRow do
      for X := 0 to Bmp.Width - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          Inc(Result);
  end;

  function RenderBand(Unbuffered: Boolean): Integer;

  // Diagnostic renders: one without the per-node bitmap (poUnbuffered) and one
  // with the focused row selected - the selection fill uses the very same
  // per-node bitmap pipeline as the focus rect and is easy to recognize.

  var
    Bmp2: Graphics.TBitmap;
  begin
    Bmp2 := Graphics.TBitmap.Create;
    try
      Bmp2.PixelFormat := pf24bit;
      Bmp2.SetSize(fTree.ClientWidth, 120);
      Bmp2.Canvas.Brush.Color := clWhite;
      Bmp2.Canvas.FillRect(Rect(0, 0, Bmp2.Width, Bmp2.Height));
      if Unbuffered then
        fTree.PaintTree(Bmp2.Canvas, Rect(0, 0, Bmp2.Width, Bmp2.Height), Point(0, 0),
          [poBackground, poColumnColor, poDrawFocusRect, poDrawSelection, poUnbuffered])
      else
        fTree.PaintTree(Bmp2.Canvas, Rect(0, 0, Bmp2.Width, Bmp2.Height), Point(0, 0),
          [poBackground, poColumnColor, poDrawFocusRect, poDrawSelection]);
      Result := CountBand(Bmp2);
    finally
      Bmp2.Free;
    end;
  end;

  function CountWhole(Bmp: Graphics.TBitmap): Integer;
  var
    X, Y: Integer;
  begin
    Result := 0;
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          Inc(Result);
  end;

  // A focus frame drawn directly onto the painted bitmap, with whatever device
  // state PaintTree left behind (after) and with the saved state restored
  // (afterR). Distinguishes "invisible only while PaintTree runs" from
  // "the DC is left in a state that suppresses the frame" (#765).

  function RenderAfter(WithRestore: Boolean): Integer;
  var
    Bmp3: Graphics.TBitmap;
    SavedDC: Integer;
  begin
    Result := -2;
    SavedDC := 0;
    Bmp3 := Graphics.TBitmap.Create;
    try
      Bmp3.PixelFormat := pf24bit;
      Bmp3.SetSize(fTree.ClientWidth, 120);
      Bmp3.Canvas.Brush.Color := clWhite;
      Bmp3.Canvas.FillRect(Rect(0, 0, Bmp3.Width, Bmp3.Height));
      if WithRestore then
        SavedDC := LCLIntf.SaveDC(Bmp3.Canvas.Handle);
      fTree.PaintTree(Bmp3.Canvas, Rect(0, 0, Bmp3.Width, Bmp3.Height), Point(0, 0),
        [poBackground, poColumnColor, poDrawFocusRect, poDrawSelection]);
      if WithRestore then
      begin
        LCLIntf.RestoreDC(Bmp3.Canvas.Handle, SavedDC);
        SavedDC := 0;
      end;
      LCLIntf.DrawFocusRect(Bmp3.Canvas.Handle, Rect(0, TopRow, Bmp3.Width, BottomRow));
      Result := CountBand(Bmp3);
      if not WithRestore then
        FocusAfterTotal := CountWhole(Bmp3);
    finally
      if (SavedDC <> 0) and WithRestore then
        LCLIntf.RestoreDC(Bmp3.Canvas.Handle, SavedDC);
      Bmp3.Free;
    end;
  end;

begin
  Result := 0;
  MinX := MaxInt;
  MaxX := -1;
  FocusUnbufCount := -1;
  FocusSelCount := -1;
  FocusAfterCount := -1;
  FocusAfterTotal := -1;
  FocusAfterResetCount := -1;
  // Re-assert the plain focus path before every render: the environment may
  // reapply theme state in between (WMThemeChanged on Windows).
  fTree.TreeStates := fTree.TreeStates - [tsUseThemes, tsUseExplorerTheme];
  // Measure exactly the focused row, wherever DPI or fonts place it, instead of
  // assuming fixed row offsets.
  if fTree.FocusedNode <> nil then
    RowRect := fTree.GetDisplayRect(fTree.FocusedNode, NoColumn, False)
  else
    RowRect := Rect(0, cNodeHeight, fTree.ClientWidth, 2 * cNodeHeight);
  TopRow := Max(RowRect.Top, 0);
  BottomRow := Min(RowRect.Bottom, 119);
  FocusBandInfo := Format('band %d..%d', [TopRow, BottomRow]);
  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(fTree.ClientWidth, 120);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    fTree.PaintTree(Bmp.Canvas, Rect(0, 0, Bmp.Width, Bmp.Height), Point(0, 0),
      [poBackground, poColumnColor, poDrawFocusRect, poDrawSelection]);

    for Y := TopRow to BottomRow do
      for X := 0 to Bmp.Width - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
        begin
          Inc(Result);
          MinX := Min(MinX, X);
          MaxX := Max(MaxX, X);
        end;

    // Diagnostic: how much did PaintTree paint at all? Separates "wrong band"
    // from "nothing was rendered" in case of a failure.
    Total := 0;
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          Inc(Total);
  finally
    Bmp.Free;
  end;

  // Diagnostic renders (only relevant when the assertion below fires).
  FocusUnbufCount := RenderBand(True);
  if fTree.FocusedNode <> nil then
  begin
    fTree.Selected[fTree.FocusedNode] := True;
    try
      FocusSelCount := RenderBand(False);
    finally
      fTree.Selected[fTree.FocusedNode] := False;
    end;
  end;
  FocusAfterCount := RenderAfter(False);
  FocusAfterResetCount := RenderAfter(True);
  FocusTotalInfo := Format('total=%d unbuf=%d sel=%d after=%d aftertotal=%d afterR=%d probecolors=%d themes=%s explorer=%s',
    [Total, FocusUnbufCount, FocusSelCount, FocusAfterCount, FocusAfterTotal, FocusAfterResetCount, FocusProbeColors,
     BoolToStr(tsUseThemes in fTree.TreeStates, True),
     BoolToStr(tsUseExplorerTheme in fTree.TreeStates, True)]);
end;

function TVTFocusRectIssue765Tests.BackendRendersFocusRect: Boolean;

  function AnyNonWhite(Bmp: Graphics.TBitmap): Boolean;
  var
    X, Y: Integer;
  begin
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          Exit(True);
    Result := False;
  end;

var
  Bmp: Graphics.TBitmap;
  X, Y: Integer;
begin
  Result := False;
  FocusProbeColors := -1;
  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(120, 60);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    LCLIntf.DrawFocusRect(Bmp.Canvas.Handle, Rect(10, 10, 100, 50));
    if not AnyNonWhite(Bmp) then
      Exit;

    // Second check: the exact geometry VT paints - a rect as wide as the tree
    // and as tall as one node (the per-node bitmap of the buffered path). Some
    // platform styles swallow frames of that shape while happily drawing the
    // compact probe frame above; there is then nothing measurable in the row.
    Bmp.SetSize(fTree.ClientWidth, cNodeHeight);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    LCLIntf.DrawFocusRect(Bmp.Canvas.Handle, Rect(0, 0, Bmp.Width, Bmp.Height));
    if not AnyNonWhite(Bmp) then
      Exit;

    // Third check: same frame, but with the exact device colors VT sets right
    // before drawing it (white text on black, for the GDI dotted pen). If the
    // platform style derives the frame from the DC colors instead of using its
    // own, this - and only this - diverges from the plain probes above (#765).
    // Reported only; the verdict stays with the plain probes.
    Bmp.SetSize(120, 60);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    LCLIntf.SetTextColor(Bmp.Canvas.Handle, $FFFFFF);
    LCLIntf.SetBkColor(Bmp.Canvas.Handle, 0);
    LCLIntf.DrawFocusRect(Bmp.Canvas.Handle, Rect(10, 10, 100, 50));
    FocusProbeColors := 0;
    for Y := 0 to Bmp.Height - 1 do
      for X := 0 to Bmp.Width - 1 do
        if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          Inc(FocusProbeColors);

    Result := True;
  finally
    Bmp.Free;
  end;
end;

procedure TVTFocusRectIssue765Tests.FocusRectSpansRowWithoutColumns;
var
  Count, MinX, MaxX: Integer;
begin
  if not BackendRendersFocusRect then
  begin
    WriteLn('NOTE: this backend does not render focus rectangles (the platform style ' +
      'swallows the stateless frame); the RowRect geometry is verified on backends ' +
      'with deterministic focus rendering instead (issue #765).');
    Exit;
  end;
  Count := RenderAndMeasure(MinX, MaxX);
  AssertTrue(Format('Sanity: focus rect pixels expected in the focused row (%s, %d pixels, %s).',
    [FocusBandInfo, Count, FocusTotalInfo]), Count > 0);
  AssertTrue(Format('Focus rect must start at the row''s left edge, starts at %d (issue #765).', [MinX]), MinX <= 1);
  AssertTrue(Format('Focus rect must extend to the row''s right edge (>= %d), ends at %d (issue #765).',
    [fTree.ClientWidth - 2, MaxX]), MaxX >= fTree.ClientWidth - 2);
end;

procedure TVTFocusRectIssue765Tests.FocusRectSpansRowAcrossColumns;
var
  Count, MinX, MaxX, I: Integer;
begin
  for I := 1 to 3 do
    with fTree.Header.Columns.Add do
      Width := 120;
  fTree.Header.MainColumn := 0;
  fTree.FocusedColumn := 0;
  Application.ProcessMessages;

  if not BackendRendersFocusRect then
  begin
    WriteLn('NOTE: this backend does not render focus rectangles (the platform style ' +
      'swallows the stateless frame); the RowRect geometry is verified on backends ' +
      'with deterministic focus rendering instead (issue #765).');
    Exit;
  end;
  Count := RenderAndMeasure(MinX, MaxX);
  AssertTrue(Format('Sanity: focus rect pixels expected in the focused row (%s, %d pixels, %s).',
    [FocusBandInfo, Count, FocusTotalInfo]), Count > 0);
  AssertTrue(Format('Focus rect must start at the row''s left edge, starts at %d (issue #765).', [MinX]), MinX <= 1);
  AssertTrue(Format('Focus rect must span all three columns (>= %d), ends at %d (issue #765).', [3 * 120 - 2, MaxX]), MaxX >= 3 * 120 - 2);
end;

initialization
  RegisterTest(TVTFocusRectIssue765Tests);

end.
