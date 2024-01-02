unit VirtualTrees.Utils;

// The contents of this file are subject to the Mozilla Public License
// Version 1.1 (the "License"); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at http://www.mozilla.org/MPL/
//
// Alternatively, you may redistribute this library, use and/or modify it under the terms of the
// GNU Lesser General Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any later version.
// You may obtain a copy of the LGPL at http://www.gnu.org/copyleft/.
//
// Software distributed under the License is distributed on an "AS IS" basis,
// WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the
// specific language governing rights and limitations under the License.
//
// The original code is VirtualTrees.pas, released September 30, 2000.
//
// The initial developer of the original code is digital publishing AG (Munich, Germany, www.digitalpublishing.de),
// written by Mike Lischke (public@soft-gems.net, www.soft-gems.net).
//
// Portions created by digital publishing AG are Copyright
// (C) 1999-2001 digital publishing AG. All Rights Reserved.
//----------------------------------------------------------------------------------------------------------------------

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  DelphiCompat, Types, LCLIntf, LCLType, Graphics, LclExt, SysUtils,
  VirtualTrees.Types, StrUtils, Math;

type
  /// <summary>
  /// Describes the mode how to blend pixels.
  /// </summary>
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

{$IFDEF DelphiSupport}
procedure DrawImage(ImageList: TCustomImageList; Index: Integer; Canvas: TCanvas; X, Y: Integer; Style: Cardinal; Enabled: Boolean);
{$ENDIF}

/// <summary>
/// Adjusts the given string S so that it fits into the given width. EllipsisWidth gives the width of
/// the three points to be added to the shorted string. If this value is 0 then it will be determined implicitely.
/// For higher speed (and multiple entries to be shorted) specify this value explicitely.
/// </summary>
function ShortenString(DC: HDC; const S: string; Width: TDimension; EllipsisWidth: TDimension = 0): string; overload;

{$IFDEF DelphiSupport}
//--------------------------
// ShortenString similar to VTV's version, except:
// -- Does not assume using three dots or any particular character for ellipsis
// -- Does not add ellipsis to string, so could be added anywhere
// -- Requires EllipsisWidth, and zero does nothing special
// Returns:
//   ShortenedString as var param
//   True if shortened (ie: add ellipsis somewhere), otherwise false
function ShortenString(TargetCanvasDC: HDC; const StrIn: string; const AllowedWidth_px: Integer; const EllipsisWidth_px: Integer; var ShortenedString: string): boolean; overload;
{$ENDIF}

/// <summary>
/// Wrap the given string S so that it fits into a space of given width.
/// RTL determines if right-to-left reading is active.
/// </summary>
function WrapString(DC: HDC; const S: string; const Bounds: TRect; RTL: Boolean; DrawFormat: Cardinal): string;

/// <summary>
/// Calculates bounds of a drawing rectangle for the given string
/// </summary>
procedure GetStringDrawRect(DC: HDC; const S: string; var Bounds: TRect; DrawFormat: Cardinal);

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
procedure FillDragRectangles(DragWidth, DragHeight, DeltaX, DeltaY: Integer; var RClip, RScroll, RSamp1, RSamp2, RDraw1, RDraw2: TRect);

{$IFDEF DelphiSupport}
/// <summary>
/// Attaches a bitmap as drag image to an IDataObject, see issue #405
/// <code>
/// Usage: Set property DragImageKind to diNoImage, in your event handler OnCreateDataObject
/// <para>       call VirtualTrees.Utils.ApplyDragImage() with your `IDataObject` and your bitmap.</para>
/// </code>
/// </summary>
procedure ApplyDragImage(const pDataObject: IDataObject; pBitmap: TBitmap);
{$ENDIF}

/// <summary>
/// Returns True if the mouse cursor is currently visible and False in case it is suppressed.
/// Useful when doing hot-tracking on touchscreens, see issue #766
/// </summary>
function IsMouseCursorVisible(): Boolean;

