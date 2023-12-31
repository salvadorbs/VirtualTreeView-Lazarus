{$warnings off}
{$hints off}

{fake unit just to compile - not used under non windows}

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, SysUtils, Types;

const
  CLSID_DragDropHelper: TGUID = (D1: $4657278A; D2: $411B; D3: $11D2; D4: ($83, $9A, $00, $C0, $4F, $D9, $18, $D0));

  SID_IDropTargetHelper = '{4657278B-411B-11D2-839A-00C04FD918D0}';
  SID_IDragSourceHelper = '{DE5BF786-477A-11D2-839D-00C04FD918D0}';
  SID_IDragSourceHelper2 = '{83E07D0D-0C5F-4163-BF1A-60B274051E40}';
  SID_IDropTarget = '{00000122-0000-0000-C000-000000000046}';
  
  //Bridge to ActiveX constants
  
  TYMED_HGLOBAL = 1;
  TYMED_ISTREAM = 4;
  DVASPECT_CONTENT = 1;
  CLSCTX_INPROC_SERVER = $0010;
  DROPEFFECT_COPY = 1;
  DROPEFFECT_LINK = 4;
  DROPEFFECT_MOVE = 2;
  DROPEFFECT_NONE = 0;
  DROPEFFECT_SCROLL = dword($80000000);
  DATADIR_GET = 1;
  
type
  //types from win unit
  Long = LongInt;
  WinBool= LongBool;
  Bool= WinBool;
  ULONG  = cardinal;
  PULONG = ^ULONG;
  LONGLONG  = int64;
  LPDWORD = ^DWORD;
  LPVOID  = pointer;
       
  TCOLORREF = cardinal;
       
  TIID = TGUID;
  
  LARGE_INTEGER = record
  case byte of
    0: (LowPart : DWORD;
        HighPart : LONG);
    1: (QuadPart : LONGLONG);
  end;
  PLARGE_INTEGER = ^LARGE_INTEGER;
  _LARGE_INTEGER = LARGE_INTEGER;

  TLargeInteger = Int64;
  PLargeInteger = ^TLargeInteger;

  ULARGE_INTEGER = record
  case byte of
    0: (LowPart : DWORD;
        HighPart : DWORD);
    1: (QuadPart : LONGLONG);
  end;
  PULARGE_INTEGER = ^ULARGE_INTEGER;
  _ULARGE_INTEGER = ULARGE_INTEGER;
     
  
  HANDLE = System.THandle;
  HWND = HANDLE;
  //HRESULT = System.HResult;
  
  HBITMAP = HANDLE;
  HENHMETAFILE = HANDLE;
  
  //activex types
  

  IMoniker            = Interface;
   
  WINOLEAPI = HResult;
  TLCID = DWORD;
  
  OleChar             = WChar;
  LPOLESTR            = ^OLECHAR;
  HMetaFilePict       = Pointer;
  
  
  tagBIND_OPTS                 = Record
                                  cvStruct,          //  sizeof(BIND_OPTS)
                                  grfFlags,
                                  grfMode,
                                  dwTickCountDeadline : DWord;
                                 End;
  TBind_Opts                   = tagBIND_OPTS;
  TCLIPFORMAT                  = Word;

  tagDVTARGETDEVICE            = Record
                                    tdSize                     : DWord;
                                    tdDriverNameOffset,
                                    tdDeviceNameOffset,
                                    tdPortNameOffset,
                                    tdExtDevmodeOffset         : Word;
                                    Data                       : Record End;
                                    End;
  DVTARGETDEVICE               = TagDVTARGETDEVICE;
  PDVTARGETDEVICE              = ^tagDVTARGETDEVICE;



  tagFORMATETC                 = Record
                                  CfFormat :  Word {TCLIPFORMAT};
                                  Ptd      : PDVTARGETDEVICE;
                                  dwAspect : DWORD;
                                  lindex   : Long;
                                  tymed    : DWORD;
                                  End;
  FORMATETC                    = TagFORMATETC;
  TFORMATETC                   = FORMATETC;
  LPFORMATETC                  = ^FORMATETC;
  PFormatEtc                   = LPFORMATETC;

  tagSTATDATA                  = Record
                                                                // field used by:
                                    FORMATETC   : Tformatetc;   // EnumAdvise, EnumData (cache), EnumFormats
                                    advf        : DWord;        // EnumAdvise, EnumData (cache)
                                    padvSink    : Pointer {IAdviseSink};  // EnumAdvise
                                    dwConnection: DWord;        // EnumAdvise
                                 End;
  STATDATA                     = TagStatData;


  TagSTGMEDIUM                 = Record
                                    Tymed : DWord;
                                    Case Integer Of
                                      0 : (HBITMAP             : hBitmap;       PUnkForRelease :  Pointer {IUnknown});
                                      1 : (HMETAFILEPICT       : hMetaFilePict );
                                      2 : (HENHMETAFILE        : hEnhMetaFile  );
                                      3 : (HGLOBAL             : hGlobal       );
                                      4 : (lpszFileName        : LPOLESTR    );
                                      5 : (pstm                : Pointer{IStream}  );
                                      6 : (pstg                : Pointer{IStorage} );
                                      End;
  USTGMEDIUM                   = TagSTGMEDIUM;
  STGMEDIUM                    = USTGMEDIUM;
  TStgMedium                                                                           = TagSTGMEDIUM;
  PStgMedium                   = ^TStgMedium;
  LPSTGMEDIUM                  = ^STGMEDIUM;

  IEnumString = Interface (IUnknown)
       ['{00000101-0000-0000-C000-000000000046}']
       Function Next(Celt:ULong;Out xcelt;Out Celtfetched:ULong):HResult; StdCall;
