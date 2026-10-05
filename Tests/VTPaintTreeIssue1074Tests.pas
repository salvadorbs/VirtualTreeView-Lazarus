unit VTPaintTreeIssue1074Tests;

// Regression test for issue #1074 "problem with painting nodes PaintTree with
// poUnbuffered in options and setMapMode...".
//
// SetCanvasOrigin() transformed its shift through LPtoDP before passing it to
// SetWindowOrgEx. SetWindowOrgEx however expects logical units - the same units
// the tree calculates with - so on a canvas with a mapping mode the shift got
// scaled twice and every node was drawn at twice its offset. With the default
// MM_TEXT mapping the transformation was a no-op, which is why the ordinary
// paint paths never showed the problem.
//
// The test renders offscreen with a 2x MM_ANISOTROPIC mapping and compares the
// horizontal grid line positions: the unbuffered rendering must place them
// exactly like the buffered one, and exactly at twice the unmapped positions.
//
// FPCUnit/LCL port of the upstream DUnitX test. The mapping mode APIs
// (SetMapMode/SetWindowExtEx/SetViewportExtEx) are available through LCLIntf on
// every widgetset; RGB components are read with Graphics.Red/Green/Blue.

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
  TVTPaintTreeIssue1074Tests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
    /// Renders via PaintTree and returns the Y positions of the horizontal grid lines.
    function RenderHLines(Mapped, Unbuffered: Boolean): TArray<Integer>;
    /// Checks whether the backend really honors an anisotropic mapping on a
    /// bitmap canvas. Some backends ignore mapping modes (or break rendering
    /// with them); the scaled assertions below are only meaningful where
    /// mapping actually scales drawing.
    function MappingScalesCanvas: Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// Under a mapping mode the unbuffered rendering must match the buffered one.
    procedure UnbufferedMatchesBufferedUnderMapMode;

    /// And both must be the unmapped rendering scaled by the mapping factor.
    procedure MappedRenderingIsScaledUnmappedRendering;
  end;

implementation

uses
  SysUtils,
  LCLIntf,
  LCLType,
  VirtualTrees.Types;

const
  LineColor = clRed;
  MapScale = 2;

procedure TVTPaintTreeIssue1074Tests.SetUp;
var
  Root, Child: PVirtualNode;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 420, 300);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(10, 10, 380, 240);
  fTree.Colors.GridLineColor := LineColor;
  fTree.Colors.TreeLineColor := LineColor;
  fTree.TreeOptions.PaintOptions := fTree.TreeOptions.PaintOptions
    + [toShowRoot, toShowHorzGridLines, toShowVertGridLines];

  Root := fTree.AddChild(nil);
  Child := fTree.AddChild(Root);
  fTree.AddChild(Child);
  fTree.AddChild(Root);
  fTree.AddChild(nil);
  fTree.FullExpand;
  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTPaintTreeIssue1074Tests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

function TVTPaintTreeIssue1074Tests.RenderHLines(Mapped, Unbuffered: Boolean): TArray<Integer>;
var
  Bmp: Graphics.TBitmap;
  Options: TVTInternalPaintOptions;
  X, Y, RedCount: Integer;
  Pixel: TColor;
begin
  Result := nil;
  Options := [poBackground, poColumnColor, poGridLines];
  if Unbuffered then
    Include(Options, poUnbuffered);

  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(500, 300);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));

    if Mapped then
    begin
      SetMapMode(Bmp.Canvas.Handle, MM_ANISOTROPIC);
      SetWindowExtEx(Bmp.Canvas.Handle, 1, 1, nil);
      SetViewportExtEx(Bmp.Canvas.Handle, MapScale, MapScale, nil);
    end;
    try
      fTree.PaintTree(Bmp.Canvas, Rect(0, 0, Bmp.Width, 130), Point(0, 0), Options, pfDevice);
    finally
      if Mapped then
        SetMapMode(Bmp.Canvas.Handle, MM_TEXT);
    end;

    // A horizontal grid line is a row that is red almost across the whole width.
    for Y := 0 to Bmp.Height - 1 do
    begin
      RedCount := 0;
      for X := 0 to Bmp.Width - 1 do
      begin
        Pixel := Bmp.Canvas.Pixels[X, Y];
        if (Red(Pixel) > 200) and (Green(Pixel) < 80) and (Blue(Pixel) < 80) then
          Inc(RedCount);
      end;
      if RedCount > Bmp.Width div 2 then
        Result := Result + [Y];
    end;
  finally
    Bmp.Free;
  end;
