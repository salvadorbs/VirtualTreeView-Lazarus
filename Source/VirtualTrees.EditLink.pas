unit VirtualTrees.EditLink;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, Controls, StdCtrls, LMessages, VirtualTrees.Types, VirtualTrees.BaseTree, VirtualTrees,
  LCLType, LCLIntf;

type
  // Edit support classes.
  TStringEditLink = class;

  { TVTEdit }

  TVTEdit = class(TCustomEdit)
  private
    procedure CMAutoAdjust(var Message: TLMessage); message CM_AUTOADJUST;
    procedure CMExit(var Message: TLMessage); message CM_EXIT;
    procedure CNCommand(var Message: TLMCommand); message CN_COMMAND;
    procedure DoRelease(Data: PtrInt);
    procedure WMChar(var Message: TLMChar); message LM_CHAR;
    procedure WMDestroy(var Message: TLMDestroy); message LM_DESTROY;
    procedure WMGetDlgCode(var Message: TLMNoParams); message LM_GETDLGCODE;
    procedure WMKeyDown(var Message: TLMKeyDown); message LM_KEYDOWN;
  protected
    FRefLink: IVTEditLink;
    FLink: TStringEditLink;
    procedure AutoAdjustSize; virtual;
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(Link: TStringEditLink); reintroduce;

    procedure Release; virtual;

    property AutoSelect;
    property AutoSize;
    property BorderStyle;
    property CharCase;
    //property HideSelection;
    property MaxLength;
    //property OEMConvert;
    property PasswordChar;
  end;

  TStringEditLink = class(TInterfacedObject, IVTEditLink)
  private
    FEdit: TVTEdit;                  // A normal custom edit control.
  protected
    FTree: TCustomVirtualStringTree; // A back reference to the tree calling.
    FNode: PVirtualNode;             // The node to be edited.
    FColumn: TColumnIndex;           // The column of the node.
    FAlignment: TAlignment;
    FTextBounds: TRect;              // Smallest rectangle around the text.
    FStopping: Boolean;              // Set to True when the edit link requests stopping the edit action.
    procedure SetEdit(const Value: TVTEdit); // Setter for the FEdit member;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    property Node  : PVirtualNode read FNode; // [IPK] Make FNode accessible
    property Column: TColumnIndex read FColumn; // [IPK] Make Column(Index) accessible

    function BeginEdit: Boolean; virtual; stdcall;
    function CancelEdit: Boolean; virtual; stdcall;
    property Edit: TVTEdit read FEdit write SetEdit;
    function EndEdit: Boolean; virtual; stdcall;
    function GetBounds: TRect; virtual; stdcall;
    function PrepareEdit(Tree: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex): Boolean; virtual; stdcall;
    procedure ProcessMessage(var Message: TLMessage); virtual; stdcall;
    procedure SetBounds(R: TRect); virtual; stdcall;
  end;

implementation

uses
  Math, Graphics, Forms, Types
  {$ifdef Windows}
  , Windows
  {$endif}
  ;

type
  TCustomVirtualStringTreeCracker = class(TCustomVirtualStringTree);

//----------------- TVTEdit --------------------------------------------------------------------------------------------

// Implementation of a generic node caption editor.

constructor TVTEdit.Create(Link: TStringEditLink);

begin
  inherited Create(nil);
  ShowHint := False;
  ParentShowHint := False;
  // This assignment increases the reference count for the interface.
  FRefLink := Link;
  // This reference is used to access the link.
  FLink := Link;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.CMAutoAdjust(var Message: TLMessage);

begin
  AutoAdjustSize;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.CMExit(var Message: TLMessage);

begin
  if Assigned(FLink) and not FLink.FStopping then
    with TCustomVirtualStringTreeCracker(FLink.FTree) do
    begin
      if (toAutoAcceptEditChange in TreeOptions.StringOptions) then
        DoEndEdit
      else
        DoCancelEdit;
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.CNCommand(var Message: TLMCommand);

begin
  if Assigned(FLink) and Assigned(FLink.FTree) and (Message.NotifyCode = EN_UPDATE) and
    not (vsMultiline in FLink.FNode.States) then
    // Instead directly calling AutoAdjustSize it is necessary on Win9x/Me to decouple this notification message
    // and eventual resizing. Hence we use a message to accomplish that.
    AutoAdjustSize()
  else
    inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.DoRelease(Data: PtrInt);
begin
  Free;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.WMChar(var Message: TLMChar);

begin
  if not (Message.CharCode in [VK_ESCAPE, VK_TAB]) then
    inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.WMDestroy(var Message: TLMDestroy);

begin
  // If editing stopped by other means than accept or cancel then we have to do default processing for
  // pending changes.
  if Assigned(FLink) and not FLink.FStopping then
  begin
    with TCustomVirtualStringTreeCracker(FLink.FTree) do
    begin
      if (toAutoAcceptEditChange in TreeOptions.StringOptions) and Modified then
        Text[FLink.FNode, FLink.FColumn] := FLink.Edit.Text;
    end;
    FLink := nil;
    FRefLink := nil;
  end;

  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.WMGetDlgCode(var Message: TLMNoParams);

