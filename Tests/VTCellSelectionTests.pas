unit VTCellSelectionTests;

// FPCUnit port of the upstream Delphi/DUnitX multi-cell selection tests.
// Original: Tests/VTCellSelectionTests.pas (Virtual-TreeView V8.4), written by CheeWee Chua.
//
// Only the tests that drive the public multi-cell selection API are ported:
//   SelectCells / ClearCellSelection / IsCellSelected / SelectedCells / OnChangeCell
//
// The upstream tests that simulate mouse and keyboard input through Windows
// messages (Tests/VirtualTrees.MouseUtils.pas) and the ones that inspect the
// OLE clipboard (HTML/RTF/plain text) are Windows-only and are intentionally
// not ported here.

interface

uses
  fpcunit,
  testregistry,
  Forms,
  Controls,
  Graphics,
  VirtualTrees,
  VirtualTrees.Types,
  Types;

type

  TCellSelectionTests = class(TTestCase)
  strict private
    FTree: TVirtualStringTree;
    FForm: TForm;
    FNode1,
    FNode2,
    FNode3,
    FNode4,
    FNode5: PVirtualNode;
    FCellChangeFired: Boolean;
    FChangeFired: Boolean;
    FChangeNode: PVirtualNode;

    procedure TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure TreeChangeCell(Sender: TBaseVirtualTree; const Cells: TVTCellArray);
    procedure TreeChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure EnableMultiCellSelection;
    function AllNodes: TArray<PVirtualNode>;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSelectSingleCell;
    procedure TestSelectCellsRectangular;
    procedure TestSelectMultipleCellsFailWithoutMultiSelect;
    procedure TestSelectMultipleCellsFailWithoutExtendedFocus;
    procedure TestClear;
    procedure TestClearCellSelection;
    procedure TestChangeCellEvent;
    procedure TestRemovingSetsClearCellSelection;
    procedure TestShiftClickMultipleCells;
    procedure TestClickUnselectsSelectedCells;
    procedure TestOnChange;
    procedure TestLeftClickSelectsNode;
    procedure TestLeftClickWithoutMultiSelectDoesNotSelectCell;
    procedure TestEmptyAreaOnChange;
    procedure TestEmptyAreaOnChange2;
  end;

implementation

uses
  SysUtils,
  Classes,
  Math,
  VirtualTrees.MouseUtils;

function RectUnion(const A, B: TRect): TRect;
begin
  Result.Left := Min(A.Left, B.Left);
  Result.Top := Min(A.Top, B.Top);
  Result.Right := Max(A.Right, B.Right);
  Result.Bottom := Max(A.Bottom, B.Bottom);
end;

type
  // Auxiliary tree hosted in a form; mirrors the upstream
  // VTCellSelectionTests.VTSelectionTestForm (VSTA).
  TSelectionAuxForm = class(TForm)
  public
    VSTA: TVirtualStringTree;
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

  // Auxiliary tree hosted in a form; mirrors the upstream
  // VTCellSelectionTests.VisibilityForm (VST1).
  TVisibilityAuxForm = class(TForm)
  public
    VST1: TVirtualStringTree;
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    procedure TreeInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
      var ChildCount: Cardinal);
    procedure TreeInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode;
      var InitialStates: TVirtualNodeInitStates);
  end;

constructor TSelectionAuxForm.CreateNew(AOwner: TComponent; Num: Integer);
var
  LParent: PVirtualNode;
  I: Integer;
begin
  inherited CreateNew(AOwner, Num);
  Width := 800;
  Height := 800;
  VSTA := TVirtualStringTree.Create(Self);
  VSTA.Parent := Self;
  VSTA.Align := alClient;
  // Same options as the upstream form's DFM.
  VSTA.TreeOptions.SelectionOptions := [toMultiSelect, toSelectNextNodeOnRemoval];
  for I := 1 to 3 do
    VSTA.Header.Columns.Add.Width := 80;
  // Root node with two children, plus a second root node (as in the upstream FormShow).
  LParent := VSTA.AddChild(nil);
  VSTA.AddChild(LParent);
  VSTA.AddChild(LParent);
  VSTA.Expanded[LParent] := True;
  VSTA.AddChild(nil);
end;