//     Function RemoteNext(Celt:ULong; Out celt;Out Celtfetched:ULong):HResult; StdCall;
       Function Skip (Celt:ULong):Hresult;StdCall;
       Function Reset:HResult;StdCall;
       Function Clone(Out penum:IEnumString):HResult;StdCall;
       End;
       

    IEnumMoniker = Interface (IUnknown)
       ['{00000102-0000-0000-C000-000000000046}']
       Function Next(celt:ULong; out Elt;out celftfetched: ULong):HResult; StdCall;
//     Function RemoteNext(Celt:ULong; Out rgelt;out celtfetched :ULong):Hresult; StdCall;
       Function Skip(celt:Ulong):HResult; StdCall;
       Function Reset:HResult; StdCall;
       Function Close(out penum:IEnumMoniker):HResult;StdCall;
       End;

   IEnumSTATDATA = Interface (IUnknown)
    ['{00000105-0000-0000-C000-000000000046}']
    Function Next (Celt:ULong;Out xcelt;pceltfetched : PUlong):HResult; StdCall;
//      Function RemoteNext(Celt:ULong;Out Rgelt:statdata;Out pceltFetched:ULong):HResult; StdCall;
    Function Skip(Celt:ULong):HResult;StdCall;
    Function Reset:HResult;StdCall;
    Function Clone(out penum:IEnumstatdata):HResult;StdCall;
    End;

   IEnumFORMATETC = Interface (IUnknown)
   ['{00000103-0000-0000-C000-000000000046}']
   Function Next(Celt:ULong;Out Rgelt:FormatEtc;pceltFetched:pULong=nil):HResult; StdCall;
//     Function RemoteNext(Celt:ULong;Out Rgelt:FormatEtc;Out pceltFetched:ULong):HResult; StdCall;
   Function Skip(Celt:ULong):HResult;StdCall;
   Function Reset:HResult;StdCall;
   Function Clone(out penum:IEnumFORMATETC):HResult;StdCall;
   End;
   

   
    IPersist = Interface (IUnknown)
       ['{0000010c-0000-0000-C000-000000000046}']
       Function GetClassId(clsid:TClsId):HResult; StdCall;
       End;

    IPersistStream = Interface(IPersist)
       ['{00000109-0000-0000-C000-000000000046}']
       Function IsDirty:HResult; StdCall;
       Function Load(Const stm: IStream):HResult; StdCall;
       Function Save(Const stm: IStream;fClearDirty:Bool):HResult;StdCall;
       Function GetSizeMax(Out cbSize:ULarge_Integer):HResult; StdCall;
       End;
   
   
    IRunningObjectTable = Interface (IUnknown)
       ['{00000010-0000-0000-C000-000000000046}']
       Function Register  (grfFlags :DWord;const unkobject:IUnknown;Const mkObjectName:IMoniker;Out dwregister:DWord):HResult;StdCall;
       Function Revoke    (dwRegister:DWord):HResult; StdCall;
       Function IsRunning (Const mkObjectName: IMoniker):HResult;StdCall;
       Function GetObject (Const mkObjectName: IMoniker; Out punkObject:IUnknown):HResult; StdCall;
       Function NoteChangeTime(dwRegister :DWord;Const FileTime: TFileTime):HResult;StdCall;
       Function GetTimeOfLastChange(Const mkObjectName:IMoniker;Out filetime:TFileTime):HResult; StdCall;
       Function EnumRunning (Out enumMoniker: IEnumMoniker):HResult; StdCall;
       End;

   
    IBindCtx = Interface (IUnknown)
       ['{0000000e-0000-0000-C000-000000000046}']
       Function RegisterObjectBound(Const punk:IUnknown):HResult; stdCall;
       Function RevokeObjectBound (Const Punk:IUnknown):HResult;  stdCall;
       Function ReleaseBoundObjects :HResult;  StdCall;
       Function SetBindOptions(Const bindOpts:TBind_Opts):HResult;  stdCall;
