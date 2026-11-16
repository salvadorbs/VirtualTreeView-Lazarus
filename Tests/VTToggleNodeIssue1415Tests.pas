unit VTToggleNodeIssue1415Tests;

// Regression tests for issue #1415 "Expanding a node with no children costs a scroll bar
// update inside BeginUpdate (major performance issue)".
//
// ToggleNode() set NeedUpdate before it knew whether the node changes at all. Expanding a
// node that has no children (and no vsHasChildren) therefore invalidated the position cache
// and repainted the node, and inside BeginUpdate it updated the scroll bars. FullExpand does
// that for every leaf, which took seconds for a large tree with a VCL style active.
//
// The fix sets NeedUpdate only when the node is changed and leaves the scroll bars to
// EndUpdate while the tree is updating. The tests check both, and that the cases which do
// change the node are still updated.
//
// FPCUnit/LCL port of the upstream DUnitX test. Instead of the Windows invalid region and
// window style, this port counts calls to the virtual Invalidate/InvalidateNode methods and
// derives the vertical scroll bar visibility from the tree's vertical range.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Types,
  Controls,
  Forms,
  Graphics,
  VirtualTrees,
  VirtualTrees.Types;

type
  /// Counts the scroll bar and repaint requests of the tree.
  TScrollBarCountingTree = class(TVirtualStringTree)
  strict private
    fScrollBarUpdates: Integer;
    fInvalidations: Integer;
  protected
    procedure UpdateScrollBars(DoRepaint: Boolean); override;
    procedure Invalidate; override;
    function InvalidateNode(Node: PVirtualNode): TRect; override;
  public
    function VerticalRange: TDimension;
    property ScrollBarUpdates: Integer read fScrollBarUpdates write fScrollBarUpdates;
    property Invalidations: Integer read fInvalidations write fInvalidations;
  end;

  TVTToggleNodeIssue1415Tests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TScrollBarCountingTree;
    fExpandingCount: Integer;
    fChildCountOnExpanding: Cardinal;
    procedure TreeExpanding(Sender: TBaseVirtualTree; Node: PVirtualNode; var Allowed: Boolean);
    procedure TreeInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode; var ChildCount: Cardinal);
    procedure ResetCounters;
    function HasInvalidation: Boolean;
    function VertBarVisible: Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// Expanding a node without children changes nothing, so nothing must be repainted.
    procedure ExpandingLeafDoesNotRepaint;

    /// The reported scenario: FullExpand over many leaves updates the scroll bars once, in
    /// EndUpdate, and not for every leaf.
    procedure FullExpandUpdatesScrollBarsOnlyOnce;

    /// Expanding a node with children inside BeginUpdate keeps the range current but leaves
    /// the scroll bars to EndUpdate.
    procedure ExpandInsideUpdateLeavesScrollBarsToEndUpdate;

    /// A node with vsHasChildren whose OnInitChildren reports no children loses its button,
    /// so it still has to be repainted.
    procedure NodeLosingItsButtonIsRepainted;

    /// OnExpanding still fires for a node without children, and children added there are
    /// expanded.
    procedure ChildrenAddedInOnExpandingAreExpanded;
  end;

implementation

uses
  SysUtils,
  LMessages;

{ TScrollBarCountingTree }

function TScrollBarCountingTree.VerticalRange: TDimension;
begin
  Result := RangeY;
end;

procedure TScrollBarCountingTree.UpdateScrollBars(DoRepaint: Boolean);
begin
  Inc(fScrollBarUpdates);
  inherited UpdateScrollBars(DoRepaint);
end;

procedure TScrollBarCountingTree.Invalidate;
begin
  Inc(fInvalidations);
  inherited Invalidate;
end;

function TScrollBarCountingTree.InvalidateNode(Node: PVirtualNode): TRect;
begin
  Inc(fInvalidations);
  Result := inherited InvalidateNode(Node);
end;

{ TVTToggleNodeIssue1415Tests }

procedure TVTToggleNodeIssue1415Tests.SetUp;
begin
  inherited SetUp;

  fExpandingCount := 0;
  fChildCountOnExpanding := 0;
  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 320, 200);
  fTree := TScrollBarCountingTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.Align := alClient;
  fTree.DefaultNodeHeight := 18;
  fTree.OnExpanding := TreeExpanding;
  fTree.OnInitChildren := TreeInitChildren;
  // Five leaves fit into the client area, so there is no vertical scroll bar yet.
  fTree.RootNodeCount := 5;
  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTToggleNodeIssue1415Tests.TearDown;
begin
  FreeAndNil(fForm);

  inherited TearDown;
end;

procedure TVTToggleNodeIssue1415Tests.TreeExpanding(Sender: TBaseVirtualTree; Node: PVirtualNode;
  var Allowed: Boolean);
