unit VirtualTrees.DragImage;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, Controls, Graphics,
  {$ifdef Windows}
  Windows,
  ActiveX,
  CommCtrl,
  UxTheme,
  {$else}
  FakeActiveX,
  {$endif}   
  LCLType
  , Math
  , DelphiCompat
  , Types
  , LCLIntf
  , SysUtils;

type
  // Drag image support for the tree.
  TVTTransparency = 0..255;
  TVTBias = -128..127;

  // Simple move limitation for the drag image.
  TVTDragMoveRestriction = (
    dmrNone,
    dmrHorizontalOnly,
    dmrVerticalOnly
  );

  TVTDragImageStates = set of (
    disHidden,          // Internal drag image is currently hidden (always hidden if drag image helper interfaces are used).
    disInDrag,          // Drag image class is currently being used.
    disPrepared,        // Drag image class is prepared.
    disSystemSupport    // Running on Windows 2000 or higher. System supports drag images natively.
  );

  // Class to manage header and tree drag image during a drag'n drop operation.

  { TVTDragImage }

  TVTDragImage = class
  private
    FOwner: TCustomControl;
    FBackImage,                        // backup of overwritten screen area
    FAlphaImage,                       // target for alpha blending
    FDragImage: Graphics.TBitmap;      // the actual drag image to blend to screen
    FImagePosition,                    // position of image (upper left corner) in screen coordinates
    FLastPosition: TPoint;             // last mouse position in screen coordinates
    FTransparency: TVTTransparency;    // alpha value of the drag image (0 - fully transparent, 255 - fully opaque)
    FPreBlendBias,                     // value to darken or lighten the drag image before it is blended
    FPostBlendBias: TVTBias;           // value to darken or lighten the alpha blend result
    FFade: Boolean;                    // determines whether to fade the drag image from center to borders or not
    FRestriction: TVTDragMoveRestriction;  // determines in which directions the drag image can be moved
    FColorKey: TColor;                 // color to make fully transparent regardless of any other setting
    FStates: TVTDragImageStates;       // Determines the states of the drag image class.
    function GetVisible: Boolean;      // True if the drag image is currently hidden (used only when dragging)
  protected
    procedure InternalShowDragImage(ScreenDC: HDC);
    procedure MakeAlphaChannel(Source, Target: Graphics.TBitmap);
  public
    constructor Create(AOwner: TCustomControl);
    destructor Destroy; override;

    function DragTo(const P: TPoint; ForceRepaint: Boolean): Boolean;
    procedure EndDrag;
    function GetDragImageRect: TRect;
    procedure HideDragImage;
    procedure PrepareDrag(DragImage: Graphics.TBitmap; const ImagePosition, HotSpot: TPoint; const DataObject: IDataObject);
    procedure RecaptureBackground(Tree: TCustomControl; R: TRect; VisibleRegion: HRGN; CaptureNCArea,
      ReshowDragImage: Boolean);
    procedure ShowDragImage;
    function WillMove(const P: TPoint): Boolean;

    property ColorKey: TColor read FColorKey write FColorKey default clWindow;
    property Fade: Boolean read FFade write FFade default False;
    property MoveRestriction: TVTDragMoveRestriction read FRestriction write FRestriction default dmrNone;
    property PostBlendBias: TVTBias read FPostBlendBias write FPostBlendBias default 0;
    property PreBlendBias: TVTBias read FPreBlendBias write FPreBlendBias default 0;
    property Transparency: TVTTransparency read FTransparency write FTransparency default 128;
    property Visible: Boolean read GetVisible;
  end;

implementation

uses
  VirtualTrees, VirtualTrees.BaseTree, VirtualTrees.Graphics, VirtualTrees.Types, VirtualTrees.DataObject, VirtualTrees.DragnDrop;

//----------------- TVTDragImage ---------------------------------------------------------------------------------------

constructor TVTDragImage.Create(AOwner: TCustomControl);

