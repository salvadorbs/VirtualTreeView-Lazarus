unit VTHeaderCursorTests;

// Regression tests for the header splitter cursor.
//
// TVTHeader sets Treeview.Cursor to crHSplit/crVSplit while the mouse is over
// a resizable column/header border. The cursor is a property of the whole tree,
// so it must be restored when the mouse leaves the splitter or the header.
// Otherwise the split cursor stays active for the entire tree - even over the
// node area - until something else changes Tree.Cursor.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Controls,
  Forms,
  Graphics,
  LCLType,
  LMessages,
  VirtualTrees,
  VirtualTrees.Types;

type
  TVTHeaderCursorTests = class(TTestCase)
  strict private
    FForm: TForm;
    FTree: TVirtualStringTree;
    procedure SendMouseMove(X, Y: Integer);
    function SplitterX: Integer;
    function HeaderY: Integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure HoveringColumnSplitterUsesHSplitCursor;
    procedure HoveringHeaderHeightSplitterUsesVSplitCursor;
    procedure LeavingColumnSplitterRestoresDefaultCursor;
    procedure LeavingColumnSplitterRestoresApplicationCursor;
    procedure LeavingTreeRestoresDefaultCursor;
    procedure MovingIntoTreeBodyRestoresDefaultCursor;
  end;

implementation

uses
  SysUtils;

procedure TVTHeaderCursorTests.SetUp;
var
  I: Integer;
begin
  inherited SetUp;

  FForm := TForm.Create(nil);
  FForm.SetBounds(0, 0, 420, 300);

  FTree := TVirtualStringTree.Create(FForm);
  FTree.Parent := FForm;
  FTree.SetBounds(10, 10, 380, 240);
  for I := 0 to 1 do
  begin
    FTree.Header.Columns.Add;
    FTree.Header.Columns[I].Width := 100;
  end;
  FTree.Header.Options := FTree.Header.Options + [hoVisible, hoColumnResize];
  FTree.RootNodeCount := 3;

  FForm.Show;
  Application.ProcessMessages;
end;

procedure TVTHeaderCursorTests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(FForm);
  FTree := nil;
end;

function TVTHeaderCursorTests.SplitterX: Integer;
begin
  // Left edge of the second column = right edge of the first one.
  Result := FTree.Header.Columns[1].Left;
end;

function TVTHeaderCursorTests.HeaderY: Integer;
begin
  Result := FTree.Header.Height div 2;
end;

procedure TVTHeaderCursorTests.SendMouseMove(X, Y: Integer);
var
  LParam: PtrInt;
begin
  LParam := PtrInt(Word(X)) or (PtrInt(Word(Y)) shl 16);
  FTree.Perform(LM_MOUSEMOVE, 0, LParam);
  Application.ProcessMessages;
end;

procedure TVTHeaderCursorTests.HoveringColumnSplitterUsesHSplitCursor;
begin
  SendMouseMove(SplitterX, HeaderY);

  AssertEquals('Hovering a column splitter must show the horizontal split cursor.',
    crHSplit, FTree.Cursor);
end;

procedure TVTHeaderCursorTests.HoveringHeaderHeightSplitterUsesVSplitCursor;
begin
  FTree.Header.Options := FTree.Header.Options + [hoHeightResize];

  SendMouseMove(50, FTree.Header.Height - 1);
  AssertEquals('Hovering the header height splitter must show the vertical split cursor.',
    crVSplit, FTree.Cursor);

  SendMouseMove(50, HeaderY);
  AssertEquals('Moving away from the header height splitter must restore the default cursor.',
    crDefault, FTree.Cursor);
end;

procedure TVTHeaderCursorTests.LeavingColumnSplitterRestoresDefaultCursor;
begin
  SendMouseMove(SplitterX, HeaderY);
  AssertEquals('Sanity: the splitter cursor must be active.', crHSplit, FTree.Cursor);

  SendMouseMove(50, HeaderY);

  AssertEquals('Moving away from the splitter must restore the default cursor. ' +
    'The header sets Tree.Cursor, which is the cursor of the whole control, so ' +
    'leaving it set makes the split cursor stick over the node area.',
    crDefault, FTree.Cursor);
end;

procedure TVTHeaderCursorTests.LeavingColumnSplitterRestoresApplicationCursor;
begin
  FTree.Cursor := crCross;

  SendMouseMove(SplitterX, HeaderY);
  AssertEquals('Sanity: the splitter cursor must be active.', crHSplit, FTree.Cursor);

  SendMouseMove(50, HeaderY);

  AssertEquals('The header must restore the cursor defined by the application, ' +
    'not blindly reset it to crDefault.',
    crCross, FTree.Cursor);
end;

procedure TVTHeaderCursorTests.LeavingTreeRestoresDefaultCursor;
begin
  SendMouseMove(SplitterX, HeaderY);
  AssertEquals('Sanity: the splitter cursor must be active.', crHSplit, FTree.Cursor);

  FTree.Perform(CM_MOUSELEAVE, 0, 0);
  Application.ProcessMessages;

  AssertEquals('Leaving the control while over a splitter must restore the cursor, ' +
    'otherwise the tree re-enters with the split cursor still set.',
    crDefault, FTree.Cursor);
end;

procedure TVTHeaderCursorTests.MovingIntoTreeBodyRestoresDefaultCursor;
begin
  SendMouseMove(SplitterX, HeaderY);
  AssertEquals('Sanity: the splitter cursor must be active.', crHSplit, FTree.Cursor);

  SendMouseMove(50, FTree.Header.Height + 40);

  AssertEquals('Leaving the header for the tree body must restore the default cursor.',
    crDefault, FTree.Cursor);
end;

initialization
  RegisterTest(TVTHeaderCursorTests);

end.
