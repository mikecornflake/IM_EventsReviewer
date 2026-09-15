Unit FormStarfixAnomalies;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus, ExtCtrls, StdCtrls,
  DBCtrls, ActnList, IniFiles, DB,
  // Library
  FormMain, FrameImageViewer, FrameGrids, FrameVideoPlayer, FrameSyncedVideo,
  // Application
  ApplicationSettings, StarfixDatabaseProvider, MediaProvider, FrameVerticalDBGrid;

Type

  { TfrmStarfixAnomalies }

  TfrmStarfixAnomalies = Class(TFormMain)
    actSeekVideo: TAction;
    actSettings: TAction;
    actOpenDatabase: TAction;
    actMain: TActionList;
    DBEdit1: TDBEdit;
    DBEdit2: TDBEdit;
    DBEdit3: TDBEdit;
    DBEdit4: TDBEdit;
    dsAnomalyDetails: TDataSource;
    edtClock: TDBEdit;
    edtDescription: TDBMemo;
    edtHeight: TDBEdit;
    edtHeight1: TDBEdit;
    edtLength: TDBEdit;
    edtLength1: TDBEdit;
    edtOffset: TDBEdit;
    edtWidth: TDBEdit;
    edtWidth1: TDBEdit;
    grpDetails: TGroupBox;
    lblClock: TLabel;
    lblDescription: TLabel;
    lblDescription1: TLabel;
    lblDescription2: TLabel;
    lblDescription3: TLabel;
    lblDescription4: TLabel;
    lblHeight: TLabel;
    lblHeight1: TLabel;
    lblLength: TLabel;
    lblLength1: TLabel;
    lblOffset: TLabel;
    lblWidth: TLabel;
    lblWidth1: TLabel;
    mnuDatabase: TMenuItem;
    mnuDatabaseOpen: TMenuItem;
    mnuEdit: TMenuItem;
    mnuExit: TMenuItem;
    mnuSeektoVideo: TMenuItem;
    mnuSettings: TMenuItem;
    pnlDetailsGrid: TPanel;
    pnlImages: TPanel;
    pnlHidingSummary: TPanel;
    pnlAnomalies: TPanel;
    pnlRight: TPanel;
    pnlVideo: TPanel;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    splAnomalies: TSplitter;
    splImages: TSplitter;
    splDetailsGrid: TSplitter;
    tmrHideSummary: TTimer;
    tmrSeekAfterLoadVideo: TTimer;
    tbMain: TToolBar;
    btnOpenDatabase: TToolButton;
    btnSettings: TToolButton;
    btnSyncVideo: TToolButton;
    ToolButton3: TToolButton;
    Procedure actSeekVideoExecute(Sender: TObject);
    procedure DBEditClick(Sender: TObject);
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure FormShow(Sender: TObject);
    Procedure actDatabaseOpenClick(Sender: TObject);
    Procedure mnuExitClick(Sender: TObject);
    Procedure actSettingsClick(Sender: TObject);
    Procedure tmrHideSummaryTimer(Sender: TObject);
    Procedure tmrSeekAfterLoadVideoTimer(Sender: TObject);
  Private
    // Settings
    FSettings: TApplicationSettings;

    // Providers
    FDataProvider: TStarfixDatabaseProvider;
    FMediaProvider: TMediaProvider;

    //UI
    FActivated: Boolean;

    fmeImageViewer: TFrameImageViewer;
    fmeAnomalies: TFrameGrid;
    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;
    fmeDetailGrid: TFrameVerticalDBGrid;

    // Tracking video playback status
    FPendingVideoTime: TDateTime;
    FSeekPending: Boolean;
    Procedure DoVideoLoaded(Sender: TObject);
  Protected
    Procedure RefreshUI; Override;

    // Stored in ini file with exe - what folders to load etc
    Procedure LoadGlobalSettings(oInifile: TIniFile); Override;
    Procedure SaveGlobalSettings(oInifile: TIniFile); Override;

    // Stored in %localappdata% - Recommended for persisting user UI preferences
    Procedure LoadLocalSettings(oInifile: TIniFile); Override;
    Procedure SaveLocalSettings(oInifile: TIniFile); Override;

    // Callback events
    Procedure DoProviderReady(Sender: TObject);
    Procedure DoAnomalyChanged(Sender: TObject; Const ANewAnomalyNo: String;
      Const ADateTime: TDateTime);
  Public

  End;