{$IFDEF DelphiSupport}
procedure ScaleImageList(const ImgList: TImageList; M, D: Integer);

/// <summary>
/// Returns True if the high contrast theme is anabled in the system settings, False otherwise.
/// </summary>
{$ENDIF}

function IsHighContrastEnabled(): Boolean;

/// <summary>
/// Divide depend of parameter type uses different division operator:
/// <code>Integer uses div</code>
/// <code>Single uses /</code>
/// </summary>
function Divide(const Dimension: Integer; const DivideBy: Integer): Integer; overload; inline;

{$IFDEF DelphiSupport}
/// <summary>
/// Divide depend of parameter type uses different division operator:
/// <code>Integer uses div</code>
/// <code>Single uses /</code>
/// </summary>
function Divide(const Dimension: Single; const DivideBy: Integer): Single; overload; inline;
{$ENDIF}

function CalculateScanline(Bits: Pointer; Width, Height, Row: Integer): Pointer;

function GetBitmapBitsFromBitmap(Bitmap: HBITMAP): Pointer;

implementation

{$IFDEF DelphiSupport}
procedure ApplyDragImage(const pDataObject: IDataObject; pBitmap: TBitmap);
var
  DragSourceHelper: IDragSourceHelper;
  DragInfo: SHDRAGIMAGE;
  lDragSourceHelper2: IDragSourceHelper2;// Needed to get Windows Vista+ style drag hints.
  lNullPoint: TPoint;
begin

  if Assigned(pDataObject) and Succeeded(CoCreateInstance(CLSID_DragDropHelper, nil, CLSCTX_INPROC_SERVER,
    IID_IDragSourceHelper, DragSourceHelper)) then
  begin
    if Supports(DragSourceHelper, IDragSourceHelper2, lDragSourceHelper2) then
      lDragSourceHelper2.SetFlags(DSH_ALLOWDROPDESCRIPTIONTEXT);// Show description texts
    if not Succeeded(DragSourceHelper.InitializeFromWindow(0, lNullPoint, pDataObject)) then begin   // First let the system try to initialze the DragSourceHelper, this works fine e.g. for file system objects
      // Create drag image

      if not Assigned(pBitmap) then
        Exit();
      DragInfo.crColorKey := clBlack;
      DragInfo.sizeDragImage.cx := pBitmap.Width;
      DragInfo.sizeDragImage.cy := pBitmap.Height;
      DragInfo.ptOffset.X := pBitmap.Width div 8;
      DragInfo.ptOffset.Y := pBitmap.Height div 10;
      DragInfo.hbmpDragImage := CopyImage(pBitmap.Handle, IMAGE_BITMAP, pBitmap.Width, pBitmap.Height, LR_COPYRETURNORG);
      if not Succeeded(DragSourceHelper.InitializeFromBitmap(@DragInfo, pDataObject)) then
        DeleteObject(DragInfo.hbmpDragImage);
    end;//if not InitializeFromWindow
  end;
end;
{$ENDIF}

{$i vtgraphicsi.inc}

function OrderRect(const R: TRect): TRect;

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

//var
//  P: TPoint;

begin
  //P := Point(X, Y);
  //LPtoDP(Canvas.Handle, P, 1);// No longer used, see issue #608
  {$ifndef INCOMPLETE_WINAPI}  
  //SetBrushOrgEx(Canvas.Handle, P.X, P.Y, nil);
  SetBrushOrgEx(Canvas.Handle, X, Y, nil);
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


procedure GetStringDrawRect(DC: HDC; const S: string; var Bounds: TRect; DrawFormat: Cardinal);

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
function ShortenString(DC: HDC; const S: string; Width: TDimension; EllipsisWidth: TDimension = 0): string;

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
function ShortenString(DC: HDC; const S: string; Width: TDimension; EllipsisWidth: TDimension = 0): string;

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

