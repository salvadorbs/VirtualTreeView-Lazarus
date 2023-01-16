unit VirtualTrees.DragnDrop;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, Controls, Graphics, LCLType,
  {$ifdef Windows}
  Windows,
  ActiveX,
  {$else}
  FakeActiveX,
  {$endif}
  DelphiCompat
  , VirtualTrees.Types
  , VirtualTrees.BaseTree
  , virtualdragmanager;

type
  TEnumFormatEtc = class(TInterfacedObject, IEnumFormatEtc)
  private
    FFormatEtcArray : TFormatEtcArray;
    FCurrentIndex   : Integer;
  public
    constructor Create(const AFormatEtcArray : TFormatEtcArray);

    function Clone(out Enum : IEnumFormatEtc) : HResult; stdcall;
    function Next(celt : LongWord; out elt: FormatEtc; pceltFetched : pULong=nil) : HResult; stdcall;
    function Reset : HResult; stdcall;
    function Skip(celt : LongWord) : HResult; stdcall;
  end;

  // ----- OLE drag'n drop handling

  IVTDragManager = interface(IUnknown)
    ['{C4B25559-14DA-446B-8901-0C879000EB16}']
    procedure ForceDragLeave; stdcall;
    function GetDataObject: IDataObject; stdcall;
    function GetDragSource: TBaseVirtualTree; stdcall;
    function GetDropTargetHelperSupported: Boolean; stdcall;
    function GetIsDropTarget: Boolean; stdcall;

    property DataObject: IDataObject read GetDataObject;
    property DragSource: TBaseVirtualTree read GetDragSource;
    property DropTargetHelperSupported: Boolean read GetDropTargetHelperSupported;
    property IsDropTarget: Boolean read GetIsDropTarget;
  end;

  IDropTargetHelper = interface(IUnknown)
    [SID_IDropTargetHelper]
    function DragEnter(hwndTarget: HWND; pDataObject: IDataObject; var ppt: TPoint; dwEffect: LongWord): HRESULT; stdcall;
    function DragLeave: HRESULT; stdcall;
    function DragOver(var ppt: TPoint; dwEffect: LongWord): HRESULT; stdcall;
    function Drop(pDataObject: IDataObject; var ppt: TPoint; dwEffect: LongWord): HRESULT; stdcall;
    function Show(fShow: Boolean): HRESULT; stdcall;
  end;

  // TVTDragManager is a class to manage drag and drop in a Virtual Treeview.
  TVTDragManager = class(TInterfacedObject, IVTDragManager, IDropSource, IDropTarget)
  private
    FOwner,                                // The tree which is responsible for drag management.
    FDragSource       : TBaseVirtualTree;  // Reference to the source tree if the source was a VT, might be different than the owner tree.
    FHeader           : TVTHeader;
    FIsDropTarget     : Boolean;           // True if the owner is currently the drop target.
    FDataObject       : IDataObject;       // A reference to the data object passed in by DragEnter (only used when the owner tree is the current drop target).
    FDropTargetHelper : IDropTargetHelper; // Win2k > Drag image support
    FFullDragging     : BOOL;              // True, if full dragging is currently enabled in the system.

    function GetDataObject : IDataObject; stdcall;
    function GetDragSource : TBaseVirtualTree; stdcall;
    function GetDropTargetHelperSupported: Boolean; stdcall;
    function GetIsDropTarget : Boolean; stdcall;
  public
    constructor Create(AOwner : TBaseVirtualTree); virtual;
    destructor Destroy; override;

    function DragEnter(const DataObject : IDataObject; KeyState : LongWord; Pt : TPoint; var Effect : LongWord) : HResult; stdcall;
    function DragLeave : HResult; stdcall;
    function DragOver(KeyState : LongWord; Pt : TPoint; var Effect : LongWord) : HResult; stdcall;
    function Drop(const DataObject : IDataObject; KeyState : LongWord; Pt : TPoint; var Effect : LongWord) : HResult; stdcall;
    procedure ForceDragLeave; stdcall;
    {$IF (FPC_FULLVERSION < 020601) and DEFINED(LCLWin32)}
    function GiveFeedback(Effect: Longint): HResult; stdcall;
    function QueryContinueDrag(EscapePressed: BOOL; KeyState: Longint): HResult; stdcall;
    {$ELSE}
    function GiveFeedback(Effect: LongWord): HResult; stdcall;
    function QueryContinueDrag(EscapePressed: BOOL; KeyState: LongWord): HResult; stdcall;
    {$ENDIF}
    class function GetTreeFromDataObject(const DataObject: TVTDragDataObject): TBaseVirtualTree;
  end;

var
  StandardOLEFormat : TFormatEtc = (
    // Format must later be set.
    cfFormat : 0;
    // No specific target device to render on.
    ptd : nil;
    // Normal content to render.
    dwAspect : DVASPECT_CONTENT;
    // No specific page of multipage data (we don't use multipage data by default).
    lindex : - 1;
    // Acceptable storage formats are IStream and global memory. The first is preferred.
    tymed : TYMED_ISTREAM or TYMED_HGLOBAL;
  );

