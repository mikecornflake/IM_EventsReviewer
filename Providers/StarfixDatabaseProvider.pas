Unit StarfixDatabaseProvider;

{$mode ObjFPC}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}

Interface

Uses
  Classes, SysUtils, DataProvider, MediaTypes, Inifiles, mssqlconn, sqldb,
  dblib, DB, BufDataset, ExtCtrls, MSSQLSupport, FrameCampaignRules,
  IMMessaging, AppMessaging, DialogFrameHost, CampaignRules;

Type

  { TStarfixDatabaseProvider }

  TStarfixDatabaseProvider = Class(TDataProvider)
  Private
    FSessionIDs: TStringList;
    FCampaignEventRules: TCampaignEventRules;

    // Connection Details
    FDatabaseName, FServer: String;
    FUsername, FPassword: String;
    FPort: Integer;

    // Database
    FDriverFilename: String;

    // Controls
    FConnection: TMSSQLConnection;
    FTransaction: TSQLTransaction;
    FMaster: TSQLQuery;
    FSurveyPerVideo: TSQLQuery;

    // Dynamic SQLs
    FMasterSQLSelect, FMasterSQLFrom, FMasterSQLWhere, FMasterSQLOrder: String;
    FTimeSQLSelect: String; // Replacement Select for the Master SQL
    FVideosForTimeSQL: String;
    FQuery: TSQLQuery;

    // Settings Frames
    fmeSettingsMSSQL: TFrameMSSQLConnection;
    fmeCampaignRules: TfmeCampaignRules;

    Function GetSessionSelectionFilter: String;
    Procedure ApplySettingsFrame(AFrame: TFrameMSSQLConnection);
    Procedure PopulateSettingsFrame(AFrame: TFrameMSSQLConnection);

    Procedure DoReceiveVideoLoaded(AMessage: TIMMessage);
    Procedure DoReceiveVideoUnloaded(AMessage: TIMMessage);
  Protected
    Function ProcessEventnameForReport(Var AType: String): Boolean; Override;

    Function GetDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;
  Public
    Constructor Create; Override;
    Destructor Destroy; Override;

    Function Open: Boolean; Override;
    Function Refresh: Boolean; Override;
    Function Close: Boolean; Override;

    Function Title: String; Override;

    Procedure RegisterFrames(ADialog: TDialogFrameHost; ALoading: Boolean); Override;
    Procedure ApplyFrames; Override;
    Procedure UnRegisterFrames(ADialog: TDialogFrameHost); Override;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;
    Function GetKPForDateTime(ADateTime: TDateTime): Double; Override;

    Procedure LoadSettings(AInifile: TIniFile); Override;
    Procedure SaveSettings(AInifile: TIniFile); Override;
  End;

Implementation

Uses
  FormMain, FormEventsReviewer, ThirdPartySupport,
  Dialogs, Controls, Forms, LazLogger, DBSupport, DataFilters, FrameGridSelection, ButtonPanel;

  { TStarfixDatabaseProvider }

