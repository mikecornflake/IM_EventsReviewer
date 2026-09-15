Unit StarfixDatabaseProvider;

{$mode ObjFPC}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}

Interface

Uses
  Classes, SysUtils, DataProvider, MediaTypes, Inifiles, mssqlconn, sqldb, dblib, DB, ExtCtrls,
  MSSQLSupport;

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
    tmrLoadAnomalyMedia: TTimer;
    qryAnomalies: TSQLQuery;
    qryVideosforTime: TSQLQuery;

    Procedure DoAnomalyScrollTimer(Sender: TObject);
    Procedure qryAnomaliesAfterOpen(DataSet: TDataSet);
    Procedure qryAnomaliesAfterScroll(DataSet: TDataSet);
  Protected
    Function GetAnomalyDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;
  Public
    Constructor Create;
    Destructor Destroy; Override;

    Function Open: Boolean; Override;
    Function Title: String; Override;

    Procedure ApplySettingsFrame(AFrame: TFrameMSSQLConnection);
    Procedure PopulateSettingsFrame(AFrame: TFrameMSSQLConnection);

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;
    Function AnomalyDateTime: TDateTime; Override;
    Function AnomalyReference: String;

    Procedure LoadSettings(AInifile: TIniFile); Override;
    Procedure SaveSettings(AInifile: TIniFile); Override;
  End;

Implementation

Uses
  FormMain, ThirdPartySupport, Dialogs, Controls, Forms, LazLogger;

  { TStarfixDatabaseProvider }

Constructor TStarfixDatabaseProvider.Create;
Begin
  FConnection := TMSSQLConnection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);

  FConnection.Transaction := FTransaction;

  qryAnomalies := TSQLQuery.Create(nil);
  qryAnomalies.Database := FConnection;
  qryAnomalies.Transaction := FTransaction;
  qryAnomalies.AfterScroll := @qryAnomaliesAfterScroll;
  qryAnomalies.AfterOpen := @qryAnomaliesAfterOpen;
  qryAnomalies.SQL.Add('SELECT E.[UNIQUE_ID],  ');
  qryAnomalies.SQL.Add('       DATEADD(S, E.TIMEDATE, ''1970-01-01'') As [Start], ');
  qryAnomalies.SQL.Add('       E.[KP],                       ');
  qryAnomalies.SQL.Add('       E.[Type],                     ');
  qryAnomalies.SQL.Add('       E.[Anomaly_No],               ');
  qryAnomalies.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Length) As [Length_(m)], ');
  qryAnomalies.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Width) As [Width_(m)],   ');
  qryAnomalies.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Height) As [Height_(m)], ');
  qryAnomalies.SQL.Add('       E.Observed_Offset As [Offset_(m)],  ');
  qryAnomalies.SQL.Add('       E.[Clock],                    ');
  qryAnomalies.SQL.Add('       E.Comment As [Description],   ');
  qryAnomalies.SQL.Add('       E.East As [Easting],          ');
  qryAnomalies.SQL.Add('       E.North As [Northing],        ');
  qryAnomalies.SQL.Add('       E.[Depth]                     ');
  qryAnomalies.SQL.Add('FROM dbo.Event_3 E                   ');
  qryAnomalies.SQL.Add('INNER JOIN dbo.SESSIONS S ON (S.START_TIME <= E.TIMEDATE    ');
  qryAnomalies.SQL.Add('                              AND S.END_TIME >= E.TIMEDATE) ');
  qryAnomalies.SQL.Add('WHERE E.ANOMALY=''1''                ');
  qryAnomalies.SQL.Add(' AND (E.PROC_FLAGS & 512)<>512       ');
  qryAnomalies.SQL.Add('ORDER BY [KP] Asc                    ');

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

  tmrLoadAnomalyMedia := TTimer.Create(nil);
  tmrLoadAnomalyMedia.Enabled := False;
  tmrLoadAnomalyMedia.Interval := 300;
  tmrLoadAnomalyMedia.OnTimer := @DoAnomalyScrollTimer;

  // Fetch complete result set.
  // Required when other queries on the same connection may be opened
  // from dataset events such as AfterScroll.
  // Without this, FreeTDS may report
  //    "adaptive server operation with results pending".
  qryAnomalies.PacketRecords := -1;
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
  FOnAnomalyChanged := nil;
