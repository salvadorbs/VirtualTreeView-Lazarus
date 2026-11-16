unit VTDefaultNodeHeightIssue1375Tests;

// Regression tests for issue #1375 "SetDefaultNodeHeight in loading a invisible
// virtual tree view visible".
//
// For issue #1341, SetDefaultNodeHeight() calls HandleNeeded() when
// toAutoChangeScale is set, so that a DefaultNodeHeight assigned at runtime is
// not overwritten by AutoScale() when the window handle is created later.
//
// TControl.ReadState() assigns the Parent before the properties are read from
// the DFM. Therefore the window handles of the tree and of all its parents were
// created in the middle of loading the DFM, whenever DefaultNodeHeight was
// stored in it. If the topmost parent is not a form, e.g. a frame that is
// created at runtime and gets its Parent only after construction, creating the
// handle even raised EInvalidOperation "Control '...' has no parent window".
// The same happened at runtime when DefaultNodeHeight was assigned to a tree
// whose parent did not have a parent itself.
//
// FPCUnit/LCL port of the upstream DUnitX test. The component text is the same
// as in the upstream test; LCL streams it through ObjectTextToBinary() and
// ReadComponent() like the VCL does.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Controls,
  ExtCtrls,
  Forms,
  VirtualTrees,
  VirtualTrees.Types;

type
  TVTDefaultNodeHeightIssue1375Tests = class(TTestCase)
  strict private
    /// Reads the given component text into the existing root component, like
    /// InitInheritedComponent() does with the resource of a form or frame.
    procedure LoadFromComponentText(aRoot: TComponent; const aText: string);
    function FindTree(aRoot: TComponent): TVirtualStringTree;
    procedure AssertSettingDefaultNodeHeightDoesNotRaise(aTree: TVirtualStringTree);
  published
    /// Loading a tree with a stored DefaultNodeHeight from a component
    /// resource must not create its window handle while loading.
    procedure LoadingDoesNotCreateWindowHandle;

    /// Loading a frame that has no parent yet must not raise an exception,
    /// e.g. TMyFrame.Create(Self) before assigning the Parent of the frame.
    procedure LoadingFrameWithoutParentDoesNotRaise;

    /// Assigning DefaultNodeHeight at runtime to a tree whose parent has no
    /// parent itself must not raise an exception.
    procedure SetDefaultNodeHeightInParentlessContainerDoesNotRaise;

    /// Guards the behavior of issue #1341: a DefaultNodeHeight assigned at
    /// runtime before the window handle exists must be kept for the nodes,
    /// although toAutoChangeScale is set.
    procedure DefaultNodeHeightSetAtRuntimeIsKept;
  end;

implementation

uses
  SysUtils;

const
  cStoredNodeHeight = 30; // differs from cInitialDefaultNodeHeight, so it is stored in the DFM

  cFormDfm =
    'object Issue1375Form: TForm' + sLineBreak +
    '  object Tree: TVirtualStringTree' + sLineBreak +
    '    DefaultNodeHeight = 30' + sLineBreak +
    '  end' + sLineBreak +
    'end';

  cFrameDfm =
    'object Issue1375Frame: TFrame' + sLineBreak +
    '  object Tree: TVirtualStringTree' + sLineBreak +
    '    DefaultNodeHeight = 30' + sLineBreak +
    '  end' + sLineBreak +
    'end';

procedure TVTDefaultNodeHeightIssue1375Tests.LoadFromComponentText(aRoot: TComponent;
  const aText: string);
var
  lTextStream: TStringStream;
  lBinaryStream: TMemoryStream;
begin
  lTextStream := TStringStream.Create(aText);
  lBinaryStream := TMemoryStream.Create;
  try
    ObjectTextToBinary(lTextStream, lBinaryStream);
    lBinaryStream.Position := 0;
    lBinaryStream.ReadComponent(aRoot);
  finally
    lBinaryStream.Free;
    lTextStream.Free;
  end;
end;

function TVTDefaultNodeHeightIssue1375Tests.FindTree(aRoot: TComponent): TVirtualStringTree;
begin
  Result := aRoot.FindComponent('Tree') as TVirtualStringTree;
  AssertNotNull('Sanity: the tree must have been loaded from the component text.', Result);
