unit virtualdragmanager;

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
  , VirtualTrees.Types;

const
  SID_IDropTargetHelper = '{4657278B-411B-11D2-839A-00C04FD918D0}';
  SID_IDragSourceHelper = '{DE5BF786-477A-11D2-839D-00C04FD918D0}';
  SID_IDragSourceHelper2 = '{83E07D0D-0C5F-4163-BF1A-60B274051E40}';
  SID_IDropTarget = '{00000122-0000-0000-C000-000000000046}';
  
  //Bridge to ActiveX constants
  
  TYMED_HGLOBAL = ActiveX.TYMED_HGLOBAL;
  TYMED_ISTREAM = ActiveX.TYMED_ISTREAM;
  DVASPECT_CONTENT = ActiveX.DVASPECT_CONTENT;
  CLSCTX_INPROC_SERVER = ActiveX.CLSCTX_INPROC_SERVER;
  DROPEFFECT_COPY = ActiveX.DROPEFFECT_COPY;
  DROPEFFECT_LINK = ActiveX.DROPEFFECT_LINK;
  DROPEFFECT_MOVE = ActiveX.DROPEFFECT_MOVE;
  DROPEFFECT_NONE = ActiveX.DROPEFFECT_NONE;
  DROPEFFECT_SCROLL = ActiveX.DROPEFFECT_SCROLL;
  DATADIR_GET = ActiveX.DATADIR_GET;
  
type
  //Bridge to ActiveX Types
  IDataObject = ActiveX.IDataObject;
  IDropTarget = ActiveX.IDropTarget;
  IDropSource = ActiveX.IDropSource;
  IEnumFormatEtc = ActiveX.IEnumFORMATETC;
  
  //WINOLEAPI = ActiveX.WINOLEAPI;
  
  TFormatEtc = ActiveX.TFORMATETC;
  TStgMedium = ActiveX.TStgMedium;
  PDVTargetDevice = ActiveX.PDVTARGETDEVICE;

  // IDataObject.SetData support
  TInternalStgMedium = packed record
    Format: TClipFormat;
    Medium: TStgMedium;
  end;
  TInternalStgMediumArray = array of TInternalStgMedium;

  PSHDragImage = ^TSHDragImage;
  TSHDragImage = packed record
    sizeDragImage: TSize;
    ptOffset: TPoint;
    hbmpDragImage: HBITMAP;
    crColorKey: TColorRef;
  end;

  IDragSourceHelper = interface(IUnknown)
    [SID_IDragSourceHelper]
    function InitializeFromBitmap(SHDragImage: PSHDragImage; pDataObject: IDataObject): HRESULT; stdcall;
    function InitializeFromWindow(Window: HWND; var ppt: TPoint; pDataObject: IDataObject): HRESULT; stdcall;
  end;
  {$EXTERNALSYM IDragSourceHelper}

  IDragSourceHelper2 = interface(IDragSourceHelper)
  [SID_IDragSourceHelper2]
    function SetFlags(dwFlags: DWORD): HRESULT; stdcall;
  end;
  {$EXTERNALSYM IDragSourceHelper2}
  
  //Ole helper functions

  function Succeeded(Status : HRESULT) : BOOLEAN;

  function Failed(Status : HRESULT) : BOOLEAN;
  
  //ActiveX functions that have wrong calling convention in fpc
  
  function RegisterDragDrop(hwnd:HWND; pDropTarget:IDropTarget):WINOLEAPI;stdcall;external 'ole32.dll' name 'RegisterDragDrop';

  function RevokeDragDrop(hwnd:HWND):WINOLEAPI;stdcall;external 'ole32.dll' name 'RevokeDragDrop';

  function DoDragDrop(pDataObj:IDataObject; pDropSource:IDropSource; dwOKEffects:DWORD; pdwEffect:LPDWORD):WINOLEAPI;stdcall;external 'ole32.dll' name 'DoDragDrop';

  function OleInitialize(pvReserved:LPVOID):WINOLEAPI;stdcall;external 'ole32.dll' name 'OleInitialize';

  procedure OleUninitialize;stdcall;external 'ole32.dll' name 'OleUninitialize';

  procedure ReleaseStgMedium(_para1:LPSTGMEDIUM);stdcall;external 'ole32.dll' name 'ReleaseStgMedium';

  function OleSetClipboard(pDataObj:IDataObject):WINOLEAPI;stdcall;external 'ole32.dll' name 'OleSetClipboard';

  function OleGetClipboard(out ppDataObj:IDataObject):WINOLEAPI;stdcall;external 'ole32.dll' name 'OleGetClipboard';

  function OleFlushClipboard:WINOLEAPI;stdcall;external 'ole32.dll' name 'OleFlushClipboard';

  function OleIsCurrentClipboard(pDataObj:IDataObject):WINOLEAPI;stdcall;external 'ole32.dll' name 'OleIsCurrentClipboard';

  function CreateStreamOnHGlobal(hGlobal:HGLOBAL; fDeleteOnRelease:BOOL;out stm:IStream):WINOLEAPI;stdcall;external 'ole32.dll' name 'CreateStreamOnHGlobal';
  
  function CoCreateInstance(const _para1:TCLSID; _para2:IUnknown; _para3:DWORD;const _para4:TIID;out _para5):HRESULT;stdcall; external  'ole32.dll' name 'CoCreateInstance';

  //helper functions to isolate windows/OLE specific code
  
  function RenderOLEData(Tree: TObject; const FormatEtcIn: TFormatEtc; out Medium: TStgMedium;
    ForClipboard: Boolean): HResult;
    
  function GetStreamFromMedium(Medium:TStgMedium):TStream;
  
  procedure UnlockMediumData(Medium:TStgMedium);
  
  function GetTreeFromDataObject(const DataObject: IDataObject; var Format: TFormatEtc): TObject;
  
  function AllocateGlobal(Data: Pointer; DataSize:Cardinal): HGLOBAL;

