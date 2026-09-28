uses
  Gtk3Objects, LazGdk3, LazCairo1;

procedure AlphaBlend(Source, Destination: HDC; const R: TRect; const Target: TPoint; Mode: TBlendMode; ConstantAlpha, Bias: Integer);

  function GetContext(GtkDC: TGtk3DeviceContext): Pcairo_t;
  begin
    Result := nil;
    { gdk_cairo_create() is deprecated in GTK3 but still provided by the bindings and used by the LCL itself. }
    if (GtkDC <> nil) and (GtkDC.Window <> nil) then
      Result := gdk_cairo_create(GtkDC.Window);
  end;

var
  DestDC: TGtk3DeviceContext absolute Destination;
  DestContext: Pcairo_t;
begin
  case Mode of
    bmConstantAlpha,
    bmPerPixelAlpha,
    bmMasterAlpha:
      begin
        { VirtualTreeView only uses bmConstantAlphaAndColor, a plain copy is a safe fallback for the others. }
        BitBlt(Destination, Target.X, Target.Y, R.Right - R.Left, R.Bottom - R.Top, Source, R.Left, R.Top, SRCCOPY);
      end;
    bmConstantAlphaAndColor:
      begin
        DestContext := GetContext(DestDC);
        if DestContext <> nil then
        begin
          cairo_set_source_rgba(DestContext,
            (Bias and $000000FF) / 255,
            ((Bias shr 8) and $000000FF) / 255,
            ((Bias shr 16) and $000000FF) / 255,
            ConstantAlpha / 255
            );
          cairo_rectangle(DestContext, R.Left + Target.x, R.Top + Target.y,
            R.Right - R.Left, R.Bottom - R.Top);
          cairo_fill(DestContext);

          cairo_destroy(DestContext);
        end;
      end;
  end;
end;

function CalculateScanline(Bits: Pointer; Width, Height, Row: Integer): Pointer;
begin
  Result := nil;
end;

function GetBitmapBitsFromBitmap(Bitmap: HBITMAP): Pointer;
begin
  Result := nil;
end;