begin
  FOwner := AOwner;
  FTransparency := 128;
  FPreBlendBias := 0;
  FPostBlendBias := 0;
  FFade := False;
  FRestriction := dmrNone;
  FColorKey := clNone;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TVTDragImage.Destroy;

begin
  EndDrag;

  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragImage.GetVisible: Boolean;

// Returns True if the internal drag image is used (i.e. the system does not natively support drag images) and
// the internal image is currently visible on screen.

begin
  Result := FStates * [disHidden, disInDrag, disPrepared, disSystemSupport] = [disInDrag, disPrepared];
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragImage.InternalShowDragImage(ScreenDC: HDC);

// Frequently called helper routine to actually do the blend and put it onto the screen.
// Only used if the system does not support drag images.

var
  BlendMode: TBlendMode;

begin
  with FAlphaImage do
    BitBlt(Canvas.Handle, 0, 0, Width, Height, FBackImage.Canvas.Handle, 0, 0, SRCCOPY);
  if not FFade and (FColorKey = clNone) then
    BlendMode := bmConstantAlpha
  else
    BlendMode := bmMasterAlpha;
  with FDragImage do
    AlphaBlend(Canvas.Handle, FAlphaImage.Canvas.Handle, Rect(0, 0, Width, Height), Point(0, 0), BlendMode,
      FTransparency, FPostBlendBias);

  with FAlphaImage do
    BitBlt(ScreenDC, FImagePosition.X, FImagePosition.Y, Width, Height, Canvas.Handle, 0, 0, SRCCOPY);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragImage.MakeAlphaChannel(Source, Target: Graphics.TBitmap);

// Helper method to create a proper alpha channel in Target (which must be in 32 bit pixel format), depending
// on the settings for the drag image and the color values in Source.
// Only used if the system does not support drag images.

type
  PBGRA = ^TBGRA;
  TBGRA = packed record
    case Boolean of
      False:
        (Color: Cardinal);
      True:
        (BGR: array[0..2] of Byte;
         Alpha: Byte);
  end;

var
  Color,
  ColorKeyRef: COLORREF;
  UseColorKey: Boolean;
  SourceRun,
  TargetRun: PBGRA;
  X, Y,
  MaxDimension,
  HalfWidth,
  HalfHeight: Integer;
  T: Extended;
  SourceBits, TargetBits: Pointer;

