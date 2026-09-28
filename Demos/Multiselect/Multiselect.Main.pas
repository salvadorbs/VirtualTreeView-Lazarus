unit Multiselect.Main;

{$MODE Delphi}

// Virtual Treeview sample form demonstrating following feature:
//   - Multiple cell selection.
// Written by CheeWee Chua.
//
// LCL port: inline variable declarations were moved to the var sections
// (FPC 3.2 does not support them) and the mouse/keyboard simulation was
// reimplemented on top of LCL messages instead of the Win32 keyboard state.

interface

uses
  LCLIntf, LCLType, LMessages, SysUtils, Variants,
  Classes, Graphics, Controls, Forms, Dialogs,
  VirtualTrees.BaseTree, VirtualTrees,
  StdCtrls, ExtCtrls;

type
  TForm1 = class(TForm)
    VirtualStringTree1: TVirtualStringTree;
    Panel1: TPanel;
    btnSelect4CellsLeftToRight: TButton;
    btnSelect4CellsRightToLeft: TButton;
    btnClickRow2Col1: TButton;
    btnClickRow1Col1: TButton;
    btnSelectRow3Col1Row4Col2: TButton;
    btnSelectRow2_3_Copy: TButton;
    procedure FormCreate(Sender: TObject);
    procedure VirtualStringTree1FreeNode(Sender: TBaseVirtualTree;
      Node: PVirtualNode);
    procedure VirtualStringTree1GetText(Sender: TBaseVirtualTree;
      Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
      var CellText: string);
    procedure btnSelect4CellsLeftToRightClick(Sender: TObject);
    procedure btnSelect4CellsRightToLeftClick(Sender: TObject);
    procedure btnClickRow1Col1Click(Sender: TObject);
    procedure btnClickRow2Col1Click(Sender: TObject);
    procedure btnSelectRow3Col1Row4Col2Click(Sender: TObject);
    procedure btnSelectRow2_3_CopyClick(Sender: TObject);
    procedure VirtualStringTree1KeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }

    procedure EnableMulticellSelection;
    procedure EnableFullRowSelection;

    // Compute a client area point that reliably hits the given node/column.
    function GetHitPoint(ANode: PVirtualNode; AColumn: TColumnIndex): TPoint;

    // These functions mimic human interaction with the user interface
    procedure MouseClick(const ACursorPos: TPoint; Modifiers: Byte); overload;
    procedure MouseClick(const ACursorPos: TPoint); overload;
    procedure MouseClick(ANode: PVirtualNode; AColumn: TColumnIndex = 0); overload;
    procedure ShiftMouseClick(ANode: PVirtualNode; AColumn: TColumnIndex = 0); overload;
    procedure ShiftMouseClick(const ACell: TVTCell); overload;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  VirtualTrees.Types, VirtualTrees.Clipboard;

{$R *.lfm}

type
  TRowData = record
    table_schema: string;
    table_name: string;
    table_type: string;
  public
    constructor Create(const ASchema, AName, AType: string);
    procedure Clear;
    class operator Finalize(var Self: TRowData);
  end;

{ TRowData }

procedure TRowData.Clear;
begin
  table_schema := '';
  table_name   := '';
  table_type   := '';
end;

constructor TRowData.Create(const ASchema, AName, AType: string);
begin
  table_schema := ASchema;
  table_name   := AName;
  table_type   := AType;
end;

class operator TRowData.Finalize(var Self: TRowData);
begin
  Self.Clear;
end;

const
  colSchema = 0;
  colName   = 1;
  colType   = 2;

procedure TForm1.btnClickRow1Col1Click(Sender: TObject);
var
  LTree: TVirtualStringTree;
  LNode: PVirtualNode;
begin
  EnableMulticellSelection;
  LTree := VirtualStringTree1;
  LNode := LTree.GetFirstChild(LTree.RootNode);
  MouseClick(LNode);
end;

procedure TForm1.btnClickRow2Col1Click(Sender: TObject);
var
  LTree: TVirtualStringTree;
  LNode: PVirtualNode;
begin
  EnableMulticellSelection;
  LTree := VirtualStringTree1;
  LNode := LTree.GetFirstChild(LTree.RootNode);
  LNode := LTree.GetNext(LNode);
  MouseClick(LNode);
end;

procedure TForm1.btnSelect4CellsLeftToRightClick(Sender: TObject);
var
  LTree: TVirtualStringTree;
  LNode, L3rdRow, L4thRow: PVirtualNode;
  I: Integer;