Var
  frmStarfixAnomalies: TfrmStarfixAnomalies;

Implementation

Uses
  ThirdPartySupport, FrameVideoLibmpv, StringSupport, FileUtil, MSSQLSupport, MediaTypes,
  Windows, DBGrids, VideoEngineFactory,
  FrameApplicationSettings, FrameSettingsSyncedVideo, DialogFrameHost;

  {$R *.lfm}

  { TfrmStarfixAnomalies }

Procedure TfrmStarfixAnomalies.FormCreate(Sender: TObject);
Begin
  // This isn't going to be app that only an Admin can change settings...
  FAlwaysSaveSettings := True;

  // Settings Manager
  FSettings := TApplicationSettings.Create;

  // UI
  fmeImageViewer := TFrameImageViewer.Create(Self);
  fmeImageViewer.Parent := pnlImages;
  fmeImageViewer.Name := 'fmeImageViewer';
  fmeImageViewer.Align := alClient;

  fmeAnomalies := TFrameGrid.Create(Self);
  fmeAnomalies.Parent := pnlAnomalies;
  fmeAnomalies.Name := 'fmeAnomalies';
  fmeAnomalies.Align := alClient;

  fmeVideoPlayer := TFrameVideoPlayer.Create(Self);
  fmeVideoPlayer.Parent := pnlVideo;
  fmeVideoPlayer.Name := 'fmeVideoPlayer';
  fmeVideoPlayer.Align := alClient;
  fmeVideoPlayer.Autoplay := True;
  fmeVideoPlayer.ShowLabel := True;

  fmeDetailGrid := TFrameVerticalDBGrid.Create(Self);
  fmeDetailGrid.Parent := pnlDetailsGrid;
  fmeDetailGrid.Name := 'fmeDetailGrid';
  fmeDetailGrid.Align := alClient;

  // Ensure the Video Player support multi channel playback
  fmeVideoPlayer.VideoEngineClass := TFrameSyncedVideo;

  // Currently multi channel functionality is only exposed through the Video Engine,
  // not the Video Player UI frame, so grab a reference of the instance
  fmeSyncedVideo := TFrameSyncedVideo(fmeVideoPlayer.PlaybackFrame);

  // Change this line to switch playback engines (mpv, vlc, mlplayer
  fmeSyncedVideo.VideoEngineClass := TVideoEngineFactory.DefaultClass;
  fmeVideoPlayer.Autoplay := False;
  fmeSyncedVideo.OnVideoLoaded := @DoVideoLoaded;

  // Now the UI is created, let's create the providers and bind/register

  // Data Provider
  FDataProvider := TStarfixDatabaseProvider.Create;
  FDataProvider.OnProviderReady := @DoProviderReady;
  FDataProvider.OnAnomalyChanged := @DoAnomalyChanged;

  dsAnomalyDetails.Dataset := FDataProvider.AnomalyDataSet;
  fmeAnomalies.Dataset := FDataProvider.AnomalyDataSet;
  fmeDetailGrid.Dataset := FDataProvider.AnomalyDataSet;

  // Media Provider
  FMediaProvider := TMediaProvider.Create;

  FActivated := False;
End;

Procedure TfrmStarfixAnomalies.FormDestroy(Sender: TObject);
Begin
  // Fully aware these woudl be cleared up by their owner anyway
  // My philosophy is: I create, I clean up...
  FreeAndNil(fmeImageViewer);
  FreeAndNil(fmeAnomalies);
  FreeAndNil(fmeVideoPlayer);
  FreeAndNil(fmeDetailGrid);

  // And these definitely need freeing :-)
  FreeAndNil(FSettings);
  FreeAndNil(FDataProvider);
  FreeAndNil(FMediaProvider);
