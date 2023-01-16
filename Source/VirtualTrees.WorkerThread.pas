unit VirtualTrees.WorkerThread;

{$mode delphi}

interface

{$I VTConfig.inc}

uses
  Classes, VirtualTrees.BaseTree, SyncObjs, LCLType, LCLIntf, VirtualTrees.Types;

type
  { TWorkerThread }

  TWorkerThread = class(TThread)
  private
    FCurrentTree: TBaseVirtualTree;
    FWaiterList: TThreadList;
    FRefCount: Cardinal;
    FWorkEvent: TEvent;

    class procedure EnsureCreated();
  protected
    procedure CancelValidation(Tree: TBaseVirtualTree);
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;

    class procedure AddTree(Tree: TBaseVirtualTree);
    class procedure RemoveTree(Tree: TBaseVirtualTree);

    /// For lifeteime management of the TWorkerThread
    class procedure AddThreadReference;
    class procedure ReleaseThreadReference(Tree: TBaseVirtualTree);

    property CurrentTree: TBaseVirtualTree read FCurrentTree;
  end;

implementation

uses
  SysUtils, Forms
  {$ifdef Windows}
  , Windows
  {$endif}
  ;

type
  TBaseVirtualTreeCracker = class(TBaseVirtualTree);

var
  WorkerThread: TWorkerThread = nil;

//----------------- TWorkerThread --------------------------------------------------------------------------------------

class procedure TWorkerThread.AddThreadReference;
begin
  if not Assigned(WorkerThread) then
  begin
    // Create worker thread, initialize it and send it to its wait loop.
    WorkerThread := TWorkerThread.Create(False);
    // Create an event used to trigger our worker thread when something is to do.
    WorkerThread.FWorkEvent := TEvent.Create(nil, False, False, '');
    //todo: see how to check if a event was succesfully created under linux since handle is allways 0
    {$ifdef Windows}
    if WorkerThread.FWorkEvent.Handle = TEventHandle(0) then
      Raise Exception.Create('VirtualTreeView - Error creating TEvent instance');
    {$endif}
  end;
  Inc(WorkerThread.FRefCount);
end;

//----------------------------------------------------------------------------------------------------------------------

class procedure TWorkerThread.ReleaseThreadReference(Tree: TBaseVirtualTree);
begin
  if Assigned(WorkerThread) then
  begin
    Dec(WorkerThread.FRefCount);

    // Make sure there is no reference remaining to the releasing tree.
    TBaseVirtualTreeCracker(Tree).InterruptValidation;

    if WorkerThread.FRefCount = 0 then
    begin
      WorkerThread.Terminate;
      WorkerThread.FWorkEvent.SetEvent;

      WorkerThread.FWorkEvent.Free;
      WorkerThread.Free;
      WorkerThread := nil;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

constructor TWorkerThread.Create(CreateSuspended: Boolean);

begin
  inherited Create(CreateSuspended);
  FWaiterList := TThreadList.Create;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TWorkerThread.Destroy;

begin
  // First let the ancestor stop the thread before freeing our resources.
  inherited;

  FWaiterList.Free;
end;

//----------------------------------------------------------------------------------------------------------------------

class procedure TWorkerThread.EnsureCreated;
begin
  if not Assigned(WorkerThread) then
    // Create worker thread, initialize it and send it to its wait loop.
    TWorkerThread.AddThreadReference();
end;

procedure TWorkerThread.CancelValidation(Tree: TBaseVirtualTree);

var
  Msg: TMsg;

begin
  // Wait for any references to this tree to be released.
  // Pump WM_CHANGESTATE messages so the thread doesn't block on SendMessage calls.
  while FCurrentTree = Tree do
  begin
    if Tree.HandleAllocated and PeekMessage(Msg, Tree.Handle, WM_CHANGESTATE, WM_CHANGESTATE, PM_REMOVE) then
    begin
      //todo: see if is correct / will work
      Application.ProcessMessages;
      continue;
      //TranslateMessage(Msg);
      //DispatchMessage(Msg);
    end;
    //Todo splitting files
    //if (toVariableNodeHeight in TBaseVirtualTreeCracker(Tree).TreeOptions.MiscOptions) then
      CheckSynchronize(); // We need to call CheckSynchronize here because we are using TThread.Synchronize in TBaseVirtualTree.MeasureItemHeight()
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TWorkerThread.Execute;

// Does some background tasks, like validating tree caches.

var
  EnterStates,
  LeaveStates: TChangeStates;
  lCurrentTree: TBaseVirtualTree;

begin
  while not Terminated do
  begin
    FWorkEvent.WaitFor(INFINITE);
    if not Terminated then
    begin
      // Get the next waiting tree.
      with FWaiterList.LockList do
      try
        if Count > 0 then
        begin
          FCurrentTree := Items[0];
          // Remove this tree from waiter list.
          Delete(0);
          // If there is yet another tree to work on then set the work event to keep looping.
          if Count > 0 then
            FWorkEvent.SetEvent;
        end
        else
          FCurrentTree := nil;
      finally
        FWaiterList.UnlockList;
      end;

      // Something to do?
      if Assigned(FCurrentTree) then
      begin
        try
          TBaseVirtualTreeCracker(FCurrentTree).ChangeTreeStatesAsync([csValidating], [csUseCache, csValidationNeeded]);
          EnterStates := [];
          if not (tsStopValidation in TBaseVirtualTreeCracker(FCurrentTree).TreeStates) and TBaseVirtualTreeCracker(FCurrentTree).DoValidateCache then
            EnterStates := [csUseCache];

        finally
          LeaveStates := [csValidating, csStopValidation];
          TBaseVirtualTreeCracker(FCurrentTree).ChangeTreeStatesAsync(EnterStates, LeaveStates);
          lCurrentTree := FCurrentTree; // Save reference in a local variable for later use
          FCurrentTree := nil; //Clear variable to prevent deadlock in CancelValidation. See #434
          Synchronize(TBaseVirtualTreeCracker(lCurrentTree).UpdateEditBounds);
        end;
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

class procedure TWorkerThread.AddTree(Tree: TBaseVirtualTree);

begin
  Assert(Assigned(Tree), 'Tree must not be nil.');
  TWorkerThread.EnsureCreated();

  // Remove validation stop flag, just in case it is still set.
  TBaseVirtualTreeCracker(Tree).DoStateChange([], [tsStopValidation]);
  with WorkerThread.FWaiterList.LockList do
  try
    if IndexOf(Tree) = -1 then
      Add(Tree);
  finally
    WorkerThread.FWaiterList.UnlockList;
  end;

  WorkerThread.FWorkEvent.SetEvent;
end;

//----------------------------------------------------------------------------------------------------------------------

class procedure TWorkerThread.RemoveTree(Tree: TBaseVirtualTree);
begin
  if not Assigned(WorkerThread) then
    exit;

  Assert(Assigned(Tree), 'Tree must not be nil.');

  with WorkerThread.FWaiterList.LockList do
  try
    Remove(Tree);
  finally
    WorkerThread.FWaiterList.UnlockList; // Seen several AVs in this line, was called from TWorkerThrea.Destroy. Joachim Marder.
  end;
  WorkerThread.CancelValidation(Tree);
end;

end.