begin
  EnableMulticellSelection;
  LTree := VirtualStringTree1;
  LTree.ClearCellSelection;

  LNode := LTree.GetFirstChild(LTree.RootNode);
  for I := 1 to 2 do
    LNode := LTree.GetNext(LNode);
  // We're on 3rd row now...
  L3rdRow := LNode; // 3rd row
  L4thRow := LTree.GetNext(L3rdRow); // 4th row

  // Select cells from left to right
  LTree.SelectCells(
    L3rdRow, 1, // Left aka Start
    L4thRow, 2, // Right aka End
    True);
end;

procedure TForm1.btnSelect4CellsRightToLeftClick(Sender: TObject);
var
  LTree: TVirtualStringTree;
  LNode, L3rdRow, L4thRow: PVirtualNode;
  I: Integer;
begin
  EnableMulticellSelection;
  LTree := VirtualStringTree1;

  LTree.ClearCellSelection;

  LNode := LTree.GetFirstChild(LTree.RootNode);
  for I := 1 to 2 do
    LNode := LTree.GetNext(LNode);
  // We're on 3rd row now...
  L3rdRow := LNode;
  L4thRow := LTree.GetNext(L3rdRow); // 4th row
  LTree.SelectCells(
    L4thRow, 2,  // Right aka Start
    L3rdRow, 1,  // Left aka End
    True);
end;

procedure TForm1.btnSelectRow2_3_CopyClick(Sender: TObject);
var
  LTree: TVirtualStringTree;
  LNode1, LNode2, LNode3: PVirtualNode;
begin
  // RegisterVTClipboardFormat(CF_TEXT, TVirtualStringTree);
  EnableFullRowSelection;
  LTree := VirtualStringTree1;

  LNode1 := LTree.GetFirstVisible();
  LNode2 := LTree.GetNextVisible(LNode1);
  LNode3 := LTree.GetNextVisible(LNode2);
  LTree.Selected[LNode2] := True;
  LTree.Selected[LNode3] := True;

  LTree.CopyToClipboard;
end;

procedure TForm1.btnSelectRow3Col1Row4Col2Click(Sender: TObject);
var
  LTree: TVirtualStringTree;
  LNode, L3rdRow, L4thRow: PVirtualNode;
  I: Integer;
begin
  EnableMulticellSelection;
  LTree := VirtualStringTree1;

  LNode := LTree.GetFirstChild(LTree.RootNode);
  for I := 1 to 2 do
    LNode := LTree.GetNext(LNode);
  // We're on 3rd row now...
  L3rdRow := LNode; // 3rd row
  L4thRow := LTree.GetNext(L3rdRow); // 4th row

  // column 1 in code is column 2 in human eyes...
  MouseClick(L3rdRow, 1);

  // column 2 in code is column 3 in human eyes...
  ShiftMouseClick(TVTCell.Create(L4thRow, 2));

  LTree.CopyToClipboard;
end;

procedure TForm1.EnableFullRowSelection;
var
  LTree: TVirtualStringTree;
begin
  LTree := VirtualStringTree1;
  LTree.TreeOptions.SelectionOptions := LTree.TreeOptions.SelectionOptions +
    [toFullRowSelect];
end;

procedure TForm1.EnableMulticellSelection;
var
  LTree: TVirtualStringTree;
begin
  LTree := VirtualStringTree1;
  LTree.TreeOptions.SelectionOptions := LTree.TreeOptions.SelectionOptions +
    [toMultiSelect, toExtendedFocus] - [toFullRowSelect];
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  LTree: TVirtualStringTree;
  LNode1, LNode2, LNode3, LNode4: PVirtualNode;
  LNode5, LNode6, LNode7, LNode8: PVirtualNode;
