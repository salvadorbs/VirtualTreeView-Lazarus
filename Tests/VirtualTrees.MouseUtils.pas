unit VirtualTrees.MouseUtils;

// FPCUnit/LCL port of the upstream Delphi helper used by the cell selection tests.
// Original: Tests/VirtualTrees.MouseUtils.pas (Virtual-TreeView V8.4).
//
// The upstream version drives the tree through Windows messages and the global
// keyboard state. Under LCL the equivalent is to send LM_LBUTTONDOWN/LM_LBUTTONUP
// directly to the control: TControl.WMLButtonDown is the message handler for
// LM_LBUTTONDOWN and TLMMouse.Keys maps onto the message WParam, so the MK_*
// flags (MK_CONTROL/MK_SHIFT) are seen by the tree as the matching shift state.

interface

uses
  VirtualTrees,
  VirtualTrees.Types,
  Types;

type

  /// <summary>
  /// Created to be used only for testing
  /// </summary>
  TCustomVirtualStringTreeMouseHelper = class helper for TCustomVirtualStringTree
  public
    function GetDisplayRectEx(ANode: PVirtualNode; AColumn: TColumnIndex): TPoint;

    procedure MouseClick(ACursorPos: TPoint; Modifiers: Byte = 0); overload;
    procedure MouseClick(ANode: PVirtualNode; AColumn: TColumnIndex = 0; Modifiers: Byte = 0); overload;

    procedure CtrlMouseClick(ACursorPos: TPoint); overload;
    procedure CtrlMouseClick(ANode: PVirtualNode; AColumn: TColumnIndex = 0); overload;

    procedure ShiftMouseClick(ANode: PVirtualNode; AColumn: TColumnIndex = 0);
  end;

implementation

uses
  SysUtils,
  Forms,
  LCLType,
  LMessages;

function MakeLParamEx(X, Y: Integer): PtrInt; inline;
begin
  Result := PtrInt(Word(X)) or (PtrInt(Word(Y)) shl 16);
end;

{ TCustomVirtualStringTreeMouseHelper }

function TCustomVirtualStringTreeMouseHelper.GetDisplayRectEx(
  ANode: PVirtualNode; AColumn: TColumnIndex): TPoint;
var
  R: TRect;
  LRight: TDimension;
begin
  if not Assigned(ANode) then
  begin
    Result := Point(0, 0);
    Exit;
  end;

  // Use the full-row rect to get a reliable Y coordinate for hit testing.
  R := GetDisplayRect(ANode, NoColumn, False, False, False);

  if IsRectEmpty(R) then
  begin
    Exit(Point(0, 0));
  end;

  Result.Y := R.Top + (R.Bottom - R.Top) div 2;
  Header.Columns.GetColumnBounds(AColumn, Result.X, LRight);

  // If the header is visible the client coordinates for hit testing are below it.
  if hoVisible in Header.Options then
    Inc(Result.Y, Header.Height);
end;

procedure TCustomVirtualStringTreeMouseHelper.MouseClick(ACursorPos: TPoint;
  Modifiers: Byte);
var
  LParam: PtrInt;
begin
  LParam := MakeLParamEx(ACursorPos.X, ACursorPos.Y);
  Perform(LM_LBUTTONDOWN, MK_LBUTTON or Modifiers, LParam);
  Perform(LM_LBUTTONUP, MK_LBUTTON or Modifiers, LParam);
end;

procedure TCustomVirtualStringTreeMouseHelper.MouseClick(ANode: PVirtualNode;
  AColumn: TColumnIndex; Modifiers: Byte);
var
  LClientRect: TRect;
  LHitInfo: THitInfo;
  LTopLeft: TPoint;
  LPasses, LCount: Integer;
begin
  if not Assigned(ANode) then
    Exit;

  LClientRect := GetDisplayRect(ANode, AColumn, True, True, True);
  LTopLeft := LClientRect.TopLeft;
  if hoVisible in Header.Options then
    Inc(LTopLeft.Y, Header.Height);

  LPasses := 0;
  LCount := VisibleCount;
  repeat
    GetHitTestInfoAt(LTopLeft.X, LTopLeft.Y, True, LHitInfo, []);
    if Assigned(LHitInfo.HitNode) and (LHitInfo.HitNode <> ANode) then
      Inc(LTopLeft.Y, LHitInfo.HitNode.NodeHeight);
    Inc(LPasses); // Prevent forever loop
  until (LHitInfo.HitNode = ANode) or (LPasses > LCount);
  Assert((LHitInfo.HitNode = ANode) and (LHitInfo.HitColumn = AColumn));

  MouseClick(LTopLeft, Modifiers);
end;

procedure TCustomVirtualStringTreeMouseHelper.CtrlMouseClick(ACursorPos: TPoint);
begin
  MouseClick(ACursorPos, MK_CONTROL);
end;

procedure TCustomVirtualStringTreeMouseHelper.CtrlMouseClick(ANode: PVirtualNode;
  AColumn: TColumnIndex);
begin
  MouseClick(ANode, AColumn, MK_CONTROL);
end;

procedure TCustomVirtualStringTreeMouseHelper.ShiftMouseClick(ANode: PVirtualNode;
  AColumn: TColumnIndex);
begin
  MouseClick(ANode, AColumn, MK_SHIFT);
end;

end.
