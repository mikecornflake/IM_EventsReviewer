Program IM_StarfixReviewer;

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
  FormStarfixAnomalies;

  {$R *.res}

Begin
  RequireDerivedFormResource := True;
  Application.Title:='IM Starfix Reviewer';
  Application.Scaled:=True;
  {$PUSH}
  {$WARN 5044 OFF}
  Application.MainFormOnTaskbar := True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TfrmStarfixReviewer, frmStarfixReviewer);
  Application.Run;
End.
