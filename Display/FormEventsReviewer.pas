Unit FormEventsReviewer;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus, ExtCtrls, StdCtrls,
  DBCtrls, ActnList, ExtDlgs, IniFiles, DB,
  // Library
  FormMain, FrameImageViewer, FrameGrids, FrameVideo,
  // Application
  ApplicationSettings, DataProvider, MediaProvider, FrameVerticalDBGrid, StarfixDatabaseProvider,
  EventListingProvider, IMMessaging, AppMessaging, DataFilters, FramePipelineEvents;

Type

  { TfrmEventsReviewer }

  TfrmEventsReviewer = Class(TFormMain)
    actFilterAnomalies: TAction;
    actFilterSpans: TAction;
    actGotoKP: TAction;
    actGotoTime: TAction;
    actOpenEventListing: TAction;
    actRefreshDatabase: TAction;
    actSeekVideo: TAction;
    actSettings: TAction;
    actOpenDatabase: TAction;
    actMain: TActionList;
    DBEdit2: TDBEdit;
    DBEdit3: TDBEdit;
    dsNotification: TDataSource;
    edtHeight1: TDBEdit;
    edtLength1: TDBEdit;
    edtWidth1: TDBEdit;
    lblDescription2: TLabel;
    lblDescription3: TLabel;
    lblHeight1: TLabel;
    lblLength1: TLabel;
    lblWidth1: TLabel;
    mnuGotoKP: TMenuItem;
    mnuGotoTime: TMenuItem;
    mnuGotoEventTime: TMenuItem;
    mnuOpenEventListing: TMenuItem;
    mnuDatabase: TMenuItem;
    mnuDatabaseOpen: TMenuItem;
    mnuEdit: TMenuItem;
    mnuExit: TMenuItem;
    mnuSeektoVideo: TMenuItem;
    mnuSettings: TMenuItem;
    dlgAddImage: TOpenPictureDialog;
    pnlDetailsGrid: TPanel;
    pnlAnomalies: TPanel;
    pcBottom: TPageControl;
    pnlNotification: TPanel;
    pnlRight: TPanel;
    pnlVideo: TPanel;
    pmFilters: TPopupMenu;
    pmGoto: TPopupMenu;
    Separator2: TMenuItem;
    splAnomalies: TSplitter;
    splImages: TSplitter;
    splDetailsGrid: TSplitter;
    btnFilter: TToolButton;
    btnClearFilter: TToolButton;
    btnGoto: TToolButton;
    tsImages: TTabSheet;
    tsChart: TTabSheet;
    tmrNotification: TTimer;
    tbMain: TToolBar;
    btnOpenDatabase: TToolButton;
    btnSettings: TToolButton;
    btnRefreshDatabase: TToolButton;
    btnOpenEventListing: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ToolButton4: TToolButton;
    ToolButton7: TToolButton;
    Procedure actGotoKPExecute(Sender: TObject);
    Procedure actGotoTimeExecute(Sender: TObject);
    Procedure btnClearFilterClick(Sender: TObject);
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
    Procedure pmFiltersPopup(Sender: TObject);

    Procedure pnlNotificationMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    Procedure pnlNotificationMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);

    Procedure pnlNotificationMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    Procedure tmrNotificationTimer(Sender: TObject);
  Private
    // Settings
    FSettings: TApplicationSettings;

    // Providers
    FDataProvider: TDataProvider;
    FMediaProvider: TMediaProvider;
    FStarfixDatabaseProvider: TStarfixDatabaseProvider;
    FEventListingProvider: TEventListingProvider;
    FMessageBus: TAppMessageBus;

    //UI
    FActivated: Boolean;

    fmeVideo: TfmeVideo;
    fmeImageViewer: TFrameImageViewer;
    fmeDBGrid: TFrameGrid;
    fmeVerticalDBGrid: TFrameVerticalDBGrid;
    fmePipelineChart: TfmePipelineEvents;

    // Flags
    FLastImageFolder: String;

    //Notification Panel
    FNotificationDragging: Boolean;
    FNotificationDragStart: TPoint;
    FNotificationStartPos: TPoint;

    Function AddImage(Const ASourceFilename: String): Boolean;
    Procedure ClearAllMedia;
    Procedure DoSetDatasets(APopulate: Boolean);
    Function GetExactTimeSeek: Boolean;
    Procedure LoadImages(Const AAnomalyReference: String);
    Procedure ReloadAllMedia;

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
    Procedure DoRefreshImages(Sender: TObject);
    Procedure DoAddNewImage(Sender: TObject);
    Procedure DoProviderPreparing(Sender: TObject);
    Procedure DoReceiveFilterChanged(AMessage: TIMMessage);
    Procedure DoReceiveTimeSeekMessage(AMessage: TIMMessage);
    Procedure DoDataChanged(Sender: TObject; Const AAnomalyReference: String;
      Const ADateTime: TDateTime);

    Function CheckFolder(Const ACaption, AFolder: String): Boolean;
  Public
    Procedure DoPlayerGrabImage(Const AFolder: String);

    Property DataProvider: TDataProvider Read FDataProvider;
    Property MediaProvider: TMediaProvider Read FMediaProvider;
    Property Settings: TApplicationSettings Read FSettings;
    Property MessageBus: TAppMessageBus Read FMessageBus;

    Property ExactTimeSeek: Boolean Read GetExactTimeSeek;
  End;

