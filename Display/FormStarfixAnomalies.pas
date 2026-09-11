Unit FormStarfixAnomalies;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus, ExtCtrls, StdCtrls,
  DBCtrls, IniFiles, FormMain, FrameImageViewer, FrameGrids, FrameVideoPlayer, FrameSyncedVideo,
  ModuleStarfix, DB;

Type

  { TfrmStarfixAnomalies }

  TfrmStarfixAnomalies = Class(TFormMain)
    dsAnomaly: TDataSource;
    edtLength: TDBEdit;
    edtWidth: TDBEdit;
    edtHeight: TDBEdit;
    edtOffset: TDBEdit;
    edtClock: TDBEdit;
    edtDescription: TDBMemo;
    grpDetails: TGroupBox;
    lblLength: TLabel;
    lblWidth: TLabel;
    lblHeight: TLabel;
    lblOffset: TLabel;
    Label5: TLabel;
    lblClock: TLabel;
    lblDescription: TLabel;
    mnuExit: TMenuItem;
    pnlVideo: TPanel;
    pnlImages: TPanel;
    pnlRight: TPanel;
    pnlAnomalies: TPanel;
    Separator2: TMenuItem;
    mnuDatabaseOpen: TMenuItem;
    mnuDatabase: TMenuItem;
    Separator1: TMenuItem;
    mnuSettings: TMenuItem;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    ToolBar1: TToolBar;
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure FormShow(Sender: TObject);
    Procedure mnuDatabaseOpenClick(Sender: TObject);
    Procedure mnuExitClick(Sender: TObject);
    Procedure mnuSettingsClick(Sender: TObject);
  Private
    // Starfix Data Module
    FStarfix: TdmStarfix;

    // Settings
    FVideoFolder: String;
    FImageFolder: String;
    FAnomalySpreadsheet: String;

    //UI
    FActivated: Boolean;

    fmeImageViewer: TFrameImageViewer;
    fmeAnomalies: TFrameGrid;

    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;
  Protected
    Procedure RefreshUI; Override;

    // Stored in ini file with exe - what folders to load etc
    Procedure LoadGlobalSettings(oInifile: TIniFile); Override;
    Procedure SaveGlobalSettings(oInifile: TIniFile); Override;
  Public

  End;

Var
  frmStarfixAnomalies: TfrmStarfixAnomalies;

Implementation

Uses
  DialogSettings, ThirdPartySupport, FrameVideoLibmpv;

  {$R *.lfm}

  { TfrmStarfixAnomalies }

Procedure TfrmStarfixAnomalies.FormCreate(Sender: TObject);
Begin
  // This isn't going to be app that only an Admin can change settings...
  FAlwaysSaveSettings := True;

  // UI
  fmeImageViewer := TFrameImageViewer.Create(Self);
  fmeImageViewer.Parent := pnlImages;
  fmeImageViewer.Align := alClient;

  fmeAnomalies := TFrameGrid.Create(Self);
  fmeAnomalies.Parent := pnlAnomalies;
  fmeAnomalies.Align := alClient;

  fmeVideoPlayer := TFrameVideoPlayer.Create(Self);
  fmeVideoPlayer.Parent := pnlVideo;
  fmeVideoPlayer.Name := 'fmeVideoPlayer';
  fmeVideoPlayer.Align := alClient;
  fmeVideoPlayer.Autoplay := True;
  fmeVideoPlayer.ShowLabel := True;

  // Change this line to switch playback engines
  fmeVideoPlayer.VideoEngineClass := TFrameSyncedVideo;

  fmeSyncedVideo := TFrameSyncedVideo(fmeVideoPlayer.PlaybackFrame);
  fmeSyncedVideo.VideoEngineClass := TFrameVideoLibmpv;

  If Not Assigned(fmeSyncedVideo) Then
    Raise Exception.Create('Playback Frame not registered');

  // Database
  FStarfix := TdmStarfix.Create(Self);
  FStarfix.RegisterAnomalyControls(fmeAnomalies, fmeImageViewer, dsAnomaly);
  FStarfix.RegisterVideoControls(fmeVideoPlayer, fmeSyncedVideo);

  FActivated := False;
End;

Procedure TfrmStarfixAnomalies.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(fmeImageViewer);
  FreeAndNil(fmeAnomalies);

  FreeAndNil(FStarfix);
End;

Procedure TfrmStarfixAnomalies.FormShow(Sender: TObject);
Begin
  If Not FActivated Then
  Begin
    // Test
    fmeImageViewer.AddImage(
      'B:\Code\Compile\Test Data\MEDIA\IMAGES\HD Images\507464_SAIPEM_15_0525_20260728202906_Centre.jpg',
      'First Image');
    fmeImageViewer.AddImage(
      'B:\Code\Compile\Test Data\MEDIA\IMAGES\HD Images\507464_SAIPEM_15_0525_20260728202944_Centre.jpg',
      'Second Image');
    fmeImageViewer.AddImage(
      'B:\Code\Compile\Test Data\MEDIA\IMAGES\HD Images\507464_SAIPEM_15_0534_20260728193144_Centre.jpg',
      'Third and absolutely final Image');

    FActivated := True;
  End;
End;

Procedure TfrmStarfixAnomalies.LoadGlobalSettings(oInifile: TIniFile);
Begin
  Inherited LoadGlobalSettings(oInifile);

  FStarfix.LoadSettings(oInifile);

  // Settings
  FAnomalySpreadsheet := oInifile.ReadString('Settings', 'AnomalySpreadsheet', '');
  FImageFolder := oInifile.ReadString('Settings', 'ImageFolder', '');
  FVideoFolder := oInifile.ReadString('Settings', 'VideoFolder', '');

  // Propogate Changes
  FStarfix.ImageFolder := FImageFolder;
  FStarfix.VideoFolder := FVideoFolder;
End;

Procedure TfrmStarfixAnomalies.SaveGlobalSettings(oInifile: TIniFile);
Begin
  FStarfix.SaveSettings(oInifile);

  // Settings
  oInifile.WriteString('Settings', 'AnomalySpreadsheet', FAnomalySpreadsheet);
  oInifile.WriteString('Settings', 'ImageFolder', FImageFolder);
  oInifile.WriteString('Settings', 'VideoFolder', FVideoFolder);

  Inherited SaveGlobalSettings(oInifile);
End;

Procedure TfrmStarfixAnomalies.mnuSettingsClick(Sender: TObject);
Var
  oDlg: TdlgSettings;
Begin
  oDlg := TdlgSettings.Create(Self);
  Try

    // Define settings
    oDlg.AnomalySpreadsheet := FAnomalySpreadsheet;
    oDlg.ImageFolder := FImageFolder;
    oDlg.VideoFolder := FVideoFolder;

    If oDlg.ShowModal = mrOk Then
    Begin
      // Update settings
      FAnomalySpreadsheet := oDlg.AnomalySpreadsheet;
      FImageFolder := oDlg.ImageFolder;
      FVideoFolder := oDlg.VideoFolder;

      // Propogate changes
      FStarfix.ImageFolder := FImageFolder;
      FStarfix.VideoFolder := FVideoFolder;
    End;
  Finally
    oDlg.Free;
  End;
End;

Procedure TfrmStarfixAnomalies.RefreshUI;
Begin
  Inherited RefreshUI;

  mnuDatabaseOpen.Enabled := FStarfix.DriverAvailable;
End;

Procedure TfrmStarfixAnomalies.mnuDatabaseOpenClick(Sender: TObject);
Begin
  If FStarfix.OpenDatabase Then
  Begin
    RefreshUI;
  End;
End;

Procedure TfrmStarfixAnomalies.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

End.
