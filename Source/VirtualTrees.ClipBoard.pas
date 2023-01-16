unit VirtualTrees.ClipBoard;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, LCLType, LCLIntf, SysUtils, VirtualTrees.Types, VirtualTrees.BaseTree

  {$ifdef Windows}
  , ActiveX
  {$else}
  , FakeActiveX
  {$endif}
  ;

type
  TClipboardFormatEntry = record
    ID: Word;
    Description: string;
  end;

var
  ClipboardDescriptions: array [1..CF_MAX - 1] of TClipboardFormatEntry = (
    (ID: CF_TEXT; Description: 'Plain text'), // Do not localize
    (ID: CF_BITMAP; Description: 'Windows bitmap'), // Do not localize
    (ID: CF_METAFILEPICT; Description: 'Windows metafile'), // Do not localize
    (ID: CF_SYLK; Description: 'Symbolic link'), // Do not localize
    (ID: CF_DIF; Description: 'Data interchange format'), // Do not localize
    (ID: CF_TIFF; Description: 'Tiff image'), // Do not localize
    (ID: CF_OEMTEXT; Description: 'OEM text'), // Do not localize
    (ID: CF_DIB; Description: 'DIB image'), // Do not localize
    (ID: CF_PALETTE; Description: 'Palette data'), // Do not localize
    (ID: CF_PENDATA; Description: 'Pen data'), // Do not localize
    (ID: CF_RIFF; Description: 'Riff audio data'), // Do not localize
    (ID: CF_WAVE; Description: 'Wav audio data'), // Do not localize
    (ID: CF_UNICODETEXT; Description: 'Unicode text'), // Do not localize
    (ID: CF_ENHMETAFILE; Description: 'Enhanced metafile image'), // Do not localize
    (ID: CF_HDROP; Description: 'File name(s)'), // Do not localize
    (ID: CF_LOCALE; Description: 'Locale descriptor') // Do not localize
    {
    ,(ID: CF_DIBV5; Description: 'DIB image V5') // Do not localize
    }
  );

// OLE Clipboard and drag'n drop helper
procedure EnumerateVTClipboardFormats(TreeClass: TVirtualTreeClass; const List: TStrings); overload;
procedure EnumerateVTClipboardFormats(TreeClass: TVirtualTreeClass; var Formats: TFormatEtcArray); overload;
function GetVTClipboardFormatDescription(AFormat: TClipboardFormat): string;
procedure RegisterVTClipboardFormat(AFormat: TClipboardFormat; TreeClass: TVirtualTreeClass; Priority: Cardinal); overload;
function RegisterVTClipboardFormat(Description: string; TreeClass: TVirtualTreeClass; Priority: Cardinal;
  tymed: Integer = TYMED_HGLOBAL; ptd: PDVTargetDevice = nil; dwAspect: Integer = DVASPECT_CONTENT;
  lindex: Integer = -1): Word; overload;

//----------------- TClipboardFormats ----------------------------------------------------------------------------------

type
  PClipboardFormatListEntry = ^TClipboardFormatListEntry;
  TClipboardFormatListEntry = record
    Description: string;               // The string used to register the format with Windows.
    TreeClass: TVirtualTreeClass;      // The tree class which supports rendering this format.
    Priority: Cardinal;                // Number which determines the order of formats used in IDataObject.
    FormatEtc: TFormatEtc;             // The definition of the format in the IDataObject.
  end;

  TClipboardFormatList = class
  private
    FList: TFpList;
    procedure Sort;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(FormatString: string; AClass: TVirtualTreeClass; Priority: Cardinal; AFormatEtc: TFormatEtc);
    procedure Clear;
    procedure EnumerateFormats(TreeClass: TVirtualTreeClass; var Formats: TFormatEtcArray;
      const AllowedFormats: TClipboardFormats = nil); overload;
    procedure EnumerateFormats(TreeClass: TVirtualTreeClass; const Formats: TStrings); overload;
    function FindFormat(FormatString: string): PClipboardFormatListEntry; overload;
    function FindFormat(FormatString: string; var Fmt: TClipboardFormat): TVirtualTreeClass; overload;
    function FindFormat(Fmt: TClipboardFormat; out Description: string): TVirtualTreeClass; overload;
  end;