Var
  frmEventsReviewer: TfrmEventsReviewer;

Implementation

Uses
  ThirdPartySupport, StringSupport, FileUtil, MSSQLSupport,
  Windows, DBGrids, VideoEngineFactory,
  FrameApplicationSettings, FrameSettingsSyncedVideo, DialogFrameHost,
  FileSupport, LazLogger, FrameVideoLibmpv,
  FrameEventListingSettings, DialogImageSelection, FrameDateTimeSelection, Types, Math;

  {$R *.lfm}

  { TfrmEventsReviewer }

Procedure TfrmEventsReviewer.FormCreate(Sender: TObject);
Var
  sPath: String;
Begin
  // This isn't going to be app that only an Admin can change settings...
  FAlwaysSaveSettings := True;
  FLastImageFolder := '';

  FMessageBus := TAppMessageBus.Create;
  FMessageBus.Subscribe(Self, TIMMessageTime, @DoReceiveTimeSeekMessage);
  FMessageBus.Subscribe(Self, TIMMessageFilterChanged, @DoReceiveFilterChanged);

  // Settings Manager
  FSettings := TApplicationSettings.Create;

  // UI
  fmeImageViewer := TFrameImageViewer.Create(Self);
  fmeImageViewer.Parent := tsImages;
  fmeImageViewer.Name := 'fmeImageViewer';
  fmeImageViewer.Align := alClient;
  fmeImageViewer.OnRequestAddImage := @DoAddNewImage;
  fmeImageViewer.OnRequestRefreshImages := @DoRefreshImages;
  fmeImageViewer.Enabled := False;

  fmePipelineChart := TfmePipelineEvents.Create(Self);
  fmePipelineChart.Parent := tsChart;
  fmePipelineChart.Name := 'fmePipelineChart';
  fmePipelineChart.Align := alClient;

  fmeDBGrid := TFrameGrid.Create(Self);
  fmeDBGrid.Parent := pnlAnomalies;
  fmeDBGrid.Name := 'fmeDBGrid';
  fmeDBGrid.Align := alClient;

  fmeVideo := TfmeVideo.Create(Self);
  fmeVideo.Parent := pnlVideo;
  fmeVideo.Name := 'fmeVideo';
  fmeVideo.Align := alClient;

  sPath := IncludeTrailingBackslash(GetAppConfigDir(False)) + 'Images' + PathDelim + '%TIMESTAMP%';
  fmeVideo.ImageGrabFolder := sPath;

  fmeVerticalDBGrid := TFrameVerticalDBGrid.Create(Self);
  fmeVerticalDBGrid.Parent := pnlDetailsGrid;
  fmeVerticalDBGrid.Name := 'fmeVerticalDBGrid';
  fmeVerticalDBGrid.Align := alClient;

  // Now the UI is created, let's create the providers and bind/register

  // Data Provider
  FStarfixDatabaseProvider := TStarfixDatabaseProvider.Create;
  FEventListingProvider := TEventListingProvider.Create;
  FDataProvider := nil;

  dsNotification.Dataset := nil;
  fmeDBGrid.Dataset := nil;
  fmeVerticalDBGrid.Dataset := nil;

  // Media Provider
  FMediaProvider := TMediaProvider.Create;

  FActivated := False;
End;

