unit VTFocusChangedIssue1379Tests;

// Regression test for issue #1379 "FocusChanged is called at wrong place when the
// user is using keyboard".
//
// Keyboard navigation sets the focused node twice: WMKeyDown moves the focus (which
// fires OnFocusChanged), then AddToSelection() assigns the - by now unchanged -
// focused node again. SetFocusedNode() always ran DoFocusNode(), which starts by
// ending a node edit. So an edit started by the application inside OnFocusChanged
// was immediately ended again by that redundant assignment. With the mouse the
// order of events differs, which is why it worked there.
//
// Fix as suggested in the issue discussion: SetFocusedNode() exits early when the
// node is already focused.

interface

uses
  fpcunit,
  testregistry,
  Forms,
  VirtualTrees;

type
  TVTFocusChangedIssue1379Tests = class(TTestCase)
  strict private

    fForm: TForm;

    fTree: TVirtualStringTree;

    fFocusChangedCount: Integer;

    procedure TreeFocusChangedStartsEdit(Sender: TBaseVirtualTree; Node: PVirtualNode;

      Column: TColumnIndex);

  public

  protected



    procedure SetUp; override;



    procedure TearDown; override;





    /// The minimal contract: re-assigning the already focused node must not end editing.

  published

    procedure RefocusingSameNodeKeepsEditing;



    /// The reported scenario: an edit started in OnFocusChanged survives keyboard navigation.

    procedure EditStartedInFocusChangedSurvivesKeyNavigation;
  end;

implementation

uses
  LCLType,
  LMessages,
  SysUtils,
  VirtualTrees.Types;

procedure TVTFocusChangedIssue1379Tests.SetUp;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.TreeOptions.MiscOptions := fTree.TreeOptions.MiscOptions + [toEditable];
  fTree.Header.Columns.Add;
  fTree.AddChild(fTree.RootNode);
  fTree.AddChild(fTree.RootNode);
  fForm.Show;
end;

procedure TVTFocusChangedIssue1379Tests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

procedure TVTFocusChangedIssue1379Tests.TreeFocusChangedStartsEdit(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex);
begin
  Inc(fFocusChangedCount);
  if Assigned(Node) then
    fTree.EditNode(Node, 0);
end;

procedure TVTFocusChangedIssue1379Tests.RefocusingSameNodeKeepsEditing;
begin
  fTree.FocusedNode := fTree.GetFirst;
  AssertTrue('Sanity: editing must start.', fTree.EditNode(fTree.FocusedNode, 0));
  AssertTrue('Sanity: tree must be in editing state.', tsEditing in fTree.TreeStates);

  fTree.FocusedNode := fTree.FocusedNode;

  AssertTrue('Assigning the already focused node must not end node editing (issue #1379).', tsEditing in fTree.TreeStates);
end;

procedure TVTFocusChangedIssue1379Tests.EditStartedInFocusChangedSurvivesKeyNavigation;
begin
  fTree.FocusedNode := fTree.GetFirst;
  fTree.Selected[fTree.GetFirst] := True;
  fFocusChangedCount := 0;
  fTree.OnFocusChanged := TreeFocusChangedStartsEdit;

  fTree.Perform(LM_KEYDOWN, VK_DOWN, 0);

  AssertEquals('Sanity: the key press must have changed the focus once.', fFocusChangedCount, 1);
  AssertTrue('Sanity: the second node must be focused now.', fTree.FocusedNode = fTree.GetNextSibling(fTree.GetFirst));
  AssertTrue('The edit started in OnFocusChanged must survive the rest of the key handling (issue #1379).', tsEditing in fTree.TreeStates);
end;

initialization
  RegisterTest(TVTFocusChangedIssue1379Tests);

end.
