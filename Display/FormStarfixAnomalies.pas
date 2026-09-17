Unit FormStarfixAnomalies;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus, ExtCtrls, StdCtrls,
  DBCtrls, ActnList, ExtDlgs, IniFiles, DB,
  // Library
  FormMain, FrameImageViewer, FrameGrids, FrameVideoPlayer, FrameSyncedVideo,
  // Application
  ApplicationSettings, DataProvider, MediaProvider, FrameVerticalDBGrid,
  StarfixDatabaseProvider, EventListingProvider;

Type

  { TfrmStarfixReviewer }

  TfrmStarfixReviewer = Class(TFormMain)
    actFilterAnomalies: TAction;
    actFilterSpans: TAction;
    actOpenEventListing: TAction;
    actRefreshDatabase: TAction;
    actSeekVideo: TAction;
    actSettings: TAction;
    actOpenDatabase: TAction;
    actMain: TActionList;
    DBEdit1: TDBEdit;
    DBEdit2: TDBEdit;
    DBEdit3: TDBEdit;
    DBEdit4: TDBEdit;
    dsDataDetails: TDataSource;
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
    mnuOpenEventListing: TMenuItem;
    mnuDatabase: TMenuItem;
    mnuDatabaseOpen: TMenuItem;
    mnuEdit: TMenuItem;
    mnuExit: TMenuItem;
    mnuSeektoVideo: TMenuItem;
    mnuSettings: TMenuItem;
    dlgAddImage: TOpenPictureDialog;
    pnlDetailsGrid: TPanel;
    pnlImages: TPanel;
    pnlHidingSummary: TPanel;
    pnlAnomalies: TPanel;
    pnlRight: TPanel;
    pnlVideo: TPanel;
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
    btnRefreshDatabase: TToolButton;
    btnOpenEventListing: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    ToolButton6: TToolButton;
    ToolButton7: TToolButton;
    Procedure DoApplyFilter(Sender: TObject);
    Procedure actOpenEventListingExecute(Sender: TObject);
    Procedure actRefreshDatabaseExecute(Sender: TObject);
    Procedure actSeekVideoExecute(Sender: TObject);
    Procedure DBEditClick(Sender: TObject);
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
    FDataProvider: TDataProvider;
    FMediaProvider: TMediaProvider;
    FStarfixDatabaseProvider: TStarfixDatabaseProvider;
    FEventListingProvider: TEventListingProvider;

    //UI
    FActivated: Boolean;

    fmeImageViewer: TFrameImageViewer;
    fmeData: TFrameGrid;
    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;
    fmeDetailGrid: TFrameVerticalDBGrid;

    // Tracking video playback status
    FPendingVideoTime: TDateTime;
    FSeekPending: Boolean;
    Function AddAnomalyImage(Const ASourceFilename: String): Boolean;
    Function CheckAnomalyReferenceReadiness: Boolean;
    Procedure DoPlayerGrabImage(Sender: TObject; Const AFolder: String);
    Procedure DoVideoLoaded(Sender: TObject);
    Procedure LoadAnomalyImages(Const AAnomalyReference: String);

    Procedure DoRefreshAnomalyImages(Sender: TObject);
    Procedure DoAddNewImage(Sender: TObject);
    Procedure SetDataProvider(AProvider: TDataProvider);
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
    Procedure DoDataChanged(Sender: TObject; Const ANewAnomalyNo: String;
      Const ADateTime: TDateTime);
  Public

  End;

Var
  frmStarfixReviewer: TfrmStarfixReviewer;

Implementation

Uses
  ThirdPartySupport, StringSupport, FileUtil, MSSQLSupport, MediaTypes,
  Windows, DBGrids, VideoEngineFactory,
  FrameApplicationSettings, FrameSettingsSyncedVideo, DialogFrameHost,
  DialogImageSelection, FileSupport, LazLogger, FrameVideoLibmpv,
  FrameEventListingSettings;

  {$R *.lfm}

  { TfrmStarfixReviewer }

