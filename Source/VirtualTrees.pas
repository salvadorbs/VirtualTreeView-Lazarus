unit VirtualTrees;

{$mode delphi}{$H+}
{$packset 1}
{$if not Defined(CPU386)}
{$define PACKARRAYPASCAL}
{$endif}

// The contents of this file are subject to the Mozilla Public License
// Version 1.1 (the "License"); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
//
// Alternatively, you may redistribute this library, use and/or modify it under the terms of the
// GNU Lesser General Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any later version.
// You may obtain a copy of the LGPL at http://www.gnu.org/copyleft/.
//
// Software distributed under the License is distributed on an "AS IS" basis,
// WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the
// specific language governing rights and limitations under the License.
//
// The original code is VirtualTrees.pas, released September 30, 2000.
//
// The initial developer of the original code is digital publishing AG (Munich, Germany, www.digitalpublishing.de),
// written by Mike Lischke (public@soft-gems.net, www.soft-gems.net).
//
// Portions created by digital publishing AG are Copyright
// (C) 1999-2001 digital publishing AG. All Rights Reserved.
//----------------------------------------------------------------------------------------------------------------------
//
// For a list of recent changes please see file CHANGES.TXT
//
// Credits for their valuable assistance and code donations go to:
//   Freddy Ertl, Marian Aldenhövel, Thomas Bogenrieder, Jim Kuenemann, Werner Lehmann, Jens Treichler,
//   Paul Gallagher (IBO tree), Ondrej Kelle, Ronaldo Melo Ferraz, Heri Bender, Roland Bedürftig (BCB)
//   Anthony Mills, Alexander Egorushkin (BCB), Mathias Torell (BCB), Frank van den Bergh, Vadim Sedulin, Peter Evans,
//   Milan Vandrovec (BCB), Steve Moss, Joe White, David Clark, Anders Thomsen, Igor Afanasyev, Eugene Programmer,
//   Corbin Dunn, Richard Pringle, Uli Gerhardt, Azza, Igor Savkic, Daniel Bauten, Timo Tegtmeier, Dmitry Zegebart,
//   Andreas Hausladen, Joachim Marder
// Beta testers:
//   Freddy Ertl, Hans-Jürgen Schnorrenberg, Werner Lehmann, Jim Kueneman, Vadim Sedulin, Moritz Franckenstein,
//   Wim van der Vegt, Franc v/d Westelaken
// Indirect contribution (via publicly accessible work of those persons):
//   Alex Denissov, Hiroyuki Hori (MMXAsm expert)
// Documentation:
//   Markus Spoettl and toolsfactory GbR (http://www.doc-o-matic.com/, sponsoring Soft Gems development
//   with a free copy of the Doc-O-Matic help authoring system), Sven H. (Step by step tutorial)
// CLX:
//   Dmitri Dmitrienko (initial developer)
// Source repository:
//   https://github.com/Virtual-TreeView/Virtual-TreeView
// LCL Source repository:
//   https://github.com/salvadorbs/VirtualTreeView-Lazarus
// Accessability implementation:
//   Marco Zehe (with help from Sebastian Modersohn)
// LCL Port:
//   Luiz Américo Pereira Câmara
//----------------------------------------------------------------------------------------------------------------------

interface

{$I VTConfig.inc}

uses
  {$ifdef Windows}
  Windows,
  ActiveX,
  CommCtrl,
  UxTheme,
  {$else}
  FakeActiveX,
  {$endif}
  LCLIntf,
  {$ifdef USE_DELPHICOMPAT}
  DelphiCompat,
  LclExt,
  {$endif}
  {$ifdef DEBUG_VTV}
  VirtualTrees.Logger,
  {$endif}
  LCLType, LMessages, Types, LCLVersion,
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, Menus,
  Clipbrd // Clipboard support
  {$ifdef EnableAccessible}
  , oleacc // for MSAA IAccessible support
  {$endif}
  , VirtualTrees.Colors
  , VirtualTrees.Types
  , VirtualTrees.Header
  , VirtualTrees.DragImage
  , VirtualTrees.DataObject
  , VirtualTrees.Classes
  , VirtualTrees.BaseTree;

  {$if defined(LCLGtk) or defined(LCLGtk2)}
    {$define Gtk}
  {$endif}

  {$if defined(Gtk) or defined(LCLCocoa)}
    {$define ManualClipNeeded}
  {$endif}

  {$if defined(LCLGtk2) or defined(LCLCarbon) or defined(LCLQt)}
    {$define ContextMenuBeforeMouseUp}
  {$endif}

var
  MMXAvailable: Boolean; // necessary to know because the blend code uses MMX instructions
  IsWinVistaOrAbove: Boolean;

  UtilityImageSize: Integer = cUtilityImageSize;

type
  // Need to declare the correct WMNCPaint record as the VCL (D5-) doesn't.
  TRealWMNCPaint = packed record
    Msg: UINT;
    Rgn: HRGN;
    lParam: LPARAM;
    Result: LRESULT;
  end;

  // --------- TCustomVirtualStringTree

