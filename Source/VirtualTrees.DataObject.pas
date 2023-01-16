unit VirtualTrees.DataObject;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, Controls, Graphics, LCLType, SysUtils, Types,
  {$ifdef Windows}
  Windows,
  ActiveX,
  {$else}
  FakeActiveX,
  {$endif}
  DelphiCompat
  , VirtualTrees.Types;

type
  // IDataObject.SetData support
  TInternalStgMedium = packed record
    Format: TClipFormat;
    Medium: TStgMedium;
  end;
  TInternalStgMediumArray = array of TInternalStgMedium;

  // This data object is used in two different places. One is for clipboard operations and the other while dragging.
  TVTDataObject = class(TInterfacedObject, IDataObject)
  private
    FOwner: TCustomControl;          // The tree which provides clipboard or drag data.
    FForClipboard: Boolean;            // Determines which data to render with GetData.
    FFormatEtcArray: TFormatEtcArray;
    FInternalStgMediumArray: TInternalStgMediumArray;  // The available formats in the DataObject
    FAdviseHolder: IDataAdviseHolder;  // Reference to an OLE supplied implementation for advising.
  protected
    function CanonicalIUnknown(TestUnknown: IUnknown): IUnknown;
    function EqualFormatEtc(FormatEtc1, FormatEtc2: TFormatEtc): Boolean;
    function FindFormatEtc(TestFormatEtc: TFormatEtc; const FormatEtcArray: TFormatEtcArray): integer;
    function FindInternalStgMedium(Format: TClipFormat): PStgMedium;
    function HGlobalClone(HGlobal: THandle): THandle;
    function RenderInternalOLEData(const FormatEtcIn: TFormatEtc; var Medium: TStgMedium; var OLEResult: HResult): Boolean;
    function StgMediumIncRef(const InStgMedium: TStgMedium; var OutStgMedium: TStgMedium;
      CopyInMedium: Boolean; DataObject: IDataObject): HRESULT;

    property ForClipboard: Boolean read FForClipboard;
    property FormatEtcArray: TFormatEtcArray read FFormatEtcArray write FFormatEtcArray;
    property InternalStgMediumArray: TInternalStgMediumArray read FInternalStgMediumArray write FInternalStgMediumArray;
    property Owner: TCustomControl read FOwner;
  public
    constructor Create(AOwner: TCustomControl; ForClipboard: Boolean); virtual;
    destructor Destroy; override;

    function DAdvise(const FormatEtc: TFormatEtc; advf: DWord; const advSink: IAdviseSink; out dwConnection: DWord):
      HResult; virtual; stdcall;
    function DUnadvise(dwConnection: DWord): HResult; virtual; stdcall;
    Function EnumDAdvise(out enumAdvise : IEnumStatData):HResult;virtual;StdCall;
    function EnumFormatEtc(Direction: DWord; out EnumFormatEtc: IEnumFormatEtc): HResult; virtual; stdcall;
    function GetCanonicalFormatEtc(const pformatetcIn : FORMATETC;Out pformatetcOut : FORMATETC):HResult; virtual; STDCALl;
    function GetData(const FormatEtcIn: TFormatEtc; out Medium: TStgMedium): HResult; virtual; stdcall;
    function GetDataHere(const FormatEtc: TFormatEtc; out Medium: TStgMedium): HResult; virtual; stdcall;
    function QueryGetData(const FormatEtc: TFormatEtc): HResult; virtual; stdcall;
    function SetData(const FormatEtc: TFormatEtc;
      {$IF FPC_FullVersion >= 30200}var{$ELSE}const{$IFEND} Medium: TStgMedium;
      DoRelease: BOOL): HResult; virtual; stdcall;
  end;

  // ----- OLE drag'n drop handling

  IDropTargetHelper = interface(IUnknown)
    [SID_IDropTargetHelper]
    function DragEnter(hwndTarget: HWND; pDataObject: IDataObject; var ppt: TPoint; dwEffect: LongWord): HRESULT; stdcall;
    function DragLeave: HRESULT; stdcall;
    function DragOver(var ppt: TPoint; dwEffect: LongWord): HRESULT; stdcall;
    function Drop(pDataObject: IDataObject; var ppt: TPoint; dwEffect: LongWord): HRESULT; stdcall;
    function Show(fShow: Boolean): HRESULT; stdcall;
  end;

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

implementation

uses
  VirtualTrees.DragnDrop, VirtualTrees.BaseTree, VirtualTrees.ClipBoard;

type
  TVTCracker = class(TBaseVirtualTree);

{$i vtvdragmanager.inc}

end.
