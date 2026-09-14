Unit FrameApplicationSettings;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, EditBtn,
  FrameBase;

Type

  { TFrameApplicationSettings }

  TFrameApplicationSettings = Class(TFrameBase)
    Bevel2: TBevel;
    edtVessel: TEdit;
    edtImageFolder: TDirectoryEdit;
    edtROV: TEdit;
    edtVideoFolder: TDirectoryEdit;
    Label1: TLabel;
    Label3: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Procedure FormCreate(Sender: TObject);
  Private
    Function GetImageFolder: String;
    Function GetROV: String;
    Function GetVessel: String;
    Function GetVideoFolder: String;
    Procedure SetImageFolder(Const AValue: String);
    Procedure SetROV(Const AValue: String);
    Procedure SetVessel(Const AValue: String);
    Procedure SetVideoFolder(Const AValue: String);
  Public
    Property ImageFolder: String Read GetImageFolder Write SetImageFolder;
    Property VideoFolder: String Read GetVideoFolder Write SetVideoFolder;
    Property Vessel: String Read GetVessel Write SetVessel;
    Property ROV: String Read GetROV Write SetROV;
  End;

Implementation

{$R *.lfm}

{ TFrameApplicationSettings }

Procedure TFrameApplicationSettings.FormCreate(Sender: TObject);
Begin
  edtImageFolder.Text := '';
  edtVideoFolder.Text := '';
  edtROV.Text := '';
  edtVessel.Text := '';
End;

Function TFrameApplicationSettings.GetImageFolder: String;
Begin
  Result := edtImageFolder.Text;
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

Procedure TFrameApplicationSettings.SetImageFolder(Const AValue: String);
Begin
  edtImageFolder.Text := AValue;
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