begin
  {$ifdef EnableAdvancedGraphics}
  SourceBits := GetBitmapBitsFromBitmap(Source.Handle);
  TargetBits := GetBitmapBitsFromBitmap(Target.Handle);

  if (SourceBits = nil) or (TargetBits = nil) then
    Exit;

  UseColorKey := ColorKey <> clNone;
  ColorKeyRef := ColorToRGB(ColorKey) and $FFFFFF;
  // Color values are in the form BGR (red on LSB) while bitmap colors are in the form ARGB (blue on LSB)
  // hence we have to swap red and blue in the color key.
  with TBGRA(ColorKeyRef) do
  begin
    X := BGR[0];
    BGR[0] := BGR[2];
    BGR[2] := X;
  end;

  with Target do
  begin
    MaxDimension := Max(Width, Height);

    HalfWidth := Width div 2;
    HalfHeight := Height div 2;
    for Y := 0 to Height - 1 do
    begin
      TargetRun := CalculateScanline(TargetBits, Width, Height, Y);
      SourceRun := CalculateScanline(SourceBits, Source.Width, Source.Height, Y);
      for X := 0 to Width - 1 do
      begin
        Color := SourceRun.Color and $FFFFFF;
        if UseColorKey and (Color = ColorKeyRef) then
          TargetRun.Alpha := 0
        else
        begin
          // If the color is not the given color key (or none is used) then do full calculation of a bell curve.
          T := Exp(-8 * Sqrt(Sqr((X - HalfWidth) / MaxDimension) + Sqr((Y - HalfHeight) / MaxDimension)));
          TargetRun.Alpha := Round(255 * T);
        end;
        Inc(SourceRun);
        Inc(TargetRun);
      end;
    end;
  end;
  {$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragImage.DragTo(const P: TPoint; ForceRepaint: Boolean): Boolean;

// Moves the drag image to a new position, which is determined from the passed point P and the previous
// mouse position.
// ForceRepaint is True if something on the screen changed and the back image must be refreshed.

var
  ScreenDC: HDC;
  DeltaX,
  DeltaY: Integer;

  // optimized drag image move support
  RSamp1,
  RSamp2,       // newly added parts from screen which will be overwritten
  RDraw1,
  RDraw2,       // parts to be restored to screen
  RScroll,
  RClip: TRect; // ScrollDC of the existent background

begin
  // Determine distances to move the drag image. Take care for restrictions.
  case FRestriction of
    dmrHorizontalOnly:
      begin
        DeltaX := FLastPosition.X - P.X;
        DeltaY := 0;
      end;
    dmrVerticalOnly:
      begin
        DeltaX := 0;
        DeltaY := FLastPosition.Y - P.Y;
      end;
  else // dmrNone
    DeltaX := FLastPosition.X - P.X;
    DeltaY := FLastPosition.Y - P.Y;
  end;

  Result := (DeltaX <> 0) or (DeltaY <> 0) or ForceRepaint;
  if Result then
  begin
    if Visible then
    begin
      // All this stuff is only called if we have to handle the drag image ourselves. If the system supports
      // drag image then this is all never executed.
      ScreenDC := GetDC(0);
      try
        if (Abs(DeltaX) >= FDragImage.Width) or (Abs(DeltaY) >= FDragImage.Height) or ForceRepaint then
        begin
          // If moved more than image size then just restore old screen and blit image to new position.
          BitBlt(ScreenDC, FImagePosition.X, FImagePosition.Y, FBackImage.Width, FBackImage.Height,
            FBackImage.Canvas.Handle, 0, 0, SRCCOPY);

          if ForceRepaint then
            UpdateWindow(FOwner.Handle);

          Inc(FImagePosition.X, -DeltaX);
          Inc(FImagePosition.Y, -DeltaY);

          BitBlt(FBackImage.Canvas.Handle, 0, 0, FBackImage.Width, FBackImage.Height, ScreenDC, FImagePosition.X,
            FImagePosition.Y, SRCCOPY);
        end
        else
        begin
          // overlapping copy
          FillDragRectangles(FDragImage.Width, FDragImage.Height, DeltaX, DeltaY, RClip, RScroll, RSamp1, RSamp2, RDraw1,
            RDraw2);

          with FBackImage.Canvas do
          begin
            // restore uncovered areas of the screen
            if DeltaX = 0 then
            begin
              with TWithSafeRect(RDraw2) do
                BitBlt(ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top, Right, Bottom, Handle, Left, Top,
                  SRCCOPY);
            end
            else
            begin
              if DeltaY = 0 then
              begin
                with TWithSafeRect(RDraw1) do
                  BitBlt(ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top, Right, Bottom, Handle, Left, Top,
                    SRCCOPY);
              end
              else
              begin
                with TWithSafeRect(RDraw1) do
                  BitBlt(ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top, Right, Bottom, Handle, Left, Top,
                    SRCCOPY);
                with TWithSafeRect(RDraw2) do
                  BitBlt(ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top, Right, Bottom, Handle, Left, Top,
                    SRCCOPY);
              end;
            end;

            //todo: implement ScrollDC. Alternatively reimplement drag operations
            {$ifndef INCOMPLETE_WINAPI}
            // move existent background
            ScrollDC(Handle, DeltaX, DeltaY, RScroll, RClip, 0, nil);
            {$endif}

            Inc(FImagePosition.X, -DeltaX);
            Inc(FImagePosition.Y, -DeltaY);

            // Get first and second additional rectangle from screen.
            if DeltaX = 0 then
            begin
              with TWithSafeRect(RSamp2) do
                BitBlt(Handle, Left, Top, Right, Bottom, ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top,
                  SRCCOPY);
            end
            else
              if DeltaY = 0 then
              begin
                with TWithSafeRect(RSamp1) do
                  BitBlt(Handle, Left, Top, Right, Bottom, ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top,
                    SRCCOPY);
              end
              else
              begin
                with TWithSafeRect(RSamp1) do
                  BitBlt(Handle, Left, Top, Right, Bottom, ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top,
                    SRCCOPY);
                with TWithSafeRect(RSamp2) do
                  BitBlt(Handle, Left, Top, Right, Bottom, ScreenDC, FImagePosition.X + Left, FImagePosition.Y + Top,
                    SRCCOPY);
              end;
          end;
        end;
        InternalShowDragImage(ScreenDC);
      finally
        ReleaseDC(0, ScreenDC);
      end;
    end;
    FLastPosition.X := P.X;
    FLastPosition.Y := P.Y;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragImage.EndDrag;

begin
  HideDragImage;
  FStates := FStates - [disInDrag, disPrepared];

  FBackImage.Free;
  FBackImage := nil;
  FDragImage.Free;
  FDragImage := nil;
  FAlphaImage.Free;
  FAlphaImage := nil;
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragImage.GetDragImageRect: TRect;

// Returns the current size and position of the drag image (screen coordinates).

begin
  if Visible then
  begin
    with FBackImage do
      Result := Rect(FImagePosition.X, FImagePosition.Y, FImagePosition.X + Width, FImagePosition.Y + Height);
  end
  else
    Result := Rect(0, 0, 0, 0);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragImage.HideDragImage;

var
  ScreenDC: HDC;

begin
  if Visible then
  begin
    Include(FStates, disHidden);
    ScreenDC := GetDC(0);
    try
      // restore screen
      with FBackImage do
        BitBlt(ScreenDC, FImagePosition.X, FImagePosition.Y, Width, Height, Canvas.Handle, 0, 0, SRCCOPY);
    finally
      ReleaseDC(0, ScreenDC);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragImage.PrepareDrag(DragImage: Graphics.TBitmap;
  const ImagePosition, HotSpot: TPoint; const DataObject: IDataObject);

// Creates all necessary structures to do alpha blended dragging using the given image.
// ImagePostion and HotSpot are given in screen coordinates. The first determines where to place the drag image while
// the second is the initial mouse position.
// This method also determines whether the system supports drag images natively. If so then only minimal structures
// are created.

var
  Width,
  Height: Integer;
  DragSourceHelper: IDragSourceHelper;
  DragInfo: TSHDragImage;
  lDragSourceHelper2: IDragSourceHelper2;// Needed to get Windows Vista+ style drag hints.
  lNullPoint: TPoint;
begin
  Width := DragImage.Width;
  Height := DragImage.Height;

  // Determine whether the system supports the drag helper interfaces.
  if Assigned(DataObject) and Succeeded(CoCreateInstance(CLSID_DragDropHelper, nil, CLSCTX_INPROC_SERVER,
    IDragSourceHelper, DragSourceHelper)) then
  begin
    Include(FStates, disSystemSupport);
    lNullPoint := Point(0,0);
    if Supports(DragSourceHelper, IDragSourceHelper2, lDragSourceHelper2) then
      lDragSourceHelper2.SetFlags(DSH_ALLOWDROPDESCRIPTIONTEXT);// Show description texts
    // First let the system try to initialze the DragSourceHelper, this works fine for file system objects (CF_HDROP)
    StandardOLEFormat.cfFormat := CF_HDROP;
    if not Succeeded(DataObject.QueryGetData(StandardOLEFormat)) or not Succeeded(DragSourceHelper.InitializeFromWindow(0, lNullPoint, DataObject)) then
    begin
      // Supply the drag source helper with our drag image.
      DragInfo.sizeDragImage.cx := Width;
      DragInfo.sizeDragImage.cy := Height;
      DragInfo.ptOffset.x := Width div 2;
      DragInfo.ptOffset.y := Height div 2;
      //lcl
      //todo: replace CopyImage. Alternatively reimplement Drag support
      {$ifndef INCOMPLETE_WINAPI}
      DragInfo.hbmpDragImage := CopyImage(DragImage.Handle, IMAGE_BITMAP, Width, Height, LR_COPYRETURNORG);
      {$else}
      DragInfo.hbmpDragImage := 0;
      {$endif}
      DragInfo.crColorKey := ColorToRGB(FColorKey);
      if not Succeeded(DragSourceHelper.InitializeFromBitmap(@DragInfo, DataObject)) then
      begin
        DeleteObject(DragInfo.hbmpDragImage);
        Exclude(FStates, disSystemSupport);
      end;
    end;
  end
  else
    Exclude(FStates, disSystemSupport);

  if MMXAvailable and not (disSystemSupport in FStates) then
  begin
    FLastPosition := HotSpot;

    FDragImage := Graphics.TBitmap.Create;
    FDragImage.PixelFormat := pf32Bit;
    FDragImage.Width := Width;
    FDragImage.Height := Height;

    FAlphaImage := Graphics.TBitmap.Create;
    FAlphaImage.PixelFormat := pf32Bit;
    FAlphaImage.Width := Width;
    FAlphaImage.Height := Height;

    FBackImage := Graphics.TBitmap.Create;
    FBackImage.PixelFormat := pf32Bit;
    FBackImage.Width := Width;
    FBackImage.Height := Height;

    // Copy the given drag image and apply pre blend bias if required.
    if FPreBlendBias = 0 then
      with FDragImage do
        BitBlt(Canvas.Handle, 0, 0, Width, Height, DragImage.Canvas.Handle, 0, 0, SRCCOPY)
    else
      AlphaBlend(DragImage.Canvas.Handle, FDragImage.Canvas.Handle, Rect(0, 0, Width, Height), Point(0, 0),
        bmConstantAlpha, 255, FPreBlendBias);

    // Create a proper alpha channel also if no fading is required (transparent parts).
    MakeAlphaChannel(DragImage, FDragImage);

    FImagePosition := ImagePosition;

    // Initially the drag image is hidden and will be shown during the immediately following DragEnter event.
    FStates := FStates + [disInDrag, disHidden, disPrepared];
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragImage.RecaptureBackground(Tree: TCustomControl; R: TRect;
  VisibleRegion: HRGN; CaptureNCArea, ReshowDragImage: Boolean);

// Notification by the drop target tree to update the background image because something in the tree has changed.
// Note: The passed rectangle is given in client coordinates of the current drop target tree (given in Tree).
//       The caller does not check if the given rectangle is actually within the drag image. Hence this method must do
//       all the checks.
// This method does nothing if the system manages the drag image.
{$ifndef INCOMPLETE_WINAPI}
var
  DragRect,
  ClipRect: TRect;
  PaintTarget: TPoint;
  PaintOptions: TVTInternalPaintOptions;
  ScreenDC: HDC;
{$endif}

begin
  //todo: reimplement
  {$ifndef INCOMPLETE_WINAPI}
  // Recapturing means we want the tree to paint the new part into our back bitmap instead to the screen.
  if Visible then
  begin
    // Create the minimum rectangle to be recaptured.
    MapWindowPoints(Tree.Handle, 0, R, 2);
    DragRect := GetDragImageRect;
    IntersectRect(R, R, DragRect);

    OffsetRgn(VisibleRegion, -DragRect.Left, -DragRect.Top);

    // The target position for painting in the drag image is relative and can be determined from screen coordinates too.
    PaintTarget.X := R.Left - DragRect.Left;
    PaintTarget.Y := R.Top - DragRect.Top;

    // The source rectangle is determined by the offsets in the tree.
    MapWindowPoints(0, Tree.Handle, R, 2);
    OffsetRect(R, -TBaseVirtualTree(Tree).OffsetX, -TBaseVirtualTree(Tree).OffsetY);

    // Finally let the tree paint the relevant part and upate the drag image on screen.
    PaintOptions := [poBackground, poColumnColor, poDrawFocusRect, poDrawDropMark, poDrawSelection, poGridLines];
    with FBackImage do
    begin
      ClipRect.TopLeft := PaintTarget;
      ClipRect.Right := ClipRect.Left + R.Right - R.Left;
      ClipRect.Bottom := ClipRect.Top + R.Bottom - R.Top;
      ClipCanvas(Canvas, ClipRect, VisibleRegion);
      TBaseVirtualTree(Tree).PaintTree(Canvas, R, PaintTarget, PaintOptions);

      if CaptureNCArea then
      begin
        // For the non-client area we only need the visible region of the window as limit for painting.
        SelectClipRgn(Canvas.Handle, VisibleRegion);
        // Since WM_PRINT cannot be given a position where to draw we simply move the window origin and
        // get the same effect.
        GetWindowRect(Tree.Handle, ClipRect);
        {$ifdef UseSetCanvasOrigin}
        SetCanvasOrigin(Canvas, DragRect.Left - ClipRect.Left, DragRect.Top - ClipRect.Top);
        {$else}
        SetWindowOrgEx(Canvas.Handle, DragRect.Left - ClipRect.Left, DragRect.Top - ClipRect.Top, nil);
        {$endif}
        //todo: see what todo here
        //Tree.Perform(WM_PRINT, WPARAM(Canvas.Handle), PRF_NONCLIENT);
        {$ifdef UseSetCanvasOrigin}
        SetCanvasOrigin(Canvas, 0, 0);
        {$else}
        SetWindowOrgEx(Canvas.Handle, 0, 0, nil);
        {$endif}
      end;
      SelectClipRgn(Canvas.Handle, 0);

      if ReshowDragImage then
      begin
        GDIFlush;
        ScreenDC := GetDC(0);
        try
          InternalShowDragImage(ScreenDC);
        finally
          ReleaseDC(0, ScreenDC);
        end;
      end;
    end;
  end;
  {$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TVTDragImage.ShowDragImage;

// Shows the drag image after it has been hidden by HideDragImage.
// Note: there might be a new background now.
// Also this method does nothing if the system manages the drag image.
{$ifndef INCOMPLETE_WINAPI}
var
  ScreenDC: HDC;
{$endif}

begin
  {$ifndef INCOMPLETE_WINAPI}
  if FStates * [disInDrag, disHidden, disPrepared, disSystemSupport] = [disInDrag, disHidden, disPrepared] then
  begin
    Exclude(FStates, disHidden);

    GDIFlush;
    ScreenDC := GetDC(0);
    try
      BitBlt(FBackImage.Canvas.Handle, 0, 0, FBackImage.Width, FBackImage.Height, ScreenDC, FImagePosition.X,
        FImagePosition.Y, SRCCOPY);

      InternalShowDragImage(ScreenDC);
    finally
      ReleaseDC(0, ScreenDC);
    end;
  end;
  {$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

function TVTDragImage.WillMove(const P: TPoint): Boolean;

// This method determines whether the drag image would "physically" move when DragTo would be called with the same
// target point.
// Always returns False if the system drag image support is available.

begin
  Result := Visible;
  if Result then
  begin
    // Determine distances to move the drag image. Take care for restrictions.
    case FRestriction of
      dmrHorizontalOnly:
        Result := FLastPosition.X <> P.X;
      dmrVerticalOnly:
        Result := FLastPosition.Y <> P.Y;
    else // dmrNone
      Result := (FLastPosition.X <> P.X) or (FLastPosition.Y <> P.Y);
    end;
  end;
end;

end.
