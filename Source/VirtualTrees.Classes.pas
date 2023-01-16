unit VirtualTrees.Classes;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes;

type
  // Helper class to speed up rendering text formats for clipboard and drag'n drop transfers.

  { TBufferedUTF8String }

  TBufferedUTF8String = class
  private
    FStart,
    FPosition,
    FEnd: PChar;
    function GetAsAnsiString: AnsiString;
    function GetAsUTF16String: UnicodeString;
    function GetAsUTF8String: String;
    function GetAsString: String;
  public
    destructor Destroy; override;

    procedure Add(const S: String);
    procedure AddNewLine;

    property AsAnsiString: AnsiString read GetAsAnsiString;
    property AsString: String read GetAsString;
    property AsUTF8String: String read GetAsUTF8String;
    property AsUTF16String: UnicodeString read GetAsUTF16String;
  end;

implementation

//----------------- TBufferedUTF8String --------------------------------------------------------------------------------

const
  AllocIncrement = 2 shl 11;  // Must be a power of 2.

destructor TBufferedUTF8String.Destroy;

begin
  FreeMem(FStart);
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TBufferedUTF8String.GetAsAnsiString: AnsiString;

begin
  //an implicit conversion is done
  Result := AsUTF16String;
end;

//----------------------------------------------------------------------------------------------------------------------

function TBufferedUTF8String.GetAsUTF16String: UnicodeString;
begin
  //todo: optimize
  Result := UTF8Decode(AsUTF8String);
end;

//----------------------------------------------------------------------------------------------------------------------

function TBufferedUTF8String.GetAsUTF8String: String;
begin
  SetString(Result, FStart, FPosition - FStart);
end;

function TBufferedUTF8String.GetAsString: String;
begin
  SetString(Result, FStart, FPosition - FStart);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TBufferedUTF8String.Add(const S: String);

var
  NewLen,
  LastOffset,
  Len: Integer;

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
  System.Move(PChar(S)^, FPosition^, Len);
  Inc(FPosition, Len);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TBufferedUTF8String.AddNewLine;

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