implementation

uses
  VirtualTrees.Clipboard,
  VirtualTrees.DataObject;

type
  TBaseVirtualTreeCracker = class(TBaseVirtualTree);

  TVTDragManagerHelper = class helper for TVTDragManager
    function TreeView : TBaseVirtualTreeCracker;
  end;


  //----------------- TEnumFormatEtc -------------------------------------------------------------------------------------

constructor TEnumFormatEtc.Create(const AFormatEtcArray : TFormatEtcArray);
var
  I : Integer;
begin
  inherited Create;

  {$IFDEF EnableWinDataObject}
  // Make a local copy of the format data.
  SetLength(FFormatEtcArray, Length(AFormatEtcArray));
  for I := 0 to High(AFormatEtcArray) do
    FFormatEtcArray[I] := AFormatEtcArray[I];
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Clone(out Enum : IEnumFormatEtc) : HResult;
{$IFDEF EnableWinDataObject}
var
  AClone : TEnumFormatEtc;
{$ENDIF}
begin
  {$IFDEF EnableWinDataObject}
  Result := S_OK;
  try
    AClone := TEnumFormatEtc.Create(FFormatEtcArray);
    AClone.FCurrentIndex := FCurrentIndex;
    Enum := AClone as IEnumFormatEtc;
  except
    Result := E_FAIL;
  end;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Next(celt : LongWord; out elt: FormatEtc; pceltFetched : pULong=nil) : HResult;
{$IFDEF EnableWinDataObject}
var
  CopyCount : Integer;
{$ENDIF}
begin
  {$IFDEF EnableWinDataObject}
  Result := S_FALSE;
  CopyCount := Length(FFormatEtcArray) - FCurrentIndex;
  if celt < CopyCount then
    CopyCount := celt;
  if CopyCount > 0 then
  begin
    Move(FFormatEtcArray[FCurrentIndex], {%H-}elt, CopyCount * SizeOf(TFormatEtc));
    Inc(FCurrentIndex, CopyCount);
    Result := S_OK;
  end;
  if Assigned(pceltFetched) then
    pceltFetched^ := CopyCount;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Reset : HResult;
begin
  {$IFDEF EnableWinDataObject}
  FCurrentIndex := 0;
  Result := S_OK;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Skip(celt : LongWord) : HResult;
begin
  {$IFDEF EnableWinDataObject}
  if FCurrentIndex + celt < High(FFormatEtcArray) then
  begin
    Inc(FCurrentIndex, celt);
    Result := S_OK;
  end
  else
    Result := S_FALSE;
  {$ENDIF}
end;


//----------------------------------------------------------------------------------------------------------------------

// OLE drag and drop support classes
// This is quite heavy stuff (compared with the VCL implementation) but is much better suited to fit the needs
// of DD'ing various kinds of virtual data and works also between applications.


//----------------- TVTDragManager -------------------------------------------------------------------------------------

constructor TVTDragManager.Create(AOwner : TBaseVirtualTree);
begin
  inherited Create;
  FOwner := AOwner;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TVTDragManager.Destroy;
begin
  // Set the owner's reference to us to nil otherwise it will access an invalid pointer
  // after our desctruction is complete.
  TreeView.ClearDragManager;
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GetDataObject : IDataObject;
begin
  // When the owner tree starts a drag operation then it gets a data object here to pass it to the OLE subsystem.
  // In this case there is no local reference to a data object and one is created (but not stored).
  // If there is a local reference then the owner tree is currently the drop target and the stored interface is
  // that of the drag initiator.
  {$IFDEF EnableWinDataObject}
  if Assigned(FDataObject) then
    Result := FDataObject
  else
  begin
    Result := TreeView.DoCreateDataObject;
    if (Result = nil) and not Assigned(TreeView.OnCreateDataObject) then
      // Do not create a TVTDataObject if the event handler explicitely decided not to supply one, issue #736.
      Result := TVTDataObject.Create(FOwner, False) as IDataObject;
  end;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GetDragSource : TBaseVirtualTree;
begin
  {$IFDEF EnableWinDataObject}
  Result := FDragSource;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GetDropTargetHelperSupported: Boolean; stdcall;

begin
  {$IFDEF EnableWinDataObject}
  Result := Assigned(FDropTargetHelper);
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GetIsDropTarget : Boolean;
begin
  Result := True;
  {$IFDEF EnableWinDataObject}
  Result := FIsDropTarget;
  {$ENDIF}
end;

class function TVTDragManager.GetTreeFromDataObject(const DataObject: TVTDragDataObject): TBaseVirtualTree;
// Returns the owner/sender of the given data object by means of a special clipboard format
// or nil if the sender is in another process or no virtual tree at all.

var
  Medium: TStgMedium;
  Data: PVTReference;

