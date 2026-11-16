unit VTDpiScalingTests;

// Regression test for the upstream work item #42716 "VirtualTreeView: node
// heights are not rescaled on per-monitor DPI change".
//
// On a per-monitor DPI change the LCL calls AutoAdjustLayout(lapAutoAdjustForDPI),
// which scales the tree's Font.PixelsPerInch through ScaleFontsPPI() and then
// calls DoAutoAdjustLayout(). The font change triggers AutoScale(), which used
// to rescale DefaultNodeHeight once more, while the existing per-node heights
// were never scaled at all. The result was an inconsistent tree:
//
//   * DefaultNodeHeight grew twice (once from AutoScale, once from the DPI ratio),
//   * existing nodes kept a height that did not match the new font DPI,
//   * scaling back to the old DPI could not restore the original heights.
//
// The fix lets AutoScale skip while ScaleFontsPPI runs and makes
// DoAutoAdjustLayout scale both DefaultNodeHeight and every existing node height
// by the DPI ratio. This test simulates a 96 -> 168 -> 96 PPI transition.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Controls,
  Forms,
  Graphics,
  VirtualTrees;

type
  TVTDpiScalingTests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
    procedure AssertAllNodesHaveHeight(AExpected: Integer; const AContext: string);
    function ScaledHeight(AHeight, AFromPPI, AToPPI: Integer): Integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// Moving to a higher DPI must scale DefaultNodeHeight and all existing
    /// node heights by the same ratio, and the result must fit the scaled text.
    procedure DpiChangeScalesDefaultAndNodeHeights;

    /// Moving back to the original DPI must restore the original row heights.
    procedure DpiChangeBackRestoresNodeHeights;

    /// The header has its own TFont which is not a control property: it must be
    /// scaled too, otherwise the header text keeps its 96 DPI size.
    procedure DpiChangeScalesHeaderFont;

    /// A header inheriting the tree font is scaled by the LCL through the tree:
    /// it must not be scaled a second time.
    procedure DpiChangeScalesInheritedHeaderFontOnce;
  end;

implementation

uses
  SysUtils;

procedure TVTDpiScalingTests.SetUp;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 320, 200);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.Align := alClient;
  // Give the tree its own font so that the font PPI is really scaled by
  // AutoAdjustLayout and not inherited from the form.
  fTree.ParentFont := False;
  fTree.RootNodeCount := 3;
  fForm.Show;
  Application.ProcessMessages;

  // Make the starting point deterministic regardless of the screen DPI.
  fTree.Font.PixelsPerInch := 96;
  fTree.Font.Height := -12;

  // The header has its own font; give it a known starting point too.
  fTree.Header.ParentFont := False;
  fTree.Header.Font.PixelsPerInch := 96;
  fTree.Header.Font.Height := -12;
  Application.ProcessMessages;
end;

procedure TVTDpiScalingTests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

function TVTDpiScalingTests.ScaledHeight(AHeight, AFromPPI, AToPPI: Integer): Integer;
begin
  Result := Round(AHeight * AToPPI / AFromPPI);
end;

procedure TVTDpiScalingTests.AssertAllNodesHaveHeight(AExpected: Integer;
  const AContext: string);
var
  Node: PVirtualNode;
  Count: Integer;
begin
  Count := 0;
  Node := fTree.GetFirstInitialized;
  while Assigned(Node) do
  begin
    AssertEquals(Format('%s: node %d height.', [AContext, Node.Index]),
      AExpected, Integer(fTree.NodeHeight[Node]));
    Inc(Count);
    Node := fTree.GetNextInitialized(Node);
  end;
  AssertEquals(AContext + ': number of initialized nodes.', 3, Count);
end;

procedure TVTDpiScalingTests.DpiChangeScalesDefaultAndNodeHeights;
var
  StartHeight, ExpectedHeight: Integer;
