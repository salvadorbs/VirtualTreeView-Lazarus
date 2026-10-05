unit VTHeaderHintIssue728Tests;

// Regression tests for issue #728 "Header tooltip not always displaying".
//
// The header lives in the window's non-client area, so hovering it produces
// WM_NCMOUSEMOVE messages. While the application's hint window is the stock
// THintWindow, its IsHintMsg cancels the pending hint on every WM_NCMOUSEMOVE
// pulled from the message queue. The header only re-armed the hint pipeline
// (Application.HintMouseMessage) when the hover COLUMN changed, so any further
// mouse movement inside the same column killed the pending hint for good.
//
// Fix (local to TVTHeader, no application-global state):
//  1. Re-arm the hint pipeline on EVERY WM_NCMOUSEMOVE inside the header ...
//  2. ... except while the cursor is inside LastHintRect (a hint was already
//     accepted for this area). Re-entering the pipeline in that state bounces
//     off the LastHintRect short-circuit in CMHintShow, whose rejection makes
//     TApplication.ActivateHint cancel - and thereby hide - the visible hint.
//     This matters because showing the hint window itself posts a synthesized
//     WM_NCMOUSEMOVE at the unchanged cursor position.
//  3. The header's leave detection timer clears LastHintRect (the header band,
//     recognizable by Top < 0 in client coordinates), because the tree itself
//     only notices the departure via CM_MOUSELEAVE after the mouse visited its
//     client area.
//
// FPCUnit/LCL port of the upstream DUnitX test, adapted to how the LCL port
// handles header hints:
// - The LCL header is painted at the top of the client area (not in the
//   non-client area), so header moves arrive as LM_MOUSEMOVE with a positive Y
//   inside the header band.
// - TApplication.HintMouseMessage is a no-op in LCL, so the hint pipeline
//   cannot be observed through CM_HINTSHOWPAUSE counters. Instead the tests
//   observe what the port really does: every header move is dispatched through
//   DoHeaderMouseMove, and the accepted-hint bookkeeping in LastHintRect (which
//   the port's CMHintShow honors as a short-circuit) is preserved by moves
//   inside the header and cleared by the leave detection only for the header
//   band (Top < 0).
// - The port has no header leave-detection timer; leaving is detected when an
//   LM_MOUSEMOVE arrives outside the header, which performs the same
//   LastHintRect clearing as the upstream WM_TIMER tick.

interface

uses
  fpcunit,
  testregistry,
  Classes,
  Types,
  Controls,
  Forms,
  VirtualTrees,
  VirtualTrees.Types;

type
  TVTHeaderHintIssue728Tests = class(TTestCase)
  strict private
    FForm: TForm;
    FTree: TVirtualStringTree;
    FHeaderMouseMoveCount: Integer;
    procedure HeaderMouseMove(Sender: TVTHeader; Shift: TShiftState; X, Y: TDimension);
    procedure SendHeaderMouseMove(OffsetX: Integer);
    procedure SendClientMouseMove;
    function HeaderBandRect: TRect;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// Every LM_MOUSEMOVE inside the header must be dispatched, even if the
    /// hover column did not change. Handling moves only on column changes left
    /// the hint pipeline unarmed - the core unreliability of issue #728.
    procedure HeaderMouseMoveFiresOnEveryHeaderMove;

    /// While the accepted hint rectangle covers the header band, moves inside
    /// the header must leave it alone: disturbing it would break the
    /// LastHintRect short-circuit in CMHintShow that protects the visible hint.
    procedure HeaderMoveInsideLastHintRectPreservesIt;

    /// The header's leave detection must clear a header-band LastHintRect,
    /// otherwise no hint is shown on the next visit to the header (the tree
    /// only gets CM_MOUSELEAVE after the mouse visited its client area).
    procedure HeaderLeaveDetectionClearsLastHintRect;

    /// The leave detection must only clear the HEADER band (Top < 0). A hint
    /// rectangle inside the client area belongs to the node hint bookkeeping
    /// and is left alone.
    procedure HeaderLeaveDetectionKeepsClientAreaHintRect;
  end;

implementation

uses
  SysUtils,
  LCLType,
  LMessages,
  VirtualTrees.BaseTree;

type
  TTreeCracker = class(TVirtualStringTree); // reach the protected LastHintRect