implementation

uses
  VirtualTrees.BaseTree, oleutils, VirtualTrees.ClipBoard;
  
type
  TVirtualTreeAccess = class (TBaseVirtualTree)
  end;

function Succeeded(Status : HRESULT) : BOOLEAN;
  begin
     Succeeded:=Status and HRESULT($80000000)=0;
  end;

function Failed(Status : HRESULT) : BOOLEAN;
  begin
     Failed:=Status and HRESULT($80000000)<>0;
  end;


function RenderOLEData(Tree: TObject; const FormatEtcIn: TFormatEtc; out
  Medium: TStgMedium; ForClipboard: Boolean): HResult;

  //--------------- local function --------------------------------------------

  procedure WriteNodes(Stream: TStream);

  var
    Selection: TNodeArray;
    I: Integer;

  begin
    with TVirtualTreeAccess(Tree) do
    begin
      if ForClipboard then
        Selection := GetSortedCutCopySet(True)
      else
        Selection := GetSortedSelection(True);
      for I := 0 to High(Selection) do
        WriteNode(Stream, Selection[I]);
    end;
  end;

  //--------------- end local function ----------------------------------------

var
  Data: PCardinal;
  ResPointer: Pointer;
  ResSize: Integer;
  OLEStream: IStream;
  VCLStream: TStream;
  