Procedure TfrmEventsReviewer.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(FMessageBus);

  // Fully aware these woudl be cleared up by their owner anyway
  // My philosophy is: I create, I clean up...
  FreeAndNil(fmePipelineChart);
  FreeAndNil(fmeImageViewer);
  FreeAndNil(fmeDBGrid);
  FreeAndNil(fmeVideo);
  FreeAndNil(fmeVerticalDBGrid);

  // And these definitely need freeing :-)
  FreeAndNil(FSettings);
  FDataProvider := nil;
  FreeAndNil(FStarfixDatabaseProvider);
  FreeAndNil(FEventListingProvider);
  FreeAndNil(FMediaProvider);
End;

Procedure TfrmEventsReviewer.FormShow(Sender: TObject);

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
    RoundControl(pnlNotification, 10);
    // Visible quickly at startup, but prevents a bad drawing issue on first show
    pnlNotification.Visible := False;

    FActivated := True;
  End;
End;

Procedure TfrmEventsReviewer.LoadGlobalSettings(oInifile: TIniFile);
Begin
  Inherited LoadGlobalSettings(oInifile);

  // Application Settings
  FSettings.LoadSettings(oInifile);

  // Data Persistence Settings
  FStarfixDatabaseProvider.LoadSettings(oInifile);
  FEventListingProvider.LoadSettings(oInifile);
End;

Procedure TfrmEventsReviewer.SaveGlobalSettings(oInifile: TIniFile);
Begin
  // Application Settings
  FSettings.SaveSettings(oInifile);

  // Database Settings
  FStarfixDatabaseProvider.SaveSettings(oInifile);
  FEventListingProvider.SaveSettings(oInifile);

  Inherited SaveGlobalSettings(oInifile);
End;

Procedure TfrmEventsReviewer.LoadLocalSettings(oInifile: TIniFile);
Begin
  Inherited LoadLocalSettings(oInifile);

  // Allow the controls to persist their own settings (data filters, volume etc)
  fmeImageViewer.LoadSettings(oInifile);
  fmeDBGrid.LoadSettings(oInifile);
  fmeVideo.LoadSettings(oInifile);

  // persist TfrmEventsReviewer settings
  pnlDetailsGrid.Height := oInifile.ReadInteger('Form', 'pnlDetailsGrid.Height',
    pnlDetailsGrid.Height);
  pcBottom.Height := oInifile.ReadInteger('Form', 'pnlImages.Height', pcBottom.Height);
  pnlAnomalies.Width := oInifile.ReadInteger('Form', 'pnlAnomalies.Width', pnlAnomalies.Width);

  splDetailsGrid.Top := pnlDetailsGrid.Top - splDetailsGrid.Height;
  splImages.Top := pcBottom.Top - splImages.Height;
  splAnomalies.Left := pnlAnomalies.Left + splAnomalies.Width;
End;

Procedure TfrmEventsReviewer.SaveLocalSettings(oInifile: TIniFile);
Begin
  // Allow the controls to persist their settings
  fmeImageViewer.SaveSettings(oInifile);
  fmeDBGrid.SaveSettings(oInifile);
  fmeVideo.SaveSettings(oInifile);

  // persist TfrmEventsReviewer settings
  oInifile.WriteInteger('Form', 'pnlDetailsGrid.Height', pnlDetailsGrid.Height);
  oInifile.WriteInteger('Form', 'pnlImages.Height', pcBottom.Height);
  oInifile.WriteInteger('Form', 'pnlAnomalies.Width', pnlAnomalies.Width);

  // Form Position
  Inherited SaveLocalSettings(oInifile);
End;

Procedure TfrmEventsReviewer.RefreshUI;
Var
  bEventsReady, bProviderReady: Boolean;
Begin
  Inherited RefreshUI;

  bProviderReady := Assigned(FDataProvider) And FDataProvider.Ready;
  bEventsReady := bProviderReady And Assigned(dsNotification.Dataset) And
    (dsNotification.Dataset.Active);

  actOpenDatabase.Enabled := MSSQL.Available;
  actOpenEventListing.Enabled := True;
  actRefreshDatabase.Enabled := bProviderReady;

  actSeekVideo.Enabled := bEventsReady;
  actGotoKP.Enabled := bEventsReady;
  actGotoTime.Enabled := bEventsReady;
  actFilterAnomalies.Enabled := bEventsReady;
  actFilterSpans.Enabled := bEventsReady;

  btnGoto.Enabled := bProviderReady;
  btnFilter.Enabled := bProviderReady;;
  btnClearFilter.Enabled := btnFilter.Enabled And FDataProvider.Filtered;
