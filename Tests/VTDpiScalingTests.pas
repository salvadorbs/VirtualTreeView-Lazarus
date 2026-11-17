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
  VirtualTrees,
  VirtualTrees.Types;

type
  // Exposes the protected element offsets so the test can observe the check
  // box margin without a public property (FImagesMargin is private).
  TVTDpiScalingTreeCracker = class(TVirtualStringTree)
  public
    /// Width of the check box plus the margin on both sides, from GetOffsets.
    function CheckAreaWidth: TDimension;
  end;

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

    /// Header height and column width/spacing/margin still at their default
    /// value must be re-derived from the new font PPI instead of keeping the
    /// pixel size of the old PPI.
    procedure DpiChangeUpdatesDefaultHeaderAndColumnSizes;

    /// The same applies to the tree-level layout defaults (indent, margins and
    /// drag image size).
    procedure DpiChangeUpdatesDefaultTreeSizes;

    /// Changing several column widths inside BeginUpdate/EndUpdate must reset
    /// the vsHeightMeasured flags only once, when the batch ends, and not once
    /// per column (which would traverse all nodes N times).
    procedure BatchedColumnWidthChangeDefersHeightReset;

    /// The checkbox margin has no stored flag and no default constant: it must
    /// follow the DPI ratio in both directions.
    procedure DpiChangeScalesImagesMargin;
  end;

implementation

uses
  SysUtils;

function TVTDpiScalingTreeCracker.CheckAreaWidth: TDimension;
var
  Offsets: TVTOffsets;
  Node: PVirtualNode;
begin
  Node := GetFirstInitialized;
  if not Assigned(Node) then
    Exit(0);
  GetOffsets(Node, Offsets, ofsStateImage);
  Result := Offsets[ofsStateImage] - Offsets[ofsCheckBox];
end;

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

procedure TVTDpiScalingTests.DpiChangeUpdatesDefaultHeaderAndColumnSizes;
var
  Col: TVirtualTreeColumn;
  StartPPI, StartHeaderHeight, StartDefaultHeight, StartMinHeight,
  StartDefaultWidth, StartWidth, StartSpacing, StartMargin: Integer;
begin
  // Keep AutoScale from recomputing the header height from its font: this test
  // only checks that the layout defaults follow the new font PPI.
  fTree.TreeOptions.AutoOptions := fTree.TreeOptions.AutoOptions - [toAutoChangeScale];

  StartPPI := fTree.Font.PixelsPerInch;
  AssertEquals('Sanity: the tree font must start at 96 PPI.', 96, StartPPI);

  // Reset header and column geometry to the default value for the current PPI,
  // so that the test really exercises the property defaults.
  fTree.Header.DefaultHeight := fTree.Scale96ToFont(DEFAULT_HEADER_HEIGHT);
  fTree.Header.MinHeight := fTree.Scale96ToFont(DEFAULT_MIN_HEIGHT);
  fTree.Header.Height := fTree.Scale96ToFont(DEFAULT_HEADER_HEIGHT);
  fTree.Header.Columns.DefaultWidth := fTree.Scale96ToFont(DEFAULT_COLUMN_WIDTH);

  Col := fTree.Header.Columns.Add;
  Col.Width := fTree.Scale96ToFont(DEFAULT_COLUMN_WIDTH);
  Col.Spacing := fTree.Scale96ToFont(DEFAULT_SPACING);
  Col.Margin := fTree.Scale96ToFont(DEFAULT_MARGIN);

  StartHeaderHeight := fTree.Header.Height;
  StartDefaultHeight := fTree.Header.DefaultHeight;
  StartMinHeight := fTree.Header.MinHeight;
  StartDefaultWidth := fTree.Header.Columns.DefaultWidth;
  StartWidth := Col.Width;
  StartSpacing := Col.Spacing;
  StartMargin := Col.Margin;

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, StartPPI, 192, 0, 0);
  Application.ProcessMessages;

  AssertEquals('The default header height must follow the new font PPI.',
    StartHeaderHeight * 2, Integer(fTree.Header.Height));
  AssertEquals('The default header default height must follow the new font PPI.',
    StartDefaultHeight * 2, Integer(fTree.Header.DefaultHeight));
  AssertEquals('The default header minimum height must follow the new font PPI.',
    StartMinHeight * 2, Integer(fTree.Header.MinHeight));
  AssertEquals('The default column width must follow the new font PPI.',
    StartDefaultWidth * 2, Integer(fTree.Header.Columns.DefaultWidth));
  AssertEquals('A column at its default width must follow the new font PPI.',
    StartWidth * 2, Integer(Col.Width));
  AssertEquals('A column at its default spacing must follow the new font PPI.',
    StartSpacing * 2, Integer(Col.Spacing));
  AssertEquals('A column at its default margin must follow the new font PPI.',
    StartMargin * 2, Integer(Col.Margin));
end;

procedure TVTDpiScalingTests.DpiChangeUpdatesDefaultTreeSizes;
var
  StartPPI, StartIndent, StartMargin, StartTextMargin,
  StartDragHeight, StartDragWidth: Integer;
