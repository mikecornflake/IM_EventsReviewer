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
    FImageFolder: String;
    FVideoFolder: String;
    FVessel: String;
    FROV: String;
    FMaxVideoDuration: Integer;

    Function GetImageFolder: String;
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
    Property ImageFolder: String Read GetImageFolder;
    Property VideoFolder: String Read GetVideoFolder;
    Property MaxVideoDuration: Integer Read GetMaxVideoDuration;
  End;

Implementation

Uses
  Forms;

  { TApplicationSettings }

Function TApplicationSettings.GetImageFolder: String;
Begin
  Result := FImageFolder;
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
  FImageFolder := AFrame.ImageFolder;
  FVideoFolder := AFrame.VideoFolder;
  FMaxVideoDuration := AFrame.MaxVideoDuration;
End;

Procedure TApplicationSettings.PopulateSettingsFrame(AFrame: TFrameApplicationSettings);
Begin
  AFrame.ImageFolder := FImageFolder;
  AFrame.VideoFolder := FVideoFolder;
  AFrame.Vessel := FVessel;
  AFrame.ROV := FROV;
  AFrame.MaxVideoDuration := FMaxVideoDuration;
End;

Procedure TApplicationSettings.LoadSettings(oInifile: TIniFile);
Begin
  // User Settings
  FImageFolder := oInifile.ReadString('Settings', 'ImageFolder', '');
  FVideoFolder := oInifile.ReadString('Settings', 'VideoFolder', '');
  FVessel := oInifile.ReadString('Settings', 'Vessel', '');
  FROV := oInifile.ReadString('Settings', 'ROV', '');
  FMaxVideoDuration := oInifile.ReadInteger('Settings', 'MaxVideoDuration', 15);
End;

Procedure TApplicationSettings.SaveSettings(oInifile: TIniFile);
Begin
  // User Settings
  oInifile.WriteString('Settings', 'ImageFolder', FImageFolder);
  oInifile.WriteString('Settings', 'VideoFolder', FVideoFolder);
  oInifile.WriteString('Settings', 'Vessel', FVessel);
  oInifile.WriteString('Settings', 'ROV', FROV);
  oInifile.WriteInteger('Settings', 'MaxVideoDuration', FMaxVideoDuration);
End;

End.
