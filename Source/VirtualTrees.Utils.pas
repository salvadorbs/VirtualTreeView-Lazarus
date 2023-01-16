unit VirtualTrees.Utils;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  DelphiCompat, Types, LCLIntf, LCLType, Graphics;

type
  // Describes the mode how to blend pixels.
  TBlendMode = (
    bmConstantAlpha,         // apply given constant alpha
    bmPerPixelAlpha,         // use alpha value of the source pixel
    bmMasterAlpha,           // use alpha value of source pixel and multiply it with the constant alpha value
    bmConstantAlphaAndColor  // blend the destination color with the given constant color und the constant alpha value
  );

procedure AlphaBlend(Source, Destination: HDC; const R: TRect; const Target: TPoint; Mode: TBlendMode; ConstantAlpha, Bias: Integer);
function GetRGBColor(Value: TColor): DWORD;
{$ifdef EnablePrint}
procedure PrtStretchDrawDIB(Canvas: TCanvas; DestRect: TRect; ABitmap: TBitmap);
{$endif}

procedure SetBrushOrigin(Canvas: TCanvas; X, Y: Integer); inline;


procedure SetCanvasOrigin(Canvas: TCanvas; X, Y: Integer); inline;

procedure ClipCanvas(Canvas: TCanvas; ClipRect: TRect; VisibleRegion: HRGN = 0);

function OrderRect(const R: TRect): TRect;

procedure FillDragRectangles(DragWidth, DragHeight, DeltaX, DeltaY: Integer; out RClip, RScroll, RSamp1, RSamp2, RDraw1,
  RDraw2: TRect);

function Divide(const Dimension: Integer; const DivideBy: Integer): Integer; overload; inline;

function CalculateScanline(Bits: Pointer; Width, Height, Row: Integer): Pointer;

function GetBitmapBitsFromBitmap(Bitmap: HBITMAP): Pointer;

implementation

{$i vtgraphicsi.inc}

//----------------------------------------------------------------------------------------------------------------------

function GetRGBColor(Value: TColor): DWORD;

// Little helper to convert a Delphi color to an image list color.

begin
  Result := ColorToRGB(Value);
  case Result of
    clNone:
      Result := CLR_NONE;
    clDefault:
      Result := CLR_DEFAULT;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

{$ifdef EnablePrint}
procedure PrtStretchDrawDIB(Canvas: TCanvas; DestRect: TRect; ABitmap: TBitmap);

// Stretch draw on to the new canvas.

var
  Header,
  Bits: Pointer;
  HeaderSize,
  BitsSize: Cardinal;

begin
  GetDIBSizes(ABitmap.Handle, HeaderSize, BitsSize);

  GetMem(Header, HeaderSize);
  GetMem(Bits, BitsSize);
  try
    GetDIB(ABitmap.Handle, ABitmap.Palette, Header^, Bits^);
    StretchDIBits(Canvas.Handle, DestRect.Left, DestRect.Top, DestRect.Right - DestRect.Left, DestRect.Bottom -
      DestRect.Top, 0, 0, ABitmap.Width, ABitmap.Height, Bits, TBitmapInfo(Header^), DIB_RGB_COLORS, SRCCOPY);
  finally
    FreeMem(Header);
    FreeMem(Bits);
  end;
end;
{$endif}

//----------------------------------------------------------------------------------------------------------------------

procedure FillDragRectangles(DragWidth, DragHeight, DeltaX, DeltaY: Integer; out RClip, RScroll, RSamp1, RSamp2, RDraw1,
  RDraw2: TRect);

// Fills the given rectangles with values which can be used while dragging around an image
// (used in DragMove of the drag manager and DragTo of the header columns).

