Unit ModuleStarfix;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, mssqlconn, sqldb, dblib, DB, IniFiles,
  DialogMSSQLConnection,
  FrameGrids, FrameImageViewer,
  FrameVideoPlayer, FrameSyncedVideo, VideoFileMap, ExtCtrls;

Type

  { TdmStarfix }

  TdmStarfix = Class(TDataModule)
    connStarfix: TMSSQLConnection;
    qryAnomalies: TSQLQuery;
    qryVideosforTime: TSQLQuery;
    tmrLoadAnomalyMedia: TTimer;
    transStarfix: TSQLTransaction;
    Procedure DataModuleCreate(Sender: TObject);
    Procedure DataModuleDestroy(Sender: TObject);
    Procedure qryAnomaliesAfterOpen(DataSet: TDataSet);
    Procedure qryAnomaliesAfterScroll(DataSet: TDataSet);
    Procedure tmrLoadAnomalyMediaTimer(Sender: TObject);
  Private
    // Connection Details
    FDatabaseName, FServer: String;
    FImageFolder: String;
    FUsername, FPassword: String;
    FPort: Integer;

    // Database
    FDriverFilename: String;

    // Anomalies
    FAnomalyImageViewer: TFrameImageViewer;
    FAnomalyGrid: TFrameGrid;
    FVideoFolder: String;

    // Video
    FVideoPlayer: TFrameVideoPlayer;
    FSyncedVideo: TFrameSyncedVideo;
    FVideoFileMap: TVideoMap;
    FChannelOrder: TStringList;
  Public
    Function OpenDatabase: Boolean;

    Procedure LoadSettings(oInifile: TIniFile);
    Procedure SaveSettings(oInifile: TIniFile);

    Procedure RegisterAnomalyControls(Const AGrid: TFrameGrid;
      Const AImageViewer: TFrameImageViewer; Const ADatasource: TDatasource);

    Procedure RegisterVideoControls(Const APlayer: TFrameVideoPlayer;
      Const AViewer: TFrameSyncedVideo);

    Function DriverAvailable: Boolean;
    Function Connected: Boolean;

    Property ImageFolder: String Read FImageFolder Write FImageFolder;
    Property VideoFolder: String Read FVideoFolder Write FVideoFolder;
  End;

Implementation

Uses
  Controls, Dialogs, Forms, FileUtil,
  FormMain, ThirdPartySupport, StringSupport, DBSupport, FileSupport;

  {$R *.lfm}

  { TdmStarfix }

Procedure TdmStarfix.DataModuleCreate(Sender: TObject);
Begin
  // Register the database driver
  FDriverFilename := '';

  // This is in DialogMSSQLConnection
  If MSSQL.Available And RegisterMSSQLDriver Then
    FDriverFilename := IncludeTrailingBackslash(MSSQL.Folder) + 'dblib.dll';

  // Third party acknowledgements
  ThirdParties.Include([THIRDPARTY_MSSQL]);

  // Anomaly Controls
  FAnomalyImageViewer := nil;
  FAnomalyGrid := nil;

  // Video Filename/Folder lookup...
  FVideoFileMap := TVideoMap.Create;

  FChannelOrder := TStringList.Create;
  FChannelOrder.Add('Centre');
  FChannelOrder.Add('Aux');
  FChannelOrder.Add('Port');
  FChannelOrder.Add('Stbd');
End;

Procedure TdmStarfix.DataModuleDestroy(Sender: TObject);
Begin
  FreeAndNil(FChannelOrder);
  FreeAndNil(FVideoFileMap);

  If connStarfix.Connected Then
    connStarfix.Connected := False;
End;

Function TdmStarfix.OpenDatabase: Boolean;
Var
  oDlg: TdlgMSSQLConnection;
  bDoConnection: Boolean;