Procedure TfrmStarfixReviewer.FormCreate(Sender: TObject);
Var
  sPath: String;
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
  fmeImageViewer.OnRequestAddImage := @DoAddNewImage;
  fmeImageViewer.OnRequestRefreshImages := @DoRefreshAnomalyImages;
  fmeImageViewer.Enabled := False;;

  fmeData := TFrameGrid.Create(Self);
  fmeData.Parent := pnlAnomalies;
  fmeData.Name := 'fmeData';
  fmeData.Align := alClient;

  fmeVideoPlayer := TFrameVideoPlayer.Create(Self);
  fmeVideoPlayer.Parent := pnlVideo;
  fmeVideoPlayer.Name := 'fmeVideoPlayer';
  fmeVideoPlayer.Align := alClient;
  fmeVideoPlayer.Autoplay := True;
  fmeVideoPlayer.ShowLabel := True;

  sPath := IncludeTrailingBackslash(GetAppConfigDir(False)) + 'Images' + PathDelim + '%TIMESTAMP%';
  fmeVideoPlayer.ImageGrabFolder := sPath;
  fmeVideoPlayer.OnGrabImage := @DoPlayerGrabImage;
  fmeVideoPlayer.ImageGrabHint := 'Selected images will be saved in Anomaly Image folder';

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
  FStarfixDatabaseProvider := TStarfixDatabaseProvider.Create;
  FEventListingProvider := TEventListingProvider.Create;
  FDataProvider := nil;

  dsDataDetails.Dataset := nil;
  fmeData.Dataset := nil;
  fmeDetailGrid.Dataset := nil;

  // Media Provider
  FMediaProvider := TMediaProvider.Create;

  FActivated := False;
End;

Procedure TfrmStarfixReviewer.FormDestroy(Sender: TObject);
Begin
  // Fully aware these woudl be cleared up by their owner anyway
  // My philosophy is: I create, I clean up...
  FreeAndNil(fmeImageViewer);
  FreeAndNil(fmeData);
  FreeAndNil(fmeVideoPlayer);
  FreeAndNil(fmeDetailGrid);

  // And these definitely need freeing :-)
  FreeAndNil(FSettings);
  FreeAndNil(FDataProvider);
  FreeAndNil(FMediaProvider);
End;

Procedure TfrmStarfixReviewer.FormShow(Sender: TObject);

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

Procedure TfrmStarfixReviewer.LoadGlobalSettings(oInifile: TIniFile);
Begin
  Inherited LoadGlobalSettings(oInifile);

  // Application Settings
  FSettings.LoadSettings(oInifile);

  // Data Persistence Settings
  FStarfixDatabaseProvider.LoadSettings(oInifile);
  FEventListingProvider.LoadSettings(oInifile);
End;

Procedure TfrmStarfixReviewer.SaveGlobalSettings(oInifile: TIniFile);
Begin
  // Application Settings
  FSettings.SaveSettings(oInifile);

  // Database Settings
  FStarfixDatabaseProvider.SaveSettings(oInifile);
  FEventListingProvider.SaveSettings(oInifile);

  Inherited SaveGlobalSettings(oInifile);
End;

Procedure TfrmStarfixReviewer.LoadLocalSettings(oInifile: TIniFile);
Begin
  Inherited LoadLocalSettings(oInifile);

  // Allow the controls to persist their own settings (data filters, volume etc)
  fmeImageViewer.LoadSettings(oInifile);
  fmeData.LoadSettings(oInifile);
  fmeVideoPlayer.LoadSettings(oInifile);

  // persist TfrmStarfixReviewer settings
  pnlDetailsGrid.Height := oInifile.ReadInteger('Form', 'pnlDetailsGrid.Height',
    pnlDetailsGrid.Height);
  pnlImages.Height := oInifile.ReadInteger('Form', 'pnlImages.Height', pnlImages.Height);
  pnlAnomalies.Width := oInifile.ReadInteger('Form', 'pnlAnomalies.Width', pnlAnomalies.Width);

  splDetailsGrid.Top := pnlDetailsGrid.Top - splDetailsGrid.Height;
  splImages.Top := pnlImages.Top - splImages.Height;
  splAnomalies.Left := pnlAnomalies.Left + splAnomalies.Width;
End;