Constructor TStarfixDatabaseProvider.Create;
Begin
  Inherited Create;

  FLoaded := False;

  FConnection := TMSSQLConnection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);

  FConnection.Transaction := FTransaction;

  FMaster := TSQLQuery.Create(nil);
  FMaster.Database := FConnection;
  FMaster.Transaction := FTransaction;
  FMaster.AfterScroll := @DoMasterAfterScroll;
  FMaster.AfterOpen := @DoDatasetAfterOpen;
  FUpdatingMasterDataset := False;

  FTimeSQLSelect := 'SELECT                                                         ';
  FTimeSQLSelect += '  Min(DATEADD(S, E.TIMEDATE, ''1970-01-01'')) As [Start_Time], ';
  FTimeSQLSelect += '  Max(DATEADD(S, E.TIMEDATE, ''1970-01-01'')) As [End_Time]    ';

  FMasterSQLSelect := 'SELECT E.[UNIQUE_ID],                   ';
  FMasterSQLSelect += '       DATEADD(S, E.TIMEDATE, ''1970-01-01'') AS [' +
    FFieldStartTime + '], ';
  FMasterSQLSelect += '       E.KP AS [' + FFieldStartKP + '], ';
  FMasterSQLSelect += '       E.[Type],                        ';
  FMasterSQLSelect += '       E.Comment AS [Description],      ';
  FMasterSQLSelect += '       E.Anomaly_No AS [' + FFieldAnomalyReference + '], ';
  FMasterSQLSelect += '       CASE E.Anomaly                   ';
  FMasterSQLSelect += '           WHEN 1 THEN ''Y''            ';
  FMasterSQLSelect += '           ELSE ''N''                   ';
  FMasterSQLSelect += '       END AS [Anomaly],                ';
  FMasterSQLSelect += '       CASE E.Anomaly                   ';
  FMasterSQLSelect += '           WHEN 1 THEN ''Red''          ';
  FMasterSQLSelect += '           ELSE NULL                    ';
  FMasterSQLSelect += '       END AS [Colour_ID],              ';
  FMasterSQLSelect += '       TRY_CONVERT(decimal(18,3), E.Length) AS [Length_(m)], ';
  FMasterSQLSelect += '       TRY_CONVERT(decimal(18,3), E.Width) AS [Width_(m)],   ';
  FMasterSQLSelect += '       TRY_CONVERT(decimal(18,3), E.Height) AS [Height_(m)], ';
  FMasterSQLSelect += '       E.Observed_Offset AS [Offset_(m)], ';
  FMasterSQLSelect += '       E.[Clock],                       ';
  FMasterSQLSelect += '       E.East AS [Easting],             ';
  FMasterSQLSelect += '       E.North AS [Northing],           ';
  FMasterSQLSelect += '       E.[Depth]                        ';

  FMasterSQLFrom := 'FROM dbo.Event_3 E                        ';
  FMasterSQLFrom += 'INNER JOIN dbo.SESSIONS S ON (S.START_TIME <= E.TIMEDATE          ';
  FMasterSQLFrom += '                              AND S.END_TIME >= E.TIMEDATE        ';
  FMasterSQLFrom += '                              AND S.INPUT_FILES = ''Pos Import'') ';

  FMasterSQLWhere := 'WHERE (E.PROC_FLAGS & 512) <> 512 ';

  FMasterSQLOrder := 'ORDER BY [KP] ASC ';

  FSurveyPerVideo := TSQLQuery.Create(nil);
  FSurveyPerVideo.Database := FConnection;
  FSurveyPerVideo.Transaction := FTransaction;
  FSurveyPerVideo.SQL.Add('SELECT DATEADD(S, P.TIMEDATE, ''1970-01-01'') AS [Time], ');
  FSurveyPerVideo.SQL.Add('       P.EDITED_KP AS [KP]                               ');
  FSurveyPerVideo.SQL.Add('FROM DBO.POSITION_3 P                                    ');
  FSurveyPerVideo.SQL.Add('WHERE DATEADD(S, P.TIMEDATE, ''1970-01-01'')>=:Start_Datetime ');
  FSurveyPerVideo.SQL.Add('  AND DATEADD(S, P.TIMEDATE, ''1970-01-01'')<=:End_Datetime   ');
  FSurveyPerVideo.SQL.Add('ORDER BY P.TIMEDATE ASC                                  ');

  // Generic TSQLQuery used for one-shot SQLs
  FQuery := TSQLQuery.Create(nil);
  FQuery.Database := FConnection;
  FQuery.Transaction := FTransaction;

  FVideosForTimeSQL := 'SELECT V.Filename As [Filename],      ';
  FVideosForTimeSQL += '    V.ChannelLocation As [Channel],   ';
  FVideosForTimeSQL += '    DATEADD(S, V.StartTime, ''1970-01-01'') AS [Start], ';
  FVideosForTimeSQL += '    DATEADD(S, V.EndTime, ''1970-01-01'') AS [End]      ';
  FVideosForTimeSQL += 'FROM dbo.dvfilename_5 V                ';
  FVideosForTimeSQL += 'WHERE DATEADD(S, V.StartTime, ''1970-01-01'') <= :TIMEDATE_ID';
  FVideosForTimeSQL += '  AND DATEADD(S, V.EndTime,   ''1970-01-01'') >= :TIMEDATE_ID';

  // Fetch complete result set.
  // Required when other queries on the same connection may be opened
  // from dataset events such as AfterScroll.
  // Without this, FreeTDS may report
  //    "adaptive server operation with results pending".
  FMaster.PacketRecords := -1;
  FQuery.PacketRecords := -1;

  // Register the database driver
  FDriverFilename := '';

  // This is in DialogMSSQLConnection
  If MSSQL.Available And RegisterMSSQLDriver Then
    FDriverFilename := IncludeTrailingBackslash(MSSQL.Folder) + 'dblib.dll';

  // Third party acknowledgements
  ThirdParties.Include([THIRDPARTY_MSSQL]);

  // Events
  FOnProviderPreparing := nil;
  FOnDataChanged := nil;

  // Filters
  FDataFilters.Add(TDataFilter.Create(11, 'Anomalies', '(Anomaly = ''Y'')', @DoDataFilterExecute));
  FDataFilters.Add(TDataFilter.Create(14, 'Freespans', '(Type = ''Freespan*'')',
    @DoDataFilterExecute));
  FDataFilters.Add(TDataFilter.Create(17, 'Exclude Fieldjoints',
    '(NOT (Type = ''*Joint*''))', @DoDataFilterExecute));

  FCampaignEventRules := TCampaignEventRules.Create(True);

  fmeSettingsMSSQL := nil;
  fmeCampaignRules := nil;

  FSessionIDs := TStringList.Create;

  FCapabilities := [dpcHasKP, dpcHasSurvey, dpcHasVideoMetadata];

  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageVideosLoaded, @DoReceiveVideoLoaded);
  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageVideosUnLoaded, @DoReceiveVideoUnloaded);
