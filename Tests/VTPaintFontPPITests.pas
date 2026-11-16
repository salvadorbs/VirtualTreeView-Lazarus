unit VTPaintFontPPITests;

// Regression test for issue #42702 "Fix per-monitor DPI scaling of node text".
//
// PaintTree draws each node into a small buffer bitmap (NodeBitmap) before it
// is blitted to the target canvas. TBitmap.Canvas.Font.PixelsPerInch starts at
// the screen PPI, and TFont.Assign converts the source font to the target
// resolution when the two differ. On a monitor whose scaling differs from the
// screen PPI the node text was therefore prepared at the wrong resolution.
//
// The fix syncs the buffer canvas PPI with the target canvas before the node
// font is assigned. The test paints a node into a bitmap whose font uses a PPI
// different from the screen and inspects the canvas handed to OnPaintText: it
// must carry the target PPI and the unscaled font height.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Controls,
  Forms,
  Graphics,
  VirtualTrees,
  VirtualTrees.Types;

type
  TVTPaintFontPPITests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
    fPaintCount: Integer;
    fPaintedPPI: Integer;
    fPaintedFontHeight: Integer;
    procedure TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure TreePaintText(Sender: TBaseVirtualTree; const TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType);
    /// Paints the tree offscreen with the tree font and the target canvas at APPI.
    procedure RenderAtPPI(APPI: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// A monitor at a different PPI must get node text prepared at that PPI.
    procedure NodeTextUsesTargetCanvasPPI;

    /// At the screen PPI nothing must be scaled up.
    procedure NodeTextUsesScreenPPIWithoutScaling;
  end;

implementation

uses
  SysUtils,
  Math,
  LCLIntf,
  Types;

const
  // Font height used at 96 DPI by the tests.
  BaseFontHeight = -12;

procedure TVTPaintFontPPITests.SetUp;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 420, 300);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(0, 0, 380, 240);
  fTree.ParentFont := False;
  fTree.OnGetText := TreeGetText;
  fTree.OnPaintText := TreePaintText;
  fTree.RootNodeCount := 2;
  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTPaintFontPPITests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

procedure TVTPaintFontPPITests.TreeGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
begin
  CellText := 'Wg';
end;

procedure TVTPaintFontPPITests.TreePaintText(Sender: TBaseVirtualTree;
  const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType);
begin
  Inc(fPaintCount);
  fPaintedPPI := TargetCanvas.Font.PixelsPerInch;
  fPaintedFontHeight := TargetCanvas.Font.Height;
end;

procedure TVTPaintFontPPITests.RenderAtPPI(APPI: Integer);
var
  Bmp: Graphics.TBitmap;
begin
  // The tree lives on the simulated monitor: its font carries the monitor PPI.
  fTree.Font.PixelsPerInch := APPI;
  fTree.Font.Height := Round(BaseFontHeight * APPI / 96);
  Application.ProcessMessages;

  fPaintCount := 0;
  fPaintedPPI := 0;
  fPaintedFontHeight := 0;

  Bmp := Graphics.TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(fTree.ClientWidth, Max(fTree.ClientHeight, fTree.DefaultNodeHeight + 40));
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    // The live window canvas carries the control font; emulate it on the target.
    Bmp.Canvas.Font.Assign(fTree.Font);
    Bmp.Canvas.Font.PixelsPerInch := APPI;

    fTree.PaintTree(Bmp.Canvas, Rect(0, 0, Bmp.Width, Bmp.Height), Point(0, 0),
      [poBackground, poColumnColor], pfDevice);
  finally
    Bmp.Free;
  end;
end;

procedure TVTPaintFontPPITests.NodeTextUsesTargetCanvasPPI;
var
  MonitorPPI: Integer;
begin
  // Pick a monitor PPI that differs from the screen, so TFont.Assign would
  // really have to convert the font if the buffer kept the screen resolution.
  if Screen.PixelsPerInch = 168 then
    MonitorPPI := 96
  else
    MonitorPPI := 168;

  RenderAtPPI(MonitorPPI);

  AssertTrue('OnPaintText was not called: the node text was not painted.', fPaintCount > 0);
  AssertEquals('The buffer canvas must use the PPI of the target canvas (issue #42702).',
    MonitorPPI, fPaintedPPI);
  AssertEquals('The node font must keep its height at the target PPI (issue #42702).',
    Round(BaseFontHeight * MonitorPPI / 96), fPaintedFontHeight);
end;

procedure TVTPaintFontPPITests.NodeTextUsesScreenPPIWithoutScaling;
begin
  RenderAtPPI(96);

  AssertTrue('OnPaintText was not called: the node text was not painted.', fPaintCount > 0);
  AssertEquals('At 96 DPI the buffer canvas keeps the screen PPI.',
    96, fPaintedPPI);
  AssertEquals('At 96 DPI the node font keeps its design height.',
    BaseFontHeight, fPaintedFontHeight);
end;

initialization
  RegisterTest(TVTPaintFontPPITests);

end.