End;

Destructor TStarfixDatabaseProvider.Destroy;
Begin
  tmrLoadAnomalyMedia.Enabled := False;

  If FConnection.Connected Then
    FConnection.Connected := False;

  FreeAndNil(tmrLoadAnomalyMedia);
  FreeAndNil(qryVideosforTime);
  FreeAndNil(qryAnomalies);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);

  Inherited Destroy;
End;

Function TStarfixDatabaseProvider.GetAnomalyDataSet: TDataSet;
Begin
  Result := qryAnomalies;
End;

Function TStarfixDatabaseProvider.GetReady: Boolean;
Begin
  Result := FConnection.Connected;
End;

Function TStarfixDatabaseProvider.Open: Boolean;
Begin
  Result := False;
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

        // Retrieving anomaly results
        qryAnomalies.Open;

        // Let the Application know we're now ready for it
        If Assigned(FOnProviderReady) Then
          FOnProviderReady(Self);
      Except
        On E: Exception Do
          ShowMessage(E.Message);
      End;
    Finally
      MainForm.Busy := False;
    End;
  End;
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
    Result := 'Connected to ' + FDatabaseName
  Else
    Result := 'Not connected';
End;

Procedure TStarfixDatabaseProvider.DoAnomalyScrollTimer(Sender: TObject);
Var
  sAnomalyNo: String;
  dtDateTime: Double;
Begin
  tmrLoadAnomalyMedia.Enabled := False;

  If Ready And Assigned(FOnAnomalyChanged) Then
  Begin
    sAnomalyNo := qryAnomalies.FieldByName('Anomaly_No').AsString;
    dtDateTime := qryAnomalies.FieldByName('Start').AsDateTime;
    FOnAnomalyChanged(Self, sAnomalyNo, dtDateTime);
  End;
End;

Procedure TStarfixDatabaseProvider.qryAnomaliesAfterScroll(DataSet: TDataSet);
Begin
  // Restart the one-shot debounce timer
  tmrLoadAnomalyMedia.Enabled := False;
  tmrLoadAnomalyMedia.Enabled := True;
End;

Procedure TStarfixDatabaseProvider.qryAnomaliesAfterOpen(DataSet: TDataSet);

  Procedure TrySetDisplayFormat(AField: TField; AFormat: String);
  Begin
    If AField Is TFloatField Then
      TFloatField(AField).DisplayFormat := AFormat;
  End;

Begin
  TrySetDisplayFormat(qryAnomalies.FieldByName('KP'), '0.000');
  TrySetDisplayFormat(qryAnomalies.FieldByName('Easting'), '0.00');
  TrySetDisplayFormat(qryAnomalies.FieldByName('Northing'), '0.00');
  TrySetDisplayFormat(qryAnomalies.FieldByName('Depth'), '0.00');
  TrySetDisplayFormat(qryAnomalies.FieldByName('Offset_(m)'), '0.00');
  TrySetDisplayFormat(qryAnomalies.FieldByName('Length_(m)'), '0.00');
  TrySetDisplayFormat(qryAnomalies.FieldByName('Width_(m)'), '0.00');
  TrySetDisplayFormat(qryAnomalies.FieldByName('Height_(m)'), '0.00');
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
    oVideoFile.EndDateTime := qryVideosforTime.FieldByName('Start').AsDateTime;

    Result.Add(oVideoFile);

    qryVideosforTime.Next;
  End;
End;

Function TStarfixDatabaseProvider.AnomalyDateTime: TDateTime;
Begin
  If (qryAnomalies.Active) And (qryAnomalies.RecordCount > 0) Then
    Result := qryAnomalies.FieldByName('Start').AsDateTime
  Else
    Result := 0;
End;

Function TStarfixDatabaseProvider.AnomalyReference: String;
Begin
  If (qryAnomalies.Active) And (qryAnomalies.RecordCount > 0) Then
    Result := qryAnomalies.FieldByName('Anomaly_No').AsString
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
