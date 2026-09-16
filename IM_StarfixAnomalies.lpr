program IM_StarfixAnomalies;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, FormStarfixAnomalies, EventListingProvider;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Title:='IM Starfix Anomaly Management';
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TfrmStarfixAnomalies, frmStarfixAnomalies);
  Application.Run;
end.

