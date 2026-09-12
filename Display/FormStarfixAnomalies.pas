Unit FormStarfixAnomalies;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus, ExtCtrls, StdCtrls,
  DBCtrls, IniFiles, DB,
  // Library
  FormMain, FrameImageViewer, FrameGrids, FrameVideoPlayer, FrameSyncedVideo,
  // Application
  ApplicationSettings, DatabaseProvider, MediaProvider;

Type

  { TfrmStarfixAnomalies }

  TfrmStarfixAnomalies = Class(TFormMain)
    DBEdit1: TDBEdit;
    DBEdit2: TDBEdit;
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
    Label5: TLabel;
    lblClock: TLabel;
    lblDescription: TLabel;
    lblDescription1: TLabel;
    lblDescription2: TLabel;
    lblHeight: TLabel;
    lblHeight1: TLabel;
    lblLength: TLabel;
    lblLength1: TLabel;
    lblOffset: TLabel;
    lblWidth: TLabel;
    lblWidth1: TLabel;
    mnuDatabase: TMenuItem;
    mnuDatabaseOpen: TMenuItem;
    mnuExit: TMenuItem;
    mnuSettings: TMenuItem;
    pnlImages: TPanel;
    pnlHidingSummary: TPanel;
    pnlAnomalies: TPanel;
    pnlRight: TPanel;
    pnlVideo: TPanel;
    Separator1: TMenuItem;
    Separator2: TMenuItem;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    tmrHideSummary: TTimer;
    ToolBar1: TToolBar;
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure FormShow(Sender: TObject);
    Procedure mnuDatabaseOpenClick(Sender: TObject);
    Procedure mnuExitClick(Sender: TObject);
    Procedure mnuSettingsClick(Sender: TObject);
    Procedure tmrHideSummaryTimer(Sender: TObject);
  Private
    // Settings
    FSettings: TApplicationSettings;

    // Providers
    FDataProvider: TDatabaseProvider;
    FMediaProvider: TMediaProvider;

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
  ThirdPartySupport, FrameVideoLibmpv, StringSupport, FileUtil, DialogMSSQLConnection, MediaTypes;

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

  // Ensure the Video Player support multi channel playback
  fmeVideoPlayer.VideoEngineClass := TFrameSyncedVideo;

  // Currently multi channel functionality is only exposed through the Video Engine,
  // not the Video Player UI frame, so grab a reference of the instance
  fmeSyncedVideo := TFrameSyncedVideo(fmeVideoPlayer.PlaybackFrame);

  // Change this line to switch playback engines (mpv, vlc, mlplayer
  { TODO: Make fmeSyncedVideo.VideoEngineClass a per-user choice based on available options }
  { TODO: fmeVideoPlayer/fmeSyncedVideo Code here was copied from IM_Video, I've simplified code
          here and it's all still working - backport changes to IM_Video }
  fmeSyncedVideo.VideoEngineClass := TFrameVideoLibmpv;

  // Now the UI is created, let's create the providers and bind/register

  // Data Provider
  FDataProvider := TDatabaseProvider.Create;
  FDataProvider.OnProviderReady := @DoProviderReady;
  FDataProvider.OnAnomalyChanged := @DoAnomalyChanged;

  dsAnomalyDetails.Dataset := FDataProvider.AnomalyDataSet;
  fmeAnomalies.Dataset := FDataProvider.AnomalyDataSet;

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

  // And these definitely need freeing :-)
  FreeAndNil(FSettings);
  FreeAndNil(FDataProvider);
  FreeAndNil(FMediaProvider);
End;

Procedure TfrmStarfixAnomalies.FormShow(Sender: TObject);
Begin
  If Not FActivated Then
  Begin
    // If needed (was for testing)

    FActivated := True;
  End;
End;

Procedure TfrmStarfixAnomalies.LoadGlobalSettings(oInifile: TIniFile);
Begin
  // FormPosition, global grid settings etc
  Inherited LoadGlobalSettings(oInifile);

  // Application Settings
  FSettings.LoadSettings(oInifile);

  // Data Persistence Settings
  FDataProvider.LoadSettings(oInifile);

  // Allow the controls to persist their own settings (data filters, volume etc)
  fmeImageViewer.LoadSettings(oInifile);
  fmeAnomalies.LoadSettings(oInifile);
  fmeVideoPlayer.LoadSettings(oInifile);
End;

Procedure TfrmStarfixAnomalies.SaveGlobalSettings(oInifile: TIniFile);
Begin
  // Application Settings
  FSettings.SaveSettings(oInifile);

  // Database Settings
  FDataProvider.SaveSettings(oInifile);

  // Allow the controls to persist their settings
  fmeImageViewer.SaveSettings(oInifile);
  fmeAnomalies.SaveSettings(oInifile);
  fmeVideoPlayer.SaveSettings(oInifile);

  // FormPosition, global grid settings etc
  Inherited SaveGlobalSettings(oInifile);
End;

Procedure TfrmStarfixAnomalies.mnuSettingsClick(Sender: TObject);
Begin
  FSettings.OpenSettings;
End;

Procedure TfrmStarfixAnomalies.tmrHideSummaryTimer(Sender: TObject);
Begin
  tmrHideSummary.Enabled := False;
  pnlHidingSummary.Visible := False;
End;

Procedure TfrmStarfixAnomalies.RefreshUI;
Begin
  Inherited RefreshUI;

  mnuDatabaseOpen.Enabled := MSSQL.Available;
End;

Procedure TfrmStarfixAnomalies.mnuDatabaseOpenClick(Sender: TObject);
Begin
  // TODO: Move Settings into a Frame, then
  //       add a plugin capability to OpenDaabase dialog
  If FSettings.OpenSettings Then
    If FDataProvider.Open Then
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
  End;
End;

// Data has just loaded or User has scrolled to the next anomaly in the list
Procedure TfrmStarfixAnomalies.DoAnomalyChanged(Sender: TObject;
  Const ANewAnomalyNo: String; Const ADateTime: TDateTime);
Var
  slImages: TStringList;
  sImageFile, sFolder: String;
  sWantedChannel: String;
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
              If FSettings.ChannelOrder.Count = 0 Then
                FSettings.ChannelOrder.Add('*');

              For sWantedChannel In FSettings.ChannelOrder Do
              Begin
                For oVideoFile In oVideoFiles Do
                Begin
                  If (oVideoFile.Channel = '*') Or SameText(oVideoFile.Channel,
                    sWantedChannel) Then
                  Begin
                    sFolder := IncludeTrailingBackslash(
                      FMediaProvider.LookupFolder(oVideoFile.Filename));

                    If FileExists(sFolder + oVideoFile.Filename) Then
                      fmeSyncedVideo.Load(sFolder + oVideoFile.Filename,
                        oVideoFile.Channel, oVideoFile.StartDateTime);

                    Break;
                  End;
                End;
              End;
            Finally
              fmeSyncedVideo.EndLoadVideos;
            End;

            If fmeSyncedVideo.VideoFileCount > 0 Then
            Begin
              // Rearrange video layout
              If fmeSyncedVideo.VideoFileCount > 2 Then
                fmeSyncedVideo.Layout(2, 2)
              Else
                fmeSyncedVideo.Layout(1, fmeSyncedVideo.VideoFileCount);

              // Pause the video (this is anomaly review, user will want to study the start)
              fmeSyncedVideo.Autoplay := False;
              fmeSyncedVideo.Pause;

              // Seek
              fmeSyncedVideo.PositionAsTime := ADateTime;

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
End;

End.