{$IFDEF DelphiSupport}
//--------------------------
function ShortenString(TargetCanvasDC: HDC; const StrIn: string; const AllowedWidth_px: Integer; const EllipsisWidth_px: Integer; var ShortenedString: string): boolean;
//--------------------------
var
  Size_px_x_px: TSize;  // cx, cy
  StrInLen: Integer;
  LoLen, HiLen, TestLen, TestWidth_px: Integer;

begin
  StrInLen := Length(StrIn);
  if (StrInLen = 0) then
  Begin
    ShortenedString := '';
    Result := False;  // No ellipsis needed since original was empty
  End else
  if (AllowedWidth_px <= 0) then
  Begin
    ShortenedString := '';
    Result := True;  // Ellipsis needed, since non-empty string replaced.
                     // But likely will get clipped if AllowedWidth is really zero
  End else
  begin
      // Do a binary search for the optimal string length which fits into the given width.
      LoLen := 0;
      TestLen := 0;
      TestWidth_px := AllowedWidth_px;
      HiLen := StrInLen;

      while LoLen < HiLen do
      begin
        TestLen := (LoLen + HiLen + 1) shr 1;  // Test average of Lo and Hi

        GetTextExtentPoint32W(TargetCanvasDC, PWideChar(StrIn), TestLen, Size_px_x_px);
        TestWidth_px := Size_px_x_px.cx + EllipsisWidth_px;

        if TestWidth_px <= AllowedWidth_px then
        Begin
          LoLen := TestLen      // Low bound must be at least as much as TestLen
        End else
        Begin
          HiLen := TestLen - 1; // Continue until Hi bound string produces width below AllowedWidth_px
        End;
      end;

      if TestWidth_px <= AllowedWidth_px then
      Begin
        LoLen := TestLen;
      End;
      if LoLen >= StrInLen then
      Begin
        ShortenedString := StrIn;
        Result := False;
      End else if AllowedWidth_px <= EllipsisWidth_px then
      Begin
        ShortenedString := '';
        Result      := True; // Even though Ellipsis won't fit in AllowedWidth,
                             // let clipping decide how much of ellipsis to show
      End else
      Begin
        ShortenedString := Copy(StrIn, 1, LoLen);
        Result := True;
      End;
    end;
end;
{$ENDIF}

//----------------------------------------------------------------------------------------------------------------------


function WrapString(DC: HDC; const S: string; const Bounds: TRect; RTL: Boolean; DrawFormat: Cardinal): string;

var
  Width,
  Len,
  WordCounter,
  WordsInLine,
  I, W: Integer;
  Buffer,
  Line: string;
  Words: array of string;
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


procedure FillDragRectangles(DragWidth, DragHeight, DeltaX, DeltaY: Integer; var RClip, RScroll, RSamp1, RSamp2, RDraw1, RDraw2: TRect);

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

{$IFDEF DelphiSupport}
type
  TCustomImageListCast = class(TCustomImageList);

procedure DrawImage(ImageList: TCustomImageList; Index: Integer; Canvas: TCanvas; X, Y: Integer; Style: Cardinal; Enabled: Boolean);
begin
  TCustomImageListCast(ImageList).DoDraw(Index, Canvas, X, Y, Style, Enabled)
end;
{$ENDIF}

//----------------------------------------------------------------------------------------------------------------------

function IsMouseCursorVisible(): Boolean;
{$IFDEF DelphiSupport}
var
  CI: TCursorInfo;
{$ENDIF}
begin
  Result := true;
  {$IFDEF DelphiSupport}
  CI.cbSize := SizeOf(CI);
  Result := GetCursorInfo(CI) and (CI.flags = CURSOR_SHOWING);
  // 0                     Hidden
  // CURSOR_SHOWING (1)    Visible
  // CURSOR_SUPPRESSED (2) Touch/Pen Input (Windows 8+)
  // https://msdn.microsoft.com/en-us/library/windows/desktop/ms648381(v=vs.85).aspx
  {$ENDIF}