end;

procedure TVTDefaultNodeHeightIssue1375Tests.AssertSettingDefaultNodeHeightDoesNotRaise(
  aTree: TVirtualStringTree);
begin
  try
    aTree.DefaultNodeHeight := cStoredNodeHeight;
  except
    on E: Exception do
      Fail(Format('Setting DefaultNodeHeight must not raise an exception (issue #1375): %s: %s',
        [E.ClassName, E.Message]));
  end;
end;

procedure TVTDefaultNodeHeightIssue1375Tests.LoadingDoesNotCreateWindowHandle;
var
  lForm: TForm;
  lTree: TVirtualStringTree;
begin
  lForm := TForm.CreateNew(nil);
  try
    LoadFromComponentText(lForm, cFormDfm);
    lTree := FindTree(lForm);
    AssertTrue('Sanity: toAutoChangeScale must be set by default.',
      toAutoChangeScale in lTree.TreeOptions.AutoOptions);
    // Only the handle of the tree is checked: The widgetset creates the handle of the form anyway while loading it.
    AssertFalse('Loading a stored DefaultNodeHeight from a component resource must not create the window handle of the tree (issue #1375).',
      lTree.HandleAllocated);
    AssertEquals('The DefaultNodeHeight from the component resource must have been applied.',
      cStoredNodeHeight, lTree.DefaultNodeHeight);
  finally
    lForm.Free;
  end;
end;

procedure TVTDefaultNodeHeightIssue1375Tests.LoadingFrameWithoutParentDoesNotRaise;
var
  lFrame: TFrame;
begin
  lFrame := TFrame.Create(nil);
  try
    try
      LoadFromComponentText(lFrame, cFrameDfm);
    except
      on E: Exception do
        Fail(Format('Loading a frame without parent that contains a tree with a stored DefaultNodeHeight must not raise an exception (issue #1375): %s: %s',
          [E.ClassName, E.Message]));
    end;
    AssertEquals('The DefaultNodeHeight from the component resource must have been applied.',
      cStoredNodeHeight, FindTree(lFrame).DefaultNodeHeight);
  finally
    lFrame.Free;
  end;
end;

procedure TVTDefaultNodeHeightIssue1375Tests.SetDefaultNodeHeightInParentlessContainerDoesNotRaise;
var
  lPanel: TPanel;
  lTree: TVirtualStringTree;
begin
  lPanel := TPanel.Create(nil);
  try
    lTree := TVirtualStringTree.Create(lPanel);
    lTree.Parent := lPanel;
    AssertSettingDefaultNodeHeightDoesNotRaise(lTree);
    AssertEquals('The DefaultNodeHeight from the component resource must have been applied.',
      cStoredNodeHeight, lTree.DefaultNodeHeight);
  finally
    lPanel.Free;
  end;
end;

procedure TVTDefaultNodeHeightIssue1375Tests.DefaultNodeHeightSetAtRuntimeIsKept;
const
  cNodeHeight = 40;
var
  lForm: TForm;
  lTree: TVirtualStringTree;
  lNode: PVirtualNode;
begin
  lForm := TForm.CreateNew(nil);
  try
    lTree := TVirtualStringTree.Create(lForm);
    lTree.Parent := lForm;
    AssertTrue('Sanity: toAutoChangeScale must be set by default.',
      toAutoChangeScale in lTree.TreeOptions.AutoOptions);
    lTree.DefaultNodeHeight := cNodeHeight;
    lTree.RootNodeCount := 3;
    lForm.Show;
    Application.ProcessMessages;
    AssertEquals('A DefaultNodeHeight set at runtime must be kept (issue #1341).',
      cNodeHeight, lTree.DefaultNodeHeight);
    for lNode in lTree.Nodes do
      AssertEquals('The nodes must use the DefaultNodeHeight set at runtime (issue #1341).',
        cNodeHeight, lNode.NodeHeight);
  finally
    lForm.Free;
  end;
end;

initialization
  // Needed to create the tree from the component text, as TForm and TFrame have no published field of this class.
  RegisterClass(TVirtualStringTree);
  RegisterTest(TVTDefaultNodeHeightIssue1375Tests);

end.