begin
  Result := nil;
  if Assigned(DataObject) then
  begin
    StandardOLEFormat.cfFormat := CF_VTREFERENCE;
    if DataObject.GetData(StandardOLEFormat, Medium) = S_OK then
    begin
      Data := GlobalLock(Medium.hGlobal);
      if Assigned(Data) then
      begin
        if Data.Process = GetCurrentProcessID then
          Result := Data.Tree;
        GlobalUnlock(Medium.hGlobal);
      end;
      ReleaseStgMedium(Medium);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.DragEnter(const DataObject : IDataObject; KeyState : LongWord; Pt : TPoint; var Effect : LongWord) : HResult;
var
  Medium: TStgMedium;
  HeaderFormatEtc: TFormatEtc;
begin
  if not Assigned(FDropTargetHelper) then
    CoCreateInstance(CLSID_DragDropHelper, nil, CLSCTX_INPROC_SERVER, IID_IDropTargetHelper, FDropTargetHelper);

  {$IFDEF EnableWinDataObject}
  FDataObject := DataObject;
  FIsDropTarget := True;

  SystemParametersInfo(SPI_GETDRAGFULLWINDOWS, 0, @FFullDragging, 0);
  // If full dragging of window contents is disabled in the system then our tree windows will be locked
  // and cannot be updated during a drag operation. With the following call painting is again enabled.
  if not FFullDragging then
    LockWindowUpdate(0);
  if Assigned(FDropTargetHelper) and FFullDragging then
  begin
    if toAutoScroll in TreeView.TreeOptions.AutoOptions then
      FDropTargetHelper.DragEnter(FOwner.Handle, DataObject, Pt, Effect)
    else
      FDropTargetHelper.DragEnter(0, DataObject, Pt, Effect); // Do not pass handle, otherwise the IDropTargetHelper will perform autoscroll. Issue #486
  end;
  FDragSource := GetTreeFromDataObject(DataObject);
  Result := TreeView.DragEnter(KeyState, Pt, Effect);
  HeaderFormatEtc := StandardOLEFormat;
  HeaderFormatEtc.cfFormat := CF_VTHEADERREFERENCE;
  if (DataObject.GetData(HeaderFormatEtc, Medium) = S_OK) and (FDragSource = FOWner) then
  begin
    FHeader := FDragSource.Header;
    FDRagSource := nil;
  end
  else
  begin
    fHeader := nil;
  end;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.DragLeave : HResult;
begin
  {$IFDEF EnableWinDataObject}
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.DragLeave;

  TreeView.DragLeave;
  FIsDropTarget := False;
  FDragSource := nil;
  FDataObject := nil;
  fHeader := nil;
  Result := NOERROR;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.DragOver(KeyState : LongWord; Pt : TPoint; var Effect : LongWord) : HResult;
begin
  {$IFDEF EnableWinDataObject}
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.DragOver(Pt, Effect);

  if Assigned(fHeader) then
  begin
    TreeView.Header.DragTo(Pt);
    Result := NOERROR;
  end
  else
    Result := TreeView.DragOver(FDragSource, KeyState, dsDragMove, Pt, Effect);
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.Drop(const DataObject : IDataObject; KeyState : LongWord; Pt : TPoint; var Effect : LongWord) : HResult;
begin
  {$IFDEF EnableWinDataObject}
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.Drop(DataObject, Pt, Effect);

  if Assigned(fHeader) then
  begin
   FHeader.ColumnDropped(Pt);
   Result := NO_ERROR;
  end
  else
    Result := TreeView.DragDrop(DataObject, KeyState, Pt, Effect);
  FIsDropTarget := False;
  FDataObject := nil;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragManager.ForceDragLeave;
// Some drop targets, e.g. Internet Explorer leave a drag image on screen instead removing it when they receive
// a drop action. This method calls the drop target helper's DragLeave method to ensure it removes the drag image from
// screen. Unfortunately, sometimes not even this does help (e.g. when dragging text from VT to a text field in IE).
begin
  {$IFDEF EnableWinDataObject}
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.DragLeave;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GiveFeedback(Effect : LongWord) : HResult;
begin
  {$IFDEF EnableWinDataObject}
  Result := DRAGDROP_S_USEDEFAULTCURSORS;
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.QueryContinueDrag(EscapePressed : BOOL; KeyState : LongWord) : HResult;
var
  RButton, LButton : Boolean;
begin
  {$IFDEF EnableWinDataObject}
  LButton := (KeyState and MK_LBUTTON) <> 0;
  RButton := (KeyState and MK_RBUTTON) <> 0;

  // Drag'n drop canceled by pressing both mouse buttons or Esc?
  if (LButton and RButton) or EscapePressed then
    Result := DRAGDROP_S_CANCEL
  else
    // Drag'n drop finished?
    if not (LButton or RButton) then
      Result := DRAGDROP_S_DROP
    else
      Result := S_OK;
  {$ENDIF}
end;

{ TVTDragManagerHelper }

function TVTDragManagerHelper.TreeView : TBaseVirtualTreeCracker;
begin
  Result := TBaseVirtualTreeCracker(FOwner);
end;

end.
