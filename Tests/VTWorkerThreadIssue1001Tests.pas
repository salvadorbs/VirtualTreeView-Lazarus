unit VTWorkerThreadIssue1001Tests;

interface

uses
  fpcunit,
  testregistry,
  Forms,
  VirtualTrees;

type
  TVTWorkerThreadIssue1001Tests = class(TTestCase)
  strict private
    procedure TreeCompareNodes(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode;
      Column: TColumnIndex; var Result: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestDestroyWhileWorkerThreadBusy;
  end;

implementation

uses
  Classes,
  SysUtils,
  VirtualTrees.Types,
  VirtualTrees.WorkerThread;

procedure TVTWorkerThreadIssue1001Tests.TreeCompareNodes(
  Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode; Column: TColumnIndex;
  var Result: Integer);
begin
  if Random(10) > 5 then
    Result := 1
  else
    Result := -1;
end;

procedure TVTWorkerThreadIssue1001Tests.SetUp;
begin
  inherited SetUp;
  Randomize;
end;

procedure TVTWorkerThreadIssue1001Tests.TearDown;
begin
  inherited TearDown;
end;

procedure TVTWorkerThreadIssue1001Tests.TestDestroyWhileWorkerThreadBusy;
const
  cRepeatCount = 100;
var
  i: Integer;
  lForm: TForm;
  lTree: TVirtualStringTree;
begin
  // The upstream test uses a bare TVTAncestor descendant, but instantiating the
  // abstract LCL ancestor directly is not safe. TVirtualStringTree exercises the
  // same worker-thread destruction path.
  // Repeated because access violations while the worker thread is finishing are
  // not deterministic and may not show up in a single run.
  for i := 1 to cRepeatCount do
  begin
    lForm := TForm.Create(nil);
    lTree := TVirtualStringTree.Create(lForm);
    lTree.TreeOptions.AutoOptions := lTree.TreeOptions.AutoOptions - [toAutoSort];
    lTree.OnCompareNodes := TreeCompareNodes;

    lTree.BeginUpdate;
    try
      lTree.ChildCount[lTree.RootNode] := 10000;
      AssertEquals('TotalCount <> ChildCount + 1',
        Int64(lTree.RootNode.ChildCount) + 1, Int64(lTree.RootNode.TotalCount));
    finally
      lTree.EndUpdate;
    end;

    FreeAndNil(lTree);
    FreeAndNil(lForm);
  end;
end;

initialization
  Randomize;
  RegisterTest(TVTWorkerThreadIssue1001Tests);

end.
