unit VirtualStringTreeTests;

interface

uses
  fpcunit,
  testregistry,
  Forms,
  Controls,
  VirtualTrees;

type

  TVirtualStringTreeTests = class(TTestCase)
  strict private
    fTree: TVirtualStringTree;
    fForm: TForm;
    procedure FreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNodeData;
  end;

implementation

uses
  SysUtils;

type
  TMyObject = class
  public
    Value: String;
  end;

{ TVirtualStringTreeTests }

procedure TVirtualStringTreeTests.FreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  Node.GetData<TMyObject>.Free;
end;

procedure TVirtualStringTreeTests.SetUp;
begin
  inherited SetUp;
  fForm := TForm.Create(nil);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.OnFreeNode := FreeNode;
  fTree.Parent := fForm;
  fTree.Align := alClient;
end;

procedure TVirtualStringTreeTests.TearDown;
begin
  fForm.Release;
  fForm := nil;
  Application.ProcessMessages;
  inherited TearDown;
end;

procedure TVirtualStringTreeTests.TestNodeData;
var
  pL_Node: PVirtualNode;
  lMyObj1,
  lMyObj2: TMyObject;
begin
  AssertNotNull('The Virtual TreeView control was not created successfully', fTree);
  fTree.BeginUpdate;
  try
    lMyObj1 := TMyObject.Create;
    lMyObj1.Value := 'Hello World';

    pL_Node := fTree.AddChild(nil, lMyObj1);
  finally
    fTree.EndUpdate;
  end;

  lMyObj2 := TMyObject(pL_Node.GetData()^);
  AssertTrue('The object that was set as node data should equal the object that was retrieved from the node using TVirtualNode.GetData()', lMyObj1 = lMyObj2);
  AssertEquals('The object''s value which was set as node data should equal the object that was retrieved from the node using TVirtualNode.GetData()', lMyObj1.Value, lMyObj2.Value);
  lMyObj2 := TMyObject(fTree.GetNodeData(pL_Node)^);
  AssertTrue('The object that was set as node data should equal the object that was retrieved from the node using TBaseVirtualTree.GetNodeData()', lMyObj1 = lMyObj2);
  AssertEquals('The object''s value which was set as node data should equal the object that was retrieved from the node using TBaseVirtualTree.GetNodeData()', lMyObj1.Value, lMyObj2.Value);
  lMyObj2 := pL_Node.GetData<TMyObject>;
  AssertTrue('The object that was set as node data should equal the object that was retrieved from the node using TVirtualNode.GetData<T>()', lMyObj1 = lMyObj2);
  AssertEquals('The object''s value which was set as node data should equal the object that was retrieved from the node using TVirtualNode.GetData<T>()', lMyObj1.Value, lMyObj2.Value);
end;

initialization
  RegisterTest(TVirtualStringTreeTests);

end.