End;

Procedure TfrmStarfixAnomalies.FormShow(Sender: TObject);

  Procedure RoundControl(AControl: TWinControl; ARadius: Integer);
  Var
    Rgn: HRGN;
  Begin
    Rgn := CreateRoundRectRgn(0, 0, AControl.Width + 1, AControl.Height + 1,
      ARadius, ARadius);

    SetWindowRgn(AControl.Handle, Rgn, True);
  End;

Begin
  If Not FActivated Then
  Begin
    RoundControl(pnlHidingSummary, 10);
    // Visible quickly at startup, but prevents a bad drawing issue on first show
    pnlHidingSummary.Visible := False;

    FActivated := True;
  End;
End;

Procedure TfrmStarfixAnomalies.LoadGlobalSettings(oInifile: TIniFile);
Begin
  Inherited LoadGlobalSettings(oInifile);

  // Application Settings
  FSettings.LoadSettings(oInifile);

  // Data Persistence Settings
  FDataProvider.LoadSettings(oInifile);
End;

Procedure TfrmStarfixAnomalies.SaveGlobalSettings(oInifile: TIniFile);
Begin
  // Application Settings
  FSettings.SaveSettings(oInifile);

  // Database Settings
  FDataProvider.SaveSettings(oInifile);

  Inherited SaveGlobalSettings(oInifile);
End;

Procedure TfrmStarfixAnomalies.LoadLocalSettings(oInifile: TIniFile);
Begin
  Inherited LoadLocalSettings(oInifile);

  // Allow the controls to persist their own settings (data filters, volume etc)
  fmeImageViewer.LoadSettings(oInifile);
  fmeAnomalies.LoadSettings(oInifile);
  fmeVideoPlayer.LoadSettings(oInifile);

  // persist TfrmStarfixAnomalies settings
  pnlDetailsGrid.Height := oInifile.ReadInteger('Form', 'pnlDetailsGrid.Height',
    pnlDetailsGrid.Height);
  pnlImages.Height := oInifile.ReadInteger('Form', 'pnlImages.Height', pnlImages.Height);
  pnlAnomalies.Width := oInifile.ReadInteger('Form', 'pnlAnomalies.Width', pnlAnomalies.Width);

  splDetailsGrid.Top := pnlDetailsGrid.Top - splDetailsGrid.Height;
  splImages.Top := pnlImages.Top - splImages.Height;
  splAnomalies.Left := pnlAnomalies.Left + splAnomalies.Width;
End;

Procedure TfrmStarfixAnomalies.SaveLocalSettings(oInifile: TIniFile);
Begin
  // Allow the controls to persist their settings
  fmeImageViewer.SaveSettings(oInifile);
  fmeAnomalies.SaveSettings(oInifile);
  fmeVideoPlayer.SaveSettings(oInifile);

  // persist TfrmStarfixAnomalies settings
  oInifile.WriteInteger('Form', 'pnlDetailsGrid.Height', pnlDetailsGrid.Height);
  oInifile.WriteInteger('Form', 'pnlImages.Height', pnlImages.Height);
  oInifile.WriteInteger('Form', 'pnlAnomalies.Width', pnlAnomalies.Width);

  // Form Position
  Inherited SaveLocalSettings(oInifile);
End;

Procedure TfrmStarfixAnomalies.RefreshUI;
Begin
  Inherited RefreshUI;

  mnuDatabaseOpen.Enabled := MSSQL.Available;
  actSeekVideo.Enabled := FDataProvider.Ready And Assigned(dsAnomalyDetails.Dataset) And
    (dsAnomalyDetails.Dataset.Active);
End;

