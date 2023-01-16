unit VirtualTrees.Colors;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, Controls, Graphics, DelphiCompat;

type
  // class to collect all switchable colors into one place
  TVTColors = class(TPersistent)
  private
    FOwner: TCustomControl;
    FColors: array[0..16] of TColor; // [IPK] 15 -> 16
    function GetColor(const Index: Integer): TColor;
    procedure SetColor(const Index: Integer; const Value: TColor);
    function GetBackgroundColor: TColor;
    function GetHeaderFontColor: TColor;
    function GetNodeFontColor: TColor;
  public
    constructor Create(AOwner: TCustomControl);

    procedure Assign(Source: TPersistent); override;
    property BackGroundColor: TColor read GetBackgroundColor;
    property HeaderFontColor: TColor read  GetHeaderFontColor;
    property NodeFontColor: TColor read GetNodeFontColor;
  published
    property BorderColor: TColor index 7 read GetColor write SetColor default clBtnFace;
    property DisabledColor: TColor index 0 read GetColor write SetColor default clBtnShadow;
    property DropMarkColor: TColor index 1 read GetColor write SetColor default clHighlight;
    property DropTargetColor: TColor index 2 read GetColor write SetColor default clHighLight;
    property DropTargetBorderColor: TColor index 11 read GetColor write SetColor default clHighLight;
    property FocusedSelectionColor: TColor index 3 read GetColor write SetColor default clHighLight;
    property FocusedSelectionBorderColor: TColor index 9 read GetColor write SetColor default clHighLight;
    property GridLineColor: TColor index 4 read GetColor write SetColor default clBtnFace;
    property HeaderHotColor: TColor index 14 read GetColor write SetColor default clBtnShadow;
    property HotColor: TColor index 8 read GetColor write SetColor default clWindowText;
    property SelectionRectangleBlendColor: TColor index 12 read GetColor write SetColor default clHighlight;
    property SelectionRectangleBorderColor: TColor index 13 read GetColor write SetColor default clHighlight;
    property SelectionTextColor: TColor index 15 read GetColor write SetColor default clHighlightText;
    property TreeLineColor: TColor index 5 read GetColor write SetColor default clBtnShadow;
    property UnfocusedColor: TColor index 16 read GetColor write SetColor default clBtnFace; // [IPK] Added
    property UnfocusedSelectionColor: TColor index 6 read GetColor write SetColor default clBtnFace;
    property UnfocusedSelectionBorderColor: TColor index 10 read GetColor write SetColor default clBtnFace;
  end;

implementation

uses
  VirtualTrees, VirtualTrees.BaseTree, VirtualTrees.Types
  {$ifdef Windows}
  , Windows
  {$endif}
  ;

type
  TBaseVirtualTreeCracker = class(TBaseVirtualTree);

  { TVTColorsHelper }

  TVTColorsHelper = class helper for TVTColors
    function TreeView: TBaseVirtualTreeCracker;
  end;

//----------------- TVTColors ------------------------------------------------------------------------------------------

constructor TVTColors.Create(AOwner: TCustomControl);

begin
  FOwner := AOwner;
  FColors[0] := clBtnShadow;      // DisabledColor
  FColors[1] := clHighlight;      // DropMarkColor
  FColors[2] := clHighLight;      // DropTargetColor
  FColors[3] := clHighLight;      // FocusedSelectionColor
  FColors[4] := clBtnFace;        // GridLineColor
  FColors[5] := clBtnShadow;      // TreeLineColor
  FColors[6] := clBtnFace;        // UnfocusedSelectionColor
  FColors[7] := clBtnFace;        // BorderColor
  FColors[8] := clWindowText;     // HotColor
  FColors[9] := clHighLight;      // FocusedSelectionBorderColor
  FColors[10] := clBtnFace;       // UnfocusedSelectionBorderColor
  FColors[11] := clHighlight;     // DropTargetBorderColor
  FColors[12] := clHighlight;     // SelectionRectangleBlendColor
  FColors[13] := clHighlight;     // SelectionRectangleBorderColor
  FColors[14] := clBtnShadow;     // HeaderHotColor
  FColors[15] := clHighlightText; // SelectionTextColor
  FColors[16] := clBtnFace;       // UnfocusedColor  [IPK]
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetBackgroundColor: TColor;
begin
// XE2 VCL Style
{$IF CompilerVersion >= 23}
  if FOwner.VclStyleEnabled {$IF CompilerVersion >= 24}and (seClient in FOwner.StyleElements){$IFEND} then
    Result := StyleServices.GetStyleColor(scTreeView)
  else
{$IFEND}
    Result := FOwner.Brush.Color;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetColor(const Index: Integer): TColor;

