Unit FrameDateTimeSelection;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, EditBtn, FrameEditor;

Type

  { TfmeDateTimeSelection }

  TfmeDateTimeSelection = Class(TFrameEditorBase)
    edtDate: TDateEdit;
    edtTime: TTimeEdit;
  Private
    Function GetDateTime: TDateTime;
    Procedure SetDateTime(Const AValue: TDateTime);
  Public
    Property DateTime: TDateTime Read GetDateTime Write SetDateTime;
  End;

Function InputQueryDateTime(ACaption: String; Var AValue: TDateTime): Boolean;

Implementation

Uses
  DialogFrameHost;

Function InputQueryDateTime(ACaption: String; Var AValue: TDateTime): Boolean;
Var
  oDlg: TDialogFrameHost;
  fmeDateTime: TfmeDateTimeSelection;
Begin
  Result := False;

  oDlg := TDialogFrameHost.Create(Application.MainForm);
  Try
    oDlg.Caption := ACaption;
    fmeDateTime := TfmeDateTimeSelection.Create(oDlg);
    oDlg.RegisterFrame(fmeDateTime, 'Date/Time');

    fmeDateTime.DateTime := AValue;

    If oDlg.ShowModal = mrOk Then
    Begin
      AValue := fmeDateTime.DateTime;
      Result := True;
    End;
  Finally
    fmeDateTime.Free;
    oDlg.Free;
  End;
End;

{$R *.lfm}

{ TfmeDateTimeSelection }

Function TfmeDateTimeSelection.GetDateTime: TDateTime;
Begin
  Result := Trunc(edtDate.Date) + Frac(edtTime.Time);
End;

Procedure TfmeDateTimeSelection.SetDateTime(Const AValue: TDateTime);
Begin
  edtDate.Date := Trunc(AValue);
  edtTime.Time := Frac(AValue);
End;

End.
