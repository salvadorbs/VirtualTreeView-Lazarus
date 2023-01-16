unit VirtualTrees.Classes;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes;

type
  // Helper classes to speed up rendering text formats for clipboard and drag'n drop transfers.
  TBufferedRawByteString = class
  private
    FStart,
    FPosition,
    FEnd: PAnsiChar;
    function GetAsString: RawByteString;
  public
    destructor Destroy; override;

    procedure Add(const S: RawByteString);
    procedure AddNewLine;

    property AsString: RawByteString read GetAsString;
  end;

  { TBufferedUTF8String }

  TBufferedString = class
  private
    FStart,
    FPosition,
    FEnd: PChar;
    function GetAsString: String;
  public
    destructor Destroy; override;

    procedure Add(const S: String);
    procedure AddNewLine;

    property AsString: String read GetAsString;
  end;


implementation

//----------------- TBufferedRawByteString ------------------------------------------------------------------------------------

const
  AllocIncrement = 2 shl 11;  // Must be a power of 2.

destructor TBufferedRawByteString.Destroy;

begin
  FreeMem(FStart);
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TBufferedRawByteString.GetAsString: RawByteString;

begin
  SetString(Result, FStart, FPosition - FStart);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TBufferedRawByteString.Add(const S: RawByteString);

var
  NewLen,
  LastOffset,
  Len: NativeInt;

begin
  Len := Length(S);
  // Make room for the new string.
  if FEnd - FPosition <= Len then
  begin
    // Round up NewLen so it is always a multiple of AllocIncrement.
    NewLen := FEnd - FStart + (Len + AllocIncrement - 1) and not (AllocIncrement - 1);
    // Keep last offset to restore it correctly in the case that FStart gets a new memory block assigned.
    LastOffset := FPosition - FStart;
    ReallocMem(FStart, NewLen);
    FPosition := FStart + LastOffset;
    FEnd := FStart + NewLen;
  end;
  Move(PAnsiChar(S)^, FPosition^, Len);
  Inc(FPosition, Len);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TBufferedRawByteString.AddNewLine;

var
  NewLen,
  LastOffset: NativeInt;

begin
  // Make room for the CR/LF characters.
  if FEnd - FPosition <= 2 then
  begin
    // Round up NewLen so it is always a multiple of AllocIncrement.
    NewLen := FEnd - FStart + (2 + AllocIncrement - 1) and not (AllocIncrement - 1);
    // Keep last offset to restore it correctly in the case that FStart gets a new memory block assigned.
    LastOffset := FPosition - FStart;
    ReallocMem(FStart, NewLen);
    FPosition := FStart + LastOffset;
    FEnd := FStart + NewLen;
  end;
  FPosition^ := #13;
  Inc(FPosition);
  FPosition^ := #10;
  Inc(FPosition);
end;

//----------------- TBufferedString --------------------------------------------------------------------------------

destructor TBufferedString.Destroy;

begin
  FreeMem(FStart);
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TBufferedString.GetAsString: string;

begin
  SetString(Result, FStart, FPosition - FStart);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TBufferedString.Add(const S: string);

var
  NewLen,
  LastOffset,
  Len: Integer;

begin
  Len := Length(S);
  if Len = 0 then
    exit;//Nothing to do
  // Make room for the new string.
  if FEnd - FPosition <= Len then
  begin
    // Round up NewLen so it is always a multiple of AllocIncrement.
    NewLen := FEnd - FStart + (Len + AllocIncrement - 1) and not (AllocIncrement - 1);
    // Keep last offset to restore it correctly in the case that FStart gets a new memory block assigned.
    LastOffset := FPosition - FStart;
    ReallocMem(FStart, NewLen);
    FPosition := FStart + LastOffset;
    FEnd := FStart + NewLen;
  end;
  System.Move(PChar(S)^, FPosition^, Len);
  Inc(FPosition, Len);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TBufferedString.AddNewLine;

var
  NewLen,
  LastOffset: Integer;

begin
  // Make room for the CR/LF characters.
  if FEnd - FPosition <= 4 then
  begin
    //todo: see in calculation of NewLen is correct for String
    // Round up NewLen so it is always a multiple of AllocIncrement.
    NewLen := FEnd - FStart + (2 + AllocIncrement - 1) and not (AllocIncrement - 1);
    // Keep last offset to restore it correctly in the case that FStart gets a new memory block assigned.
    LastOffset := FPosition - FStart;
    ReallocMem(FStart, NewLen);
    FPosition := FStart + LastOffset;
    FEnd := FStart + NewLen;
  end;
  FPosition^ := #13;
  Inc(FPosition);
  FPosition^ := #10;
  Inc(FPosition);
end;

end.
