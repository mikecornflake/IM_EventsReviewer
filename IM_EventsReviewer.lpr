Program IM_EventsReviewer;

{$mode objfpc}{$H+}

Uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  FormEventsReviewer, DataFilters, FrameEditor;

  {$R *.res}

Begin
  RequireDerivedFormResource := True;
  Application.Title:='IM Events Reviewer';
  Application.Scaled:=True;
  {$PUSH}
  {$WARN 5044 OFF}
  Application.MainFormOnTaskbar := True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TfrmEventsReviewer, frmEventsReviewer);
  Application.Run;
End.
