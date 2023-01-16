function TBaseVirtualTree.GetTreeFromDataObject(const DataObject: IDataObject): TBaseVirtualTree;

// Returns the owner/sender of the given data object by means of a special clipboard format
// or nil if the sender is in another process or no virtual tree at all.

var
  Medium: TStgMedium;
  Data: PVTReference;

begin
  Result := nil;
  {
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
      ReleaseStgMedium(@Medium);
    end;
  end;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TBaseVirtualTree.RenderOLEData(const FormatEtcIn: TFormatEtc; out Medium: TStgMedium;
  ForClipboard: Boolean): HResult;

// Returns a memory expression of all currently selected nodes in the Medium structure.
// Note: The memory requirement of this method might be very high. This depends however on the requested storage format.
//       For HGlobal (a global memory block) we need to render first all nodes to local memory and copy this then to
//       the global memory in Medium. This is necessary because we have first to determine how much
//       memory is needed before we can allocate it. Hence for a short moment we need twice the space as used by the
//       nodes alone (plus the amount the nodes need in the tree anyway)!
//       With IStream this does not happen. We directly stream out the nodes and pass the constructed stream along.

  //--------------- local function --------------------------------------------
{
  procedure WriteNodes(Stream: TStream);

  var
    Selection: TNodeArray;
    I: Integer;

  begin
    if ForClipboard then
      Selection := GetSortedCutCopySet(True)
    else
      Selection := GetSortedSelection(True);
    for I := 0 to High(Selection) do
      WriteNode(Stream, Selection[I]);
  end;

  //--------------- end local function ----------------------------------------

var
  Data: PCardinal;
  ResPointer: Pointer;
  ResSize: Integer;
  OLEStream: IStream;
  VCLStream: TStream;
}
begin
  {
  FillChar(Medium, SizeOf(Medium), 0);
  // We can render the native clipboard format in two different storage media.
  if (FormatEtcIn.cfFormat = CF_VIRTUALTREE) and (FormatEtcIn.tymed and (TYMED_HGLOBAL or TYMED_ISTREAM) <> 0) then
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
  end
  else // Ask application descendants to render self defined formats.
    Result := DoRenderOLEData(FormatEtcIn, Medium, ForClipboard);
  }
end;


//----------------------------------------------------------------------------------------------------------------------

type
  // needed to handle OLE global memory objects
  TOLEMemoryStream = class(TCustomMemoryStream)
  public
    function Write(const Buffer; Count: Integer): Longint; override;
  end;

//----------------------------------------------------------------------------------------------------------------------

function TOLEMemoryStream.Write(const Buffer; Count: Integer): Integer;

begin
  //raise EStreamError.CreateRes(PResStringRec(@SCantWriteResourceStreamError));
  raise EStreamError.Create(SCantWriteResourceStreamError);
end;

//----------------------------------------------------------------------------------------------------------------------

function TBaseVirtualTree.ProcessOLEData(Source: TBaseVirtualTree; DataObject: IDataObject; TargetNode: PVirtualNode;
  Mode: TVTNodeAttachMode; Optimized: Boolean): Boolean;

// Recreates the (sub) tree structure serialized into memory and provided by DataObject. The new nodes are attached to
// the passed node or FRoot if TargetNode is nil according to Mode. Optimized can be set to True if the entire operation
// happens within the same process (i.e. sender and receiver of the OLE operation are located in the same process).
// Optimize = True makes only sense if the operation to carry out is a move hence it is also the indication of the
// operation to be done here. Source is the source of the OLE data and only of use (and usually assigned) when
// an OLE operation takes place in the same application.
// Returns True on success, i.e. the CF_VIRTUALTREE format is supported by the data object and the structure could be
// recreated, otherwise False.

var
  Medium: TStgMedium;
  Stream: TStream;
  Data: Pointer;
  Node: PVirtualNode;
  Nodes: TNodeArray;
  I: Integer;
  Res: HRESULT;
  ChangeReason: TChangeReason;

begin
  {
  Nodes := nil;
  // Check the data format available by the data object.
  with StandardOLEFormat do
  begin
    // Read best format.
    cfFormat := CF_VIRTUALTREE;
  end;
  Result := DataObject.QueryGetData(StandardOLEFormat) = S_OK;
  if Result and not (toReadOnly in FOptions.MiscOptions) then
  begin
    BeginUpdate;
    Result := False;
    try
      if TargetNode = nil then
        TargetNode := FRoot;
      if TargetNode = FRoot then
      begin
        case Mode of
          amInsertBefore:
            Mode := amAddChildFirst;
          amInsertAfter:
            Mode := amAddChildLast;
        end;
      end;

      // Optimized means source is known and in the same process so we can access its pointers, which avoids duplicating
      // the data while doing a serialization. Can only be used with cut'n paste and drag'n drop with move effect.
      if Optimized then
      begin
        if tsOLEDragging in Source.FStates then
          Nodes := Source.FDragSelection
        else
          Nodes := Source.GetSortedCutCopySet(True);

        if Mode in [amInsertBefore,amAddChildLast] then
        begin
          for I := 0 to High(Nodes) do
            if not HasAsParent(TargetNode, Nodes[I]) then
              Source.MoveTo(Nodes[I], TargetNode, Mode, False);
        end
        else
        begin
          for I := High(Nodes) downto 0 do
            if not HasAsParent(TargetNode, Nodes[I]) then
              Source.MoveTo(Nodes[I], TargetNode, Mode, False);
        end;
        Result := True;
      end
      else
      begin
        if Source = Self then
          ChangeReason := crNodeCopied
        else
          ChangeReason := crNodeAdded;
        Res := DataObject.GetData(StandardOLEFormat, Medium);
        if Res = S_OK then
        begin
          case Medium.tymed of
            TYMED_ISTREAM, // IStream interface
            TYMED_HGLOBAL: // global memory block
              begin
                Stream := nil;
                if Medium.tymed = TYMED_ISTREAM then
                  Stream := TOLEStream.Create(IUnknown(Medium.Pstm) as IStream)
                else
                begin
                  Data := GlobalLock(Medium.hGlobal);
                  if Assigned(Data) then
                  begin
                    // Get the total size of data to retrieve.
                    I := PCardinal(Data)^;
                    Inc(PCardinal(Data));
                    Stream := TOLEMemoryStream.Create;
                    TOLEMemoryStream(Stream).SetPointer(Data, I);
                  end;
                end;
                if Assigned(Stream) then
                try
                  while Stream.Position < Stream.Size do
                  begin
                    Node := MakeNewNode;
                    InternalConnectNode(Node, TargetNode, Self, Mode);
                    InternalAddFromStream(Stream, VTTreeStreamVersion, Node);
                    // This seems a bit strange because of the callback for granting to add the node
                    // which actually comes after the node has been added. The reason is that the node must
                    // contain valid data otherwise I don't see how the application can make a funded decision.
                    if not DoNodeCopying(Node, TargetNode) then
                      DeleteNode(Node)
                    else
                      DoNodeCopied(Node);
                    StructureChange(Node, ChangeReason);

                    // In order to maintain the same node order when restoring nodes in the case of amInsertAfter
                    // we have to move the reference node continously. Othwise we would end up with reversed node order.
                    if Mode = amInsertAfter then
                      TargetNode := Node;
                  end;
                  Result := True;
                finally
                  Stream.Free;
                  if Medium.tymed = TYMED_HGLOBAL then
                    GlobalUnlock(Medium.hGlobal);
                end;
              end;
          end;
          ReleaseStgMedium(@Medium);
        end;
      end;
    finally
      EndUpdate;
    end;
  end;
  }
end;