begin
  inherited;

  Message.Result := Message.Result or DLGC_WANTALLKEYS or DLGC_WANTTAB or DLGC_WANTARROWS;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.WMKeyDown(var Message: TLMKeyDown);

// Handles some control keys.

var
  Shift: TShiftState;
  EndEdit: Boolean;
  Tree: TBaseVirtualTree;
  NextNode: PVirtualNode;
begin
  Tree := FLink.FTree;
  case Message.CharCode of
    VK_ESCAPE:
      begin
        TCustomVirtualStringTreeCracker(Tree).DoCancelEdit;
        Tree.SetFocus;
      end;
    VK_RETURN:
      begin
        EndEdit := not (vsMultiline in FLink.FNode.States);
        if not EndEdit then
        begin
          // If a multiline node is being edited the finish editing only if Ctrl+Enter was pressed,
          // otherwise allow to insert line breaks into the text.
          Shift := KeyDataToShiftState(Message.KeyData);
          EndEdit := ssCtrl in Shift;
        end;
        if EndEdit then
        begin
          Tree := TCustomVirtualStringTreeCracker(FLink.FTree);
          TCustomVirtualStringTreeCracker(FLink.FTree).InvalidateNode(FLink.FNode);
          TCustomVirtualStringTreeCracker(FLink.FTree).DoEndEdit;
          Tree.SetFocus;
        end;
      end;
    VK_UP:
      begin
        if not (vsMultiline in FLink.FNode.States) then
          Message.CharCode := VK_LEFT;
        inherited;
      end;
    VK_DOWN:
      begin
        if not (vsMultiline in FLink.FNode.States) then
          Message.CharCode := VK_RIGHT;
        inherited;
      end;
    VK_TAB:
      begin
        if Tree.IsEditing then
        begin
          Tree.InvalidateNode(FLink.FNode);
          NextNode := Tree.GetNextVisible(FLink.FNode, True);
          Tree.EndEditNode;
          Tree.FocusedNode := NextNode;
          if Tree.CanEdit(Tree.FocusedNode, Tree.FocusedColumn) then
            TCustomVirtualStringTreeCracker(Tree).DoEdit;
        end;
      end;
    Ord('A'):
      begin
        if Tree.IsEditing and ([ssCtrl] = KeyDataToShiftState(Message.KeyData) {KeyboardStateToShiftState}) then
        begin
          Self.SelectAll();
          Message.CharCode := 0;
        end;
      end;
  else
    inherited;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.AutoAdjustSize;

// Changes the size of the edit to accomodate as much as possible of its text within its container window.
// NewChar describes the next character which will be added to the edit's text.

var
  DC: HDC;
  Size: TSize;
  LastFont: THandle;

