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
  , VirtualTrees.BaseTree;

type
  TEnumFormatEtc = class(TInterfacedObject, IEnumFormatEtc)
  private
    FFormatEtcArray: TFormatEtcArray;
    FCurrentIndex: Integer;
  public
    constructor Create(AFormatEtcArray: TFormatEtcArray);

    function Clone(out Enum: IEnumFormatEtc): HResult; stdcall;
    function Next(celt: LongWord; out elt: FormatEtc;pceltFetched:pULong=nil): HResult; stdcall;
    function Reset: HResult; stdcall;
    function Skip(celt: LongWord): HResult; stdcall;
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
    FOwner,                            // The tree which is responsible for drag management.
    FDragSource: TBaseVirtualTree;     // Reference to the source tree if the source was a VT, might be different than
                                       // the owner tree.
    FIsDropTarget: Boolean;            // True if the owner is currently the drop target.
    FDataObject: IDataObject;          // A reference to the data object passed in by DragEnter (only used when the owner
                                       // tree is the current drop target).
    FDropTargetHelper: IDropTargetHelper; // Win2k > Drag image support
    FFullDragging: BOOL;               // True, if full dragging is currently enabled in the system.

    function GetDataObject: IDataObject; stdcall;
    function GetDragSource: TBaseVirtualTree; stdcall;
    function GetDropTargetHelperSupported: Boolean; stdcall;
    function GetIsDropTarget: Boolean; stdcall;
  public
    constructor Create(AOwner: TBaseVirtualTree); virtual;
    destructor Destroy; override;

    function DragEnter(const DataObject: IDataObject; KeyState: LongWord; Pt: TPoint;
      var Effect: LongWord): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function DragOver(KeyState: LongWord; Pt: TPoint; var Effect: LongWord): HResult; stdcall;
    function Drop(const DataObject: IDataObject; KeyState: LongWord; Pt: TPoint; var Effect: LongWord): HResult; stdcall;
    procedure ForceDragLeave; stdcall;
    {$IF (FPC_FULLVERSION < 020601) and DEFINED(LCLWin32)}
    function GiveFeedback(Effect: Longint): HResult; stdcall;
    function QueryContinueDrag(EscapePressed: BOOL; KeyState: Longint): HResult; stdcall;
    {$ELSE}
    function GiveFeedback(Effect: LongWord): HResult; stdcall;
    function QueryContinueDrag(EscapePressed: BOOL; KeyState: LongWord): HResult; stdcall;
    {$ENDIF}
  end;

var
  StandardOLEFormat: TFormatEtc = (
    // Format must later be set.
    cfFormat: 0;
    // No specific target device to render on.
    ptd: nil;
    // Normal content to render.
    dwAspect: DVASPECT_CONTENT;
    // No specific page of multipage data (we don't use multipage data by default).
    lindex: -1;
    // Acceptable storage formats are IStream and global memory. The first is preferred.
    tymed: TYMED_ISTREAM or TYMED_HGLOBAL;
  );

implementation

uses
  VirtualTrees.DataObject;

type
  TBaseVirtualTreeCracker = class(TBaseVirtualTree);

  { TVTDragManagerHelper }

  TVTDragManagerHelper = class helper for TVTDragManager
    function TreeView : TBaseVirtualTreeCracker;
  end;

{ TVTDragManagerHelper }

function TVTDragManagerHelper.TreeView: TBaseVirtualTreeCracker;
begin
  Result := TBaseVirtualTreeCracker(FOwner);
end;

{$i vtvdragndrop.inc}

end.
