Unit StarfixDatabaseProvider;

{$mode ObjFPC}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}

Interface

Uses
  Classes, SysUtils, DataProvider, MediaTypes, Inifiles, mssqlconn, sqldb,
  dblib, DB, BufDataset, ExtCtrls,
  MSSQLSupport, IMMessaging, AppMessaging;

Type

  { TStarfixDatabaseProvider }

  TStarfixDatabaseProvider = Class(TDataProvider)
  Private
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

    // Dynamic SQL
    FMasterSQLSelect, FMasterSQLWhere, FMasterSQLOrder: String;

    qryVideosforTime: TSQLQuery;
    Function GetSessionSelectionFilter: String;
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

    Procedure ApplySettingsFrame(AFrame: TFrameMSSQLConnection);
    Procedure PopulateSettingsFrame(AFrame: TFrameMSSQLConnection);

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;

    Procedure LoadSettings(AInifile: TIniFile); Override;
    Procedure SaveSettings(AInifile: TIniFile); Override;
  End;

Implementation

Uses
  FormMain, FormEventsReviewer, ThirdPartySupport,
  Dialogs, Controls, Forms, LazLogger, DBSupport, DataFilters, DialogFrameHost, FrameGridSelection;

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

  FMasterSQLSelect := 'SELECT E.[UNIQUE_ID], ';
  FMasterSQLSelect += '       DATEADD(S, E.TIMEDATE, ''1970-01-01'') AS [' +
    FFieldStartTime + '], ';
  FMasterSQLSelect += '       E.KP AS [' + FFieldStartKP + '], ';
  FMasterSQLSelect += '       E.[Type], ';
  FMasterSQLSelect += '       E.Comment AS [Description], ';
  FMasterSQLSelect += '       E.Anomaly_No AS [' + FFieldAnomalyReference + '], ';
  FMasterSQLSelect += '       CASE E.Anomaly ';
  FMasterSQLSelect += '           WHEN 1 THEN ''Y'' ';
  FMasterSQLSelect += '           ELSE ''N'' ';
  FMasterSQLSelect += '       END AS [Anomaly], ';
  FMasterSQLSelect += '       CASE E.Anomaly ';
  FMasterSQLSelect += '           WHEN 1 THEN ''Red'' ';
  FMasterSQLSelect += '           ELSE NULL ';
  FMasterSQLSelect += '       END AS [Colour_ID], ';
  FMasterSQLSelect += '       TRY_CONVERT(decimal(18,3), E.Length) AS [Length_(m)], ';
  FMasterSQLSelect += '       TRY_CONVERT(decimal(18,3), E.Width) AS [Width_(m)], ';
  FMasterSQLSelect += '       TRY_CONVERT(decimal(18,3), E.Height) AS [Height_(m)], ';
  FMasterSQLSelect += '       E.Observed_Offset AS [Offset_(m)], ';
  FMasterSQLSelect += '       E.[Clock], ';
  FMasterSQLSelect += '       E.East AS [Easting], ';
  FMasterSQLSelect += '       E.North AS [Northing], ';
  FMasterSQLSelect += '       E.[Depth] ';
  FMasterSQLSelect += 'FROM dbo.Event_3 E ';
  FMasterSQLSelect += 'INNER JOIN dbo.SESSIONS S ON (S.START_TIME <= E.TIMEDATE ';
  FMasterSQLSelect += '                              AND S.END_TIME >= E.TIMEDATE ';
  FMasterSQLSelect += '                              AND S.INPUT_FILES = ''Pos Import'') ';
  FMasterSQLWhere := 'WHERE (E.PROC_FLAGS & 512) <> 512 ';
  FMasterSQLOrder := 'ORDER BY [KP] ASC ';

  qryVideosforTime := TSQLQuery.Create(nil);
  qryVideosforTime.Database := FConnection;
  qryVideosforTime.Transaction := FTransaction;
  qryVideosforTime.SQL.Add('SELECT V.Filename As [Filename],       ');
  qryVideosforTime.SQL.Add('    V.ChannelLocation As [Channel], ');
  qryVideosforTime.SQL.Add('    DATEADD(S, V.StartTime, ''1970-01-01'') AS [Start], ');
  qryVideosforTime.SQL.Add('    DATEADD(S, V.EndTime, ''1970-01-01'') AS [End]      ');
  qryVideosforTime.SQL.Add('FROM dbo.dvfilename_5 V            ');
  qryVideosforTime.SQL.Add('WHERE DATEADD(S, V.StartTime, ''1970-01-01'') <= :TIMEDATE_ID');
  qryVideosforTime.SQL.Add('  AND DATEADD(S, V.EndTime,   ''1970-01-01'') >= :TIMEDATE_ID');

  // Fetch complete result set.
  // Required when other queries on the same connection may be opened
  // from dataset events such as AfterScroll.
  // Without this, FreeTDS may report
  //    "adaptive server operation with results pending".
  FMaster.PacketRecords := -1;
  qryVideosforTime.PacketRecords := -1;

  // Register the database driver
  FDriverFilename := '';

  // This is in DialogMSSQLConnection
  If MSSQL.Available And RegisterMSSQLDriver Then
    FDriverFilename := IncludeTrailingBackslash(MSSQL.Folder) + 'dblib.dll';

  // Third party acknowledgements
  ThirdParties.Include([THIRDPARTY_MSSQL]);

  // Events
  FOnProviderReady := nil;
  FOnDataChanged := nil;

  // Filters
  FDataFilters.Add(TDataFilter.Create(11, 'Anomalies', '(Anomaly = ''Y'')', @DoDataFilterExecute));
  FDataFilters.Add(TDataFilter.Create(14, 'Freespans', '(Type = ''Freespan*'')',
    @DoDataFilterExecute));
  FDataFilters.Add(TDataFilter.Create(17, 'Exclude Fieldjoints',
    '(NOT (Type = ''*Joint*''))', @DoDataFilterExecute));