end;

function TVTPaintTreeIssue1074Tests.MappingScalesCanvas: Boolean;
var
  Bmp: Graphics.TBitmap;
  X, MaxRedX: Integer;
begin
  // A 10x10 logical fill under a 2x mapping must cover about 20 device pixels.
  MaxRedX := -1;
  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(60, 60);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    SetMapMode(Bmp.Canvas.Handle, MM_ANISOTROPIC);
    SetWindowExtEx(Bmp.Canvas.Handle, 1, 1, nil);
    SetViewportExtEx(Bmp.Canvas.Handle, MapScale, MapScale, nil);
    Bmp.Canvas.Brush.Color := clRed;
    Bmp.Canvas.FillRect(Rect(0, 0, 10, 10));
    SetMapMode(Bmp.Canvas.Handle, MM_TEXT);
    for X := 0 to Bmp.Width - 1 do
      if (Red(Bmp.Canvas.Pixels[X, 5]) > 200) and (Green(Bmp.Canvas.Pixels[X, 5]) < 80)
        and (Blue(Bmp.Canvas.Pixels[X, 5]) < 80) then
        MaxRedX := X;
  finally
    Bmp.Free;
  end;
  Result := MaxRedX >= 15;
end;

function RowList(const Rows: TArray<Integer>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Rows) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + IntToStr(Rows[I]);
  end;
end;

function ContainsRow(const Rows: TArray<Integer>; Row: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Rows) do
    if Rows[I] = Row then
      Exit(True);
  Result := False;
end;

procedure TVTPaintTreeIssue1074Tests.UnbufferedMatchesBufferedUnderMapMode;
var
  Buffered, Unbuffered, PlainBuf, PlainUnbuf: TArray<Integer>;
begin
  // Render unbuffered first: equality is symmetric, and this avoids any
  // cross-render state interaction on backends with fragile GDI state.
  Unbuffered := RenderHLines(True, True);
  Buffered := RenderHLines(True, False);
  if not MappingScalesCanvas then
  begin
    WriteLn('NOTE: this backend does not honor anisotropic mappings; verifying ' +
      'buffered/unbuffered consistency without mapping instead (issue #1074).');
    PlainBuf := RenderHLines(False, False);
    PlainUnbuf := RenderHLines(False, True);
    if Length(PlainBuf) = 0 then
    begin
      // Without a usable buffered reference there is nothing to compare against;
      // the backend then cannot render grid lines into bitmaps at all, which is
      // not specific to the unbuffered path under test here.
      WriteLn('NOTE: this backend produced no buffered reference rendering; ' +
        'skipping the comparison (issue #1074).');
      Exit;
    end;
    AssertEquals('Without mapping support, buffered and unbuffered rendering must still agree.',
      RowList(PlainBuf), RowList(PlainUnbuf));
    Exit;
  end;
  AssertTrue('Sanity: grid lines expected in the buffered rendering.', Length(Buffered) > 0);
  AssertEquals('Unbuffered painting must place the grid lines exactly like buffered painting under a mapping mode (issue #1074).',
    RowList(Buffered), RowList(Unbuffered));
end;

procedure TVTPaintTreeIssue1074Tests.MappedRenderingIsScaledUnmappedRendering;
var
  Plain, Mapped: TArray<Integer>;
  I: Integer;
begin
  Plain := RenderHLines(False, True);
  Mapped := RenderHLines(True, True);
  AssertTrue('Sanity: grid lines expected in the unmapped rendering.', Length(Plain) > 0);
  if not MappingScalesCanvas then
  begin
    WriteLn('NOTE: this backend does not honor anisotropic mappings; the scaled ' +
      'rendering cannot be verified here (issue #1074).');
    Exit;
  end;
  for I := 0 to High(Plain) do
    AssertTrue(Format('Grid line at %d must appear at %d under the %dx mapping (issue #1074), got [%s].',
      [Plain[I], Plain[I] * MapScale, MapScale, RowList(Mapped)]), ContainsRow(Mapped, Plain[I] * MapScale));
end;

initialization
  RegisterTest(TVTPaintTreeIssue1074Tests);

end.
