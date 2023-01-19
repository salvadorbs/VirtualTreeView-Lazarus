unit VirtualTrees.Utils;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  DelphiCompat, Types, LCLIntf, LCLType, Graphics, LclExt, SysUtils,
  VirtualTrees.Types, StrUtils, Math;

type
  // Describes the mode how to blend pixels.
  TBlendMode = (
    bmConstantAlpha,         // apply given constant alpha
    bmPerPixelAlpha,         // use alpha value of the source pixel
    bmMasterAlpha,           // use alpha value of source pixel and multiply it with the constant alpha value
    bmConstantAlphaAndColor  // blend the destination color with the given constant color und the constant alpha value
  );

procedure AlphaBlend(Source, Destination: HDC; R: TRect; Target: TPoint; Mode: TBlendMode; ConstantAlpha, Bias: Integer);
function GetRGBColor(Value: TColor): DWORD;
{$ifdef EnablePrint}
procedure PrtStretchDrawDIB(Canvas: TCanvas; DestRect: TRect; ABitmap: TBitmap);
{$endif}

procedure SetBrushOrigin(Canvas: TCanvas; X, Y: Integer); inline;


procedure SetCanvasOrigin(Canvas: TCanvas; X, Y: Integer); inline;

/// <summary>
/// Clip a given canvas to ClipRect while transforming the given rect to device coordinates.
/// </summary>
procedure ClipCanvas(Canvas: TCanvas; ClipRect: TRect; VisibleRegion: HRGN = 0);

/// <summary>
/// Adjusts the given string S so that it fits into the given width. EllipsisWidth gives the width of
/// the three points to be added to the shorted string. If this value is 0 then it will be determined implicitely.
/// For higher speed (and multiple entries to be shorted) specify this value explicitely.
/// </summary>
function ShortenString(DC: HDC; const S: string; Width: TDimension; EllipsisWidth: TDimension = 0): string;

/// <summary>
/// Wrap the given string S so that it fits into a space of given width.
/// RTL determines if right-to-left reading is active.
/// </summary>
function WrapString(DC: HDC; const S: string; const Bounds: TRect; RTL: Boolean; DrawFormat: Cardinal): string;

/// <summary>
/// Calculates bounds of a drawing rectangle for the given string
/// </summary>
procedure GetStringDrawRect(DC: HDC; const S: String; var Bounds: TRect; DrawFormat: Cardinal);

/// <summary>
/// Converts the incoming rectangle so that left and top are always less than or equal to right and bottom.
/// </summary>
function OrderRect(const R: TRect): TRect;

/// <summary>
/// Fills the given rectangles with values which can be used while dragging around an image
/// </summary>
/// <remarks>
/// (used in DragMove of the drag manager and DragTo of the header columns).
/// </remarks>
procedure FillDragRectangles(DragWidth, DragHeight, DeltaX, DeltaY: Integer; out RClip, RScroll, RSamp1, RSamp2, RDraw1, RDraw2: TRect);

/// <summary>
/// Divide depend of parameter type uses different division operator:
/// <code>Integer uses div</code>
/// <code>Single uses /</code>
/// </summary>
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

//----------------------------------------------------------------------------------------------------------------------

procedure GetStringDrawRect(DC: HDC; const S: String; var Bounds: TRect; DrawFormat: Cardinal);

// Calculates bounds of a drawing rectangle for the given string

begin
  Bounds.Right := Bounds.Left + 1;
  Bounds.Bottom := Bounds.Top + 1;

  DrawText(DC, PChar(S), Length(S), Bounds, DrawFormat or DT_CALCRECT);
end;

//----------------------------------------------------------------------------------------------------------------------

//todo: Unify the procedure or change to widgetset specific
// Currently the UTF-8 version is broken.
// the unicode version is used when all winapi is available

{$ifndef INCOMPLETE_WINAPI}
function ShortenString(DC: HDC; const S: String; Width: TDimension; EllipsisWidth: TDimension = 0): String;

// Adjusts the given string S so that it fits into the given width. EllipsisWidth gives the width of
// the three points to be added to the shorted string. If this value is 0 then it will be determined implicitely.
// For higher speed (and multiple entries to be shorted) specify this value explicitely.
// Note: It is assumed that the string really needs shortage. Check this in advance.

var
  Size: TSize;
  Len: Integer;
  L, H, N, W: Integer;
  WideStr: UnicodeString;
begin
  WideStr := UTF8Decode(S);
  Len := Length(WideStr);
  if (Len = 0) or (Width <= 0) then
    Result := ''
  else
  begin
    // Determine width of triple point using the current DC settings (if not already done).
    if EllipsisWidth = 0 then
    begin
      GetTextExtentPoint32W(DC, '...', 3, Size);
      EllipsisWidth := Size.cx;
    end;

    if Width <= EllipsisWidth then
      Result := ''
    else
    begin
      // Do a binary search for the optimal string length which fits into the given width.
      L := 0;
      H := Len - 1;
      while L < H do
      begin
        N := (L + H + 1) shr 1;
        GetTextExtentPoint32W(DC, PWideChar(WideStr), N, Size);
        W := Size.cx + EllipsisWidth;
        if W <= Width then
          L := N
        else
          H := N - 1;
      end;
      Result := UTF8Encode(Copy(WideStr, 1, L) + '...');
    end;
  end;
end;
{$else}
function ShortenString(DC: HDC; const S: String; Width: Integer; EllipsisWidth: Integer = 0): String;

