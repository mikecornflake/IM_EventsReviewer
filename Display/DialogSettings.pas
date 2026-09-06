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
    edtMasterFilename: TFileNameEdit;
    Label1: TLabel;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
  Private
    Function GetImageFolder: String;
    Function GetMasterFilename: String;
    Procedure SetImageFolder(Const AValue: String);
    Procedure SetMasterFilename(Const AValue: String);

  Public
    Property ImageFolder: String Read GetImageFolder Write SetImageFolder;
    Property MasterFilename: String Read GetMasterFilename Write SetMasterFilename;
  End;

Implementation

{$R *.lfm}

{ TdlgSettings }

procedure TdlgSettings.FormCreate(Sender: TObject);
begin
  edtImageFolder.Text := '';
  edtMasterFilename.Text := '';
end;

Function TdlgSettings.GetImageFolder: String;
Begin
  Result := edtImageFolder.Text;
End;

Function TdlgSettings.GetMasterFilename: String;
Begin
  Result := edtMasterFilename.Text;
End;

Procedure TdlgSettings.SetImageFolder(Const AValue: String);
Begin
  edtImageFolder.Text := AValue;
End;

Procedure TdlgSettings.SetMasterFilename(Const AValue: String);
Begin
  edtMasterFilename.Text := AValue;
End;

End.