Procedure TfrmStarfixAnomalies.tmrHideSummaryTimer(Sender: TObject);
Begin
  tmrHideSummary.Enabled := False;
  pnlHidingSummary.Visible := False;
End;

Procedure TfrmStarfixAnomalies.actSeekVideoExecute(Sender: TObject);
Begin
  If FDataProvider.Ready Then
    fmeSyncedVideo.PositionAsTime := FDataProvider.AnomalyDateTime;
End;

procedure TfrmStarfixAnomalies.DBEditClick(Sender: TObject);
begin
  TDBEdit(Sender).SelectAll;
end;

Procedure TfrmStarfixAnomalies.actSettingsClick(Sender: TObject);
Var
  oDlg: TDialogFrameHost;
  fmeSettingsApp: TFrameApplicationSettings;
  fmeSettingsVideo: TFrameSettingsSyncedVideo;
Begin
  oDlg := TDialogFrameHost.Create(Self);
  fmeSettingsApp := TFrameApplicationSettings.Create(oDlg);
  fmeSettingsVideo := TFrameSettingsSyncedVideo.Create(oDlg);
  Try
    oDlg.Caption := Application.Title;

    oDlg.RegisterFrame(fmeSettingsApp, 'Starfix');
    FSettings.PopulateSettingsFrame(fmeSettingsApp);

    oDlg.RegisterFrame(fmeSettingsVideo, 'Video');
    fmeSyncedVideo.PopulateSettingsFrame(fmeSettingsVideo);

    If oDlg.ShowModal = mrOk Then
    Begin
      FSettings.ApplySettingsFrame(fmeSettingsApp);
      fmeSyncedVideo.ApplySettingsFrame(fmeSettingsVideo);
    End;
  Finally
    fmeSettingsApp.Free;
    fmeSettingsVideo.Free;
    oDlg.Free;
  End;

  RefreshUI;
End;

Procedure TfrmStarfixAnomalies.actDatabaseOpenClick(Sender: TObject);
Var
  oDlg: TDialogFrameHost;
  fmeSettingsMSSQL: TFrameMSSQLConnection;
  fmeSettingsApp: TFrameApplicationSettings;
Begin
  oDlg := TDialogFrameHost.Create(Self);
  fmeSettingsMSSQL := TFrameMSSQLConnection.Create(oDlg);
  fmeSettingsApp := TFrameApplicationSettings.Create(oDlg);
  Try
    oDlg.Caption := Application.Title;

    // Additional filter to limit the databases available to be opened
    fmeSettingsMSSQL.DatabasePrefix:='SFX';

    oDlg.RegisterFrame(fmeSettingsMSSQL, 'Database Server');
    FDataProvider.PopulateSettingsFrame(fmeSettingsMSSQL);

    oDlg.RegisterFrame(fmeSettingsApp, 'Starfix');
    FSettings.PopulateSettingsFrame(fmeSettingsApp);

    If oDlg.ShowModal = mrOk Then
    Begin
      FDataProvider.ApplySettingsFrame(fmeSettingsMSSQL);
      FSettings.ApplySettingsFrame(fmeSettingsApp);

      If FDataProvider.Open Then
        RefreshUI;
    End;
  Finally
    fmeSettingsMSSQL.Free;
    fmeSettingsApp.Free;
    oDlg.Free;
  End;
  fmeAnomalies.SetFocus;
  RefreshUI;
End;

Procedure TfrmStarfixAnomalies.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

Procedure TfrmStarfixAnomalies.DoProviderReady(Sender: TObject);
Begin
  // We're now either connected to database, or have the offline data available
  If FDataProvider.Ready Then
  Begin
    FMediaProvider.ScanVideoFiles(FSettings.VideoFolder);

    // Resize columns etc
    fmeAnomalies.InitialiseDBGrid(True);

    Caption := Format('%s: [%s]', [Application.Title, FDataProvider.Title]);
    Status := '';
  End;

  RefreshUI;
End;