begin
  StartHeight := fTree.DefaultNodeHeight;
  AssertTrue('Sanity: the test needs a non-empty starting row height.', StartHeight > 0);
  AssertAllNodesHaveHeight(StartHeight, 'At 96 PPI');

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, 96, 168, 0, 0);
  Application.ProcessMessages;

  ExpectedHeight := ScaledHeight(StartHeight, 96, 168);

  AssertEquals('DefaultNodeHeight must be scaled exactly once by the DPI ratio.',
    ExpectedHeight, Integer(fTree.DefaultNodeHeight));
  AssertAllNodesHaveHeight(ExpectedHeight, 'After 96 -> 168 PPI');

  // The whole point of the fix: the scaled text must now fit into the rows.
  fTree.Canvas.Font.Assign(fTree.Font);
  AssertTrue(Format('Scaled text (%d px + %d px margin) must fit into DefaultNodeHeight %d.',
    [fTree.Canvas.TextHeight('Tg'), fTree.TextMargin, fTree.DefaultNodeHeight]),
    fTree.DefaultNodeHeight >= fTree.Canvas.TextHeight('Tg') + fTree.TextMargin);
end;

procedure TVTDpiScalingTests.DpiChangeBackRestoresNodeHeights;
var
  StartHeight: Integer;
begin
  StartHeight := fTree.DefaultNodeHeight;

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, 96, 168, 0, 0);
  Application.ProcessMessages;
  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, 168, 96, 0, 0);
  Application.ProcessMessages;

  AssertEquals('Moving back to 96 PPI must restore DefaultNodeHeight.',
    StartHeight, Integer(fTree.DefaultNodeHeight));
  AssertAllNodesHaveHeight(StartHeight, 'After 96 -> 168 -> 96 PPI');
end;

procedure TVTDpiScalingTests.DpiChangeScalesHeaderFont;
var
  StartHeight, StartPPI, StartHeaderHeight: Integer;
begin
  StartPPI := fTree.Header.Font.PixelsPerInch;
  StartHeight := fTree.Header.Font.Height;
  StartHeaderHeight := fTree.Header.Height;

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, StartPPI, 168, 0, 0);
  Application.ProcessMessages;

  AssertEquals('The header font must follow the DPI change.',
    168, fTree.Header.Font.PixelsPerInch);
  AssertEquals('The header font height must be scaled together with its PPI.',
    Round(StartHeight * 168 / StartPPI), fTree.Header.Font.Height);
  AssertEquals('The header height must be scaled exactly once by the DPI ratio.',
    Round(StartHeaderHeight * 168 / StartPPI), fTree.Header.Height);

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, 168, StartPPI, 0, 0);
  Application.ProcessMessages;

  AssertEquals('Moving back must restore the header font PPI.',
    StartPPI, fTree.Header.Font.PixelsPerInch);
  AssertEquals('Moving back must restore the header font height.',
    StartHeight, fTree.Header.Font.Height);
  AssertEquals('Moving back must restore the header height.',
    StartHeaderHeight, fTree.Header.Height);
end;

procedure TVTDpiScalingTests.DpiChangeScalesInheritedHeaderFontOnce;
var
  StartPPI, StartHeight, StartHeaderHeight: Integer;
begin
  fTree.Header.ParentFont := True;
  fTree.Header.Font.PixelsPerInch := 96;
  fTree.Header.Font.Height := -12;
  Application.ProcessMessages;

  StartPPI := fTree.Header.Font.PixelsPerInch;
  StartHeight := fTree.Header.Font.Height;
  StartHeaderHeight := fTree.Header.Height;

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, StartPPI, 168, 0, 0);
  Application.ProcessMessages;

  AssertEquals('An inherited header font must follow the tree font.',
    168, fTree.Header.Font.PixelsPerInch);
  AssertEquals('An inherited header font must be scaled exactly once.',
    Round(StartHeight * 168 / StartPPI), fTree.Header.Font.Height);
  AssertEquals('The header height must be scaled exactly once by the DPI ratio.',
    Round(StartHeaderHeight * 168 / StartPPI), fTree.Header.Height);

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, 168, StartPPI, 0, 0);
  Application.ProcessMessages;

  AssertEquals('Moving back must restore the inherited header font PPI.',
    StartPPI, fTree.Header.Font.PixelsPerInch);
  AssertEquals('Moving back must restore the inherited header font height.',
    StartHeight, fTree.Header.Font.Height);
  AssertEquals('Moving back must restore the header height.',
    StartHeaderHeight, fTree.Header.Height);
end;

initialization
  RegisterTest(TVTDpiScalingTests);

end.
