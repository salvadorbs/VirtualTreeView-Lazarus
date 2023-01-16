unit VirtualTrees.Header;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  LMessages, Types, LCLIntf, LCLType, Controls, Classes, StdCtrls, Themes, Graphics,
  {$ifdef Windows}
  Windows,
  ActiveX,
  CommCtrl,
  UxTheme,
  {$else}
  FakeActiveX,
  {$endif}
  {$ifdef DEBUG_VTV}
  VirtualTrees.Logger,
  {$endif}
  SysUtils
  , DelphiCompat
  , VirtualTrees.Types
  , VirtualTrees.DragImage
  , ImgList
  , Menus
  , LCLVersion;

const
  DefaultColumnOptions = [coAllowClick, coDraggable, coEnabled, coParentColor, coParentBidiMode, coResizable,
    coShowDropmark, coVisible, coAllowFocus, coEditable];

type
  TVTHeader = class;

  TVirtualTreeColumn = class;

  // This structure carries all important information about header painting and is used in the advanced header painting.
  THeaderPaintInfo = record
    TargetCanvas: TCanvas;
    Column: TVirtualTreeColumn;
    PaintRectangle: TRect;
    TextRectangle: TRect;
    IsHoverIndex,
    IsDownIndex,
    IsEnabled,
    ShowHeaderGlyph,
    ShowSortGlyph,
    ShowRightBorder: Boolean;
    DropMark: TVTDropMarkMode;
    GlyphPos,
    SortGlyphPos: TPoint;
  end;

  // tree columns implementation
  TVirtualTreeColumns = class;

  { TVirtualTreeColumn }

  TVirtualTreeColumn = class(TCollectionItem)
  private
    FText,
    FHint: TTranslateString;
    FLeft,
    FWidth: Integer;
    FPosition: TColumnPosition;
    FMinWidth: Integer;
    FMaxWidth: Integer;
    FStyle: TVirtualTreeColumnStyle;
    FImageIndex: TImageIndex;
    FBiDiMode: TBiDiMode;
    FLayout: TVTHeaderColumnLayout;
    FMargin,
    FSpacing: Integer;
    FOptions: TVTColumnOptions;
    FTag: NativeInt;
    FAlignment: TAlignment;
    FCaptionAlignment: TAlignment;     // Alignment of the caption.
    FLastWidth: Integer;
    FColor: TColor;
    FBonusPixel: Boolean;
    FSpringRest: Single;               // Accumulator for width adjustment when auto spring option is enabled.
    FCaptionText: String;
    FCheckBox: Boolean;
    FCheckType: TCheckType;
    FCheckState: TCheckState;
    FImageRect: TRect;
    FHasImage: Boolean;
    FDefaultSortDirection: TSortDirection;
    function GetCaptionAlignment: TAlignment;
    function GetLeft: Integer;
    function IsBiDiModeStored: Boolean;
    function IsCaptionAlignmentStored: Boolean;
    function IsColorStored: Boolean;
    function IsMarginStored: Boolean;
    function IsSpacingStored: Boolean;
    function IsWidthStored: Boolean;
    procedure SetAlignment(const Value: TAlignment);
    procedure SetBiDiMode(Value: TBiDiMode);
    procedure SetCaptionAlignment(const Value: TAlignment);
    procedure SetCheckBox(Value: Boolean);
    procedure SetCheckState(Value: TCheckState);
    procedure SetCheckType(Value: TCheckType);
    procedure SetColor(const Value: TColor);
    procedure SetImageIndex(Value: TImageIndex);
    procedure SetLayout(Value: TVTHeaderColumnLayout);
    procedure SetMargin(Value: Integer);
    procedure SetMaxWidth(Value: Integer);
    procedure SetMinWidth(Value: Integer);
    procedure SetOptions(Value: TVTColumnOptions);
    procedure SetPosition(Value: TColumnPosition);
    procedure SetSpacing(Value: Integer);
    procedure SetStyle(Value: TVirtualTreeColumnStyle);
    procedure SetWidth(Value: Integer);
  protected
    procedure ComputeHeaderLayout(DC: HDC; const Client: TRect; UseHeaderGlyph, UseSortGlyph: Boolean;
      var HeaderGlyphPos, SortGlyphPos: TPoint; var SortGlyphSize: TSize; var TextBounds: TRect; DrawFormat: Cardinal;
      CalculateTextRect: Boolean = False);
    procedure GetAbsoluteBounds(var Left, Right: Integer);
    function GetDisplayName: string; override;
    function GetText: String; virtual; // [IPK]
    procedure SetText(const Value: TTranslateString); virtual; // [IPK] private to protected & virtual
    function GetOwner: TVirtualTreeColumns; reintroduce;
    procedure InternalSetWidth(const Value : Integer); //bypass side effects in SetWidth
    property HasImage: Boolean read FHasImage;
    property ImageRect: TRect read FImageRect;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;

    procedure Assign(Source: TPersistent); override;
    function Equals(OtherColumnObj: TObject): Boolean; override;
    function GetRect: TRect; virtual;
    procedure LoadFromStream(const Stream: TStream; Version: Integer);
    procedure ParentBiDiModeChanged;
    procedure ParentColorChanged;
    procedure RestoreLastWidth;
    procedure SaveToStream(const Stream: TStream);
    function UseRightToLeftReading: Boolean;

    property Left: Integer read GetLeft;
    property Owner: TVirtualTreeColumns read GetOwner;
  published
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property BiDiMode: TBiDiMode read FBiDiMode write SetBiDiMode stored IsBiDiModeStored;
    property CaptionAlignment: TAlignment read GetCaptionAlignment write SetCaptionAlignment
      stored IsCaptionAlignmentStored default taLeftJustify;
    property CaptionText: String read FCaptionText stored False;
    property CheckType: TCheckType read FCheckType write SetCheckType default ctCheckBox;
    property CheckState: TCheckState read FCheckState write SetCheckState default csUncheckedNormal;
    property CheckBox: Boolean read FCheckBox write SetCheckBox default False;
    property Color: TColor read FColor write SetColor stored IsColorStored;
    property DefaultSortDirection: TSortDirection read FDefaultSortDirection write FDefaultSortDirection default sdAscending;
    property Hint: TTranslateString read FHint write FHint stored False;
    property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
    property Layout: TVTHeaderColumnLayout read FLayout write SetLayout default blGlyphLeft;
    property Margin: Integer read FMargin write SetMargin stored IsMarginStored;
    property MaxWidth: Integer read FMaxWidth write SetMaxWidth default 10000;
    property MinWidth: Integer read FMinWidth write SetMinWidth default 10;
    property Options: TVTColumnOptions read FOptions write SetOptions default DefaultColumnOptions;
    property Position: TColumnPosition read FPosition write SetPosition;
    property Spacing: Integer read FSpacing write SetSpacing stored IsSpacingStored;
    property Style: TVirtualTreeColumnStyle read FStyle write SetStyle default vsText;
    property Tag: NativeInt read FTag write FTag default 0;
    property Text: TTranslateString read GetText write SetText;
    property Width: Integer read FWidth write SetWidth stored IsWidthStored;
  end;

  TVirtualTreeColumnClass = class of TVirtualTreeColumn;

  TColumnsArray = array of TVirtualTreeColumn;
  TCardinalArray = array of Cardinal;
  TIndexArray = array of TColumnIndex;

  TVirtualTreeColumns = class(TCollection)
  private
    FHeader: TVTHeader;
    FHeaderBitmap: Graphics.TBitmap;      // backbuffer for drawing
    FHoverIndex,                          // currently "hot" column
    FDownIndex,                           // Column on which a mouse button is held down.
    FTrackIndex: TColumnIndex;            // Index of column which is currently being resized.
    FClickIndex: TColumnIndex;            // Index of the last clicked column.
    FCheckBoxHit: Boolean;                // True if the last click was on a header checkbox.
    FPositionToIndex: TIndexArray;
    FDefaultWidth: Integer;               // the width columns are created with
    FNeedPositionsFix: Boolean;           // True if FixPositions must still be called after DFM loading or Bidi mode change.
    FClearing: Boolean;                   // True if columns are being deleted entirely.

    function GetItem(Index: TColumnIndex): TVirtualTreeColumn;
    function GetNewIndex(P: TPoint; var OldIndex: TColumnIndex): Boolean;
    function IsDefaultWidthStored: Boolean;
    procedure SetDefaultWidth(Value: Integer);
    procedure SetItem(Index: TColumnIndex; Value: TVirtualTreeColumn);
  protected
    // drag support
    FDragIndex: TColumnIndex;             // index of column currently being dragged
    FDropTarget: TColumnIndex;            // current target column (index) while dragging
    FDropBefore: Boolean;                 // True if drop position is in the left half of a column, False for the right
                                          // side to drop the dragged column to

    procedure AdjustAutoSize(CurrentIndex: TColumnIndex; Force: Boolean = False);
    function AdjustDownColumn(P: TPoint): TColumnIndex;
    function AdjustHoverColumn(const P: TPoint): Boolean;
    procedure AdjustPosition(Column: TVirtualTreeColumn; Position: Cardinal);
    function CanSplitterResize(P: TPoint; Column: TColumnIndex): Boolean;
    procedure DoCanSplitterResize(P: TPoint; Column: TColumnIndex; var Allowed: Boolean); virtual;
    procedure DrawButtonText(DC: HDC; Caption: String; Bounds: TRect; Enabled, Hot: Boolean; DrawFormat: Cardinal;
      WrapCaption: Boolean);
    procedure FixPositions;
    function GetColumnAndBounds(const P: TPoint; var ColumnLeft, ColumnRight: Integer; Relative: Boolean = True): Integer;
    function GetOwner: TPersistent; override;
    procedure HandleClick(P: TPoint; Button: TMouseButton; Force, DblClick: Boolean); virtual;
    procedure IndexChanged(OldIndex, NewIndex: Integer);
    procedure InitializePositionArray;
    procedure Notify(Item: TCollectionItem; Action: TCollectionNotification); override;
    procedure ReorderColumns(RTL: Boolean);
    procedure Update(Item: TCollectionItem); override;
    procedure UpdatePositions(Force: Boolean = False);

    property HeaderBitmap: Graphics.TBitmap read FHeaderBitmap;
    property PositionToIndex: TIndexArray read FPositionToIndex;
    property HoverIndex: TColumnIndex read FHoverIndex write FHoverIndex;
    property DownIndex: TColumnIndex read FDownIndex write FDownIndex;
    property CheckBoxHit: Boolean read FCheckBoxHit write FCheckBoxHit;
  public
    constructor Create(AOwner: TVTHeader); virtual;
    destructor Destroy; override;

    function Add: TVirtualTreeColumn; virtual;
    procedure AnimatedResize(Column: TColumnIndex; NewWidth: Integer);
    procedure Assign(Source: TPersistent); override;
    procedure Clear; virtual;
    function ColumnFromPosition(const P: TPoint; Relative: Boolean = True): TColumnIndex; overload; virtual;
    function ColumnFromPosition(PositionIndex: TColumnPosition): TColumnIndex; overload; virtual;
    function Equals(OtherColumnsObj: TObject): Boolean; override;
    procedure GetColumnBounds(Column: TColumnIndex; out Left, Right: Integer);
    function GetFirstVisibleColumn(ConsiderAllowFocus: Boolean = False): TColumnIndex;
    function GetLastVisibleColumn(ConsiderAllowFocus: Boolean = False): TColumnIndex;
    function GetFirstColumn: TColumnIndex;
    function GetNextColumn(Column: TColumnIndex): TColumnIndex;
    function GetNextVisibleColumn(Column: TColumnIndex; ConsiderAllowFocus: Boolean = False): TColumnIndex;
    function GetPreviousColumn(Column: TColumnIndex): TColumnIndex;
    function GetPreviousVisibleColumn(Column: TColumnIndex; ConsiderAllowFocus: Boolean = False): TColumnIndex;
    function GetScrollWidth: Integer;
    function GetVisibleColumns: TColumnsArray;
    function GetVisibleFixedWidth: Integer;
    function IsValidColumn(Column: TColumnIndex): Boolean;
    procedure LoadFromStream(const Stream: TStream; Version: Integer);
    procedure PaintHeader(DC: HDC; const R: TRect; HOffset: Integer); overload; virtual;
    procedure PaintHeader(TargetCanvas: TCanvas; R: TRect; const Target: TPoint;
      RTLOffset: Integer = 0); overload; virtual;
    procedure SaveToStream(const Stream: TStream);
    function TotalWidth: Integer;

    property ClickIndex: TColumnIndex read FClickIndex write FClickIndex;
    property DefaultWidth: Integer read FDefaultWidth write SetDefaultWidth stored IsDefaultWidthStored;
    property Items[Index: TColumnIndex]: TVirtualTreeColumn read GetItem write SetItem; default;
    property Header: TVTHeader read FHeader;
    property TrackIndex: TColumnIndex read FTrackIndex;
  end;

  TVirtualTreeColumnsClass = class of TVirtualTreeColumns;

  TVTConstraintPercent = 0..100;

  TVTFixedAreaConstraints = class(TPersistent)
  private
    FHeader: TVTHeader;
    FMaxHeightPercent,
    FMaxWidthPercent,
    FMinHeightPercent,
    FMinWidthPercent: TVTConstraintPercent;
    FOnChange: TNotifyEvent;
    procedure SetConstraints(Index: Integer; Value: TVTConstraintPercent);
  protected
    procedure Change;
    property Header: TVTHeader read FHeader;
  public
    constructor Create(AOwner: TVTHeader);

    procedure Assign(Source: TPersistent); override;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property MaxHeightPercent: TVTConstraintPercent index 0 read FMaxHeightPercent write SetConstraints default 0;
    property MaxWidthPercent: TVTConstraintPercent index 1 read FMaxWidthPercent write SetConstraints default 0;
    property MinHeightPercent: TVTConstraintPercent index 2 read FMinHeightPercent write SetConstraints default 0;
    property MinWidthPercent: TVTConstraintPercent index 3 read FMinWidthPercent write SetConstraints default 0;
  end;

  TVTHeaderStyle = (
    hsThickButtons,    // TButton look and feel
    hsFlatButtons,     // flatter look than hsThickButton, like an always raised flat TToolButton
    hsPlates          // flat TToolButton look and feel (raise on hover etc.)
  );

  TVTHeaderOption = (
    hoAutoResize,            // Adjust a column so that the header never exceeds the client width of the owner control.
    hoColumnResize,          // Resizing columns with the mouse is allowed.
    hoDblClickResize,        // Allows a column to resize itself to its largest entry.
    hoDrag,                  // Dragging columns is allowed.
    hoHotTrack,              // Header captions are highlighted when mouse is over a particular column.
    hoOwnerDraw,             // Header items with the owner draw style can be drawn by the application via event.
    hoRestrictDrag,          // Header can only be dragged horizontally.
    hoShowHint,              // Show application defined header hint.
    hoShowImages,            // Show header images.
    hoShowSortGlyphs,        // Allow visible sort glyphs.
    hoVisible,               // Header is visible.
    hoAutoSpring,            // Distribute size changes of the header to all columns, which are sizable and have the
                             // coAutoSpring option enabled.
    hoFullRepaintOnResize,   // Fully invalidate the header (instead of subsequent columns only) when a column is resized.
    hoDisableAnimatedResize, // Disable animated resize for all columns.
    hoHeightResize,          // Allow resizing header height via mouse.
    hoHeightDblClickResize,  // Allow the header to resize itself to its default height.
    hoHeaderClickAutoSort    // Clicks on the header will make the clicked column the SortColumn or toggle sort direction if
                             // it already was the sort column
  );
  TVTHeaderOptions = set of TVTHeaderOption;

  THeaderState = (
    hsAutoSizing,              // auto size chain is in progess, do not trigger again on WM_SIZE
    hsDragging,                // header dragging is in progress (only if enabled)
    hsDragPending,             // left button is down, user might want to start dragging a column
    hsLoading,                 // The header currently loads from stream, so updates are not necessary.
    hsColumnWidthTracking,     // column resizing is in progress
    hsColumnWidthTrackPending, // left button is down, user might want to start resize a column
    hsHeightTracking,          // height resizing is in progress
    hsHeightTrackPending,      // left button is down, user might want to start changing height
    hsResizing,                // multi column resizing in progress
    hsScaling,                 // the header is scaled after a change of FixedAreaConstraints or client size
    hsNeedScaling              // the header needs to be scaled
  );
  THeaderStates = set of THeaderState;

  { TVTHeader }

  TVTHeader = class(TPersistent)
  private
    FOwner: TCustomControl;
    FColumns: TVirtualTreeColumns;
    FHeight: Integer;
    FFont: TFont;
    FParentFont: Boolean;
    FOptions: TVTHeaderOptions;
    FStyle: TVTHeaderStyle;            // button style
    FBackground: TColor;
    FAutoSizeIndex: TColumnIndex;
    FPopupMenu: TPopupMenu;
    FMainColumn: TColumnIndex;         // the column which holds the tree
    FMaxHeight: Integer;
    FMinHeight: Integer;
    FDefaultHeight: Integer;
    FFixedAreaConstraints: TVTFixedAreaConstraints; // Percentages for the fixed area (header, fixed columns).
    FImages: TCustomImageList;
    FImageChangeLink: TChangeLink;     // connections to the image list to get notified about changes
    {$IF LCL_FullVersion >= 2000000}
    FImagesWidth: Integer;
    {$IFEND}
    FSortColumn: TColumnIndex;
    FSortDirection: TSortDirection;
    FDragImage: TVTDragImage;          // drag image management during header drag
    FLastWidth: Integer;               // Used to adjust spring columns. This is the width of all visible columns,
                                       // not the header rectangle.
    procedure FontChanged(Sender: TObject);
    function GetMainColumn: TColumnIndex;
    function GetUseColumns: Boolean;
    function IsDefaultHeightStored: Boolean;
    function IsFontStored: Boolean;
    function IsHeightStored: Boolean;
    procedure SetAutoSizeIndex(Value: TColumnIndex);
    procedure SetBackground(Value: TColor);
    procedure SetColumns(Value: TVirtualTreeColumns);
    procedure SetDefaultHeight(Value: Integer);
    procedure SetFont(const Value: TFont);
    procedure SetHeight(Value: Integer);
    procedure SetImages(const Value: TCustomImageList);
    {$IF LCL_FullVersion >= 2000000}
    procedure SetImagesWidth(const Value: Integer);
    {$IFEND}
    procedure SetMainColumn(Value: TColumnIndex);
    procedure SetMaxHeight(Value: Integer);
    procedure SetMinHeight(Value: Integer);
    procedure SetOptions(Value: TVTHeaderOptions);
    procedure SetParentFont(Value: Boolean);
    procedure SetSortColumn(Value: TColumnIndex);
    procedure SetSortDirection(const Value: TSortDirection);
    procedure SetStyle(Value: TVTHeaderStyle);
  protected
    FStates: THeaderStates;            // Used to keep track of internal states the header can enter.
    FDragStart: TPoint;                // initial mouse drag position
    FTrackStart: TPoint;               // client coordinates of the tracking start point
    FTrackPoint: TPoint;               // Client coordinate where the tracking started.
    function CanSplitterResize(P: TPoint): Boolean;
    function CanWriteColumns: Boolean; virtual;
    procedure ChangeScale(M, D: Integer); virtual;
    function DetermineSplitterIndex(const P: TPoint): Boolean; virtual;
    procedure DoAfterAutoFitColumn(Column: TColumnIndex); virtual;
    procedure DoAfterColumnWidthTracking(Column: TColumnIndex); virtual;
    procedure DoAfterHeightTracking; virtual;
    function DoBeforeAutoFitColumn(Column: TColumnIndex; SmartAutoFitType: TSmartAutoFitType): Boolean; virtual;
    procedure DoBeforeColumnWidthTracking(Column: TColumnIndex; Shift: TShiftState); virtual;
    procedure DoBeforeHeightTracking(Shift: TShiftState); virtual;
    procedure DoCanSplitterResize(P: TPoint; var Allowed: Boolean); virtual;
    function DoColumnWidthDblClickResize(Column: TColumnIndex; P: TPoint; Shift: TShiftState): Boolean; virtual;
    function DoColumnWidthTracking(Column: TColumnIndex; Shift: TShiftState; var TrackPoint: TPoint; P: TPoint): Boolean; virtual;
    function DoGetPopupMenu(Column: TColumnIndex; Position: TPoint): TPopupMenu; virtual;
    function DoHeightTracking(var P: TPoint; Shift: TShiftState): Boolean; virtual;
    function DoHeightDblClickResize(var P: TPoint; Shift: TShiftState): Boolean; virtual;
    procedure DoSetSortColumn(Value: TColumnIndex); virtual;
    procedure DragTo(const P: TPoint);
    procedure FixedAreaConstraintsChanged(Sender: TObject);
    function GetColumnsClass: TVirtualTreeColumnsClass; virtual;
    function GetOwner: TPersistent; override;
    function GetShiftState: TShiftState;
    function HandleHeaderMouseMove(var Message: TLMMouseMove): Boolean;
    function HandleMessage(var Message: TLMessage): Boolean; virtual;
    procedure ImageListChange(Sender: TObject);
    procedure PrepareDrag(P, Start: TPoint);
    procedure RecalculateHeader; virtual;
    procedure RescaleHeader;
    procedure UpdateMainColumn;
    procedure UpdateSpringColumns;
    procedure InternalSetMainColumn(const Index : TColumnIndex);
    procedure InternalSetAutoSizeIndex(const Index : TColumnIndex);
    procedure InternalSetSortColumn(const Index : TColumnIndex);
  public
    constructor Create(AOwner: TCustomControl); virtual;
    destructor Destroy; override;

    function AllowFocus(ColumnIndex: TColumnIndex): Boolean;
    procedure Assign(Source: TPersistent); override;
    {$IF LCL_FullVersion >= 1080000}
    procedure AutoAdjustLayout(const AXProportion, AYProportion: Double); virtual;
    {$IFEND}
    procedure AutoFitColumns(Animated: Boolean = True; SmartAutoFitType: TSmartAutoFitType = smaUseColumnOption;
      RangeStartCol: Integer = NoColumn; RangeEndCol: Integer = NoColumn); virtual;
    {$IF LCL_FullVersion >= 2010000}
    procedure FixDesignFontsPPI(const ADesignTimePPI: Integer); virtual;
    {$IFEND}
    function InHeader(const P: TPoint): Boolean; virtual;
    function InHeaderSplitterArea(P: TPoint): Boolean; virtual;
    procedure Invalidate(Column: TVirtualTreeColumn; ExpandToBorder: Boolean = False);
    procedure LoadFromStream(const Stream: TStream); virtual;
    function ResizeColumns(ChangeBy: Integer; RangeStartCol: TColumnIndex; RangeEndCol: TColumnIndex;
      Options: TVTColumnOptions = [coVisible]): Integer;
    procedure RestoreColumns;
    procedure SaveToStream(const Stream: TStream); virtual;

    property DragImage: TVTDragImage read FDragImage;
    property States: THeaderStates read FStates;
    property Treeview: TCustomControl read FOwner;
    property UseColumns: Boolean read GetUseColumns;
  published
    property AutoSizeIndex: TColumnIndex read FAutoSizeIndex write SetAutoSizeIndex;
    property Background: TColor read FBackground write SetBackground default clBtnFace;
    property Columns: TVirtualTreeColumns read FColumns write SetColumns;
    property DefaultHeight: Integer read FDefaultHeight write SetDefaultHeight stored IsDefaultHeightStored;
    property Font: TFont read FFont write SetFont stored IsFontStored;
    property FixedAreaConstraints: TVTFixedAreaConstraints read FFixedAreaConstraints write FFixedAreaConstraints;
    property Height: Integer read FHeight write SetHeight stored IsHeightStored;
    property Images: TCustomImageList read FImages write SetImages;
    {$IF LCL_FullVersion >= 2000000}
    property ImagesWidth: Integer read FImagesWidth write SetImagesWidth default 0;
    {$IFEND}
    property MainColumn: TColumnIndex read GetMainColumn write SetMainColumn default 0;
    property MaxHeight: Integer read FMaxHeight write SetMaxHeight default 10000;
    property MinHeight: Integer read FMinHeight write SetMinHeight default 10;
    property Options: TVTHeaderOptions read FOptions write SetOptions default [hoColumnResize, hoDrag, hoShowSortGlyphs];
    property ParentFont: Boolean read FParentFont write SetParentFont default False;
    property PopupMenu: TPopupMenu read FPopupMenu write FPopupMenu;
    property SortColumn: TColumnIndex read FSortColumn write SetSortColumn default NoColumn;
    property SortDirection: TSortDirection read FSortDirection write SetSortDirection default sdAscending;
    property Style: TVTHeaderStyle read FStyle write SetStyle default hsThickButtons;
  end;

  TVTHeaderClass = class of TVTHeader;

