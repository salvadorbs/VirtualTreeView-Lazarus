unit VTOnDrawTextTests;

interface

uses
  fpcunit,
  testregistry,
  Forms,
  Graphics,
  VirtualTrees.Types,
  VirtualTrees, Types;

type

  TVTOnDrawTextTests = class(TTestCase)
  strict private
    fTree: TVirtualStringTree;
    fForm: TForm;

    FDrawText1Called: Boolean;
    FDrawTextEx1Called: Boolean;

    FDrawText2Called: Boolean;
    FDrawTextEx2Called: Boolean;

    FDrawText3Called: Boolean;
    FDrawTextEx3Called: Boolean;

    // Invokes the text drawing routine that raises OnDrawText / OnDrawTextEx.
    // It does not depend on the widgetset actually repainting the control,
    // because LCL repaints differently on each backend (win32, gtk2, gtk3, qt).
    procedure TriggerTextDrawing;

    procedure DrawText1Event(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const Text: string;
      const CellRect: TRect; var DefaultDraw: Boolean);

    procedure DrawTextEx2Event(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const Text: string;
      const CellRect: TRect; var DefaultDraw: Boolean; var DrawFormat: Cardinal);

    procedure DrawText3Event(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const Text: string;
      const CellRect: TRect; var DefaultDraw: Boolean);
    procedure DrawTextEx3Event(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const Text: string;
      const CellRect: TRect; var DefaultDraw: Boolean; var DrawFormat: Cardinal);

    procedure GetTextEvent(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestOnDrawText;

    procedure TestOnDrawTextOnDrawTextEx;

    procedure TestOnDrawTextEx;
  end;

  // Bypasses the protected DoTextDrawing so the test does not depend on the
  // widgetset actually painting the control.
  TVirtualStringTreeAccess = class(TVirtualStringTree)
  public
    procedure DoTextDrawingAccess(var PaintInfo: TVTPaintInfo; const Text: string;
      CellRect: TRect; DrawFormat: Cardinal);
  end;

implementation

uses
  SysUtils;

const
  colCaption = 0;
  colData    = 1;

procedure TVirtualStringTreeAccess.DoTextDrawingAccess(var PaintInfo: TVTPaintInfo;
  const Text: string; CellRect: TRect; DrawFormat: Cardinal);
begin
  DoTextDrawing(PaintInfo, Text, CellRect, DrawFormat);
end;

procedure TVTOnDrawTextTests.TriggerTextDrawing;
var
  LBitmap: TBitmap;
  LPaintInfo: TVTPaintInfo;
begin
  LBitmap := TBitmap.Create;
  try
    LBitmap.SetSize(200, 20);
    LPaintInfo := Default(TVTPaintInfo);
    LPaintInfo.Canvas := LBitmap.Canvas;
    LPaintInfo.Node := fTree.GetFirstChild(fTree.RootNode);
    LPaintInfo.Column := colCaption;
    TVirtualStringTreeAccess(fTree).DoTextDrawingAccess(LPaintInfo, 'Caption',
      Rect(0, 0, 200, 20), 0);
  finally
    LBitmap.Free;
  end;
end;

procedure TVTOnDrawTextTests.DrawText1Event(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
begin
  FDrawText1Called := True;
end;

procedure TVTOnDrawTextTests.DrawText3Event(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
begin
  FDrawText3Called := True;
end;

procedure TVTOnDrawTextTests.DrawTextEx2Event(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: string; const CellRect: TRect; var DefaultDraw: Boolean;
  var DrawFormat: Cardinal);
begin
  FDrawTextEx2Called := True;
end;

procedure TVTOnDrawTextTests.DrawTextEx3Event(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: string; const CellRect: TRect; var DefaultDraw: Boolean;
  var DrawFormat: Cardinal);
begin
  FDrawTextEx3Called := True;
end;

procedure TVTOnDrawTextTests.GetTextEvent(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
begin
  case Column of
    colCaption: begin
      CellText := 'Caption';
    end;
    colData: begin
      CellText := 'Data';
    end;
  end;
end;

procedure TVTOnDrawTextTests.SetUp;
var
  LCol1: TVirtualTreeColumn;
  LCol2: TVirtualTreeColumn;
begin
  inherited SetUp;
  FDrawText1Called := False;
  FDrawTextEx1Called := False;

  FDrawText2Called := False;
  FDrawTextEx2Called := False;

  FDrawText3Called := False;
  FDrawTextEx3Called := False;

  fForm := TForm.Create(nil);
  fTree := TVirtualStringTree.Create(fForm);
  fForm.InsertControl(fTree);

  fTree.OnGetText := GetTextEvent;

  LCol1 := fTree.Header.Columns.Add;
  LCol2 := fTree.Header.Columns.Add;
  LCol1.Text := 'Caption';
  LCol2.Text := 'Data';

  fTree.AddChild(fTree.RootNode);
  fTree.AddChild(fTree.RootNode);
  fForm.Show;
end;

procedure TVTOnDrawTextTests.TearDown;
begin
  FreeAndNil(fForm);
  inherited TearDown;
end;

procedure TVTOnDrawTextTests.TestOnDrawText;
begin
  // This test ensures that OnDrawText event is called when OnDrawText is assigned
  fTree.OnDrawText := DrawText1Event;
  fTree.OnDrawTextEx := nil;
  TriggerTextDrawing;

  AssertTrue(FDrawText1Called and not FDrawTextEx1Called);
end;

procedure TVTOnDrawTextTests.TestOnDrawTextEx;
begin
  // This test ensures that OnDrawTextEx event is called when OnDrawTextEx is assigned
  // and that OnDrawText is not called
  fTree.OnDrawText := nil;
  fTree.OnDrawTextEx := DrawTextEx2Event;
  TriggerTextDrawing;

  AssertTrue(not FDrawText2Called and FDrawTextEx2Called);
end;

procedure TVTOnDrawTextTests.TestOnDrawTextOnDrawTextEx;
begin
  // This test ensures that only the OnDrawTextEx event is called when both
  // OnDrawText and OnDrawTextEx are assigned and that OnDrawText is not called
  fTree.OnDrawText := DrawText3Event;
  fTree.OnDrawTextEx := DrawTextEx3Event;
  TriggerTextDrawing;

  AssertTrue(not FDrawText3Called and FDrawTextEx3Called);
end;

initialization
  RegisterTest(TVTOnDrawTextTests);
end.