Procedure TfrmStarfixReviewer.SaveLocalSettings(oInifile: TIniFile);
Begin
  // Allow the controls to persist their settings
  fmeImageViewer.SaveSettings(oInifile);
  fmeData.SaveSettings(oInifile);
  fmeVideoPlayer.SaveSettings(oInifile);

  // persist TfrmStarfixReviewer settings
  oInifile.WriteInteger('Form', 'pnlDetailsGrid.Height', pnlDetailsGrid.Height);
  oInifile.WriteInteger('Form', 'pnlImages.Height', pnlImages.Height);
  oInifile.WriteInteger('Form', 'pnlAnomalies.Width', pnlAnomalies.Width);

  // Form Position
  Inherited SaveLocalSettings(oInifile);
End;

Procedure TfrmStarfixReviewer.RefreshUI;
Begin
  Inherited RefreshUI;

  actOpenDatabase.Enabled := MSSQL.Available;
  actOpenEventListing.Enabled := True;
  actRefreshDatabase.Enabled := Assigned(FDataProvider) And FDataProvider.Ready;

  actSeekVideo.Enabled := Assigned(FDataProvider) And FDataProvider.Ready And
    Assigned(dsDataDetails.Dataset) And (dsDataDetails.Dataset.Active);

  actFilterAnomalies.Enabled := actSeekVideo.Enabled;
  actFilterSpans.Enabled := actSeekVideo.Enabled;

  If FSettings.ImageFolder <> '' Then
    fmeVideoPlayer.ImageGrabHint := 'Selected images will be saved in ' + FSettings.ImageFolder;
End;

Procedure TfrmStarfixReviewer.tmrHideSummaryTimer(Sender: TObject);
Begin
  tmrHideSummary.Enabled := False;
  pnlHidingSummary.Visible := False;
End;

Procedure TfrmStarfixReviewer.actSeekVideoExecute(Sender: TObject);
Begin
  If FDataProvider.Ready Then
    fmeSyncedVideo.PositionAsTime := FDataProvider.DateTime;
End;

Procedure TfrmStarfixReviewer.DBEditClick(Sender: TObject);
Begin
  TDBEdit(Sender).SelectAll;
End;

Procedure TfrmStarfixReviewer.actSettingsClick(Sender: TObject);
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

Procedure TfrmStarfixReviewer.SetDataProvider(AProvider: TDataProvider);
Begin
  If FDataProvider = AProvider Then
    Exit;

  If Assigned(FDataProvider) Then
  Begin
    FDataProvider.Close;

    FDataProvider.OnProviderReady := nil;
    FDataProvider.OnDataChanged := nil;

    dsDataDetails.Dataset := nil;
    fmeData.Dataset := nil;
    fmeDetailGrid.Dataset := nil;
  End;

  FDataProvider := AProvider;

  If Assigned(FDataProvider) Then
  Begin
    FDataProvider.OnProviderReady := @DoProviderReady;
    FDataProvider.OnDataChanged := @DoDataChanged;

    dsDataDetails.Dataset := FDataProvider.Dataset;
    fmeData.Dataset := FDataProvider.Dataset;
    fmeDetailGrid.Dataset := FDataProvider.Dataset;

    FDataProvider.Open;
  End;
End;

Procedure TfrmStarfixReviewer.actOpenEventListingExecute(Sender: TObject);
Var
  oDlg: TDialogFrameHost;
  fmeSettingsEventListing: TFrameEventListingSettings;
  fmeSettingsApp: TFrameApplicationSettings;
Begin
  oDlg := TDialogFrameHost.Create(Self);
  fmeSettingsEventListing := TFrameEventListingSettings.Create(oDlg);
  fmeSettingsApp := TFrameApplicationSettings.Create(oDlg);
  Try
    oDlg.Caption := Application.Title;

    oDlg.RegisterFrame(fmeSettingsEventListing, 'Event Listing');
    FEventListingProvider.PopulateSettingsFrame(fmeSettingsEventListing);

    oDlg.RegisterFrame(fmeSettingsApp, 'Starfix');
    FSettings.PopulateSettingsFrame(fmeSettingsApp);

    If oDlg.ShowModal = mrOk Then
    Begin
      SetDataProvider(FEventListingProvider);

      FEventListingProvider.ApplySettingsFrame(fmeSettingsEventListing);
      FSettings.ApplySettingsFrame(fmeSettingsApp);

      If FDataProvider.Open Then
        RefreshUI;
    End;
  Finally
    fmeSettingsEventListing.Free;
    fmeSettingsApp.Free;
    oDlg.Free;
  End;
  RefreshUI;
