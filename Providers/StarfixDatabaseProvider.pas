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
    FFilteredDataset: TBufDataset;
    FUpdatingFilteredDataset: Boolean;

    qryVideosforTime: TSQLQuery;

    Procedure DatasetAfterOpen(ADataSet: TDataSet);
    Procedure DoMasterAfterScroll(ADataSet: TDataSet);
    Procedure DoFilterAfterScroll(ADataSet: TDataSet);
  Protected
    Function GetDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;

    Function GetFilteredDataSet: TDataSet; Override;
    Procedure SetFilter(Const AValue: String); Override;

    // Messaging
    Procedure DoReceiveTimeSeekMessage(AMessage: TIMMessage);
  Public
    Constructor Create;
    Destructor Destroy; Override;

    Function Open: Boolean; Override;
    Function Refresh: Boolean; Override;
    Function Close: Boolean; Override;

    Function Title: String; Override;

    Procedure ApplySettingsFrame(AFrame: TFrameMSSQLConnection);
    Procedure PopulateSettingsFrame(AFrame: TFrameMSSQLConnection);

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;
    Function DateTime: TDateTime; Override;
    Function AnomalyReference: String; Override;

    Procedure LoadSettings(AInifile: TIniFile); Override;
    Procedure SaveSettings(AInifile: TIniFile); Override;
  End;

Implementation

Uses
  FormMain, FormEventsReviewer, ThirdPartySupport,
  Dialogs, Controls, Forms, LazLogger, DBSupport;

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
  FMaster.AfterOpen := @DatasetAfterOpen;
  FMaster.SQL.Add('SELECT E.[UNIQUE_ID],  ');
  FMaster.SQL.Add('       DATEADD(S, E.TIMEDATE, ''1970-01-01'') As [Start_(UTC)], ');
  FMaster.SQL.Add('       E.[KP],                       ');
  FMaster.SQL.Add('       E.[Type],                     ');
  FMaster.SQL.Add('       E.Comment As [Description],   ');
  FMaster.SQL.Add('       E.[Anomaly_No],               ');
  FMaster.SQL.Add('       CASE E.Anomaly WHEN 1 THEN ''Y''   ');
  FMaster.SQL.Add('                      ELSE ''N''     ');
  FMaster.SQL.Add('       END AS [Anomaly],                  ');
  FMaster.SQL.Add('       CASE E.Anomaly WHEN 1 THEN ''Red'' ');
  FMaster.SQL.Add('                      ELSE Null      ');
  FMaster.SQL.Add('       END AS [Colour_ID],           ');
  FMaster.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Length) As [Length_(m)], ');
  FMaster.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Width) As [Width_(m)],   ');
  FMaster.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Height) As [Height_(m)], ');
  FMaster.SQL.Add('       E.Observed_Offset As [Offset_(m)],  ');
  FMaster.SQL.Add('       E.[Clock],                    ');
  FMaster.SQL.Add('       E.East As [Easting],          ');
  FMaster.SQL.Add('       E.North As [Northing],        ');
  FMaster.SQL.Add('       E.[Depth]                     ');
  FMaster.SQL.Add('FROM dbo.Event_3 E                   ');
  FMaster.SQL.Add('INNER JOIN dbo.SESSIONS S ON (    S.START_TIME <= E.TIMEDATE    ');
  FMaster.SQL.Add('                              AND S.END_TIME   >= E.TIMEDATE    ');
  FMaster.SQL.Add('                              AND S.INPUT_FILES=''Pos Import'') ');
  FMaster.SQL.Add('WHERE (E.PROC_FLAGS & 512)<>512      ');
  FMaster.SQL.Add('ORDER BY [KP] Asc                    ');

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

  FFilteredDataset := TBufDataset.Create(nil);
  FFilteredDataset.AfterScroll := @DoFilterAfterScroll;
  FFilteredDataset.AfterOpen := @DatasetAfterOpen;
  FUpdatingFilteredDataset := False;

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

  // Messages
  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageTime, @DoReceiveTimeSeekMessage);
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

Function TStarfixDatabaseProvider.GetDataSet: TDataSet;
Begin
  Result := FMaster;
End;

Function TStarfixDatabaseProvider.GetReady: Boolean;
Begin
  Result := FLoaded And FConnection.Connected;
End;

Function TStarfixDatabaseProvider.GetFilteredDataSet: TDataSet;
Begin
  Result := FFilteredDataset;
End;

Procedure TStarfixDatabaseProvider.SetFilter(Const AValue: String);
Begin
  Inherited SetFilter(AValue);

  If Filtered Then
  Begin
    BuildFilteredDataset(FMaster, FFilteredDataset, AValue);

    FFilteredDataset.Open;
  End
  Else If FFilteredDataset.Active Then
    FFilteredDataset.Close;

  frmEventsReviewer.MessageBus.BroadcastFilterChanged(Self, Self);
End;

Function TStarfixDatabaseProvider.Open: Boolean;
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

        // Retrieving results
        FMaster.Open;

        Result := True;
        FLoaded := True;

        // Let the Application know we're now ready for it
        If Assigned(FOnProviderReady) Then
          FOnProviderReady(Self);

        // Everything that must happen before the rest of the application
        // sees the provider as ready has now happened.
        frmEventsReviewer.MessageBus.BroadcastDataProviderReady(Self, Self);

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
Begin
  Result := False;

  If Ready Then
  Begin
    FMaster.Close;
    FMaster.Open;

    Result := True;

    // Let the Application know we're now ready for it
    If Assigned(FOnProviderReady) Then
      FOnProviderReady(Self);
  End;
