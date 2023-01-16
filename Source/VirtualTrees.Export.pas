unit VirtualTrees.Export;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, SysUtils, StrUtils, Controls, Forms, VirtualTrees, VirtualTrees.BaseTree,
  VirtualTrees.Classes, LCLType, DelphiCompat;

function ContentToHTML(Tree: TCustomVirtualStringTree; Source: TVSTTextSourceType; const Caption: string = ''): String;
function ContentToRTF(Tree: TCustomVirtualStringTree; Source: TVSTTextSourceType): AnsiString;
procedure ContentToCustom(Tree: TCustomVirtualStringTree; Source: TVSTTextSourceType);

implementation

uses
  Graphics, VirtualTrees.Header, VirtualTrees.Types,
  {$ifdef Windows}
  Windows,
  ActiveX
  {$else}
  FakeActiveX
  {$endif};

type
  TCustomVirtualStringTreeCracker = class(TCustomVirtualStringTree)
  end;

const
  WideCR = Char(#13);
  WideLF = Char(#10);


function ContentToHTML(Tree: TCustomVirtualStringTree;
  Source: TVSTTextSourceType; const Caption: string): String;

// Renders the current tree content (depending on Source) as HTML text encoded in UTF-8.
// If Caption is not empty then it is used to create and fill the header for the table built here.
// Based on ideas and code from Frank van den Bergh and Andreas H??emeier.

var
  Buffer: TBufferedUTF8String;

  //--------------- local functions -------------------------------------------

  procedure WriteColorAsHex(Color: TColor);

  var
    WinColor: COLORREF;
    I: Integer;
    Component,
    Value: Byte;

  begin
    Buffer.Add('#');
    WinColor := ColorToRGB(Color);
    I := 1;
    while I <= 6 do
    begin
      Component := WinColor and $FF;

      Value := 48 + (Component shr 4);
      if Value > $39 then
        Inc(Value, 7);
      Buffer.Add(AnsiChar(Value));
      Inc(I);

      Value := 48 + (Component and $F);
      if Value > $39 then
        Inc(Value, 7);
      Buffer.Add(AnsiChar(Value));
      Inc(I);

      WinColor := WinColor shr 8;
    end;
  end;

  //---------------------------------------------------------------------------

  procedure WriteStyle(const Name: AnsiString; Font: TFont);

  // Creates a CSS style entry with the given name for the given font.
  // If Name is empty then the entry is created as inline style.

  begin
    if Length(Name) = 0 then
      Buffer.Add(' style="{')
    else
    begin
      Buffer.Add('.');
      Buffer.Add(Name);
      Buffer.Add('{');
    end;

    Buffer.Add(Format('font-family: ''%s''; ', [Font.Name]));
    if Font.Size < 0 then
      Buffer.Add(Format('font-size: %dpx; ', [Font.Height]))
    else
      Buffer.Add(Format('font-size: %dpt; ', [Font.Size]));

    Buffer.Add(Format('font-style: %s; ', [IfThen(fsItalic in Font.Style, 'italic', 'normal')]));
    Buffer.Add(Format('font-weight: %s; ', [IfThen(fsBold in Font.Style, 'bold', 'normal')]));
    Buffer.Add(Format('text-decoration: %s; ', [IfThen(fsUnderline in Font.Style, 'underline', 'none')]));

    Buffer.Add('color: ');
    WriteColorAsHex(Font.Color);
    Buffer.Add(';}');
    if Length(Name) = 0 then
      Buffer.Add('"');
  end;

  //--------------- end local functions ---------------------------------------

var
  I, J : Integer;
  Level, MaxLevel: Cardinal;
  AddHeader: String;
  Save, Run: PVirtualNode;
  GetNextNode: TGetNextNodeProc;
  Text: String;

  RenderColumns: Boolean;
  Columns: TColumnsArray;
  Index: Integer;
  IndentWidth,
  LineStyleText: String;
  Alignment: TAlignment;
  BidiMode: TBidiMode;

  CellPadding: String;
  CrackTree: TCustomVirtualStringTreeCracker;

begin
  CrackTree := TCustomVirtualStringTreeCracker(Tree);
  
  CrackTree.StartOperation(TVTOperationKind.okExport);
  Buffer := TBufferedUTF8String.Create;
  try
    // For customization by the application or descendants we use again the redirected font change event.
    CrackTree.RedirectFontChangeEvent(CrackTree.Canvas);

    CellPadding := Format('padding-left: %dpx; padding-right: %0:dpx;', [CrackTree.Margin]);

    IndentWidth := IntToStr(CrackTree.Indent);
    AddHeader := ' ';
    // Add title if adviced so by giving a caption.
    if Length(Caption) > 0 then
      AddHeader := AddHeader + 'caption="' + Caption + '"';
    if CrackTree.Borderstyle <> TFormBorderStyle.bsNone then
      AddHeader := AddHeader + Format(' border="%d" frame=box', [CrackTree.BorderWidth + 1]);

    Buffer.Add('<META http-equiv="Content-Type" content="text/html; charset=utf-8">');

    // Create HTML table based on the CrackTree structure. To simplify formatting we use styles defined in a small CSS area.
    Buffer.Add('<style type="text/css">');
    Buffer.AddnewLine;
    WriteStyle('default', CrackTree.Font);
    Buffer.AddNewLine;
    WriteStyle('header', CrackTree.Header.Font);
    Buffer.AddNewLine;

    // Determine grid/table lines and create CSS for it.
    // Vertical and/or horizontal border to show.
    if CrackTree.LineStyle = lsSolid then
      LineStyleText := 'solid;'
    else
      LineStyleText := 'dotted;';
    if toShowHorzGridLines in CrackTree.TreeOptions.PaintOptions then
    begin
      Buffer.Add('.noborder{');
      Buffer.Add(' border-bottom:1px; border-left: 0px; border-right: 0px; border-top: 1px;');
      Buffer.Add('border-style:');
      Buffer.Add(LineStyleText);
      Buffer.Add(CellPadding);
      Buffer.Add('}');
    end
    else
    begin
      Buffer.Add('.noborder{border-style: none;');
      Buffer.Add(CellPadding);
      Buffer.Add('}');
    end;
    Buffer.AddNewLine;

    Buffer.Add('.normalborder {vertical-align: top; ');
    if toShowVertGridLines in CrackTree.TreeOptions.PaintOptions then
      Buffer.Add('border-right: 1px; border-left: 1px; ')
    else
      Buffer.Add('border-right: none; border-left:none; ');
    if toShowHorzGridLines in CrackTree.TreeOptions.PaintOptions then
      Buffer.Add('border-top: 1px; border-bottom: 1px; ')
    else
      Buffer.Add('border-top:none; border-bottom: none;');
    Buffer.Add('border-width: thin; border-style: ');
    Buffer.Add(LineStyleText);
    Buffer.Add(CellPadding);
    Buffer.Add('}');
    Buffer.Add('</style>');
    Buffer.AddNewLine;

    // General table properties.
    Buffer.Add('<table class="default" style="border-collapse: collapse;" bgcolor=');
    WriteColorAsHex(CrackTree.Color);
    Buffer.Add(AddHeader);
    Buffer.Add(' cellspacing="0">');
    Buffer.AddNewLine;

    Columns := nil;
    RenderColumns := CrackTree.Header.UseColumns;
    if RenderColumns then
    begin
      Columns := CrackTree.Header.Columns.GetVisibleColumns;
    end;

    CrackTree.GetRenderStartValues(Source, Run, GetNextNode);
    Save := Run;

    MaxLevel := 0;
    // The table consists of visible columns and rows as used in the CrackTree, but the main CrackTree column is splitted
    // into several HTML columns to accomodate the indentation.
    while Assigned(Run) do
    begin
      if (CrackTree.CanExportNode(Run)) then
      begin
        Level := CrackTree.GetNodeLevel(Run);
          if Level > MaxLevel then
            MaxLevel := Level;
      end;
      Run := GetNextNode(Run);
    end;

    if RenderColumns then
    begin
      if Assigned(CrackTree.OnBeforeHeaderExport) then
        CrackTree.OnBeforeHeaderExport(CrackTree, etHTML);
      Buffer.Add('<tr class="header" style="');
      Buffer.Add(CellPadding);
      Buffer.Add('">');
      Buffer.AddNewLine;
      // Make the first row in the HTML table an image of the CrackTree header.
      for I := 0 to High(Columns) do
      begin
        if Assigned(CrackTree.OnBeforeColumnExport) then
          CrackTree.OnBeforeColumnExport(CrackTree, etHTML, Columns[I]);
        Buffer.Add('<th height="');
        Buffer.Add(IntToStr(CrackTree.Header.Height));
        Buffer.Add('px"');
        Alignment := Columns[I].CaptionAlignment;
        // Consider directionality.
        if Columns[I].BiDiMode <> bdLeftToRight then
        begin
          ChangeBidiModeAlignment(Alignment);
          Buffer.Add(' dir="rtl"');
        end;

          // Consider aligment.
        case Alignment of
          taRightJustify:
            Buffer.Add(' align=right');
          taCenter:
            Buffer.Add(' align=center');
        else
          Buffer.Add(' align=left');
        end;

        Index := Columns[I].Index;
        // Merge cells of the header emulation in the main column.
        if (MaxLevel > 0) and (Index = CrackTree.Header.MainColumn) then
        begin
          Buffer.Add(' colspan="');
          Buffer.Add(IntToStr(MaxLevel + 1));
          Buffer.Add('"');
        end;

        // The color of the header is usually clBtnFace.
        Buffer.Add(' bgcolor=');
        WriteColorAsHex(clBtnFace);

        // Set column width in pixels.
        Buffer.Add(' width="');
        Buffer.Add(IntToStr(Columns[I].Width));
        Buffer.Add('px">');

        if Length(Columns[I].Text) > 0 then
          Buffer.Add(Columns[I].Text);
        Buffer.Add('</th>');
        if Assigned(CrackTree.OnAfterColumnExport) then
          CrackTree.OnAfterColumnExport(CrackTree, etHTML, Columns[I]);
      end;
      Buffer.Add('</tr>');
      Buffer.AddNewLine;
      if Assigned(CrackTree.OnAfterHeaderExport) then
        CrackTree.OnAfterHeaderExport(CrackTree, etHTML);
    end;

    // Now go through the CrackTree.
    Run := Save;
    while Assigned(Run) do
    begin
      if (not CrackTree.CanExportNode(Run)) then
      begin
        Run := GetNextNode(Run);
        Continue;
      end;
      Level := CrackTree.GetNodeLevel(Run);
      Buffer.Add(' <tr class="default">');
      Buffer.AddNewLine;

      I := 0;
      while (I < Length(Columns)) or not RenderColumns do
      begin
        if RenderColumns then
          Index := Columns[I].Index
        else
          Index := NoColumn;

        if not RenderColumns or (coVisible in Columns[I].Options) then
        begin
          // Call back the application to know about font customization.
          CrackTree.Canvas.Font := CrackTree.Font;
          CrackTree.FFontChanged := False;
          CrackTree.DoPaintText(Run, CrackTree.Canvas, Index, ttNormal);

          if Index = CrackTree.Header.MainColumn then
          begin
            // Create a cell for each indentation level.
            if RenderColumns and not (coParentColor in Columns[I].Options) then
            begin
              for J := 1 to Level do
              begin
                Buffer.Add('<td class="noborder" width="');
                Buffer.Add(IndentWidth);
                Buffer.Add('" height="');
                Buffer.Add(IntToStr(CrackTree.NodeHeight[Run]));
                Buffer.Add('px"');
                if not (coParentColor in Columns[I].Options) then
                begin
                  Buffer.Add(' bgcolor=');
                  WriteColorAsHex(Columns[I].Color);
                end;
                Buffer.Add('>&nbsp;</td>');
              end;
            end
            else
            begin
              for J := 1 to Level do
                if J = 1 then
                begin
                  Buffer.Add(' <td height="');
                  Buffer.Add(IntToStr(CrackTree.NodeHeight[Run]));
                  Buffer.Add('px" class="normalborder">&nbsp;</td>');
                end
                else
                  Buffer.Add(' <td>&nbsp;</td>');
            end;
          end;

          if CrackTree.FFontChanged then
          begin
            Buffer.Add(' <td class="normalborder" ');
            WriteStyle('', CrackTree.Canvas.Font);
            Buffer.Add(' height="');
            Buffer.Add(IntToStr(CrackTree.NodeHeight[Run]));
            Buffer.Add('px"');
          end
          else
          begin
            Buffer.Add(' <td class="normalborder"  height="');
            Buffer.Add(IntToStr(CrackTree.NodeHeight[Run]));
            Buffer.Add('px"');
          end;

          if RenderColumns then
          begin
            Alignment := Columns[I].Alignment;
            BidiMode := Columns[I].BidiMode;
          end
          else
          begin
            Alignment := CrackTree.Alignment;
            BidiMode := CrackTree.BidiMode;
          end;
          // Consider directionality.
          if BiDiMode <> bdLeftToRight then
          begin
            ChangeBidiModeAlignment(Alignment);
            Buffer.Add(' dir="rtl"');
          end;

          // Consider aligment.
          case Alignment of
            taRightJustify:
              Buffer.Add(' align=right');
            taCenter:
              Buffer.Add(' align=center');
          else
            Buffer.Add(' align=left');
          end;
          // Merge cells in the main column.
          if (MaxLevel > 0) and (Index = CrackTree.Header.MainColumn) and (Level < MaxLevel) then
          begin
            Buffer.Add(' colspan="');
            Buffer.Add(IntToStr(MaxLevel - Level + 1));
            Buffer.Add('"');
          end;
          if RenderColumns and not (coParentColor in Columns[I].Options) then
          begin
            Buffer.Add(' bgcolor=');
            WriteColorAsHex(Columns[I].Color);
          end;
          Buffer.Add('>');
          // Get the text
          lGetCellTextEventArgs.Node := Run;
          lGetCellTextEventArgs.Column := Index;
          CrackTree.DoGetText(lGetCellTextEventArgs.Node, lGetCellTextEventArgs.Column, ttNormal, lGetCellTextEventArgs.CellText);
          Buffer.Add(lGetCellTextEventArgs.CellText);
          if not lGetCellTextEventArgs.StaticText.IsEmpty and (toShowStaticText in TStringTreeOptions(CrackTree.TreeOptions).StringOptions) then
            Buffer.Add(' ' + lGetCellTextEventArgs.StaticText);
          Buffer.Add('</td>');
        end;

        if not RenderColumns then
          Break;
        Inc(I);
      end;
      if Assigned(CrackTree.OnAfterNodeExport) then
        CrackTree.OnAfterNodeExport(CrackTree, etHTML, Run);
      Run := GetNextNode(Run);
      Buffer.Add(' </tr>');
      Buffer.AddNewLine;
    end;
    Buffer.Add('</table>');

    CrackTree.RestoreFontChangeEvent(CrackTree.Canvas);

    Result := Buffer.AsUTF8String;
  finally
    Buffer.Free;
  end;
end;

function ContentToRTF(Tree: TCustomVirtualStringTree; Source: TVSTTextSourceType
  ): AnsiString;

// Renders the current tree content (depending on Source) as RTF (rich text).
// Based on ideas and code from Frank van den Bergh and Andreas H??emeier.

var
  Fonts: TStringList;
  Colors: TFpList;
  CurrentFontIndex,
  CurrentFontColor,
  CurrentFontSize: Integer;
  Buffer: TBufferedUTF8String;

  //--------------- local functions -------------------------------------------

  procedure SelectFont(const Font: string);

  var
    I: Integer;

  begin
    I := Fonts.IndexOf(Font);
    if I > -1 then
    begin
      // Font has already been used
      if I <> CurrentFontIndex then
      begin
        Buffer.Add('\f');
        Buffer.Add(IntToStr(I));
        CurrentFontIndex := I;
      end;
    end
    else
    begin
      I := Fonts.Add(Font);
      Buffer.Add('\f');
      Buffer.Add(IntToStr(I));
      CurrentFontIndex := I;
    end;
  end;

  //---------------------------------------------------------------------------

  procedure SelectColor(Color: TColor);

  var
    I: Integer;

  begin
    I := Colors.IndexOf(Pointer(Color));
    if I > -1 then
    begin
      // Color has already been used
      if I <> CurrentFontColor then
      begin
        Buffer.Add('\cf');
        Buffer.Add(IntToStr(I + 1));
        CurrentFontColor := I;
      end;
    end
    else
    begin
      I := Colors.Add(Pointer(Color));
      Buffer.Add('\cf');
      Buffer.Add(IntToStr(I + 1));
      CurrentFontColor := I;
    end;
  end;

  //---------------------------------------------------------------------------

  procedure TextPlusFont(const Text: String; Font: TFont);

  var
    UseUnderline,
    UseItalic,
    UseBold: Boolean;
    I: Integer;
    WText: UnicodeString;
  begin
    if Length(Text) > 0 then
    begin
      WText := UTF8Decode(Text);
      UseUnderline := fsUnderline in Font.Style;
      if UseUnderline then
        Buffer.Add('\ul');
      UseItalic := fsItalic in Font.Style;
      if UseItalic then
        Buffer.Add('\i');
      UseBold := fsBold in Font.Style;
      if UseBold then
        Buffer.Add('\b');
      SelectFont(Font.Name);
      SelectColor(Font.Color);
      if Font.Size <> CurrentFontSize then
      begin
        // Font size must be given in half points.
        Buffer.Add('\fs');
        Buffer.Add(IntToStr(2 * Font.Size));
        CurrentFontSize := Font.Size;
      end;
      // Use escape sequences to note Unicode text.
      Buffer.Add(' ');
      // Note: Unicode values > 32767 must be expressed as negative numbers. This is implicitly done
      //       by interpreting the wide chars (word values) as small integers.
      for I := 1 to Length(WText) do
      begin
        if (Text[I] = WideLF) then
          Buffer.Add( '{\par}' )
        else
          if (Text[I] <> WideCR) then
          begin
            Buffer.Add(Format('\u%d\''3f', [SmallInt(WText[I])]));
            Continue;
          end;
      end;
      if UseUnderline then
        Buffer.Add('\ul0');
      if UseItalic then
        Buffer.Add('\i0');
      if UseBold then
        Buffer.Add('\b0');
    end;
  end;

  //--------------- end local functions ---------------------------------------

var
  Level, LastLevel: Integer;
  I, J: Integer;
  Save, Run: PVirtualNode;
  GetNextNode: TGetNextNodeProc;
  S, Tabs : String;
  Text: String;
  Twips: Integer;

  RenderColumns: Boolean;
  Columns: TColumnsArray;
  Index: Integer;
  Alignment: TAlignment;
  BidiMode: TBidiMode;
  LocaleBuffer: array [0..1] of Char;
  CrackTree: TCustomVirtualStringTreeCracker;

begin
  CrackTree := TCustomVirtualStringTreeCracker(Tree);
  Buffer := TBufferedUTF8String.Create;
  try
    // For customization by the application or descendants we use again the redirected font change event.
    CrackTree.RedirectFontChangeEvent(CrackTree.Canvas);

    Fonts := TStringList.Create;
    Colors := TFpList.Create;
    CurrentFontIndex := -1;
    CurrentFontColor := -1;
    CurrentFontSize := -1;

    Columns := nil;
    Tabs := '';
    LastLevel := 0;

    RenderColumns := CrackTree.Header.UseColumns;
    if RenderColumns then
      Columns := CrackTree.Header.Columns.GetVisibleColumns;

    CrackTree.GetRenderStartValues(Source, Run, GetNextNode);
    Save := Run;

    // First make a table structure. The \rtf and other header stuff is included
    // when the font and color tables are created.
    Buffer.Add('\uc1\trowd\trgaph70');
    J := 0;
    if RenderColumns then
    begin
      for I := 0 to High(Columns) do
      begin
        Inc(J, Columns[I].Width);
        // This value must be expressed in twips (1 inch = 1440 twips).
        Twips := Round(1440 * J / Screen.PixelsPerInch);
        Buffer.Add('\cellx');
        Buffer.Add(IntToStr(Twips));
      end;
    end
    else
    begin
      Twips := Round(1440 * CrackTree.ClientWidth / Screen.PixelsPerInch);
      Buffer.Add('\cellx');
      Buffer.Add(IntToStr(Twips));
    end;

    // Fill table header.
    if RenderColumns then
    begin
      if Assigned(CrackTree.OnBeforeHeaderExport) then
        CrackTree.OnBeforeHeaderExport(CrackTree, etRTF);
      Buffer.Add('\pard\intbl');
      for I := 0 to High(Columns) do
      begin
        if Assigned(CrackTree.OnBeforeColumnExport) then
          CrackTree.OnBeforeColumnExport(CrackTree, etRTF, Columns[I]);
        Alignment := Columns[I].CaptionAlignment;
        BidiMode := Columns[I].BidiMode;

        // Alignment is not supported with older RTF formats, however it will be ignored.
        if BidiMode <> bdLeftToRight then
          ChangeBidiModeAlignment(Alignment);
        case Alignment of
          taLeftJustify:
            Buffer.Add('\ql');
          taRightJustify:
            Buffer.Add('\qr');
          taCenter:
            Buffer.Add('\qc');
        end;

        TextPlusFont(Columns[I].Text, CrackTree.Header.Font);
        Buffer.Add('\cell');
        if Assigned(CrackTree.OnAfterColumnExport) then
          CrackTree.OnAfterColumnExport(CrackTree, etRTF, Columns[I]);
      end;
      Buffer.Add('\row');
      if Assigned(CrackTree.OnAfterHeaderExport) then
        CrackTree.OnAfterHeaderExport(CrackTree, etRTF);
    end;

    // Now write the contents.
    Run := Save;
    while Assigned(Run) do
    begin
      if (not CrackTree.CanExportNode(Run)) then
      begin
        Run := GetNextNode(Run);
        Continue;
      end;
      I := 0;
      while not RenderColumns or (I < Length(Columns)) do
      begin
        if RenderColumns then
        begin
          Index := Columns[I].Index;
          Alignment := Columns[I].Alignment;
          BidiMode := Columns[I].BidiMode;
        end
        else
        begin
          Index := NoColumn;
          Alignment := CrackTree.Alignment;
          BidiMode := CrackTree.BidiMode;
        end;

        if not RenderColumns or (coVisible in Columns[I].Options) then
        begin
          // Get the text
          lGetCellTextEventArgs.Node := Run;
          lGetCellTextEventArgs.Column := Index;
          CrackTree.DoGetText(lGetCellTextEventArgs.Node, lGetCellTextEventArgs.Column, ttNormal, lGetCellTextEventArgs.CellText);
          Buffer.Add('\pard\intbl');

          // Alignment is not supported with older RTF formats, however it will be ignored.
          if BidiMode <> bdLeftToRight then
            ChangeBidiModeAlignment(Alignment);
          case Alignment of
            taRightJustify:
              Buffer.Add('\qr');
            taCenter:
              Buffer.Add('\qc');
          end;

          // Call back the application to know about font customization.
          CrackTree.Canvas.Font := CrackTree.Font;
          CrackTree.FFontChanged := False;
          CrackTree.DoPaintText(Run, CrackTree.Canvas, Index, ttNormal);

          if Index = CrackTree.Header.MainColumn then
          begin
            Level := CrackTree.GetNodeLevel(Run);
            if Level <> LastLevel then
            begin
              LastLevel := Level;
              Tabs := '';
              for J := 0 to Level - 1 do
                Tabs := Tabs + '\tab';
            end;
            if Level > 0 then
            begin
              Buffer.Add(Tabs);
              Buffer.Add(' ');
              TextPlusFont(Text, CrackTree.Canvas.Font);
              Buffer.Add('\cell');
            end
            else
            begin
              TextPlusFont(Text, CrackTree.Canvas.Font);
              Buffer.Add('\cell');
            end;
          end
          else
          begin
            TextPlusFont(Text, CrackTree.Canvas.Font);
            Buffer.Add('\cell');
          end;
        end;

        if not RenderColumns then
          Break;
        Inc(I);
      end;
      Buffer.Add('\row');
      Buffer.AddNewLine;
      if (Assigned(CrackTree.OnAfterNodeExport)) then
        CrackTree.OnAfterNodeExport(CrackTree, etRTF, Run);
      Run := GetNextNode(Run);
    end;

    Buffer.Add('\pard\par');

    // Build lists with fonts and colors. They have to be at the start of the document.
    S := '{\rtf1\ansi\ansicpg1252\deff0\deflang1043{\fonttbl';
    for I := 0 to Fonts.Count - 1 do
      S := S + Format('{\f%d %s;}', [I, Fonts[I]]);
    S := S + '}';

    S := S + '{\colortbl;';
    for I := 0 to Colors.Count - 1 do
    begin
      J := ColorToRGB(TColor(Colors[I]));
      S := S + Format('\red%d\green%d\blue%d;', [J and $FF, (J shr 8) and $FF, (J shr 16) and $FF]);
    end;
    S := S + '}';
    {$ifndef INCOMPLETE_WINAPI}
    if (GetLocaleInfo(LOCALE_USER_DEFAULT, LOCALE_IMEASURE, @LocaleBuffer[0], Length(LocaleBuffer)) <> 0) and (LocaleBuffer[0] = '0'{metric}) then
      S := S + '\paperw16840\paperh11907'// This sets A4 landscape format
    else
      S := S + '\paperw15840\paperh12240';//[JAM:marder]  This sets US Letter landscape format
    {$else}
    S := S + '\paperw16840\paperh11907';// This sets A4 landscape format
    {$endif}
    // Make sure a small margin is used so that a lot of the table fits on a paper. This defines a margin of 0.5"
    S := S + '\margl720\margr720\margt720\margb720';
    Result := S + Buffer.AsString + '}';
    Fonts.Free;
    Colors.Free;

    CrackTree.RestoreFontChangeEvent(CrackTree.Canvas);
  finally
    Buffer.Free;
  end;
end;

procedure ContentToCustom(Tree: TCustomVirtualStringTree;
  Source: TVSTTextSourceType);

// Generic export procedure which polls the application at every stage of the export.

var
  I: Integer;
  Save, Run: PVirtualNode;
  GetNextNode: TGetNextNodeProc;
  RenderColumns: Boolean;
  Columns: TColumnsArray;
  CrackTree: TCustomVirtualStringTreeCracker;
begin
  CrackTree := TCustomVirtualStringTreeCracker(Tree);
  
  Columns := nil;
    CrackTree.GetRenderStartValues(Source, Run, GetNextNode);
  Save := Run;

    RenderColumns := CrackTree.Header.UseColumns and ( hoVisible in CrackTree.Header.Options );

    if Assigned(CrackTree.OnBeforeTreeExport) then
      CrackTree.OnBeforeTreeExport(CrackTree, etCustom);

  // Fill table header.
  if RenderColumns then
  begin
      if Assigned(CrackTree.OnBeforeHeaderExport) then
        CrackTree.OnBeforeHeaderExport(CrackTree, etCustom);

      Columns := CrackTree.Header.Columns.GetVisibleColumns;
    for I := 0 to High(Columns) do
    begin
        if Assigned(CrackTree.OnBeforeColumnExport) then
          CrackTree.OnBeforeColumnExport(CrackTree, etCustom, Columns[I]);

        if Assigned(CrackTree.OnColumnExport) then
          CrackTree.OnColumnExport(CrackTree, etCustom, Columns[I]);

        if Assigned(CrackTree.OnAfterColumnExport) then
          CrackTree.OnAfterColumnExport(CrackTree, etCustom, Columns[I]);
    end;

      if Assigned(CrackTree.OnAfterHeaderExport) then
        CrackTree.OnAfterHeaderExport(CrackTree, etCustom);
  end;

  // Now write the content.
  Run := Save;
  while Assigned(Run) do
  begin
      if CrackTree.CanExportNode(Run) then
    begin
        if Assigned(CrackTree.OnBeforeNodeExport) then
          CrackTree.OnBeforeNodeExport(CrackTree, etCustom, Run);

        if Assigned(CrackTree.OnNodeExport) then
          CrackTree.OnNodeExport(CrackTree, etCustom, Run);

        if Assigned(CrackTree.OnAfterNodeExport) then
          CrackTree.OnAfterNodeExport(CrackTree, etCustom, Run);
    end;

    Run := GetNextNode(Run);
  end;

  if Assigned(CrackTree.OnAfterTreeExport) then
    CrackTree.OnAfterTreeExport(CrackTree, etCustom);
end;

end.
