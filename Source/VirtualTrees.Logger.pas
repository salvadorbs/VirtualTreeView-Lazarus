unit VirtualTrees.Logger;

{$mode delphi}

interface

uses
  Graphics, Types, Classes, SysUtils;

type

  TDebugEnum = (lcDebug, lcError, lcInfo, lcWarning, lcEvents, lcUser,
    lcVTEvents, lcPaint, lcPaintHeader, lcDummyFunctions, lcMessages,
    lcPaintSelection, lcSetCursor, lcPaintBitmap, lcScroll, lcPaintDetails,
    lcCheck, lcEditLink, lcEraseBkgnd, lcColumnPosition, lcTimer, lcDrag,
    lcOle, lcPanning, lcHeaderOffset, lcSelection, lcAlphaBlend, lcHint, lcMouseEvent);

  TDebugClasses = Set of TDebugEnum;

  { Logger }

  Logger = class
  private
    class procedure DebugLn(Classes: TDebugClasses; AText: String);
    class procedure DebugLnValue(Classes: TDebugClasses; AText: String; Args: array of const);
    class procedure DebugLnMultipleValues(Classes: TDebugClasses; AText: String; Args: array of const);
    class procedure DebugLnEnter(Classes: TDebugClasses; const AMethodName,
      AMessage: String);
    class procedure DebugLnExit(Classes: TDebugClasses; const AMethodName,
      AMessage: String);

    class function DebugClassesToString(Classes: TDebugClasses): String;
  public
    class function RectToStr(const ARect: TRect): string;
    class function PointToStr(const APoint: TPoint): string;

    //Send functions
    class procedure Send(Classes: TDebugClasses; const AText: string); overload;
    class procedure Send(Classes: TDebugClasses; const AText, AValue: string); overload;
    class procedure Send(Classes: TDebugClasses; const AText: String; Args: array of const);overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; AValue: integer); overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; AValue: cardinal); overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; AValue: double); overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; AValue: int64); overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; AValue: QWord); overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; AValue: boolean); overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; const ARect: TRect); overload;
    class procedure Send(Classes: TDebugClasses; const AText: string; const APoint: TPoint); overload;
    class procedure SendColor(Classes: TDebugClasses; const AText: string;
      AColor: TColor); overload;
    class procedure SendCallStack(Classes: TDebugClasses; const AText: string); overload;
    class procedure SendError(Classes: TDebugClasses; const AText: string); overload;
    class procedure SendWarning(Classes: TDebugClasses; const AText: string); overload;
    class procedure EnterMethod(Classes: TDebugClasses; const AMethodName: string;
      const AMessage: string = ''); overload;
    class procedure ExitMethod(Classes: TDebugClasses; const AMethodName: string;
      const AMessage: string = ''); overload;
  end;

var
  LogLevel: TDebugClasses = [lcDebug..lcMouseEvent];

implementation

uses
  VirtualTrees, VirtualTrees.BaseTree, LCLProc, LazTracer, TypInfo;

{ Logger }

class procedure Logger.DebugLn(Classes: TDebugClasses; AText: String);
begin
  if Classes * LogLevel <> [] then
    LCLProc.DebugLn(Format('%s%s', [DebugClassesToString(Classes), AText]));
end;

class procedure Logger.DebugLnValue(Classes: TDebugClasses; AText: String;
  Args: array of const);
begin
  if Classes * LogLevel <> [] then
    LCLProc.DebugLn(DebugClassesToString(Classes) + AText + Format(' = %s', Args));
end;

class procedure Logger.DebugLnMultipleValues(Classes: TDebugClasses;
  AText: String; Args: array of const);
begin
  if Classes * LogLevel <> [] then
    LCLProc.DebugLn(DebugClassesToString(Classes) + Format(AText, Args));
end;

class procedure Logger.DebugLnEnter(Classes: TDebugClasses; const AMethodName,
  AMessage: String);