var // Clipboard format IDs used in OLE drag'n drop and clipboard transfers.
  CF_VIRTUALTREE,
  CF_VTREFERENCE,
  CF_VRTF,
  CF_VRTFNOOBJS,   // Unfortunately CF_RTF* is already defined as being
                   // registration strings so I have to use different identifiers.
  CF_HTML,
  CF_CSV: TClipboardFormat;
  InternalClipboardFormats: TClipboardFormatList;

implementation

procedure EnumerateVTClipboardFormats(TreeClass: TVirtualTreeClass; const List: TStrings);

begin
  if InternalClipboardFormats = nil then
    InternalClipboardFormats := TClipboardFormatList.Create;
  InternalClipboardFormats.EnumerateFormats(TreeClass, List);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure EnumerateVTClipboardFormats(TreeClass: TVirtualTreeClass; var Formats: TFormatEtcArray);

begin
  if InternalClipboardFormats = nil then
    InternalClipboardFormats := TClipboardFormatList.Create;
  InternalClipboardFormats.EnumerateFormats(TreeClass, Formats);
end;

//----------------------------------------------------------------------------------------------------------------------

function GetVTClipboardFormatDescription(AFormat: TClipboardFormat): string;

begin
  if InternalClipboardFormats = nil then
    InternalClipboardFormats := TClipboardFormatList.Create;
  if InternalClipboardFormats.FindFormat(AFormat, Result) = nil then
    Result := '';
end;

//----------------------------------------------------------------------------------------------------------------------

procedure RegisterVTClipboardFormat(AFormat: TClipboardFormat; TreeClass: TVirtualTreeClass; Priority: Cardinal);

// Registers the given clipboard format for the given TreeClass.

var
  I: Integer;
  FormatEtc: TFormatEtc;

begin
  if InternalClipboardFormats = nil then
    InternalClipboardFormats := TClipboardFormatList.Create;

  // Assumes a HGlobal format.
  FormatEtc.cfFormat := AFormat;
  FormatEtc.ptd := nil;
  FormatEtc.dwAspect := DVASPECT_CONTENT;
  FormatEtc.lindex := -1;
  FormatEtc.tymed := TYMED_HGLOBAL;

  // Determine description string of the given format. For predefined formats we need the lookup table because they
  // don't have a description string. For registered formats the description string is the string which was used
  // to register them.
  if AFormat < CF_MAX then
  begin
    for I := 1 to High(ClipboardDescriptions) do
      if ClipboardDescriptions[I].ID = AFormat then
      begin
        InternalClipboardFormats.Add(ClipboardDescriptions[I].Description, TreeClass, Priority, FormatEtc);
        Break;
      end;
  end
  else
  begin
    InternalClipboardFormats.Add(ClipboardFormatToMimeType(AFormat), TreeClass, Priority, FormatEtc);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function RegisterVTClipboardFormat(Description: string; TreeClass: TVirtualTreeClass; Priority: Cardinal;
  tymed: Integer = TYMED_HGLOBAL; ptd: PDVTargetDevice = nil; dwAspect: Integer = DVASPECT_CONTENT;
  lindex: Integer = -1): Word;

// Alternative method to register a certain clipboard format for a given tree class. Registration with the
// clipboard is done here too and the assigned ID returned by the function.
// tymed may contain or'ed TYMED constants which allows to register several storage formats for one clipboard format.

var
  FormatEtc: TFormatEtc;

begin
  if InternalClipboardFormats = nil then
    InternalClipboardFormats := TClipboardFormatList.Create;
  Result := ClipboardRegisterFormat(Description);
  FormatEtc.cfFormat := Result;
  FormatEtc.ptd := ptd;
  FormatEtc.dwAspect := dwAspect;
  FormatEtc.lindex := lindex;
  FormatEtc.tymed := tymed;
  InternalClipboardFormats.Add(Description, TreeClass, Priority, FormatEtc);
end;

//----------------------------------------------------------------------------------------------------------------------

constructor TClipboardFormatList.Create;

begin
  FList := TFpList.Create;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TClipboardFormatList.Destroy;

begin
  Clear;
  FList.Free;
  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TClipboardFormatList.Sort;

