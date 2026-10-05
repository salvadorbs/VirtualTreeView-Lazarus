unit VTScrollRangeIssue983Tests;

// Regression test for issue #983 "Vertical Scroll Bar Cannot Scroll To Bottom In
// Select Circumstances".
//
// Without columns the horizontal scroll range is the width of the currently
// visible nodes. When the only over-wide node scrolls out of view, the range
// shrinks, the horizontal scroll bar disappears, the taller client area clamps
// the vertical offset back up - which scrolls the wide node into view again and
// brings the bar back. The tree oscillates between both states and the user can
// never reach the bottom.
//
// The fix makes the horizontal range grow-only while the update is caused by
// scrolling; every other trigger (resize, structure change) recomputes it from
// scratch as before. The tests assert both halves of that contract.
//
// FPCUnit/LCL port of the upstream DUnitX test. The upstream version detects the
// horizontal scroll bar through the Win32 window style (GetWindowLong/GWL_STYLE);
// the LCL port computes the same condition from the public RangeX property, which
// is exactly the quantity the fix governs. Scrolling is driven with LM_VSCROLL,
// the LCL counterpart of WM_VSCROLL.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Types,
  Controls,
  Forms,
  Graphics,
  VirtualTrees;

type
  TVTScrollRangeIssue983Tests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
    procedure OnGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType; var CellText: string);
    function HorzBarVisible: Boolean;
    procedure ScrollToBottom;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// The core symptom: line-scrolling down must reach the last node.
    procedure ScrollToBottomReachesLastNode;

    /// Releasing the scroll bar (SB_ENDSCROLL) must not pull the position back up.
    procedure EndScrollKeepsPosition;

    /// The other half of the contract: enlarging the window must still recompute
    /// the range from scratch and drop the horizontal scroll bar.
    procedure WideningTheWindowDropsHorizontalScrollBar;
  end;

implementation

uses
  SysUtils,
  LCLType,
  LMessages,
  VirtualTrees.Types;

procedure TVTScrollRangeIssue983Tests.SetUp;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 320, 160);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.Align := alClient;
  fTree.BorderStyle := bsNone;
  fTree.DefaultNodeHeight := 18;
  fTree.OnGetText := OnGetText;
  // Node 0 is the only node wider than the client area; six short nodes below make
  // the tree just tall enough that node 0 can scroll completely out of view.
  fTree.RootNodeCount := 7;
  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTScrollRangeIssue983Tests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

procedure TVTScrollRangeIssue983Tests.OnGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
begin
  if Node.Index = 0 then
    CellText := 'A long node name to fill the entire width of the tree window and then some'
  else
    CellText := Format('n%d', [Node.Index]);
end;

function TVTScrollRangeIssue983Tests.HorzBarVisible: Boolean;
begin
  // Without columns the horizontal scroll bar is shown exactly when the widest
  // visible line exceeds the client width; RangeX is that width. This mirrors the
  // upstream GetWindowLong(Handle, GWL_STYLE) and WS_HSCROLL check without
  // depending on Win32 window styles.
  Result := fTree.RangeX > fTree.ClientWidth;
end;

procedure TVTScrollRangeIssue983Tests.ScrollToBottom;
var
  I: Integer;
  LastOffsetY: TDimension;
begin
  LastOffsetY := 1; // never a valid offset, forces at least two iterations
  for I := 1 to 20 do
  begin
    fTree.Perform(LM_VSCROLL, SB_LINEDOWN, 0);
    Application.ProcessMessages;
    if fTree.OffsetY = LastOffsetY then
      Break;
    LastOffsetY := fTree.OffsetY;
  end;
end;

procedure TVTScrollRangeIssue983Tests.ScrollToBottomReachesLastNode;
var
  R: TRect;
begin
  AssertTrue('Sanity: the over-wide node 0 must produce a horizontal scroll bar.', HorzBarVisible);
  ScrollToBottom;
  R := fTree.GetDisplayRect(fTree.GetLast, NoColumn, False);
  AssertTrue(Format('After scrolling down the last node (%d..%d) must be fully inside the client area (height %d) - issue #983.',
    [R.Top, R.Bottom, fTree.ClientHeight]), R.Bottom <= fTree.ClientHeight);
end;

procedure TVTScrollRangeIssue983Tests.EndScrollKeepsPosition;
var
  OffsetAtBottom: TDimension;
begin
  ScrollToBottom;
  OffsetAtBottom := fTree.OffsetY;
  fTree.Perform(LM_VSCROLL, SB_ENDSCROLL, 0);
  Application.ProcessMessages;
  AssertEquals('Releasing the scroll bar must not pull the scroll position back up (issue #983).',
    Integer(OffsetAtBottom), Integer(fTree.OffsetY));
end;

procedure TVTScrollRangeIssue983Tests.WideningTheWindowDropsHorizontalScrollBar;
begin
  AssertTrue('Sanity: the over-wide node 0 must produce a horizontal scroll bar.', HorzBarVisible);
  fForm.Width := fForm.Width + 400;
  Application.ProcessMessages;
  AssertFalse('After enlarging the window no node is over-wide anymore, the horizontal scroll bar must disappear.',
    HorzBarVisible);
end;

initialization
  RegisterTest(TVTScrollRangeIssue983Tests);

end.