end;

//----------------------------------------------------------------------------------------------------------------------

{$IFDEF DelphiSupport}
procedure ScaleImageList(const ImgList: TImageList; M, D: Integer);
var
  ii : integer;
  mb, ib, sib, smb : TBitmap;
  TmpImgList : TImageList;
begin
  if M <= D then Exit;

  //clear images
  TmpImgList := TImageList.Create(nil);
  try
    TmpImgList.Assign(ImgList);

    ImgList.Clear;
    ImgList.SetSize(MulDiv(ImgList.Width, M, D), MulDiv(ImgList.Height, M, D));

    //add images back to original ImageList stretched (if DPI scaling > 150%) or centered (if DPI scaling <= 150%)
    for ii := 0 to -1 + TmpImgList.Count do
    begin
      ib := TBitmap.Create;
      mb := TBitmap.Create;
      try
        ib.SetSize(TmpImgList.Width, TmpImgList.Height);
        ib.Canvas.FillRect(ib.Canvas.ClipRect);

        mb.SetSize(TmpImgList.Width, TmpImgList.Height);
        mb.Canvas.FillRect(mb.Canvas.ClipRect);

        ImageList_DrawEx(TmpImgList.Handle, ii, ib.Canvas.Handle, 0, 0, ib.Width, ib.Height, CLR_NONE, CLR_NONE, ILD_NORMAL);
        ImageList_DrawEx(TmpImgList.Handle, ii, mb.Canvas.Handle, 0, 0, mb.Width, mb.Height, CLR_NONE, CLR_NONE, ILD_MASK);

        sib := TBitmap.Create; //stretched (or centered) image
        smb := TBitmap.Create; //stretched (or centered) mask
        try
          sib.SetSize(ImgList.Width, ImgList.Height);
          sib.Canvas.FillRect(sib.Canvas.ClipRect);
          smb.SetSize(ImgList.Width, ImgList.Height);
          smb.Canvas.FillRect(smb.Canvas.ClipRect);

          if M * 100 / D >= 150 then //stretch if >= 150%
          begin
            sib.Canvas.StretchDraw(Rect(0, 0, sib.Width, sib.Width), ib);
            smb.Canvas.StretchDraw(Rect(0, 0, smb.Width, smb.Width), mb);
          end
          else //center if < 150%
          begin
            sib.Canvas.Draw((sib.Width - ib.Width) DIV 2, (sib.Height - ib.Height) DIV 2, ib);
            smb.Canvas.Draw((smb.Width - mb.Width) DIV 2, (smb.Height - mb.Height) DIV 2, mb);
          end;
          ImgList.Add(sib, smb);
        finally
          sib.Free;
          smb.Free;
        end;
    finally
        ib.Free;
        mb.Free;
      end;
    end;
  finally
    TmpImgList.Free;
  end;
end;
{$ENDIF}

//----------------------------------------------------------------------------------------------------------------------

function IsHighContrastEnabled(): Boolean;
{$IFDEF DelphiSupport}
var
  l: HIGHCONTRAST;
{$ENDIF}
begin
  {$IFDEF DelphiSupport}
  l.cbSize := SizeOf(l);
  Result := SystemParametersInfo(SPI_GETHIGHCONTRAST, 0, @l, 0) and ((l.dwFlags and HCF_HIGHCONTRASTON) <> 0);
  {$ENDIF}
  //lcl: for now always false
  Result := False;
end;

{$IFDEF DelphiSupport}
function Divide(const Dimension: Single; const DivideBy: Integer): Single;
begin
  Result:= Dimension / DivideBy;
end;
{$ENDIF}

//----------------------------------------------------------------------------------------------------------------------

function Divide(const Dimension: Integer; const DivideBy: Integer): Integer;
begin
  Result:= Dimension div DivideBy;
end;

end.