End;

Procedure TfrmEventsReviewer.tmrNotificationTimer(Sender: TObject);
Begin
  tmrNotification.Enabled := False;
  pnlNotification.Visible := False;
End;

Procedure TfrmEventsReviewer.actSeekVideoExecute(Sender: TObject);
Begin
  If FDataProvider.Ready Then
    FMessageBus.BroadcastTime(Self, FDataProvider.DateTime);
End;

Procedure TfrmEventsReviewer.DBEditClick(Sender: TObject);
Begin
  TDBEdit(Sender).SelectAll;
End;

Procedure TfrmEventsReviewer.actSettingsClick(Sender: TObject);
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

    oDlg.RegisterFrame(fmeSettingsApp, 'Folders');
    FSettings.PopulateSettingsFrame(fmeSettingsApp);

    oDlg.RegisterFrame(fmeSettingsVideo, 'Video');
    fmeVideo.PopulateSettingsFrame(fmeSettingsVideo);

    If oDlg.ShowModal = mrOk Then
    Begin
      FSettings.ApplySettingsFrame(fmeSettingsApp);
      fmeVideo.ApplySettingsFrame(fmeSettingsVideo);

      ReloadAllMedia;
    End;
  Finally
    fmeSettingsApp.Free;
    fmeSettingsVideo.Free;
    oDlg.Free;
  End;

  RefreshUI;
End;

Procedure TfrmEventsReviewer.pmFiltersPopup(Sender: TObject);
Var
  oFilter: TDataFilter;
  oMenu: TMenuItem;
Begin
  pmFilters.Items.Clear;

  If Not Assigned(FDataProvider) Then
    Exit;

  For oFilter In FDataProvider.DataFilters Do
  Begin
    oMenu := TMenuItem.Create(pmFilters);

    oMenu.Caption := oFilter.Caption;
    oMenu.ImageIndex := oFilter.ImageIndex;
    oMenu.OnClick := oFilter.OnExecute;

    oMenu.Tag := PtrInt(oFilter);

    pmFilters.Items.Add(oMenu);
  End;
End;

Procedure TfrmEventsReviewer.pnlNotificationMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
Begin
  If Button <> mbLeft Then
    Exit;

  tmrNotification.Enabled := False;
  FNotificationDragging := True;
  //pnlNotification.MouseCapture := True;

  // Remember the mouse position in screen coordinates.
  FNotificationDragStart := pnlNotification.ClientToScreen(Types.Point(X, Y));

  // Remember the panel's original position.
  FNotificationStartPos := Point(pnlNotification.Left, pnlNotification.Top);
End;

Procedure TfrmEventsReviewer.pnlNotificationMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
Var
  pMouse: TPoint;
  pVideoTopLeft, pVideoBottomRight: TPoint;
  rBounds: TRect;
  iLeft, iTop: Integer;
Begin
  If Not FNotificationDragging Then
    Exit;

  // Current mouse position in screen coordinates.
  pMouse := pnlNotification.ClientToScreen(Point(X, Y));

  // Calculate the proposed new position.
  iLeft := FNotificationStartPos.X + (pMouse.X - FNotificationDragStart.X);
  iTop := FNotificationStartPos.Y + (pMouse.Y - FNotificationDragStart.Y);

  // Convert pnlVideo's client rectangle into the coordinate
  // system of pnlNotification's parent (the form).
  pVideoTopLeft := pnlNotification.Parent.ScreenToClient(pnlVideo.ClientToScreen(Point(0, 0)));

  pVideoBottomRight := pnlNotification.Parent.ScreenToClient(pnlVideo.ClientToScreen(
    Point(pnlVideo.ClientWidth, pnlVideo.ClientHeight)));

  rBounds := Rect(pVideoTopLeft.X, pVideoTopLeft.Y, pVideoBottomRight.X, pVideoBottomRight.Y);

  // Keep the entire notification panel inside pnlVideo.
  iLeft := EnsureRange(iLeft, rBounds.Left, Max(rBounds.Left, rBounds.Right -
    pnlNotification.Width));

  iTop := EnsureRange(iTop, rBounds.Top, Max(rBounds.Top, rBounds.Bottom -
    pnlNotification.Height));

  pnlNotification.SetBounds(iLeft, iTop, pnlNotification.Width, pnlNotification.Height);
