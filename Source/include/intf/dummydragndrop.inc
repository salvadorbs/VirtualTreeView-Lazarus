{$warnings off}
{$hints off}

//----------------------------------------------------------------------------------------------------------------------

// OLE drag and drop support classes
// This is quite heavy stuff (compared with the VCL implementation) but is much better suited to fit the needs
// of DD'ing various kinds of virtual data and works also between applications.

//----------------- TEnumFormatEtc -------------------------------------------------------------------------------------

constructor TEnumFormatEtc.Create(AFormatEtcArray: TFormatEtcArray);

var
  I: Integer;

begin
  inherited Create;

  {
  FTree := Tree;
  // Make a local copy of the format data.
  SetLength(FFormatEtcArray, Length(AFormatEtcArray));
  for I := 0 to High(AFormatEtcArray) do
    FFormatEtcArray[I] := AFormatEtcArray[I];
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Clone(out Enum: IEnumFormatEtc): HResult;

{
var
  AClone: TEnumFormatEtc;
}
begin
  {
  Result := S_OK;
  try
    AClone := TEnumFormatEtc.Create(nil, FFormatEtcArray);
    AClone.FCurrentIndex := FCurrentIndex;
    Enum := AClone as IEnumFormatEtc;
  except
    Result := E_FAIL;
  end;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Next(celt: LongWord; out elt: FormatEtc;pceltFetched:pULong=nil): HResult;
{
var
  CopyCount: LongWord;
}
begin
  {
  Result := S_FALSE;
  CopyCount := Length(FFormatEtcArray) - FCurrentIndex;
  if celt < CopyCount then
    CopyCount := celt;
  if CopyCount > 0 then
  begin
    Move(FFormatEtcArray[FCurrentIndex], elt, CopyCount * SizeOf(TFormatEtc));
    Inc(FCurrentIndex, CopyCount);
    Result := S_OK;
  end;
  //todo_lcl_check Delphi treats pceltFetched an PInteger. Implemented like in fpc.activex. What heappens with
  // a C Program call with a NULL in pCeltFetcjed??
  //Answer: Yes. Is necessary a check here
  if @pceltFetched <> nil then
    pceltFetched := CopyCount;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Reset: HResult;

begin
  {
  FCurrentIndex := 0;
  Result := S_OK;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TEnumFormatEtc.Skip(celt: LongWord): HResult;

begin
  {
  if FCurrentIndex + celt < High(FFormatEtcArray) then
  begin
    Inc(FCurrentIndex, celt);
    Result := S_Ok;
  end
  else
    Result := S_FALSE;
  }
end;

//----------------- TVTDragManager -------------------------------------------------------------------------------------

constructor TVTDragManager.Create(AOwner: TBaseVirtualTree);

begin
  inherited Create;

  FOwner := AOwner;
  {
  // Create an instance  of the drop target helper interface. This will fail but not harm on systems which do
  // not support this interface (everything below Windows 2000);
  CoCreateInstance(CLSID_DragDropHelper, nil, CLSCTX_INPROC_SERVER, IID_IDropTargetHelper, FDropTargetHelper);
  }
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

function TVTDragManager.GetDataObject: IDataObject;

begin
  // When the owner tree starts a drag operation then it gets a data object here to pass it to the OLE subsystem.
  // In this case there is no local reference to a data object and one is created (but not stored).
  // If there is a local reference then the owner tree is currently the drop target and the stored interface is
  // that of the drag initiator.
  {
  if Assigned(FDataObject) then
    Result := FDataObject
  else
  begin
    Result := FOwner.DoCreateDataObject;
    if Result = nil then
      Result := TVTDataObject.Create(FOwner, False) as IDataObject;
  end;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GetDragSource: TBaseVirtualTree;

begin
  //Result := FDragSource;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GetDropTargetHelperSupported: Boolean;

begin
  //Result := Assigned(FDropTargetHelper);
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GetIsDropTarget: Boolean;

begin
  //Result := FIsDropTarget;
  Result := True;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.DragEnter(const DataObject: IDataObject; KeyState: LongWord; Pt: TPoint;
  var Effect: LongWord): HResult;

begin
  {
  FDataObject := DataObject;
  FIsDropTarget := True;

  SystemParametersInfo(SPI_GETDRAGFULLWINDOWS, 0, @FFullDragging, 0);
  // If full dragging of window contents is disabled in the system then our tree windows will be locked
  // and cannot be updated during a drag operation. With the following call painting is again enabled.
  if not FFullDragging then
    LockWindowUpdate(0);
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.DragEnter(FOwner.Handle, DataObject, Pt, Effect);

  FDragSource := FOwner.GetTreeFromDataObject(DataObject);
  Result := FOwner.DragEnter(KeyState, Pt, Effect);
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.DragLeave: HResult;

begin
  {
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.DragLeave;

  FOwner.DragLeave;
  FIsDropTarget := False;
  FDragSource := nil;
  FDataObject := nil;
  Result := NOERROR;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.DragOver(KeyState: LongWord; Pt: TPoint; var Effect: LongWord): HResult;

begin
  {
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.DragOver(Pt, Effect);

  Result := FOwner.DragOver(FDragSource, KeyState, dsDragMove, Pt, Effect);
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.Drop(const DataObject: IDataObject; KeyState: LongWord; Pt: TPoint;
  var Effect: LongWord): HResult;

begin
  {
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.Drop(DataObject, Pt, Effect);

  Result := FOwner.DragDrop(DataObject, KeyState, Pt, Effect);
  FIsDropTarget := False;
  FDataObject := nil;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragManager.ForceDragLeave;

// Some drop targets, e.g. Internet Explorer leave a drag image on screen instead removing it when they receive
// a drop action. This method calls the drop target helper's DragLeave method to ensure it removes the drag image from
// screen. Unfortunately, sometimes not even this does help (e.g. when dragging text from VT to a text field in IE).

begin
  {
  if Assigned(FDropTargetHelper) and FFullDragging then
    FDropTargetHelper.DragLeave;
  }
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.GiveFeedback(Effect: LongWord): HResult;

begin
  //Result := DRAGDROP_S_USEDEFAULTCURSORS;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragManager.QueryContinueDrag(EscapePressed: BOOL; KeyState: LongWord): HResult;

var
  RButton,
  LButton: Boolean;

begin
  {
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

  }
end;