implementation

uses
  VirtualTrees, VirtualTrees.BaseTree, Math, Forms, VirtualTrees.Graphics;

type
  TVirtualTreeColumnsCracker = class(TVirtualTreeColumns);
  TVirtualTreeColumnCracker = class(TVirtualTreeColumn);
  TBaseVirtualTreeCracker = class(TBaseVirtualTree);

  TVTHeaderHelper = class helper for TVTHeader
  public
    function Tree : TBaseVirtualTreeCracker;
  end;

  TVirtualTreeColumnHelper = class helper for TVirtualTreeColumn
    function TreeViewControl : TBaseVirtualTreeCracker;
    function Header : TVTHeader;
  end;

  TVirtualTreeColumnsHelper = class helper for TVirtualTreeColumns
    function TreeViewControl : TBaseVirtualTreeCracker;
  end;

//----------------- TVTFixedAreaConstraints ----------------------------------------------------------------------------

constructor TVTFixedAreaConstraints.Create(AOwner: TVTHeader);

begin
  inherited Create;

  FHeader := AOwner;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTFixedAreaConstraints.SetConstraints(Index: Integer; Value: TVTConstraintPercent);

begin
  case Index of
    0:
      if Value <> FMaxHeightPercent then
      begin
        FMaxHeightPercent := Value;
        if (Value > 0) and (Value < FMinHeightPercent) then
          FMinHeightPercent := Value;
        Change;
      end;
    1:
      if Value <> FMaxWidthPercent then
      begin
        FMaxWidthPercent := Value;
        if (Value > 0) and (Value < FMinWidthPercent) then
          FMinWidthPercent := Value;
        Change;
      end;
    2:
      if Value <> FMinHeightPercent then
      begin
        FMinHeightPercent := Value;
        if (FMaxHeightPercent > 0) and (Value > FMaxHeightPercent) then
          FMaxHeightPercent := Value;
        Change;
      end;
    3:
      if Value <> FMinWidthPercent then
      begin
        FMinWidthPercent := Value;
        if (FMaxWidthPercent > 0) and (Value > FMaxWidthPercent) then
          FMaxWidthPercent := Value;
        Change;
      end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTFixedAreaConstraints.Change;

begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTFixedAreaConstraints.Assign(Source: TPersistent);

begin
  if Source is TVTFixedAreaConstraints then
  begin
    FMaxHeightPercent := TVTFixedAreaConstraints(Source).FMaxHeightPercent;
    FMaxWidthPercent := TVTFixedAreaConstraints(Source).FMaxWidthPercent;
    FMinHeightPercent := TVTFixedAreaConstraints(Source).FMinHeightPercent;
    FMinWidthPercent := TVTFixedAreaConstraints(Source).FMinWidthPercent;
    Change;
  end
  else
    inherited;
end;

//----------------- TVTHeader -----------------------------------------------------------------------------------------

constructor TVTHeader.Create(AOwner: TCustomControl);

begin
  inherited Create;
  FOwner := AOwner;
  FColumns := GetColumnsClass.Create(Self);
  {$IF LCL_FullVersion >= 1080000}
  FHeight := FOwner.Scale96ToFont(DEFAULT_HEADER_HEIGHT);
  FDefaultHeight := FOwner.Scale96ToFont(DEFAULT_HEADER_HEIGHT);
  {$ELSE}
  FHeight := DEFAULT_HEADER_HEIGHT;
  FDefaultHeight := DEFAULT_HEADER_HEIGHT;
  {$IFEND}
  FMinHeight := 10;
  FMaxHeight := 10000;
  FFont := TFont.Create;
  FFont.OnChange := FontChanged;
  FParentFont := False;
  FBackground := clBtnFace;
  FOptions := [hoColumnResize, hoDrag, hoShowSortGlyphs];

  FImageChangeLink := TChangeLink.Create;
  FImageChangeLink.OnChange := ImageListChange;

  FSortColumn := NoColumn;
  FSortDirection := sdAscending;
  FMainColumn := NoColumn;

  FDragImage := TVTDragImage.Create(AOwner);
  with FDragImage do
  begin
    Fade := False;
    PostBlendBias := 0;
    PreBlendBias := -50;
    Transparency := 140;
  end;

  FFixedAreaConstraints := TVTFixedAreaConstraints.Create(Self);
  FFixedAreaConstraints.OnChange := FixedAreaConstraintsChanged;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TVTHeader.Destroy;

begin
  FDragImage.Free;
  FFixedAreaConstraints.Free;
  FImageChangeLink.Free;
  FFont.Free;
  FColumns.Clear; // TCollection's Clear method is not virtual, so we have to call our own Clear method manually.
  FColumns.Free;
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.FontChanged(Sender: TObject);
var
  I: Integer;
  lMaxHeight: Integer;
begin
  if toAutoChangeScale in Tree.TreeOptions.AutoOptions then
  begin
    // Find the largest Columns[].Spacing
    lMaxHeight := 0;
    for I := 0 to Self.Columns.Count - 1 do
      lMaxHeight := Max(lMaxHeight, Columns[I].Spacing);
    // Calculate the required size based on the font, this is important as the use migth just vave increased the size of the icon font
    with Graphics.TBitmap.Create do
      try
        Canvas.Font.Assign(FFont);
        lMaxHeight := lMaxHeight {top spacing} + (lMaxHeight div 2) {minimum bottom spacing} + Canvas.TextHeight('Q');
      finally
        Free;
      end;
    // Get the maximum of the scaled original value an
    lMaxHeight := Max(lMaxHeight, FHeight);
    // Set the calculated size
    Self.SetHeight(lMaxHeight);
  end;
  Invalidate(nil);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.GetMainColumn: TColumnIndex;

begin
  if FColumns.Count > 0 then
    Result := FMainColumn
  else
    Result := NoColumn;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.GetUseColumns: Boolean;

begin
  Result := FColumns.Count > 0;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.IsDefaultHeightStored: Boolean;
begin
  {$IF LCL_FullVersion >= 1080000}
  Result := FDefaultHeight <> FOwner.Scale96ToFont(DEFAULT_HEADER_HEIGHT);
  {$ELSE}
  Result := FDefaultHeight <> DEFAULT_HEADER_HEIGHT;
  {$IFEND}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.IsFontStored: Boolean;

begin
  Result := not ParentFont;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.IsHeightStored: Boolean;
begin
  {$IF LCL_FullVersion >= 1080000}
  Result := FHeight <> FOwner.Scale96ToFont(DEFAULT_HEADER_HEIGHT);
  {$ELSE}
  Result := FHeight <> DEFAULT_HEADER_HEIGHT;
  {$IFEND}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetAutoSizeIndex(Value: TColumnIndex);

begin
  if FAutoSizeIndex <> Value then
  begin
    FAutoSizeIndex := Value;
    if hoAutoResize in FOptions then
      Columns.AdjustAutoSize(InvalidColumn);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetBackground(Value: TColor);

begin
  if FBackground <> Value then
  begin
    FBackground := Value;
    Invalidate(nil);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetColumns(Value: TVirtualTreeColumns);

begin
  FColumns.Assign(Value);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetDefaultHeight(Value: Integer);

begin
  if Value < FMinHeight then
    Value := FMinHeight;
  if Value > FMaxHeight then
    Value := FMaxHeight;

  if FHeight = FDefaultHeight then
    SetHeight(Value);
  FDefaultHeight := Value;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetFont(const Value: TFont);

begin
  FFont.Assign(Value);
  FParentFont := False;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetHeight(Value: Integer);

var
  RelativeMaxHeight,
  RelativeMinHeight,
  EffectiveMaxHeight,
  EffectiveMinHeight: Integer;

begin
  if not TreeView.HandleAllocated then
  begin
    FHeight := Value;
    Include(FStates, hsNeedScaling);
  end
  else
  begin
    with FFixedAreaConstraints do
    begin
      RelativeMaxHeight := ((Treeview.ClientHeight + FHeight) * FMaxHeightPercent) div 100;
      RelativeMinHeight := ((Treeview.ClientHeight + FHeight) * FMinHeightPercent) div 100;

      EffectiveMinHeight := IfThen(FMaxHeightPercent > 0, Min(RelativeMaxHeight, FMinHeight), FMinHeight);
      EffectiveMaxHeight := IfThen(FMinHeightPercent > 0, Max(RelativeMinHeight, FMaxHeight), FMaxHeight);

      Value := Min(Max(Value, EffectiveMinHeight), EffectiveMaxHeight);
      if FMinHeightPercent > 0 then
        Value := Max(RelativeMinHeight, Value);
      if FMaxHeightPercent > 0 then
        Value := Min(RelativeMaxHeight, Value);
    end;

    if FHeight <> Value then
    begin
      FHeight := Value;
      if not (csLoading in Treeview.ComponentState) and not (hsScaling in FStates) then
        RecalculateHeader;
      Treeview.Invalidate;
      UpdateWindow(Treeview.Handle);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetImages(const Value: TCustomImageList);

begin
  if FImages <> Value then
  begin
    if Assigned(FImages) then
    begin
      FImages.UnRegisterChanges(FImageChangeLink);
      FImages.RemoveFreeNotification(FOwner);
    end;
    FImages := Value;
    if Assigned(FImages) then
    begin
      FImages.RegisterChanges(FImageChangeLink);
      FImages.FreeNotification(FOwner);
    end;
    if not (csLoading in Treeview.ComponentState) then
      Invalidate(nil);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

{$IF LCL_FullVersion >= 2000000}
procedure TVTHeader.SetImagesWidth(const Value: Integer);
begin
  if Value <> FImagesWidth then begin
    FImagesWidth := Value;
    Invalidate(nil);
  end;
end;
{$IFEND}

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetMainColumn(Value: TColumnIndex);

begin
  if csLoading in Treeview.ComponentState then
    FMainColumn := Value
  else
  begin
    if Value < 0 then
      Value := 0;
    if Value > FColumns.Count - 1 then
      Value := FColumns.Count - 1;
    if Value <> FMainColumn then
    begin
      FMainColumn := Value;
      if Treeview.HandleAllocated then
      begin
        Tree.MainColumnChanged;
        if not (toExtendedFocus in Tree.TreeOptions.SelectionOptions) then
          Tree.FocusedColumn := Value;
        Treeview.Invalidate;
      end
      else
      begin
        if not (toExtendedFocus in Tree.TreeOptions.SelectionOptions) then
          Tree.FocusedColumn := Value;
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetMaxHeight(Value: Integer);

begin
  if Value < FMinHeight then
    Value := FMinHeight;
  FMaxHeight := Value;
  SetHeight(FHeight);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetMinHeight(Value: Integer);

begin
  if Value < 0 then
    Value := 0;
  if Value > FMaxHeight then
    Value := FMaxHeight;
  FMinHeight := Value;
  SetHeight(FHeight);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetOptions(Value: TVTHeaderOptions);

var
  ToBeSet,
  ToBeCleared: TVTHeaderOptions;

begin
  ToBeSet := Value - FOptions;
  ToBeCleared := FOptions - Value;
  FOptions := Value;

  if (hoAutoResize in (ToBeSet + ToBeCleared)) and (FColumns.Count > 0) then
  begin
    FColumns.AdjustAutoSize(InvalidColumn);
    if Tree.HandleAllocated then
    begin
      Tree.UpdateHorizontalScrollBar(False);
      if hoAutoResize in ToBeSet then
        Treeview.Invalidate;
    end;
  end;

  if not (csLoading in Treeview.ComponentState) and Treeview.HandleAllocated then
  begin
    if hoVisible in (ToBeSet + ToBeCleared) then
      RecalculateHeader;
    Invalidate(nil);
    Treeview.Invalidate;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetParentFont(Value: Boolean);

begin
  if FParentFont <> Value then
  begin
    FParentFont := Value;
    if FParentFont then
      FFont.Assign(FOwner.Font);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetSortColumn(Value: TColumnIndex);

begin
  if csLoading in Treeview.ComponentState then
    FSortColumn := Value
  else
    DoSetSortColumn(Value);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetSortDirection(const Value: TSortDirection);

begin
  if Value <> FSortDirection then
  begin
    FSortDirection := Value;
    Invalidate(nil);
    if ((toAutoSort in Tree.TreeOptions.AutoOptions) or (hoHeaderClickAutoSort in Options)) and (Tree.UpdateCount = 0) then
      Tree.SortTree(FSortColumn, FSortDirection, True);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.CanSplitterResize(P: TPoint): Boolean;