End;

Procedure TfrmEventsReviewer.pnlNotificationMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
Begin
  If Button = mbLeft Then
  Begin
    FNotificationDragging := False;
    tmrNotification.Enabled := True;
    //pnlNotification.MouseCapture := False;
  End;
End;

Procedure TfrmEventsReviewer.DoSetDatasets(APopulate: Boolean);
Begin
  If APopulate Then
  Begin
    dsNotification.Dataset := FDataProvider.Dataset;

    If FDataProvider.Filtered Then
    Begin
      fmeDBGrid.Dataset := FDataProvider.FilteredDataSet;
      fmeVerticalDBGrid.Dataset := FDataProvider.FilteredDataSet;
    End
    Else
    Begin
      fmeDBGrid.Dataset := FDataProvider.Dataset;
      fmeVerticalDBGrid.Dataset := FDataProvider.Dataset;
    End;
  End
  Else
  Begin
    dsNotification.Dataset := nil;

    fmeDBGrid.Dataset := nil;
    fmeVerticalDBGrid.Dataset := nil;
  End;
End;

Procedure TfrmEventsReviewer.SetDataProvider(AProvider: TDataProvider);
Begin
  If Assigned(FDataProvider) Then
  Begin
    FDataProvider.Close;

    FDataProvider.OnProviderPreparing := nil;
    FDataProvider.OnDataChanged := nil;

    ClearAllMedia;

    DoSetDatasets(False);
  End;

  FDataProvider := AProvider;

  Try
    If Assigned(FDataProvider) Then
    Begin
      FDataProvider.OnProviderPreparing := @DoProviderPreparing;
      FDataProvider.OnDataChanged := @DoDataChanged;

      DoSetDatasets(True);

      FDataProvider.Open;
    End;
  Finally
    RefreshUI;
  End;
End;

Procedure TfrmEventsReviewer.DoReceiveTimeSeekMessage(AMessage: TIMMessage);
//Var
//  oMessage: TIMMessageTime;
Begin
  If Not (AMessage Is TIMMessageTime) Then
    Exit;

  //  oMessage := TIMMessageTime(Sender);

  //Caption := oMessage.Sender.ClassName + ' Seek to: ' +
  //  FormatDateTime('HH:mm:ss', oMessage.DateTime);
End;

Procedure TfrmEventsReviewer.actOpenEventListingExecute(Sender: TObject);
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

    oDlg.RegisterFrame(fmeSettingsApp, 'Folders');
    FSettings.PopulateSettingsFrame(fmeSettingsApp);

    If oDlg.ShowModal = mrOk Then
    Begin
      FEventListingProvider.ApplySettingsFrame(fmeSettingsEventListing);
      FSettings.ApplySettingsFrame(fmeSettingsApp);

      // Set Provider includes the Open Call;
      SetDataProvider(FEventListingProvider);

      If FDataProvider.Ready Then
        RefreshUI;
    End;
  Finally
    fmeSettingsEventListing.Free;
    fmeSettingsApp.Free;
    oDlg.Free;
  End;
End;

Procedure TfrmEventsReviewer.actDatabaseOpenClick(Sender: TObject);
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

    oDlg.RegisterFrame(fmeSettingsApp, 'Folders');
    FSettings.PopulateSettingsFrame(fmeSettingsApp);

    If oDlg.ShowModal = mrOk Then
    Begin
      FStarfixDatabaseProvider.ApplySettingsFrame(fmeSettingsMSSQL);
      FSettings.ApplySettingsFrame(fmeSettingsApp);

      // Set Provider includes the Open Call;
      SetDataProvider(FStarfixDatabaseProvider);

      If FDataProvider.Ready Then
        RefreshUI;
    End;
  Finally
    fmeSettingsMSSQL.Free;
    fmeSettingsApp.Free;
    oDlg.Free;
  End;
End;

Procedure TfrmEventsReviewer.btnClearFilterClick(Sender: TObject);
Begin
  If Assigned(FDataProvider) Then
    FDataProvider.Filter := '';
End;

Procedure TfrmEventsReviewer.actGotoKPExecute(Sender: TObject);
Var
  dKP: Double;
  sNewKP: String;
