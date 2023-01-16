unit VirtualTrees.BaseAncestorLcl;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, Controls, Graphics,
  {$ifdef Windows}
  Windows,
  ActiveX,
  CommCtrl,
  UxTheme,
  {$else}
  FakeActiveX,
  {$endif}
  DelphiCompat,
  {$ifdef EnableAccessible}
  oleacc, // for MSAA IAccessible support
  {$endif}
  VirtualTrees.Types,
  LCLIntf,
  LCLType,
  Types;

type

  { TVTBaseAncestorLcl }

  TVTBaseAncestorLcl = class abstract(TCustomControl)
  private
    {$ifdef EnableAccessible}
    // MSAA support
    FAccessible: IAccessible;                    // The IAccessible interface to the window itself.
    FAccessibleItem: IAccessible;                // The IAccessible to the item that currently has focus.
    FAccessibleName: string;                     // The name the window is given for screen readers.
    {$endif}
    FDottedBrushTreeLines: TBrush;               // used to paint dotted lines without special pens

    function GetDottedBrushGridLines: TBrush;
  protected // methods
    function DoRenderOLEData(const FormatEtcIn: TFormatEtc; out Medium: TStgMedium; ForClipboard: Boolean): HRESULT; virtual; abstract;
    function RenderOLEData(const FormatEtcIn: TFormatEtc; out Medium: TStgMedium; ForClipboard: Boolean): HResult; virtual; abstract;
    procedure NotifyAccessibilityCollapsed(); virtual; abstract;
    function PrepareDottedBrush(CurrentDottedBrush: TBrush; Bits: Pointer; const BitsLinesCount: Word): TBrush; virtual;
  protected //properties
    property DottedBrushTreeLines: TBrush read FDottedBrushTreeLines write FDottedBrushTreeLines;
    property DottedBrushGridLines: TBrush read GetDottedBrushGridLines;
  public // methods
    procedure CopyToClipboard; virtual; abstract;
    procedure CutToClipboard; virtual; abstract;
    function PasteFromClipboard: Boolean; virtual; abstract;

    /// <summary>
    /// Handle less alias for LCLIntf.InvalidateRect
    /// </summary>
    function InvalidateRect(lpRect: PRect; bErase: BOOL): BOOL; inline;
    /// <summary>
    /// Handle less alias for LCLIntf.UpdateWindow
    /// </summary>
    function UpdateWindow(): BOOL; inline;
    /// <summary>
    /// Handle less alias for LCLIntf.RedrawWindow
    /// </summary>
    function RedrawWindow(lprcUpdate: PRect; hrgnUpdate: HRGN; flags: UINT): BOOL; overload; inline;

    /// <summary>
    /// Handle less and with limited parameters version
    /// </summary>
    function SendWM_SETREDRAW(Updating: Boolean): LRESULT; inline;

    /// <summary>
    /// Handle less alias for LCLIntf.ShowScrollBar
    /// </summary>
    procedure ShowScrollBar(Bar: Integer; AShow: Boolean);
    /// <summary>
    /// Handle less alias for LCLIntf.SetScrollInfo
    /// </summary>
    function SetScrollInfo(Bar: Integer; const ScrollInfo: TScrollInfo; Redraw: Boolean): TDimension;
    /// <summary>
    /// Handle less alias for LCLIntf.GetScrollInfo
    /// </summary>
    function GetScrollInfo(Bar: Integer; var ScrollInfo: TScrollInfo): Boolean;
    /// <summary>
    /// Handle less alias for LCLIntf.GetScrollPos
    /// </summary>
    function GetScrollPos(Bar: Integer): TDimension;
  public //properties
    {$ifdef EnableAccessible}
    property Accessible: IAccessible read FAccessible write FAccessible;
    property AccessibleItem: IAccessible read FAccessibleItem write FAccessibleItem;
    property AccessibleName: string read FAccessibleName write FAccessibleName;
    {$endif}
  end;

implementation

uses
  VirtualTrees, VirtualTrees.BaseTree;

//----------------------------------------------------------------------------------------------------------------------
function TVTBaseAncestorLcl.PrepareDottedBrush(CurrentDottedBrush: TBrush; Bits: Pointer; const BitsLinesCount: Word): TBrush;
begin
  if Assigned(CurrentDottedBrush) then
    begin
      Result := CurrentDottedBrush;
    end else
    begin
      Result := TBrush.Create;
      Result.Bitmap := TBitmap.Create;
    end;

  Result.Bitmap.Handle := CreateBitmap(8, 8, 1, 1, Bits);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.RedrawWindow(lprcUpdate: PRect; hrgnUpdate: HRGN; flags: UINT): BOOL;
begin
  Result:= LCLIntf.RedrawWindow(Handle, lprcUpdate, hrgnUpdate, flags);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.InvalidateRect(lpRect: PRect; bErase: BOOL): BOOL;
begin
  Result:= LCLIntf.InvalidateRect(Handle, lpRect, bErase);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.UpdateWindow(): BOOL;
begin
  Result:= LCLIntf.UpdateWindow(Handle);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTBaseAncestorLcl.ShowScrollBar(Bar: Integer; AShow: Boolean);
begin
  LCLIntf.ShowScrollBar(Handle, Bar, AShow);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.SendWM_SETREDRAW(Updating: Boolean): LRESULT;
begin
  Result:= SendMessage(Handle, WM_SETREDRAW, Ord(not Updating), 0);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.SetScrollInfo(Bar: Integer; const ScrollInfo: TScrollInfo; Redraw: Boolean): TDimension;
begin
  Result:= LCLIntf.SetScrollInfo(Handle, Bar, ScrollInfo, Redraw);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.GetDottedBrushGridLines: TBrush;
begin
  Result:= FDottedBrushTreeLines;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.GetScrollInfo(Bar: Integer; var ScrollInfo: TScrollInfo): Boolean;
begin
  Result:= LCLIntf.GetScrollInfo(Handle, Bar, ScrollInfo);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTBaseAncestorLcl.GetScrollPos(Bar: Integer): TDimension;
begin
  Result:= LCLIntf.GetScrollPos(Handle, Bar);
end;

end.