begin
  if not (vsMultiline in FLink.FNode.States) and not (toGridExtensions in TCustomVirtualStringTreeCracker(FLink.FTree).TreeOptions.MiscOptions{see issue #252}) then
  begin
    DC := GetDC(Handle);
    LastFont := SelectObject(DC, Font.Reference.Handle);
    try
      // Read needed space for the current text.
      GetTextExtentPoint32(DC, PChar(Text), Length(Text), Size);
      Inc(Size.cx, 2 * TCustomVirtualStringTreeCracker(FLink.FTree).TextMargin);
      Inc(Size.cy, 2 * TCustomVirtualStringTreeCracker(FLink.FTree).TextMargin);
      Height := Max(Size.cy, Height); // Ensure a minimum height so that the edit field's content and cursor are displayed correctly. See #159
      // Repaint associated node if the edit becomes smaller.
      if Size.cx < Width then
        FLink.FTree.Invalidate();

      if FLink.FAlignment = taRightJustify then
        FLink.SetBounds(Types.Rect(Left + Width - Size.cx, Top, Left + Width, Top + Height))
      else
        FLink.SetBounds(Types.Rect(Left, Top, Left + Size.cx, Top + Height));
    finally
      SelectObject(DC, LastFont);
      ReleaseDC(Handle, DC);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.CreateParams(var Params: TCreateParams);

begin
  inherited;

  // Only with multiline style we can use the text formatting rectangle.
  // This does not harm formatting as single line control, if we don't use word wrapping.
  with Params do
  begin
    //todo: delphi uses Multiline for all
    //Style := Style or ES_MULTILINE;
    if vsMultiline in FLink.FNode.States then
    begin
      Style := Style and not (ES_AUTOHSCROLL or WS_HSCROLL) or WS_VSCROLL or ES_AUTOVSCROLL;
      Style := Style or ES_MULTILINE;
    end;
    if tsUseThemes in FLink.FTree.TreeStates then
    begin
      Style := Style and not WS_BORDER;
      ExStyle := ExStyle or WS_EX_CLIENTEDGE;
    end
    else
    begin
      Style := Style or WS_BORDER;
      ExStyle := ExStyle and not WS_EX_CLIENTEDGE;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTEdit.Release;

begin
  if HandleAllocated then
    Application.QueueAsyncCall(DoRelease, 0);
end;

//----------------- TStringEditLink ------------------------------------------------------------------------------------

constructor TStringEditLink.Create;

begin
  inherited;
  FEdit := TVTEdit.Create(Self);
  with FEdit do
  begin
    Visible := False;
    BorderStyle := bsSingle;
    AutoSize := False;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TStringEditLink.Destroy;

begin
  if Assigned(FEdit) then
    FEdit.Release;
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TStringEditLink.BeginEdit: Boolean;

// Notifies the edit link that editing can start now. descendants may cancel node edit
// by returning False.

begin
  Result := not FStopping;
  if Result then
  begin
    FEdit.Show;
    FEdit.SelectAll;
    FEdit.SetFocus;
    FEdit.AutoAdjustSize;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TStringEditLink.SetEdit(const Value: TVTEdit);

begin
  if Assigned(FEdit) then
    FEdit.Free;
  FEdit := Value;
end;

//----------------------------------------------------------------------------------------------------------------------

function TStringEditLink.CancelEdit: Boolean;

begin
  Result := not FStopping;
  if Result then
  begin
    FStopping := True;
    FEdit.Hide;
    FTree.CancelEditNode;
    FEdit.FLink := nil;
    FEdit.FRefLink := nil;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TStringEditLink.EndEdit: Boolean;

begin
  Result := not FStopping;
  if Result then
  try
    FStopping := True;
    if FEdit.Modified then
      FTree.Text[FNode, FColumn] := FEdit.Text;
    FEdit.Hide;
    FEdit.FLink := nil;
    FEdit.FRefLink := nil;
  except
    FStopping := False;
    raise;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TStringEditLink.GetBounds: TRect;

begin
  Result := FEdit.BoundsRect;
end;

//----------------------------------------------------------------------------------------------------------------------

function TStringEditLink.PrepareEdit(Tree: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex): Boolean;

// Retrieves the true text bounds from the owner tree.

var
  Text: String;

begin
  Result := Tree is TCustomVirtualStringTree;
  if Result then
  begin
    if not Assigned(FEdit) then
    begin
      FEdit := TVTEdit.Create(Self);
      FEdit.Visible := False;
      FEdit.BorderStyle := bsSingle;
      FEdit.AutoSize := False;
    end;
    FTree := Tree as TCustomVirtualStringTree;
    FNode := Node;
    FColumn := Column;
    // Initial size, font and text of the node.
    FTree.GetTextInfo(Node, Column, FEdit.Font, FTextBounds, Text);
    FEdit.Font.Color := clWindowText;
    FEdit.Parent := Tree;
    FEdit.HandleNeeded;
    FEdit.Text := Text;

    if Column <= NoColumn then
    begin
      FEdit.BidiMode := FTree.BidiMode;
      FAlignment := TCustomVirtualStringTreeCracker(FTree).Alignment;
    end
    else
    begin
      FEdit.BidiMode := TCustomVirtualStringTreeCracker(FTree).Header.Columns[Column].BidiMode;
      FAlignment := TCustomVirtualStringTreeCracker(FTree).Header.Columns[Column].Alignment;
    end;

    if FEdit.BidiMode <> bdLeftToRight then
      ChangeBidiModeAlignment(FAlignment);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TStringEditLink.ProcessMessage(var Message: TLMessage);

begin
  FEdit.WindowProc(Message);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TStringEditLink.SetBounds(R: TRect);

// Sets the outer bounds of the edit control and the actual edit area in the control.

var
  lOffset: Integer;

begin
  if not FStopping then
  begin
    // Set the edit's bounds but make sure there's a minimum width and the right border does not
    // extend beyond the parent's left/right border.
    if R.Left < 0 then
      R.Left := 0;
    if R.Right - R.Left < 30 then
    begin
      if FAlignment = taRightJustify then
        R.Left := R.Right - 30
      else
        R.Right := R.Left + 30;
    end;
    if R.Right > FTree.ClientWidth then
      R.Right := FTree.ClientWidth;
    FEdit.BoundsRect := R;

    // The selected text shall exclude the text margins and be centered vertically.
    // We have to take out the two pixel border of the edit control as well as a one pixel "edit border" the
    // control leaves around the (selected) text.
    R := FEdit.ClientRect;
    lOffset := IfThen(vsMultiline in FNode.States, 0, 2);
    if tsUseThemes in TCustomVirtualStringTreeCracker(FTree).TreeStates then
      Inc(lOffset);
    InflateRect(R, -TCustomVirtualStringTreeCracker(FTree).TextMargin + lOffset, lOffset);
    if not (vsMultiline in FNode.States) then
      OffsetRect(R, 0, FTextBounds.Top - FEdit.Top);
    R.Top := Max(-1, R.Top); // A value smaller than -1 will prevent the edit cursor from being shown by Windows, see issue #159
    R.Left := Max(-1, R.Left);
    SendMessage(FEdit.Handle, EM_SETRECTNP, 0, LPARAM(@R));
  end;
end;

end.