begin
  // Avoid AutoScale changing DefaultNodeHeight while we check the layout
  // defaults; it has its own tests above.
  fTree.TreeOptions.AutoOptions := fTree.TreeOptions.AutoOptions - [toAutoChangeScale];

  StartPPI := fTree.Font.PixelsPerInch;
  AssertEquals('Sanity: the tree font must start at 96 PPI.', 96, StartPPI);

  // Reset the layout values to their defaults for the current PPI.
  fTree.Indent := fTree.Scale96ToFont(DEFAULT_INDENT);
  fTree.Margin := fTree.Scale96ToFont(DEFAULT_MARGIN);
  fTree.TextMargin := fTree.Scale96ToFont(DEFAULT_MARGIN);
  fTree.DragHeight := fTree.Scale96ToFont(DEFAULT_DRAG_HEIGHT);
  fTree.DragWidth := fTree.Scale96ToFont(DEFAULT_DRAG_WIDTH);

  StartIndent := fTree.Indent;
  StartMargin := fTree.Margin;
  StartTextMargin := fTree.TextMargin;
  StartDragHeight := fTree.DragHeight;
  StartDragWidth := fTree.DragWidth;

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, StartPPI, 192, 0, 0);
  Application.ProcessMessages;

  AssertEquals('The default indent must follow the new font PPI.',
    StartIndent * 2, Integer(fTree.Indent));
  AssertEquals('The default margin must follow the new font PPI.',
    StartMargin * 2, Integer(fTree.Margin));
  AssertEquals('The default text margin must follow the new font PPI.',
    StartTextMargin * 2, Integer(fTree.TextMargin));
  AssertEquals('The default drag height must follow the new font PPI.',
    StartDragHeight * 2, Integer(fTree.DragHeight));
  AssertEquals('The default drag width must follow the new font PPI.',
    StartDragWidth * 2, Integer(fTree.DragWidth));
end;

procedure TVTDpiScalingTests.BatchedColumnWidthChangeDefersHeightReset;
var
  Node: PVirtualNode;
begin
  while fTree.Header.Columns.Count < 2 do
    fTree.Header.Columns.Add;
  Application.ProcessMessages;

  // Mark all nodes as already measured multiline nodes. Their height depends on
  // the column width, so a width change must clear vsHeightMeasured.
  Node := fTree.GetFirstInitialized;
  AssertNotNull('Sanity: the tree must have initialized nodes.', Node);
  while Assigned(Node) do
  begin
    Include(Node.States, vsMultiline);
    Include(Node.States, vsHeightMeasured);
    Node := fTree.GetNextInitialized(Node);
  end;

  Node := fTree.GetFirstInitialized;
  fTree.Header.Columns.BeginUpdate;
  try
    fTree.Header.Columns[0].Width := fTree.Header.Columns[0].Width + 10;
    // While the batch is open the reset must be deferred, so that further
    // column changes do not traverse all nodes again.
    AssertTrue('vsHeightMeasured must not be reset before the batch ends.',
      vsHeightMeasured in Node.States);
    fTree.Header.Columns[1].Width := fTree.Header.Columns[1].Width + 10;
    AssertTrue('vsHeightMeasured must still be set after the second width change.',
      vsHeightMeasured in Node.States);
  finally
    fTree.Header.Columns.EndUpdate;
  end;

  while Assigned(Node) do
  begin
    AssertFalse(Format('Node %d: vsHeightMeasured must be reset when the column batch ends.',
      [Node.Index]), vsHeightMeasured in Node.States);
    Node := fTree.GetNextInitialized(Node);
  end;
end;

procedure TVTDpiScalingTests.DpiChangeScalesImagesMargin;
var
  StartWidth: TDimension;
  Node: PVirtualNode;
begin
  fTree.TreeOptions.MiscOptions := fTree.TreeOptions.MiscOptions + [toCheckSupport];
  Node := fTree.GetFirstInitialized;
  AssertNotNull('Sanity: the tree must have initialized nodes.', Node);
  Node.CheckType := ctCheckBox;
  Application.ProcessMessages;

  // CheckAreaWidth = check box width + ImagesMargin on both sides. Both must
  // follow the DPI ratio; a margin left at 2 px would make the result smaller
  // than the doubled value.
  StartWidth := TVTDpiScalingTreeCracker(fTree).CheckAreaWidth;
  AssertTrue('Sanity: the check box area must have a width.', StartWidth > 0);

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, 96, 192, 0, 0);
  Application.ProcessMessages;
  AssertEquals('The check box area must scale with the DPI ratio.',
    StartWidth * 2, Integer(TVTDpiScalingTreeCracker(fTree).CheckAreaWidth));

  fTree.AutoAdjustLayout(lapAutoAdjustForDPI, 192, 96, 0, 0);
  Application.ProcessMessages;
  AssertEquals('Moving back must restore the check box area.',
    StartWidth, Integer(TVTDpiScalingTreeCracker(fTree).CheckAreaWidth));
end;

initialization
  RegisterTest(TVTDpiScalingTests);

end.
