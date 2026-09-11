Unit ApplicationSettings;

{$mode ObjFPC}{$H+}
{$interfaces corba}

Interface

Uses
  Classes, SysUtils, Controls, IniFiles;

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

    Property ImageFolder: String Read GetImageFolder;
    Property VideoFolder: String Read GetVideoFolder;
    Property AnomalySpreadsheet: String Read GetAnomalySpreadsheet;
    Property ChannelOrder: TStrings Read GetChannelOrder;
  End;

Implementation

Uses
  // Library
  FormMain,

  // Application
  DialogSettings;

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
begin
 Result := FImageFolder;
end;

Function TApplicationSettings.GetVideoFolder: String;
begin
  Result := FVideoFolder;
end;

Function TApplicationSettings.GetAnomalySpreadsheet: String;
begin
  Result := FAnomalySpreadsheet;
end;

Function TApplicationSettings.GetChannelOrder: TStrings;
begin
  Result := FChannelOrder;
end;

Function TApplicationSettings.OpenSettings: Boolean;
Var
  oDlg: TdlgSettings;
Begin
  Result := False;

  oDlg := TdlgSettings.Create(MainForm);
  Try
    // Define settings
    oDlg.AnomalySpreadsheet := FAnomalySpreadsheet;
    oDlg.ImageFolder := FImageFolder;
    oDlg.VideoFolder := FVideoFolder;
    oDlg.SetChannelOrder(FChannelOrder);

    If oDlg.ShowModal = mrOk Then
    Begin
      // Update settings
      FAnomalySpreadsheet := oDlg.AnomalySpreadsheet;
      FImageFolder := oDlg.ImageFolder;
      FVideoFolder := oDlg.VideoFolder;
      oDlg.GetChannelOrder(FChannelOrder);

      Result := True;
    End;
  Finally
    oDlg.Free;
  End;
End;

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