Begin
  Result := False;
  If MSSQL.Available Then
  Begin
    oDlg := TdlgMSSQLConnection.Create(Self);
    Try
      // Define Connection
      oDlg.Database := FDatabaseName;
      oDlg.Server := FServer;
      oDlg.Port := FPort;
      oDlg.Username := FUsername;
      oDlg.Password := FPassword;

      bDoConnection := (oDlg.ShowModal = mrOk);

      If bDoConnection Then
      Begin
        // Update Connection
        FDatabaseName := oDlg.Database;
        FServer := oDlg.Server;
        FPort := oDlg.Port;
        FUsername := oDlg.Username;
        FPassword := oDlg.Password;
      End;
    Finally
      oDlg.Free;
    End;

    If bDoConnection Then
    Begin
      // Try to connect to database
      If connStarfix.Connected Then
        connStarfix.Connected := False;

      If (Pos('\', FServer) > 0) Or (Pos(':', FServer) > 0) Then
        connStarfix.Hostname := FServer
      Else
        connStarfix.Hostname := Format('%s:%d', [FServer, FPort]);
      connStarfix.DatabaseName := FDatabaseName;
      connStarfix.Username := FUsername;
      connStarfix.Password := FPassword;

      // Here to allow debugging in MS SQL
      connStarfix.Params.Clear;
      connStarfix.Params.Add('APPLICATIONNAME=' + Copy(Application.Title, 1, 25));

      MainForm.Status := 'Connecting to MS SQL';
      MainForm.Busy := True;
      Try
        Try
          connStarfix.Connected := True;

          transStarfix.StartTransaction;
          connStarfix.ExecuteDirect('SET CONCAT_NULL_YIELDS_NULL ON');
          connStarfix.ExecuteDirect('SET QUOTED_IDENTIFIER ON');
          connStarfix.ExecuteDirect('SET ANSI_WARNINGS ON');
          connStarfix.ExecuteDirect('SET ANSI_PADDING ON');
          connStarfix.ExecuteDirect('SET ANSI_NULLS ON');
          transStarfix.Commit;

          // Retrieving anomaly results
          qryAnomalies.Open;

          // Populate VideoFilenames
          If DirectoryExists(FVideoFolder) Then
            FVideoFileMap.ScanFolder(FVideoFolder);
        Except
          On E: Exception Do
            ShowMessage(E.Message);
        End;
      Finally
        MainForm.Busy := False;
      End;
    End;
  End;
End;

Procedure TdmStarfix.LoadSettings(oInifile: TIniFile);
Begin
  // Connection
  FDatabaseName := oInifile.ReadString('Database', 'DatabaseName', '');
  FServer := oInifile.ReadString('Database', 'Server', '');
  FUsername := oInifile.ReadString('Database', 'Username', '');
  FPassword := oInifile.ReadString('Database', 'Password', '');
  FPort := oInifile.ReadInteger('Database', 'Port', 1433);
End;

Procedure TdmStarfix.SaveSettings(oInifile: TIniFile);
Begin
  // Connection
  oInifile.WriteString('Database', 'DatabaseName', FDatabaseName);
  oInifile.WriteString('Database', 'Server', FServer);
  oInifile.WriteString('Database', 'Username', FUsername);
  oInifile.WriteString('Database', 'Password', FPassword);
  oInifile.WriteInteger('Database', 'Port', FPort);
End;

Procedure TdmStarfix.RegisterAnomalyControls(Const AGrid: TFrameGrid; Const AImageViewer: TFrameImageViewer; Const ADatasource: TDatasource);
Begin
  //Assert(Connected, 'Database must be connected');
  Assert(Assigned(AImageViewer), 'Valid TFrameImageViewer must be registered with DataModule');
  Assert(Assigned(AGrid), 'Valid TFrameGrid must be connected registered with DataModule');

  FAnomalyGrid := AGrid;
  FAnomalyImageViewer := AImageViewer;

  // Connect the Grid to our dataset
  FAnomalyGrid.DataSet := qryAnomalies;

  // Initialise the Viewer
  FAnomalyImageViewer.ClearImages;

  // Connect the text entries
  ADatasource.DataSet := qryAnomalies;
End;

Procedure TdmStarfix.RegisterVideoControls(Const APlayer: TFrameVideoPlayer;
  Const AViewer: TFrameSyncedVideo);
Begin
  FVideoPlayer := APlayer;
  FSyncedVideo := AViewer;
End;

Procedure TdmStarfix.qryAnomaliesAfterOpen(DataSet: TDataSet);
Begin
  TFloatField(qryAnomalies.FieldByName('KP')).DisplayFormat := '0.000';
  FAnomalyGrid.InitialiseDBGrid(True);
End;

Procedure TdmStarfix.qryAnomaliesAfterScroll(DataSet: TDataSet);
Begin
  // Restart the one-shot debounce timer
  tmrLoadAnomalyMedia.Enabled := False;
  tmrLoadAnomalyMedia.Enabled := True;
End;

Procedure TdmStarfix.tmrLoadAnomalyMediaTimer(Sender: TObject);
Var
  oField: TField;
  slImages: TStringList;
  sAnomalyNo, sImageFile, sFilename, sChannel, sFolder: String;
  dtStart, dtEvent: TDateTime;
  dTemp: Double;
  i: Integer;
  sWantedChannel: String;

  Function Caption(ABaseFolder: String; AFilename: String): String;
  Begin
    Result := TextBetween(AFilename, IncludeTrailingBackslash(ABaseFolder), '');
  End;

Begin
  tmrLoadAnomalyMedia.Enabled := False;

  Assert(Assigned(FAnomalyImageViewer), 'Anomaly ImageViewer not connected to DataModule');
  FAnomalyImageViewer.ClearImages;

  If DirectoryExists(FImageFolder) Then
  Begin
    oField := qryAnomalies.FindField('ANOMALY_NO');

    If Not Assigned(oField) Then
      Raise EDatabaseError.CreateFMT('Anomaly Field "%s" not present in Dataset', ['ANOMALY_NO']);

    // Load Anomaly Images
    FAnomalyImageViewer.ClearImages;

    sAnomalyNo := oField.AsString;

    If Trim(sAnomalyNo) = '' Then
      Exit;

    slImages := TStringList.Create;
    Try
      FindAllFiles(slImages, FImageFolder, sAnomalyNo + '*.*', True);

      For sImageFile In slImages Do
        FAnomalyImageViewer.AddImage(sImageFile, Caption(FImageFolder, sImageFile));
    Finally
      slImages.Free;
    End;

    dtEvent := qryAnomalies.FieldByName('DATETIME').AsDateTime;

    // Do I need to load new Video?
    If (FSyncedVideo.StartDateTime <= dtEvent) And (dtEvent <= FSyncedVideo.EndDateTime) Then
    Begin
      FSyncedVideo.PositionAsTime := dtEvent;

      // TODO: Stop Seeking from restarting the video :-(
      FSyncedVideo.Pause;
    End
    Else
    Begin
      // Find the target videos
      If qryVideosforTime.Active Then
        qryVideosforTime.Close;

      // Split for testing purposes
      dTemp := qryAnomalies.FieldByName('TIMEDATE_ID').AsFloat;
      qryVideosforTime.ParamByName('TIMEDATE_ID').AsFloat := dTemp;
      qryVideosforTime.Open;

      If qryVideosforTime.RecordCount = 0 Then
      Begin
        FVideoPlayer.Clear;

        // TODO: Implement fmeSyncedVideo.clear
        //       Not done now as this will require testing all Video modules
        FSyncedVideo.ClearVideoCount;
        FSyncedVideo.ClearUnloadedVideoFrames;
      End
      Else
      Begin
        MainForm.Busy := True;
        MainForm.DisableAutoSizing;
        Try
          FSyncedVideo.BeginLoadVideos;
          Try
            qryVideosforTime.First;

            For i := 0 To FChannelOrder.Count - 1 Do
            Begin
              sWantedChannel := FChannelOrder[i];

              qryVideosforTime.First;

              While Not qryVideosforTime.EOF Do
              Begin
                sChannel := qryVideosforTime.FieldByName('Channel').AsString;

                If SameText(sChannel, sWantedChannel) Then
                Begin
                  sFilename := qryVideosforTime.FieldByName('Filename').AsString;
                  sFolder := FVideoFileMap.LookupFolder(sFilename);
                  dtStart := qryVideosforTime.FieldByName('Start').AsDateTime;

                  If FileExists(sFolder + sFilename) Then
                    FSyncedVideo.Load(sFolder + sFilename, sChannel, dtStart);

                  Break;
                End;

                qryVideosforTime.Next;
              End;
            End;
          Finally
            FSyncedVideo.EndLoadVideos;
          End;

          If FSyncedVideo.VideoFileCount > 0 Then
          Begin
            If FSyncedVideo.VideoFileCount > 2 Then
              FSyncedVideo.Layout(2, 2)
            Else
              FSyncedVideo.Layout(1, FSyncedVideo.VideoFileCount);

            // Pause the video (this is anomaly review, user will want to study the start)
            FSyncedVideo.Pause;

            // Seek
            FSyncedVideo.PositionAsTime := qryAnomalies.FieldByName('DATETIME').AsDateTime;

            FVideoPlayer.RefreshUI;
          End;
        Finally
          MainForm.EnableAutoSizing;
          MainForm.Busy := False;
        End;
      End;
    End;
  End;
End;


Function TdmStarfix.DriverAvailable: Boolean;
Begin
  Result := MSSQL.Available;
End;

Function TdmStarfix.Connected: Boolean;
Begin
  Result := connStarfix.Connected;
End;

End.