End;

Destructor TStarfixDatabaseProvider.Destroy;
Begin
  frmEventsReviewer.MessageBus.Unsubscribe(Self);

  Close;

  FreeAndNil(FSessionIDs);

  // Shouldn't be needed
  FreeAndNil(fmeSettingsMSSQL);
  FreeAndNil(fmeCampaignRules);

  If FConnection.Connected Then
    FConnection.Connected := False;

  FreeAndNil(FCampaignEventRules);
  FreeAndNil(FSurveyPerVideo);
  FreeAndNil(FQuery);
  FreeAndNil(FMaster);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);

  Inherited Destroy;
End;

Function TStarfixDatabaseProvider.Open: Boolean;
Var
  sSessionFilter: String;
Begin
  Result := False;
  FLoaded := False;

  If MSSQL.Available Then
  Begin
    // Close any existing connection
    If FConnection.Connected Then
    Begin
      // Clear any set Filter
      Filter := '';

      FMinDateTime := 0;
      FMaxDateTime := 0;

      // Unload any filtered records
      FFilteredDataset.Clear;

      FConnection.Connected := False;
    End;

    // Try to connect to database
    If (Pos('\', FServer) > 0) Or (Pos(':', FServer) > 0) Then
      FConnection.Hostname := FServer
    Else
      FConnection.Hostname := Format('%s:%d', [FServer, FPort]);
    FConnection.DatabaseName := FDatabaseName;
    FConnection.Username := FUsername;
    FConnection.Password := FPassword;

    // Here to allow debugging in MS SQL
    FConnection.Params.Clear;
    FConnection.Params.Add('APPLICATIONNAME=' + Copy(Application.Title, 1, 25));

    MainForm.Status := 'Connecting to MS SQL';
    MainForm.Busy := True;
    Try
      Try
        FConnection.Connected := True;

        FTransaction.StartTransaction;
        FConnection.ExecuteDirect('SET CONCAT_NULL_YIELDS_NULL ON');
        FConnection.ExecuteDirect('SET QUOTED_IDENTIFIER ON');
        FConnection.ExecuteDirect('SET ANSI_WARNINGS ON');
        FConnection.ExecuteDirect('SET ANSI_PADDING ON');
        FConnection.ExecuteDirect('SET ANSI_NULLS ON');
        FTransaction.Commit;

        // Override our earlier Busy (manually, because it is likely a nested Busy)
        frmEventsReviewer.Cursor := crDefault;
        Screen.Cursor := crDefault;
        Try
          sSessionFilter := Trim(GetSessionSelectionFilter);
        Finally
          frmEventsReviewer.Cursor := crHourglass;
          Screen.Cursor := crHourglass;
        End;

        If FMaster.Active Then
          FMaster.Close;

        // Retrieving results
        FMaster.SQL.Text := FMasterSQLSelect + FMasterSQLFrom + FMasterSQLWhere +
          sSessionFilter + FMasterSQLOrder;
        FMaster.Open;

        If FQuery.Active Then
          FQuery.Close;

        FQuery.SQL.Text := FTimeSQLSelect + FMasterSQLFrom + FMasterSQLWhere + sSessionFilter;
        FQuery.Open;

        FMinDateTime := ValueAsFloat(FQuery, 'Start_Time', 0);
        FMaxDateTime := ValueAsFloat(FQuery, 'End_Time', 0);

        Result := True;
        FLoaded := True;

        // Let the Application know we're now ready for it
        If Assigned(FOnProviderPreparing) Then
          FOnProviderPreparing(Self);

        // Everything that must happen before the rest of the application
        // sees the provider as ready has now happened.
        frmEventsReviewer.MessageBus.Broadcast(Self, TIMMessageDataProviderReady);

        // We suppressed the first event being loaded, so broadcast it now manually
        DoMasterAfterScroll(FMaster);
      Except
        On E: Exception Do
        Begin
          ShowMessage(E.Message);

          If FMaster.Active Then
            FMaster.Close;

          If FConnection.Connected Then
            FConnection.Close;

          Result := False;
          FLoaded := False;
        End;
      End;
    Finally
      MainForm.Busy := False;
    End;
  End;
End;

Function TStarfixDatabaseProvider.Refresh: Boolean;
Var
  dtCurrent: TDateTime;
Begin
  Result := False;

  If Ready Then
  Begin
    // Remember State
    dtCurrent := DateTime;

    // Clear any set Filter on Refresh;
    Filter := '';

    // Unload any filtered records
    FFilteredDataset.Clear;

    // Now refresh the Master records
    FMaster.Close;
    FMaster.Open;

    Result := True;

    // Let the Application know we're now ready for it
    If Assigned(FOnProviderPreparing) Then
      FOnProviderPreparing(Self);

    // Everything that must happen before the rest of the application
    // sees the provider as ready has now happened.
    frmEventsReviewer.MessageBus.Broadcast(Self, TIMMessageDataProviderReady);

    // We suppressed the first event being loaded, so broadcast it now manually
    DoMasterAfterScroll(FMaster);

    // Restore State;
    GotoNearestValue(FFieldStartTime, dtCurrent, -1);
  End;
End;

Function TStarfixDatabaseProvider.Close: Boolean;
Begin
  FMinDateTime := 0;
  FMaxDateTime := 0;
  FLoaded := False;

  // Clear any set Filter
  Filter := '';

  // Unload any filtered records
  FFilteredDataset.Clear;

  If FMaster.Active Then
    FMaster.Close;

  If FSurveyPerVideo.Active Then
    FSurveyPerVideo.Close;

  If FQuery.Active Then
    FQuery.Close;

  If FConnection.Connected Then
    FConnection.Close;

  Result := True;
End;

Function TStarfixDatabaseProvider.ProcessEventnameForReport(Var AType: String): Boolean;
Begin
  Result := Inherited ProcessEventnameForReport(AType);

  AType := FCampaignEventRules.ProcessedEventname(AType);

  // Starfix Database processing only...
  // Merge Start/End events into a single line each (assumes Length correctly set)
  If AType.EndsWith(' Start') Then
    AType := AType.Replace(' Start', '');

  Result := Result And Not (AType.Contains(' End'));
End;

Function TStarfixDatabaseProvider.GetDataSet: TDataSet;
Begin
  Result := FMaster;
End;

Function TStarfixDatabaseProvider.GetReady: Boolean;
Begin
  Result := FLoaded And FConnection.Connected And FMaster.Active;
End;

Procedure TStarfixDatabaseProvider.ApplySettingsFrame(AFrame: TFrameMSSQLConnection);
Begin
  // Update Connection
  FDatabaseName := AFrame.Database;
  FServer := AFrame.Server;
  FPort := AFrame.Port;
  FUsername := AFrame.Username;
  FPassword := AFrame.Password;
End;

Procedure TStarfixDatabaseProvider.PopulateSettingsFrame(AFrame: TFrameMSSQLConnection);
Begin
  // Define Connection
  AFrame.Database := FDatabaseName;
  AFrame.Server := FServer;
  AFrame.Port := FPort;
  AFrame.Username := FUsername;
  AFrame.Password := FPassword;
End;

Function TStarfixDatabaseProvider.Title: String;
Begin
  If Ready Then
    Result := 'Fugro Starfix Database: Connected to ' + FDatabaseName
  Else
    Result := 'Fugro Starfix Database: Not connected';
End;

Procedure TStarfixDatabaseProvider.RegisterFrames(ADialog: TDialogFrameHost; ALoading: Boolean);
Begin
  Inherited RegisterFrames(ADialog, ALoading);

  If ALoading Then
  Begin
    If Not Assigned(fmeSettingsMSSQL) Then
      fmeSettingsMSSQL := TFrameMSSQLConnection.Create(ADialog);

    // Additional filter to limit the databases available to be opened
    fmeSettingsMSSQL.DatabasePrefix := 'SFX';

    ADialog.RegisterFrame(fmeSettingsMSSQL, 'Database Server');
    PopulateSettingsFrame(fmeSettingsMSSQL);
  End
  Else
  Begin
    If Not Assigned(fmeCampaignRules) Then
      fmeCampaignRules := TfmeCampaignRules.Create(ADialog);

    ADialog.RegisterFrame(fmeCampaignRules, 'Pipeline Chart');
    fmeCampaignRules.CopyFrom(FCampaignEventRules);
  End;
End;

Procedure TStarfixDatabaseProvider.ApplyFrames;
Var
  sCurrent: String;
Begin
  Inherited ApplyFrames;

  // Detect if Database has changed
  sCurrent := FDatabaseName;

  If Assigned(fmeSettingsMSSQL) Then
    ApplySettingsFrame(fmeSettingsMSSQL);

  // if it has, then clear remembered session IDs
  If Not SameText(FDatabaseName, sCurrent) Then
    FSessionIDs.Clear;

  If Assigned(fmeCampaignRules) Then
    FCampaignEventRules.CopyFrom(fmeCampaignRules.CampaignEventRules);
End;

Procedure TStarfixDatabaseProvider.UnRegisterFrames(ADialog: TDialogFrameHost);
Begin
  Inherited UnRegisterFrames(ADialog);

  FreeAndNil(fmeSettingsMSSQL);
  FreeAndNil(fmeCampaignRules);
End;

Function TStarfixDatabaseProvider.GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
Var
  oVideoFile: TVideoFile;
Begin
  {$IFNDEF RELEASE}
  DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}]);
  {$ENDIF}

  Result := TVideoFiles.Create;
  Try
    // Find the target videos
    If FQuery.Active Then
      FQuery.Close;

    FQuery.SQL.Text := FVideosForTimeSQL;

    // Split for testing purposes
    FQuery.ParamByName('TIMEDATE_ID').AsDateTime := ADateTime;
    Try
      FQuery.Open;
    Except
      On E: Exception Do
      Begin
        DebugLn(['DATABASE EXCEPTION: ', E.ClassName, ': ', E.Message,
          ' Connected=', FConnection.Connected, ' Transaction.Active=', FTransaction.Active]);

        Raise Exception.CreateFmt('%s: %s' + LineEnding + 'Connection connected: %s' +
          LineEnding + 'Transaction active: %s', [E.ClassName, E.Message,
          BoolToStr(FConnection.Connected, True), BoolToStr(FTransaction.Active, True)]);
      End;
    End;

    FQuery.First;

    While Not FQuery.EOF Do
    Begin
      oVideoFile := TVideoFile.Create;
      Try
        oVideoFile.Filename := FQuery.FieldByName('Filename').AsString;
        oVideoFile.Channel := FQuery.FieldByName('Channel').AsString;
        oVideoFile.StartDateTime := FQuery.FieldByName('Start').AsDateTime;
        oVideoFile.EndDateTime := FQuery.FieldByName('End').AsDateTime;

        Result.Add(oVideoFile);
      Except
        oVideoFile.Free;
        Raise;
      End;

      FQuery.Next;
    End;

    FQuery.Close;
  Except
    Result.Free;
    Result := nil;

    Raise;
  End;
