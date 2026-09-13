Unit ApplicationSettings;

{$mode ObjFPC}{$H+}
{$interfaces corba}

Interface

Uses
  Classes, SysUtils, Controls, IniFiles,
  // Application
  FrameApplicationSettings;

Type

  IApplicationSettings = Interface
    Function GetImageFolder: String;
    Function GetVideoFolder: String;
    Function GetAnomalySpreadsheet: String;
    Function GetChannelOrder: TStrings;

    Property ImageFolder: String Read GetImageFolder;
    Property VideoFolder: String Read GetVideoFolder;
    Property AnomalySpreadsheet: String Read GetAnomalySpreadsheet;
    Property ChannelOrder: TStrings Read GetChannelOrder;
  End;

  { TApplicationSettings }

  TApplicationSettings = Class(TObject, IApplicationSettings)
  Private
    // Settings
    FChannelOrder: TStringList;
    FAnomalySpreadsheet: String;
    FImageFolder: String;
    FVideoFolder: String;

    Function GetImageFolder: String;
    Function GetVideoFolder: String;
    Function GetAnomalySpreadsheet: String;
    Function GetChannelOrder: TStrings;
  Public
    Constructor Create; Virtual;
    Destructor Destroy; Override;

    Function OpenSettings: Boolean;

    Procedure LoadSettings(oInifile: TIniFile);
    Procedure SaveSettings(oInifile: TIniFile);

    Procedure ApplySettingsFrame(AFrame: TfmeApplicationSettings);
    Procedure PopulateSettingsFrame(AFrame: TfmeApplicationSettings);

    Property ImageFolder: String Read GetImageFolder;
    Property VideoFolder: String Read GetVideoFolder;
    Property AnomalySpreadsheet: String Read GetAnomalySpreadsheet;
    Property ChannelOrder: TStrings Read GetChannelOrder;
  End;

Implementation

Uses
  Forms,

  // Library
  FormMain, DialogFrameHost;

  { TApplicationSettings }

Constructor TApplicationSettings.Create;
Begin
  // Order the videos are loaded
  FChannelOrder := TStringList.Create;
  FChannelOrder.Delimiter := ',';
End;

Destructor TApplicationSettings.Destroy;
Begin
  FreeAndNil(FChannelOrder);

  Inherited Destroy;
End;

Function TApplicationSettings.GetImageFolder: String;
Begin
  Result := FImageFolder;
End;

Function TApplicationSettings.GetVideoFolder: String;
Begin
  Result := FVideoFolder;
End;

Function TApplicationSettings.GetAnomalySpreadsheet: String;
Begin
  Result := FAnomalySpreadsheet;
End;

Function TApplicationSettings.GetChannelOrder: TStrings;
Begin
  Result := FChannelOrder;
End;

Function TApplicationSettings.OpenSettings: Boolean;
Var
  oDlg: TDialogFrameHost;
  oFrame: TfmeApplicationSettings;
Begin
  Result := False;

  oDlg := TDialogFrameHost.Create(MainForm);
  oFrame := TfmeApplicationSettings.Create(oDlg);
  Try
    oDlg.Caption := Application.Title;
    oDlg.RegisterFrame(oFrame, 'Application');

    // Define settings
    PopulateSettingsFrame(oFrame);

    If oDlg.ShowModal = mrOk Then
    Begin
      // Update settings
      ApplySettingsFrame(oFrame);

      Result := True;
    End;
  Finally
    oFrame.Free;
    oDlg.Free;
  End;
End;

Procedure TApplicationSettings.ApplySettingsFrame(AFrame: TfmeApplicationSettings);
Begin
  FAnomalySpreadsheet := AFrame.AnomalySpreadsheet;
  FImageFolder := AFrame.ImageFolder;
  FVideoFolder := AFrame.VideoFolder;
  AFrame.GetChannelOrder(FChannelOrder);
End;

Procedure TApplicationSettings.PopulateSettingsFrame(AFrame: TfmeApplicationSettings);
Begin
  AFrame.AnomalySpreadsheet := FAnomalySpreadsheet;
  AFrame.ImageFolder := FImageFolder;
  AFrame.VideoFolder := FVideoFolder;
  AFrame.SetChannelOrder(FChannelOrder);
  AFrame.ROV := ''; // TODO
  AFrame.Vessel := ''; // TODO
end;

Procedure TApplicationSettings.LoadSettings(oInifile: TIniFile);
Begin
  // User Settings
  FAnomalySpreadsheet := oInifile.ReadString('Settings', 'AnomalySpreadsheet', '');
  FImageFolder := oInifile.ReadString('Settings', 'ImageFolder', '');
  FVideoFolder := oInifile.ReadString('Settings', 'VideoFolder', '');
  FChannelOrder.DelimitedText := oInifile.ReadString('Settings', 'ChannelOrder',
    'Centre,Aux,Port,Stbd');
End;

Procedure TApplicationSettings.SaveSettings(oInifile: TIniFile);
Begin
  // User Settings
  oInifile.WriteString('Settings', 'AnomalySpreadsheet', FAnomalySpreadsheet);
  oInifile.WriteString('Settings', 'ImageFolder', FImageFolder);
  oInifile.WriteString('Settings', 'VideoFolder', FVideoFolder);
  oInifile.WriteString('Settings', 'ChannelOrder', FChannelOrder.DelimitedText);
End;

End.
