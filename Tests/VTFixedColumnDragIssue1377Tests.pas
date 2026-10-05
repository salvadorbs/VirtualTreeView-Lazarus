unit VTFixedColumnDragIssue1377Tests;

// Regression test for issue #1377 "Normal columns can be dragged in front of fixed
// columns (!) and cannot be dragged back".
//
// Dropping a normal column inside the fixed area made it fixed (deliberate behavior
// of TVirtualTreeColumn.SetPosition) - and since issue #1314 fixed columns lose
// coDraggable, so the column was trapped there for good.
//
// The fix redirects the drop target in TVTHeader.DragTo(): when a non-fixed column
// is dragged over a fixed one, the target becomes the first non-fixed visible
// column, so the drop lands right after the fixed area. The deliberate programmatic
// behavior (assigning Position directly moves a column into the fixed area and makes
// it fixed) is unchanged and covered by a test as well.
//
// FPCUnit/LCL port of the upstream DUnitX test. Unlike VCL, where the header lives
// in the window's non-client area, the LCL header is painted at the top of the
// client area, so the drag point uses a positive Y inside the header band.

interface

uses
  fpcunit,
  testregistry,
  Types,
  Forms,
  VirtualTrees;

type
  TVTFixedColumnDragIssue1377Tests = class(TTestCase)
  strict private
    fForm: TForm;
    fTree: TVirtualStringTree;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    /// Dragging a normal column over the fixed area must land it right after the
    /// fixed columns, keeping it normal and draggable.
    procedure DropOnFixedAreaLandsAfterFixedColumns;

    /// The deliberate programmatic behavior is unchanged: assigning Position
    /// directly still moves the column into the fixed area and makes it fixed.
    procedure DirectPositionAssignmentStillEntersFixedArea;
  end;

implementation

uses
  SysUtils,
  Controls,
  LCLIntf,
  VirtualTrees.Types,
  VirtualTrees.Header;

procedure TVTFixedColumnDragIssue1377Tests.SetUp;
var
  I: Integer;
begin
  inherited SetUp;

  fForm := TForm.Create(nil);
  fForm.SetBounds(0, 0, 420, 300);
  fTree := TVirtualStringTree.Create(fForm);
  fTree.Parent := fForm;
  fTree.SetBounds(0, 0, 400, 260);
  for I := 0 to 2 do
    with fTree.Header.Columns.Add do
      Width := 80;
  fTree.Header.Columns[0].Options := fTree.Header.Columns[0].Options + [coFixed];
  fTree.Header.Options := fTree.Header.Options + [hoVisible, hoDrag];
  fForm.Show;
  Application.ProcessMessages;
end;

procedure TVTFixedColumnDragIssue1377Tests.TearDown;
begin
  inherited TearDown;

  FreeAndNil(fForm);
end;

procedure TVTFixedColumnDragIssue1377Tests.DropOnFixedAreaLandsAfterFixedColumns;
var
  P: TPoint;
  R: TRect;
begin
  AssertFalse('Sanity: the fixed column must not be draggable (issue #1314).',
    coDraggable in fTree.Header.Columns[0].Options);

  // Simulate dragging column 2 over the fixed column 0: point inside the header,
  // horizontally in the middle of column 0. The LCL header lives in the client
  // area, so the Y coordinate is positive (VCL uses a negative Y in the
  // non-client area).
  fTree.Header.Columns.DragIndex := 2;
  P := fTree.ClientToScreen(Point(40, fTree.Header.Height div 2));
  fTree.Header.DragTo(P);

  AssertTrue('The fixed column must not become the drop target (issue #1377).',
    fTree.Header.Columns.DropTarget <> 0);
  AssertEquals('The drop target must be redirected to the first non-fixed column.',
    1, Integer(fTree.Header.Columns.DropTarget));
  AssertTrue('The drop must aim before the first non-fixed column.',
    fTree.Header.Columns.DropBefore);

  // Re-anchor the drop point to the current window position: the window manager
  // may have (re)positioned the window after the ClientToScreen above, and
  // ColumnDropped only performs the drop while the point lies inside the window
  // rect (otherwise the drop is silently skipped).
  GetWindowRect(fTree.Handle, R);
  P := Point(R.Left + 40, R.Top + fTree.Header.Height div 2);
  fTree.Header.ColumnDropped(P);

  AssertEquals('The dropped column must land right after the fixed area (issue #1377).',
    1, Integer(fTree.Header.Columns[2].Position));
  AssertEquals('The fixed column must stay at position 0.',
    0, Integer(fTree.Header.Columns[0].Position));
  AssertFalse('The dropped column must not become fixed (issue #1377).',
    coFixed in fTree.Header.Columns[2].Options);
  AssertTrue('The dropped column must remain draggable (issue #1377).',
    coDraggable in fTree.Header.Columns[2].Options);
end;

procedure TVTFixedColumnDragIssue1377Tests.DirectPositionAssignmentStillEntersFixedArea;
begin
  fTree.Header.Columns[2].Position := 0;
  AssertTrue('Programmatically moving a column into the fixed area must still make it fixed (deliberate behavior).',
    coFixed in fTree.Header.Columns[2].Options);
end;

initialization
  RegisterTest(TVTFixedColumnDragIssue1377Tests);

end.