// Data has just loaded or User has scrolled to the next anomaly in the list
Procedure TfrmStarfixAnomalies.DoAnomalyChanged(Sender: TObject;
  Const ANewAnomalyNo: String; Const ADateTime: TDateTime);
Var
  slImages: TStringList;
  sImageFile, sFolder: String;
  oVideoFiles: TVideoFiles;
  oVideoFile: TVideoFile;

  Function Caption(ABaseFolder: String; AFilename: String): String;
  Begin
    Result := TextBetween(AFilename, IncludeTrailingBackslash(ABaseFolder), '');
  End;

Begin
  tmrHideSummary.Enabled := True;
  pnlHidingSummary.Visible := True;

  fmeImageViewer.ClearImages;

  If DirectoryExists(FSettings.ImageFolder) Then
  Begin
    // Load Anomaly Images
    fmeImageViewer.ClearImages;

    If Trim(ANewAnomalyNo) = '' Then
      Exit;

    slImages := TStringList.Create;
    Try
      FindAllFiles(slImages, FSettings.ImageFolder, ANewAnomalyNo + '*.*', True);

      For sImageFile In slImages Do
        fmeImageViewer.AddImage(sImageFile, Caption(FSettings.ImageFolder, sImageFile));
    Finally
      slImages.Free;
    End;

    // Do I need to load new Video?
    If (fmeSyncedVideo.StartDateTime <= ADateTime) And (ADateTime <=
      fmeSyncedVideo.EndDateTime) Then
    Begin
      fmeSyncedVideo.PositionAsTime := ADateTime;

      // TODO: Stop Seeking from restarting the video :-(
      fmeSyncedVideo.Pause;
    End
    Else
    Begin
      oVideoFiles := FDataProvider.GetVideoFilesForTime(ADateTime);
      Try
        If oVideoFiles.Count = 0 Then
        Begin
          fmeVideoPlayer.Clear;

          // TODO: Implement fmeSyncedVideo.clear
          //       Not done now as this will require testing all Video modules
          fmeSyncedVideo.ClearVideoCount;
          fmeSyncedVideo.ClearUnloadedVideoFrames;
        End
        Else
        Begin
          MainForm.Busy := True;
          MainForm.DisableAutoSizing;
          Try
            fmeSyncedVideo.BeginLoadVideos;
            Try
              For oVideoFile In oVideoFiles Do
              Begin
                sFolder := IncludeTrailingBackslash(
                  FMediaProvider.LookupFolder(oVideoFile.Filename));

                If FileExists(sFolder + oVideoFile.Filename) Then
                  fmeSyncedVideo.Load(sFolder + oVideoFile.Filename,
                    oVideoFile.Channel, oVideoFile.StartDateTime);
              End;
            Finally
              fmeSyncedVideo.EndLoadVideos;
              FSeekPending := True;
            End;

            If fmeSyncedVideo.VideoFileCount > 0 Then
            Begin
              // Pause the video (this is anomaly review, user will want to study the start)
              fmeSyncedVideo.Pause;

              // Seek
              fmeSyncedVideo.PositionAsTime := ADateTime;
              FPendingVideoTime := ADateTime;

              fmeVideoPlayer.RefreshUI;
            End;
          Finally
            MainForm.EnableAutoSizing;
            MainForm.Busy := False;
          End;
        End;
      Finally
        oVideoFiles.Free;
      End;
    End;
  End;

  RefreshUI;
End;

Procedure TfrmStarfixAnomalies.DoVideoLoaded(Sender: TObject);
Begin
  tmrSeekAfterLoadVideo.Enabled := True;
End;

Procedure TfrmStarfixAnomalies.tmrSeekAfterLoadVideoTimer(Sender: TObject);
Begin
  tmrSeekAfterLoadVideo.Enabled := False;

  If FSeekPending Then
  Begin
    FSeekPending := False;
    fmeSyncedVideo.PositionAsTime := FPendingVideoTime;
  End;
End;

End.
