Unit FrameApplicationSettings;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, EditBtn,
  FrameBase;

Type

  { TfmeApplicationSettings }

  TfmeApplicationSettings = Class(TFrameBase)
    Bevel1: TBevel;
    Bevel2: TBevel;
    Bevel3: TBevel;
    edtVessel: TEdit;
    edtAnomalySpreadsheet: TFileNameEdit;
    edtImageFolder: TDirectoryEdit;
    edtROV: TEdit;
    edtVideoFolder: TDirectoryEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    memChannelOrder: TMemo;
    Procedure FormCreate(Sender: TObject);
  Private
    Function GetImageFolder: String;
    Function GetAnomalySpreadsheet: String;
    function GetROV: String;
    function GetVessel: String;
    Function GetVideoFolder: String;
    Procedure SetImageFolder(Const AValue: String);
    Procedure SetAnomalySpreadsheet(Const AValue: String);
    procedure SetROV(const AValue: String);
    procedure SetVessel(const AValue: String);
    Procedure SetVideoFolder(Const AValue: String);

  Public
    Procedure GetChannelOrder(Const AChannelOrder: TStringList);
    Procedure SetChannelOrder(Const AChannelOrder: TStringList);

    Property ImageFolder: String Read GetImageFolder Write SetImageFolder;
    Property VideoFolder: String Read GetVideoFolder Write SetVideoFolder;
    Property AnomalySpreadsheet: String Read GetAnomalySpreadsheet Write SetAnomalySpreadsheet;

    Property Vessel: String Read GetVessel Write SetVessel;
    Property ROV: String Read GetROV Write SetROV;
  End;

Implementation

{$R *.lfm}

{ TfmeApplicationSettings }

Procedure TfmeApplicationSettings.FormCreate(Sender: TObject);
Begin
  edtImageFolder.Text := '';
  edtVideoFolder.Text := '';
  edtAnomalySpreadsheet.Text := '';
End;

Function TfmeApplicationSettings.GetImageFolder: String;
Begin
  Result := edtImageFolder.Text;
End;

Function TfmeApplicationSettings.GetAnomalySpreadsheet: String;
Begin
  Result := edtAnomalySpreadsheet.Text;
End;

function TfmeApplicationSettings.GetROV: String;
begin
  Result := edtROV.Text;
end;

function TfmeApplicationSettings.GetVessel: String;
begin
  Result := edtVessel.Text;
end;

Function TfmeApplicationSettings.GetVideoFolder: String;
Begin
  Result := edtVideoFolder.Text;
End;

Procedure TfmeApplicationSettings.SetImageFolder(Const AValue: String);
Begin
  edtImageFolder.Text := AValue;
End;

Procedure TfmeApplicationSettings.SetAnomalySpreadsheet(Const AValue: String);
Begin
  edtAnomalySpreadsheet.Text := AValue;
End;

procedure TfmeApplicationSettings.SetROV(const AValue: String);
begin
  edtROV.Text := AValue;
end;

procedure TfmeApplicationSettings.SetVessel(const AValue: String);
begin
  edtVessel.Text := AValue;
end;

Procedure TfmeApplicationSettings.SetVideoFolder(Const AValue: String);
Begin
  edtVideoFolder.Text := AValue;
End;

Procedure TfmeApplicationSettings.GetChannelOrder(Const AChannelOrder: TStringList);
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

Procedure TfmeApplicationSettings.SetChannelOrder(Const AChannelOrder: TStringList);
Begin
  memChannelOrder.Lines.Assign(AChannelOrder);

  // In case someone has hand-hacked the inifile
  If memChannelOrder.Lines.Count = 0 Then
    memChannelOrder.Lines.Add('*');
End;

End.