// Sorts all entry for priority (increasing priority value).

  //--------------- local function --------------------------------------------

  procedure QuickSort(L, R: Integer);

  var
    I, J: Integer;
    P, T: PClipboardFormatListEntry;

  begin
    repeat
      I := L;
      J := R;
      P := FList[(L + R) shr 1];
      repeat
        while PClipboardFormatListEntry(FList[I]).Priority < P.Priority do
          Inc(I);
        while PClipboardFormatListEntry(FList[J]).Priority > P.Priority do
          Dec(J);
        if I <= J then
        begin
          T := FList[I];
          FList[I] := FList[J];
          FList[J] := T;
          Inc(I);
          Dec(J);
        end;
      until I > J;
      if L < J then
        QuickSort(L, J);
      L := I;
    until I >= R;
  end;

  //--------------- end local function ----------------------------------------

begin
  if FList.Count > 1 then
    QuickSort(0, FList.Count - 1);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TClipboardFormatList.Add(FormatString: string; AClass: TVirtualTreeClass; Priority: Cardinal;
  AFormatEtc: TFormatEtc);

// Adds the given data to the internal list. The priority value is used to sort formats for importance. Larger priority
// values mean less priority.

var
  Entry: PClipboardFormatListEntry;

begin
  New(Entry);
  Entry.Description := FormatString;
  Entry.TreeClass := AClass;
  Entry.Priority := Priority;
  Entry.FormatEtc := AFormatEtc;
  FList.Add(Entry);

  Sort;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TClipboardFormatList.Clear;

var
  I: Integer;

begin
  for I := 0 to FList.Count - 1 do
    Dispose(PClipboardFormatListEntry(FList[I]));
  FList.Clear;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TClipboardFormatList.EnumerateFormats(TreeClass: TVirtualTreeClass; var Formats: TFormatEtcArray;
  const AllowedFormats: TClipboardFormats = nil);

// Returns a list of format records for the given class. If assigned the AllowedFormats is used to limit the
// enumerated formats to those described in the list.

var
  I, Count: Integer;
  Entry: PClipboardFormatListEntry;

begin
  SetLength(Formats, FList.Count);
  Count := 0;
  for I := 0 to FList.Count - 1 do
  begin
    Entry := FList[I];
    // Does the tree class support this clipboard format?
    if TreeClass.InheritsFrom(Entry.TreeClass) then
    begin
      // Is this format allowed to be included?
      if (AllowedFormats = nil) or (AllowedFormats.IndexOf(Entry.Description) > -1) then
      begin
        // The list could change before we use the FormatEtc so it is best not to pass a pointer to the true FormatEtc
        // structure. Instead make a copy and send that.
        Formats[Count] := Entry.FormatEtc;
        Inc(Count);
      end;
    end;
  end;
  SetLength(Formats, Count);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TClipboardFormatList.EnumerateFormats(TreeClass: TVirtualTreeClass; const Formats: TStrings);

// Returns a list of format descriptions for the given class.

var
  I: Integer;
  Entry: PClipboardFormatListEntry;

begin
  for I := 0 to FList.Count - 1 do
  begin
    Entry := FList[I];
    if TreeClass.InheritsFrom(Entry.TreeClass) then
      Formats.Add(Entry.Description);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TClipboardFormatList.FindFormat(FormatString: string): PClipboardFormatListEntry;

var
  I: Integer;
  Entry: PClipboardFormatListEntry;

begin
  Result := nil;
  for I := FList.Count - 1 downto 0 do
  begin
    Entry := FList[I];
    if CompareText(Entry.Description, FormatString) = 0 then
    begin
      Result := Entry;
      Break;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TClipboardFormatList.FindFormat(FormatString: string; var Fmt: TClipboardFormat): TVirtualTreeClass;

var
  I: Integer;
  Entry: PClipboardFormatListEntry;

begin
  Result := nil;
  for I := FList.Count - 1 downto 0 do
  begin
    Entry := FList[I];
    if CompareText(Entry.Description, FormatString) = 0 then
    begin
      Result := Entry.TreeClass;
      Fmt := Entry.FormatEtc.cfFormat;
      Break;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TClipboardFormatList.FindFormat(Fmt: TClipboardFormat; out Description: string): TVirtualTreeClass;

var
  I: Integer;
  Entry: PClipboardFormatListEntry;

begin
  Result := nil;
  for I := FList.Count - 1 downto 0 do
  begin
    Entry := FList[I];
    if Entry.FormatEtc.cfFormat = Fmt then
    begin
      Result := Entry.TreeClass;
      Description := Entry.Description;
      Break;
    end;
  end;
end;

end.