begin
  if Classes * LogLevel <> [] then
    if (AMessage = '') then
      LCLProc.DebugLnEnter(Format('%sEnter Method = %s', [DebugClassesToString(Classes), AMethodName]))
    else
      LCLProc.DebugLnEnter(Format('%sEnter Method = %s - %s', [DebugClassesToString(Classes), AMethodName, AMessage]));
end;

class procedure Logger.DebugLnExit(Classes: TDebugClasses; const AMethodName,
  AMessage: String);
begin
  if Classes * LogLevel <> [] then
    if (AMessage = '') then
      LCLProc.DebugLnExit(Format('%sExit Method = %s', [DebugClassesToString(Classes), AMethodName]))
    else
      LCLProc.DebugLnExit(Format('%sExit Method = %s - %s', [DebugClassesToString(Classes), AMethodName, AMessage]));
end;

class function Logger.DebugClassesToString(Classes: TDebugClasses): String;
begin
  Result := SetToString(PTypeInfo(TypeInfo(TDebugClasses)), @Classes, True) + ' ';
end;

class function Logger.RectToStr(const ARect: TRect): string;
begin
  with ARect do
    Result := Format('(Left: %d; Top: %d; Right: %d; Bottom: %d)', [Left, Top, Right, Bottom]);
end;

class function Logger.PointToStr(const APoint: TPoint): string;
begin
  with APoint do
    Result := Format('(X: %d; Y: %d)', [X, Y]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string);
begin
  DebugLn(Classes, AText);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText, AValue: string
  );
begin
  DebugLnValue(Classes, AText, [AValue]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: String;
  Args: array of const);
begin
  DebugLnMultipleValues(Classes, AText, Args);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  AValue: integer);
begin
  DebugLnValue(Classes, AText, [IntToStr(AValue)]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  AValue: cardinal);
begin
  DebugLnValue(Classes, AText, [IntToStr(AValue)]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  AValue: double);
begin
  DebugLnValue(Classes, AText, [FloatToStr(AValue)]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  AValue: int64);
begin
  DebugLnValue(Classes, AText, [IntToStr(AValue)]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  AValue: QWord);
begin
  DebugLnValue(Classes, AText, [IntToStr(AValue)]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  AValue: boolean);
begin
  DebugLnValue(Classes, AText, [BoolToStr(AValue, True)]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  const ARect: TRect);
begin
  DebugLnValue(Classes, AText, [RectToStr(ARect)]);
end;

class procedure Logger.Send(Classes: TDebugClasses; const AText: string;
  const APoint: TPoint);
begin
  DebugLnValue(Classes, AText, [PointToStr(APoint)]);
end;

class procedure Logger.SendColor(Classes: TDebugClasses; const AText: string;
  AColor: TColor);
begin
  DebugLnValue(Classes, AText, [ColorToString(AColor)]);
end;

class procedure Logger.SendCallStack(Classes: TDebugClasses; const AText: string
  );
begin
  if Classes * LogLevel <> [] then
  begin
    LCLProc.DebugLn(AText);
    LCLProc.DebugLn(GetStackTrace(True));
  end;
end;

class procedure Logger.SendError(Classes: TDebugClasses; const AText: string);
begin
  if Classes * LogLevel <> [] then
    LCLProc.DebugLn('ERROR: ' + AText);
end;

class procedure Logger.SendWarning(Classes: TDebugClasses; const AText: string);
begin
  if Classes * LogLevel <> [] then
    LCLProc.DebugLn('WARNING: ' + AText);
end;

class procedure Logger.EnterMethod(Classes: TDebugClasses;
  const AMethodName: string; const AMessage: string);
begin
  DebugLnEnter(Classes, AMethodName, AMessage);
end;

class procedure Logger.ExitMethod(Classes: TDebugClasses;
  const AMethodName: string; const AMessage: string);
begin
  DebugLnExit(Classes, AMethodName, AMessage);
end;

end.