constructor TVisibilityAuxForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Width := 800;
  Height := 800;
  VST1 := TVirtualStringTree.Create(Self);
  VST1.Parent := Self;
  VST1.Align := alClient;
  // Same options as the upstream form's DFM.
  VST1.TreeOptions.SelectionOptions := [toMultiSelect];
  VST1.OnInitChildren := TreeInitChildren;
  VST1.OnInitNode := TreeInitNode;
  VST1.RootNodeCount := 5;
end;

procedure TVisibilityAuxForm.TreeInitChildren(Sender: TBaseVirtualTree;
  Node: PVirtualNode; var ChildCount: Cardinal);
begin
  // The upstream uses Random(5) + 1; use a fixed count for deterministic tests.
  ChildCount := 2;
end;

procedure TVisibilityAuxForm.TreeInitNode(Sender: TBaseVirtualTree;
  ParentNode, Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);
begin
  if Sender.GetNodeLevel(Node) < 4 then
    Include(InitialStates, ivsHasChildren);
end;

function TCellSelectionTests.AllNodes: TArray<PVirtualNode>;
begin
  Result := [FNode1, FNode2, FNode3, FNode4, FNode5];
end;

procedure TCellSelectionTests.TreeGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
begin
  if Assigned(Node) then
    CellText := Format('r%dx%d', [Node.Index + 1, Column + 1])
  else
    CellText := '';
end;

procedure TCellSelectionTests.TreeChangeCell(Sender: TBaseVirtualTree;
  const Cells: TVTCellArray);
begin
  FCellChangeFired := True;
end;