End;

Destructor TStarfixDatabaseProvider.Destroy;
Begin
  If FConnection.Connected Then
    FConnection.Connected := False;

  FreeAndNil(qryVideosforTime);
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
    // Try to connect to database
    If FConnection.Connected Then
      FConnection.Connected := False;

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

        MainForm.Busy := False;
        Try
          sSessionFilter := Trim(GetSessionSelectionFilter);
        Finally
          MainForm.Busy := True;
        End;

        // Retrieving results
        FMaster.SQL.Text := FMasterSQLSelect + FMasterSQLWhere + sSessionFilter + FMasterSQLOrder;
        FMaster.Open;

        Result := True;
        FLoaded := True;

        // Let the Application know we're now ready for it
        If Assigned(FOnProviderReady) Then
          FOnProviderReady(Self);

        // Everything that must happen before the rest of the application
        // sees the provider as ready has now happened.
        frmEventsReviewer.MessageBus.Broadcast(Self, TIMMessageDataProviderReady);

        // We suppressed the first event being loaded, so broadcast it now manually
        DoMasterAfterScroll(FMaster);
      Except
        On E: Exception Do
          ShowMessage(E.Message);
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

    FMaster.Close;
    FMaster.Open;

    Result := True;

    // Let the Application know we're now ready for it
    If Assigned(FOnProviderReady) Then
      FOnProviderReady(Self);

    // Restore State;
    GotoNearestValue(FFieldStartTime, dtCurrent, -1);
  End;
End;

Function TStarfixDatabaseProvider.Close: Boolean;
Begin
  FLoaded := False;

  If FMaster.Active Then
    FMaster.Close;

  If qryVideosforTime.Active Then
    qryVideosforTime.Close;

  If FConnection.Connected Then
    FConnection.Close;

  Result := True;
End;

Function TStarfixDatabaseProvider.ProcessEventnameForReport(Var AType: String): Boolean;
Begin
  Result := Inherited ProcessEventnameForReport(AType);

  // Merge all fieldjoint types into a single line
  If AType.Contains(' Joint') Then
    AType := 'Fieldjoint';

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
  Result := FLoaded And FConnection.Connected;
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

Function TStarfixDatabaseProvider.GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
Var
  oVideoFile: TVideoFile;
