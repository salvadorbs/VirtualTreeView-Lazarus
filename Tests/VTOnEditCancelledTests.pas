unit VTOnEditCancelledTests;

interface

uses
  fpcunit,
  testregistry,
  Forms,
  VirtualTrees;

type

  TVTOnEditCancelledTests = class(TTestCase)
  strict private
    fTree: TVirtualStringTree;
    fForm: TForm;
    FEditCancelled: Boolean;
    procedure TreeEditCancelled(Sender: TBaseVirtualTree; Column: TColumnIndex);
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestAddColumn;
    procedure TestEditNodeFail;
    procedure TestEditNode;
    procedure TestEditNodeReadOnly;
    procedure TestOnEditCancelled;
  end;

implementation

uses
  SysUtils, VirtualTrees.Types;

procedure TVTOnEditCancelledTests.SetUp;
begin
  inherited SetUp;
  fForm := TForm.Create(nil);
  fTree := TVirtualStringTree.Create(fForm);
end;

procedure TVTOnEditCancelledTests.TearDown;
begin
  FreeAndNil(fForm);
  inherited TearDown;
end;

procedure TVTOnEditCancelledTests.TestAddColumn;
var
  LBeforeColumnCount: Integer;
  LAfterColumnCount: Integer;
begin
  LBeforeColumnCount := fTree.Header.Columns.Count;
  fTree.Header.Columns.Add;
  LAfterColumnCount := fTree.Header.Columns.Count;
  AssertEquals(1, LAfterColumnCount - LBeforeColumnCount);
end;

procedure TVTOnEditCancelledTests.TestEditNode;
var
  LNode: PVirtualNode;
  LEditNodeResult: Boolean;
  LAfterStates: TVirtualTreeStates;
begin
  fForm.Show;
  fTree.TreeOptions.MiscOptions := fTree.TreeOptions.MiscOptions + [toEditable];
  fTree.Parent := fForm;
  fTree.Header.Columns.Add;
  LNode := fTree.AddChild(fTree.RootNode);
  LEditNodeResult := fTree.EditNode(LNode, 0);
  LAfterStates := fTree.TreeStates;
  AssertTrue(tsEditing in LAfterStates);
  AssertTrue(LEditNodeResult);
end;

procedure TVTOnEditCancelledTests.TestEditNodeFail;
var
  LNode: PVirtualNode;
  LEditNodeResult: Boolean;
begin
  fForm.Show;
  fTree.TreeOptions.MiscOptions := fTree.TreeOptions.MiscOptions - [toEditable];
  fTree.Parent := fForm;
  fTree.Header.Columns.Add;
  LNode := fTree.AddChild(fTree.RootNode);
  LEditNodeResult := fTree.EditNode(LNode, 0);
  AssertFalse(LEditNodeResult);
end;

procedure TVTOnEditCancelledTests.TestEditNodeReadOnly;
var
  LNode: PVirtualNode;
  LEditNodeResult: Boolean;
begin
  fForm.Show;
  fTree.Parent := fForm;
  fTree.Header.Columns.Add;
  LNode := fTree.AddChild(fTree.RootNode);
  fTree.TreeOptions.MiscOptions := fTree.TreeOptions.MiscOptions + [toReadOnly];
  LEditNodeResult := fTree.EditNode(LNode, 0);
  AssertFalse(LEditNodeResult);
end;

procedure TVTOnEditCancelledTests.TestOnEditCancelled;
var
  LNode: PVirtualNode;
begin
  fForm.Show;
  FEditCancelled := False;
  fTree.OnEditCancelled := TreeEditCancelled;
  fTree.TreeOptions.MiscOptions := fTree.TreeOptions.MiscOptions + [toEditable];
  LNode := fTree.AddChild(fTree.RootNode);
  fTree.Parent := fForm;
  fTree.Header.Columns.Add;
  fTree.EditNode(LNode, 0);
  fTree.CancelEditNode;
  AssertTrue(FEditCancelled);
end;

procedure TVTOnEditCancelledTests.TreeEditCancelled(Sender: TBaseVirtualTree;
  Column: TColumnIndex);
begin
  FEditCancelled := True;
end;

initialization
  RegisterTest(TVTOnEditCancelledTests);
end.