// Adjusts the given string S so that it fits into the given width. EllipsisWidth gives the width of
// the three points to be added to the shorted string. If this value is 0 then it will be determined implicitely.
// For higher speed (and multiple entries to be shorted) specify this value explicitely.
// Note: It is assumed that the string really needs shortage. Check this in advance.

var
  Size: TSize;
  Len: Integer;
  L, H, N, W: Integer;
begin
  Len := Length(S);
  if (Len = 0) or (Width <= 0) then
    Result := ''
  else
  begin
    // Determine width of triple point using the current DC settings (if not already done).
    if EllipsisWidth = 0 then
    begin
      GetTextExtentPoint32(DC, '...', 3, Size);
      EllipsisWidth := Size.cx;
    end;

    if Width <= EllipsisWidth then
      Result := ''
    else
    begin
      // Do a binary search for the optimal string length which fits into the given width.
      L := 0;
      H := Len - 1;
      while L < H do
      begin
        N := (L + H + 1) shr 1;
        GetTextExtentPoint32(DC, PAnsiChar(S), N, Size);
        W := Size.cx + EllipsisWidth;
        if W <= Width then
          L := N
        else
          H := N - 1;
      end;
      Result := Copy(S, 1, L) + '...';
    end;
  end;
end;
{$endif}

//----------------------------------------------------------------------------------------------------------------------

function WrapString(DC: HDC; const S: String; const Bounds: TRect; RTL: Boolean;
  DrawFormat: Cardinal): String;

// Wrap the given string S so that it fits into a space of given width.
// RTL determines if right-to-left reading is active.

var
  Width,
  Len,
  WordCounter,
  WordsInLine,
  I, W: Integer;
  Buffer,
  Line: String;
  Words: array of String;
  R: TRect;

begin
  Result := '';
  // Leading and trailing are ignored.
  Buffer := Trim(S);
  Len := Length(Buffer);
  if Len < 1 then
    Exit;

  Width := Bounds.Right - Bounds.Left;
  R := Rect(0, 0, 0, 0);

  // Count the words in the string.
  WordCounter := 1;
  for I := 1 to Len do
    if Buffer[I] = ' ' then
      Inc(WordCounter);
  SetLength(Words, WordCounter);

  if RTL then
  begin
    // At first we split the string into words with the last word being the
    // first element in Words.
    W := 0;
    for I := 1 to Len do
      if Buffer[I] = ' ' then
        Inc(W)
      else
        Words[W] := Words[W] + Buffer[I];

    // Compose Result.
    while WordCounter > 0 do
    begin
      WordsInLine := 0;
      Line := '';

      while WordCounter > 0 do
      begin
        GetStringDrawRect(DC, Line + IfThen(WordsInLine > 0, ' ', '') + Words[WordCounter - 1], R, DrawFormat);
        if R.Right > Width then
        begin
          // If at least one word fits into this line then continue with the next line.
          if WordsInLine > 0 then
            Break;

          Buffer := Words[WordCounter - 1];
          if Len > 1 then
          begin
            for Len := Length(Buffer) - 1 downto 2 do
            begin
              GetStringDrawRect(DC, RightStr(Buffer, Len), R, DrawFormat);
              if R.Right <= Width then
                Break;
            end;
          end
          else
            Len := Length(Buffer);

          Line := Line + RightStr(Buffer, Max(Len, 1));
          Words[WordCounter - 1] := LeftStr(Buffer, Length(Buffer) - Max(Len, 1));
          if Words[WordCounter - 1] = '' then
            Dec(WordCounter);
          Break;
        end
        else
        begin
          Dec(WordCounter);
          Line := Words[WordCounter] + IfThen(WordsInLine > 0, ' ', '') + Line;
          Inc(WordsInLine);
        end;
      end;

      Result := Result + Line + LineEnding;
    end;
  end
  else
  begin
    // At first we split the string into words with the last word being the
    // first element in Words.
    W := WordCounter - 1;
    for I := 1 to Len do
      if Buffer[I] = ' ' then
        Dec(W)
      else
        Words[W] := Words[W] + Buffer[I];

    // Compose Result.
    while WordCounter > 0 do
    begin
      WordsInLine := 0;
      Line := '';

      while WordCounter > 0 do
      begin
        GetStringDrawRect(DC, Line + IfThen(WordsInLine > 0, ' ', '') + Words[WordCounter - 1], R, DrawFormat);
        if R.Right > Width then
        begin
          // If at least one word fits into this line then continue with the next line.
          if WordsInLine > 0 then
            Break;

          Buffer := Words[WordCounter - 1];
          if Len > 1 then
          begin
            for Len := Length(Buffer) - 1 downto 2 do
            begin
              GetStringDrawRect(DC, LeftStr(Buffer, Len), R, DrawFormat);
              if R.Right <= Width then
                Break;
            end;
          end
          else
            Len := Length(Buffer);

          Line := Line + LeftStr(Buffer, Max(Len, 1));
          Words[WordCounter - 1] := RightStr(Buffer, Length(Buffer) - Max(Len, 1));
          if Words[WordCounter - 1] = '' then
            Dec(WordCounter);
          Break;
        end
        else
        begin
          Dec(WordCounter);
          Line := Line + IfThen(WordsInLine > 0, ' ', '') + Words[WordCounter];
          Inc(WordsInLine);
        end;
      end;

      Result := Result + Line + LineEnding;
    end;
  end;

  Len := Length(Result) - Length(LineEnding);
  if CompareByte(Result[Len + 1], String(LineEnding)[1], Length(LineEnding)) = 0 then
    SetLength(Result, Len);
end;

end.