begin
  VCLStream := nil;
  try
    Medium.PunkForRelease := nil;
    // Return data in one of the supported storage formats, prefer IStream.
    if FormatEtcIn.tymed and TYMED_ISTREAM <> 0 then
    begin
      // Create an IStream on a memory handle (here it is 0 which indicates to implicitely allocated a handle).
      // Do not use TStreamAdapter as it is not compatible with OLE (when flushing the clipboard OLE wants the HGlobal
      // back which is not supported by TStreamAdapater).
      CreateStreamOnHGlobal(0, True, OLEStream);

      VCLStream := TOLEStream.Create(OLEStream);
      WriteNodes(VCLStream);
      // Rewind stream.
      VCLStream.Position := 0;
      Medium.tymed := TYMED_ISTREAM;
      IUnknown(Medium.Pstm) := OLEStream;
      Result := S_OK;
    end
    else
    begin
      VCLStream := TMemoryStream.Create;
      WriteNodes(VCLStream);
      ResPointer := TMemoryStream(VCLStream).Memory;
      ResSize := VCLStream.Position;

      // Allocate memory to hold the string.
      if ResSize > 0 then
      begin
        Medium.hGlobal := GlobalAlloc(GHND or GMEM_SHARE, ResSize + SizeOf(Cardinal));
        Data := GlobalLock(Medium.hGlobal);
        // Store the size of the data too, for easy retrival.
        Data^ := ResSize;
        Inc(Data);
        Move(ResPointer^, Data^, ResSize);
        GlobalUnlock(Medium.hGlobal);
        Medium.tymed := TYMED_HGLOBAL;

        Result := S_OK;
      end
      else
        Result := E_FAIL;
    end;
  finally
    // We can free the VCL stream here since it was either a pure memory stream or only a wrapper around
    // the OLEStream which exists independently.
    VCLStream.Free;
  end;
end;


type
  // needed to handle OLE global memory objects
  TOLEMemoryStream = class(TCustomMemoryStream)
  public
    function Write(const Buffer; Count: Integer): Longint; override;
  end;

//----------------------------------------------------------------------------------------------------------------------

function TOLEMemoryStream.Write(const Buffer; Count: Integer): Integer;

begin
  {$ifdef COMPILER_5_UP}
    raise EStreamError.CreateRes(PResStringRec(@SCantWriteResourceStreamError));
  {$else}
    raise EStreamError.Create(SCantWriteResourceStreamError);
  {$endif COMPILER_5_UP}
end;


function GetStreamFromMedium(Medium: TStgMedium): TStream;
var
  Data: Pointer;
  I: Integer;
begin
  Result := nil;
  if Medium.tymed = TYMED_ISTREAM then
    Result := TOLEStream.Create(IUnknown(Medium.Pstm) as IStream)
  else
  begin
    Data := GlobalLock(Medium.hGlobal);
    if Assigned(Data) then
    begin
      // Get the total size of data to retrieve.
      I := PCardinal(Data)^;
      Inc(PCardinal(Data));
      Result := TOLEMemoryStream.Create;
      TOLEMemoryStream(Result).SetPointer(Data, I);
    end;
  end;
end;

procedure UnlockMediumData(Medium: TStgMedium);
begin
  if Medium.tymed = TYMED_HGLOBAL then
    GlobalUnlock(Medium.hGlobal);
end;

function GetTreeFromDataObject(const DataObject: IDataObject;
  var Format: TFormatEtc): TObject;
  
var
  Medium: TStgMedium;
  Data: PVTReference;
  
begin
  Result := nil;
  if Assigned(DataObject) then
  begin
    Format.cfFormat := CF_VTREFERENCE;
    if DataObject.GetData(Format, Medium) = S_OK then
    begin
      Data := GlobalLock(Medium.hGlobal);
      if Assigned(Data) then
      begin
        if Data.Process = GetCurrentProcessID then
          Result := Data.Tree;
        GlobalUnlock(Medium.hGlobal);
      end;
      ReleaseStgMedium(@Medium);
    end;
  end;
end;

function AllocateGlobal(Data: Pointer; DataSize: Cardinal): HGLOBAL;
var
  P:Pointer;
begin
  Result := GlobalAlloc(GHND or GMEM_SHARE, DataSize);
  P := GlobalLock(Result);
  Move(Data^, P^, DataSize);
  GlobalUnlock(Result);
end;


end.