begin
  Inc(fExpandingCount);
  if fChildCountOnExpanding > 0 then
    Sender.ChildCount[Node] := fChildCountOnExpanding;
end;

procedure TVTToggleNodeIssue1415Tests.TreeInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
  var ChildCount: Cardinal);
begin
  ChildCount := 0; // A node marked with HasChildren turns out to have none.
end;

procedure TVTToggleNodeIssue1415Tests.ResetCounters;
begin
  fTree.ScrollBarUpdates := 0;
  fTree.Invalidations := 0;
end;

function TVTToggleNodeIssue1415Tests.HasInvalidation: Boolean;
begin
  Result := fTree.Invalidations > 0;
end;

function TVTToggleNodeIssue1415Tests.VertBarVisible: Boolean;
begin
  // The LCL widgetset does not necessarily use WS_VSCROLL; the tree's own range
  // decides whether a vertical scroll bar is needed.
  Result := fTree.VerticalRange > fTree.ClientHeight;
end;

procedure TVTToggleNodeIssue1415Tests.ExpandingLeafDoesNotRepaint;
var
  Node: PVirtualNode;
begin
  Node := fTree.GetFirst;
  AssertFalse('Sanity: the node must not have children.', fTree.HasChildren[Node]);
  ResetCounters;

  fTree.Expanded[Node] := True;

  AssertEquals('OnExpanding must still be fired for a node without children.', 1, fExpandingCount);
  AssertFalse('A node without children cannot be expanded.', fTree.Expanded[Node]);
  AssertFalse('Expanding a node without children changes nothing and must not repaint it (issue #1415).',
    HasInvalidation);
end;

procedure TVTToggleNodeIssue1415Tests.FullExpandUpdatesScrollBarsOnlyOnce;
const
  cLeafCount = 200;
begin
  fTree.RootNodeCount := cLeafCount;
  Application.ProcessMessages;
  ResetCounters;

  fTree.FullExpand;

  AssertEquals('Sanity: FullExpand must try to expand every leaf.', cLeafCount, fExpandingCount);
  AssertEquals('FullExpand must update the scroll bars once in EndUpdate, not for every leaf (issue #1415).',
    1, fTree.ScrollBarUpdates);
end;

procedure TVTToggleNodeIssue1415Tests.ExpandInsideUpdateLeavesScrollBarsToEndUpdate;
var
  Node: PVirtualNode;
begin
  Node := fTree.GetFirst;
  fTree.ChildCount[Node] := 50;
  Application.ProcessMessages;
  AssertFalse('Sanity: with the node collapsed all nodes fit into the client area.', VertBarVisible);
  ResetCounters;

  fTree.BeginUpdate;
  try
    fTree.Expanded[Node] := True;
    AssertTrue('Sanity: the node must be expanded.', fTree.Expanded[Node]);
    AssertEquals('Inside BeginUpdate expanding must leave the scroll bars to EndUpdate (issue #1415).',
      0, fTree.ScrollBarUpdates);
    AssertTrue('Inside BeginUpdate the vertical range must still be kept current.',
      fTree.VerticalRange > fTree.ClientHeight);
  finally
    fTree.EndUpdate;
  end;

  AssertTrue('EndUpdate must show the vertical scroll bar for the expanded children.', VertBarVisible);
end;

procedure TVTToggleNodeIssue1415Tests.NodeLosingItsButtonIsRepainted;
var
  Node: PVirtualNode;
begin
  Node := fTree.GetFirst;
  fTree.HasChildren[Node] := True;
  Application.ProcessMessages;
  ResetCounters;

  fTree.Expanded[Node] := True; // OnInitChildren reports no children.

  AssertFalse('Sanity: without children the node must lose vsHasChildren.', fTree.HasChildren[Node]);
  AssertFalse('Sanity: a node without children cannot be expanded.', fTree.Expanded[Node]);
  AssertTrue('The node lost its expand button and must be repainted (issue #1415).',
    HasInvalidation);
end;

procedure TVTToggleNodeIssue1415Tests.ChildrenAddedInOnExpandingAreExpanded;
var
  Node: PVirtualNode;
begin
  Node := fTree.GetFirst;
  fChildCountOnExpanding := 3;

  fTree.Expanded[Node] := True;

  AssertEquals('Sanity: OnExpanding must have been fired once.', 1, fExpandingCount);
  AssertEquals('Sanity: OnExpanding must have added the children.', 3, Integer(fTree.ChildCount[Node]));
  AssertTrue('Children added in OnExpanding must be expanded (issue #1415).', fTree.Expanded[Node]);
end;

initialization
  RegisterTest(TVTToggleNodeIssue1415Tests);

end.