End;

Procedure TStarfixDatabaseProvider.DoReceiveVideoLoaded(AMessage: TIMMessage);
Var
  oMessage: TIMMessageVideosLoaded;
Begin
  If Not Ready Then
    Exit;

  If Not (AMessage Is TIMMessageVideosLoaded) Then
    Exit;

  oMessage := TIMMessageVideosLoaded(AMessage);

  If FSurveyPerVideo.Active Then
    FSurveyPerVideo.Close;

  FSurveyPerVideo.ParamByName('Start_Datetime').AsDateTime := oMessage.StartDateTime;
  FSurveyPerVideo.ParamByName('End_Datetime').AsDateTime := oMessage.EndDateTime;

  FSurveyPerVideo.Open;
End;

Procedure TStarfixDatabaseProvider.DoReceiveVideoUnloaded(AMessage: TIMMessage);
Begin
  If FSurveyPerVideo.Active Then
    FSurveyPerVideo.Close;
End;

Function TStarfixDatabaseProvider.GetKPForDateTime(ADateTime: TDateTime): Double;
Var
  oField: TField;
Begin
  If Ready Then
  Begin
    If Not FSurveyPerVideo.Active Or FSurveyPerVideo.IsEmpty Then
    Begin
      Result := FMaster.FieldByName(FFieldStartKP).AsFloat;
      Exit;
    End;

    DBSupport.GotoNearestValue(FSurveyPerVideo, 'Time', ADateTime, SEEK_FIRST_AFTER);

    oField := FSurveyPerVideo.FieldByName('KP');

    If (oField.IsNull) Or (oField.AsFloat = -999999) Then
      Result := FMaster.FieldByName(FFieldStartKP).AsFloat
    Else
      Result := oField.AsFloat;
  End
  Else
    Result := Inherited GetKPForDateTime(ADateTime);