type

  TCustomVirtualStringTree = class;


  // Describes the type of text to return in the text and draw info retrival events.
  TVSTTextType = (
    ttNormal,      // normal label of the node, this is also the text which can be edited
    ttStatic       // static (non-editable) text after the normal text
  );

  // Describes the source to use when converting a string tree into a string for clipboard etc.
  TVSTTextSourceType = (
    tstAll,             // All nodes are rendered. Initialization is done on the fly.
    tstInitialized,     // Only initialized nodes are rendered.
    tstSelected,        // Only selected nodes are rendered.
    tstCutCopySet,      // Only nodes currently marked as being in the cut/copy clipboard set are rendered.
    tstVisible,         // Only visible nodes are rendered.
    tstChecked          // Only checked nodes are rendered
  );

  TVTPaintText = procedure(Sender: TBaseVirtualTree; const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
    TextType: TVSTTextType) of object;
  TVSTGetTextEvent = procedure(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
    TextType: TVSTTextType; var CellText: String) of object;
  TVSTGetHintEvent = procedure(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
    var LineBreakStyle: TVTTooltipLineBreakStyle; var HintText: String) of object;
  // New text can only be set for variable caption.
  TVSTNewTextEvent = procedure(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
    const NewText: String) of object;
  TVSTShortenStringEvent = procedure(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode;
    Column: TColumnIndex; const S: String; TextSpace: Integer; var Result: String;
    var Done: Boolean) of object;
  TVTMeasureTextEvent = procedure(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode;
    Column: TColumnIndex; const CellText: String; var Extent: Integer) of object;
  TVTDrawTextEvent = procedure(Sender: TBaseVirtualTree; TargetCanvas: TCanvas; Node: PVirtualNode;
    Column: TColumnIndex; const CellText: String; const CellRect: TRect; var DefaultDraw: Boolean) of object;

  /// Event arguments of the OnGetCellText event
  TVSTGetCellTextEventArgs = record
    Node: PVirtualNode;
    Column: TColumnIndex;
    CellText: string;
    StaticText: string;
    StaticTextAlignment: TAlignment;
    ExportType: TVTExportType;
    constructor Create(pNode: PVirtualNode; pColumn: TColumnIndex; pExportType: TVTExportType = TVTExportType.etNone);
  end;

  { TCustomVirtualStringTree }

  TCustomVirtualStringTree = class(TBaseVirtualTree)
  private
    FDefaultText: String;                      // text to show if there's no OnGetText event handler (e.g. at design time)
    FTextHeight: Integer;                          // true size of the font
    FEllipsisWidth: Integer;                       // width of '...' for the current font
    FInternalDataOffset: Cardinal;                 // offset to the internal data of the string tree

    FOnPaintText: TVTPaintText;                    // triggered before either normal or fixed text is painted to allow
                                                   // even finer customization (kind of sub cell painting)
    FOnGetText: TVSTGetTextEvent;                  // used to retrieve the string to be displayed for a specific node
    FOnGetHint: TVSTGetHintEvent;                  // used to retrieve the hint to be displayed for a specific node
    FOnNewText: TVSTNewTextEvent;                  // used to notify the application about an edited node caption
    FOnShortenString: TVSTShortenStringEvent;      // used to allow the application a customized string shortage
    FOnMeasureTextWidth: TVTMeasureTextEvent;      // used to adjust the width of the cells
    FOnMeasureTextHeight: TVTMeasureTextEvent;
    FOnDrawText: TVTDrawTextEvent;                 // used to custom draw the node text

    procedure AddContentToBuffer(Buffer: TBufferedUTF8String; Source: TVSTTextSourceType; const Separator: String);
    function GetImageText(Node: PVirtualNode; Kind: TVTImageKind;
      Column: TColumnIndex): String;
    function GetOptions: TCustomStringTreeOptions;
    function GetStaticText(Node: PVirtualNode; Column: TColumnIndex): String;
    function GetText(Node: PVirtualNode; Column: TColumnIndex): String;
    procedure SetDefaultText(const Value: String);
    procedure SetOptions(const Value: TCustomStringTreeOptions);
    procedure SetText(Node: PVirtualNode; Column: TColumnIndex; const Value: String);
    procedure CMFontChanged(var Msg: TLMessage); message CM_FONTCHANGED;
    procedure GetDataFromGrid(const AStrings : TStringList; const IncludeHeading : Boolean = True);
  protected
    FPreviouslySelected: TStringList;
    procedure InitializeTextProperties(var PaintInfo: TVTPaintInfo); // [IPK] - private to protected
    procedure PaintNormalText(var PaintInfo: TVTPaintInfo; TextOutFlags: Integer; Text: String); virtual; // [IPK] - private to protected
    procedure PaintStaticText(const PaintInfo: TVTPaintInfo; TextOutFlags: Integer; const Text: String); virtual; // [IPK] - private to protected
    procedure AdjustPaintCellRect(var PaintInfo: TVTPaintInfo; out NextNonEmpty: TColumnIndex); override;
    function CanExportNode(Node: PVirtualNode): Boolean;
    function CalculateStaticTextWidth(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; const Text: String): Integer; virtual;
    function CalculateTextWidth(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; const Text: String): Integer; virtual;
    function ColumnIsEmpty(Node: PVirtualNode; Column: TColumnIndex): Boolean; override;
    function DoCreateEditor(Node: PVirtualNode; Column: TColumnIndex): IVTEditLink; override;
    function DoGetNodeHint(Node: PVirtualNode; Column: TColumnIndex; var LineBreakStyle: TVTTooltipLineBreakStyle): String; override;
    function DoGetNodeTooltip(Node: PVirtualNode; Column: TColumnIndex; var LineBreakStyle: TVTTooltipLineBreakStyle): String; override;
    function DoGetNodeExtraWidth(Node: PVirtualNode; Column: TColumnIndex; Canvas: TCanvas = nil): Integer; override;
    function DoGetNodeWidth(Node: PVirtualNode; Column: TColumnIndex; Canvas: TCanvas = nil): Integer; override;
    procedure DoGetText(Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
      var Text: String); virtual;
    function DoIncrementalSearch(Node: PVirtualNode; const Text: String): Integer; override;
    procedure DoNewText(Node: PVirtualNode; Column: TColumnIndex; const Text: String); virtual;
    procedure DoPaintNode(var PaintInfo: TVTPaintInfo); override;
    procedure DoPaintText(Node: PVirtualNode; const Canvas: TCanvas; Column: TColumnIndex;
      TextType: TVSTTextType); virtual;
    function DoShortenString(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; const S: String; Width: Integer;
      EllipsisWidth: Integer = 0): String; virtual;
    procedure DoTextDrawing(var PaintInfo: TVTPaintInfo; const Text: String; CellRect: TRect; DrawFormat: Cardinal); virtual;
    function DoTextMeasuring(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; const Text: String): TSize; virtual;
    function GetOptionsClass: TTreeOptionsClass; override;
    procedure GetRenderStartValues(Source: TVSTTextSourceType; out Node: PVirtualNode;
      out NextNodeProc: TGetNextNodeProc);
    function InternalData(Node: PVirtualNode): Pointer;
    procedure MainColumnChanged; override;
    function ReadChunk(Stream: TStream; Version: Integer; Node: PVirtualNode; ChunkType,
      ChunkSize: Integer): Boolean; override;
    function RenderOLEData(const FormatEtcIn: TFormatEtc; out Medium: TStgMedium; ForClipboard: Boolean): HResult; override;
    procedure WriteChunks(Stream: TStream; Node: PVirtualNode); override;

    property DefaultText: String read FDefaultText write SetDefaultText;
    property EllipsisWidth: Integer read FEllipsisWidth;
    property TreeOptions: TCustomStringTreeOptions read GetOptions write SetOptions;

    property OnGetHint: TVSTGetHintEvent read FOnGetHint write FOnGetHint;
    property OnGetText: TVSTGetTextEvent read FOnGetText write FOnGetText;
    property OnNewText: TVSTNewTextEvent read FOnNewText write FOnNewText;
    property OnPaintText: TVTPaintText read FOnPaintText write FOnPaintText;
    property OnShortenString: TVSTShortenStringEvent read FOnShortenString write FOnShortenString;
    property OnMeasureTextWidth: TVTMeasureTextEvent read FOnMeasureTextWidth write FOnMeasureTextWidth;
    property OnMeasureTextHeight: TVTMeasureTextEvent read FOnMeasureTextHeight write FOnMeasureTextHeight;
    property OnDrawText: TVTDrawTextEvent read FOnDrawText write FOnDrawText;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
    function AddChild(Parent: PVirtualNode; UserData: Pointer = nil): PVirtualNode; override;
    function ComputeNodeHeight(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex; S: String = ''): Integer; virtual;
    function ContentToClipboard(Format: TClipboardFormat; Source: TVSTTextSourceType): HGLOBAL;
    procedure ContentToCustom(Source: TVSTTextSourceType);
    function ContentToHTML(Source: TVSTTextSourceType; const Caption: String = ''): String;
    function ContentToRTF(Source: TVSTTextSourceType): AnsiString;
    function ContentToAnsi(Source: TVSTTextSourceType; const Separator: String): AnsiString;
    function ContentToText(Source: TVSTTextSourceType; const Separator: String): AnsiString; inline;
    function ContentToUnicode(Source: TVSTTextSourceType; const Separator: String): UnicodeString; inline;
    function ContentToUTF16(Source: TVSTTextSourceType; const Separator: String): UnicodeString;
    function ContentToUTF8(Source: TVSTTextSourceType; const Separator: String): String;
    {$ifndef LCLWin32}
    procedure CopyToClipBoard; override;
    procedure CutToClipBoard; override;
    {$endif}
    procedure GetTextInfo(Node: PVirtualNode; Column: TColumnIndex; const AFont: TFont; var R: TRect;
      out Text: String); override;
    function InvalidateNode(Node: PVirtualNode): TRect; override;
    function Path(Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; Delimiter: Char): String;
    procedure ReinitNode(Node: PVirtualNode; Recursive: Boolean); override;
    procedure AddToSelection(Node: PVirtualNode); override;
    procedure RemoveFromSelection(Node: PVirtualNode); override;
    function SaveToCSVFile(const FileNameWithPath : TFileName; const IncludeHeading : Boolean) : Boolean;
    property ImageText[Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex]: String read GetImageText;
    property StaticText[Node: PVirtualNode; Column: TColumnIndex]: String read GetStaticText;
    property Text[Node: PVirtualNode; Column: TColumnIndex]: String read GetText write SetText;
  end;

  TVirtualStringTree = class(TCustomVirtualStringTree)
  private
    function GetOptions: TStringTreeOptions;
    procedure SetOptions(const Value: TStringTreeOptions);
  protected
    function GetOptionsClass: TTreeOptionsClass; override;
    {$if CompilerVersion >= 23}
    class constructor Create();
    {$ifend}
  public
    property Canvas;
    property RangeX;
    property LastDragEffect;
  published
    {$ifdef EnableAccessible}
    property AccessibleName;
    {$endif}
    property Action;
    property Align;
    property Alignment;
    property Anchors;
    property AnimationDuration;
    property AutoExpandDelay;
    property AutoScrollDelay;
    property AutoScrollInterval;
    property Background;
    property BackgroundOffsetX;
    property BackgroundOffsetY;
    property BiDiMode;
    //property BevelEdges;
    //property BevelInner;
    //property BevelOuter;
    //property BevelKind;
    //property BevelWidth;
    property BorderSpacing;
    property BorderStyle default bsSingle;
    property BottomSpace;
    property ButtonFillMode;
    property ButtonStyle;
    property BorderWidth;
    property ChangeDelay;
    property CheckImageKind;
    property ClipboardFormats;
    property Color;
    property Colors;
    property Constraints;
    property CustomCheckImages;
    property DefaultNodeHeight;
    property DefaultPasteMode;
    property DefaultText;
    property DragCursor;
    property DragHeight;
    property DragKind;
    property DragImageKind;
    property DragMode;
    property DragOperations;
    property DragType;
    property DragWidth;
    property DrawSelectionMode;
    property EditDelay;
    property EmptyListMessage;
    property Enabled;
    property Font;
    property Header;
    property HintMode;
    property HotCursor;
    property Images;
    property IncrementalSearch;
    property IncrementalSearchDirection;
    property IncrementalSearchStart;
    property IncrementalSearchTimeout;
    property Indent;
    property LineMode;
    property LineStyle;
    property Margin;
    property NodeAlignment;
    property NodeDataSize;
    property OperationCanceled;
    property ParentBiDiMode;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property RootNodeCount;
    property ScrollBarOptions;
    property SelectionBlendFactor;
    property SelectionCurveRadius;
    property ShowHint;
    property StateImages;
    {$if CompilerVersion >= 24}
    property StyleElements;
    {$ifend}
    property TabOrder;
    property TabStop default True;
    property TextMargin;
    property TreeOptions: TStringTreeOptions read GetOptions write SetOptions;
    property Visible;
    property WantTabs;
    {$IF LCL_FullVersion >= 2000000}
    property ImagesWidth;
    property StateImagesWidth;
    property CustomCheckImagesWidth;
    {$IFEND}

    property OnAddToSelection;
    property OnAdvancedHeaderDraw;
    property OnAfterAutoFitColumn;
    property OnAfterAutoFitColumns;
    property OnAfterCellPaint;
    property OnAfterColumnExport;
    property OnAfterColumnWidthTracking;
    property OnAfterGetMaxColumnWidth;
    property OnAfterHeaderExport;
    property OnAfterHeaderHeightTracking;
    property OnAfterItemErase;
    property OnAfterItemPaint;
    property OnAfterNodeExport;
    property OnAfterPaint;
    property OnAfterTreeExport;
    property OnBeforeAutoFitColumn;
    property OnBeforeAutoFitColumns;
    property OnBeforeCellPaint;
    property OnBeforeColumnExport;
    property OnBeforeColumnWidthTracking;
    property OnBeforeDrawTreeLine;
    property OnBeforeGetMaxColumnWidth;
    property OnBeforeHeaderExport;
    property OnBeforeHeaderHeightTracking;
    property OnBeforeItemErase;
    property OnBeforeItemPaint;
    property OnBeforeNodeExport;
    property OnBeforePaint;
    property OnBeforeTreeExport;
    property OnCanSplitterResizeColumn;
    property OnCanSplitterResizeHeader;
    property OnCanSplitterResizeNode;
    property OnChange;
    property OnChecked;
    property OnChecking;
    property OnClick;
    property OnCollapsed;
    property OnCollapsing;
    property OnColumnClick;
    property OnColumnDblClick;
    property OnColumnExport;
    property OnColumnResize;
    property OnColumnWidthDblClickResize;
    property OnColumnWidthTracking;
    property OnCompareNodes;
    property OnContextPopup;
    property OnCreateDataObject;
    property OnCreateDragManager;
    property OnCreateEditor;
    property OnDblClick;
    property OnDragAllowed;
    property OnDragOver;
    property OnDragDrop;
    property OnDrawHint;
    property OnDrawText;
    property OnEditCancelled;
    property OnEdited;
    property OnEditing;
    property OnEndDock;
    property OnEndDrag;
    property OnEndOperation;
    property OnEnter;
    property OnExit;
    property OnExpanded;
    property OnExpanding;
    property OnFocusChanged;
    property OnFocusChanging;
    property OnFreeNode;
    property OnGetCellIsEmpty;
    property OnGetCursor;
    property OnGetHeaderCursor;
    property OnGetText;
    property OnPaintText;
    property OnGetHelpContext;
    property OnGetHintKind;
    property OnGetHintSize;
    property OnGetImageIndex;
    property OnGetImageIndexEx;
    property OnGetImageText;
    property OnGetHint;
    property OnGetLineStyle;
    property OnGetNodeDataSize;
    property OnGetPopupMenu;
    property OnGetUserClipboardFormats;
    property OnHeaderClick;
    property OnHeaderDblClick;
    property OnHeaderDragged;
    property OnHeaderDraggedOut;
    property OnHeaderDragging;
    property OnHeaderDraw;
    property OnHeaderDrawQueryElements;
    property OnHeaderHeightDblClickResize;
    property OnHeaderHeightTracking;
    property OnHeaderMouseDown;
    property OnHeaderMouseMove;
    property OnHeaderMouseUp;
    property OnHotChange;
    property OnIncrementalSearch;
    property OnInitChildren;
    property OnInitNode;
    property OnKeyAction;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnLoadNode;
    property OnLoadTree;
    property OnMeasureItem;
    property OnMeasureTextWidth;
    property OnMeasureTextHeight;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnNewText;
    property OnNodeClick;
    property OnNodeCopied;
    property OnNodeCopying;
    property OnNodeDblClick;
    property OnNodeExport;
    property OnNodeHeightDblClickResize;
    property OnNodeHeightTracking;
    property OnNodeMoved;
    property OnNodeMoving;
    property OnPaintBackground;
    property OnRemoveFromSelection;
    property OnRenderOLEData;
    property OnResetNode;
    property OnResize;
    property OnSaveNode;
    property OnSaveTree;
    property OnScroll;
    property OnShortenString;
    property OnShowScrollBar;
    property OnStartDock;
    property OnStartDrag;
    property OnStartOperation;
    property OnStateChange;
    property OnStructureChange;
    property OnUpdating;
    property OnUTF8KeyPress;
    //delphi only
    //property OnCanResize;
    //property OnGesture;
    //property Touch;
  end;

