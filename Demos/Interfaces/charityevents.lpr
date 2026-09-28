program charityevents;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  modelviewform,
  myeventdata,
  myevents;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormModelView, FormModelView);
  Application.Run;
end.