End;

Function TStarfixDatabaseProvider.Close: Boolean;
Begin
  FLoaded := False;

  If FMaster.Active Then
    FMaster.Close;

  If qryVideosforTime.Active Then
    FMaster.Close;

  If FConnection.Connected Then
    FConnection.Close;

  Result := True;
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

Procedure TStarfixDatabaseProvider.ApplySettingsFrame(AFrame: TFrameMSSQLConnection);
Begin
  // Update Connection
  FDatabaseName := AFrame.Database;
  FServer := AFrame.Server;
  FPort := AFrame.Port;
  FUsername := AFrame.Username;
  FPassword := AFrame.Password;
End;


Function TStarfixDatabaseProvider.Title: String;
Begin
  If Ready Then
    Result := 'Fugro Starfix Database: Connected to ' + FDatabaseName
  Else
    Result := 'Fugro Starfix Database: Not connected';
End;

Procedure TStarfixDatabaseProvider.DoMasterAfterScroll(ADataSet: TDataSet);
Var
  sAnomalyNo: String;
  dtDateTime: TDateTime;
  dKP: Extended;
Begin
  If Ready And Assigned(FOnDataChanged) And Not FMaster.ControlsDisabled Then
  Begin
    sAnomalyNo := FMaster.FieldByName('Anomaly_No').AsString;
    dtDateTime := FMaster.FieldByName('Start_(UTC)').AsDateTime;
    dKP := FMaster.FieldByName('KP').AsExtended;

    FOnDataChanged(Self, sAnomalyNo, dtDateTime);

    frmEventsReviewer.MessageBus.BroadcastTime(Self, dtDateTime);
    frmEventsReviewer.MessageBus.BroadcastKP(Self, dKP);
  End;
End;

Procedure TStarfixDatabaseProvider.DoFilterAfterScroll(ADataSet: TDataSet);
Begin
  If FUpdatingFilteredDataset Then
    Exit;

  If Ready And FMaster.Active And FFilteredDataset.Active And Not ADataSet.ControlsDisabled Then
    FMaster.RecNo := FFilteredDataset.FieldByName(MASTER_RECNO_FIELD).AsInteger;
End;

Procedure TStarfixDatabaseProvider.DatasetAfterOpen(ADataSet: TDataSet);

  Procedure TrySetDisplayFormat(AField: TField; AFormat: String);
  Begin
    If AField Is TFloatField Then
      TFloatField(AField).DisplayFormat := AFormat;
  End;

Begin
  TrySetDisplayFormat(ADataSet.FieldByName('KP'), '0.000');
  TrySetDisplayFormat(ADataSet.FieldByName('Easting'), '0.00');
  TrySetDisplayFormat(ADataSet.FieldByName('Northing'), '0.00');
  TrySetDisplayFormat(ADataSet.FieldByName('Depth'), '0.00');
  TrySetDisplayFormat(ADataSet.FieldByName('Offset_(m)'), '0.00');
  TrySetDisplayFormat(ADataSet.FieldByName('Length_(m)'), '0.00');
  TrySetDisplayFormat(ADataSet.FieldByName('Width_(m)'), '0.00');
  TrySetDisplayFormat(ADataSet.FieldByName('Height_(m)'), '0.00');
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

Function TStarfixDatabaseProvider.DateTime: TDateTime;
Begin
  If Ready And (FMaster.Active) And (FMaster.RecordCount > 0) Then
    Result := FMaster.FieldByName('Start_(UTC)').AsDateTime
  Else
    Result := 0;
End;

Procedure TStarfixDatabaseProvider.DoReceiveTimeSeekMessage(AMessage: TIMMessage);
Var
  oMessage: TIMMessageTime;
  oKP: TField;
  dStartKP: Extended;
  dtThreshold: TDateTime;
Begin
  If Not (AMessage Is TIMMessageTime) Then
    Exit;

  If Ready And (FMaster.Active) And (FMaster.RecordCount > 0) Then
  Begin
    oMessage := TIMMessageTime(AMessage);

    // Are we being asked to jump to a potentially distant point on the video?
    If frmEventsReviewer.ExactTimeSeek Then
      dtThreshold := -1
    Else
      dtThreshold := 10 / SecsPerDay;

    oKP := FMaster.FieldByName('KP');
    dStartKP := oKP.AsExtended;

    If GotoNearestTime(FMaster, 'Start_(UTC)', oMessage.DateTime, dtThreshold) Then
    Begin
      // The above suppressed OnAfterScroll, so we need to manually raise
      DoMasterAfterScroll(FMaster);
    End;

    If Filtered Then
    Begin
      FUpdatingFilteredDataset := True;
      Try
        GotoNearestTime(FFilteredDataset, 'Start_(UTC)', oMessage.DateTime, dtThreshold);
      Finally
        FUpdatingFilteredDataset := False;
      End;
    End;

    If (abs(dStartKP - oKP.AsExtended) > 0.001) Then
      frmEventsReviewer.MessageBus.BroadcastKP(Self, oKP.AsExtended);
  End;
End;

Function TStarfixDatabaseProvider.AnomalyReference: String;
Begin
  If (FMaster.Active) And (FMaster.RecordCount > 0) Then
    Result := FMaster.FieldByName('Anomaly_No').AsString
  Else
    Result := '';
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