//       Function RemoteSetBindOptions(Const bind_opts: TBind_Opts2):HResult;StdCall;
       Function GetBindOptions(var BindOpts:TBind_Opts):HResult;  stdCall;
//       Function RemoteGetBindOptions(Var bind_opts: TBind_Opts2):HResult;StdCall;
       Function GetRunningObjectTable(Out rot : IRunningObjectTable):Hresult; StdCall;
       Function RegisterObjectParam(Const pszkey:LPOleStr;const punk:IUnknown):HResult;
       Function GetObjectParam(Const pszkey:LPOleStr; out punk: IUnknown):HResult; StdCall;
       Function EnumObjectParam (out enum:IEnumString):Hresult;StdCall;
       Function RevokeObjectParam(pszKey:LPOleStr):HResult;StdCall;
       End;

   
    PIMoniker = ^IMoniker;
    IMoniker = Interface (IPersistStream)
      ['{0000000f-0000-0000-C000-000000000046}']
      Function BindToObject (const pbc:IBindCtx;const mktoleft:IMoniker; RiidResult:TIID;Out vresult):HResult;StdCall;
//    Function RemoteBindToObject (const pbc:IBindCtx;const mktoleft:IMoniker;RiidResult:TIID;Out vresult):HResult;StdCall;
      Function BindToStorage(Const Pbc:IBindCtx;Const mktoLeft:IMoniker; Riid:TIID;Out vobj):HResult; StdCall;