End;

Procedure TfrmStarfixReviewer.DoApplyFilter(Sender: TObject);
Begin
  If actFilterAnomalies.Checked And actFilterSpans.Checked Then
    fmeData.Filter := '(Anomaly_No <> '''') OR (Type = ''Freespan*'')'
  Else If actFilterAnomalies.Checked Then
    fmeData.Filter := '(Anomaly_No <> '''')'
  Else If actFilterSpans.Checked Then
    fmeData.Filter := '(Type = ''Freespan*'')'
  Else
    fmeData.Filter := '';
End;

Procedure TfrmStarfixReviewer.actDatabaseOpenClick(Sender: TObject);
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
    fmeSettingsMSSQL.DatabasePrefix := 'SFX';

    oDlg.RegisterFrame(fmeSettingsMSSQL, 'Database Server');
    FStarfixDatabaseProvider.PopulateSettingsFrame(fmeSettingsMSSQL);

    oDlg.RegisterFrame(fmeSettingsApp, 'Starfix');
    FSettings.PopulateSettingsFrame(fmeSettingsApp);

    If oDlg.ShowModal = mrOk Then
    Begin
      SetDataProvider(FStarfixDatabaseProvider);

      FStarfixDatabaseProvider.ApplySettingsFrame(fmeSettingsMSSQL);
      FSettings.ApplySettingsFrame(fmeSettingsApp);

      If FDataProvider.Open Then
        RefreshUI;
    End;
  Finally
    fmeSettingsMSSQL.Free;
    fmeSettingsApp.Free;
    oDlg.Free;
  End;
  RefreshUI;
End;

Procedure TfrmStarfixReviewer.actRefreshDatabaseExecute(Sender: TObject);
Begin
  FDataProvider.Refresh;

  RefreshUI;
End;

Procedure TfrmStarfixReviewer.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

Procedure TfrmStarfixReviewer.DoProviderReady(Sender: TObject);
Begin
  // We're now either connected to database, or have the offline data available
  If FDataProvider.Ready Then
  Begin
    FMediaProvider.ScanVideoFiles(FSettings.VideoFolder);

    // Resize columns etc
    fmeData.InitialiseDBGrid(True);

    Caption := Format('%s: [%s]', [Application.Title, FDataProvider.Title]);
    Status := '';

    fmeImageViewer.Enabled := True;
  End;

  RefreshUI;
End;

Procedure TfrmStarfixReviewer.LoadAnomalyImages(Const AAnomalyReference: String);
Var
  slImages: TStringList;
  sImageFile: String;

  Function Caption(ABaseFolder: String; AFilename: String): String;
  Begin
    Result := TextBetween(AFilename, IncludeTrailingBackslash(ABaseFolder), '');
  End;

Begin
  {$IFNDEF RELEASE}
  DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}, ' ', AAnomalyReference]);
  {$ENDIF}

  // Load Anomaly Images
  fmeImageViewer.ClearImages;

  If Trim(AAnomalyReference) = '' Then
    Exit;

  slImages := TStringList.Create;
  Try
    FindAllFiles(slImages, FSettings.ImageFolder, AAnomalyReference + '*.*', True);

    For sImageFile In slImages Do
      fmeImageViewer.AddImage(sImageFile, Caption(FSettings.ImageFolder, sImageFile));
  Finally
    slImages.Free;
  End;
End;

Procedure TfrmStarfixReviewer.DoRefreshAnomalyImages(Sender: TObject);
Var
  sAnomalyRef: String;
Begin
  If FDataProvider.Ready Then
  Begin
    sAnomalyRef := FDataProvider.AnomalyReference;
    LoadAnomalyImages(sAnomalyRef);
  End;
End;

// Data has just loaded or User has scrolled to the next anomaly in the list
Procedure TfrmStarfixReviewer.DoDataChanged(Sender: TObject; Const ANewAnomalyNo: String;
  Const ADateTime: TDateTime);
Var
  sFolder: String;
  oVideoFiles: TVideoFiles;
  oVideoFile: TVideoFile;