procedure TVTHeaderHintIssue728Tests.SetUp;
begin
  inherited SetUp;

  FForm := TForm.Create(nil);
  FForm.SetBounds(0, 0, 420, 300);

  FTree := TVirtualStringTree.Create(FForm);
  FTree.Parent := FForm;
  FTree.SetBounds(20, 20, 360, 220);
  FTree.Header.Options := FTree.Header.Options + [hoVisible, hoShowHint];
  FTree.Header.Columns.Add;
  FTree.Header.Columns[0].Text := 'Column 0';
  FTree.Header.Columns[0].Hint := 'Header column hint';
  FTree.Header.Columns[0].Width := 340;
  FTree.ShowHint := True;
  FTree.OnHeaderMouseMove := HeaderMouseMove;
  FForm.Show;
  Application.ProcessMessages;

  FHeaderMouseMoveCount := 0;
  Application.CancelHint;
end;

procedure TVTHeaderHintIssue728Tests.TearDown;
begin
  inherited TearDown;

  Application.CancelHint; // do not leave an armed hint timer behind
  FreeAndNil(FForm);
  FTree := nil;
end;

procedure TVTHeaderHintIssue728Tests.HeaderMouseMove(Sender: TVTHeader;
  Shift: TShiftState; X, Y: TDimension);
begin
  Inc(FHeaderMouseMoveCount);
end;

procedure TVTHeaderHintIssue728Tests.SendHeaderMouseMove(OffsetX: Integer);
var
  LParam: PtrInt;
begin
  // Middle of the first header column, vertically centered in the header band.
  // The LCL header lives in the client area, so Y is positive (VCL uses a
  // negative Y in the non-client area).
  LParam := PtrInt(Word(FTree.ClientWidth div 2 + OffsetX)) or
    (PtrInt(Word(FTree.Header.Height div 2)) shl 16);
  FTree.Perform(LM_MOUSEMOVE, 0, LParam);
end;

procedure TVTHeaderHintIssue728Tests.SendClientMouseMove;
var
  LParam: PtrInt;
begin
  // Client area below the header: this is where the port detects leaving.
  LParam := PtrInt(Word(FTree.ClientWidth div 2)) or
    (PtrInt(Word(FTree.Header.Height + 60)) shl 16);
  FTree.Perform(LM_MOUSEMOVE, 0, LParam);
end;

function TVTHeaderHintIssue728Tests.HeaderBandRect: TRect;
begin
  // The header band in client coordinates, as CMHintShow stores it in
  // LastHintRect when a header hint is accepted (Top < 0, small positive
  // Bottom for the splitter allowance).
  Result := Rect(0, -Integer(FTree.Header.Height), FTree.ClientWidth, 2);
end;

procedure TVTHeaderHintIssue728Tests.HeaderMouseMoveFiresOnEveryHeaderMove;
begin
  SendHeaderMouseMove(0);
  AssertEquals('Sanity: entering the header must dispatch a header mouse move.',
    1, FHeaderMouseMoveCount);

  // Same hover column as before - no column change involved.
  SendHeaderMouseMove(4);
  AssertEquals('A mouse move inside the same header column must still be dispatched, ' +
    'otherwise a hint cancelled while pointing at the header is never re-armed ' +
    'and no header tooltip appears (issue #728).',
    2, FHeaderMouseMoveCount);
end;

procedure TVTHeaderHintIssue728Tests.HeaderMoveInsideLastHintRectPreservesIt;
begin
  // A header hint was already accepted for the whole header band.
  TTreeCracker(FTree).LastHintRect := HeaderBandRect;

  SendHeaderMouseMove(0);
  AssertTrue('While the accepted hint rectangle covers the header the move must ' +
    'not disturb it: resetting it here would break the LastHintRect short-circuit ' +
    'in CMHintShow that protects the visible hint (issue #728).',
    EqualRect(HeaderBandRect, TTreeCracker(FTree).LastHintRect));
end;

procedure TVTHeaderHintIssue728Tests.HeaderLeaveDetectionClearsLastHintRect;
begin
  TTreeCracker(FTree).LastHintRect := HeaderBandRect;

  SendClientMouseMove;

  AssertTrue('Leaving the header must clear a header-band LastHintRect so the next visit ' +
    'can show a hint again - the tree only receives CM_MOUSELEAVE after the ' +
    'mouse visited its client area (issue #728).',
    IsRectEmpty(TTreeCracker(FTree).LastHintRect));
end;

procedure TVTHeaderHintIssue728Tests.HeaderLeaveDetectionKeepsClientAreaHintRect;
var
  NodeRect: TRect;
begin
  NodeRect := Rect(10, 20, 200, 40); // a node hint rectangle, Top >= 0
  TTreeCracker(FTree).LastHintRect := NodeRect;

  SendClientMouseMove;

  AssertTrue('The header leave detection must only reset the header band (Top < 0); ' +
    'node hint bookkeeping in the client area is none of its business.',
    EqualRect(NodeRect, TTreeCracker(FTree).LastHintRect));
end;

initialization
  RegisterTest(TVTHeaderHintIssue728Tests);

end.