//    Function RemoteBindToStorage(Const Pbc:IBindCtx;Const mktoLeft:IMoniker; Riid:TIID;Out vobj):HResult; StdCall;
      Function Reduce (const pbc:IBindCtx; dwReduceHowFar:DWord; mktoLeft: PIMoniker; Out mkReduced:IMoniker):HResult; StdCall;
      Function ComposeWith(Const MkRight:IMoniker;fOnlyIfNotGeneric:BOOL; OUT mkComposite:IMoniker):HResult; StdCall;
      Function Enum(fForward:Bool;Out enumMoniker:IEnumMoniker):HResult;StdCall;
      Function IsEqual(Const mkOtherMoniker:IMoniker):HResult;StdCall;
      Function Hash   (Out dwHash:Dword):HResult;StdCall;
      Function IsRunning(Const bc:IBindCtx;Const MkToLeft:IMoniker;Const mknewlyRunning:IMoniker):HResult;StdCall;
      Function GetTimeOfLastChange(Const bc:IBindCtx;Const mkToLeft:IMoniker; out ft : FileTime):HResult; StdCall;
      Function Inverse(out mk : IMoniker):HResult; StdCall;
      Function CommonPrefixWith (Const mkOther:IMoniker):HResult; StdCall;
      Function RelativePathTo(Const mkother:IMoniker; Out mkRelPath : IMoniker):HResult;StdCall;
      Function GetDisplayName(Const bc:IMoniker;const mktoleft:IMoniker;Out szDisplayName: pOleStr):HResult; StdCall;
      Function ParseDisplayName(Const bc:IBindCtx;Const mkToLeft:IMoniker;szDisplayName:POleStr;out cheaten:ULong;out mkOut:IMoniker):HResult; StdCall;
      Function IsSystemMonitor(Out dwMkSys:DWord):HResult;StdCall;
      End;


    IAdviseSink = Interface (IUnknown)
        ['{0000010f-0000-0000-C000-000000000046}']
    {$ifdef midl500} ['{00000150-0000-0000-C000-000000000046}'] {$endif}
        Procedure OnDataChange (Const pformatetc : Formatetc;const pstgmed : STGMEDIUM); StdCall;
        Procedure OnViewChange (dwAspect : DWord; lindex : Long); StdCall;
        Procedure OnRename (Const pmk : IMoniker); StdCall;
        Procedure OnSave; StdCall;
        Procedure OnClose; StdCall;
     End;


  //Fake interfaces
  IDataObject = Interface (IUnknown)
   ['{0000010e-0000-0000-C000-000000000046}']
   Function GetData(Const formatetcIn : FORMATETC;Out medium : STGMEDIUM):HRESULT; STDCALL;
   Function GetDataHere(CONST pformatetc : FormatETC; Out medium : STGMEDIUM):HRESULT; STDCALL;
   Function QueryGetData(const pformatetc : FORMATETC):HRESULT; STDCALL;
   Function GetCanonicalFormatEtc(const pformatetcIn : FORMATETC;Out pformatetcOut : FORMATETC):HResult; STDCALl;
   Function SetData (Const pformatetc : FORMATETC;
     {$IF FPC_FullVersion >= 30200}var{$else}const{$IFEND} medium:STGMEDIUM;
     FRelease : BOOL):HRESULT; StdCall;
   Function EnumFormatEtc(dwDirection : DWord; OUT enumformatetcpara : IENUMFORMATETC):HRESULT; StdCall;
   Function DAdvise(const formatetc : FORMATETC;advf :DWORD; CONST AdvSink : IAdviseSink;OUT dwConnection:DWORD):HRESULT;StdCall;
   Function DUnadvise(dwconnection :DWord) :HRESULT;StdCall;
   Function EnumDAdvise(Out enumAdvise : IEnumStatData):HResult;StdCall;
   End;

 IDropTarget = interface(IUnknown)
    ['{00000122-0000-0000-C000-000000000046}']
    function DragEnter(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult;StdCall;
    function DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult;StdCall;
    function DragLeave: HResult;StdCall;
    function Drop(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD):HResult;StdCall;
  end;


  IDropSource = interface(IUnknown)
    ['{00000121-0000-0000-C000-000000000046}']
    function QueryContinueDrag(fEscapePressed: BOOL;
      grfKeyState: DWORD):HResult;StdCall;
    function GiveFeedback(dwEffect: DWORD): HResult;StdCall;
  end;
  
  
  IDataAdviseHolder = Interface (IUnknown)
       ['{00000110-0000-0000-C000-000000000046}']
       Function Advise    (CONST pdataObject : IDataObject;CONST fetc:FORMATETC;advf : DWORD;Const pAdvise:IAdviseSink;Out DwConnection:DWord):HResult; StdCall;
       Function Unadvise  (dwConnection:Dword):HResult; StdCall;
       Function EnumAdvise(out penumAdvise : IEnumStatData):HResult;StdCall;
       Function SendOnDataChange(const pDataObject :IDataObject;DwReserved,advf : DWord):HResult; StdCall;
       End;

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

  IDragSourceHelper2 = interface(IDragSourceHelper)
  [SID_IDragSourceHelper2]
    function SetFlags(dwFlags: DWORD): HRESULT; stdcall;
  end;
  
  //Ole helper functions

  function Succeeded(Status : HRESULT) : BOOLEAN;

  function Failed(Status : HRESULT) : BOOLEAN;
  
  //ActiveX functions that have wrong calling convention in fpc
  
  function RegisterDragDrop(hwnd:HWND; pDropTarget:IDropTarget):WINOLEAPI;stdcall;

  function RevokeDragDrop(hwnd:HWND):WINOLEAPI;stdcall;

  function DoDragDrop(pDataObj:IDataObject; pDropSource:IDropSource; dwOKEffects:DWORD; pdwEffect:LPDWORD):WINOLEAPI;

  function OleInitialize(pvReserved:LPVOID):WINOLEAPI;stdcall;

  procedure OleUninitialize;stdcall;

  procedure ReleaseStgMedium(_para1:LPSTGMEDIUM);stdcall;

  function OleSetClipboard(pDataObj:IDataObject):WINOLEAPI;stdcall;

  function OleGetClipboard(out ppDataObj:IDataObject):WINOLEAPI;stdcall;

  function OleFlushClipboard:WINOLEAPI;stdcall;

  function OleIsCurrentClipboard(pDataObj:IDataObject):WINOLEAPI;stdcall;

  function CreateStreamOnHGlobal(hGlobal:HGLOBAL; fDeleteOnRelease:BOOL;out stm:IStream):WINOLEAPI;stdcall;
  
  function CoCreateInstance(const _para1:TCLSID; _para2:IUnknown; _para3:DWORD;const _para4:TIID;out _para5):HRESULT;stdcall;

  //helper functions to isolate windows/OLE specific code
  
  function RenderOLEData(Tree: TObject; const FormatEtcIn: TFormatEtc; out Medium: TStgMedium;
    ForClipboard: Boolean): HResult;
    
  function GetStreamFromMedium(Medium:TStgMedium):TStream;
  
  procedure UnlockMediumData(Medium:TStgMedium);
  
  function GetTreeFromDataObject(const DataObject: IDataObject; var Format: TFormatEtc): TObject;
  
  function AllocateGlobal(Data: Pointer; DataSize:Cardinal): HGLOBAL;

implementation

uses
  VirtualTrees.BaseTree, Controls {$ifdef DEBUG_VTV}, VirtualTrees.logger {$endif};
  
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

function RegisterDragDrop(hwnd: HWND; pDropTarget: IDropTarget): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function RevokeDragDrop(hwnd: HWND): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function DoDragDrop(pDataObj: IDataObject; pDropSource: IDropSource;
  dwOKEffects: DWORD; pdwEffect: LPDWORD): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function OleInitialize(pvReserved: LPVOID): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

procedure OleUninitialize;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

procedure ReleaseStgMedium(_para1: LPSTGMEDIUM);
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function OleSetClipboard(pDataObj: IDataObject): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function OleGetClipboard(out ppDataObj: IDataObject): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function OleFlushClipboard: WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function OleIsCurrentClipboard(pDataObj: IDataObject): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function CreateStreamOnHGlobal(hGlobal: HGLOBAL; fDeleteOnRelease: BOOL; out
  stm: IStream): WINOLEAPI;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;

function CoCreateInstance(const _para1: TCLSID; _para2: IUnknown;
  _para3: DWORD; const _para4: TIID; out _para5): HRESULT;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
end;


function RenderOLEData(Tree: TObject; const FormatEtcIn: TFormatEtc; out
  Medium: TStgMedium; ForClipboard: Boolean): HResult;
{
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
}
var
  Data: PCardinal;
  ResPointer: Pointer;
  ResSize: Integer;
  OLEStream: IStream;
  VCLStream: TStream;
  
begin
 {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
  {
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
  }
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
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
   // raise EStreamError.CreateRes(PResStringRec(@SCantWriteResourceStreamError));
end;


function GetStreamFromMedium(Medium: TStgMedium): TStream;

var
  Data: Pointer;
  I: Integer;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
{
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
}
end;

procedure UnlockMediumData(Medium: TStgMedium);
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
{
  if Medium.tymed = TYMED_HGLOBAL then
    GlobalUnlock(Medium.hGlobal);
 }
end;

function GetTreeFromDataObject(const DataObject: IDataObject;
  var Format: TFormatEtc): TObject;
  
var
  Medium: TStgMedium;
  Data: PVTReference;
  
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
  {
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
  }
end;

function AllocateGlobal(Data: Pointer; DataSize: Cardinal): HGLOBAL;
var
  P:Pointer;
begin
  {$ifdef DEBUG_VTV}Logger.SendError([lcOle],'Ole function called in Linux');{$endif}
  {$ifdef DEBUG_VTV}Logger.SendCallStack([lcOle],'Stack');{$endif}
  {
  Result := GlobalAlloc(GHND or GMEM_SHARE, DataSize);
  P := GlobalLock(Result);
  Move(Data^, P^, DataSize);
  GlobalUnlock(Result);
  }
end;


end.

