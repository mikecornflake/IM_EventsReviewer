Unit FrameApplicationSettings;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, EditBtn, Spin,
  FrameBase;

Type

  { TFrameApplicationSettings }

  TFrameApplicationSettings = Class(TFrameBase)
    Bevel2: TBevel;
    edtEventImageFolder: TDirectoryEdit;
    edtVessel: TEdit;
    edtAnomalyImageFolder: TDirectoryEdit;
    edtROV: TEdit;
    edtVideoFolder: TDirectoryEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    edtMaxVideoDuration: TSpinEdit;
    Procedure FormCreate(Sender: TObject);
  Private
    Function GetAnomalyImageFolder: String;
    function GetEventImageFolder: String;
    Function GetMaxVideoDuration: Integer;
    Function GetROV: String;
    Function GetVessel: String;
    Function GetVideoFolder: String;
    procedure SetAnomalyImageFolder(const AValue: String);
    procedure SetEventImageFolder(const AValue: String);
    Procedure SetMaxVideoDuration(Const AValue: Integer);
    Procedure SetROV(Const AValue: String);
    Procedure SetVessel(Const AValue: String);
    Procedure SetVideoFolder(Const AValue: String);
  Public
    Property AnomalyImageFolder: String Read GetAnomalyImageFolder Write SetAnomalyImageFolder;
    Property EventImageFolder: String Read GetEventImageFolder Write SetEventImageFolder;
    Property VideoFolder: String Read GetVideoFolder Write SetVideoFolder;
    Property Vessel: String Read GetVessel Write SetVessel;
    Property ROV: String Read GetROV Write SetROV;
    Property MaxVideoDuration: Integer Read GetMaxVideoDuration Write SetMaxVideoDuration;
  End;

Implementation

{$R *.lfm}

{ TFrameApplicationSettings }

Procedure TFrameApplicationSettings.FormCreate(Sender: TObject);
Begin
  edtAnomalyImageFolder.Text := '';
  edtVideoFolder.Text := '';
  edtROV.Text := '';
  edtVessel.Text := '';
End;

Function TFrameApplicationSettings.GetAnomalyImageFolder: String;
Begin
  Result := edtAnomalyImageFolder.Text;
End;

function TFrameApplicationSettings.GetEventImageFolder: String;
begin
  Result := edtEventImageFolder.Text;
end;

Function TFrameApplicationSettings.GetMaxVideoDuration: Integer;
Begin
  Result := edtMaxVideoDuration.Value;
End;

Function TFrameApplicationSettings.GetROV: String;
Begin
  Result := edtROV.Text;
End;

Function TFrameApplicationSettings.GetVessel: String;
Begin
  Result := edtVessel.Text;
End;

Function TFrameApplicationSettings.GetVideoFolder: String;
Begin
  Result := edtVideoFolder.Text;
End;

procedure TFrameApplicationSettings.SetAnomalyImageFolder(const AValue: String);
Begin
  edtAnomalyImageFolder.Text := AValue;
End;

procedure TFrameApplicationSettings.SetEventImageFolder(const AValue: String);
begin
  edtEventImageFolder.Text := AValue;
end;

Procedure TFrameApplicationSettings.SetMaxVideoDuration(Const AValue: Integer);
Begin
  edtMaxVideoDuration.Value := AValue;
End;

Procedure TFrameApplicationSettings.SetROV(Const AValue: String);
Begin
  edtROV.Text := AValue;
End;

Procedure TFrameApplicationSettings.SetVessel(Const AValue: String);
Begin
  edtVessel.Text := AValue;
End;

Procedure TFrameApplicationSettings.SetVideoFolder(Const AValue: String);
Begin
  edtVideoFolder.Text := AValue;
End;

End.