begin
  // ScrollDC limits
  RClip := Rect(0, 0, DragWidth, DragHeight);
  if DeltaX > 0 then
  begin
    // move to the left
    if DeltaY = 0 then
    begin
      // move only to the left
      // background movement
      RScroll := Rect(0, 0, DragWidth - DeltaX, DragHeight);
      RSamp1 := Rect(0, 0, DeltaX, DragHeight);
      RDraw1 := Rect(DragWidth - DeltaX, 0, DeltaX, DragHeight);
    end
    else
      if DeltaY < 0 then
      begin
        // move to bottom left
        RScroll := Rect(0, -DeltaY, DragWidth - DeltaX, DragHeight);
        RSamp1 := Rect(0, 0, DeltaX, DragHeight);
        RSamp2 := Rect(DeltaX, DragHeight + DeltaY, DragWidth - DeltaX, -DeltaY);
        RDraw1 := Rect(0, 0, DragWidth - DeltaX, -DeltaY);
        RDraw2 := Rect(DragWidth - DeltaX, 0, DeltaX, DragHeight);
      end
      else
      begin
        // move to upper left
        RScroll := Rect(0, 0, DragWidth - DeltaX, DragHeight - DeltaY);
        RSamp1 := Rect(0, 0, DeltaX, DragHeight);
        RSamp2 := Rect(DeltaX, 0, DragWidth - DeltaX, DeltaY);
        RDraw1 := Rect(0, DragHeight - DeltaY, DragWidth - DeltaX, DeltaY);
        RDraw2 := Rect(DragWidth - DeltaX, 0, DeltaX, DragHeight);
      end;
  end
  else
    if DeltaX = 0 then
    begin
      // vertical movement only
      if DeltaY < 0 then
      begin
        // move downwards
        RScroll := Rect(0, -DeltaY, DragWidth, DragHeight);
        RSamp2 := Rect(0, DragHeight + DeltaY, DragWidth, -DeltaY);
        RDraw2 := Rect(0, 0, DragWidth, -DeltaY);
      end
      else
      begin
        // move upwards
        RScroll := Rect(0, 0, DragWidth, DragHeight - DeltaY);
        RSamp2 := Rect(0, 0, DragWidth, DeltaY);
        RDraw2 := Rect(0, DragHeight - DeltaY, DragWidth, DeltaY);
      end;
    end
    else
    begin
      // move to the right
      if DeltaY > 0 then
      begin
        // move up right
        RScroll := Rect(-DeltaX, 0, DragWidth, DragHeight);
        RSamp1 := Rect(0, 0, DragWidth + DeltaX, DeltaY);
        RSamp2 := Rect(DragWidth + DeltaX, 0, -DeltaX, DragHeight);
        RDraw1 := Rect(0, 0, -DeltaX, DragHeight);
        RDraw2 := Rect(-DeltaX, DragHeight - DeltaY, DragWidth + DeltaX, DeltaY);
      end
      else
        if DeltaY = 0 then
        begin
          // to the right only
          RScroll := Rect(-DeltaX, 0, DragWidth, DragHeight);
          RSamp1 := Rect(DragWidth + DeltaX, 0, -DeltaX, DragHeight);
          RDraw1 := Rect(0, 0, -DeltaX, DragHeight);
        end
        else
        begin
          // move down right
          RScroll := Rect(-DeltaX, -DeltaY, DragWidth, DragHeight);
          RSamp1 := Rect(0, DragHeight + DeltaY, DragWidth + DeltaX, -DeltaY);
          RSamp2 := Rect(DragWidth + DeltaX, 0, -DeltaX, DragHeight);
          RDraw1 := Rect(0, 0, -DeltaX, DragHeight);
          RDraw2 := Rect(-DeltaX, 0, DragWidth + DeltaX, -DeltaY);
        end;
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

function Divide(const Dimension: Integer; const DivideBy: Integer): Integer;
begin
  Result:= Dimension div DivideBy;
end;

//----------------------------------------------------------------------------------------------------------------------

function OrderRect(const R: TRect): TRect;

// Converts the incoming rectangle so that left and top are always less than or equal to right and bottom.

begin
  if R.Left < R.Right then
  begin
    Result.Left := R.Left;
    Result.Right := R.Right;
  end
  else
  begin
    Result.Left := R.Right;
    Result.Right := R.Left;
  end;
  if R.Top < R.Bottom then
  begin
    Result.Top := R.Top;
    Result.Bottom := R.Bottom;
  end
  else
  begin
    Result.Top := R.Bottom;
    Result.Bottom := R.Top;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure SetBrushOrigin(Canvas: TCanvas; X, Y: Integer);

// Set the brush origin of a given canvas.

var
  P: TPoint;

begin
  P := Point(X, Y);
  LPtoDP(Canvas.Handle, P, 1);
  {$ifndef INCOMPLETE_WINAPI}
  SetBrushOrgEx(Canvas.Handle, P.X, P.Y, nil);
  {$endif}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure SetCanvasOrigin(Canvas: TCanvas; X, Y: Integer);

// Set the coordinate space origin of a given canvas.

var
  P: TPoint;

begin
  // Reset origin as otherwise we would accumulate the origin shifts when calling LPtoDP.
  SetWindowOrgEx(Canvas.Handle, 0, 0, nil);

  // The shifting is expected in physical points, so we have to transform them accordingly.
  P := Point(X, Y);
  LPtoDP(Canvas.Handle, P, 1);

  // Do the shift.
  SetWindowOrgEx(Canvas.Handle, P.X, P.Y, nil);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure ClipCanvas(Canvas: TCanvas; ClipRect: TRect; VisibleRegion: HRGN = 0);

// Clip a given canvas to ClipRect while transforming the given rect to device coordinates.

var
  ClipRegion: HRGN;

begin
  // Regions expect their coordinates in device coordinates, hence we have to transform the region rectangle.
  LPtoDP(Canvas.Handle, ClipRect, 2);
  ClipRegion := CreateRectRgnIndirect(ClipRect);
  if VisibleRegion <> 0 then
    CombineRgn(ClipRegion, ClipRegion, VisibleRegion, RGN_AND);
  SelectClipRgn(Canvas.Handle, ClipRegion);
  DeleteObject(ClipRegion);
end;

end.