Begin
  dKP := fmePipelineChart.KP;
  sNewKP := FormatFloat('0.000', dKP);

  If Not InputQuery('Goto KP', 'Please enter new KP', sNewKP) Then
    Exit;

  If Not TryStrToFloat(sNewKP, dKP) Then
  Begin
    ShowMessage('Invalid KP entered: ' + sNewKP);
    Exit;
  End;

  FDataProvider.GotoKP(dKP);
End;

Procedure TfrmEventsReviewer.actGotoTimeExecute(Sender: TObject);
Var
  dtDateTime: TDateTime;
Begin
  dtDateTime := FDataProvider.DateTime;

  If Not InputQueryDateTime('Please enter new time (UTC)', dtDateTime) Then
    Exit;

  FDataProvider.GotoDateTime(dtDateTime);
End;

Procedure TfrmEventsReviewer.actRefreshDatabaseExecute(Sender: TObject);
Begin
  Try
    // Sender is nil if this routine manually called during
    // OnDataProviderPreparing
    If Assigned(Sender) Then
      FDataProvider.Refresh;
  Finally
    Try
      If FDataProvider.Ready Then
        ReloadAllMedia
      Else
      Begin
        DoSetDatasets(False);
        ClearAllMedia;
      End;
    Finally
      RefreshUI;
    End;
  End;
End;

Procedure TfrmEventsReviewer.ReloadAllMedia;
Begin
  If Assigned(FDataProvider) And FDataProvider.Ready Then
  Begin
    // Media folder contents are updated dynamically during operations
    // Reload all media on eiter settings change or user request
    FMediaProvider.ScanVideoFiles(FSettings.VideoFolder);
    fmeImageViewer.RefreshImages;
  End;
End;

Procedure TfrmEventsReviewer.ClearAllMedia;
Begin
  // This will reload when the ProviderReady message is broadcast
  fmePipelineChart.Clear;

  fmeImageViewer.ClearImages;
  fmeVideo.Clear;
  FMediaProvider.Clear;

  // clear flags
  FLastImageFolder := '';
  fmeImageViewer.Enabled := False;
End;

Procedure TfrmEventsReviewer.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

Procedure TfrmEventsReviewer.DoProviderPreparing(Sender: TObject);
Begin
  // We're now either connected to database, or have the offline data available
  If FDataProvider.Ready Then
  Begin
    actRefreshDatabaseExecute(nil);

    // Resize columns etc
    fmeDBGrid.InitialiseDBGrid(True);

    Caption := Format('%s: [%s]', [Application.Title, FDataProvider.Title]);
    Status := '';

    fmeImageViewer.Enabled := True;
  End;

  RefreshUI;
End;

Procedure TfrmEventsReviewer.DoReceiveFilterChanged(AMessage: TIMMessage);
Begin
  DoSetDatasets(True);

  // Resize columns etc
  fmeDBGrid.InitialiseDBGrid(True);

  RefreshUI;
End;

Procedure TfrmEventsReviewer.LoadImages(Const AAnomalyReference: String);
Var
  slImages: TStringList;
  sImageFile, sFolder, sExt: String;

  Function Caption(ABaseFolder: String; AFilename: String): String;
  Begin
    Result := TextBetween(AFilename, IncludeTrailingBackslash(ABaseFolder), '');
  End;

Begin
  {$IFNDEF RELEASE}
  DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}, ' ', AAnomalyReference]);
  {$ENDIF}

  If Trim(AAnomalyReference) = '' Then
    sFolder := FSettings.EventImageFolder
  Else
    sFolder := FSettings.AnomalyImageFolder;

  fmeVideo.GrabImageBtnEnabled := DirectoryExists(sFolder);

  If Not fmeVideo.GrabImageBtnEnabled Then
    fmeVideo.ImageGrabHint := 'Check Settings: Image Folder does not exist.'
  Else
    fmeVideo.ImageGrabHint := 'Selected images will be saved in ' + sFolder;

  If (AAnomalyReference = '') And (sFolder = FLastImageFolder) Then
    Exit;

  FLastImageFolder := sFolder;

  fmeImageViewer.ClearImages;

  If Not fmeVideo.GrabImageBtnEnabled Then
    Exit;

  Status := 'Loading images from ' + sFolder;

  slImages := TStringList.Create;
  Try
    FindAllFiles(slImages, sFolder, AAnomalyReference + '_*.*', False);

    slImages.Sorted := True;

    For sImageFile In slImages Do
    Begin
      sExt := ExtractFileExt(sImageFile);

      If IsImage(sExt) Then
        fmeImageViewer.AddImage(sImageFile, Caption(sFolder, sImageFile));
    End;
  Finally
    slImages.Free;
  End;

  Status := 'Finished loading images';
  Status := '';
