Unit DialogSettings;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, EditBtn;

Type

  { TdlgSettings }

  TdlgSettings = Class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    edtImageFolder: TDirectoryEdit;
    edtAnomalySpreadsheet: TFileNameEdit;
    edtVideoFolder: TDirectoryEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Procedure FormCreate(Sender: TObject);
  Private
    Function GetImageFolder: String;
    Function GetAnomalySpreadsheet: String;
    Function GetVideoFolder: String;
    Procedure SetImageFolder(Const AValue: String);
    Procedure SetAnomalySpreadsheet(Const AValue: String);
    Procedure SetVideoFolder(Const AValue: String);

  Public
    Property ImageFolder: String Read GetImageFolder Write SetImageFolder;
    Property VideoFolder: String Read GetVideoFolder Write SetVideoFolder;
    Property AnomalySpreadsheet: String Read GetAnomalySpreadsheet Write SetAnomalySpreadsheet;
  End;

Implementation

{$R *.lfm}

{ TdlgSettings }

Procedure TdlgSettings.FormCreate(Sender: TObject);
Begin
  edtImageFolder.Text := '';
  edtVideoFolder.Text := '';
  edtAnomalySpreadsheet.Text := '';
End;

Function TdlgSettings.GetImageFolder: String;
Begin
  Result := edtImageFolder.Text;
End;

Function TdlgSettings.GetAnomalySpreadsheet: String;
Begin
  Result := edtAnomalySpreadsheet.Text;
End;

Function TdlgSettings.GetVideoFolder: String;
Begin
  Result := edtVideoFolder.Text;
End;

Procedure TdlgSettings.SetImageFolder(Const AValue: String);
Begin
  edtImageFolder.Text := AValue;
End;

Procedure TdlgSettings.SetAnomalySpreadsheet(Const AValue: String);
Begin
  edtAnomalySpreadsheet.Text := AValue;
End;

Procedure TdlgSettings.SetVideoFolder(Const AValue: String);
Begin
  edtVideoFolder.Text := AValue;
End;

End.