Begin
  {$IFNDEF RELEASE}
  DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}]);
  {$ENDIF}

  Result := TVideoFiles.Create;

  // Find the target videos
  If qryVideosforTime.Active Then
    qryVideosforTime.Close;

  // Split for testing purposes
  qryVideosforTime.ParamByName('TIMEDATE_ID').AsDateTime := ADateTime;
  Try
    qryVideosforTime.Open;
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

  qryVideosforTime.First;

  While Not qryVideosforTime.EOF Do
  Begin
    oVideoFile := TVideoFile.Create;

    oVideoFile.Filename := qryVideosforTime.FieldByName('Filename').AsString;
    oVideoFile.Channel := qryVideosforTime.FieldByName('Channel').AsString;
    oVideoFile.StartDateTime := qryVideosforTime.FieldByName('Start').AsDateTime;
    oVideoFile.EndDateTime := qryVideosforTime.FieldByName('End').AsDateTime;

    Result.Add(oVideoFile);

    qryVideosforTime.Next;
  End;
End;

Function TStarfixDatabaseProvider.GetSessionSelectionFilter: String;
Var
  sQuery, sIDs: String;
  oQuery: TSQLQuery;
  oDlg: TDialogFrameHost;
  fmeSelection: TfmeGridSelection;
  iRecord: Integer;
Begin
  Result := '';

  sQuery := 'SELECT S.NAME AS [Session], ';
  sQuery += '       CASE S.START_KP ';
  sQuery += '           WHEN -999999 THEN NULL ';
  sQuery += '           ELSE S.START_KP ';
  sQuery += '       END AS [Start_KP], ';
  sQuery += '       CASE S.END_KP ';
  sQuery += '           WHEN -999999 THEN NULL ';
  sQuery += '           ELSE S.END_KP ';
  sQuery += '       END AS [End_KP], ';
  sQuery += '       DATEADD(S, S.START_TIME, ''1970-01-01'') AS [Start_Time], ';
  sQuery += '       DATEADD(S, S.END_TIME, ''1970-01-01'') AS [End_Time], ';
  sQuery += '       S.[SESSION_ID] ';
  sQuery += 'FROM DBO.SESSIONS S ';
  sQuery += 'ORDER BY S.SESSION_ID ';

  oQuery := TSQLQuery.Create(nil);
  Try
    oQuery.Database := FConnection;
    oQuery.Transaction := FTransaction;

    oQuery.SQL.Text := sQuery;
    oQuery.Open;

    oDlg := TDialogFrameHost.Create(frmEventsReviewer);
    fmeSelection := TfmeGridSelection.Create(oDlg);
    Try
      oDlg.Caption := 'Choose working sessions';
      oDlg.RegisterFrame(fmeSelection, 'Sessions');
      oDlg.ButtonPanel.OKButton.Caption := 'Select sessions';
      oDlg.ButtonPanel.CancelButton.Caption := 'Load all sessions';
      oDlg.ButtonPanel.ShowGlyphs := [];

      fmeSelection.Dataset := oQuery;

      If oDlg.ShowModal = mrOk Then
      Begin
        sIDs := '';
        iRecord := 0;

        oQuery.First;

        While Not oQuery.EOF Do
        Begin
          If fmeSelection.Selected[iRecord] Then
          Begin
            If sIDs <> '' Then
              sIDs += ',';

            sIDs += oQuery.FieldByName('SESSION_ID').AsString;
          End;

          Inc(iRecord);
          oQuery.Next;
        End;

        If sIDs <> '' Then
          Result := 'AND S.SESSION_ID IN (' + sIDs + ') ';
      End;
    Finally
      fmeSelection.Free;
      oDlg.Free;
    End;
  Finally
    oQuery.Close;
    oQuery.Free;
  End;
End;

Procedure TStarfixDatabaseProvider.LoadSettings(AInifile: TIniFile);
Begin
  // Connection
  FDatabaseName := AInifile.ReadString('Database', 'DatabaseName', '');
  FServer := AInifile.ReadString('Database', 'Server', '');
  FUsername := AInifile.ReadString('Database', 'Username', '');
  FPassword := AInifile.ReadString('Database', 'Password', '');
  FPort := AInifile.ReadInteger('Database', 'Port', 1433);
End;

Procedure TStarfixDatabaseProvider.SaveSettings(AInifile: TIniFile);
Begin
  // Connection
  AInifile.WriteString('Database', 'DatabaseName', FDatabaseName);
  AInifile.WriteString('Database', 'Server', FServer);
  AInifile.WriteString('Database', 'Username', FUsername);
  AInifile.WriteString('Database', 'Password', FPassword);
  AInifile.WriteInteger('Database', 'Port', FPort);
End;

End.