End;

Function TStarfixDatabaseProvider.GetSessionSelectionFilter: String;
Var
  sQuery, sIDs: String;
  oDlg: TDialogFrameHost;
  fmeSelection: TfmeGridSelection;
  iRecord: Integer;
  oField: TField;
Begin
  Result := '';

  sQuery := 'SELECT S.NAME AS [Session],          ';
  sQuery += '       CASE S.START_KP               ';
  sQuery += '           WHEN -999999 THEN NULL    ';
  sQuery += '           ELSE S.START_KP           ';
  sQuery += '       END AS [Start_KP],            ';
  sQuery += '       CASE S.END_KP                 ';
  sQuery += '           WHEN -999999 THEN NULL    ';
  sQuery += '           ELSE S.END_KP             ';
  sQuery += '       END AS [End_KP],              ';
  sQuery += '       DATEADD(S, S.START_TIME, ''1970-01-01'') AS [Start_Time], ';
  sQuery += '       DATEADD(S, S.END_TIME, ''1970-01-01'') AS [End_Time], ';
  sQuery += '       S.[SESSION_ID]                ';
  sQuery += 'FROM DBO.SESSIONS S                  ';
  sQuery += 'WHERE S.INPUT_FILES=''Pos Import''   ';
  sQuery += 'ORDER BY S.SESSION_ID                ';

  If FQuery.Active Then
    FQuery.Close;

  FQuery.SQL.Text := sQuery;
  FQuery.Open;

  oDlg := TDialogFrameHost.Create(frmEventsReviewer);
  fmeSelection := TfmeGridSelection.Create(oDlg);
  Try
    oDlg.Caption := 'Choose working sessions';
    oDlg.RegisterFrame(fmeSelection, 'Sessions');
    oDlg.ButtonPanel.ShowButtons := [pbOK];
    oDlg.ButtonPanel.OKButton.Caption := 'Load selected sessions';
    oDlg.ButtonPanel.OKButton.Enabled := (FSessionIDs.Count > 0);

    oDlg.ButtonPanel.ShowGlyphs := [];

    fmeSelection.Dataset := FQuery;

    // Presist pre-existing FSessionIDs selection
    If FSessionIDs.Count > 0 Then
    Begin
      FQuery.DisableControls;
      Try
        iRecord := 0;

        oField := FQuery.FieldByName('SESSION_ID');

        FQuery.First;
        While Not FQuery.EOF Do
        Begin
          fmeSelection.Selected[iRecord] := (FSessionIDs.IndexOf(oField.AsString) >= 0);

          Inc(iRecord);
          FQuery.Next;
        End;
      Finally
        FQuery.EnableControls;
      End;
    End;

    If oDlg.ShowModal = mrOk Then
    Begin
      sIDs := '';
      iRecord := 0;

      FQuery.DisableControls;
      Try
        // Remember new Session IDs
        FSessionIDs.Clear;
        FQuery.First;

        oField := FQuery.FieldByName('SESSION_ID');

        While Not FQuery.EOF Do
        Begin
          If fmeSelection.Selected[iRecord] Then
          Begin
            If sIDs <> '' Then
              sIDs += ',';

            sIDs += oField.AsString;
            FSessionIDs.Add(oField.AsString);
          End;

          Inc(iRecord);
          FQuery.Next;
        End;
      Finally
        FQuery.EnableControls;
      End;

      If sIDs <> '' Then
        Result := 'AND S.SESSION_ID IN (' + sIDs + ') ';
    End;
  Finally
    fmeSelection.Free;
    oDlg.Free;
  End;

  If FQuery.Active Then
    FQuery.Close;