End;

Procedure TfrmEventsReviewer.DoRefreshImages(Sender: TObject);
Var
  sAnomalyRef: String;
Begin
  If FDataProvider.Ready Then
  Begin
    sAnomalyRef := FDataProvider.AnomalyReference;
    FLastImageFolder := '';
    LoadImages(sAnomalyRef);
  End;
End;

// Data has just loaded or User has scrolled to the next anomaly in the list
Procedure TfrmEventsReviewer.DoDataChanged(Sender: TObject; Const AAnomalyReference: String;
  Const ADateTime: TDateTime);
Begin
  tmrNotification.Enabled := True;

  If Trim(AAnomalyReference) = '' Then
    pnlNotification.Color := TColor($00B0FFFF) // Yellow
  Else
    pnlNotification.Color := TColor($008080FF);  // Red

  pnlNotification.Visible := True;

  LoadImages(AAnomalyReference);

  RefreshUI;
End;

Function TfrmEventsReviewer.CheckFolder(Const ACaption, AFolder: String): Boolean;
Begin
  Result := DirectoryExists(AFolder);
  If Not Result Then
    ShowMessage(ACaption + ' Folder does not exist.' + LineEnding +
      'Please check Settings and try again');
End;

Function TfrmEventsReviewer.AddImage(Const ASourceFilename: String): Boolean;
Var
  iFileSuffix: Integer;
  sFilename, sPrefix, sDir, sExt: String;
Begin
  Result := False;

  sPrefix := Trim(FDataProvider.AnomalyReference);
  If sPrefix <> '' Then
  Begin
    // If this is an anomaly image, rename to the Anomaly Reference
    sDir := IncludeTrailingBackslash(FSettings.AnomalyImageFolder);

    sExt := ExtractFileExt(ASourceFilename);

    iFileSuffix := 0;

    Repeat
      sFilename := Format('%s%s_%s%s', [sDir, sPrefix, Chr(Ord('a') + iFileSuffix), sExt]);

      Inc(iFileSuffix);
    Until Not FileExists(sFilename) Or (iFileSuffix = 26);

    // We exhausted a-z
    If FileExists(sFilename) Then
    Begin
      Status := 'Unable to add image - no free filename';
      Exit;
    End;
  End
  Else
  Begin
    // If this is an event image, keep original name, but change folder
    sDir := IncludeTrailingPathDelimiter(FSettings.EventImageFolder);

    sFilename := sDir + ExtractFilename(ASourceFilename);
  End;

  // Copy the file to the destination
  Result := FileUtil.CopyFile(ASourceFilename, sFilename);

  If Result Then
  Begin
    Status := 'Successfully added image ' + sFilename;

    // Force a refres
    FLastImageFolder := '';
  End
  Else
    Status := 'Unable to copy image ' + ASourceFilename;
End;

Function TfrmEventsReviewer.GetExactTimeSeek: Boolean;
Begin
  Result := fmeVideo.VideoTrackbarSeek;
End;

Procedure TfrmEventsReviewer.DoPlayerGrabImage(Const AFolder: String);
Var
  oDlg: TDialogImageSelection;
  i: Integer;
  oImage: TViewerImage;
  sAnomalyReference: String;
  bContinue: Boolean;
Begin
  sAnomalyReference := Trim(FDataProvider.AnomalyReference);
  If sAnomalyReference = '' Then
    bContinue := CheckFolder('Event Image', FSettings.EventImageFolder)
  Else
    bContinue := CheckFolder('Anomaly Image', FSettings.AnomalyImageFolder);

  If bContinue Then
  Begin
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
            AddImage(oImage.Filename);
        End;

        LoadImages(FDataProvider.AnomalyReference);
      End;
    Finally
      oDlg.Free;
    End;
  End;

  // Delete all remaining files
  DeleteDirectory(AFolder, False, True);
End;

Procedure TfrmEventsReviewer.DoAddNewImage(Sender: TObject);
Begin
  dlgAddImage.Options := dlgAddImage.Options - [ofAutoPreview];

  If dlgAddImage.Execute Then
  Begin
    If AddImage(dlgAddImage.Filename) Then
      LoadImages(FDataProvider.AnomalyReference);
  End;
End;

End.