// utility routines
function ShortenString(DC: HDC; const S: String; Width: Integer; EllipsisWidth: Integer = 0): String;
procedure GetStringDrawRect(DC: HDC; const S: String; var Bounds: TRect; DrawFormat: Cardinal);
function WrapString(DC: HDC; const S: String; const Bounds: TRect; RTL: Boolean;
  DrawFormat: Cardinal): String;

procedure ShowError(const Msg: String; HelpContext: Integer);  // [IPK] Surface this to interface

//----------------------------------------------------------------------------------------------------------------------

var
  LightCheckImages,                    // global light check images
  DarkCheckImages,                     // global heavy check images
  LightTickImages,                     // global light tick images
  DarkTickImages,                      // global heavy check images
  FlatImages,                          // global flat check images
  XPImages,                            // global XP style check images
  SystemCheckImages,                   // global system check images
  SystemFlatCheckImages: TImageList;   // global flat system check images
  UtilityImages: TCustomBitmap;        // some small additional images (e.g for header dragging)
  Initialized: Boolean;                // True if global structures have been initialized.
  NeedToUnitialize: Boolean;           // True if the OLE subsystem could be initialized successfully.

type
  // protection against TRect record method that cause problems with with-statements
  TWithSafeRect = record
    case Integer of
      0: (Left, Top, Right, Bottom: Longint);
      1: (TopLeft, BottomRight: TPoint);
  end;

implementation

{$R VirtualTrees.res}

uses
  StrUtils, Math,
  {$ifdef EnableOLE}
  //AxCtrls,       // TOLEStream
  {$endif}
  {$ifdef Windows}
  MMSystem,                // for animation timer (does not include further resources)
  {$else}
  FakeMMSystem,
  {$endif}
  TypInfo,                 // for migration stuff
  LCLProc
  {$ifdef EnableAccessible}
  , VirtualTrees.AccessibilityFactory
  {$endif}
  , VirtualTrees.ClipBoard
  , VirtualTrees.WorkerThread
  , VirtualTrees.DragnDrop
  , VirtualTrees.Export
  , VirtualTrees.EditLink
  , VirtualTrees.DrawTree;  // accessibility helper class

