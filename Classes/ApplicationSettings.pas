Unit ApplicationSettings;

{$mode ObjFPC}{$H+}
{$interfaces corba}

Interface

Uses
  Classes, SysUtils, Controls, IniFiles,
  // Application
  FrameApplicationSettings;

Type

  { TApplicationSettings }

  TApplicationSettings = Class(TObject)
  Private
    // Settings
    FAnomalyImageFolder: String;
    FEventImageFolder: String;
    FVideoFolder: String;
    FVessel: String;
    FROV: String;
    FMaxVideoDuration: Integer;

    Function GetAnomalyImageFolder: String;
    Function GetEventImageFolder: String;
    Function GetMaxVideoDuration: Integer;
    Function GetROV: String;
    Function GetVessel: String;
    Function GetVideoFolder: String;
  Public
    Procedure LoadSettings(oInifile: TIniFile);
    Procedure SaveSettings(oInifile: TIniFile);

    Procedure ApplySettingsFrame(AFrame: TFrameApplicationSettings);
    Procedure PopulateSettingsFrame(AFrame: TFrameApplicationSettings);

    Property Vessel: String Read GetVessel;
    Property ROV: String Read GetROV;
    Property AnomalyImageFolder: String Read GetAnomalyImageFolder;
    Property EventImageFolder: String Read GetEventImageFolder;
    Property VideoFolder: String Read GetVideoFolder;
    Property MaxVideoDuration: Integer Read GetMaxVideoDuration;
  End;

Implementation

Uses
  Forms, Math;

  { TApplicationSettings }

Function TApplicationSettings.GetAnomalyImageFolder: String;
Begin
  Result := FAnomalyImageFolder;
End;

Function TApplicationSettings.GetEventImageFolder: String;
Begin
  Result := FEventImageFolder;
End;

Function TApplicationSettings.GetMaxVideoDuration: Integer;
Begin
  Result := FMaxVideoDuration;
End;

Function TApplicationSettings.GetROV: String;
Begin
  Result := FROV;
End;

Function TApplicationSettings.GetVessel: String;
Begin
  Result := FVessel;
End;

Function TApplicationSettings.GetVideoFolder: String;
Begin
  Result := FVideoFolder;
End;

Procedure TApplicationSettings.ApplySettingsFrame(AFrame: TFrameApplicationSettings);
Begin
  FVessel := AFrame.Vessel;
  FROV := AFrame.ROV;
  FAnomalyImageFolder := AFrame.AnomalyImageFolder;
  FEventImageFolder := AFrame.EventImageFolder;
  FVideoFolder := AFrame.VideoFolder;
  FMaxVideoDuration := AFrame.MaxVideoDuration;
End;

Procedure TApplicationSettings.PopulateSettingsFrame(AFrame: TFrameApplicationSettings);
Begin
  AFrame.AnomalyImageFolder := FAnomalyImageFolder;
  AFrame.EventImageFolder := FEventImageFolder;
  AFrame.VideoFolder := FVideoFolder;
  AFrame.Vessel := FVessel;
  AFrame.ROV := FROV;
  AFrame.MaxVideoDuration := FMaxVideoDuration;
End;

Procedure TApplicationSettings.LoadSettings(oInifile: TIniFile);
Begin
  // User Settings
  FAnomalyImageFolder := oInifile.ReadString('Settings', 'AnomalyImageFolder', '');
  FEventImageFolder := oInifile.ReadString('Settings', 'EventImageFolder', '');
  FVideoFolder := oInifile.ReadString('Settings', 'VideoFolder', '');
  FVessel := oInifile.ReadString('Settings', 'Vessel', '');
  FROV := oInifile.ReadString('Settings', 'ROV', '');
  // Do not allow a maximum length of less than 5 minutes
  FMaxVideoDuration := Max(5, oInifile.ReadInteger('Settings', 'MaxVideoDuration', 15));
End;

Procedure TApplicationSettings.SaveSettings(oInifile: TIniFile);
Begin
  // User Settings
  oInifile.WriteString('Settings', 'AnomalyImageFolder', FAnomalyImageFolder);
  oInifile.WriteString('Settings', 'EventImageFolder', FEventImageFolder);
  oInifile.WriteString('Settings', 'VideoFolder', FVideoFolder);
  oInifile.WriteString('Settings', 'Vessel', FVessel);
  oInifile.WriteString('Settings', 'ROV', FROV);
  oInifile.WriteInteger('Settings', 'MaxVideoDuration', FMaxVideoDuration);
End;

End.
