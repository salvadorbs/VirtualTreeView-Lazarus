unit VTEditLinkReleaseTests;

// Regression test for the editor release of a tree that is destroyed while it
// is editing.
//
// The edit link used to post CM_RELEASE to the editor handle from its
// destructor. That is a VCL idiom: no TWinControl handler consumes
// CM_RELEASE in the LCL, and the queued message keeps the raw handle. When
// the editor dies together with its parent - the usual case while a form is
// being freed - the queued message was delivered to freed memory on the next
// message loop iteration, which crashed the gtk3 (and Qt) tests that happened
// to run afterwards.

interface

uses
  fpcunit,
  testregistry,
  Forms,
  VirtualTrees;

type
  TVTEditLinkReleaseTests = class(TTestCase)
  strict private

    fForm: TForm;

    fTree: TVirtualStringTree;

  protected

    procedure SetUp; override;

    procedure TearDown; override;

  published

    procedure DestroyingTheTreeWhileEditingDoesNotCrashTheQueue;

  end;

implementation

uses
  SysUtils;

procedure TVTEditLinkReleaseTests.SetUp;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 320, 220);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(10, 10, 300, 180);
  fTree.Header.Columns.Add;
  fTree.TreeOptions.MiscOptions := fTree.TreeOptions.MiscOptions + [toEditable];
  fTree.RootNodeCount := 1;
  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTEditLinkReleaseTests.TearDown;
begin
  FreeAndNil(fForm);
  inherited TearDown;
end;

procedure TVTEditLinkReleaseTests.DestroyingTheTreeWhileEditingDoesNotCrashTheQueue;
begin
  AssertTrue('The tree must be able to start editing the first node.', fTree.EditNode(fTree.GetFirst, 0));
  Application.ProcessMessages;

  // Destroying the form destroys the editor together with the tree, so the
  // release of the editor must not reach the (already gone) widget.
  FreeAndNil(fForm);
  Application.ProcessMessages;
  Application.ProcessMessages;

  AssertTrue('Processing the pending messages after the destroy must not crash.', True);
end;

initialization
  RegisterTest(TVTEditLinkReleaseTests);

end.