const

  {$ifndef COMPILER_11_UP}
      TVP_HOTGLYPH = 4;
  {$endif COMPILER_11_UP}

  RTLFlag: array[Boolean] of Integer = (0, ETO_RTLREADING);
  AlignmentToDrawFlag: array[TAlignment] of Cardinal = (DT_LEFT, DT_RIGHT, DT_CENTER);

  WideCR = WideChar(#13);
  WideLF = WideChar(#10);

//----------------- compatibility functions ----------------------------------------------------------------------------

// ExcludeClipRect is buggy in Cocoa
// https://github.com/blikblum/VirtualTreeView-Lazarus/issues/8
// https://bugs.freepascal.org/view.php?id=34196

{$ifdef LCLCocoa}
function ExcludeClipRect(dc: hdc; Left, Top, Right, Bottom : Integer) : Integer;
begin
  Result := 0;
end;
{$endif}

// LCLIntf.BitBlt is not compatible with windows.BitBlt
// The former takes into account the alpha channel while the later not

{$if not defined(USE_DELPHICOMPAT) and defined(LCLWin)}
function BitBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC; XSrc, YSrc: Integer; Rop: DWORD): Boolean;
begin
  Result := windows.BitBlt(DestDC, X, Y, Width, Height, SrcDC, XSrc, YSrc, Rop);
end;
{$endif}

//----------------- utility functions ----------------------------------------------------------------------------------

procedure ShowError(const Msg: String; HelpContext: Integer);

begin
  raise EVirtualTreeError.CreateHelp(Msg, HelpContext);
end;

//----------------------------------------------------------------------------------------------------------------------

//todo: Unify the procedure or change to widgetset specific
// Currently the UTF-8 version is broken.
// the unicode version is used when all winapi is available

{$ifndef INCOMPLETE_WINAPI}
function ShortenString(DC: HDC; const S: String; Width: Integer; EllipsisWidth: Integer = 0): String;

// Adjusts the given string S so that it fits into the given width. EllipsisWidth gives the width of
// the three points to be added to the shorted string. If this value is 0 then it will be determined implicitely.
// For higher speed (and multiple entries to be shorted) specify this value explicitely.
// Note: It is assumed that the string really needs shortage. Check this in advance.

var
  Size: TSize;
  Len: Integer;
  L, H, N, W: Integer;
  WideStr: UnicodeString;
begin
  WideStr := UTF8Decode(S);
  Len := Length(WideStr);
  if (Len = 0) or (Width <= 0) then
    Result := ''
  else
  begin
    // Determine width of triple point using the current DC settings (if not already done).
    if EllipsisWidth = 0 then
    begin
      GetTextExtentPoint32W(DC, '...', 3, Size);
      EllipsisWidth := Size.cx;
    end;

    if Width <= EllipsisWidth then
      Result := ''
    else
    begin
      // Do a binary search for the optimal string length which fits into the given width.
      L := 0;
      H := Len - 1;
      while L < H do
      begin
        N := (L + H + 1) shr 1;
        GetTextExtentPoint32W(DC, PWideChar(WideStr), N, Size);
        W := Size.cx + EllipsisWidth;
        if W <= Width then
          L := N
        else
          H := N - 1;
      end;
      Result := UTF8Encode(Copy(WideStr, 1, L) + '...');
    end;
  end;
end;
{$else}
function ShortenString(DC: HDC; const S: String; Width: Integer; EllipsisWidth: Integer = 0): String;

// Adjusts the given string S so that it fits into the given width. EllipsisWidth gives the width of
// the three points to be added to the shorted string. If this value is 0 then it will be determined implicitely.
// For higher speed (and multiple entries to be shorted) specify this value explicitely.
// Note: It is assumed that the string really needs shortage. Check this in advance.

var
  Size: TSize;
  Len: Integer;
  L, H, N, W: Integer;
begin
  Len := Length(S);
  if (Len = 0) or (Width <= 0) then
    Result := ''
  else
  begin
    // Determine width of triple point using the current DC settings (if not already done).
    if EllipsisWidth = 0 then
    begin
      GetTextExtentPoint32(DC, '...', 3, Size);
      EllipsisWidth := Size.cx;
    end;

    if Width <= EllipsisWidth then
      Result := ''
    else
    begin
      // Do a binary search for the optimal string length which fits into the given width.
      L := 0;
      H := Len - 1;
      while L < H do
      begin
        N := (L + H + 1) shr 1;
        GetTextExtentPoint32(DC, PAnsiChar(S), N, Size);
        W := Size.cx + EllipsisWidth;
        if W <= Width then
          L := N
        else
          H := N - 1;
      end;
      Result := Copy(S, 1, L) + '...';
    end;
  end;
end;
{$endif}
//----------------------------------------------------------------------------------------------------------------------

function WrapString(DC: HDC; const S: String; const Bounds: TRect; RTL: Boolean;
  DrawFormat: Cardinal): String;

// Wrap the given string S so that it fits into a space of given width.
// RTL determines if right-to-left reading is active.

var
  Width,
  Len,
  WordCounter,
  WordsInLine,
  I, W: Integer;
  Buffer,
  Line: String;
  Words: array of String;
  R: TRect;

begin
  Result := '';
  // Leading and trailing are ignored.
  Buffer := Trim(S);
  Len := Length(Buffer);
  if Len < 1 then
    Exit;

  Width := Bounds.Right - Bounds.Left;
  R := Rect(0, 0, 0, 0);

  // Count the words in the string.
  WordCounter := 1;
  for I := 1 to Len do
    if Buffer[I] = ' ' then
      Inc(WordCounter);
  SetLength(Words, WordCounter);

  if RTL then
  begin
    // At first we split the string into words with the last word being the
    // first element in Words.
    W := 0;
    for I := 1 to Len do
      if Buffer[I] = ' ' then
        Inc(W)
      else
        Words[W] := Words[W] + Buffer[I];

    // Compose Result.
    while WordCounter > 0 do
    begin
      WordsInLine := 0;
      Line := '';

      while WordCounter > 0 do
      begin
        GetStringDrawRect(DC, Line + IfThen(WordsInLine > 0, ' ', '') + Words[WordCounter - 1], R, DrawFormat);
        if R.Right > Width then
        begin
          // If at least one word fits into this line then continue with the next line.
          if WordsInLine > 0 then
            Break;

          Buffer := Words[WordCounter - 1];
          if Len > 1 then
          begin
            for Len := Length(Buffer) - 1 downto 2 do
            begin
              GetStringDrawRect(DC, RightStr(Buffer, Len), R, DrawFormat);
              if R.Right <= Width then
                Break;
            end;
          end
          else
            Len := Length(Buffer);

          Line := Line + RightStr(Buffer, Max(Len, 1));
          Words[WordCounter - 1] := LeftStr(Buffer, Length(Buffer) - Max(Len, 1));
          if Words[WordCounter - 1] = '' then
            Dec(WordCounter);
          Break;
        end
        else
        begin
          Dec(WordCounter);
          Line := Words[WordCounter] + IfThen(WordsInLine > 0, ' ', '') + Line;
          Inc(WordsInLine);
        end;
      end;

      Result := Result + Line + LineEnding;
    end;
  end
  else
  begin
    // At first we split the string into words with the last word being the
    // first element in Words.
    W := WordCounter - 1;
    for I := 1 to Len do
      if Buffer[I] = ' ' then
        Dec(W)
      else
        Words[W] := Words[W] + Buffer[I];

    // Compose Result.
    while WordCounter > 0 do
    begin
      WordsInLine := 0;
      Line := '';

      while WordCounter > 0 do
      begin
        GetStringDrawRect(DC, Line + IfThen(WordsInLine > 0, ' ', '') + Words[WordCounter - 1], R, DrawFormat);
        if R.Right > Width then
        begin
          // If at least one word fits into this line then continue with the next line.
          if WordsInLine > 0 then
            Break;

          Buffer := Words[WordCounter - 1];
          if Len > 1 then
          begin
            for Len := Length(Buffer) - 1 downto 2 do
            begin
              GetStringDrawRect(DC, LeftStr(Buffer, Len), R, DrawFormat);
              if R.Right <= Width then
                Break;
            end;
          end
          else
            Len := Length(Buffer);

          Line := Line + LeftStr(Buffer, Max(Len, 1));
          Words[WordCounter - 1] := RightStr(Buffer, Length(Buffer) - Max(Len, 1));
          if Words[WordCounter - 1] = '' then
            Dec(WordCounter);
          Break;
        end
        else
        begin
          Dec(WordCounter);
          Line := Line + IfThen(WordsInLine > 0, ' ', '') + Words[WordCounter];
          Inc(WordsInLine);
        end;
      end;

      Result := Result + Line + LineEnding;
    end;
  end;

  Len := Length(Result) - Length(LineEnding);
  if CompareByte(Result[Len + 1], String(LineEnding)[1], Length(LineEnding)) = 0 then
    SetLength(Result, Len);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure GetStringDrawRect(DC: HDC; const S: String; var Bounds: TRect; DrawFormat: Cardinal);

// Calculates bounds of a drawing rectangle for the given string

begin
  Bounds.Right := Bounds.Left + 1;
  Bounds.Bottom := Bounds.Top + 1;

  DrawText(DC, PChar(S), Length(S), Bounds, DrawFormat or DT_CALCRECT);
end;

//----------------------------------------------------------------------------------------------------------------------
{$ifdef EnableAccessible}
procedure GetAccessibilityFactory;

// Accessibility helper function to create a singleton class that will create or return
// the IAccessible interface for the tree and the focused node.

begin
  // Check to see if the class has already been created.
  if VTAccessibleFactory = nil then
    VTAccessibleFactory := TVTAccessibilityFactory.Create;
end;
{$endif}

//----------------- TCustomVirtualString -------------------------------------------------------------------------------

constructor TCustomVirtualStringTree.Create(AOwner: TComponent);

begin
  inherited;
  FPreviouslySelected := nil;
  if (Owner = nil) or (([csReading, csDesigning] * Owner.ComponentState) = [csDesigning]) then
    FDefaultText := 'Node';
  FInternalDataOffset := AllocateInternalDataArea(SizeOf(Cardinal));
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.GetRenderStartValues(Source: TVSTTextSourceType; out Node: PVirtualNode;
  out NextNodeProc: TGetNextNodeProc);

begin
  case Source of
    tstInitialized:
      begin
        Node := GetFirstInitialized;
        NextNodeProc := GetNextInitialized;
      end;
    tstSelected:
      begin
        Node := GetFirstSelected;
        NextNodeProc := GetNextSelected;
      end;
    tstCutCopySet:
      begin
        Node := GetFirstCutCopy;
        NextNodeProc := GetNextCutCopy;
      end;
    tstVisible:
      begin
        Node := GetFirstVisible(nil, True);
        NextNodeProc := GetNextVisible;
      end;
    tstChecked:
      begin
        Node := GetFirstChecked;
        NextNodeProc := GetNextChecked;
      end;
  else // tstAll
    Node := GetFirst;
    NextNodeProc := GetNext;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.GetDataFromGrid(const AStrings: TStringList;
  const IncludeHeading: Boolean);
var
  LColIndex   : Integer;
  LStartIndex : Integer;
  LAddString  : string;
  LCellText   : string;
  LChildNode  : PVirtualNode;
begin
  { Start from the First column. }
  LStartIndex := 0;

  { Do it for Header first }
  if IncludeHeading then
  begin
    LAddString := EmptyStr;
    for LColIndex := LStartIndex to Pred(Header.Columns.Count) do
    begin
      if (LColIndex > LStartIndex) then
        LAddString := LAddString + ',';
      LAddString := LAddString + AnsiQuotedStr(Header.Columns.Items[LColIndex].Text, '"');
    end;//for
    AStrings.Add(LAddString);
  end;//if

  { Loop thru the virtual tree for Data }
  LChildNode := GetFirst;
  while Assigned(LChildNode) do
  begin
    LAddString := EmptyStr;

    { Read for each column and then populate the text }
    for LColIndex := LStartIndex to Pred(Header.Columns.Count) do
    begin
      LCellText := Text[LChildNode, LColIndex];
      if (LCellText = EmptyStr) then
        LCellText := ' ';
      if (LColIndex > LStartIndex) then
        LAddString := LAddString + ',';
      LAddString := LAddString + AnsiQuotedStr(LCellText, '"');
    end;//for - Header.Columns.Count

    AStrings.Add(LAddString);
    LChildNode := LChildNode.NextSibling;
  end;//while Assigned(LChildNode);
end;

function TCustomVirtualStringTree.GetImageText(Node: PVirtualNode;
  Kind: TVTImageKind; Column: TColumnIndex): String;
begin
  Assert(Assigned(Node), 'Node must not be nil.');

  if not (vsInitialized in Node.States) then
    InitNode(Node);
  Result := '';

  DoGetImageText(Node, Kind, Column, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.GetOptions: TCustomStringTreeOptions;

begin
  Result := inherited TreeOptions as TCustomStringTreeOptions;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.GetStaticText(Node: PVirtualNode; Column: TColumnIndex): String;

begin
  Assert(Assigned(Node), 'Node must not be nil.');

  if not (vsInitialized in Node.States) then
    InitNode(Node);
  Result := '';

  DoGetText(Node, Column, ttStatic, Result);
end;


//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.GetText(Node: PVirtualNode; Column: TColumnIndex): String;

begin
  Assert(Assigned(Node), 'Node must not be nil.');

  if not (vsInitialized in Node.States) then
    InitNode(Node);
  Result := FDefaultText;

  DoGetText(Node, Column, ttNormal, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.InitializeTextProperties(var PaintInfo: TVTPaintInfo);

// Initializes default values for customization in PaintNormalText.

begin
  with PaintInfo do
  begin
    // Set default font values first.
    Canvas.Font := Font;
    if Enabled then // Es werden sonst nur die Farben verwendet von Font die an  Canvas.Font übergeben wurden
       Canvas.Font.Color := Colors.NodeFontColor
    else
      Canvas.Font.Color := Colors.DisabledColor;

    if (toHotTrack in TreeOptions.PaintOptions) and (Node = HotNode) then
    begin
      if not (tsUseExplorerTheme in TreeStates) then
      begin
        Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];
        Canvas.Font.Color := Colors.HotColor;
      end;
    end;

    // Change the font color only if the node also is drawn in selected style.
    if poDrawSelection in PaintOptions then
    begin
      if (Column = FocusedColumn) or (toFullRowSelect in TreeOptions.SelectionOptions) then
      begin
        if Node = DropTargetNode then
        begin
          if ((LastDropMode = dmOnNode) or (vsSelected in Node.States)) and not
             (tsUseExplorerTheme in TreeStates) then
            Canvas.Font.Color := Colors.SelectionTextColor;
        end
        else
          if vsSelected in Node.States then
          begin
            if (Focused or (toPopupMode in TreeOptions.PaintOptions)) and not
               (tsUseExplorerTheme in TreeStates) then
            Canvas.Font.Color := Colors.SelectionTextColor;
          end;
      end;
    end;
    if Canvas.Font.Color = clDefault then
      Canvas.Font.Color := GetDefaultColor(dctFont);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.PaintNormalText(var PaintInfo: TVTPaintInfo; TextOutFlags: Integer;
  Text: String);

// This method is responsible for painting the given text to target canvas (under consideration of the given rectangles).
// The text drawn here is considered as the normal text in a node.
// Note: NodeWidth is the actual width of the text to be drawn. This does not necessarily correspond to the width of
//       the node rectangle. The clipping rectangle comprises the entire node (including tree lines, buttons etc.).

var
  TripleWidth: Integer;
  R: TRect;
  DrawFormat: Cardinal;
  Size: TSize;
  Height: Integer;

begin
  {$ifdef DEBUG_VTV}Logger.EnterMethod([lcPaintDetails],'PaintNormalText') ;{$endif}
  InitializeTextProperties(PaintInfo);
  with PaintInfo do
  begin
    R := ContentRect;
    //todo_lcl See how TextStyle should be set
    //Canvas.TextFlags := 0;
    InflateRect(R, -TextMargin, 0);

    // Multiline nodes don't need special font handling or text manipulation.
    // Note: multiline support requires the Unicode version of DrawText, which is able to do word breaking.
    //       The emulation in this unit does not support this so we have to use the OS version. However
    //       DrawTextW is only available on NT/2000/XP and up. Hence there is only partial multiline support
    //       for 9x/Me.
    if vsMultiline in Node.States then
    begin
      DoPaintText(Node, Canvas, Column, ttNormal);
      Height := ComputeNodeHeight(Canvas, Node, Column);
      // Disabled node color overrides all other variants.
      if (vsDisabled in Node.States) or not Enabled then
        Canvas.Font.Color := Colors.DisabledColor;

      // The edit control flag will ensure that no partial line is displayed, that is, only lines
      // which are (vertically) fully visible are drawn.
      DrawFormat := DT_NOPREFIX or DT_WORDBREAK or DT_END_ELLIPSIS or DT_EDITCONTROL or AlignmentToDrawFlag[Alignment];
      if BidiMode <> bdLeftToRight then
        DrawFormat := DrawFormat or DT_RTLREADING;

      // Center the text vertically if it fits entirely into the content rect.
      if R.Bottom - R.Top > Height then
        InflateRect(R, 0, (Height - R.Bottom - R.Top) div 2);
    end
    else
    begin
      FFontChanged := False;
      TripleWidth := FEllipsisWidth;
      DoPaintText(Node, Canvas, Column, ttNormal);
      if FFontChanged then
      begin
        // If the font has been changed then the ellipsis width must be recalculated.
        TripleWidth := 0;
        // Recalculate also the width of the normal text.
        GetTextExtentPoint32(Canvas.Handle, PChar(Text), Length(Text), Size);
        NodeWidth := Size.cx + 2 * TextMargin;
      end;

      // Disabled node color overrides all other variants.
      if (vsDisabled in Node.States) or not Enabled then
        Canvas.Font.Color := Colors.DisabledColor;

      DrawFormat := DT_NOPREFIX or DT_VCENTER or DT_SINGLELINE;
      if BidiMode <> bdLeftToRight then
        DrawFormat := DrawFormat or DT_RTLREADING;
      // Check if the text must be shortend.
      if (Column > -1) and ((NodeWidth - 2 * TextMargin) > R.Right - R.Left) then
      begin
        Text := DoShortenString(Canvas, Node, Column, Text, R.Right - R.Left, TripleWidth);
        if Alignment = taRightJustify then
          DrawFormat := DrawFormat or DT_RIGHT
        else
          DrawFormat := DrawFormat or DT_LEFT;
      end
      else
        DrawFormat := DrawFormat or AlignmentToDrawFlag[Alignment];
    end;
    //todo_lcl_check
    if not Canvas.TextStyle.Opaque then
      SetBkMode(Canvas.Handle, TRANSPARENT)
    else
      SetBkMode(Canvas.Handle, OPAQUE);
    {$ifdef DEBUG_VTV}Logger.Send([lcPaintDetails],'Canvas.Brush.Color',Canvas.Brush.Color);{$endif}
    DoTextDrawing(PaintInfo, Text, R, DrawFormat);
  end;
  {$ifdef DEBUG_VTV}Logger.ExitMethod([lcPaintDetails],'PaintNormalText');{$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.PaintStaticText(const PaintInfo: TVTPaintInfo; TextOutFlags: Integer;
  const Text: String);

// This method retrives and draws the static text bound to a particular node.

var
  R: TRect;
  DrawFormat: Cardinal;

begin
  {$ifdef DEBUG_VTV}Logger.EnterMethod([lcPaintDetails],'PaintStaticText');{$endif}
  with PaintInfo do
  begin
    Canvas.Font := Font;
    if Font.Color = clDefault then
      Canvas.Font.Color := GetDefaultColor(dctFont);
    if toFullRowSelect in TreeOptions.SelectionOptions then
    begin
      if Node = DropTargetNode then
      begin
        if (LastDropMode = dmOnNode) or (vsSelected in Node.States) then
          Canvas.Font.Color := Colors.SelectionTextColor
        else
          Canvas.Font.Color := Colors.NodeFontColor;
      end
      else
        if vsSelected in Node.States then
        begin
          if Focused or (toPopupMode in TreeOptions.PaintOptions) then
          Canvas.Font.Color := Colors.SelectionTextColor
          else
            Canvas.Font.Color := Colors.NodeFontColor;
        end;
      if Canvas.Font.Color = clDefault then
        Canvas.Font.Color := GetDefaultColor(dctFont);
    end;

    DrawFormat := DT_NOPREFIX or DT_VCENTER or DT_SINGLELINE;
    //todo_lcl See how Canvas.TextStyle should be
    //Canvas.TextFlags := 0;
    DoPaintText(Node, Canvas, Column, ttStatic);

    // Disabled node color overrides all other variants.
    if (vsDisabled in Node.States) or not Enabled then
      Canvas.Font.Color := Colors.DisabledColor;

    R := ContentRect;
    if Alignment = taRightJustify then
      Dec(R.Right, NodeWidth + TextMargin)
    else
      Inc(R.Left, NodeWidth + TextMargin);
    //todo_lcl_check
    if not Canvas.TextStyle.Opaque then
      SetBkMode(Canvas.Handle, TRANSPARENT)
    else
      SetBkMode(Canvas.Handle, OPAQUE);
    DrawText(Canvas.Handle, PChar(Text), Length(Text), R, DrawFormat)
  end;
  {$ifdef DEBUG_VTV}Logger.ExitMethod([lcPaintDetails],'PaintStaticText');{$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.SaveToCSVFile(
  const FileNameWithPath: TFileName; const IncludeHeading: Boolean): Boolean;
var
  LResultList : TStringList;
begin
  Result := False;
  if (FileNameWithPath = '') then
    Exit;

  LResultList := TStringList.Create;
  try
    { Get the data from grid. }
    GetDataFromGrid(LResultList, IncludeHeading);
    { Save File to Disk }
    LResultList.SaveToFile(FileNameWithPath);
    Result := True;
  finally
    FreeAndNil(LResultList);
  end;//try-finally
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.SetDefaultText(const Value: String);

begin
  if FDefaultText <> Value then
  begin
    FDefaultText := Value;
    if not (csLoading in ComponentState) then
      Invalidate;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.SetOptions(const Value: TCustomStringTreeOptions);

begin
  inherited TreeOptions.Assign(Value);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.SetText(Node: PVirtualNode; Column: TColumnIndex; const Value: String);

begin
  DoNewText(Node, Column, Value);
  InvalidateNode(Node);
end;

//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.CMFontChanged(var Msg: TLMessage);

// Whenever a new font is applied to the tree some default values are determined to avoid frequent
// determination of the same value.

var
  MemDC: HDC;
  Run: PVirtualNode;
  TM: TTextMetric;
  Size: TSize;
  Data: PInteger;

begin
  inherited;

  MemDC := CreateCompatibleDC(0);
  try
    SelectObject(MemDC, Font.Reference.Handle);
    GetTextMetrics(MemDC, TM);
    FTextHeight := TM.tmHeight;

    GetTextExtentPoint32(MemDC, '...', 3, Size);
    FEllipsisWidth := Size.cx;
  finally
    DeleteDC(MemDC);
  end;

  // Have to reset all node widths.
  Run := RootNode.FirstChild;
  while Assigned(Run) do
  begin
    Data := InternalData(Run);
    if Assigned(Data) then
      Data^ := 0;
    Run := GetNextNoInit(Run);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.AddChild(Parent: PVirtualNode; UserData: Pointer): PVirtualNode;
var
  NewNodeText: String;
begin
  Result := inherited AddChild(Parent, UserData);
  // Restore the prviously restored node if the caption of this node is knwon and no other node was selected
  if (toRestoreSelection in TreeOptions.SelectionOptions) and Assigned(FPreviouslySelected) and Assigned(OnGetText) then
  begin
    // See if this was the previously selected node and restore it in this case
    Self.OnGetText(Self, Result, 0, ttNormal, NewNodeText);
    if FPreviouslySelected.IndexOf(NewNodeText) >= 0 then
    begin
      // Select this node and make sure that the parent node is expanded
      TreeStates:= TreeStates + [tsPreviouslySelectedLocked];
      try
        Self.Selected[Result] := True;
      finally
        TreeStates:= TreeStates - [tsPreviouslySelectedLocked];
      end;
      // if a there is a selected node now, then make sure that it is visible
      if Self.GetFirstSelected <> nil then
        Self.ScrollIntoView(Self.GetFirstSelected, True);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.AdjustPaintCellRect(var PaintInfo: TVTPaintInfo; out NextNonEmpty: TColumnIndex);

// In the case a node spans several columns (if enabled) we need to determine how many columns.
// Note: the autospan feature can only be used with left-to-right layout.

begin
  if (toAutoSpanColumns in TreeOptions.AutoOptions) and Header.UseColumns and (PaintInfo.BidiMode = bdLeftToRight) then
    with Header.Columns, PaintInfo do
    begin
      // Start with the directly following column.
      NextNonEmpty := GetNextVisibleColumn(Column);

      // Auto spanning columns can only be used for left-to-right directionality because the tree is drawn
      // from left to right. For RTL directionality it would be necessary to draw it from right to left.
      // While this could be managed, it becomes impossible when directionality is mixed.
      repeat
        if (NextNonEmpty = InvalidColumn) or not ColumnIsEmpty(Node, NextNonEmpty) or
          (Items[NextNonEmpty].BidiMode <> bdLeftToRight) then
          Break;
        Inc(CellRect.Right, Items[NextNonEmpty].Width);
        NextNonEmpty := GetNextVisibleColumn(NextNonEmpty);
      until False;
    end
    else
      inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.CalculateStaticTextWidth(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: String): Integer;

begin
  Result := 0;
  if (Length(Text) > 0) and (Alignment <> taCenter) and not
     (vsMultiline in Node.States) and (toShowStaticText in TreeOptions.StringOptions) then
  begin
    DoPaintText(Node, Canvas, Column, ttStatic);

    Inc(Result, DoTextMeasuring(Canvas, Node, Column, Text).cx);
    Inc(Result, TextMargin);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.CalculateTextWidth(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: String): Integer;

// Determines the width of the given text.

begin
  Result := 2 * TextMargin;
  if Length(Text) > 0 then
  begin
    Canvas.Font := Font;
    DoPaintText(Node, Canvas, Column, ttNormal);

    Inc(Result, DoTextMeasuring(Canvas, Node, Column, Text).cx);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ColumnIsEmpty(Node: PVirtualNode; Column: TColumnIndex): Boolean;

// For hit tests it is necessary to consider cases where columns are empty and automatic column spanning is enabled.
// This method simply checks the given column's text and if this is empty then the column is considered as being empty.

begin
  Result := Length(Text[Node, Column]) = 0;
  // If there is no text then let the ancestor decide if the column is to be considered as being empty
  // (e.g. by asking the application). If there is text then the column is never be considered as being empty.
  if Result then
    Result := inherited ColumnIsEmpty(Node, Column);
end;

//----------------------------------------------------------------------------------------------------------------------
{$ifndef LCLWin32}
procedure TCustomVirtualStringTree.CopyToClipBoard;
begin
  if SelectedCount > 0 then
  begin
    MarkCutCopyNodes;
    DoStateChange([tsCopyPending]);
    Clipboard.AsText := ContentToUTF8(tstCutCopySet, #9);
    DoStateChange([], [tsCopyPending]);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.CutToClipBoard;
begin
  //todo: currently there's no way in LCL to know when the clipboard was used
  CopyToClipBoard;
end;
{$endif}

destructor TCustomVirtualStringTree.Destroy;
begin
  FreeAndNil(FPreviouslySelected);
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoCreateEditor(Node: PVirtualNode; Column: TColumnIndex): IVTEditLink;

begin
  Result := inherited DoCreateEditor(Node, Column);
  // Enable generic label editing support if the application does not have own editors.
  if Result = nil then
    Result := TStringEditLink.Create;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoGetNodeHint(Node: PVirtualNode; Column: TColumnIndex;
  var LineBreakStyle: TVTTooltipLineBreakStyle): String;

begin
  Result := inherited DoGetNodeHint(Node, Column, LineBreakStyle);
  if Assigned(FOnGetHint) then
    FOnGetHint(Self, Node, Column, LineBreakStyle, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoGetNodeTooltip(Node: PVirtualNode; Column: TColumnIndex;
  var LineBreakStyle: TVTTooltipLineBreakStyle): String;

begin
  Result := inherited DoGetNodeToolTip(Node, Column, LineBreakStyle);
  if Assigned(FOnGetHint) then
    FOnGetHint(Self, Node, Column, LineBreakStyle, Result)
  else
    Result := Text[Node, Column];
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoGetNodeExtraWidth(Node: PVirtualNode; Column: TColumnIndex;
  Canvas: TCanvas = nil): Integer;

begin
    if Canvas = nil then
      Canvas := Self.Canvas;
    Result := CalculateStaticTextWidth(Canvas, Node, Column, StaticText[Node, Column]);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoGetNodeWidth(Node: PVirtualNode; Column: TColumnIndex; Canvas: TCanvas = nil): Integer;

// Returns the text width of the given node in pixels.
// This width is stored in the node's data member to increase access speed.

var
  Data: PInteger;

begin
  if (Column > NoColumn) and (vsMultiline in Node.States) then
    Result := Header.Columns[Column].Width
  else
  begin
    if Canvas = nil then
      Canvas := Self.Canvas;

    if Column = Header.MainColumn then
    begin
      // Primary column or no columns.
      Data := InternalData(Node);
      if Assigned(Data) then
      begin
        Result := Data^;
        if Result = 0 then
        begin
          Data^ := CalculateTextWidth(Canvas, Node, Column, Text[Node, Column]);
          Result := Data^;
        end;
      end
      else
        Result := 0;
    end
    else
      // any other column
      Result := CalculateTextWidth(Canvas, Node, Column, Text[Node, Column]);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.DoGetText(Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var Text: String);

begin
  if Assigned(FOnGetText) then
    FOnGetText(Self, Node, Column, TextType, Text);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoIncrementalSearch(Node: PVirtualNode; const Text: String): Integer;

// Since the string tree has access to node text it can do incremental search on its own. Use the event to
// override the default behavior.

begin
  Result := 0;
  if Assigned(OnIncrementalSearch) then
    OnIncrementalSearch(Self, Node, Text, Result)
  else
    // Default behavior is to match the search string with the start of the node text.
    if Pos(Text, GetText(Node, FocusedColumn)) <> 1 then
      Result := 1;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.DoNewText(Node: PVirtualNode; Column: TColumnIndex; const Text: String);

begin
  if Assigned(FOnNewText) then
    FOnNewText(Self, Node, Column, Text);

  // The width might have changed, so update the scrollbar.
  if UpdateCount = 0 then
    UpdateHorizontalScrollBar(True);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.DoPaintNode(var PaintInfo: TVTPaintInfo);

// Main output routine to print the text of the given node using the space provided in PaintInfo.ContentRect.

var
  S: String;
  TextOutFlags: Integer;

begin
  {$ifdef DEBUG_VTV}Logger.EnterMethod([lcPaintDetails],'TCustomVirtualStringTree.DoPaintNode');{$endif}
  // Set a new OnChange event for the canvas' font so we know if the application changes it in the callbacks.
  // This long winded procedure is necessary because font changes (as well as brush and pen changes) are
  // unfortunately not announced via the Canvas.OnChange event.
  RedirectFontChangeEvent(PaintInfo.Canvas);
  try

    // Determine main text direction as well as other text properties.
    TextOutFlags := ETO_CLIPPED or RTLFlag[PaintInfo.BidiMode <> bdLeftToRight];
    S := Text[PaintInfo.Node, PaintInfo.Column];

    // Paint the normal text first...
    if Length(S) > 0 then
      PaintNormalText(PaintInfo, TextOutFlags, S);

    // ... and afterwards the static text if not centered and the node is not multiline enabled.
    if (Alignment <> taCenter) and not (vsMultiline in PaintInfo.Node.States) and (toShowStaticText in TreeOptions.StringOptions) then
    begin
      S := '';
      with PaintInfo do
        DoGetText(Node, Column, ttStatic, S);
      if Length(S) > 0 then
        PaintStaticText(PaintInfo, TextOutFlags, S);
    end;
  finally
    RestoreFontChangeEvent(PaintInfo.Canvas);
  end;
  {$ifdef DEBUG_VTV}Logger.ExitMethod([lcPaintDetails],'TCustomVirtualStringTree.DoPaintNode');{$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.DoPaintText(Node: PVirtualNode; const Canvas: TCanvas; Column: TColumnIndex;
  TextType: TVSTTextType);

begin
  if Assigned(FOnPaintText) then
    FOnPaintText(Self, Canvas, Node, Column, TextType);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoShortenString(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const S: String; Width: Integer; EllipsisWidth: Integer = 0): String;

var
  Done: Boolean;

begin
  Result := '';
  Done := False;
  if Assigned(FOnShortenString) then
    FOnShortenString(Self, Canvas, Node, Column, S, Width, Result, Done);
  if not Done then
    Result := ShortenString(Canvas.Handle, S, Width, EllipsisWidth);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.DoTextDrawing(var PaintInfo: TVTPaintInfo; const Text: String; CellRect: TRect;
  DrawFormat: Cardinal);

var
  DefaultDraw: Boolean;

begin
  DefaultDraw := True;
  if Assigned(FOnDrawText) then
    FOnDrawText(Self, PaintInfo.Canvas, PaintInfo.Node, PaintInfo.Column, Text, CellRect, DefaultDraw);
  if DefaultDraw then
    DrawText(PaintInfo.Canvas.Handle, PChar(Text), Length(Text), CellRect, DrawFormat);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.DoTextMeasuring(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: String): TSize;

var
  R: TRect;
  DrawFormat: Integer;

begin
  GetTextExtentPoint32(Canvas.Handle, PChar(Text), Length(Text), Result);
  if vsMultiLine in Node.States then
  begin
    DrawFormat := DT_CALCRECT or DT_NOPREFIX or DT_WORDBREAK or DT_END_ELLIPSIS or DT_EDITCONTROL or AlignmentToDrawFlag[Alignment];
    if BidiMode <> bdLeftToRight then
      DrawFormat := DrawFormat or DT_RTLREADING;

    R := Rect(0, 0, Result.cx, MaxInt);
    DrawText(Canvas.Handle, PChar(Text), Length(Text), R, DrawFormat);
    Result.cx := R.Right - R.Left;
  end;
  if Assigned(FOnMeasureTextWidth) then
    FOnMeasureTextWidth(Self, Canvas, Node, Column, Text, Result.cx);
  if Assigned(FOnMeasureTextHeight) then
    FOnMeasureTextHeight(Self, Canvas, Node, Column, Text, Result.cy);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.GetOptionsClass: TTreeOptionsClass;

begin
  Result := TCustomStringTreeOptions;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.InternalData(Node: PVirtualNode): Pointer;

begin
  if (Node = RootNode) or (Node = nil) then
    Result := nil
  else
    Result := PByte(Node) + FInternalDataOffset;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.MainColumnChanged;

var
  Run: PVirtualNode;
  Data: PInteger;

begin
  inherited;

  // Have to reset all node widths.
  Run := RootNode.FirstChild;
  while Assigned(Run) do
  begin
    Data := InternalData(Run);
    if Assigned(Data) then
      Data^ := 0;
    Run := GetNextNoInit(Run);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ReadChunk(Stream: TStream; Version: Integer; Node: PVirtualNode; ChunkType,
  ChunkSize: Integer): Boolean;

// read in the caption chunk if there is one

var
  NewText: String;

begin
  case ChunkType of
    CaptionChunk:
      begin
        NewText := '';
        if ChunkSize > 0 then
        begin
          SetLength(NewText, ChunkSize);
          Stream.Read(PChar(NewText)^, ChunkSize);
        end;
        // Do a new text event regardless of the caption content to allow removing the default string.
        Text[Node, Header.MainColumn] := NewText;
        Result := True;
      end;
  else
    Result := inherited ReadChunk(Stream, Version, Node, ChunkType, ChunkSize);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.RenderOLEData(const FormatEtcIn: TFormatEtc; out Medium: TStgMedium;
  ForClipboard: Boolean): HResult;

// Returns string expressions of all currently selected nodes in the Medium structure.

begin
  Result := inherited RenderOLEData(FormatEtcIn, Medium, ForClipboard);
  if Failed(Result) then
  try
    if ForClipboard then
      Medium.hGlobal := ContentToClipboard(FormatEtcIn.cfFormat, tstCutCopySet)
    else
      Medium.hGlobal := ContentToClipboard(FormatEtcIn.cfFormat, tstSelected);

    // Fill rest of the Medium structure if rendering went fine.
    if Medium.hGlobal <> 0 then
    begin
      Medium.tymed := TYMED_HGLOBAL;
      Medium.PunkForRelease := nil;

      Result := S_OK;
    end;
  except
    Result := E_FAIL;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.WriteChunks(Stream: TStream; Node: PVirtualNode);

// Adds another sibling chunk for Node storing the label if the node is initialized.
// Note: If the application stores a node's caption in the node's data member (which will be quite common) and needs to
//       store more node specific data then it should use the OnSaveNode event rather than the caption autosave function
//       (take out soSaveCaption from StringOptions). Otherwise the caption is unnecessarily stored twice.

var
  ChunkHeader: TChunkHeader;
  S: String;
  Len: Integer;

begin
  inherited;
  if (toSaveCaptions in TreeOptions.StringOptions) and (Node <> RootNode) and
    (vsInitialized in Node.States) then
    with Stream do
    begin
      // Read the node's caption (primary column only).
      S := Text[Node, Header.MainColumn];
      Len := Length(S);
      if Len > 0 then
      begin
        // Write a new sub chunk.
        ChunkHeader.ChunkType := CaptionChunk;
        ChunkHeader.ChunkSize := Len;
        Write(ChunkHeader, SizeOf(ChunkHeader));
        Write(PChar(S)^, Len);
      end;
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ComputeNodeHeight(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  S: String): Integer;

// Default node height calculation for multi line nodes. This method can be used by the application to delegate the
// computation to the string tree.
// Canvas is used to compute that value by using its current font settings.
// Node and Column describe the cell to be used for the computation.
// S is the string for which the height must be computed. If this string is empty the cell text is used instead.

var
  DrawFormat: Cardinal;
  BidiMode: TBidiMode;
  Alignment: TAlignment;
  PaintInfo: TVTPaintInfo;
  Dummy: TColumnIndex;
  LineImage: TLineImage;
begin
  if Length(S) = 0 then
    S := Text[Node, Column];
  DrawFormat := DT_TOP or DT_NOPREFIX or DT_CALCRECT or DT_WORDBREAK;
  if Column <= NoColumn then
  begin
    BidiMode := Self.BidiMode;
    Alignment := Self.Alignment;
  end
  else
  begin
    BidiMode := Header.Columns[Column].BidiMode;
    Alignment := Header.Columns[Column].Alignment;
  end;

  if BidiMode <> bdLeftToRight then
    ChangeBidiModeAlignment(Alignment);

  // Allow for autospanning.
  PaintInfo.Node := Node;
  PaintInfo.BidiMode := BidiMode;
  PaintInfo.Column := Column;
  PaintInfo.CellRect := Rect(0, 0, 0, 0);
  if Column > NoColumn then
  begin
    PaintInfo.CellRect.Right := Header.Columns[Column].Width - TextMargin;
    PaintInfo.CellRect.Left := TextMargin + Margin;
    if Column = Header.MainColumn then
    begin
      if toFixedIndent in TreeOptions.PaintOptions then
        SetLength(LineImage, 1)
      else
        DetermineLineImageAndSelectLevel(Node, LineImage);
    Inc(PaintInfo.CellRect.Left, Length(LineImage) * Integer(Indent));
    end;
  end
  else
    PaintInfo.CellRect.Right := ClientWidth;
  AdjustPaintCellRect(PaintInfo, Dummy);

  if BidiMode <> bdLeftToRight then
    DrawFormat := DrawFormat or DT_RIGHT or DT_RTLREADING
  else
    DrawFormat := DrawFormat or DT_LEFT;
  DrawText(Canvas.Handle, PChar(S), Length(S), PaintInfo.CellRect, DrawFormat);
  Result := PaintInfo.CellRect.Bottom - PaintInfo.CellRect.Top;
  if toShowHorzGridLines in TreeOptions.PaintOptions then
    Inc(Result);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ContentToClipboard(Format: TClipboardFormat; Source: TVSTTextSourceType): HGLOBAL;
{$ifdef LCLWin32}

// This method constructs a shareable memory object filled with string data in the required format. Supported are:
// CF_TEXT - plain ANSI text (Unicode text is converted using the user's current locale)
// CF_UNICODETEXT - plain Unicode text
// CF_CSV - comma separated plain ANSI text
// CF_VRTF + CF_RTFNOOBS - rich text (plain ANSI)
// CF_HTML - HTML text encoded using UTF-8
//
// Result is the handle to a globally allocated memory block which can directly be used for clipboard and drag'n drop
// transfers. The caller is responsible for freeing the memory. If for some reason the content could not be rendered
// the Result is 0.

  //--------------- local function --------------------------------------------

  procedure MakeFragment(var HTML: string);

  // Helper routine to build a properly-formatted HTML fragment.

  const
    Version = 'Version:1.0'#13#10;
    StartHTML = 'StartHTML:';
    EndHTML = 'EndHTML:';
    StartFragment = 'StartFragment:';
    EndFragment = 'EndFragment:';
    DocType = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">';
    HTMLIntro = '<html><head><META http-equiv=Content-Type content="text/html; charset=utf-8">' +
      '</head><body><!--StartFragment-->';
    HTMLExtro = '<!--EndFragment--></body></html>';
    NumberLengthAndCR = 10;

    // Let the compiler determine the description length.
    DescriptionLength = Length(Version) + Length(StartHTML) + Length(EndHTML) + Length(StartFragment) +
      Length(EndFragment) + 4 * NumberLengthAndCR;

  var
    Description: string;
    StartHTMLIndex,
    EndHTMLIndex,
    StartFragmentIndex,
    EndFragmentIndex: Integer;

  begin
    // The HTML clipboard format is defined by using byte positions in the entire block where HTML text and
    // fragments start and end. These positions are written in a description. Unfortunately the positions depend on the
    // length of the description but the description may change with varying positions.
    // To solve this dilemma the offsets are converted into fixed length strings which makes it possible to know
    // the description length in advance.
    StartHTMLIndex := DescriptionLength;              // position 0 after the description
    StartFragmentIndex := StartHTMLIndex + Length(DocType) + Length(HTMLIntro);
    EndFragmentIndex := StartFragmentIndex + Length(HTML);
    EndHTMLIndex := EndFragmentIndex + Length(HTMLExtro);

    Description := Version +
      SysUtils.Format('%s%.8d', [StartHTML, StartHTMLIndex]) + #13#10 +
      SysUtils.Format('%s%.8d', [EndHTML, EndHTMLIndex]) + #13#10 +
      SysUtils.Format('%s%.8d', [StartFragment, StartFragmentIndex]) + #13#10 +
      SysUtils.Format('%s%.8d', [EndFragment, EndFragmentIndex]) + #13#10;
    HTML := Description + DocType + HTMLIntro + HTML + HTMLExtro;
  end;

  //--------------- end local function ----------------------------------------

var
  Data: Pointer;
  DataSize: Cardinal;
  S: string;
  WS: UnicodeString;
  P: Pointer;

{$endif}
begin           
  Result := 0;
{$ifdef LCLWin32}
  case Format of
    CF_TEXT:
      begin
        S := ContentToAnsi(Source, #9) + #0;
        Data := PChar(S);
        DataSize := Length(S);
      end;
    CF_UNICODETEXT:
      begin
        WS := ContentToUTF16(Source, #9) + #0;
        Data := PWideChar(WS);
        DataSize := 2 * Length(WS);
      end;
  else
    if Format = CF_CSV then
      S := ContentToAnsi(Source, DefaultFormatSettings.ListSeparator) + #0
    else
      if (Format = CF_VRTF) or (Format = CF_VRTFNOOBJS) then
        S := ContentToRTF(Source) + #0
      else
        if Format = CF_HTML then
        begin
          S := ContentToHTML(Source);
          // Build a valid HTML clipboard fragment.
          MakeFragment(S);
          S := S + #0;
        end;
    Data := PChar(S);
    DataSize := Length(S);
  end;

  if DataSize > 0 then
  begin
    Result := GlobalAlloc(GHND or GMEM_SHARE, DataSize);
    P := GlobalLock(Result);
    Move(Data^, P^, DataSize);
    GlobalUnlock(Result);
  end;
{$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ContentToHTML(Source: TVSTTextSourceType; const Caption: String = ''): String;

// Renders the current tree content (depending on Source) as HTML text encoded in UTF-8.
// If Caption is not empty then it is used to create and fill the header for the table built here.
// Based on ideas and code from Frank van den Bergh and Andreas Hörstemeier.

begin
  Result := VirtualTrees.Export.ContentToHTML(Self, Source, Caption);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.CanExportNode(Node: PVirtualNode): Boolean;

begin
  case TreeOptions.ExportMode of
    emChecked:
      Result := Node.CheckState = csCheckedNormal;
    emUnchecked:
      Result := Node.CheckState = csUncheckedNormal;
    emVisibleDueToExpansion: //Do not export nodes that are not visible because their parent is not expanded
      Result := not Assigned(Node.Parent) or Self.Expanded[Node.Parent];
    emSelected: // export selected nodes only
      Result := Selected[Node];
    else
      Result := True;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.AddToSelection(Node: PVirtualNode);
var
  lSelectedNodeCaption: String;
begin
  inherited;
  if (toRestoreSelection in TreeOptions.SelectionOptions) and Assigned(Self.OnGetText) and Self.Selected[Node] and not (tsPreviouslySelectedLocked in TreeStates) then
  begin
    if not Assigned(FPreviouslySelected) then
    begin
      FPreviouslySelected := TStringList.Create();
      FPreviouslySelected.Duplicates := dupIgnore;
      FPreviouslySelected.Sorted := True; //Improves performance, required to use Find()
      FPreviouslySelected.CaseSensitive := False;
    end;
    if Self.SelectedCount = 1 then
      FPreviouslySelected.Clear();
    Self.OnGetText(Self, Node, 0, ttNormal, lSelectedNodeCaption);
    FPreviouslySelected.Add(lSelectedNodeCaption);
  end;//if
  UpdateNextNodeToSelect(Node);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.RemoveFromSelection(Node: PVirtualNode);
var
  lSelectedNodeCaption: String;
  lIndex: Integer;
begin
  inherited;
  if (toRestoreSelection in TreeOptions.SelectionOptions) and Assigned(FPreviouslySelected) and not Self.Selected[Node] then
  begin
    if Self.SelectedCount = 0 then
      FPreviouslySelected.Clear()
    else
    begin
      Self.OnGetText(Self, Node, 0, ttNormal, lSelectedNodeCaption);
      if FPreviouslySelected.Find(lSelectedNodeCaption, lIndex) then
        FPreviouslySelected.Delete(lIndex);
    end;//else
  end;//if
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ContentToRTF(Source: TVSTTextSourceType): String;
// Renders the current tree content (depending on Source) as RTF (rich text).
// Based on ideas and code from Frank van den Bergh and Andreas Hörstemeier.

begin
  Result := VirtualTrees.Export.ContentToRTF(Self, Source);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.ContentToCustom(Source: TVSTTextSourceType);

// Generic export procedure which polls the application at every stage of the export.

begin
  VirtualTrees.Export.ContentToCustom(Self, Source);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ContentToAnsi(Source: TVSTTextSourceType; const Separator: String): AnsiString;
var
  Buffer: TBufferedUTF8String;
begin
  Buffer := TBufferedUTF8String.Create;
  try
    AddContentToBuffer(Buffer, Source, Separator);
  finally
    Result := Buffer.AsAnsiString;
    Buffer.Destroy;
  end;
end;

function TCustomVirtualStringTree.ContentToText(Source: TVSTTextSourceType;
  const Separator: String): AnsiString;
begin
  Result := ContentToAnsi(Source, Separator);
end;

function TCustomVirtualStringTree.ContentToUnicode(Source: TVSTTextSourceType;
  const Separator: String): UnicodeString;
begin
  Result := ContentToUTF16(Source, Separator);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.AddContentToBuffer(Buffer: TBufferedUTF8String; Source: TVSTTextSourceType; const Separator: String);

// Renders the current tree content (depending on Source) as UTF8 text.
// If an entry contains the separator char or double quotes then it is wrapped with double quotes
// and existing double quotes are duplicated.

var
  RenderColumns: Boolean;
  Tabs: String;
  GetNextNode: TGetNextNodeProc;
  Run, Save: PVirtualNode;
  Level, MaxLevel: Cardinal;
  Columns: TColumnsArray;
  LastColumn: TVirtualTreeColumn;
  Index,
  I: Integer;
  Text: String;
begin
  Columns := nil;
  RenderColumns := Header.UseColumns;
  if RenderColumns then
    Columns := Header.Columns.GetVisibleColumns;

  GetRenderStartValues(Source, Run, GetNextNode);
  Save := Run;

  // The text consists of visible groups representing the columns, which are separated by one or more separator
  // characters. There are always MaxLevel separator chars in a line (main column only). Either before the caption
  // to ident it or after the caption to make the following column aligned.
  MaxLevel := 0;
  while Assigned(Run) do
  begin
    Level := GetNodeLevel(Run);
      if Level > MaxLevel then
      MaxLevel := Level;
    Run := GetNextNode(Run);
  end;

  Tabs := DupeString(Separator, MaxLevel);

  // First line is always the header if used.
  if RenderColumns then
  begin
    LastColumn := Columns[High(Columns)];
    for I := 0 to High(Columns) do
    begin
      Buffer.Add(Columns[I].Text);
      if Columns[I] <> LastColumn then
      begin
        if Columns[I].Index = Header.MainColumn then
        begin
          Buffer.Add(Tabs);
          Buffer.Add(Separator);
        end
        else
          Buffer.Add(Separator);
      end;
    end;
    Buffer.AddNewLine;
  end
  else
    LastColumn := nil;

  Run := Save;
  if RenderColumns then
  begin
    while Assigned(Run) do
    begin
      if (not CanExportNode(Run) or
         (Assigned(OnBeforeNodeExport) and (not OnBeforeNodeExport(Self, etText, Run)))) then
      begin
        Run := GetNextNode(Run);
        Continue;
      end;
      for I := 0 to High(Columns) do
      begin
        if coVisible in Columns[I].Options then
        begin
          Index := Columns[I].Index;
          // This line implicitly converts the Unicode text to ANSI.
          Text := Self.Text[Run, Index];
          if Index = Header.MainColumn then
          begin
            Level := GetNodeLevel(Run);
            Buffer.Add(Copy(Tabs, 1, Integer(Level) * Length(Separator)));
            // Wrap the text with quotation marks if it contains the separator character.
            if (Pos(Separator, Text) > 0) or (Pos('"', Text) > 0) then
              Buffer.Add(AnsiQuotedStr(Text, '"'))
            else
              Buffer.Add(Text);
            Buffer.Add(Copy(Tabs, 1, Integer(MaxLevel - Level) * Length(Separator)));
          end
          else
            if (Pos(Separator, Text) > 0) or (Pos('"', Text) > 0) then
              Buffer.Add(AnsiQuotedStr(Text, '"'))
            else
              Buffer.Add(Text);

          if Columns[I] <> LastColumn then
            Buffer.Add(Separator);
        end;
      end;
      if Assigned(OnAfterNodeExport) then
        OnAfterNodeExport(Self, etText, Run);
      Run := GetNextNode(Run);
      Buffer.AddNewLine;
    end;
  end
  else
  begin
    while Assigned(Run) do
    begin
      if ((not CanExportNode(Run)) or
         (Assigned(OnBeforeNodeExport) and (not OnBeforeNodeExport(Self, etText, Run)))) then
      begin
        Run := GetNextNode(Run);
        Continue;
      end;
      // This line implicitly converts the Unicode text to ANSI.
      Text := Self.Text[Run, NoColumn];
      Level := GetNodeLevel(Run);
      Buffer.Add(Copy(Tabs, 1, Integer(Level) * Length(Separator)));
      Buffer.Add(Text);
      Buffer.AddNewLine;

      if Assigned(OnAfterNodeExport) then
          OnAfterNodeExport(Self, etText, Run);
      Run := GetNextNode(Run);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ContentToUTF16(Source: TVSTTextSourceType; const Separator: String): UnicodeString;
var
  Buffer: TBufferedUTF8String;
begin
  Buffer := TBufferedUTF8String.Create;
  try
    AddContentToBuffer(Buffer, Source, Separator);
  finally
    Result := Buffer.AsUTF16String;
    Buffer.Destroy;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.ContentToUTF8(Source: TVSTTextSourceType;
  const Separator: String): String;
var
  Buffer: TBufferedUTF8String;
begin
  Buffer := TBufferedUTF8String.Create;
  try
    AddContentToBuffer(Buffer, Source, Separator);
  finally
    Result := Buffer.AsUTF8String;
    Buffer.Destroy;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.GetTextInfo(Node: PVirtualNode; Column: TColumnIndex; const AFont: TFont; var R: TRect;
  out Text: String);

// Returns the font, the text and its bounding rectangle to the caller. R is returned as the closest
// bounding rectangle around Text.

var
  NewHeight: Integer;
  TM: TTextMetric;

begin
  // Get default font and initialize the other parameters.
  //inherited GetTextInfo(Node, Column, AFont, R, Text);

  Canvas.Font := AFont;

  FFontChanged := False;
  RedirectFontChangeEvent(Canvas);
  DoPaintText(Node, Canvas, Column, ttNormal);
  if FFontChanged then
  begin
    AFont.Assign(Canvas.Font);
    GetTextMetrics(Canvas.Handle, TM);
    NewHeight := TM.tmHeight;
  end
  else // Otherwise the correct font is already there and we only need to set the correct height.
    NewHeight := FTextHeight;
  RestoreFontChangeEvent(Canvas);

  // Alignment to the actual text.
  Text := Self.Text[Node, Column];
  R := GetDisplayRect(Node, Column, True, not (vsMultiline in Node.States));
  if toShowHorzGridLines in TreeOptions.PaintOptions then
    Dec(R.Bottom);
  InflateRect(R, 0, -(R.Bottom - R.Top - NewHeight) div 2);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.InvalidateNode(Node: PVirtualNode): TRect;

var
  Data: PInteger;

begin
  Result := inherited InvalidateNode(Node);
  // Reset node width so changed text attributes are applied correctly.
  if Assigned(Node) then
  begin
    Data := InternalData(Node);
    if Assigned(Data) then
      Data^ := 0;
    // Reset height measured flag too to cause a re-issue of the OnMeasureItem event.
    Exclude(Node.States, vsHeightMeasured);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCustomVirtualStringTree.Path(Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  Delimiter: Char): String;

// Constructs a string containing the node and all its parents. The last character in the returned path is always the
// given delimiter.

var
  S: String;

begin
  if (Node = nil) or (Node = RootNode) then
    Result := Delimiter
  else
  begin
    Result := '';
    while Node <> RootNode do
    begin
      DoGetText(Node, Column, TextType, S);
      Result := S + Delimiter + Result;
      Node := Node.Parent;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCustomVirtualStringTree.ReinitNode(Node: PVirtualNode; Recursive: Boolean);

var
  Data: PInteger;

begin
  inherited;
  // Reset node width so changed text attributes are applied correctly.
  if Assigned(Node) and (Node <> RootNode) then
  begin
    Data := InternalData(Node);
    if Assigned(Data) then
      Data^ := 0;
    // vsHeightMeasured is already removed in the base tree.
  end;
end;

//----------------- TVirtualStringTree ---------------------------------------------------------------------------------

function TVirtualStringTree.GetOptions: TStringTreeOptions;

begin
  Result := inherited TreeOptions as TStringTreeOptions;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualStringTree.SetOptions(const Value: TStringTreeOptions);

begin
  inherited TreeOptions.Assign(Value);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualStringTree.GetOptionsClass: TTreeOptionsClass;

begin
  Result := TStringTreeOptions;
end;

{ TVSTGetCellTextEventArgs }

//----------------------------------------------------------------------------------------------------------------------

constructor TVSTGetCellTextEventArgs.Create(pNode: PVirtualNode; pColumn: TColumnIndex; pExportType: TVTExportType);
begin
  Self.Node := pNode;
  Self.Column := pColumn;
  Self.ExportType := pExportType;
end;

//----------------------------------------------------------------------------------------------------------------------

{$if CompilerVersion >= 23}
class constructor TVirtualStringTree.Create();
begin
  TCustomStyleEngine.RegisterStyleHook(TVirtualStringTree, TVclStyleScrollBarsHook);
end;
{$ifend}

end.