begin
{$IF CompilerVersion >= 23 }
  if FOwner.VclStyleEnabled then
  begin
    case Index of
      0:
        StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemDisabled), ecTextColor, Result); // DisabledColor
      1:
        Result := StyleServices.GetSystemColor(clHighlight); // DropMarkColor
      2:
        Result := StyleServices.GetSystemColor(clHighlight); // DropTargetColor
      3:
        Result := StyleServices.GetSystemColor(clHighlight); // FocusedSelectionColor
      4:
        Result := StyleServices.GetSystemColor(clBtnFace); // GridLineColor
      5:
        StyleServices.GetElementColor(StyleServices.GetElementDetails(ttBranch), ecBorderColor, Result); // TreeLineColor
      6:
        Result := StyleServices.GetSystemColor(clHighlight); // UnfocusedSelectionColor
      7:
        Result := StyleServices.GetSystemColor(clBtnFace); // BorderColor
      8:
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemHot), ecTextColor, Result) or
          (Result <> clWindowText) then
          Result := NodeFontColor; // HotColor
      9:
        StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemSelected), ecFillColor, Result);
      // FocusedSelectionBorderColor
      10:
        Result := StyleServices.GetSystemColor(clHighlight); // UnfocusedSelectionBorderColor
      11:
        Result := StyleServices.GetSystemColor(clBtnFace); // DropTargetBorderColor
      12:
        Result := StyleServices.GetSystemColor(clHighlight); // SelectionRectangleBlendColor
      13:
        Result := StyleServices.GetSystemColor(clHighlight); // SelectionRectangleBorderColor
      14:
        StyleServices.GetElementColor(StyleServices.GetElementDetails(thHeaderItemNormal), ecTextColor, Result); // HeaderHotColor
      15:
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemSelected), ecTextColor, Result) or
          (Result <> clWindowText) then
          Result := NodeFontColor; // SelectionTextColor
    end;
  end
  else
{$IFEND}
  Result := FColors[Index];
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetHeaderFontColor: TColor;
begin
// XE2+ VCL Style
{$IF CompilerVersion >= 23}
  if FOwner.VclStyleEnabled {$IF CompilerVersion >= 24}and (seFont in FOwner.StyleElements){$IFEND} then
    StyleServices.GetElementColor(StyleServices.GetElementDetails(thHeaderItemNormal), ecTextColor, Result)
  else
{$IFEND}
    Result := TreeView.Header.Font.Color;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetNodeFontColor: TColor;
begin
{$IF CompilerVersion >= 23}
  if FOwner.VclStyleEnabled {$IF CompilerVersion >= 24}and (seFont in FOwner.StyleElements){$IFEND} then
    StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemNormal), ecTextColor, Result)
  else
{$IFEND}
    Result := FOwner.Font.Color;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTColors.SetColor(const Index: Integer; const Value: TColor);

begin
  if FColors[Index] <> Value then
  begin
    FColors[Index] := Value;
    if not (csLoading in FOwner.ComponentState) and FOwner.HandleAllocated then
    begin
      // Cause helper bitmap rebuild if the button color changed.
      case Index of
        5:
          begin
            TreeView.PrepareBitmaps(True, False);
            FOwner.Invalidate;
          end;
        7:
          RedrawWindow(FOwner.Handle, nil, 0, RDW_FRAME or RDW_INVALIDATE or RDW_NOERASE or RDW_NOCHILDREN)
      else
        FOwner.Invalidate;
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTColors.Assign(Source: TPersistent);

begin
  if Source is TVTColors then
  begin
    FColors := TVTColors(Source).FColors;
    if TreeView.UpdateCount = 0 then
      TreeView.Invalidate;
  end
  else
    inherited;
end;

{ TVTColorsHelper }

function TVTColorsHelper.TreeView: TBaseVirtualTreeCracker;
begin
  Result := TBaseVirtualTreeCracker(FOwner);
end;

end.