Begin
  tmrHideSummary.Enabled := True;
  pnlHidingSummary.Visible := True;

  If DirectoryExists(FSettings.ImageFolder) Then
    LoadAnomalyImages(ANewAnomalyNo)
  Else
    fmeImageViewer.ClearImages;

  // Do I need to load new Video?
  If (fmeSyncedVideo.StartDateTime <= ADateTime) And
    (ADateTime <= fmeSyncedVideo.EndDateTime) Then
  Begin
    // No, we just need to seek to the new time
    fmeSyncedVideo.PositionAsTime := ADateTime;
  End
  Else
  Begin
    // Yes, videos need to be updated

    // Does the Data Provider know anything about Videos?
    oVideoFiles := FDataProvider.GetVideoFilesForTime(ADateTime);

    // If not, ask the Media Provider...
    If Not Assigned(oVideoFiles) Then
      oVideoFiles := FMediaProvider.VideoFilesForDateTime(ADateTime);
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

  RefreshUI;
End;

Procedure TfrmStarfixReviewer.DoVideoLoaded(Sender: TObject);
Begin
  tmrSeekAfterLoadVideo.Enabled := True;
End;

Procedure TfrmStarfixReviewer.tmrSeekAfterLoadVideoTimer(Sender: TObject);
Begin
  tmrSeekAfterLoadVideo.Enabled := False;

  If FSeekPending Then
  Begin
    FSeekPending := False;
    fmeSyncedVideo.PositionAsTime := FPendingVideoTime;
  End;
End;

Function TfrmStarfixReviewer.AddAnomalyImage(Const ASourceFilename: String): Boolean;
Var
  iFileSuffix: Integer;
  sFilename, sAnomalyRef, sDir, sExt: String;
Begin
  Result := False;

  sAnomalyRef := FDataProvider.AnomalyReference;
  sDir := IncludeTrailingBackslash(FSettings.ImageFolder);
  sExt := ExtractFileExt(ASourceFilename);

  iFileSuffix := 0;

  Repeat
    sFilename := Format('%s%s_%s%s', [sDir, sAnomalyRef, Chr(Ord('a') + iFileSuffix), sExt]);

    Inc(iFileSuffix);
  Until Not FileExists(sFilename) Or (iFileSuffix = 26);

  // We exhausted a-z
  If FileExists(sFilename) Then
  Begin
    Status := 'Unable to add anomaly image - no free filename';
    Exit;
  End;

  Result := FileUtil.CopyFile(ASourceFilename, sFilename);

  If Result Then
    Status := 'Successfully added anomaly image ' + sFilename
  Else
    Status := 'Unable to copy anomaly image ' + ASourceFilename;
End;

Function TfrmStarfixReviewer.CheckAnomalyReferenceReadiness: Boolean;
Begin
  Result := False;

  If FDataProvider.Ready Then
    If Trim(FDataProvider.AnomalyReference) = '' Then
      ShowMessage('The current anomaly does not have an Anomaly Reference assigned.' +
        LineEnding + 'This needs to be resolved using Starfix.Edit first.')
    Else
      Result := True;
End;

Procedure TfrmStarfixReviewer.DoPlayerGrabImage(Sender: TObject; Const AFolder: String);
Var
  oDlg: TDialogImageSelection;
  i: Integer;
  oImage: TViewerImage;
Begin
  If Not CheckAnomalyReferenceReadiness Then
    Exit;

  oDlg := TDialogImageSelection.Create(Self);
  Try
    oDlg.LoadFromFolder(AFolder);

    If oDlg.ShowModal = mrOk Then
    Begin
      // Move and rename
      For i := 0 To oDlg.ImageCount - 1 Do
      Begin
        oImage := oDlg.Image[i];

        If oImage.Selected Then
          AddAnomalyImage(oImage.Filename);
      End;

      LoadAnomalyImages(FDataProvider.AnomalyReference);
    End;
  Finally
    Try
      // Delete all remaining files
      DeleteDirectory(AFolder, False);
    Finally
      oDlg.Free;
    End;
  End;
End;

Procedure TfrmStarfixReviewer.DoAddNewImage(Sender: TObject);
Begin
  If Not CheckAnomalyReferenceReadiness Then
    Exit;

  dlgAddImage.Options := dlgAddImage.Options - [ofAutoPreview];

  If dlgAddImage.Execute Then
  Begin
    If AddAnomalyImage(dlgAddImage.Filename) Then
      LoadAnomalyImages(FDataProvider.AnomalyReference);
  End;
End;

End.