End;

Procedure TStarfixDatabaseProvider.LoadSettings(AInifile: TIniFile);
Begin
  // Connection
  FDatabaseName := AInifile.ReadString('Database', 'DatabaseName', '');
  FServer := AInifile.ReadString('Database', 'Server', '');
  FUsername := AInifile.ReadString('Database', 'Username', '');
  FPassword := AInifile.ReadString('Database', 'Password', '');
  FPort := AInifile.ReadInteger('Database', 'Port', 1433);
  FSessionIDs.DelimitedText := AInifile.ReadString('Database', 'Sessions', '');

  FCampaignEventRules.LoadSettings(AInifile, 'StarfixDatabase.CampaignRules');
End;

Procedure TStarfixDatabaseProvider.SaveSettings(AInifile: TIniFile);
Begin
  // Connection
  AInifile.WriteString('Database', 'DatabaseName', FDatabaseName);
  AInifile.WriteString('Database', 'Server', FServer);
  AInifile.WriteString('Database', 'Username', FUsername);
  AInifile.WriteString('Database', 'Password', FPassword);
  AInifile.WriteInteger('Database', 'Port', FPort);

  AInifile.WriteString('Database', 'Sessions', FSessionIDs.DelimitedText);

  FCampaignEventRules.SaveSettings(AInifile, 'StarfixDatabase.CampaignRules');
End;

End.
