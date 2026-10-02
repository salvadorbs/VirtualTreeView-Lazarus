unit VTSelectedCountIssue1197Tests;

// Regression test for issue #1197 "SelectedCount is not always correct".
//
// Finding: ToggleSelection() (the Shift+Arrow path) removes nodes from the selection via
// InternalRemoveFromSelection. That routine only MARKS the entry in the selection array (it
// sets the lowest bit of the pointer, see PackArray) but immediately fires DoRemoveFromSelection
// and Change. FSelectionCount is only corrected AFTER the loop by PackArray.
//
// Consequence: in OnRemoveFromSelection / OnChange / OnStateChange, SelectedCount still reports
// the old, too high value, while counting the nodes with vsSelected is already correct - which is
// exactly what the reporter described.
//
// FPCUnit/LCL port of the upstream DUnitX test.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Forms,
  VirtualTrees,
  VirtualTrees.Types,
  VirtualTrees.BaseTree;

type
  // Cracker to reach the protected ToggleSelection (the keyboard path calls it).
  TTestTree = class(TVirtualStringTree)
  public
    procedure PublicToggleSelection(StartNode, EndNode: PVirtualNode);
  end;

  TVTSelectedCountIssue1197Tests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TTestTree;
    fCountInEvent: Integer;      // SelectedCount as the event sees it
    fActualInEvent: Integer;     // actually selected nodes at the same moment
    fEventFired: Boolean;
    function CountSelectedNodes: Integer;
    procedure TreeRemoveFromSelection(Sender: TBaseVirtualTree; Node: PVirtualNode);
    function NodeByIndex(Index: Integer): PVirtualNode;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// SelectedCount must match the actual number of selected nodes even during OnRemoveFromSelection.
    procedure SelectedCountIsCorrectDuringRemoveFromSelection;

    /// After the operation completes the value must be correct in any case
    /// (this already worked before the fix - guards against over-correction).
    procedure SelectedCountIsCorrectAfterToggleSelection;
  end;

implementation

uses
  SysUtils;

{ TTestTree }

procedure TTestTree.PublicToggleSelection(StartNode, EndNode: PVirtualNode);
begin
  ToggleSelection(StartNode, EndNode);
end;

{ TVTSelectedCountIssue1197Tests }

procedure TVTSelectedCountIssue1197Tests.SetUp;
begin
  inherited SetUp;
  fForm := TForm.Create(nil);
  fTree := TTestTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.TreeOptions.SelectionOptions := fTree.TreeOptions.SelectionOptions + [toMultiSelect];
  fTree.NodeDataSize := 0;
  fTree.RootNodeCount := 10;
  fTree.ValidateNode(nil, True);
  fEventFired := False;
  fCountInEvent := -1;
  fActualInEvent := -1;
end;

procedure TVTSelectedCountIssue1197Tests.TearDown;
begin
  FreeAndNil(fForm);
  inherited TearDown;
end;

function TVTSelectedCountIssue1197Tests.NodeByIndex(Index: Integer): PVirtualNode;
var
  I: Integer;
begin
  Result := fTree.GetFirst;
  for I := 1 to Index do
    Result := fTree.GetNext(Result);
end;

function TVTSelectedCountIssue1197Tests.CountSelectedNodes: Integer;
var
  Node: PVirtualNode;
begin
  Result := 0;
  Node := fTree.GetFirst;
  while Assigned(Node) do
  begin
    if vsSelected in Node.States then
      Inc(Result);
    Node := fTree.GetNext(Node);
  end;
end;

procedure TVTSelectedCountIssue1197Tests.TreeRemoveFromSelection(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
begin
  // Record only the first call - the deviation is largest there.
  if fEventFired then
    Exit;
  fEventFired := True;
  fCountInEvent := fTree.SelectedCount;
  fActualInEvent := CountSelectedNodes;
end;

procedure TVTSelectedCountIssue1197Tests.SelectedCountIsCorrectDuringRemoveFromSelection;
var
  First, Fifth: PVirtualNode;
begin
  First := NodeByIndex(0);
  Fifth := NodeByIndex(4);

  // Select nodes 0..4, anchor on the first (like Shift+Arrow down).
  fTree.FocusedNode := First;
  fTree.Selected[First] := True;
  fTree.SelectNodes(First, Fifth, False);
  AssertEquals('Precondition: 5 nodes selected', 5, fTree.SelectedCount);

  fTree.OnRemoveFromSelection := TreeRemoveFromSelection;

  // Shrink the selection (Shift+Arrow up): the range 4..2 gets deselected.
  fTree.PublicToggleSelection(Fifth, NodeByIndex(2));

  AssertTrue('OnRemoveFromSelection was not fired', fEventFired);
  AssertEquals(Format('SelectedCount reports %d in the event, actually selected are %d',
    [fCountInEvent, fActualInEvent]), fActualInEvent, fCountInEvent);
end;

procedure TVTSelectedCountIssue1197Tests.SelectedCountIsCorrectAfterToggleSelection;
var
  First, Fifth: PVirtualNode;
begin
  First := NodeByIndex(0);
  Fifth := NodeByIndex(4);

  fTree.FocusedNode := First;
  fTree.Selected[First] := True;
  fTree.SelectNodes(First, Fifth, False);

  fTree.PublicToggleSelection(Fifth, NodeByIndex(2));

  AssertEquals('SelectedCount after the operation completed', CountSelectedNodes, fTree.SelectedCount);
end;

initialization
  RegisterTest(TVTSelectedCountIssue1197Tests);
end.