begin
  Result := hoHeightResize in FOptions;
  DoCanSplitterResize(P, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SetStyle(Value: TVTHeaderStyle);

begin
  if FStyle <> Value then
  begin
    FStyle := Value;
    if not (csLoading in Treeview.ComponentState) then
      Invalidate(nil);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.CanWriteColumns: Boolean;

// descendants may override this to optionally prevent column writing (e.g. if they are build dynamically).

begin
  Result := True;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.ChangeScale(M, D: Integer);
var
  I: Integer;
begin
  // This method is only executed if toAutoChangeScale is set
  if not ParentFont then
    FFont.Size := MulDiv(FFont.Size, M, D);
  Self.Height := MulDiv(FHeight, M, D);
  // Scale the columns widths too
  for I := 0 to FColumns.Count - 1 do
  begin
    Self.FColumns[I].Width := MulDiv(Self.FColumns[I].Width, M, D);
  end;//for I
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.DetermineSplitterIndex(const P: TPoint): Boolean;

// Tries to find the index of that column whose right border corresponds to P.
// Result is True if column border was hit (with -3..+5 pixels tolerance).
// For continuous resizing the current track index and the column's left/right border are set.
// Note: The hit test is checking from right to left (or left to right in RTL mode) to make enlarging of zero-sized
//       columns possible.

var
  I,
  VisibleFixedWidth: Integer;
  SplitPoint: Integer;

  //--------------- local function --------------------------------------------

  function IsNearBy(IsFixedCol: Boolean; LeftTolerance, RightTolerance: Integer): Boolean;

  begin
    if IsFixedCol then
      Result := (P.X < SplitPoint + Tree.EffectiveOffsetX + RightTolerance) and (P.X > SplitPoint + Tree.EffectiveOffsetX - LeftTolerance)
    else
      Result := (P.X > VisibleFixedWidth) and (P.X < SplitPoint + RightTolerance) and (P.X > SplitPoint - LeftTolerance);
  end;

  //--------------- end local function ----------------------------------------

begin
  Result := False;
  FColumns.FTrackIndex := NoColumn;

  VisibleFixedWidth := FColumns.GetVisibleFixedWidth;

  if FColumns.Count > 0 then
  begin
    if Treeview.UseRightToLeftAlignment then
    begin
      SplitPoint := -Tree.EffectiveOffsetX;
      if Integer(Tree.RangeX) < Treeview.ClientWidth then
        Inc(SplitPoint, Treeview.ClientWidth - Integer(Tree.RangeX));

      for I := 0 to FColumns.Count - 1 do
        with TVirtualTreeColumnsCracker(FColumns), Items[FPositionToIndex[I]] do
          if coVisible in FOptions then
          begin
            if IsNearBy(coFixed in FOptions, 5, 3) then
            begin
              if CanSplitterResize(P, FPositionToIndex[I]) then
              begin
                Result := True;
                FTrackIndex := FPositionToIndex[I];

                // Keep the right border of this column. This and the current mouse position
                // directly determine the current column width.
                FTrackPoint.X := SplitPoint + IfThen(coFixed in FOptions, Tree.EffectiveOffsetX) + FWidth;
                FTrackPoint.Y := P.Y;
                Break;
              end;
            end;
            Inc(SplitPoint, FWidth);
          end;
    end
    else
    begin
      SplitPoint := -Tree.EffectiveOffsetX + Integer(Tree.RangeX);

      for I := FColumns.Count - 1 downto 0 do
        with FColumns, Items[FPositionToIndex[I]] do
          if coVisible in FOptions then
          begin
            if IsNearBy(coFixed in FOptions, 3, 5) then
            begin
              if CanSplitterResize(P, FPositionToIndex[I]) then
              begin
                Result := True;
                FTrackIndex := FPositionToIndex[I];

                // Keep the left border of this column. This and the current mouse position
                // directly determine the current column width.
                FTrackPoint.X := SplitPoint + IfThen(coFixed in FOptions, Tree.EffectiveOffsetX) - FWidth;
                FTrackPoint.Y := P.Y;
                Break;
              end;
            end;
            Dec(SplitPoint, FWidth);
          end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

{$IF LCL_FullVersion >= 1080000}
procedure TVTHeader.AutoAdjustLayout(const AXProportion, AYProportion: Double);
var
  i: Integer;
  col: TVirtualTreeColumn;
begin
  if IsDefaultHeightStored then
    FDefaultHeight := Round(FDefaultHeight * AYProportion);

  if IsHeightStored then
    FHeight := Round(FHeight * AYProportion);

    if Columns.IsDefaultWidthStored then
      Columns.DefaultWidth := Round(Columns.DefaultWidth * AXProportion);

    for i := 0 to Columns.Count-1 do begin
      col := Columns[i];
      if col.IsWidthStored then
        col.Width := Round(col.Width * AXProportion);
      if col.IsSpacingStored then
        col.Spacing := Round(col.Spacing * AXProportion);
      if col.IsMarginStored then
        col.Margin := Round(col.Margin * AXProportion);    end;
end;
{$IFEND}

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DoAfterAutoFitColumn(Column: TColumnIndex);

begin
  if Assigned(Tree.OnAfterAutoFitColumn) then
    Tree.OnAfterAutoFitColumn(Self, Column);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DoAfterColumnWidthTracking(Column: TColumnIndex);

// Tell the application that a column width tracking operation has been finished.

begin
  if Assigned(Tree.OnAfterColumnWidthTracking) then
    Tree.OnAfterColumnWidthTracking(Self, Column);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DoAfterHeightTracking;

// Tell the application that a height tracking operation has been finished.

begin
  if Assigned(Tree.OnAfterHeaderHeightTracking) then
    Tree.OnAfterHeaderHeightTracking(Self);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.DoBeforeAutoFitColumn(Column: TColumnIndex; SmartAutoFitType: TSmartAutoFitType): Boolean;

// Query the application if we may autofit a column.

begin
  Result := True;
  if Assigned(Tree.OnBeforeAutoFitColumn) then
    Tree.OnBeforeAutoFitColumn(Self, Column, SmartAutoFitType, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DoBeforeColumnWidthTracking(Column: TColumnIndex; Shift: TShiftState);

// Tell the a application that a column width tracking operation may begin.

begin
  if Assigned(Tree.OnBeforeColumnWidthTracking) then
    Tree.OnBeforeColumnWidthTracking(Self, Column, Shift);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DoBeforeHeightTracking(Shift: TShiftState);

// Tell the application that a height tracking operation may begin.

begin
  if Assigned(Tree.OnBeforeHeaderHeightTracking) then
    Tree.OnBeforeHeaderHeightTracking(Self, Shift);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DoCanSplitterResize(P: TPoint; var Allowed: Boolean);
begin
  if Assigned(Tree.OnCanSplitterResizeHeader) then
    Tree.OnCanSplitterResizeHeader(Self, P, Allowed);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.DoColumnWidthDblClickResize(Column: TColumnIndex; P: TPoint; Shift: TShiftState): Boolean;

// Queries the application whether a double click on the column splitter should resize the column.

begin
  Result := True;
  if Assigned(Tree.OnColumnWidthDblClickResize) then
    Tree.OnColumnWidthDblClickResize(Self, Column, Shift, P, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.DoColumnWidthTracking(Column: TColumnIndex; Shift: TShiftState; var TrackPoint: TPoint; P: TPoint): Boolean;

begin
  Result := True;
  if Assigned(Tree.OnColumnWidthTracking) then
    Tree.OnColumnWidthTracking(Self, Column, Shift, TrackPoint, P, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.DoGetPopupMenu(Column: TColumnIndex; Position: TPoint): TPopupMenu;

// Queries the application whether there is a column specific header popup menu.

var
  AskParent: Boolean;

begin
  Result := nil;
  if Assigned(Tree.OnGetPopupMenu) then
    Tree.OnGetPopupMenu(TBaseVirtualTree(FOwner), nil, Column, Position, AskParent, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.DoHeightTracking(var P: TPoint; Shift: TShiftState): Boolean;

begin
  Result := True;
  if Assigned(Tree.OnHeaderHeightTracking) then
    Tree.OnHeaderHeightTracking(Self, P, Shift, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.DoHeightDblClickResize(var P: TPoint; Shift: TShiftState): Boolean;

begin
  Result := True;
  if Assigned(Tree.OnHeaderHeightDblClickResize) then
    Tree.OnHeaderHeightDblClickResize(Self, P, Shift, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DoSetSortColumn(Value: TColumnIndex);

begin
  if Value < NoColumn then
    Value := NoColumn;
  if Value > Columns.Count - 1 then
    Value := Columns.Count - 1;
  if FSortColumn <> Value then
  begin
    if FSortColumn > NoColumn then
      Invalidate(Columns[FSortColumn]);
    FSortColumn := Value;
    if FSortColumn > NoColumn then
      Invalidate(Columns[FSortColumn]);
    if ((toAutoSort in Tree.TreeOptions.AutoOptions) or (hoHeaderClickAutoSort in Options)) and (Tree.UpdateCount = 0) then
      Tree.SortTree(FSortColumn, FSortDirection, True);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.DragTo(const P: TPoint);

// Moves the drag image to a new position, which is determined from the passed point P and the previous
// mouse position.

var
  I,
  NewTarget: Integer;
  // optimized drag image move support
  ClientP: TPoint;
  Left,
  Right: Integer;
  NeedRepaint: Boolean; // True if the screen needs an update (changed drop target or drop side)

begin
  // Determine new drop target and which side of it is prefered.
  ClientP := Treeview.ScreenToClient(P);
  // Make coordinates relative to (0, 0) of the non-client area.
  Inc(ClientP.Y, FHeight);
  NewTarget := FColumns.ColumnFromPosition(ClientP);
  NeedRepaint := (NewTarget <> InvalidColumn) and (NewTarget <> FColumns.FDropTarget);
  if NewTarget >= 0 then
  begin
    FColumns.GetColumnBounds(NewTarget, Left, Right);
    if (ClientP.X < ((Left + Right) div 2)) <> FColumns.FDropBefore then
    begin
      NeedRepaint := True;
      FColumns.FDropBefore := not FColumns.FDropBefore;
    end;
  end;

  if NeedRepaint then
  begin
    // Invalidate columns which need a repaint.
    if FColumns.FDropTarget > NoColumn then
    begin
      I := FColumns.FDropTarget;
      FColumns.FDropTarget := NoColumn;
      Invalidate(FColumns.Items[I]);
    end;
    if (NewTarget > NoColumn) and (NewTarget <> FColumns.FDropTarget) then
    begin
      Invalidate(FColumns.Items[NewTarget]);
      FColumns.FDropTarget := NewTarget;
    end;
  end;

  FDragImage.DragTo(P, NeedRepaint);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.FixedAreaConstraintsChanged(Sender: TObject);

// This method gets called when FFixedAreaConstraints is changed.

begin
  if Treeview.HandleAllocated then
    RescaleHeader
  else
    Include(FStates, hsNeedScaling);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.GetColumnsClass: TVirtualTreeColumnsClass;

// Returns the class to be used for the actual column implementation. descendants may optionally override this and
// return their own class.

begin
  Result := TVirtualTreeColumns;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.GetOwner: TPersistent;

begin
  Result := FOwner;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.GetShiftState: TShiftState;

begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then
    Include(Result, ssShift);
  if GetKeyState(VK_LWIN) < 0 then      // Mac OS X substitute of ssCtrl
    Include(Result, ssMeta);
  if GetKeyState(VK_CONTROL) < 0 then
    Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then
    Include(Result, ssAlt);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.HandleHeaderMouseMove(var Message: TLMMouseMove): Boolean;

var
  P: TPoint;
  NextColumn,
  I: TColumnIndex;
  NewWidth: Integer;

begin
  Result := False;
  with Message do
  begin
    P := Types.Point(XPos, YPos);
    if hsColumnWidthTrackPending in FStates then
    begin
      FStates := FStates - [hsColumnWidthTrackPending] + [hsColumnWidthTracking];
      HandleHeaderMouseMove := True;
      Result := 0;
    end
    else
      if hsHeightTrackPending in FStates then
      begin
        FStates := FStates - [hsHeightTrackPending] + [hsHeightTracking];
        HandleHeaderMouseMove := True;
        Result := 0;
      end
      else
        if hsColumnWidthTracking in FStates then
        begin
          if DoColumnWidthTracking(FColumns.FTrackIndex, GetShiftState, FTrackPoint, P) then
          begin
            if Treeview.UseRightToLeftAlignment then
            begin
              NewWidth := FTrackPoint.X - XPos;
              NextColumn := FColumns.GetPreviousVisibleColumn(FColumns.FTrackIndex);
          end
            else
            begin
              NewWidth := XPos - FTrackPoint.X;
              NextColumn := FColumns.GetNextVisibleColumn(FColumns.FTrackIndex);
            end;

            // The autosized column cannot be resized using the mouse normally. Instead we resize the next
            // visible column, so it look as we directly resize the autosized column.
            if (hoAutoResize in FOptions) and (FColumns.FTrackIndex = FAutoSizeIndex) and
               (NextColumn > NoColumn) and (coResizable in FColumns[NextColumn].FOptions) and
               (FColumns[FColumns.FTrackIndex].FMinWidth < NewWidth) and
               (FColumns[FColumns.FTrackIndex].FMaxWidth > NewWidth) then
              FColumns[NextColumn].Width := FColumns[NextColumn].Width - NewWidth
                                            + FColumns[FColumns.FTrackIndex].Width
            else
              FColumns[FColumns.FTrackIndex].Width := NewWidth; // 1 EListError seen here (List index out of bounds (-1)) since 10/2013
          end;
          HandleHeaderMouseMove := True;
          Result := 0;
        end
        else
          if hsHeightTracking in FStates then
          begin
            //lclheader
            //fixes setting height
            Dec(P.Y, FHeight);
            if DoHeightTracking(P, GetShiftState) then
              SetHeight(Integer(FHeight) + P.Y);
            HandleHeaderMouseMove := True;
            Result := 0;
          end
          else
          begin
            if hsDragPending in FStates then
            begin
              P := Treeview.ClientToScreen(P);
              // start actual dragging if allowed
              if (hoDrag in FOptions) and Tree.DoHeaderDragging(FColumns.FDownIndex) then
              begin
                if ((Abs(FDragStart.X - P.X) > DragManager.DragThreshold) or
                   (Abs(FDragStart.Y - P.Y) > DragManager.DragThreshold)) then
                begin
              {$ifdef DEBUG_VTV}Logger.Send([lcDrag], 'HandleHeaderMouseMove - DragIndex: %d - DownIndex: %d',
                [FColumns.FDragIndex, FColumns.FDownIndex]);{$endif}
                  I := FColumns.FDownIndex;
                  FColumns.FDownIndex := NoColumn;
                  FColumns.FHoverIndex := NoColumn;
                  if I > NoColumn then
                    Invalidate(FColumns[I]);
              //todo: implement drag image under gtk
                  PrepareDrag(P, FDragStart);
                  FStates := FStates - [hsDragPending] + [hsDragging];
                  HandleHeaderMouseMove := True;
                  Result := 0;
                end;
              end;
            end
            else
              if hsDragging in FStates then
              begin
                DragTo(Treeview.ClientToScreen(P));
                HandleHeaderMouseMove := True;
                Result := 0;
              end;
          end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.HandleMessage(var Message: TLMessage): Boolean;

// The header gets here the opportunity to handle certain messages before they reach the tree. This is important
// because the tree needs to handle various non-client area messages for the header as well as some dragging/tracking
// events.
// By returning True the message will not be handled further, otherwise the message is then dispatched
// to the proper message handlers.

var
  P: TPoint;
  R: TRect;
  I: TColumnIndex;
  OldPosition: Integer;
  HitIndex: TColumnIndex;
  NewCursor: HCURSOR;
  Button: TMouseButton;
  Menu: TPopupMenu;
  IsInHeader,
  IsHSplitterHit,
  IsVSplitterHit: Boolean;

  //--------------- local function --------------------------------------------

  function HSplitterHit: Boolean;

  var
    NextCol: TColumnIndex;

  begin
    Result := (hoColumnResize in FOptions) and DetermineSplitterIndex(P);
    if Result and not InHeader(P) then
    begin
      NextCol := FColumns.GetNextVisibleColumn(FColumns.FTrackIndex);
      if not (coFixed in FColumns[FColumns.FTrackIndex].Options) or (NextCol <= NoColumn) or
         (coFixed in FColumns[NextCol].Options) or (P.Y > Integer(Tree.RangeY)) then
        Result := False;
    end;
  end;

  //--------------- end local function ----------------------------------------

begin
  Result := False;
  case Message.Msg of
    LM_SIZE:
      begin
        if not (tsWindowCreating in Tree.TreeStates) then
          if (hoAutoResize in FOptions) and not (hsAutoSizing in FStates) then
          begin
            FColumns.AdjustAutoSize(InvalidColumn);
            Invalidate(nil);
          end
          else
            if not (hsScaling in FStates) then
            begin
              RescaleHeader;
              Invalidate(nil);
            end;
      end;
    CM_PARENTFONTCHANGED:
      if FParentFont then
        FFont.Assign(FOwner.Font);
    CM_BIDIMODECHANGED:
      for I := 0 to FColumns.Count - 1 do
        if coParentBiDiMode in FColumns[I].FOptions then
          FColumns[I].ParentBiDiModeChanged;
    LM_MBUTTONDOWN:
      begin
        //lclheader: NCMessages are given in screen coordinates unlike the ordinary
        with TLMMButtonDown(Message) do
          P:= Types.Point(XPos, YPos);
          //P := Treeview.ScreenToClient(Point(XPos, YPos));
        //lclheader
        if InHeader(P) then
          Tree.DoHeaderMouseDown(mbMiddle, GetShiftState, P.X, P.Y { + Integer(FHeight)});
      end;
    LM_MBUTTONUP:
      begin
        with TLMMButtonUp(Message) do
          P:= Types.Point(XPos, YPos);
          //P := FOwner.ScreenToClient(Point(XPos, YPos));
        if InHeader(P) then
        begin
          FColumns.HandleClick(P, mbMiddle, True, False);
          //lclheader
          Tree.DoHeaderMouseUp(mbMiddle, GetShiftState, P.X, P.Y { + Integer(FHeight)});
          FColumns.FDownIndex := NoColumn;
          FColumns.FCheckBoxHit := False;
        end;
      end;
    LM_LBUTTONDBLCLK,
    LM_MBUTTONDBLCLK,
    LM_RBUTTONDBLCLK:
      begin
        with TLMLButtonDblClk(Message) do
          P := Types.Point(XPos, YPos);

        IsInHeader := InHeader(P);
        Result := IsInHeader;

        if (hoHeightDblClickResize in FOptions) and InHeaderSplitterArea(P) and (FDefaultHeight > 0) then
        begin
          if DoHeightDblClickResize(P, GetShiftState) and (FDefaultHeight > 0) then
            SetHeight(FMinHeight);
          Result := True;
        end
        else
          if HSplitterHit and (Message.Msg = LM_LBUTTONDBLCLK) and
             (hoDblClickResize in FOptions) and (FColumns.FTrackIndex > NoColumn) then
          begin
            // If the click was on a splitter then resize column to smallest width.
            if DoColumnWidthDblClickResize(FColumns.FTrackIndex, P, GetShiftState) then
              AutoFitColumns(True, smaUseColumnOption, FColumns[FColumns.FTrackIndex].FPosition,
                             FColumns[FColumns.FTrackIndex].FPosition);
            Message.Result := 0;
            Result := True;
          end
          else
            if IsInHeader and (Message.Msg <> LM_LBUTTONDBLCLK) then
            begin
              case Message.Msg of
                LM_MBUTTONDBLCLK:
                  Button := mbMiddle;
                LM_RBUTTONDBLCLK:
                  Button := mbRight;
                else
                  // WM_NCLBUTTONDBLCLK
                  Button := mbLeft;
              end;
              if Button = mbLeft then
                Columns.AdjustDownColumn(P);
              FColumns.HandleClick(P, Button, True, True);
            end;
      end;
    // The "hot" area of the headers horizontal splitter is partly within the client area of the the tree, so we need
    // to handle WM_LBUTTONDOWN here, too.
    LM_LBUTTONDOWN:
      begin

        Application.CancelHint;

        if not (csDesigning in Treeview.ComponentState) then
        begin
          // make sure no auto scrolling is active...
          KillTimer(Treeview.Handle, ScrollTimer);
          Tree.DoStateChange([], [tsScrollPending, tsScrolling]);
          // ... pending editing is cancelled (actual editing remains active)
          KillTimer(Treeview.Handle, EditTimer);
          Tree.DoStateChange([], [tsEditPending]);
        end;

        with TLMLButtonDown(Message) do
        begin
          // want the drag start point in screen coordinates
          P := Types.Point(XPos, YPos);
          FDragStart := Treeview.ClientToScreen(P);
          //FDragStart := Types.Point(XPos, YPos);
          //P := Treeview.ScreenToClient(FDragStart);
        end;

        IsInHeader := InHeader(P);
        // in design-time header columns are always resizable
        if (csDesigning in Treeview.ComponentState) then
          IsVSplitterHit := InHeaderSplitterArea(P)
        else
          IsVSplitterHit := InHeaderSplitterArea(P) and CanSplitterResize(P);
        IsHSplitterHit := HSplitterHit;

        if IsVSplitterHit or IsHSplitterHit then
        begin
          FTrackStart := P;
          FColumns.FHoverIndex := NoColumn;
          if IsVSplitterHit then
          begin
            if not (csDesigning in Treeview.ComponentState) then
              DoBeforeHeightTracking(GetShiftState);
            Include(FStates, hsHeightTrackPending);
          end
          else
          begin
            if not (csDesigning in Treeview.ComponentState) then
              DoBeforeColumnWidthTracking(FColumns.FTrackIndex, GetShiftState);
            Include(FStates, hsColumnWidthTrackPending);
          end;

          SetCapture(Treeview.Handle);
          Result := True;
          Message.Result := 0;
        end
        else
          if IsInHeader then
          begin
            HitIndex := Columns.AdjustDownColumn(P);
            // in design-time header columns are always draggable
            if ((csDesigning in Treeview.ComponentState) and (HitIndex > NoColumn)) or
               ((hoDrag in FOptions) and (HitIndex > NoColumn) and (coDraggable in FColumns[HitIndex].FOptions)) then
            begin
              // Show potential drag operation.
              // Disabled columns do not start a drag operation because they can't be clicked.
              Include(FStates, hsDragPending);
              SetCapture(Treeview.Handle);
              Message.Result := 0;
            end;
            Result := True;
          end;

        // This is a good opportunity to notify the application.
        //lclheader
        if not (csDesigning in Treeview.ComponentState) and IsInHeader then
          Tree.DoHeaderMouseDown(mbLeft, GetShiftState, P.X, P.Y { + Integer(FHeight)});
        end;
    LM_RBUTTONDOWN:
      begin
        with TLMRButtonDown(Message) do
          P:=Types.Point(XPos,YPos);
          //P := FOwner.ScreenToClient(Point(XPos, YPos));
        //lclheader
        if InHeader(P) then
          Tree.DoHeaderMouseDown(mbRight, GetShiftState, P.X, P.Y { + Integer(FHeight)});
      end;
    LM_RBUTTONUP:
      if not (csDesigning in FOwner.ComponentState) then
        with TLMRButtonUp(Message) do
        begin
          Application.CancelHint;

          P := Types.Point(XPos,YPos);
          //P := FOwner.ScreenToClient(Point(XPos, YPos));
          if InHeader(P) then
          begin
            FColumns.HandleClick(P, mbRight, True, False);
            //lclheader
            Tree.DoHeaderMouseUp(mbRight, GetShiftState, P.X, P.Y { + Integer(FHeight)});
            FColumns.FDownIndex := NoColumn;
            FColumns.FTrackIndex := NoColumn;
            FColumns.FCheckBoxHit := False;

            Menu := FPopupMenu;
            //lclheader
            if not Assigned(Menu) then
              Menu := DoGetPopupMenu(FColumns.ColumnFromPosition(Types.Point(P.X, P.Y { + Integer(FHeight)})), P);

            // Trigger header popup if there's one.
            if Assigned(Menu) then
            begin
              KillTimer(Treeview.Handle, ScrollTimer);
              FColumns.FHoverIndex := NoColumn;
              Tree.DoStateChange([], [tsScrollPending, tsScrolling]);
              Menu.PopupComponent := Treeview;
              P := Treeview.ClientToScreen(Types.Point(XPos, YPos));
              Menu.Popup(P.X, P.Y);
              HandleMessage := True;
              Message.Result := 1;
            end;
          end;
        end;
    // When the tree window has an active mouse capture then we only get "client-area" messages.
    LM_LBUTTONUP:
      begin
        Application.CancelHint;

        if FStates <> [] then
        begin
          ReleaseCapture;
          //lcl
          if hsColumnWidthTracking in FStates then
          begin
            if not InHeader(SmallPointToPoint(TLMLButtonUp(Message).Pos)) then
              TreeView.Cursor := crDefault;
          end;
          if hsDragging in FStates then
          begin
            // successfull dragging moves columns
            with TLMLButtonUp(Message) do
              P := Treeview.ClientToScreen(Types.Point(XPos, YPos));
            GetWindowRect(Treeview.Handle, R);
            {$ifdef DEBUG_VTV}Logger.Send([lcDrag],'Header - EndDrag / R',R);{$endif}
            with FColumns do
            begin
              {$ifdef DEBUG_VTV}Logger.Send([lcDrag],'Header - EndDrag / FDropTarget: %d FDragIndex: %d FDragIndexPosition: %d',
                [FDropTarget, FDragIndex, FColumns[FDragIndex].Position]);{$endif}
              {$ifdef DEBUG_VTV}Logger.Send([lcDrag],'Header - EndDrag / FDropBefore', FColumns.FDropBefore);{$endif}
              FDragImage.EndDrag;
              if (FDropTarget > -1) and (FDropTarget <> FDragIndex) and PtInRect(R, P) then
              begin
                {$ifdef DEBUG_VTV}Logger.Send([lcDrag],'Header - EndDrag / FDropTargetPosition', FColumns[FDropTarget].Position);{$endif}
                OldPosition := FColumns[FDragIndex].Position;
                if FColumns.FDropBefore then
                begin
                  if FColumns[FDragIndex].Position < FColumns[FDropTarget].Position then
                    FColumns[FDragIndex].Position := Max(0, FColumns[FDropTarget].Position - 1)
                  else
                    FColumns[FDragIndex].Position := FColumns[FDropTarget].Position;
                end
                else
                begin
                  if FColumns[FDragIndex].Position < FColumns[FDropTarget].Position then
                    FColumns[FDragIndex].Position := FColumns[FDropTarget].Position
                  else
                    FColumns[FDragIndex].Position := FColumns[FDropTarget].Position + 1;
                end;
                Tree.DoHeaderDragged(FDragIndex, OldPosition);
              end
              else
                Tree.DoHeaderDraggedOut(FDragIndex, P);
              FDropTarget := NoColumn;
            end;
            Invalidate(nil);
          end;
          Result := True;
          Message.Result := 0;
        end;

        case Message.Msg of
          LM_LBUTTONUP:
            with TLMLButtonUp(Message) do
            begin
              if FColumns.FDownIndex > NoColumn then
                FColumns.HandleClick(Types.Point(XPos, YPos), mbLeft, False, False);
              if FStates <> [] then
                Tree.DoHeaderMouseUp(mbLeft, KeysToShiftState(Keys), XPos, YPos);
            end;
          //todo: there's a difference here
          {
          LM_NCLBUTTONUP:
            with TLMLButtonUp(Message) do
            begin
              P := FOwner.ScreenToClient(Types.Point(XPos, YPos));
              FColumns.HandleClick(P, mbLeft, False, False);
              Tree.DoHeaderMouseUp(mbLeft, GetShiftState, P.X, P.Y + Integer(FHeight));
            end;
          }
        end;

        if FColumns.FTrackIndex > NoColumn then
        begin
          if hsColumnWidthTracking in FStates then
            DoAfterColumnWidthTracking(FColumns.FTrackIndex);
          Invalidate(Columns[FColumns.FTrackIndex]);
          FColumns.FTrackIndex := NoColumn;
        end;
        if FColumns.FDownIndex > NoColumn then
        begin
          Invalidate(Columns[FColumns.FDownIndex]);
          FColumns.FDownIndex := NoColumn;
        end;
        if hsHeightTracking in FStates then
          DoAfterHeightTracking;

        FStates := FStates - [hsDragging, hsDragPending,
                              hsColumnWidthTracking, hsColumnWidthTrackPending,
                              hsHeightTracking, hsHeightTrackPending];
      end;
    // hovering, mouse leave detection
    CM_MOUSELEAVE:
      with FColumns do
      begin
        if FHoverIndex > NoColumn then
          Invalidate(Items[FHoverIndex]);
        FHoverIndex := NoColumn;
        FClickIndex := NoColumn;
        FDownIndex := NoColumn;
      end;
    //todo: see the difference to below
    LM_MOUSEMOVE:
      with TLMMouseMove(Message), FColumns do
      begin
        //lcl
        HandleMessage := HandleHeaderMouseMove(TLMMouseMove(Message));

        P := Types.Point(XPos,YPos);
        //P := Treeview.ScreenToClient(Point(XPos, YPos));
        IsInHeader := InHeader(P);
        if IsInHeader then
        begin
          Tree.DoHeaderMouseMove(GetShiftState, P.X, P.Y);
          if ((AdjustHoverColumn(P)) or ((FDownIndex > NoColumn) and (FHoverIndex <> FDownIndex))) then
          begin
            Invalidate(nil);
            // todo: under lcl, the hint is show even if HintMouseMessage is not implemented
            // Is it necessary here?
            // use Delphi's internal hint handling for header hints too
            if hoShowHint in FOptions then
            begin
              // client coordinates!
              XPos := P.X;
              YPos := P.Y;
              Application.HintMouseMessage(Treeview, Message);
            end;
          end;
        end
        else
        begin
          if FHoverIndex > NoColumn then
            Invalidate(Items[FHoverIndex]);
          FHoverIndex := NoColumn;
          FClickIndex := NoColumn;
          FDownIndex := NoColumn;
          FCheckBoxHit := False;
        end;
        //Adjust Cursor
        // Feature: design-time header
        if (FStates = []) then
        begin
          //todo: see a way to store the user defined cursor.
          IsHSplitterHit := HSplitterHit;
          // in design-time header columns are always resizable
          if (csDesigning in Treeview.ComponentState) then
            IsVSplitterHit := InHeaderSplitterArea(P)
          else
            IsVSplitterHit := InHeaderSplitterArea(P) and FHeader.CanSplitterResize(P);

          if IsVSplitterHit or IsHSplitterHit then
          begin
            NewCursor := crDefault;
            if IsVSplitterHit and (hoHeightResize in FOptions) then
              NewCursor := crVertSplit
            else if IsHSplitterHit then
              NewCursor := crHeaderSplit;

            Tree.DoGetHeaderCursor(NewCursor);
            if NewCursor <> crDefault then
            begin
              Treeview.Cursor := NewCursor;
              HandleMessage := True;
              Message.Result := 1;
            end;
          end;
        end
        else
        begin
          Message.Result := 1;
          HandleMessage := True;
        end;
      end;
    LM_KEYDOWN,
    LM_KILLFOCUS:
      if (Message.Msg = LM_KILLFOCUS) or
         (TLMKeyDown(Message).CharCode = VK_ESCAPE) then
      begin
        if hsDragging in FStates then
        begin
          ReleaseCapture;
          FDragImage.EndDrag;
          Exclude(FStates, hsDragging);
          FColumns.FDropTarget := NoColumn;
          Invalidate(nil);
          Result := True;
          Message.Result := 0;
        end
        else
        begin
          if [hsColumnWidthTracking, hsHeightTracking] * FStates <> [] then
          begin
            ReleaseCapture;
            if hsColumnWidthTracking in FStates then
              DoAfterColumnWidthTracking(FColumns.FTrackIndex);
            if hsHeightTracking in FStates then
              DoAfterHeightTracking;
            Result := True;
            Message.Result := 0;
          end;

          FStates := FStates - [hsColumnWidthTracking, hsColumnWidthTrackPending,
                                hsHeightTracking, hsHeightTrackPending];
        end;
      end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.ImageListChange(Sender: TObject);

begin
  if not (csDestroying in Treeview.ComponentState) then
    Invalidate(nil);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.PrepareDrag(P, Start: TPoint);

// Initializes dragging of the header, P is the current mouse postion and Start the initial mouse position.

var
  Image: Graphics.TBitmap;
  ImagePos: TPoint;
  DragColumn: TVirtualTreeColumn;
  RTLOffset: Integer;

begin
  // Determine initial position of drag image (screen coordinates).
  FColumns.FDropTarget := NoColumn;
  Start := Treeview.ScreenToClient(Start);
  //lclheader
  //Inc(Start.Y, FHeight);
  FColumns.FDragIndex := FColumns.ColumnFromPosition(Start);
  DragColumn := FColumns[FColumns.FDragIndex];

  Image := Graphics.TBitmap.Create;
  with Image do
  try
    PixelFormat := pf32Bit;
    Width := DragColumn.Width;
    Height := FHeight;

    // Erase the entire image with the color key value, for the case not everything
    // in the image is covered by the header image.
    Canvas.Brush.Color := clBtnFace;
    Canvas.FillRect(Types.Rect(0, 0, Width, Height));

    if TreeView.UseRightToLeftAlignment then
      RTLOffset := Tree.ComputeRTLOffset
    else
      RTLOffset := 0;
    with DragColumn do
      FColumns.PaintHeader(Canvas, Types.Rect(FLeft, 0, FLeft + Width, Height), Types.Point(-RTLOffset, 0), RTLOffset);

    if Treeview.UseRightToLeftAlignment then
      ImagePos := Treeview.ClientToScreen(Types.Point(DragColumn.Left + Tree.ComputeRTLOffset(True), 0))
    else
      ImagePos := Treeview.ClientToScreen(Types.Point(DragColumn.Left, 0));
    //lclheader
    // Column rectangles are given in local window coordinates not client coordinates.
    // The above statement is not valid under LCL
    //Dec(ImagePos.Y, FHeight);

    if hoRestrictDrag in FOptions then
      FDragImage.MoveRestriction := dmrHorizontalOnly
    else
      FDragImage.MoveRestriction := dmrNone;
    FDragImage.PrepareDrag(Image, ImagePos, P, nil);
    FDragImage.ShowDragImage;
  finally
    Image.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.RecalculateHeader;

// Initiate a recalculation of the non-client area of the owner tree.

begin
  if Treeview.HandleAllocated then
  begin
    Tree.UpdateHeaderRect;
    //lclheader
    //not necessary since header is draw inside client area
    //SetWindowPos(Treeview.Handle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOACTIVATE or SWP_NOOWNERZORDER or
    //  SWP_NOSENDCHANGING or SWP_NOSIZE or SWP_NOZORDER);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.RescaleHeader;

// Rescale the fixed elements (fixed columns, header itself) to FixedAreaConstraints.

var
  FixedWidth,
  MaxFixedWidth,
  MinFixedWidth: Integer;

  //--------------- local function --------------------------------------------

  procedure ComputeConstraints;

  var
    I: TColumnIndex;

  begin
    with FColumns do
    begin
      I := GetFirstVisibleColumn;
      while I > NoColumn do
      begin
        if (coFixed in FColumns[I].Options) and (FColumns[I].Width < FColumns[I].MinWidth) then
          TVirtualTreeColumnCracker(FColumns[I]).InternalSetWidth(FColumns[I].MinWidth); //SetWidth has side effects and this bypasses them
        I := GetNextVisibleColumn(I);
      end;
      FixedWidth := GetVisibleFixedWidth;
    end;

    with FFixedAreaConstraints do
    begin
      MinFixedWidth := (TreeView.ClientWidth * FMinWidthPercent) div 100;
      MaxFixedWidth := (TreeView.ClientWidth * FMaxWidthPercent) div 100;
    end;
  end;

  //----------- end local function --------------------------------------------

begin
  if ([csLoading, csReading, csWriting, csDestroying] * Treeview.ComponentState = []) and not
     (hsLoading in FStates) and Treeview.HandleAllocated then
  begin
    Include(FStates, hsScaling);

    SetHeight(FHeight);
    RecalculateHeader;

    with FFixedAreaConstraints do
      if (FMinHeightPercent > 0) or (FMaxHeightPercent > 0) then
      begin
        ComputeConstraints;

        with FColumns do
          if (FMaxWidthPercent > 0) and (FixedWidth > MaxFixedWidth) then
            ResizeColumns(MaxFixedWidth - FixedWidth, 0, Count - 1, [coVisible, coFixed])
          else
            if (FMinWidthPercent > 0) and (FixedWidth < MinFixedWidth) then
              ResizeColumns(MinFixedWidth - FixedWidth, 0, Count - 1, [coVisible, coFixed]);

        FColumns.UpdatePositions;
      end;

    Exclude(FStates, hsScaling);
    Exclude(FStates, hsNeedScaling);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.UpdateMainColumn;

// Called once the load process of the owner tree is done.

begin
  if FMainColumn < 0 then
    FMainColumn := 0;
  if FMainColumn > FColumns.Count - 1 then
    FMainColumn := FColumns.Count - 1;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.UpdateSpringColumns;

var
  I: TColumnIndex;
  SpringCount: Integer;
  Sign: Integer;
  ChangeBy: Single;
  Difference: Single;
  NewAccumulator: Single;

begin
  with Tree do
    ChangeBy := HeaderRect.Right - HeaderRect.Left - FLastWidth;
  if (hoAutoSpring in FOptions) and (FLastWidth <> 0) and (ChangeBy <> 0) then
  begin
    // Stay positive if downsizing the control.
    if ChangeBy < 0 then
      Sign := -1
    else
      Sign := 1;
    ChangeBy := Abs(ChangeBy);
    // Count how many columns have spring enabled.
    SpringCount := 0;
    for I := 0 to FColumns.Count-1 do
      if [coVisible, coAutoSpring] * FColumns[I].FOptions = [coVisible, coAutoSpring] then
        Inc(SpringCount);
    if SpringCount > 0 then
    begin
      // Calculate the size to add/sub to each columns.
      Difference := ChangeBy / SpringCount;
      // Adjust the column's size accumulators and resize if the result is >= 1.
      for I := 0 to FColumns.Count - 1 do
        if [coVisible, coAutoSpring] * FColumns[I].FOptions = [coVisible, coAutoSpring] then
        begin
          // Sum up rest changes from previous runs and the amount from this one and store it in the
          // column. If there is at least one pixel difference then do a resize and reset the accumulator.
          NewAccumulator := FColumns[I].FSpringRest + Difference;
          // Set new width if at least one pixel size difference is reached.
          if NewAccumulator >= 1 then
            FColumns[I].SetWidth(FColumns[I].FWidth + (Trunc(NewAccumulator) * Sign));
          FColumns[I].FSpringRest := Frac(NewAccumulator);

          // Keep track of the size count.
          ChangeBy := ChangeBy - Difference;
          // Exit loop if resize count drops below freezing point.
          if ChangeBy < 0 then
            Break;
        end;
    end;
  end;
  with Tree do
    FLastWidth := HeaderRect.Right - HeaderRect.Left;
end;

procedure TVTHeader.InternalSetMainColumn(const Index: TColumnIndex);
begin
  FMainColumn := index;
end;

procedure TVTHeader.InternalSetAutoSizeIndex(const Index: TColumnIndex);
begin
  FAutoSizeIndex := index;
end;

procedure TVTHeader.InternalSetSortColumn(const Index: TColumnIndex);
begin
  FSortColumn := index;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.AllowFocus(ColumnIndex: TColumnIndex): Boolean;
begin
  Result := False;
  if not FColumns.IsValidColumn(ColumnIndex) then
    Exit; // Just in case.

  Result := (coAllowFocus in FColumns[ColumnIndex].Options);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.Assign(Source: TPersistent);

begin
  if Source is TVTHeader then
  begin
    AutoSizeIndex := TVTHeader(Source).AutoSizeIndex;
    Background := TVTHeader(Source).Background;
    Columns := TVTHeader(Source).Columns;
    Font := TVTHeader(Source).Font;
    FixedAreaConstraints.Assign(TVTHeader(Source).FixedAreaConstraints);
    Height := TVTHeader(Source).Height;
    Images := TVTHeader(Source).Images;
    MainColumn := TVTHeader(Source).MainColumn;
    Options := TVTHeader(Source).Options;
    ParentFont := TVTHeader(Source).ParentFont;
    PopupMenu := TVTHeader(Source).PopupMenu;
    SortColumn := TVTHeader(Source).SortColumn;
    SortDirection := TVTHeader(Source).SortDirection;
    Style := TVTHeader(Source).Style;
    {$IF LCL_FullVersion >= 2000000}
    ImagesWidth := TVTHeader(Source).ImagesWidth;
    {$IFEND}

    RescaleHeader;
  end
  else
    inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.AutoFitColumns(Animated: Boolean = True; SmartAutoFitType: TSmartAutoFitType = smaUseColumnOption;
  RangeStartCol: Integer = NoColumn; RangeEndCol: Integer = NoColumn);

  //--------------- local functions -------------------------------------------

  function GetUseSmartColumnWidth(ColumnIndex: TColumnIndex): Boolean;

  begin
    Result := False;
    case SmartAutoFitType of
      smaAllColumns:
        Result := True;
      smaNoColumn:
        Result := False;
      smaUseColumnOption:
        Result := coSmartResize in FColumns.Items[ColumnIndex].FOptions;
    end;
  end;

  //----------------------------------------------------------------------------

  procedure DoAutoFitColumn(Column: TColumnIndex);

  begin
    with FColumns do
      if ([coResizable, coVisible] * Items[FPositionToIndex[Column]].FOptions = [coResizable, coVisible]) and
            DoBeforeAutoFitColumn(FPositionToIndex[Column], SmartAutoFitType) and not Tree.OperationCanceled then
      begin
        if Animated then
          AnimatedResize(FPositionToIndex[Column], Tree.GetMaxColumnWidth(FPositionToIndex[Column],
            GetUseSmartColumnWidth(FPositionToIndex[Column])))
        else
          FColumns[FPositionToIndex[Column]].Width := Tree.GetMaxColumnWidth(FPositionToIndex[Column],
            GetUseSmartColumnWidth(FPositionToIndex[Column]));

        DoAfterAutoFitColumn(FPositionToIndex[Column]);
      end;
  end;

  //--------------- end local functions ----------------------------------------

var
  I: Integer;
  StartCol,
  EndCol: Integer;

begin
  StartCol := Max(NoColumn + 1, RangeStartCol);

  if RangeEndCol <= NoColumn then
    EndCol := FColumns.Count - 1
  else
    EndCol := Min(RangeEndCol, FColumns.Count - 1);

  if StartCol > EndCol then
    Exit; // nothing to do

  Tree.StartOperation(okAutoFitColumns);
  try
    if Assigned(Tree.OnBeforeAutoFitColumns) then
      Tree.OnBeforeAutoFitColumns(Self, SmartAutoFitType);

    for I := StartCol to EndCol do
      DoAutoFitColumn(I);

    if Assigned(Tree.OnAfterAutoFitColumns) then
      Tree.OnAfterAutoFitColumns(Self);

  finally
    Tree.EndOperation(okAutoFitColumns);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

{$IF LCL_FullVersion >= 2010000}
procedure TVTHeader.FixDesignFontsPPI(const ADesignTimePPI: Integer);
begin
  Tree.DoFixDesignFontPPI(Font, ADesignTimePPI);
end;
{$IFEND}

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.InHeader(const P: TPoint): Boolean;

// Determines whether the given point (client coordinates!) is within the header rectangle (non-client coordinates).

begin
  //lclheader
  //todo: remove this function and use PtInRect directly ??
  Result := PtInRect(Tree.HeaderRect, P);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.InHeaderSplitterArea(P: TPoint): Boolean;

// Determines whether the given point (client coordinates!) hits the horizontal splitter area of the header.

var
  R: TRect;

begin
  Result := (hoVisible in FOptions);
  if Result then
  begin
    R := Tree.HeaderRect;
    R.Top := R.Bottom - 2;
    Inc(R.Bottom, 2);
    Result := PtInRect(R, P);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.Invalidate(Column: TVirtualTreeColumn; ExpandToBorder: Boolean = False);

// Because the header is in the non-client area of the tree it needs some special handling in order to initiate its
// repainting.
// If ExpandToBorder is True then not only the given column but everything or (depending on hoFullRepaintOnResize) just
// everything to its right (or left, in RTL mode) will be invalidated (useful for resizing). This makes only sense when
// a column is given.

var
  R: TRect;

begin
  if (hoVisible in FOptions) and Treeview.HandleAllocated then
    with Tree do
    begin
      if Column = nil then
        R := HeaderRect
      else
      begin
        R := Column.GetRect;
        if not (coFixed in Column.Options) then
          OffsetRect(R, -EffectiveOffsetX, 0);
        if UseRightToLeftAlignment then
          OffsetRect(R, ComputeRTLOffset, 0);
        if ExpandToBorder then
        begin
          if (hoFullRepaintOnResize in Header.FOptions) then
          begin
            R.Left := HeaderRect.Left;
            R.Right := HeaderRect.Right;
          end
          else
          begin
            if UseRightToLeftAlignment then
              R.Left := HeaderRect.Left
            else
              R.Right := HeaderRect.Right;
          end;
        end;
      end;
    //lclheader
    RedrawWindow(Handle, @R, 0, RDW_FRAME or RDW_INVALIDATE or RDW_VALIDATE or RDW_NOINTERNALPAINT or
      RDW_NOERASE or RDW_NOCHILDREN);

    {
    // Current position of the owner in screen coordinates.
    GetWindowRect(Handle, RW);

    // Consider the header within this rectangle.
    OffsetRect(R, RW.Left, RW.Top);

    // Expressed in client coordinates (because RedrawWindow wants them so, they will actually become negative).
    MapWindowPoints(0, Handle, R, 2);
    RedrawWindow(Handle, @R, 0, RDW_FRAME or RDW_INVALIDATE or RDW_VALIDATE or RDW_NOINTERNALPAINT or
      RDW_NOERASE or RDW_NOCHILDREN);
    }
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.LoadFromStream(const Stream: TStream);

// restore the state of the header from the given stream

var
  Dummy,
  Version: Integer;
  S: AnsiString;
  OldOptions: TVTHeaderOptions;

begin
  Include(FStates, hsLoading);
  with Stream do
  try
    // Switch off all options which could influence loading the columns (they will be later set again).
    OldOptions := FOptions;
    FOptions := [];

    // Determine whether the stream contains data without a version number.
    ReadBuffer(Dummy, SizeOf(Dummy));
    if Dummy > -1 then
    begin
      // Seek back to undo the read operation if this is an old stream format.
      Seek(-SizeOf(Dummy), soFromCurrent);
      Version := -1;
    end
    else // Read version number if this is a "versionized" format.
      ReadBuffer(Version, SizeOf(Version));
    Columns.LoadFromStream(Stream, Version);

    ReadBuffer(Dummy, SizeOf(Dummy));
    AutoSizeIndex := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    Background := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    Height := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    FOptions := OldOptions;
    Options := TVTHeaderOptions(Dummy);
    // PopupMenu is neither saved nor restored
    ReadBuffer(Dummy, SizeOf(Dummy));
    Style := TVTHeaderStyle(Dummy);
    // TFont has no own save routine so we do it manually
    with Font do
    begin
      ReadBuffer(Dummy, SizeOf(Dummy));
      Color := Dummy;
      ReadBuffer(Dummy, SizeOf(Dummy));
      Height := Dummy;
      ReadBuffer(Dummy, SizeOf(Dummy));
      SetLength(S, Dummy);
      ReadBuffer(PAnsiChar(S)^, Dummy);
      Name := S;
      ReadBuffer(Dummy, SizeOf(Dummy));
      Pitch := TFontPitch(Dummy);
      ReadBuffer(Dummy, SizeOf(Dummy));
      Style := TFontStyles(LongWord(Dummy));
    end;
    // LCL port started with header stream version 6 so no need to do the check here
    // Read data introduced by stream version 1+.
    ReadBuffer(Dummy, SizeOf(Dummy));
    MainColumn := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    SortColumn := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    SortDirection := TSortDirection(Byte(Dummy));

    // Read data introduced by stream version 5+.
    ReadBuffer(Dummy, SizeOf(Dummy));
    ParentFont := Boolean(Dummy);
    ReadBuffer(Dummy, SizeOf(Dummy));
    FMaxHeight := Integer(Dummy);
    ReadBuffer(Dummy, SizeOf(Dummy));
    FMinHeight := Integer(Dummy);
    ReadBuffer(Dummy, SizeOf(Dummy));
    FDefaultHeight := Integer(Dummy);
    with FFixedAreaConstraints do
    begin
      ReadBuffer(Dummy, SizeOf(Dummy));
      FMaxHeightPercent := TVTConstraintPercent(Dummy);
        ReadBuffer(Dummy, SizeOf(Dummy));
      FMaxWidthPercent := TVTConstraintPercent(Dummy);
      ReadBuffer(Dummy, SizeOf(Dummy));
      FMinHeightPercent := TVTConstraintPercent(Dummy);
        ReadBuffer(Dummy, SizeOf(Dummy));
      FMinWidthPercent := TVTConstraintPercent(Dummy);
    end;
  finally
    Exclude(FStates, hsLoading);
    Tree.DoColumnResize(NoColumn);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTHeader.ResizeColumns(ChangeBy: Integer; RangeStartCol: TColumnIndex; RangeEndCol: TColumnIndex;
  Options: TVTColumnOptions = [coVisible]): Integer;

// Distribute the given width change to a range of columns. A 'fair' way is used to distribute ChangeBy to the columns,
// while ensuring that everything that can be distributed will be distributed.

var
  Start,
  I: TColumnIndex;
  ColCount,
  ToGo,
  Sign,
  Rest,
  MaxDelta,
  Difference: Integer;
  Constraints,
  Widths: array of Integer;
  BonusPixel: Boolean;

  //--------------- local functions -------------------------------------------

  function IsResizable (Column: TColumnIndex): Boolean;

  begin
    if BonusPixel then
      Result := Widths[Column - RangeStartCol] < Constraints[Column - RangeStartCol]
    else
      Result := Widths[Column - RangeStartCol] > Constraints[Column - RangeStartCol];
  end;

  //---------------------------------------------------------------------------

  procedure IncDelta(Column: TColumnIndex);

  begin
    if BonusPixel then
      Inc(MaxDelta, FColumns[Column].MaxWidth - Widths[Column - RangeStartCol])
    else
      Inc(MaxDelta, Widths[Column - RangeStartCol] - Constraints[Column - RangeStartCol]);
  end;

  //---------------------------------------------------------------------------

  function ChangeWidth(Column: TColumnIndex; Delta: Integer): Integer;

  begin
    if Delta > 0 then
      Delta := Min(Delta, Constraints[Column - RangeStartCol] - Widths[Column - RangeStartCol])
    else
      Delta := Max(Delta, Constraints[Column - RangeStartCol] - Widths[Column - RangeStartCol]);

    Inc(Widths[Column - RangeStartCol], Delta);
    Dec(ToGo, Abs(Delta));
    Result := Abs(Delta);
  end;

  //---------------------------------------------------------------------------

  function ReduceConstraints: Boolean;

  var
    MaxWidth,
    MaxReserveCol,
    Column: TColumnIndex;

  begin
    Result := True;
    if not (hsScaling in FStates) or BonusPixel then
      Exit;

    MaxWidth := 0;
    MaxReserveCol := NoColumn;
    for Column := RangeStartCol to RangeEndCol do
      if (Options * FColumns[Column].FOptions = Options) and
         (FColumns[Column].FWidth > MaxWidth) then
      begin
        MaxWidth := Widths[Column - RangeStartCol];
        MaxReserveCol := Column;
      end;

    if (MaxReserveCol <= NoColumn) or (Constraints[MaxReserveCol - RangeStartCol] <= 10) then
      Result := False
    else
      Dec(Constraints[MaxReserveCol - RangeStartCol],
          Constraints[MaxReserveCol - RangeStartCol] div 10);
  end;

  //----------- end local functions -------------------------------------------

begin
  Result := 0;
  if ChangeBy <> 0 then
  begin
    // Do some initialization here
    BonusPixel := ChangeBy > 0;
    Sign := IfThen(BonusPixel, 1, -1);
    Start := IfThen(BonusPixel, RangeStartCol, RangeEndCol);
    ToGo := Abs(ChangeBy);
    SetLength(Widths, RangeEndCol - RangeStartCol + 1);
    SetLength(Constraints, RangeEndCol - RangeStartCol + 1);
    for I := RangeStartCol to RangeEndCol do
    begin
      Widths[I - RangeStartCol] := FColumns[I].FWidth;
      Constraints[I - RangeStartCol] := IfThen(BonusPixel, FColumns[I].MaxWidth, FColumns[I].MinWidth);
    end;

    repeat
      repeat
        MaxDelta := 0;
        ColCount := 0;
        for I := RangeStartCol to RangeEndCol do
          if (Options * FColumns[I].FOptions = Options) and IsResizable(I) then
          begin
            Inc(ColCount);
            IncDelta(I);
          end;
        if MaxDelta < Abs(ChangeBy) then
          if not ReduceConstraints then
            Break;
      until (MaxDelta >= Abs(ChangeBy)) or not (hsScaling in FStates);

      if ColCount = 0 then
        Break;

      ToGo := Min(ToGo, MaxDelta);
      Difference := ToGo div ColCount;
      Rest := ToGo mod ColCount;

      if Difference > 0 then
        for I := RangeStartCol to RangeEndCol do
          if (Options * FColumns[I].FOptions = Options) and IsResizable(I) then
            ChangeWidth(I, Difference * Sign);

      // Now distribute Rest.
      I := Start;
      while Rest > 0 do
      begin
        if (Options * FColumns[I].FOptions = Options) and IsResizable(I) then
          if FColumns[I].FBonusPixel <> BonusPixel then
          begin
            Dec(Rest, ChangeWidth(I, Sign));
            FColumns[I].FBonusPixel := BonusPixel;
          end;
        Inc(I, Sign);
        if (BonusPixel and (I > RangeEndCol)) or (not BonusPixel and (I < RangeStartCol)) then
        begin
          for I := RangeStartCol to RangeEndCol do
            if Options * FColumns[I].FOptions = Options then
              FColumns[I].FBonusPixel := not FColumns[I].FBonusPixel;
          I := Start;
        end;
      end;
    until ToGo <= 0;

    // Now set the computed widths. We also compute the result here.
    Include(FStates, hsResizing);
    for I := RangeStartCol to RangeEndCol do
      if (Options * FColumns[I].FOptions = Options) then
      begin
        Inc(Result, Widths[I - RangeStartCol] - FColumns[I].FWidth);
        FColumns[I].SetWidth(Widths[I - RangeStartCol]);
      end;
    Exclude(FStates, hsResizing);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.RestoreColumns;

// Restores all columns to their width which they had before they have been auto fitted.

var
  I: TColumnIndex;

begin
  with FColumns do
    for I := Count - 1 downto 0 do
      if [coResizable, coVisible] * Items[FPositionToIndex[I]].FOptions = [coResizable, coVisible] then
        Items[I].RestoreLastWidth;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTHeader.SaveToStream(const Stream: TStream);

// Saves the complete state of the header into the provided stream.

var
  Dummy: Integer;
  Tmp: AnsiString;

begin
  with Stream do
  begin
    // In previous version of VT was no header stream version defined.
    // For feature enhancements it is necessary, however, to know which stream
    // format we are trying to load.
    // In order to distict from non-version streams an indicator is inserted.
    Dummy := -1;
    WriteBuffer(Dummy, SizeOf(Dummy));
    // Write current stream version number, nothing more is required at the time being.
    Dummy := VTHeaderStreamVersion;
    WriteBuffer(Dummy, SizeOf(Dummy));

    // Save columns in case they depend on certain options (like auto size).
    Columns.SaveToStream(Stream);

    Dummy := FAutoSizeIndex;
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := FBackground;
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := FHeight;
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := Integer(FOptions);
    WriteBuffer(Dummy, SizeOf(Dummy));
    // PopupMenu is neither saved nor restored
    Dummy := Ord(FStyle);
    WriteBuffer(Dummy, SizeOf(Dummy));
    // TFont has no own save routine so we do it manually
    with Font do
    begin
      Dummy := Color;
      WriteBuffer(Dummy, SizeOf(Dummy));

      // Need only to write one: size or height, I decided to write height.
      Dummy := Height;
      WriteBuffer(Dummy, SizeOf(Dummy));
      Tmp := Name;
      Dummy := Length(Tmp);
      WriteBuffer(Dummy, SizeOf(Dummy));
      WriteBuffer(PAnsiChar(Tmp)^, Dummy);
      Dummy := Ord(Pitch);
      WriteBuffer(Dummy, SizeOf(Dummy));
      Dummy := Integer(Style);
      WriteBuffer(Dummy, SizeOf(Dummy));
    end;

    // Data introduced by stream version 1.
    Dummy := FMainColumn;
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := FSortColumn;
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := Byte(FSortDirection);
    WriteBuffer(Dummy, SizeOf(Dummy));

    // Data introduced by stream version 5.
    Dummy := Integer(ParentFont);
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := Integer(FMaxHeight);
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := Integer(FMinHeight);
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := Integer(FDefaultHeight);
    WriteBuffer(Dummy, SizeOf(Dummy));
    with FFixedAreaConstraints do
    begin
      Dummy := Integer(FMaxHeightPercent);
      WriteBuffer(Dummy, SizeOf(Dummy));
      Dummy := Integer(FMaxWidthPercent);
      WriteBuffer(Dummy, SizeOf(Dummy));
      Dummy := Integer(FMinHeightPercent);
      WriteBuffer(Dummy, SizeOf(Dummy));
      Dummy := Integer(FMinWidthPercent);
      WriteBuffer(Dummy, SizeOf(Dummy));
    end;
  end;
end;

{ TVTHeaderHelper }

function TVTHeaderHelper.Tree : TBaseVirtualTreeCracker;
begin
  Result := TBaseVirtualTreeCracker(Self.FOwner);
end;

//----------------- TVirtualTreeColumn ---------------------------------------------------------------------------------

constructor TVirtualTreeColumn.Create(Collection: TCollection);

begin
  FMinWidth := 10;
  FMaxWidth := 10000;
  FImageIndex := -1;
  //FText := '';
  FOptions := DefaultColumnOptions;
  FAlignment := taLeftJustify;
  FBiDiMode := bdLeftToRight;
  FColor := clWindow;
  FLayout := blGlyphLeft;
  //FBonusPixel := False;
  FCaptionAlignment := taLeftJustify;
  FCheckType := ctCheckBox;
  FCheckState := csUncheckedNormal;
  //FCheckBox := False;
  //FHasImage := False;
  FDefaultSortDirection := sdAscending;

  inherited Create(Collection);

  {$IF LCL_FullVersion >= 1080000}
  FMargin := Owner.Header.TreeView.Scale96ToFont(DEFAULT_MARGIN);
  FSpacing := Owner.Header.TreeView.Scale96ToFont(DEFAULT_SPACING);
  {$ELSE}
  FMargin := DEFAULT_MARGIN;
  FSpacing := DEFAULT_SPACING;
  {$IFEND}

  FWidth := Owner.FDefaultWidth;
  FLastWidth := Owner.FDefaultWidth;

  //lcl: setting FPosition here will override the Design time value
  //FPosition := Owner.Count - 1;
  // Read parent bidi mode and color values as default values.
  ParentBiDiModeChanged;
  ParentColorChanged;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TVirtualTreeColumn.Destroy;

var
  I: Integer;

  //--------------- local function ---------------------------------------------

  procedure AdjustColumnIndex(var ColumnIndex: TColumnIndex);

  begin
    if Index = ColumnIndex then
      ColumnIndex := NoColumn
    else
      if Index < ColumnIndex then
        Dec(ColumnIndex);
  end;

  //--------------- end local function -----------------------------------------

begin
  // Check if this column is somehow referenced by its collection parent or the header.
  with Owner do
  begin
    // If the columns collection object is currently deleting all columns
    // then we don't need to check the various cached indices individually.
    if not FClearing then
    begin
      Header.Tree.CancelEditNode;
      IndexChanged(Index, -1);

      AdjustColumnIndex(FHoverIndex);
      AdjustColumnIndex(FDownIndex);
      AdjustColumnIndex(FTrackIndex);
      AdjustColumnIndex(FClickIndex);

      with Header do
      begin
        AdjustColumnIndex(FAutoSizeIndex);
        if Index = FMainColumn then
        begin
          // If the current main column is about to be destroyed then we have to find a new main column.
          InternalSetMainColumn(NoColumn); //SetColumn has side effects we want to avoid here.
          for I := 0 to Count - 1 do
            if I <> Index then
            begin
              InternalSetMainColumn(I);
              Break;
            end;
        end;
        AdjustColumnIndex(FSortColumn);
      end;
    end;
  end;

  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.GetCaptionAlignment: TAlignment;

begin
  if coUseCaptionAlignment in FOptions then
    Result := FCaptionAlignment
  else
    Result := FAlignment;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.GetLeft: Integer;

begin
  Result := FLeft;
  if [coVisible, coFixed] * FOptions <> [coVisible, coFixed] then
    Dec(Result, Owner.Header.Tree.EffectiveOffsetX);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.IsBiDiModeStored: Boolean;

begin
  Result := not (coParentBiDiMode in FOptions);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.IsCaptionAlignmentStored: Boolean;

begin
  Result := coUseCaptionAlignment in FOptions;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.IsColorStored: Boolean;

begin
  Result := not (coParentColor in FOptions);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.IsMarginStored: Boolean;
begin
  {$IF LCL_FullVersion >= 1080000}
  Result := FMargin <> Owner.Header.TreeView.Scale96ToFont(DEFAULT_MARGIN);
  {$ELSE}
  Result := FMargin <> DEFAULT_MARGIN;
  {$IFEND}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.IsSpacingStored: Boolean;
begin
  {$IF LCL_FullVersion >= 1080000}
  Result := FSpacing <> Owner.Header.TreeView.Scale96ToFont(DEFAULT_SPACING);
  {$ELSE}
  Result := FSpacing <> DEFAULT_SPACING;
  {$IFEND}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.IsWidthStored: Boolean;
begin
  Result := FWidth <> Owner.DefaultWidth;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetAlignment(const Value: TAlignment);

begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Changed(False);
    // Setting the alignment affects also the tree, hence invalidate it too.
    Owner.Header.TreeView.Invalidate;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetBiDiMode(Value: TBiDiMode);

begin
  if Value <> FBiDiMode then
  begin
    FBiDiMode := Value;
    Exclude(FOptions, coParentBiDiMode);
    Changed(False);
    // Setting the alignment affects also the tree, hence invalidate it too.
    Owner.Header.TreeView.Invalidate;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetCaptionAlignment(const Value: TAlignment);

begin
  if not (coUseCaptionAlignment in FOptions) or (FCaptionAlignment <> Value) then
  begin
    FCaptionAlignment := Value;
    Include(FOptions, coUseCaptionAlignment);
    // Setting the alignment affects also the tree, hence invalidate it too.
    Owner.Header.Invalidate(Self);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetColor(const Value: TColor);

begin
  if FColor <> Value then
  begin
    FColor := Value;
    Exclude(FOptions, coParentColor);
    Changed(False);
    Owner.Header.TreeView.Invalidate;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetCheckBox(Value: Boolean);

begin
  if Value <> FCheckBox then
  begin
    FCheckBox := Value;
    if Value and (csDesigning in Owner.Header.Treeview.ComponentState) then
      Owner.Header.Options := Owner.Header.Options + [hoShowImages];
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetCheckState(Value: TCheckState);

begin
  if Value <> FCheckState then
  begin
    FCheckState := Value;
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetCheckType(Value: TCheckType);

begin
  if Value <> FCheckType then
  begin
    FCheckType := Value;
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetImageIndex(Value: TImageIndex);

begin
  if Value <> FImageIndex then
  begin
    FImageIndex := Value;
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetLayout(Value: TVTHeaderColumnLayout);

begin
  if FLayout <> Value then
  begin
    FLayout := Value;
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetMargin(Value: Integer);

begin
  // Compatibility setting for -1.
  if Value < 0 then
    Value := 4;
  if FMargin <> Value then
  begin
    FMargin := Value;
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetMaxWidth(Value: Integer);

begin
  if Value < FMinWidth then
    Value := FMinWidth;
  FMaxWidth := Value;
  SetWidth(FWidth);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetMinWidth(Value: Integer);

begin
  if Value < 0 then
    Value := 0;
  if Value > FMaxWidth then
    Value := FMaxWidth;
  FMinWidth := Value;
  SetWidth(FWidth);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetOptions(Value: TVTColumnOptions);

var
  ToBeSet,
  ToBeCleared: TVTColumnOptions;
  AVisibleChanged,
  ColorChanged: Boolean;

begin
  if FOptions <> Value then
  begin
    ToBeCleared := FOptions - Value;
    ToBeSet := Value - FOptions;

    FOptions := Value;

    AVisibleChanged := coVisible in (ToBeSet + ToBeCleared);
    ColorChanged := coParentColor in ToBeSet;

    if coParentBidiMode in ToBeSet then
      ParentBiDiModeChanged;
    if ColorChanged then
      ParentColorChanged;

    if coAutoSpring in ToBeSet then
      FSpringRest := 0;

    if ((coFixed in ToBeSet) or (coFixed in ToBeCleared)) and (coVisible in FOptions) then
      Owner.Header.RescaleHeader;

    Changed(False);
    // Need to repaint and adjust the owner tree too.

    //lcl: fpc refuses to compile the original code by no aparent reason.
    //Found: Was confounding TControl.VisibleChanged
    with Owner, Header.Tree do
      if not (csLoading in ComponentState) and (AVisibleChanged or ColorChanged) and (UpdateCount = 0) and
        HandleAllocated then
      begin
        Invalidate;
        if AVisibleChanged then
          UpdateHorizontalScrollBar(False);
      end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetPosition(Value: TColumnPosition);

var
  Temp: TColumnIndex;

begin
  if csLoading in Owner.Header.Treeview.ComponentState then
    // Only cache the position for final fixup when loading from DFM.
    FPosition := Value
  else
  begin
    if Value >= TColumnPosition(Collection.Count) then
      Value := Collection.Count - 1;
    if FPosition <> Value then
    begin
      with Owner do
      begin
        InitializePositionArray;
        Header.Tree.CancelEditNode;
        AdjustPosition(Self, Value);
        Self.Changed(False);

        // Need to repaint.
        with Header do
        begin
          if (UpdateCount = 0) and Treeview.HandleAllocated then
          begin
            Invalidate(Self);
            Treeview.Invalidate;
          end;
        end;
      end;

      // If the moved column is now within the fixed columns then we make it fixed as well. If it's not
      // we clear the fixed state (in case that fixed column is moved outside fixed area).
      if (coFixed in FOptions) and (FPosition > 0) then
        Temp := Owner.ColumnFromPosition(FPosition - 1)
      else
        Temp := Owner.ColumnFromPosition(FPosition + 1);

      if Temp <> NoColumn then
      begin
        if coFixed in Owner[Temp].Options then
          Options := Options + [coFixed]
        else
          Options := Options - [coFixed];
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetSpacing(Value: Integer);

begin
  if FSpacing <> Value then
  begin
    FSpacing := Value;
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetStyle(Value: TVirtualTreeColumnStyle);

begin
  if FStyle <> Value then
  begin
    FStyle := Value;
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetText(const Value: TTranslateString);

begin
  if FText <> Value then
  begin
    FText := Value;
    FCaptionText := '';
    Changed(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SetWidth(Value: Integer);

var
  EffectiveMaxWidth,
  EffectiveMinWidth,
  TotalFixedMaxWidth,
  TotalFixedMinWidth: Integer;
  I: TColumnIndex;

begin
  if not (hsScaling in Owner.FHeader.FStates) then
    if ([coVisible, coFixed] * FOptions = [coVisible, coFixed]) then
    begin
      with Owner, FHeader, FFixedAreaConstraints, TreeView do
      begin
        TotalFixedMinWidth := 0;
        TotalFixedMaxWidth := 0;
        for I := 0 to FColumns.Count - 1 do
          if ([coVisible, coFixed] * FColumns[I].FOptions = [coVisible, coFixed]) then
          begin
            Inc(TotalFixedMaxWidth, FColumns[I].FMaxWidth);
            Inc(TotalFixedMinWidth, FColumns[I].FMinWidth);
          end;

        // The percentage values have precedence over the pixel values.
        TotalFixedMinWidth := IfThen(FMaxWidthPercent > 0,
                                     Min((ClientWidth * FMaxWidthPercent) div 100, TotalFixedMinWidth),
                                     TotalFixedMinWidth);
        TotalFixedMaxWidth := IfThen(FMinWidthPercent > 0,
                                     Max((ClientWidth * FMinWidthPercent) div 100, TotalFixedMaxWidth),
                                     TotalFixedMaxWidth);

        EffectiveMaxWidth := Min(TotalFixedMaxWidth - (GetVisibleFixedWidth - Self.FWidth), FMaxWidth);
        EffectiveMinWidth := Max(TotalFixedMinWidth - (GetVisibleFixedWidth - Self.FWidth), FMinWidth);
        Value := Min(Max(Value, EffectiveMinWidth), EffectiveMaxWidth);

        if FMinWidthPercent > 0 then
          Value := Max((ClientWidth * FMinWidthPercent) div 100 - GetVisibleFixedWidth + Self.FWidth, Value);
        if FMaxWidthPercent > 0 then
          Value := Min((ClientWidth * FMaxWidthPercent) div 100 - GetVisibleFixedWidth + Self.FWidth, Value);
      end;
    end
    else
      Value := Min(Max(Value, FMinWidth), FMaxWidth);

  if FWidth <> Value then
  begin
    FLastWidth := FWidth;
    if not (hsResizing in Owner.Header.States) then
      FBonusPixel := False;
    with Owner, Header do
    begin
      if not (hoAutoResize in FOptions) or (Index <> FAutoSizeIndex) then
      begin
        FWidth := Value;
        UpdatePositions;
      end;
      if not (csLoading in Treeview.ComponentState) and (UpdateCount = 0) then
      begin
        if hoAutoResize in FOptions then
          AdjustAutoSize(Index);
        Tree.DoColumnResize(Index);
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.ComputeHeaderLayout(DC: HDC; const Client: TRect; UseHeaderGlyph, UseSortGlyph: Boolean;
  var HeaderGlyphPos, SortGlyphPos: TPoint; var SortGlyphSize: TSize; var TextBounds: TRect; DrawFormat: Cardinal;
  CalculateTextRect: Boolean = False);

// The layout of a column header is determined by a lot of factors. This method takes them all into account and
// determines all necessary positions and bounds:
// - for the header text
// - the header glyph
// - the sort glyph

var
  TextSize: TSize;
  TextPos,
  ClientSize,
  HeaderGlyphSize: TPoint;
  CurrentAlignment: TAlignment;
  MinLeft,
  MaxRight,
  TextSpacing: Integer;
  UseText: Boolean;
  R: TRect;
  {$ifdef Windows}
  Theme: HTHEME;
  {$endif}

begin
  UseText := Length(FText) > 0;
  // If nothing is to show then don't waste time with useless preparation.
  if not (UseText or UseHeaderGlyph or UseSortGlyph) then
    Exit;

  CurrentAlignment := CaptionAlignment;
  if FBiDiMode <> bdLeftToRight then
    ChangeBiDiModeAlignment(CurrentAlignment);

  // Calculate sizes of the involved items.
  ClientSize := Types.Point(Client.Right - Client.Left, Client.Bottom - Client.Top);
  with Owner, Header do
  begin
    if UseHeaderGlyph then
      if not FCheckBox then begin
        {$IF LCL_FullVersion >= 2000000}
        with FImages.ResolutionForPPI[FImagesWidth, Font.PixelsPerInch, Self.Owner.Header.TreeView.GetCanvasScaleFactor] do
          HeaderGlyphSize := Types.Point(Width, Height);
        {$ELSE}
        HeaderGlyphSize := Types.Point(FImages.Width, FImages.Height)
        {$IFEND}
      end else
        with Self.Owner.Header.Tree do
        begin
          if Assigned(CheckImages) then
            HeaderGlyphSize := Types.Point(GetRealCheckImagesWidth, GetRealCheckImagesHeight);
        end
    else
      HeaderGlyphSize := Types.Point(0, 0);
    if UseSortGlyph then
    begin
      if tsUseExplorerTheme in FHeader.Tree.TreeStates then
      begin
        R := Types.Rect(0, 0, 100, 100);

	{$ifdef Windows}
        Theme := OpenThemeData(FHeader.Treeview.Handle, 'HEADER');
        GetThemePartSize(Theme, DC, HP_HEADERSORTARROW, HSAS_SORTEDUP, @R, TS_TRUE, SortGlyphSize);
        CloseThemeData(Theme);
	{$endif}
      end
      else
      begin
        SortGlyphSize.cx := VirtualTrees.UtilityImages.Height;
        SortGlyphSize.cy := VirtualTrees.UtilityImages.Height;
      end;

      // In any case, the sort glyph is vertically centered.
      SortGlyphPos.Y := (ClientSize.Y - SortGlyphSize.cy) div 2;
    end
    else
    begin
      SortGlyphSize.cx := 0;
      SortGlyphSize.cy := 0;
    end;
  end;

  if UseText then
  begin
    if not (coWrapCaption in FOptions) then
    begin
      FCaptionText := FText;
      GetTextExtentPoint32(DC, PChar(FText), Length(FText), TextSize);
      Inc(TextSize.cx, 2);
      TextBounds := Types.Rect(0, 0, TextSize.cx, TextSize.cy);
    end
    else
    begin
      R := Client;
      if FCaptionText = '' then
        FCaptionText := WrapString(DC, FText, R, DT_RTLREADING and DrawFormat <> 0, DrawFormat);

      GetStringDrawRect(DC, FCaptionText, R, DrawFormat);
      TextSize.cx := Client.Right - Client.Left;
      TextSize.cy := R.Bottom - R.Top;
      TextBounds  := Types.Rect(0, 0, TextSize.cx, TextSize.cy);
    end;
    TextSpacing := FSpacing;
  end
  else
  begin
    TextSpacing := 0;
    TextSize.cx := 0;
    TextSize.cy := 0;
  end;

  // Check first for the special case where nothing is shown except the sort glyph.
  if UseSortGlyph and not (UseText or UseHeaderGlyph) then
  begin
    // Center the sort glyph in the available area if nothing else is there.
    SortGlyphPos := Types.Point((ClientSize.X - SortGlyphSize.cx) div 2, (ClientSize.Y - SortGlyphSize.cy) div 2);
  end
  else
  begin
    // Determine extents of text and glyph and calculate positions which are clear from the layout.
    if (Layout in [blGlyphLeft, blGlyphRight]) or not UseHeaderGlyph then
    begin
      HeaderGlyphPos.Y := (ClientSize.Y - HeaderGlyphSize.Y) div 2;
      // If the text is taller than the given height, perform no vertical centration as this
      // would make the text even less readable.
      //Using Max() fixes badly positioned text if Extra Large fonts have been activated in the Windows display options
      TextPos.Y := Max(-5, (ClientSize.Y - TextSize.cy) div 2);
    end
    else
    begin
      if Layout = blGlyphTop then
      begin
        HeaderGlyphPos.Y := (ClientSize.Y - HeaderGlyphSize.Y - TextSize.cy - TextSpacing) div 2;
        TextPos.Y := HeaderGlyphPos.Y + HeaderGlyphSize.Y + TextSpacing;
      end
      else
      begin
        TextPos.Y := (ClientSize.Y - HeaderGlyphSize.Y - TextSize.cy - TextSpacing) div 2;
        HeaderGlyphPos.Y := TextPos.Y + TextSize.cy + TextSpacing;
      end;
    end;

    // Each alignment needs special consideration.
    case CurrentAlignment of
      taLeftJustify:
        begin
          MinLeft := FMargin;
          if UseSortGlyph and (FBiDiMode <> bdLeftToRight) then
          begin
            // In RTL context is the sort glyph placed on the left hand side.
            SortGlyphPos.X := MinLeft;
            Inc(MinLeft, SortGlyphSize.cx + FSpacing);
          end;
          if Layout in [blGlyphTop, blGlyphBottom] then
          begin
            // Header glyph is above or below text, so both must be considered when calculating
            // the left positition of the sort glyph (if it is on the right hand side).
            TextPos.X := MinLeft;
            if UseHeaderGlyph then
            begin
              HeaderGlyphPos.X := (ClientSize.X - HeaderGlyphSize.X) div 2;
              if HeaderGlyphPos.X < MinLeft then
                HeaderGlyphPos.X := MinLeft;
              MinLeft := Max(TextPos.X + TextSize.cx + TextSpacing, HeaderGlyphPos.X + HeaderGlyphSize.X + FSpacing);
            end
            else
              MinLeft := TextPos.X + TextSize.cx + TextSpacing;
          end
          else
          begin
            // Everything is lined up. TextSpacing might be 0 if there is no text.
            // This simplifies the calculation because no extra tests are necessary.
            if UseHeaderGlyph and (Layout = blGlyphLeft) then
            begin
              HeaderGlyphPos.X := MinLeft;
              Inc(MinLeft, HeaderGlyphSize.X + FSpacing);
            end;
            TextPos.X := MinLeft;
            Inc(MinLeft, TextSize.cx + TextSpacing);
            if UseHeaderGlyph and (Layout = blGlyphRight) then
            begin
              HeaderGlyphPos.X := MinLeft;
              Inc(MinLeft, HeaderGlyphSize.X + FSpacing);
            end;
          end;
          if UseSortGlyph and (FBiDiMode = bdLeftToRight) then
            SortGlyphPos.X := MinLeft;
        end;
      taCenter:
        begin
          if Layout in [blGlyphTop, blGlyphBottom] then
          begin
            HeaderGlyphPos.X := (ClientSize.X - HeaderGlyphSize.X) div 2;
            TextPos.X := (ClientSize.X - TextSize.cx) div 2;
            if UseSortGlyph then
              Dec(TextPos.X, SortGlyphSize.cx div 2);
          end
          else
          begin
            MinLeft := (ClientSize.X - HeaderGlyphSize.X - TextSpacing - TextSize.cx) div 2;
            if UseHeaderGlyph and (Layout = blGlyphLeft) then
            begin
              HeaderGlyphPos.X := MinLeft;
              Inc(MinLeft, HeaderGlyphSize.X + TextSpacing);
            end;
            TextPos.X := MinLeft;
            Inc(MinLeft, TextSize.cx + TextSpacing);
            if UseHeaderGlyph and (Layout = blGlyphRight) then
              HeaderGlyphPos.X := MinLeft;
          end;
          if UseHeaderGlyph then
          begin
            MinLeft := Min(HeaderGlyphPos.X, TextPos.X);
            MaxRight := Max(HeaderGlyphPos.X + HeaderGlyphSize.X, TextPos.X + TextSize.cx);
          end
          else
          begin
            MinLeft := TextPos.X;
            MaxRight := TextPos.X + TextSize.cx;
          end;
          // Place the sort glyph directly to the left or right of the larger item.
          if UseSortGlyph then
            if FBiDiMode = bdLeftToRight then
            begin
              // Sort glyph on the right hand side.
              SortGlyphPos.X := MaxRight + FSpacing;
            end
            else
            begin
              // Sort glyph on the left hand side.
              SortGlyphPos.X := MinLeft - FSpacing - SortGlyphSize.cx;
            end;
        end;
    else
      // taRightJustify
      MaxRight := ClientSize.X - FMargin;
      if UseSortGlyph and (FBiDiMode = bdLeftToRight) then
      begin
        // In LTR context is the sort glyph placed on the right hand side.
        Dec(MaxRight, SortGlyphSize.cx);
        SortGlyphPos.X := MaxRight;
        Dec(MaxRight, FSpacing);
      end;
      if Layout in [blGlyphTop, blGlyphBottom] then
      begin
        TextPos.X := MaxRight - TextSize.cx;
        if UseHeaderGlyph then
        begin
          HeaderGlyphPos.X := (ClientSize.X - HeaderGlyphSize.X) div 2;
          if HeaderGlyphPos.X + HeaderGlyphSize.X + FSpacing > MaxRight then
            HeaderGlyphPos.X := MaxRight - HeaderGlyphSize.X - FSpacing;
          MaxRight := Min(TextPos.X - TextSpacing, HeaderGlyphPos.X - FSpacing);
        end
        else
          MaxRight := TextPos.X - TextSpacing;
      end
      else
      begin
        // Everything is lined up. TextSpacing might be 0 if there is no text.
        // This simplifies the calculation because no extra tests are necessary.
        if UseHeaderGlyph and (Layout = blGlyphRight) then
        begin
          HeaderGlyphPos.X := MaxRight -  HeaderGlyphSize.X;
          MaxRight := HeaderGlyphPos.X - FSpacing;
        end;
        TextPos.X := MaxRight - TextSize.cx;
        MaxRight := TextPos.X - TextSpacing;
        if UseHeaderGlyph and (Layout = blGlyphLeft) then
        begin
          HeaderGlyphPos.X := MaxRight - HeaderGlyphSize.X;
          MaxRight := HeaderGlyphPos.X - FSpacing;
        end;
      end;
      if UseSortGlyph and (FBiDiMode <> bdLeftToRight) then
        SortGlyphPos.X := MaxRight - SortGlyphSize.cx;
    end;
  end;

  // Once the position of each element is determined there remains only one but important step.
  // The horizontal positions of every element must be adjusted so that it always fits into the
  // given header area. This is accomplished by shorten the text appropriately.

  // These are the maximum bounds. Nothing goes beyond them.
  MinLeft := FMargin;
  MaxRight := ClientSize.X - FMargin;
  if UseSortGlyph then
  begin
    if FBiDiMode = bdLeftToRight then
    begin
      // Sort glyph on the right hand side.
      if SortGlyphPos.X + SortGlyphSize.cx > MaxRight then
        SortGlyphPos.X := MaxRight - SortGlyphSize.cx;
      MaxRight := SortGlyphPos.X - FSpacing;
    end;

    // Consider also the left side of the sort glyph regardless of the bidi mode.
    if SortGlyphPos.X < MinLeft then
      SortGlyphPos.X := MinLeft;
    // Left border needs only adjustment if the sort glyph marks the left border.
    if FBiDiMode <> bdLeftToRight then
      MinLeft := SortGlyphPos.X + SortGlyphSize.cx + FSpacing;

    // Finally transform sort glyph to its actual position.
    Inc(SortGlyphPos.X, Client.Left);
    Inc(SortGlyphPos.Y, Client.Top);
  end;
  if UseHeaderGlyph then
  begin
    if HeaderGlyphPos.X + HeaderGlyphSize.X > MaxRight then
      HeaderGlyphPos.X := MaxRight - HeaderGlyphSize.X;
    if Layout = blGlyphRight then
      MaxRight := HeaderGlyphPos.X - FSpacing;
    if HeaderGlyphPos.X < MinLeft then
      HeaderGlyphPos.X := MinLeft;
    if Layout = blGlyphLeft then
      MinLeft := HeaderGlyphPos.X + HeaderGlyphSize.X + FSpacing;
    if FCheckBox and (Owner.Header.MainColumn = Self.Index) then
      Dec(HeaderGlyphPos.X, 2)
    else
      if Owner.Header.MainColumn <> Self.Index then
        Dec(HeaderGlyphPos.X, 2);

    // Finally transform header glyph to its actual position.
    Inc(HeaderGlyphPos.X, Client.Left);
    Inc(HeaderGlyphPos.Y, Client.Top);
  end;
  if UseText then
  begin
    if TextPos.X < MinLeft then
      TextPos.X := MinLeft;
    OffsetRect(TextBounds, TextPos.X, TextPos.Y);
    if TextBounds.Right > MaxRight then
      TextBounds.Right := MaxRight;
    OffsetRect(TextBounds, Client.Left, Client.Top);

    if coWrapCaption in FOptions then
    begin
      // Wrap the column caption if necessary.
      R := TextBounds;
      FCaptionText := WrapString(DC, FText, R, DT_RTLREADING and DrawFormat <> 0, DrawFormat);
      GetStringDrawRect(DC, FCaptionText, R, DrawFormat);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.GetAbsoluteBounds(var Left, Right: Integer);

// Returns the column's left and right bounds in header coordinates, that is, independant of the scrolling position.

begin
  Left := FLeft;
  Right := FLeft + FWidth;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.GetDisplayName: string;

// Returns the column text otherwise the column id is returned

begin
  if Length(FText) > 0 then
    Result := FText
  else
    Result := Format('Column %d', [Index]);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.GetOwner: TVirtualTreeColumns;

begin
  Result := Collection as TVirtualTreeColumns;
end;

procedure TVirtualTreeColumn.InternalSetWidth(const Value: Integer);
begin
  FWidth := Value;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.Assign(Source: TPersistent);

var
  OldOptions: TVTColumnOptions;

begin
  if Source is TVirtualTreeColumn then
  begin
    OldOptions := FOptions;
    FOptions := [];

    BiDiMode := TVirtualTreeColumn(Source).BiDiMode;
    ImageIndex := TVirtualTreeColumn(Source).ImageIndex;
    Layout := TVirtualTreeColumn(Source).Layout;
    Margin := TVirtualTreeColumn(Source).Margin;
    MaxWidth := TVirtualTreeColumn(Source).MaxWidth;
    MinWidth := TVirtualTreeColumn(Source).MinWidth;
    Position := TVirtualTreeColumn(Source).Position;
    Spacing := TVirtualTreeColumn(Source).Spacing;
    Style := TVirtualTreeColumn(Source).Style;
    Text := TVirtualTreeColumn(Source).Text;
    Hint := TVirtualTreeColumn(Source).Hint;
    Width := TVirtualTreeColumn(Source).Width;
    Alignment := TVirtualTreeColumn(Source).Alignment;
    CaptionAlignment := TVirtualTreeColumn(Source).CaptionAlignment;
    Color := TVirtualTreeColumn(Source).Color;
    Tag := TVirtualTreeColumn(Source).Tag;

    // Order is important. Assign options last.
    FOptions := OldOptions;
    Options := TVirtualTreeColumn(Source).Options;

    Changed(False);
  end
  else
    inherited Assign(Source);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.Equals(OtherColumnObj: TObject): Boolean;
var
 OtherColumn : TVirtualTreeColumn;
begin
  if OtherColumnObj is TVirtualTreeColumn then
  begin
    OtherColumn := TVirtualTreeColumn (OtherColumnObj);
    Result := (BiDiMode = OtherColumn.BiDiMode) and
      (ImageIndex = OtherColumn.ImageIndex) and
      (Layout = OtherColumn.Layout) and
      (Margin = OtherColumn.Margin) and
      (MaxWidth = OtherColumn.MaxWidth) and
      (MinWidth = OtherColumn.MinWidth) and
      (Position = OtherColumn.Position) and
      (Spacing = OtherColumn.Spacing) and
      (Style = OtherColumn.Style) and
      (Text = OtherColumn.Text) and
      (Hint = OtherColumn.Hint) and
      (Width = OtherColumn.Width) and
      (Alignment = OtherColumn.Alignment) and
      (CaptionAlignment = OtherColumn.CaptionAlignment) and
      (Color = OtherColumn.Color) and
      (Tag = OtherColumn.Tag) and
      (Options = OtherColumn.Options);
  end
  else
    Result := False;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.GetRect: TRect;

// Returns the rectangle this column occupies in the header (relative to (0, 0) of the non-client area).

begin
  with TVirtualTreeColumns(GetOwner).FHeader do
    Result := Tree.HeaderRect;
  Inc(Result.Left, FLeft);
  Result.Right := Result.Left + FWidth;
end;

//----------------------------------------------------------------------------------------------------------------------

// [IPK]
function TVirtualTreeColumn.GetText: String;

begin
  Result := FText;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.LoadFromStream(const Stream: TStream; Version: Integer);

var
  Dummy: Integer;
  S: String;

begin
  with Stream do
  begin
    ReadBuffer(Dummy, SizeOf(Dummy));
    SetLength(S, Dummy);
    ReadBuffer(PChar(S)^, Dummy);
    Text := S;
    ReadBuffer(Dummy, SizeOf(Dummy));
    SetLength(FHint, Dummy);
    ReadBuffer(PChar(FHint)^, Dummy);
    ReadBuffer(Dummy, SizeOf(Dummy));
    Width := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    MinWidth := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    MaxWidth := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    Style := TVirtualTreeColumnStyle(Dummy);
    ReadBuffer(Dummy, SizeOf(Dummy));
    ImageIndex := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    Layout := TVTHeaderColumnLayout(Dummy);
    ReadBuffer(Dummy, SizeOf(Dummy));
    Margin := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    Spacing := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    BiDiMode := TBiDiMode(Dummy);

    ReadBuffer(Dummy, SizeOf(Dummy));
    Options := TVTColumnOptions(Word(Dummy and $FFFF));

    // Parts which have been introduced/changed with header stream version 1+.
    // LCL port started with header stream version 6 so no need to do the check here
    ReadBuffer(Dummy, SizeOf(Dummy));
    Tag := Dummy;
    ReadBuffer(Dummy, SizeOf(Dummy));
    Alignment := TAlignment(Dummy);

    ReadBuffer(Dummy, SizeOf(Dummy));
    Color := TColor(Dummy);

    if coUseCaptionAlignment in FOptions then
    begin
      ReadBuffer(Dummy, SizeOf(Dummy));
      CaptionAlignment := TAlignment(Dummy);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.ParentBiDiModeChanged;

var
  Columns: TVirtualTreeColumns;

begin
  if coParentBiDiMode in FOptions then
  begin
    Columns := GetOwner as TVirtualTreeColumns;
    if Assigned(Columns) and (FBiDiMode <> Columns.FHeader.Treeview.BiDiMode) then
    begin
      FBiDiMode := Columns.FHeader.Treeview.BiDiMode;
      Changed(False);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.ParentColorChanged;

var
  Columns: TVirtualTreeColumns;
  TreeViewColor: TColor;
begin
  if coParentColor in FOptions then
  begin
    Columns := GetOwner as TVirtualTreeColumns;
    if Assigned(Columns) then
    begin
      TreeViewColor := Columns.FHeader.Treeview.Brush.Color;
      if FColor <> TreeViewColor then
      begin
        FColor := TreeViewColor;
        Changed(False);
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.RestoreLastWidth;

begin
  TVirtualTreeColumns(GetOwner).AnimatedResize(Index, FLastWidth);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumn.SaveToStream(const Stream: TStream);

var
  Dummy: Integer;

begin
  with Stream do
  begin
    Dummy := Length(FText);
    WriteBuffer(Dummy, SizeOf(Dummy));
    WriteBuffer(PChar(FText)^, Dummy);
    Dummy := Length(FHint);
    WriteBuffer(Dummy, SizeOf(Dummy));
    WriteBuffer(PChar(FHint)^, Dummy);
    WriteBuffer(FWidth, SizeOf(FWidth));
    WriteBuffer(FMinWidth, SizeOf(FMinWidth));
    WriteBuffer(FMaxWidth, SizeOf(FMaxWidth));
    Dummy := Ord(FStyle);
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := FImageIndex;
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := Ord(FLayout);
    WriteBuffer(Dummy, SizeOf(Dummy));
    WriteBuffer(FMargin, SizeOf(FMargin));
    WriteBuffer(FSpacing, SizeOf(FSpacing));
    Dummy := Ord(FBiDiMode);
    WriteBuffer(Dummy, SizeOf(Dummy));
    Dummy := Word(FOptions);
    WriteBuffer(Dummy, SizeOf(Dummy));

    // parts introduced with stream version 1
    WriteBuffer(FTag, SizeOf(Dummy));
    Dummy := Cardinal(FAlignment);
    WriteBuffer(Dummy, SizeOf(Dummy));

    // parts introduced with stream version 2
    Dummy := Integer(FColor);
    WriteBuffer(Dummy, SizeOf(Dummy));

    // parts introduced with stream version 6
    if coUseCaptionAlignment in FOptions then
    begin
      Dummy := Cardinal(FCaptionAlignment);
      WriteBuffer(Dummy, SizeOf(Dummy));
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumn.UseRightToLeftReading: Boolean;

begin
  Result := FBiDiMode <> bdLeftToRight;
end;

//----------------- TVirtualTreeColumns --------------------------------------------------------------------------------

constructor TVirtualTreeColumns.Create(AOwner: TVTHeader);

var
  ColumnClass: TVirtualTreeColumnClass;

begin
  FHeader := AOwner;

  // Determine column class to be used in the header.
  ColumnClass := Self.TreeViewControl.GetColumnClass;
  // The owner tree always returns the default tree column class if not changed by application/descendants.
  inherited Create(ColumnClass);

  FHeaderBitmap := Graphics.TBitmap.Create;
  FHeaderBitmap.PixelFormat := pf32Bit;

  FHoverIndex := NoColumn;
  FDownIndex := NoColumn;
  FClickIndex := NoColumn;
  FDropTarget := NoColumn;
  FTrackIndex := NoColumn;
  {$IF LCL_FullVersion >= 1080000}
  FDefaultWidth := Header.TreeView.Scale96ToFont(DEFAULT_COLUMN_WIDTH);
  {$ELSE}
  FDefaultWidth := DEFAULT_COLUMN_WIDTH;
  {$IFEND}
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TVirtualTreeColumns.Destroy;

begin
  FHeaderBitmap.Free;
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetItem(Index: TColumnIndex): TVirtualTreeColumn;

begin
  Result := TVirtualTreeColumn(inherited GetItem(Index));
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetNewIndex(P: TPoint; var OldIndex: TColumnIndex): Boolean;

var
  NewIndex: Integer;

begin
  Result := False;
  // convert to local coordinates
  Inc(P.Y, FHeader.FHeight);
  NewIndex := ColumnFromPosition(P);
  if NewIndex <> OldIndex then
  begin
    if OldIndex > NoColumn then
      FHeader.Invalidate(Items[OldIndex]);
    OldIndex := NewIndex;
    if OldIndex > NoColumn then
      FHeader.Invalidate(Items[OldIndex]);
    Result := True;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.IsDefaultWidthStored: Boolean;
begin
  {$IF LCL_FullVersion >= 1080000}
  Result := FDefaultWidth <> Header.TreeView.Scale96ToFont(DEFAULT_COLUMN_WIDTH);
  {$ELSE}
  Result := FDefaultWidth <> DEFAULT_COLUMN_WIDTH;
  {$IFEND}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.SetDefaultWidth(Value: Integer);

begin
  FDefaultWidth := Value;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.SetItem(Index: TColumnIndex; Value: TVirtualTreeColumn);

begin
  inherited SetItem(Index, Value);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.AdjustAutoSize(CurrentIndex: TColumnIndex; Force: Boolean = False);

// Called only if the header is in auto-size mode which means a column needs to be so large
// that it fills all the horizontal space not occupied by the other columns.
// CurrentIndex (if not InvalidColumn) describes which column has just been resized.

var
  NewValue,
  AutoIndex,
  Index,
  RestWidth: Integer;
  WasUpdating: Boolean;
begin
  if Count > 0 then
  begin
    // Determine index to be used for auto resizing. This is usually given by the owner's AutoSizeIndex, but
    // could be different if the column whose resize caused the invokation here is either the auto column itself
    // or visually to the right of the auto size column.
    AutoIndex := FHeader.FAutoSizeIndex;
    if (AutoIndex < 0) or (AutoIndex >= Count) then
      AutoIndex := Count - 1;

    if AutoIndex >= 0 then
    begin
      with FHeader.Treeview do
      begin
        if HandleAllocated then
          RestWidth := ClientWidth
        else
          RestWidth := Width;
      end;

      // Go through all columns and calculate the rest space remaining.
      for Index := 0 to Count - 1 do
        if (Index <> AutoIndex) and (coVisible in Items[Index].FOptions) then
          Dec(RestWidth, Items[Index].Width);

      with Items[AutoIndex] do
      begin
        NewValue := Max(MinWidth, Min(MaxWidth, RestWidth));
        if Force or (FWidth <> NewValue) then
        begin
          FWidth := NewValue;
          UpdatePositions;
          WasUpdating := csUpdating in FHeader.Treeview.ComponentState;
          if not WasUpdating then
            FHeader.Tree.Updating();// Fixes #398
          try
            FHeader.Tree.DoColumnResize(AutoIndex);
          finally
            if not WasUpdating then
              FHeader.Tree.Updated();
          end;
        end;
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.AdjustDownColumn(P: TPoint): TColumnIndex;

// Determines the column from the given position and returns it. If this column is allowed to be clicked then
// it is also kept for later use.

begin
  // Convert to local coordinates.
  Inc(P.Y, FHeader.FHeight);
  Result := ColumnFromPosition(P);
  if (Result > NoColumn) and (Result <> FDownIndex) and (coAllowClick in Items[Result].FOptions) and
    (coEnabled in Items[Result].FOptions) then
  begin
    if FDownIndex > NoColumn then
      FHeader.Invalidate(Items[FDownIndex]);
    FDownIndex := Result;
    FCheckBoxHit := Items[Result].FHasImage and PtInRect(Items[Result].FImageRect, P) and Items[Result].CheckBox;
    FHeader.Invalidate(Items[FDownIndex]);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.AdjustHoverColumn(const P: TPoint): Boolean;

// Determines the new hover column index and returns True if the index actually changed else False.

begin
  Result := GetNewIndex(P, FHoverIndex);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.AdjustPosition(Column: TVirtualTreeColumn; Position: Cardinal);

// Reorders the column position array so that the given column gets the given position.

var
  OldPosition: Cardinal;

begin
  OldPosition := Column.Position;
  if OldPosition <> Position then
  begin
    if OldPosition < Position then
    begin
      // column will be moved up so move down other entries
      System.Move(FPositionToIndex[OldPosition + 1], FPositionToIndex[OldPosition], (Position - OldPosition) * SizeOf(Cardinal));
    end
    else
    begin
      // column will be moved down so move up other entries
      System.Move(FPositionToIndex[Position], FPositionToIndex[Position + 1], (OldPosition - Position) * SizeOf(Cardinal));
    end;
    FPositionToIndex[Position] := Column.Index;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.CanSplitterResize(P: TPoint; Column: TColumnIndex): Boolean;

begin
  Result := (Column > NoColumn) and ([coResizable, coVisible] * Items[Column].FOptions = [coResizable, coVisible]);
  DoCanSplitterResize(P, Column, Result);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.DoCanSplitterResize(P: TPoint; Column: TColumnIndex; var Allowed: Boolean);

begin
  if Assigned(FHeader.Tree.OnCanSplitterResizeColumn) then
    FHeader.Tree.OnCanSplitterResizeColumn(FHeader, P, Column, Allowed);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.DrawButtonText(DC: HDC; Caption: String; Bounds: TRect; Enabled, Hot: Boolean;
    DrawFormat: Cardinal; WrapCaption: Boolean);

var
  TextSpace: Integer;
  TextColor: TColor;
  Size: TSize;

begin
  if not WrapCaption then
  begin
    // Do we need to shorten the caption due to limited space?
    GetTextExtentPoint32(DC, PChar(Caption), Length(Caption), Size);
    TextSpace := Bounds.Right - Bounds.Left;
    if TextSpace < Size.cx then
      Caption := ShortenString(DC, Caption, TextSpace);
  end;

  SetBkMode(DC, TRANSPARENT);
  if not Enabled then
    if FHeader.Tree.VclStyleEnabled then
    begin
      TextColor := FHeader.Tree.Colors.HeaderFontColor;
      if TextColor = clDefault then
        TextColor := clBtnText;
      SetTextColor(DC, ColorToRGB(TextColor));
      DrawText(DC, PChar(Caption), Length(Caption), Bounds, DrawFormat);
    end
    else
  begin
    OffsetRect(Bounds, 1, 1);
    SetTextColor(DC, ColorToRGB(clBtnHighlight));
    DrawText(DC, PChar(Caption), Length(Caption), Bounds, DrawFormat);
    OffsetRect(Bounds, -1, -1);
    SetTextColor(DC, ColorToRGB(clBtnShadow));
    DrawText(DC, PChar(Caption), Length(Caption), Bounds, DrawFormat);
  end
  else
  begin
    if Hot then
      TextColor := FHeader.Tree.Colors.HeaderHotColor
    else
      TextColor := FHeader.Tree.Colors.HeaderFontColor;
    if TextColor = clDefault then
      TextColor := FHeader.Treeview.GetDefaultColor(dctFont);
    SetTextColor(DC, ColorToRGB(TextColor));
    DrawText(DC, PChar(Caption), Length(Caption), Bounds, DrawFormat);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.FixPositions;

// Fixes column positions after loading from DFM or Bidi mode change.

var
  I: Integer;

begin
  for I := 0 to Count - 1 do
    FPositionToIndex[Items[I].Position] := I;

  FNeedPositionsFix := False;
  UpdatePositions(True);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetColumnAndBounds(const P: TPoint; var ColumnLeft, ColumnRight: Integer;
  Relative: Boolean = True): Integer;

// Returns the column where the mouse is currently in as well as the left and right bound of
// this column (Left and Right are undetermined if no column is involved).

var
  I: Integer;

begin
  Result := InvalidColumn;
  if Relative and (P.X >= Header.Columns.GetVisibleFixedWidth) then
    ColumnLeft := -FHeader.Tree.EffectiveOffsetX
  else
    ColumnLeft := 0;

  if FHeader.Treeview.UseRightToLeftAlignment then
    Inc(ColumnLeft, FHeader.Tree.ComputeRTLOffset(True));

  for I := 0 to Count - 1 do
    with Items[FPositionToIndex[I]] do
      if coVisible in FOptions then
      begin
        ColumnRight := ColumnLeft + FWidth;
        if P.X < ColumnRight then
        begin
          Result := FPositionToIndex[I];
          Exit;
        end;
        ColumnLeft := ColumnRight;
      end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetOwner: TPersistent;

begin
  Result := FHeader;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.HandleClick(P: TPoint; Button: TMouseButton; Force, DblClick: Boolean);

// Generates a click event if the mouse button has been released over the same column it was pressed first.
// Alternatively, Force might be set to True to indicate that the down index does not matter (right, middle and
// double click).

var
  HitInfo: TVTHeaderHitInfo;
  NewClickIndex: Integer;

begin
  if (csDesigning in Header.Treeview.ComponentState) then
    exit;
  // Convert vertical position to local coordinates.
  //lclheader
  //Inc(P.Y, FHeader.FHeight);
  NewClickIndex := ColumnFromPosition(P);
  with HitInfo do
  begin
    X := P.X;
    Y := P.Y;
    Shift := FHeader.GetShiftState;
    if DblClick then
      Shift := Shift + [ssDouble];
  end;
  HitInfo.Button := Button;

  if (NewClickIndex > NoColumn) and (coAllowClick in Items[NewClickIndex].FOptions) and
    ((NewClickIndex = FDownIndex) or Force) then
  begin
    FClickIndex := NewClickIndex;
    HitInfo.Column := NewClickIndex;
    HitInfo.HitPosition := [hhiOnColumn];

    if Items[NewClickIndex].FHasImage and PtInRect(Items[NewClickIndex].FImageRect, P) then
    begin
      Include(HitInfo.HitPosition, hhiOnIcon);
      if Items[NewClickIndex].CheckBox then
      begin
        if Button = mbLeft then
          FHeader.Tree.UpdateColumnCheckState(Items[NewClickIndex]);
        Include(HitInfo.HitPosition, hhiOnCheckbox);
      end;
    end;
  end
  else
  begin
    FClickIndex := NoColumn;
    HitInfo.Column := NoColumn;
    HitInfo.HitPosition := [hhiNoWhere];
  end;

  if (hoHeaderClickAutoSort in Header.Options) and (HitInfo.Button = mbLeft) and not DblClick and not (hhiOnCheckbox in HitInfo.HitPosition) and (HitInfo.Column >= 0) then
  begin
    // handle automatic setting of SortColumn and toggling of the sort order
    if HitInfo.Column <> Header.SortColumn then
    begin
      // set sort column
      Header.SortColumn := HitInfo.Column;
      Header.SortDirection := Self[Header.SortColumn].DefaultSortDirection;
    end//if
    else
    begin
      // toggle sort direction
      if Header.SortDirection = sdDescending then
        Header.SortDirection := sdAscending
      else
        Header.SortDirection := sdDescending;
    end;//else
  end;//if

  if DblClick then
    FHeader.Tree.DoHeaderDblClick(HitInfo)
  else
    FHeader.Tree.DoHeaderClick(HitInfo);

  if not (hhiNoWhere in HitInfo.HitPosition) then
    FHeader.Invalidate(Items[NewClickIndex]);
  if (FClickIndex > NoColumn) and (FClickIndex <> NewClickIndex) then
    FHeader.Invalidate(Items[FClickIndex]);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.IndexChanged(OldIndex, NewIndex: Integer);

// Called by a column when its index in the collection changes. If NewIndex is -1 then the column is
// about to be removed, otherwise it is moved to a new index.
// The method will then update the position array to reflect the change.

var
  I: Integer;
  Increment: Integer;
  Lower,
  Upper: Integer;

begin
  if NewIndex = -1 then
  begin
    // Find position in the array with the old index.
    Upper := High(FPositionToIndex);
    for I := 0 to Upper do
    begin
      if FPositionToIndex[I] = OldIndex then
      begin
        // Index found. Move all higher entries one step down and remove the last entry.
        if I < Upper then
          System.Move(FPositionToIndex[I + 1], FPositionToIndex[I], (Upper - I) * SizeOf(TColumnIndex));
      end;
      // Decrease all indices, which are greater than the index to be deleted.
      if FPositionToIndex[I] > OldIndex then
        Dec(FPositionToIndex[I]);
    end;
    SetLength(FPositionToIndex, High(FPositionToIndex));
  end
  else
  begin
    if OldIndex < NewIndex then
      Increment := -1
    else
      Increment := 1;

    Lower := Min(OldIndex, NewIndex);
    Upper := Max(OldIndex, NewIndex);
    for I := 0 to High(FPositionToIndex) do
    begin
      if (FPositionToIndex[I] >= Lower) and (FPositionToIndex[I] < Upper) then
        Inc(FPositionToIndex[I], Increment)
      else
        if FPositionToIndex[I] = OldIndex then
          FPositionToIndex[I] := NewIndex;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.InitializePositionArray;

// Ensures that the column position array contains as many entries as columns are defined.
// The array is resized and initialized with default values if needed.

var
  I, OldSize: Integer;
  Changed: Boolean;

begin
  if Count <> Length(FPositionToIndex) then
  begin
    OldSize := Length(FPositionToIndex);
    SetLength(FPositionToIndex, Count);
    if Count > OldSize then
    begin
      // New items have been added, just set their position to the same as their index.
      for I := OldSize to Count - 1 do
        FPositionToIndex[I] := I;
    end
    else
    begin
      // Items have been deleted, so reindex remaining entries by decrementing values larger than the highest
      // possible index until no entry is higher than this limit.
      repeat
        Changed := False;
        for I := 0 to Count - 1 do
          if FPositionToIndex[I] >= Count then
          begin
            Dec(FPositionToIndex[I]);
            Changed := True;
          end;
      until not Changed;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.Notify(Item: TCollectionItem; Action: TCollectionNotification);

begin
  if Action in [cnExtracting, cnDeleting] then
    with Header.Tree do
      if not (csLoading in ComponentState) and (FocusedColumn = Item.Index) then
        InternalSetFocusedColumn(NoColumn); //bypass side effects in SetFocusedColumn
end;                                        // if cnDeleting

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.ReorderColumns(RTL: Boolean);

var
  I: Integer;

begin
  if RTL then
  begin
    for I := 0 to Count - 1 do
      FPositionToIndex[I] := Count - I - 1;
  end
  else
  begin
    for I := 0 to Count - 1 do
      FPositionToIndex[I] := I;
  end;

  UpdatePositions(True);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.Update(Item: TCollectionItem);

begin
  //lcl
  // Skip while Destroying
  if csDestroying in FHeader.TreeView.ComponentState then
    Exit;
  // This is the only place which gets notified when a new column has been added or removed
  // and we need this event to adjust the column position array.
  InitializePositionArray;
  if csLoading in Header.Treeview.ComponentState then
    FNeedPositionsFix := True
  else
    UpdatePositions;

  // The first column which is created is by definition also the main column.
  if (Count > 0) and (Header.FMainColumn < 0) then
    FHeader.FMainColumn := 0;

  if not (csLoading in Header.Treeview.ComponentState) and not (hsLoading in FHeader.FStates) then
  begin
    with FHeader do
    begin
      if hoAutoResize in FOptions then
        AdjustAutoSize(InvalidColumn);
      if Assigned(Item) then
        Invalidate(Item as TVirtualTreeColumn)
      else
        if Treeview.HandleAllocated then
        begin
          Tree.UpdateHorizontalScrollBar(False);
          Invalidate(nil);
          Treeview.Invalidate;
        end;

      if not (tsUpdating in Tree.TreeStates) then
        // This is mainly to let the designer know when a change occurs at design time which
        // doesn't involve the object inspector (like column resizing with the mouse).
        // This does NOT include design time code as the communication is done via an interface.
        Tree.UpdateDesigner;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.UpdatePositions(Force: Boolean = False);

// Recalculates the left border of every column and updates their position property according to the
// PostionToIndex array which primarily determines where each column is placed visually.

var
  I, RunningPos: Integer;

begin
  if not FNeedPositionsFix and (Force or (UpdateCount = 0)) then
  begin
    RunningPos := 0;
    for I := 0 to High(FPositionToIndex) do
      with Items[FPositionToIndex[I]] do
      begin
        FPosition := I;
        FLeft := RunningPos;
        if coVisible in FOptions then
          Inc(RunningPos, FWidth);
      end;
    FHeader.Tree.UpdateHorizontalScrollBar(False);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.Add: TVirtualTreeColumn;

begin
  Result := TVirtualTreeColumn(inherited Add);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.AnimatedResize(Column: TColumnIndex; NewWidth: Integer);

// Resizes the given column animated by scrolling the window DC.
{$ifndef INCOMPLETE_WINAPI}
var
  OldWidth: Integer;
  DC: HDC;
  I,
  Steps,
  DX: Integer;
  HeaderScrollRect,
  ScrollRect,
  R: TRect;

  NewBrush,
  LastBrush: HBRUSH;
{$endif}
begin
  //todo: reimplement
  {$ifndef INCOMPLETE_WINAPI}
  if not IsValidColumn(Column) then
    Exit; // Just in case.

  // Make sure the width constrains are considered.
  if NewWidth < Items[Column].FMinWidth then
     NewWidth := Items[Column].FMinWidth;
  if NewWidth > Items[Column].FMaxWidth then
     NewWidth := Items[Column].FMaxWidth;

  OldWidth := Items[Column].Width;
  // Nothing to do if the width is the same.
  if OldWidth <> NewWidth then
  begin
    if not ( (hoDisableAnimatedResize in FHeader.Options) or
             (coDisableAnimatedResize in Items[Column].Options) ) then
    begin
      DC := GetWindowDC(FHeader.Treeview.Handle);
      with FHeader.Tree do
      try
        Steps := 32;
        DX := (NewWidth - OldWidth) div Steps;

        // Determination of the scroll rectangle is a bit complicated since we neither want
        // to scroll the scrollbars nor the border of the treeview window.
        HeaderScrollRect := HeaderRect;
        ScrollRect := HeaderScrollRect;
        // Exclude the header itself from scrolling.
        ScrollRect.Top := ScrollRect.Bottom;
        ScrollRect.Bottom := ScrollRect.Top + ClientHeight;
        ScrollRect.Right := ScrollRect.Left + ClientWidth;
        with Items[Column] do
          Inc(ScrollRect.Left, FLeft + FWidth);
        HeaderScrollRect.Left := ScrollRect.Left;
        HeaderScrollRect.Right := ScrollRect.Right;

        // When the new width is larger then avoid artefacts on the left hand side
        // by deleting a small stripe
        if NewWidth > OldWidth then
        begin
          R := ScrollRect;
          NewBrush := CreateSolidBrush(ColorToRGB(Brush.Color));
          LastBrush := SelectObject(DC, NewBrush);
          R.Right := R.Left + DX;
          FillRect(DC, R, NewBrush);
          SelectObject(DC, LastBrush);
          DeleteObject(NewBrush);
        end
        else
        begin
          Inc(HeaderScrollRect.Left, DX);
          Inc(ScrollRect.Left, DX);
        end;

        for I := 0 to Steps - 1 do
        begin
          ScrollDC(DC, DX, 0, HeaderScrollRect, HeaderScrollRect, 0, nil);
          Inc(HeaderScrollRect.Left, DX);
          ScrollDC(DC, DX, 0, ScrollRect, ScrollRect, 0, nil);
          Inc(ScrollRect.Left, DX);
          Sleep(1);
        end;
      finally
        ReleaseDC(Handle, DC);
      end;
    end;
    Items[Column].Width := NewWidth;
  end;
  {$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.Assign(Source: TPersistent);

begin
  // Let the collection class assign the items.
  inherited;

  if Source is TVirtualTreeColumns then
  begin
    // Copying the position array is the only needed task here.
    FPositionToIndex := Copy(TVirtualTreeColumns(Source).FPositionToIndex, 0, MaxInt);

    // Make sure the left edges are correct after assignment.
    FNeedPositionsFix := False;
    UpdatePositions(True);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.Clear;

begin
  FClearing := True;
  try
    Header.Tree.CancelEditNode;

    // Since we're freeing all columns, the following have to be true when we're done.
    FHoverIndex := NoColumn;
    FDownIndex := NoColumn;
    FTrackIndex := NoColumn;
    FClickIndex := NoColumn;
    FCheckBoxHit := False;

    with Header do
      if not (hsLoading in States) then
      begin
        InternalSetAutoSizeIndex(NoColumn); //bypass side effects in SetAutoSizeColumn
        MainColumn := NoColumn;
        InternalSetSortColumn(NoColumn);    //bypass side effects in SetSortColumn
      end;

    with Header.Tree do
      if not (csLoading in ComponentState) then
        InternalSetFocusedColumn(NoColumn); //bypass side effects in SetFocusedColumn

    inherited Clear;
  finally
    FClearing := False;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.ColumnFromPosition(const P: TPoint; Relative: Boolean = True): TColumnIndex;

// Determines the current column based on the position passed in P.

var
  I, Sum: Integer;

begin
  Result := InvalidColumn;

  // The position must be within the header area, but we extend the vertical bounds to the entire treeview area.
  if (P.X >= 0) and (P.Y >= 0) and (P.Y <= FHeader.TreeView.Height) then
    with FHeader, Tree do
    begin
      if Relative and (P.X >= GetVisibleFixedWidth) then
        Sum := -EffectiveOffsetX
      else
        Sum := 0;

      if UseRightToLeftAlignment then
        Inc(Sum, ComputeRTLOffset(True));

      for I := 0 to Count - 1 do
        if coVisible in Items[FPositionToIndex[I]].FOptions then
        begin
          Inc(Sum, Items[FPositionToIndex[I]].Width);
          if P.X < Sum then
          begin
            Result := FPositionToIndex[I];
            Break;
          end;
        end;
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.ColumnFromPosition(PositionIndex: TColumnPosition): TColumnIndex;

// Returns the index of the column at the given position.

begin
  if Integer(PositionIndex) < Length(FPositionToIndex) then
    Result := FPositionToIndex[PositionIndex]
  else
    Result := NoColumn;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.Equals(OtherColumnsObj: TObject): Boolean;

// Compares itself with the given set of columns and returns True if all published properties are the same
// (including column order), otherwise False is returned.

var
  I: Integer;
  OtherColumns : TVirtualTreeColumns;

begin
  if not (OtherColumnsObj is TVirtualTreeColumns) then
  begin
    Result := False;
    Exit;
  end;

  OtherColumns := TVirtualTreeColumns (OtherColumnsObj);

  // Same number of columns?
  Result := OtherColumns.Count = Count;
  if Result then
  begin
    // Same order of columns?
    Result := CompareMem(Pointer(FPositionToIndex), Pointer(OtherColumns.FPositionToIndex),
      Length(FPositionToIndex) * SizeOf(TColumnIndex));
    if Result then
    begin
      for I := 0 to Count - 1 do
        if not Items[I].Equals(OtherColumns[I]) then
        begin
          Result := False;
          Break;
        end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.GetColumnBounds(Column: TColumnIndex; out Left, Right: Integer);

// Returns the left and right bound of the given column. If Column is NoColumn then the entire client width is returned.

begin
  if Column <= NoColumn then
  begin
    Left := 0;
    Right := FHeader.Treeview.ClientWidth;
  end
  else
  begin
    Left := Items[Column].Left;
    Right := Left + Items[Column].Width;
    if FHeader.Treeview.UseRightToLeftAlignment then
    begin
      Inc(Left, FHeader.Tree.ComputeRTLOffset(True));
      Inc(Right, FHeader.Tree.ComputeRTLOffset(True));
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetScrollWidth: Integer;

// Returns the average width of all visible, non-fixed columns. If there is no such column the indent is returned.

var
  I: Integer;
  ScrollColumnCount: Integer;

begin

  Result := 0;

  ScrollColumnCount := 0;
  for I := 0 to FHeader.Columns.Count - 1 do
  begin
    if ([coVisible, coFixed] * FHeader.Columns[I].Options = [coVisible]) then
    begin
      Inc(Result, FHeader.Columns[I].Width);
      Inc(ScrollColumnCount);
    end;
  end;

  if ScrollColumnCount > 0 then // use average width
    Result := Round(Result / ScrollColumnCount)
  else // use indent
    Result := Integer(FHeader.Tree.Indent);

end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetFirstVisibleColumn(ConsiderAllowFocus: Boolean = False): TColumnIndex;

// Returns the index of the first visible column or "InvalidColumn" if either no columns are defined or
// all columns are hidden.
// If ConsiderAllowFocus is True then the column has not only to be visible but also focus has to be allowed.

var
  I: Integer;

begin
  Result := InvalidColumn;
  for I := 0 to Count - 1 do
    if (coVisible in Items[FPositionToIndex[I]].FOptions) and
       ( (not ConsiderAllowFocus) or
         (coAllowFocus in Items[FPositionToIndex[I]].FOptions)
       ) then
    begin
      Result := FPositionToIndex[I];
      Break;
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetLastVisibleColumn(ConsiderAllowFocus: Boolean = False): TColumnIndex;

// Returns the index of the last visible column or "InvalidColumn" if either no columns are defined or
// all columns are hidden.
// If ConsiderAllowFocus is True then the column has not only to be visible but also focus has to be allowed.

var
  I: Integer;

begin
  Result := InvalidColumn;
  for I := Count - 1 downto 0 do
    if (coVisible in Items[FPositionToIndex[I]].FOptions) and
       ( (not ConsiderAllowFocus) or
         (coAllowFocus in Items[FPositionToIndex[I]].FOptions)
       ) then
    begin
      Result := FPositionToIndex[I];
      Break;
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetFirstColumn: TColumnIndex;

// Returns the first column in display order.

begin
  if Count = 0 then
    Result := InvalidColumn
  else
    Result := FPositionToIndex[0];
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetNextColumn(Column: TColumnIndex): TColumnIndex;

// Returns the next column in display order. Column is the index of an item in the collection (a column).

var
  Position: Integer;

begin
  if Column < 0 then
    Result := InvalidColumn
  else
  begin
    Position := Items[Column].Position;
    if Position < Count - 1 then
      Result := FPositionToIndex[Position + 1]
    else
      Result := InvalidColumn;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetNextVisibleColumn(Column: TColumnIndex; ConsiderAllowFocus: Boolean = False): TColumnIndex;

// Returns the next visible column in display order, Column is an index into the columns list.
// If ConsiderAllowFocus is True then the column has not only to be visible but also focus has to be allowed.

begin
  Result := Column;
  repeat
    Result := GetNextColumn(Result);
  until (Result = InvalidColumn) or
        ( (coVisible in Items[Result].FOptions) and
          ( (not ConsiderAllowFocus) or
            (coAllowFocus in Items[Result].FOptions)
          )
        );
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetPreviousColumn(Column: TColumnIndex): TColumnIndex;

// Returns the previous column in display order, Column is an index into the columns list.

var
  Position: Integer;

begin
  if Column < 0 then
    Result := InvalidColumn
  else
  begin
    Position := Items[Column].Position;
    if Position > 0 then
      Result := FPositionToIndex[Position - 1]
    else
      Result := InvalidColumn;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetPreviousVisibleColumn(Column: TColumnIndex; ConsiderAllowFocus: Boolean = False): TColumnIndex;

// Returns the previous visible column in display order, Column is an index into the columns list.
// If ConsiderAllowFocus is True then the column has not only to be visible but also focus has to be allowed.

begin
  Result := Column;
  repeat
    Result := GetPreviousColumn(Result);
  until (Result = InvalidColumn) or
        ( (coVisible in Items[Result].FOptions) and
          ( (not ConsiderAllowFocus) or
            (coAllowFocus in Items[Result].FOptions)
          )
        );
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetVisibleColumns: TColumnsArray;

// Returns a list of all currently visible columns in actual order.

var
  I, Counter: Integer;

begin
  SetLength(Result, Count);
  Counter := 0;

  for I := 0 to Count - 1 do
    if coVisible in Items[FPositionToIndex[I]].FOptions then
    begin
      Result[Counter] := Items[FPositionToIndex[I]];
      Inc(Counter);
    end;
  // Set result length to actual visible count.
  SetLength(Result, Counter);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.GetVisibleFixedWidth: Integer;

// Determines the horizontal space all visible and fixed columns occupy.

var
  I: Integer;

begin
  Result := 0;
  for I := 0 to Count - 1 do
  begin
    if Items[I].Options * [coVisible, coFixed] = [coVisible, coFixed] then
      Inc(Result, Items[I].Width);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.IsValidColumn(Column: TColumnIndex): Boolean;

// Determines whether the given column is valid or not, that is, whether it is one of the current columns.

begin
  Result := (Column > NoColumn) and (Column < Count);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.LoadFromStream(const Stream: TStream; Version: Integer);

var
  I,
  ItemCount: Integer;

begin
  Clear;
  Stream.ReadBuffer(ItemCount, SizeOf(ItemCount));
  // number of columns
  if ItemCount > 0 then
  begin
    BeginUpdate;
    try
      for I := 0 to ItemCount - 1 do
        Add.LoadFromStream(Stream, Version);
      SetLength(FPositionToIndex, ItemCount);
      Stream.ReadBuffer(FPositionToIndex[0], ItemCount * SizeOf(TColumnIndex));
      UpdatePositions(True);
    finally
      EndUpdate;
    end;
  end;

  // Data introduced with header stream version 5
  // LCL port started with header stream version 6 so no need to do the check here
  Stream.ReadBuffer(FDefaultWidth, SizeOf(FDefaultWidth));
end;
//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.PaintHeader(DC: HDC; const R: TRect; HOffset: Integer);

// Backward compatible header paint method. This method takes care of visually moving floating columns

var
  VisibleFixedWidth: Integer;
  RTLOffset: Integer;

  procedure PaintFixedArea;

  begin
    if VisibleFixedWidth > 0 then
      PaintHeader(FHeaderBitmap.Canvas,
        Types.Rect(0, 0, Min(R.Right, VisibleFixedWidth), R.Bottom - R.Top),
        Types.Point(R.Left, R.Top), RTLOffset);
  end;

begin
  // Adjust size of the header bitmap
  with TWithSafeRect(FHeader.Tree.HeaderRect) do
  begin
    FHeaderBitmap.Width := Max(Right, R.Right - R.Left);
    FHeaderBitmap.Height := Bottom;
  end;

  VisibleFixedWidth := GetVisibleFixedWidth;

  // Consider right-to-left directionality.
  if FHeader.Tree.UseRightToLeftAlignment then
    RTLOffset := FHeader.Tree.ComputeRTLOffset
  else
    RTLOffset := 0;

  if RTLOffset = 0 then
    PaintFixedArea;

  // Paint the floating part of the header.
  PaintHeader(FHeaderBitmap.Canvas,
    Types.Rect(VisibleFixedWidth - HOffset, 0, R.Right + VisibleFixedWidth - HOffset, R.Bottom - R.Top),
    Types.Point(R.Left + VisibleFixedWidth, R.Top), RTLOffset);

  // In case of right-to-left directionality we paint the fixed part last.
  if RTLOffset <> 0 then
    PaintFixedArea;

  // Blit the result to target.
  with TWithSafeRect(R) do
    BitBlt(DC, Left, Top, Right - Left, Bottom - Top, FHeaderBitmap.Canvas.Handle, Left, Top, SRCCOPY);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.PaintHeader(TargetCanvas: TCanvas; R: TRect; const Target: TPoint;
  RTLOffset: Integer = 0);

// Main paint method to draw the header.
// This procedure will paint the a slice (given in R) out of HeaderRect into TargetCanvas starting at position Target.
// This function does not offer the option to visually move floating columns due to scrolling. To accomplish this you
// need to call this method twice.

const
  SortGlyphs: array[TSortDirection, Boolean] of Integer = ( // ascending/descending, normal/XP style
    (3, 5) {ascending}, (2, 4) {descending}
  );

var
  Run: TColumnIndex;
  RightBorderFlag,
  NormalButtonStyle,
  NormalButtonFlags,
  PressedButtonStyle,
  PressedButtonFlags,
  RaisedButtonStyle,
  RaisedButtonFlags: Cardinal;
  Images: TCustomImageList;
  OwnerDraw,
  AdvancedOwnerDraw: Boolean;
  PaintInfo: THeaderPaintInfo;
  RequestedElements,
  ActualElements: THeaderPaintElements;
  {$IF LCL_FullVersion >= 2000000}
  ImagesRes: TScaledImageListResolution;
  {$IFEND}

  //--------------- local functions -------------------------------------------

  procedure PrepareButtonStyles;

  // Prepare the button styles and flags for later usage.

  begin
    RaisedButtonStyle := 0;
    RaisedButtonFlags := 0;
    case FHeader.Style of
      hsThickButtons:
        begin
          NormalButtonStyle := BDR_RAISEDINNER or BDR_RAISEDOUTER;
          NormalButtonFlags := BF_LEFT or BF_TOP or BF_BOTTOM or BF_MIDDLE or BF_SOFT or BF_ADJUST;
          PressedButtonStyle := BDR_RAISEDINNER or BDR_RAISEDOUTER;
          PressedButtonFlags := NormalButtonFlags or BF_RIGHT or BF_FLAT or BF_ADJUST;
        end;
      hsFlatButtons:
        begin
          NormalButtonStyle := BDR_RAISEDINNER;
          NormalButtonFlags := BF_LEFT or BF_TOP or BF_BOTTOM or BF_MIDDLE or BF_ADJUST;
          PressedButtonStyle := BDR_SUNKENOUTER;
          PressedButtonFlags := BF_RECT or BF_MIDDLE or BF_ADJUST;
        end;
    else
      // hsPlates or hsXPStyle, values are not used in the latter case
      begin
        NormalButtonStyle := BDR_RAISEDINNER;
        NormalButtonFlags := BF_RECT or BF_MIDDLE or BF_SOFT or BF_ADJUST;
        PressedButtonStyle := BDR_SUNKENOUTER;
        PressedButtonFlags := BF_RECT or BF_MIDDLE or BF_ADJUST;
        RaisedButtonStyle := BDR_RAISEDINNER;
        RaisedButtonFlags := BF_LEFT or BF_TOP or BF_BOTTOM or BF_MIDDLE or BF_ADJUST;
      end;
    end;
  end;

  //---------------------------------------------------------------------------

  procedure DrawBackground;

  // Draw the header background.

  var
    BackgroundRect: TRect;
    Details: TThemedElementDetails;

  begin
    BackgroundRect := Types.Rect(Target.X, Target.Y, Target.X + R.Right - R.Left, Target.Y + FHeader.Height);

    with TargetCanvas do
      begin
      if hpeBackground in RequestedElements then
      begin
        PaintInfo.PaintRectangle := BackgroundRect;
        FHeader.Tree.DoAdvancedHeaderDraw(PaintInfo, [hpeBackground]);
      end
      else
      begin
        if tsUseThemes in FHeader.Tree.TreeStates then
        begin
          Details := StyleServices.GetElementDetails(thHeaderItemRightNormal);
          StyleServices.DrawElement(Handle, Details, BackgroundRect, @BackgroundRect);
        end
        else
        begin
          Brush.Color := FHeader.FBackground;
          FillRect(BackgroundRect);
        end;
      end;
    end;
  end;

  //---------------------------------------------------------------------------

  procedure PaintColumnHeader(AColumn: TColumnIndex; ATargetRect: TRect);

  // Draw a single column to TargetRect. The clipping rect needs to be set before
  // this procedure is called.

  var
    Y: Integer;
    SavedDC: Integer;
    ColCaptionText: UnicodeString;
    ColImageInfo: TVTImageInfo;
    SortIndex: Integer;
    SortGlyphSize: TSize;
    Glyph: TThemedHeader;
    Details: TThemedElementDetails;
    WrapCaption: Boolean;
    DrawFormat: Cardinal;
    Pos: TRect;
    DrawHot: Boolean;
    ImageWidth: Integer;
    w, h: Integer;
    Rsrc, Rdest: TRect;
  begin
    ColImageInfo.Ghosted := False;
    PaintInfo.Column := Items[AColumn];
    with PaintInfo, Column do
    begin
      //lclheader
      //Under Delphi/VCL, unlike LCL, the hover index is not changed while dragging.
      //Here we check if dragging and not draw as hover
      IsHoverIndex := (AColumn = FHoverIndex) and (hoHotTrack in FHeader.FOptions) and
        (coEnabled in FOptions) and not (hsDragging in FHeader.States);
      IsDownIndex := (AColumn = FDownIndex) and not FCheckBoxHit;

      if (coShowDropMark in FOptions) and (AColumn = FDropTarget) and (AColumn <> FDragIndex) then
      begin
        if FDropBefore then
          DropMark := dmmLeft
        else
          DropMark := dmmRight;
      end
      else
        DropMark := dmmNone;

      IsEnabled := (coEnabled in FOptions) and (FHeader.Tree.Enabled);
      ShowHeaderGlyph := (hoShowImages in FHeader.FOptions) and ((Assigned(Images) and (FImageIndex > -1)) or FCheckBox);
      ShowSortGlyph := (AColumn = FHeader.FSortColumn) and (hoShowSortGlyphs in FHeader.FOptions);
      WrapCaption := coWrapCaption in FOptions;

      PaintRectangle := ATargetRect;

      // This path for text columns or advanced owner draw.
      if (Style = vsText) or not OwnerDraw or AdvancedOwnerDraw then
      begin
        // See if the application wants to draw part of the header itself.
        RequestedElements := [];
        if AdvancedOwnerDraw then
        begin
          PaintInfo.Column := Items[AColumn];
          FHeader.Tree.DoHeaderDrawQueryElements(PaintInfo, RequestedElements);
        end;

        if ShowRightBorder or (AColumn < Count - 1) then
          RightBorderFlag := BF_RIGHT
        else
          RightBorderFlag := 0;

        if hpeBackground in RequestedElements then
          FHeader.Tree.DoAdvancedHeaderDraw(PaintInfo, [hpeBackground])
        else
        begin
          if tsUseThemes in FHeader.Tree.TreeStates then
          begin
            if IsDownIndex then
              Details := StyleServices.GetElementDetails(thHeaderItemPressed)
            else
              if IsHoverIndex then
                Details := StyleServices.GetElementDetails(thHeaderItemHot)
              else
                Details := StyleServices.GetElementDetails(thHeaderItemNormal);
            StyleServices.DrawElement(TargetCanvas.Handle, Details, PaintRectangle, @PaintRectangle);
          end
          else
          begin
            if IsDownIndex then
              DrawEdge(TargetCanvas.Handle, PaintRectangle, PressedButtonStyle, PressedButtonFlags)
            else
              // Plates have the special case of raising on mouse over.
              if (FHeader.Style = hsPlates) and IsHoverIndex and
                (coAllowClick in FOptions) and (coEnabled in FOptions) then
                DrawEdge(TargetCanvas.Handle, PaintRectangle, RaisedButtonStyle,
                         RaisedButtonFlags or RightBorderFlag)
              else
                DrawEdge(TargetCanvas.Handle, PaintRectangle, NormalButtonStyle,
                         NormalButtonFlags or RightBorderFlag);
          end;
        end;

        PaintRectangle := ATargetRect;

        // calculate text and glyph position
        InflateRect(PaintRectangle, -2, -2);
        DrawFormat := DT_TOP or DT_NOPREFIX;
        case CaptionAlignment of
          taLeftJustify  : DrawFormat := DrawFormat or DT_LEFT;
          taRightJustify : DrawFormat := DrawFormat or DT_RIGHT;
          taCenter       : DrawFormat := DrawFormat or DT_CENTER;
        end;
        if UseRightToLeftReading then
          DrawFormat := DrawFormat + DT_RTLREADING;
        ComputeHeaderLayout(TargetCanvas.Handle, PaintRectangle, ShowHeaderGlyph, ShowSortGlyph, GlyphPos,
          SortGlyphPos, SortGlyphSize, TextRectangle, DrawFormat);

        // Move glyph and text one pixel to the right and down to simulate a pressed button.
        if IsDownIndex then
        begin
          OffsetRect(TextRectangle, 1, 1);
          Inc(GlyphPos.X);
          Inc(GlyphPos.Y);
          Inc(SortGlyphPos.X);
          Inc(SortGlyphPos.Y);
        end;

        // Advanced owner draw allows to paint elements, which would normally not be painted (because of space
        // limitations, empty captions etc.).
        ActualElements := RequestedElements * [hpeHeaderGlyph, hpeSortGlyph, hpeDropMark, hpeText];

        // main glyph
        FHasImage := False;
        if Assigned(Images) then
        {$IF LCL_FullVersion >= 2000000}
        ImageWidth := ImagesRes.Width
        {$ELSE}
        ImageWidth := Images.Width
        {$IFEND}
        else
          ImageWidth := 0;

        if not (hpeHeaderGlyph in ActualElements) and ShowHeaderGlyph and
          (not ShowSortGlyph or (FBiDiMode <> bdLeftToRight) or (GlyphPos.X + ImageWidth <= SortGlyphPos.X) ) then
        begin
          if not FCheckBox then
          begin
            ColImageInfo.Images := Images;
            {$IF LCL_FullVersion >= 2000000}
            ImagesRes.Draw(TargetCanvas, GlyphPos.X, GlyphPos.Y, FImageIndex, IsEnabled);
            w := ImagesRes.Width;
            h := ImagesRes.Height;
            {$ELSE}
            Images.Draw(TargetCanvas, GlyphPos.X, GlyphPos.Y, FImageIndex, IsEnabled);
            w := Images.Width;
            h := Images.Height;
            {$IFEND}
          end
          else
          begin
            with Header.Tree do
            begin
              ColImageInfo.Images := GetCheckImageListFor(CheckImageKind);
              ColImageInfo.Index := GetCheckImage(nil, FCheckType, FCheckState, IsEnabled);
              ColImageInfo.XPos := GlyphPos.X;
              ColImageInfo.YPos := GlyphPos.Y;
              if ColImageInfo.Images <> nil then begin
              w := ColImageInfo.Images.Width;
              h := ColImageInfo.Images.Height;
              end else begin
                w := 0;
                h := 0;
              end;
              PaintCheckImage(TargetCanvas, ColImageInfo, False);
            end;
          end;

          FHasImage := True;
          with TWithSafeRect(FImageRect) do
          begin
            Left := GlyphPos.X;
            Top := GlyphPos.Y;
            Right := Left + w;
            Bottom := Top + h;
          end;
        end;

        // caption
        if WrapCaption then
          ColCaptionText := FCaptionText
        else
          ColCaptionText := Text;
          if IsHoverIndex and FHeader.Tree.VclStyleEnabled then
            DrawHot := True
          else
            DrawHot := (IsHoverIndex and (hoHotTrack in FHeader.FOptions) and not(tsUseThemes in FHeader.Tree.TreeStates));
          if not(hpeText in ActualElements) and (Length(Text) > 0) then
            DrawButtonText(TargetCanvas.Handle, ColCaptionText, TextRectangle, IsEnabled, DrawHot, DrawFormat, WrapCaption);

        // sort glyph
        if not (hpeSortGlyph in ActualElements) and ShowSortGlyph then
        begin
          Rsrc := Types.Rect(0, 0, UtilityImageSize-1, UtilityImageSize-1);
          Rdest := Rsrc;
          if tsUseExplorerTheme in FHeader.Tree.TreeStates then
          begin
            Pos.TopLeft := SortGlyphPos;
            Pos.Right := Pos.Left + SortGlyphSize.cx;
            Pos.Bottom := Pos.Top + SortGlyphSize.cy;
            if FHeader.FSortDirection = sdAscending then
              Glyph := thHeaderSortArrowSortedUp
            else
              Glyph := thHeaderSortArrowSortedDown;
            Details := StyleServices.GetElementDetails(Glyph);
            StyleServices.DrawElement(TargetCanvas.Handle, Details, Pos, @Pos);
          end
          else
          begin
            SortIndex := SortGlyphs[FHeader.FSortDirection, tsUseThemes in FHeader.Tree.TreeStates];
            OffsetRect(Rsrc, SortIndex * UtilityImageSize, 0);
            OffsetRect(Rdest, SortGlyphPos.x, SortGlyphPos.y);
            FHeaderBitmap.Canvas.CopyRect(Rdest, UtilityImages.Canvas, Rsrc);          end;
        end;

        // Show an indication if this column is the current drop target in a header drag operation.
        if not (hpeDropMark in ActualElements) and (DropMark <> dmmNone) then
        begin
          Rsrc := Types.Rect(0, 0, UtilityImageSize-1, UtilityImageSize-1);
          Rdest := Rsrc;
          Y := (PaintRectangle.Top + PaintRectangle.Bottom - UtilityImages.Height) div 2;
          if DropMark = dmmLeft then begin
            OffsetRect(Rdest, PaintRectangle.Left, Y);
            FHeaderBitmap.Canvas.CopyRect(Rdest, UtilityImages.Canvas, Rsrc);
          end else begin
            OffsetRect(Rdest, PaintRectangle.Right - UtilityImageSize, Y);
            OffsetRect(Rsrc, UtilityImageSize, 0);
            FHeaderBitmap.Canvas.CopyRect(Rdest, UtilityImages.Canvas, Rsrc);
          end;
        end;

        if ActualElements <> [] then
        begin
          SavedDC := SaveDC(TargetCanvas.Handle);
          FHeader.Tree.DoAdvancedHeaderDraw(PaintInfo, ActualElements);
          RestoreDC(TargetCanvas.Handle, SavedDC);
        end;
      end
      else // Let application draw the header.
        FHeader.Tree.DoHeaderDraw(TargetCanvas, Items[AColumn], PaintRectangle, IsHoverIndex, IsDownIndex,
          DropMark);
    end;
  end;

  //--------------- end local functions ---------------------------------------

var
  TargetRect: TRect;
  MaxX: Integer;

begin
  if IsRectEmpty(R) then
    Exit;

  // If both draw posibillities are specified then prefer the advanced way.
  AdvancedOwnerDraw := (hoOwnerDraw in FHeader.FOptions) and Assigned(FHeader.Tree.OnAdvancedHeaderDraw) and
    Assigned(FHeader.Tree.OnHeaderDrawQueryElements) and not (csDesigning in FHeader.Tree.ComponentState);
  OwnerDraw := (hoOwnerDraw in FHeader.FOptions) and Assigned(FHeader.Tree.OnHeaderDraw) and
    not (csDesigning in FHeader.Tree.ComponentState) and not AdvancedOwnerDraw;

  FillChar(PaintInfo, SizeOf(PaintInfo), #0);
  PaintInfo.TargetCanvas := TargetCanvas;

  with PaintInfo, TargetCanvas do
  begin
    // Use shortcuts for the images and the font.
    Images := FHeader.FImages;
    Font := FHeader.FFont;
    if Font.Color = clDefault then
      Font.Color := FHeader.Tree.GetDefaultColor(dctFont);

    {$IF LCL_FullVersion >= 2000000}
    if Images <> nil then
      ImagesRes := Images.ResolutionForPPI[FHeader.ImagesWidth, Font.PixelsPerInch, Header.Tree.GetCanvasScaleFactor];
    {$IFEND}

    PrepareButtonStyles;

    // At first, query the application which parts of the header it wants to draw on its own.
    RequestedElements := [];
    if AdvancedOwnerDraw then
    begin
      PaintRectangle := R;
      Column := nil;
      FHeader.Tree.DoHeaderDrawQueryElements(PaintInfo, RequestedElements);
    end;

    // Draw the background.
    DrawBackground;

    // Now that we have drawn the background, we apply the header's dimensions to R.
    R := Types.Rect(Max(R.Left, 0), Max(R.Top, 0), Min(R.Right, TotalWidth), Min(R.Bottom, Header.Height));

    // Determine where to stop.
    MaxX := Target.X + R.Right - R.Left;

    // Determine the start column.
    Run := ColumnFromPosition(Types.Point(R.Left + RTLOffset, 0), False);
    if Run <= NoColumn then
      Exit;

    TargetRect.Top := Target.Y;
    TargetRect.Bottom := Target.Y + R.Bottom - R.Top;
    TargetRect.Left := Target.X - R.Left + Items[Run].FLeft + RTLOffset;
    // TargetRect.Right will be set in the loop

    ShowRightBorder := (FHeader.Style = hsThickButtons) or not (hoAutoResize in FHeader.FOptions);

    // Now go for each button.
    while (Run > NoColumn) and (TargetRect.Left < MaxX) do
    begin
      TargetRect.Right := TargetRect.Left + Items[Run].FWidth;

      // create a clipping rect to limit painting to button area
      ClipCanvas(TargetCanvas, Types.Rect(Max(TargetRect.Left, Target.X), Target.Y + R.Top,
                                          Min(TargetRect.Right, MaxX), TargetRect.Bottom));

      PaintColumnHeader(Run, TargetRect);

      SelectClipRgn(Handle, 0);

      TargetRect.Left := TargetRect.Right;
      Run := GetNextVisibleColumn(Run);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVirtualTreeColumns.SaveToStream(const Stream: TStream);

var
  I: Integer;

begin
  I := Count;
  Stream.WriteBuffer(I, SizeOf(I));
  if I > 0 then
  begin
    for I := 0 to Count - 1 do
      TVirtualTreeColumn(Items[I]).SaveToStream(Stream);

    Stream.WriteBuffer(FPositionToIndex[0], Count * SizeOf(TColumnIndex));
  end;

  // Data introduced with header stream version 5.
  Stream.WriteBuffer(DefaultWidth, SizeOf(DefaultWidth));
end;

//----------------------------------------------------------------------------------------------------------------------

function TVirtualTreeColumns.TotalWidth: Integer;

var
  LastColumn: TColumnIndex;

begin
  Result := 0;
  if (Count > 0) and (Length(FPositionToIndex) > 0) then
  begin
    LastColumn := FPositionToIndex[Count - 1];
    if not (coVisible in Items[LastColumn].FOptions) then
      LastColumn := GetPreviousVisibleColumn(LastColumn);
    if LastColumn > NoColumn then
      with Items[LastColumn] do
        Result := FLeft + FWidth;
  end;
end;

{ TVirtualTreeColumnHelper }

function TVirtualTreeColumnHelper.Header : TVTHeader;
begin
  Result := Owner.Header;
end;

function TVirtualTreeColumnHelper.TreeViewControl : TBaseVirtualTreeCracker;
begin
  Result := TBaseVirtualTreeCracker(Owner.Header.GetOwner);
end;

{ TVirtualTreeColumnsHelper }

function TVirtualTreeColumnsHelper.TreeViewControl : TBaseVirtualTreeCracker;
begin
  Result := TBaseVirtualTreeCracker(Header.GetOwner);
end;

end.