begin
  LTree := VirtualStringTree1;

  LTree.NodeDataSize := SizeOf(TRowData);

  LNode1 := LTree.AddChild(LTree.RootNode);
  LNode2 := LTree.AddChild(LTree.RootNode);
  LNode3 := LTree.AddChild(LTree.RootNode);
  LNode4 := LTree.AddChild(LTree.RootNode);
  LNode5 := LTree.AddChild(LTree.RootNode);
  LNode6 := LTree.AddChild(LTree.RootNode);
  LNode7 := LTree.AddChild(LTree.RootNode);
  LNode8 := LTree.AddChild(LTree.RootNode);

  LNode1.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_user_info',  'VIEW'));
  LNode2.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_stastic',    'BASE TABLE'));
  LNode3.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_settings',   'VIEW1'));
  LNode4.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_type',       'VIEW2'));
  LNode5.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_attribute',  'BASE TABLE'));
  LNode6.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_class',      'BASE TABLE'));
  LNode7.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_tablespace', 'BASE TABLE'));
  LNode8.SetData<TRowData>(TRowData.Create('pg_catalog', 'pg_inherits',   'BASE TABLE'));

  LTree.ClipboardFormats.Add(GetVTClipboardFormatDescription(CF_TEXT));
  LTree.ClipboardFormats.Add(GetVTClipboardFormatDescription(CF_UNICODETEXT));
  LTree.ClipboardFormats.Add(GetVTClipboardFormatDescription(CF_VRTF));
  LTree.ClipboardFormats.Add(GetVTClipboardFormatDescription(CF_HTML));
end;

procedure TForm1.VirtualStringTree1FreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  LData: TRowData;
begin
  LData := Node.GetData<TRowData>;
  LData.Clear;
end;

procedure TForm1.VirtualStringTree1GetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
var
  LData: TRowData;
begin
  if not Assigned(Node) then
    Exit;
  LData := Node.GetData<TRowData>;
  case Column of
    colSchema: begin
      CellText := LData.table_schema;
    end;
    colName: begin
      CellText := LData.table_name;
    end;
    colType: begin
      CellText := LData.table_type;
    end;
    // column 4 is deliberately left empty
  end;
end;

// Compute a client area point that reliably hits the given node/column.
// The upstream Delphi demo derived the point from Mouse.CursorPos and the
// real keyboard state; under LCL we compute the point from the tree geometry
// and pass the modifier flags directly to the message.
function TForm1.GetHitPoint(ANode: PVirtualNode; AColumn: TColumnIndex): TPoint;
var
  LHitInfo: THitInfo;
  LPasses, LCount: Integer;
  LRect: TRect;
begin
  if not Assigned(ANode) then
    Exit(Point(-1, -1));

  LRect := VirtualStringTree1.GetDisplayRect(ANode, AColumn, True, True, True);
  Result := LRect.TopLeft;
  if hoVisible in VirtualStringTree1.Header.Options then
    Inc(Result.Y, VirtualStringTree1.Header.Height);

  LPasses := 0;
  LCount := VirtualStringTree1.VisibleCount;
  repeat
    VirtualStringTree1.GetHitTestInfoAt(Result.X, Result.Y, True, LHitInfo, []);
    if Assigned(LHitInfo.HitNode) and (LHitInfo.HitNode <> ANode) then
      Inc(Result.Y, LHitInfo.HitNode.NodeHeight);
    Inc(LPasses); // Prevent forever loop
  until (LHitInfo.HitNode = ANode) or (LPasses > LCount);
end;

procedure TForm1.MouseClick(const ACursorPos: TPoint; Modifiers: Byte);
var
  LParam: PtrInt;
begin
  LParam := PtrInt(Word(ACursorPos.X)) or (PtrInt(Word(ACursorPos.Y)) shl 16);
  VirtualStringTree1.Perform(LM_LBUTTONDOWN, MK_LBUTTON or Modifiers, LParam);
  VirtualStringTree1.Perform(LM_LBUTTONUP, MK_LBUTTON or Modifiers, LParam);
end;

procedure TForm1.MouseClick(const ACursorPos: TPoint);
begin
  MouseClick(ACursorPos, 0);
end;

procedure TForm1.MouseClick(ANode: PVirtualNode; AColumn: TColumnIndex);
begin
  MouseClick(GetHitPoint(ANode, AColumn), 0);
end;

procedure TForm1.ShiftMouseClick(const ACell: TVTCell);
begin
  ShiftMouseClick(ACell.Node, ACell.Column);
end;

procedure TForm1.ShiftMouseClick(ANode: PVirtualNode; AColumn: TColumnIndex = 0);
begin
  MouseClick(GetHitPoint(ANode, AColumn), MK_SHIFT);
end;

procedure TForm1.VirtualStringTree1KeyPress(Sender: TObject; var Key: Char);
begin
  // Press Ctrl+C to copy to clipboard
  if Key = ^C then
    begin
      VirtualStringTree1.CopyToClipboard;
    end;
end;

end.