procedure TCellSelectionTests.TreeChange(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
begin
  FChangeFired := True;
  FChangeNode := Node;
end;

procedure TCellSelectionTests.EnableMultiCellSelection;
begin
  FTree.TreeOptions.SelectionOptions := FTree.TreeOptions.SelectionOptions +
    [toExtendedFocus, toMultiSelect, toMultiCellSelect] - [toFullRowSelect];
end;

procedure TCellSelectionTests.SetUp;
var
  I: Integer;
  LCol: TVirtualTreeColumn;
begin
  inherited SetUp;
  FCellChangeFired := False;
  FChangeFired := False;
  FChangeNode := nil;

  FForm := TForm.Create(nil);
  FForm.Width := 400;
  FForm.Height := 300;
  FTree := TVirtualStringTree.Create(FForm);
  FTree.Parent := FForm;
  FTree.Align := alClient;
  FTree.OnGetText := TreeGetText;
  FTree.TreeStates := FTree.TreeStates + [tsUseCache];

  for I := 1 to 5 do
  begin
    LCol := FTree.Header.Columns.Add;
    LCol.Text := 'col' + IntToStr(I);
    LCol.Width := 60;
  end;

  FNode1 := FTree.AddChild(FTree.RootNode);
  FNode2 := FTree.AddChild(FTree.RootNode);
  FNode3 := FTree.AddChild(FTree.RootNode);
  FNode4 := FTree.AddChild(FTree.RootNode);
  FNode5 := FTree.AddChild(FTree.RootNode);

  // The tree must be laid out for the mouse based tests (hit testing).
  FForm.Show;
end;

procedure TCellSelectionTests.TearDown;
begin
  FreeAndNil(FForm);
  inherited TearDown;
end;

procedure TCellSelectionTests.TestSelectSingleCell;
var
  LSelectedCells: TVTCellArray;
  LNode: PVirtualNode;
  LColumn: Integer;
begin
  EnableMultiCellSelection;

  FCellChangeFired := False;
  FTree.OnChangeCell := TreeChangeCell;

  FTree.SelectCells(FNode3, 1, FNode3, 1, False);

  AssertTrue('OnChangeCell not fired when selecting a cell', FCellChangeFired);
  AssertTrue('n3, col1 should be selected', FTree.IsCellSelected(FNode3, 1));

  LSelectedCells := FTree.SelectedCells;
  AssertEquals('Should only have 1 cell selected', 1, Length(LSelectedCells));
  AssertTrue('Selected cell identity', (LSelectedCells[0].Node = FNode3) and (LSelectedCells[0].Column = 1));

  for LNode in AllNodes do
    for LColumn := 0 to 3 do
    begin
      if (LNode = FNode3) and (LColumn = 1) then
        Continue;
      AssertFalse(Format('Row: %p Column: %d should not be selected', [Pointer(LNode), LColumn]),
        FTree.IsCellSelected(LNode, LColumn));
    end;
end;

procedure TCellSelectionTests.TestSelectCellsRectangular;
begin
  EnableMultiCellSelection;

  // Select the rectangle from n3/col1 to n4/col2
  FTree.SelectCells(FNode3, 1, FNode4, 2, False);

  AssertTrue('n3, col1 should be selected', FTree.IsCellSelected(FNode3, 1));
  AssertTrue('n3, col2 should be selected', FTree.IsCellSelected(FNode3, 2));
  AssertTrue('n4, col1 should be selected', FTree.IsCellSelected(FNode4, 1));
  AssertTrue('n4, col2 should be selected', FTree.IsCellSelected(FNode4, 2));

  AssertFalse('n3, col0 should not be selected', FTree.IsCellSelected(FNode3, 0));
  AssertFalse('n3, col3 should not be selected', FTree.IsCellSelected(FNode3, 3));
  AssertFalse('n4, col0 should not be selected', FTree.IsCellSelected(FNode4, 0));
  AssertFalse('n4, col3 should not be selected', FTree.IsCellSelected(FNode4, 3));
end;

procedure TCellSelectionTests.TestSelectMultipleCellsFailWithoutMultiSelect;
begin
  FTree.TreeOptions.SelectionOptions := FTree.TreeOptions.SelectionOptions - [toMultiSelect];

  FTree.SelectCells(FNode3, 1, FNode4, 2, False);

  AssertFalse('n3, col1 should not be selected', FTree.IsCellSelected(FNode3, 1));
  AssertFalse('n3, col2 should not be selected', FTree.IsCellSelected(FNode3, 2));
  AssertFalse('n4, col1 should not be selected', FTree.IsCellSelected(FNode4, 1));
  AssertFalse('n4, col2 should not be selected', FTree.IsCellSelected(FNode4, 2));
end;

procedure TCellSelectionTests.TestSelectMultipleCellsFailWithoutExtendedFocus;
begin
  FTree.TreeOptions.SelectionOptions := FTree.TreeOptions.SelectionOptions - [toExtendedFocus];

  FTree.SelectCells(FNode3, 1, FNode4, 2, False);

  AssertFalse('n3, col1 should not be selected', FTree.IsCellSelected(FNode3, 1));
  AssertFalse('n3, col2 should not be selected', FTree.IsCellSelected(FNode3, 2));
  AssertFalse('n4, col1 should not be selected', FTree.IsCellSelected(FNode4, 1));
  AssertFalse('n4, col2 should not be selected', FTree.IsCellSelected(FNode4, 2));
end;

procedure TCellSelectionTests.TestClear;
begin
  EnableMultiCellSelection;

  FTree.SelectCells(FNode3, 1, FNode4, 2, False);
  AssertTrue('Some cells should be selected', Length(FTree.SelectedCells) > 0);

  FTree.Clear;

  AssertEquals('Selected cells are not cleared', 0, Length(FTree.SelectedCells));
end;

procedure TCellSelectionTests.TestClearCellSelection;
begin
  EnableMultiCellSelection;

  FTree.SelectCells(FNode3, 1, FNode4, 2, False);

  AssertTrue('toExtendedFocus expected', toExtendedFocus in FTree.TreeOptions.SelectionOptions);
  AssertTrue('toMultiSelect expected', toMultiSelect in FTree.TreeOptions.SelectionOptions);

  AssertTrue('n3, col1 should be selected', FTree.IsCellSelected(FNode3, 1));
  AssertTrue('n3, col2 should be selected', FTree.IsCellSelected(FNode3, 2));
  AssertTrue('n4, col1 should be selected', FTree.IsCellSelected(FNode4, 1));
  AssertTrue('n4, col2 should be selected', FTree.IsCellSelected(FNode4, 2));

  AssertEquals('Length of selected cells is not 4', 4, Length(FTree.SelectedCells));

  FTree.ClearCellSelection;

  AssertEquals('Length of selected cells is not 0', 0, Length(FTree.SelectedCells));
end;

procedure TCellSelectionTests.TestChangeCellEvent;
begin
  EnableMultiCellSelection;

  FCellChangeFired := False;
  FTree.OnChangeCell := TreeChangeCell;
  FTree.SelectCells(FNode3, 1, FNode3, 1, False);
  AssertTrue('OnChangeCell event not fired when adding', FCellChangeFired);

  FCellChangeFired := False;
  FTree.ClearCellSelection;
  AssertTrue('OnChangeCell event not fired when removing', FCellChangeFired);
end;

procedure TCellSelectionTests.TestRemovingSetsClearCellSelection;

  procedure CheckTree(ATree: TVirtualStringTree; ANode: PVirtualNode);

    procedure SelectOneCell;
    begin
      ATree.TreeOptions.SelectionOptions := ATree.TreeOptions.SelectionOptions +
        [toExtendedFocus, toMultiSelect, toMultiCellSelect] - [toFullRowSelect];
      ATree.SelectCells(ANode, 0, ANode, 0, False);
      AssertEquals('A cell should be selected', 1, Length(ATree.SelectedCells));
    end;

  begin
    // Removing toMultiCellSelect clears the cell selection
    SelectOneCell;
    ATree.TreeOptions.SelectionOptions := ATree.TreeOptions.SelectionOptions - [toMultiCellSelect];
    AssertEquals('toMultiCellSelect removal should clear cells', 0, Length(ATree.SelectedCells));

    // Re-select, then ClearCellSelection
    SelectOneCell;
    ATree.ClearCellSelection;
    AssertEquals('ClearCellSelection should clear cells', 0, Length(ATree.SelectedCells));

    // Removing toExtendedFocus clears the cell selection
    SelectOneCell;
    ATree.TreeOptions.SelectionOptions := ATree.TreeOptions.SelectionOptions - [toExtendedFocus];
    AssertEquals('toExtendedFocus removal should clear cells', 0, Length(ATree.SelectedCells));

    // Removing toMultiSelect clears the cell selection
    SelectOneCell;
    ATree.TreeOptions.SelectionOptions := ATree.TreeOptions.SelectionOptions - [toMultiSelect];
    AssertEquals('toMultiSelect removal should clear cells', 0, Length(ATree.SelectedCells));

    // Enabling toFullRowSelect clears the cell selection
    SelectOneCell;
    ATree.TreeOptions.SelectionOptions := ATree.TreeOptions.SelectionOptions + [toFullRowSelect];
    AssertEquals('toFullRowSelect should clear cells', 0, Length(ATree.SelectedCells));
  end;

var
  LForm: TSelectionAuxForm;
  LTree: TVirtualStringTree;
begin
  // Run against the default tree
  CheckTree(FTree, FNode3);

  // Run against a tree hosted in a form (upstream TSelectionTestForm)
  LForm := TSelectionAuxForm.Create(nil);
  try
    LForm.Show;
    LTree := LForm.VSTA;
    CheckTree(LTree, LTree.GetFirstVisible);
  finally
    LForm.Free;
  end;
end;

procedure TCellSelectionTests.TestShiftClickMultipleCells;
var
  LSelectedCells, LNewSelectedCells: TVTCellArray;
begin
  EnableMultiCellSelection;

  FTree.MouseClick(FNode3, 1);
  LSelectedCells := FTree.SelectedCells;
  FTree.ShiftMouseClick(FNode4, 2);
  LNewSelectedCells := FTree.SelectedCells;

  AssertEquals('Length of selected cell is unexpected', 1, Length(LSelectedCells));
  AssertTrue('Unexpected cell selection 1',
    (LSelectedCells[0].Node = FNode3) and (LSelectedCells[0].Column = 1));

  AssertEquals('Length of selected cells is unexpected', 4, Length(LNewSelectedCells));
  AssertTrue('Unexpected cell selection 0',
    (LNewSelectedCells[0].Node = FNode3) and (LNewSelectedCells[0].Column = 1));
  AssertTrue('Unexpected cell selection 1',
    (LNewSelectedCells[1].Node = FNode3) and (LNewSelectedCells[1].Column = 2));
  AssertTrue('Unexpected cell selection 2',
    (LNewSelectedCells[2].Node = FNode4) and (LNewSelectedCells[2].Column = 1));
  AssertTrue('Unexpected cell selection 3',
    (LNewSelectedCells[3].Node = FNode4) and (LNewSelectedCells[3].Column = 2));
end;

procedure TCellSelectionTests.TestClickUnselectsSelectedCells;
begin
  EnableMultiCellSelection;

  FTree.SelectCells(FNode3, 1, FNode4, 2, False);
  AssertTrue('n3, col1 should be selected', FTree.IsCellSelected(FNode3, 1));

  FTree.MouseClick(FNode1);

  AssertFalse('n3, col1 should not be selected', FTree.IsCellSelected(FNode3, 1));
  AssertFalse('n3, col2 should not be selected', FTree.IsCellSelected(FNode3, 2));
  AssertFalse('n4, col1 should not be selected', FTree.IsCellSelected(FNode4, 1));
  AssertFalse('n4, col2 should not be selected', FTree.IsCellSelected(FNode4, 2));

  AssertTrue('n1, col0 should be selected', FTree.IsCellSelected(FNode1, 0));
end;

procedure TCellSelectionTests.TestOnChange;
begin
  FChangeFired := False;
  FTree.OnChange := TreeChange;

  FTree.MouseClick(FNode3);

  AssertTrue('OnChange event not fired', FChangeFired);
end;

procedure TCellSelectionTests.TestLeftClickSelectsNode;
var
  LSelectedCells: TVTCellArray;
  LSelected: Boolean;
  LForm: TSelectionAuxForm;
  LTree: TVirtualStringTree;
  LNode: PVirtualNode;
begin
  EnableMultiCellSelection;

  FTree.ClearCellSelection;
  AssertEquals('Length of selected cell is unexpected', 0, Length(FTree.SelectedCells));

  FTree.MouseClick(FNode3, 0);
  LSelectedCells := FTree.SelectedCells;
  AssertEquals('Length of selected cell is unexpected', 1, Length(LSelectedCells));

  FTree.ClearCellSelection;
  AssertEquals('Length of selected cell is unexpected', 0, Length(FTree.SelectedCells));

  // Remove multiselect, which is part of multicell select
  FTree.TreeOptions.SelectionOptions := FTree.TreeOptions.SelectionOptions - [toMultiSelect];
  FTree.MouseClick(FNode3);

  AssertEquals('No cell should be selected', 0, Length(FTree.SelectedCells));
  AssertTrue('Node should be selected', FTree.Selected[FNode3]);

  // Same checks against a tree hosted in a form (upstream TSelectionTestForm)
  LForm := TSelectionAuxForm.Create(nil);
  try
    LForm.Show; // Needed to initialize the VST
    LTree := LForm.VSTA;
    LNode := LTree.GetFirstVisible;
    AssertTrue('Node is nil', LNode <> nil);
    LSelected := LTree.Selected[LNode];
    AssertFalse('Node is selected', LSelected);
    LTree.MouseClick(LNode);
    LSelected := LTree.Selected[LNode];
    AssertTrue('Node is selected', LSelected);
  finally
    LForm.Free;
  end;
end;

procedure TCellSelectionTests.TestLeftClickWithoutMultiSelectDoesNotSelectCell;
var
  LSelectedCells: TVTCellArray;
begin
  FTree.TreeOptions.SelectionOptions := FTree.TreeOptions.SelectionOptions - [toMultiSelect];

  AssertEquals('Length of selected cell is unexpected', 0, Length(FTree.SelectedCells));

  FTree.MouseClick(FNode3, 1);

  LSelectedCells := FTree.SelectedCells;
  AssertEquals('Length of selected cell is unexpected', 0, Length(LSelectedCells));
end;

procedure TCellSelectionTests.TestEmptyAreaOnChange;
var
  I, LColumnCount, LMaxWidth: Integer;
  Rects: array of TRect;
  LargestRect: TRect;
  LTextOnly, LUnclipped, LApplyCellContentMargin: Boolean;
  LastNode: PVirtualNode;
  LEmptyArea: TPoint;
  LHitInfo: THitInfo;
begin
  // Compute the largest client area needed by the node and enlarge the tree so
  // there is guaranteed to be empty space below the last visible node.
  LColumnCount := FTree.Header.Columns.Count;
  LMaxWidth := 0;
  for I := 0 to LColumnCount - 1 do
    if FTree.Header.Columns[I].Width > LMaxWidth then
      LMaxWidth := FTree.Header.Columns[I].Width;

  I := 0;
  for LTextOnly := False to True do
    for LUnclipped := False to True do
      for LApplyCellContentMargin := False to True do
      begin
        SetLength(Rects, I + 1);
        Rects[I] := FTree.GetDisplayRect(FNode3, LColumnCount - 1,
          LTextOnly, LUnclipped, LApplyCellContentMargin);
        Inc(I);
      end;

  LargestRect := Rects[0];
  for I := 1 to High(Rects) do
    LargestRect := RectUnion(LargestRect, Rects[I]);

  LastNode := FTree.GetLastVisible;

  FTree.ClientHeight := LargestRect.BottomRight.Y + (LastNode.NodeHeight * 2);
  FTree.ClientWidth := LargestRect.BottomRight.X + LMaxWidth;

  // This should be an empty area, beyond any visible nodes
  LEmptyArea := Point(LargestRect.BottomRight.X + LMaxWidth,
    LargestRect.BottomRight.Y + LastNode.NodeHeight);

  // Select a node first: clicking an empty area must clear the selection and
  // therefore fire OnChange(nil).
  FTree.ClearSelection;
  FTree.MouseClick(FNode3);
  AssertEquals('A node should be selected', 1, FTree.SelectedCount);

  FChangeFired := False;
  FChangeNode := FNode3; // sentinel, must become nil
  FTree.OnChange := TreeChange;

  FTree.GetHitTestInfoAt(LEmptyArea.X, LEmptyArea.Y, True, LHitInfo);
  AssertTrue('Mouse click is not in an unpopulated/empty area', hiNowhere in LHitInfo.HitPositions);

  FTree.MouseClick(LEmptyArea);

  AssertTrue('OnChange event not fired', FChangeFired);
  AssertTrue('Node is not nil', FChangeNode = nil);
end;

procedure TCellSelectionTests.TestEmptyAreaOnChange2;
var
  LForm: TVisibilityAuxForm;
  LTree: TVirtualStringTree;
  n1: PVirtualNode;
  I, LColumnCount, LMaxWidth: Integer;
  Rects: array of TRect;
  LargestRect: TRect;
  LTextOnly, LUnclipped, LApplyCellContentMargin: Boolean;
  LastNode: PVirtualNode;
  LEmptyArea: TPoint;
  LHitInfo: THitInfo;
begin
  LForm := TVisibilityAuxForm.Create(nil);
  try
    LForm.Show;
    LTree := LForm.VST1;

    n1 := LTree.GetLastVisible;

    // Calculate the largest client area for the tree and set it
    LColumnCount := LTree.Header.Columns.Count;
    LMaxWidth := 0;
    for I := 0 to LColumnCount - 1 do
      if LTree.Header.Columns[I].Width > LMaxWidth then
        LMaxWidth := LTree.Header.Columns[I].Width;
    if LMaxWidth = 0 then
      LMaxWidth := 300;

    I := 0;
    LargestRect := Rect(0, 0, 0, 0);
    for LTextOnly := False to True do
      for LUnclipped := False to True do
        for LApplyCellContentMargin := False to True do
        begin
          SetLength(Rects, I + 1);
          // With no columns, LColumnCount - 1 is NoColumn.
          Rects[I] := LTree.GetDisplayRect(n1, LColumnCount - 1,
            LTextOnly, LUnclipped, LApplyCellContentMargin);
          LargestRect := RectUnion(LargestRect, Rects[I]);
          Inc(I);
        end;

    LastNode := LTree.GetLastVisibleChild(LTree.RootNode);

    LTree.ClientHeight := LargestRect.BottomRight.Y + (LastNode.NodeHeight * 2);
    LTree.ClientWidth := LargestRect.BottomRight.X + LMaxWidth;

    // Choose a point below the last visible node: it is guaranteed to be an
    // empty area inside the (large) client rectangle.
    LEmptyArea := LTree.GetDisplayRect(n1, NoColumn, False, False, False).BottomRight;
    LEmptyArea := Point(10, LEmptyArea.Y + 5);

    // At this point, there should be no nodes selected
    LTree.ClearSelection;
    AssertEquals('No node should be selected', 0, LTree.SelectedCount);

    LTree.MouseClick(n1, NoColumn);
    AssertEquals('A node should be selected', 1, LTree.SelectedCount);

    FChangeFired := False;
    FChangeNode := n1; // sentinel, must become nil
    LTree.OnChange := TreeChange;

    LTree.GetHitTestInfoAt(LEmptyArea.X, LEmptyArea.Y, True, LHitInfo);
    AssertTrue('Mouse click is not in an unpopulated/empty area', hiNowhere in LHitInfo.HitPositions);

    LTree.MouseClick(LEmptyArea);

    AssertTrue('OnChange event not fired', FChangeFired);
    AssertTrue('Node is not nil', FChangeNode = nil);
  finally
    LForm.Free;
  end;
end;

initialization
  RegisterTest(TCellSelectionTests);

end.
