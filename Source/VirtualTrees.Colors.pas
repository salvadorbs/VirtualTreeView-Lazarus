unit VirtualTrees.Colors;

interface

uses
  System.Classes,
  Vcl.Graphics,
  Vcl.Themes,
  Vcl.Controls;

type
  //class to collect all switchable colors into one place
  TVTColors = class(TPersistent)
  private
    FOwner  : TCustomControl;
    FColors : array [TVTColorEnum] of TColor; //[IPK] 15 -> 16
    function GetColor(const Index : TVTColorEnum) : TColor;
    procedure SetColor(const Index : TVTColorEnum; const Value : TColor);
    function GetBackgroundColor : TColor;
    function GetHeaderFontColor : TColor;
    function GetNodeFontColor : TColor;
  public
    constructor Create(AOwner : TCustomControl);

    procedure Assign(Source : TPersistent); override;
    function GetSelectedNodeFontColor(Focused : boolean) : TColor;
    property BackGroundColor : TColor read GetBackgroundColor;
    property HeaderFontColor : TColor read GetHeaderFontColor;
    property NodeFontColor : TColor read GetNodeFontColor;
    //Mitigator function to use the correct style service for this context (either the style assigned to the control for Delphi > 10.4 or the application style)
    function StyleServices(AControl : TControl = nil) : TCustomStyleServices;
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

  TVTColorsHelper = class helper for TVTColors
    function TreeView : TBaseVirtualTreeCracker;
  end;

  //----------------- TVTColors ------------------------------------------------------------------------------------------

constructor TVTColors.Create(AOwner : TCustomControl);
var
  CE : TVTColorEnum;
begin
  FOwner := AOwner;
  for CE := Low(TVTColorEnum) to High(TVTColorEnum) do
    FColors[CE] := cDefaultColors[CE];
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetBackgroundColor : TColor;
begin
  //XE2 VCL Style
  if TreeView.VclStyleEnabled and (seClient in FOwner.StyleElements) then
    Result := StyleServices.GetStyleColor(scTreeView)
  else
    Result := TreeView.Color;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetColor(const Index : TVTColorEnum) : TColor;
begin
{$IF CompilerVersion >= 23 }
  if FOwner.VclStyleEnabled then
  begin
    //If the ElementDetails are not defined, fall back to the SystemColor
    case Index of
      cDisabledColor :
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemDisabled), ecTextColor, Result) then
          Result := StyleServices.GetSystemColor(FColors[Index]);
      cTreeLineColor :
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(ttBranch), ecBorderColor, Result) then
          Result := StyleServices.GetSystemColor(FColors[Index]);
      cBorderColor :
        if (seBorder in FOwner.StyleElements) then
          Result := StyleServices.GetSystemColor(FColors[Index])
        else
          Result := FColors[Index];
      cHotColor :
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemHot), ecTextColor, Result) then
          Result := StyleServices.GetSystemColor(FColors[Index]);
      cHeaderHotColor :
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(thHeaderItemHot), ecTextColor, Result) then
          Result := StyleServices.GetSystemColor(FColors[Index]);
      cSelectionTextColor :
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemSelected), ecTextColor, Result) then
          Result := StyleServices.GetSystemColor(clHighlightText);
      cUnfocusedColor :
        if not StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemSelectedNotFocus), ecTextColor, Result) then
          Result := StyleServices.GetSystemColor(FColors[Index]);
    else
      Result := StyleServices.GetSystemColor(FColors[Index]);
    end;
  end
  else
    Result := FColors[Index];
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetHeaderFontColor : TColor;
begin
  //XE2+ VCL Style
  if TreeView.VclStyleEnabled and (seFont in FOwner.StyleElements) then
    StyleServices.GetElementColor(StyleServices.GetElementDetails(thHeaderItemNormal), ecTextColor, Result)
  else
    Result := TreeView.Header.Font.Color;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetNodeFontColor : TColor;
begin
  if TreeView.VclStyleEnabled and (seFont in FOwner.StyleElements) then
    StyleServices.GetElementColor(StyleServices.GetElementDetails(ttItemNormal), ecTextColor, Result)
  else
    Result := TreeView.Font.Color;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.GetSelectedNodeFontColor(Focused : boolean) : TColor;
begin
  if Focused then
  begin
    if (tsUseExplorerTheme in TreeView.TreeStates) and not IsHighContrastEnabled then
    begin
      Result := NodeFontColor
    end
    else
      Result := SelectionTextColor
  end//if Focused
  else
    Result := UnfocusedColor;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTColors.SetColor(const Index : TVTColorEnum; const Value : TColor);
begin
  if FColors[Index] <> Value then
  begin
    FColors[Index] := Value;
    if not (csLoading in FOwner.ComponentState) and FOwner.HandleAllocated then
    begin
      //Cause helper bitmap rebuild if the button color changed.
      case Index of
        cTreeLineColor :
          begin
            TreeView.PrepareBitmaps(True, False);
            FOwner.Invalidate;
          end;
        cBorderColor :
          RedrawWindow(FOwner.Handle, nil, 0, RDW_FRAME or RDW_INVALIDATE or RDW_NOERASE or RDW_NOCHILDREN)
      else
        FOwner.Invalidate;
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTColors.StyleServices(AControl : TControl) : TCustomStyleServices;
begin
  if AControl = nil then
    AControl := FOwner;
  Result := VTStyleServices(AControl);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTColors.Assign(Source : TPersistent);
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

function TVTColorsHelper.TreeView : TBaseVirtualTreeCracker;
begin
  Result := TBaseVirtualTreeCracker(FOwner);
end;

end.
