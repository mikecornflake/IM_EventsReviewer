Unit DialogSettings;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, EditBtn;

Type

  { TdlgSettings }

  TdlgSettings = Class(TForm)
    Bevel1: TBevel;
    Bevel2: TBevel;
    btnCancel: TButton;
    btnOK: TButton;
    edtImageFolder: TDirectoryEdit;
    edtAnomalySpreadsheet: TFileNameEdit;
    edtVideoFolder: TDirectoryEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    memChannelOrder: TMemo;
    Procedure FormCreate(Sender: TObject);
  Private
    Function GetImageFolder: String;
    Function GetAnomalySpreadsheet: String;
    Function GetVideoFolder: String;
    Procedure SetImageFolder(Const AValue: String);
    Procedure SetAnomalySpreadsheet(Const AValue: String);
    Procedure SetVideoFolder(Const AValue: String);

  Public
    Procedure GetChannelOrder(Const AChannelOrder: TStringList);
    Procedure SetChannelOrder(Const AChannelOrder: TStringList);

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

Procedure TdlgSettings.GetChannelOrder(Const AChannelOrder: TStringList);
Var
  i: Integer;
Begin
  For i := memChannelOrder.Lines.Count - 1 Downto 0 Do
    If Trim(memChannelOrder.Lines[i]) = '' Then
      memChannelOrder.Lines.Delete(i);

  // In case user deleted all contents
  If memChannelOrder.Lines.Count = 0 Then
    memChannelOrder.Lines.Add('*');

  AChannelOrder.Assign(memChannelOrder.Lines);
End;

Procedure TdlgSettings.SetChannelOrder(Const AChannelOrder: TStringList);
Begin
  memChannelOrder.Lines.Assign(AChannelOrder);

  // In case someone has hand-hacked the inifile
  If memChannelOrder.Lines.Count = 0 Then
    memChannelOrder.Lines.Add('*');
End;

End.
