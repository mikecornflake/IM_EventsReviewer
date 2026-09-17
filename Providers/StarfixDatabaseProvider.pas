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
    qryData: TSQLQuery;
    qryVideosforTime: TSQLQuery;

    Procedure qryDataAfterOpen(ADataSet: TDataSet);
    Procedure qryDataAfterScroll(ADataSet: TDataSet);
  Protected
    Function GetDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;
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
  FormMain, ThirdPartySupport, Dialogs, Controls, Forms, LazLogger;

  { TStarfixDatabaseProvider }

Constructor TStarfixDatabaseProvider.Create;
Begin
  Inherited Create;

  FLoaded := False;

  FConnection := TMSSQLConnection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);

  FConnection.Transaction := FTransaction;

  qryData := TSQLQuery.Create(nil);
  qryData.Database := FConnection;
  qryData.Transaction := FTransaction;
  qryData.AfterScroll := @qryDataAfterScroll;
  qryData.AfterOpen := @qryDataAfterOpen;
  qryData.SQL.Add('SELECT E.[UNIQUE_ID],  ');
  qryData.SQL.Add('       DATEADD(S, E.TIMEDATE, ''1970-01-01'') As [Start_(UTC)], ');
  qryData.SQL.Add('       E.[KP],                       ');
  qryData.SQL.Add('       E.[Type],                     ');
  qryData.SQL.Add('       E.[Anomaly_No],               ');
  qryData.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Length) As [Length_(m)], ');
  qryData.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Width) As [Width_(m)],   ');
  qryData.SQL.Add('       TRY_CONVERT(decimal(18,3), E.Height) As [Height_(m)], ');
  qryData.SQL.Add('       E.Observed_Offset As [Offset_(m)],  ');
  qryData.SQL.Add('       E.[Clock],                    ');
  qryData.SQL.Add('       E.Comment As [Description],   ');
  qryData.SQL.Add('       E.East As [Easting],          ');
  qryData.SQL.Add('       E.North As [Northing],        ');
  qryData.SQL.Add('       E.[Depth]                     ');
  qryData.SQL.Add('FROM dbo.Event_3 E                   ');
  qryData.SQL.Add('INNER JOIN dbo.SESSIONS S ON (S.START_TIME <= E.TIMEDATE    ');
  qryData.SQL.Add('                              AND S.END_TIME >= E.TIMEDATE) ');
  qryData.SQL.Add('WHERE (E.PROC_FLAGS & 512)<>512      ');
  qryData.SQL.Add('ORDER BY [KP] Asc                    ');

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
  qryData.PacketRecords := -1;
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
End;

Destructor TStarfixDatabaseProvider.Destroy;
Begin
  If FConnection.Connected Then
    FConnection.Connected := False;

  FreeAndNil(qryVideosforTime);
  FreeAndNil(qryData);
  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);

  Inherited Destroy;
End;

Function TStarfixDatabaseProvider.GetDataSet: TDataSet;
Begin
  Result := qryData;
End;

Function TStarfixDatabaseProvider.GetReady: Boolean;
Begin
  Result := FLoaded And FConnection.Connected;
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
        qryData.Open;

        Result := True;
        FLoaded := True;

        // Let the Application know we're now ready for it
        If Assigned(FOnProviderReady) Then
          FOnProviderReady(Self);

        // We suppressed the first event being loaded, so broadcast it now manually
        qryDataAfterScroll(qryData);
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
    qryData.Close;
    qryData.Open;

    Result := True;

    // Let the Application know we're now ready for it
    If Assigned(FOnProviderReady) Then
      FOnProviderReady(Self);
  End;
End;

Function TStarfixDatabaseProvider.Close: Boolean;
Begin
  FLoaded := False;

  If qryData.Active Then
    qryData.Close;

  If qryVideosforTime.Active Then
    qryData.Close;

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

Procedure TStarfixDatabaseProvider.qryDataAfterScroll(ADataSet: TDataSet);
Var
  sAnomalyNo: String;
  dtDateTime: TDateTime;
Begin
  If Ready And Assigned(FOnDataChanged) And Not qryData.ControlsDisabled Then
  Begin
    sAnomalyNo := qryData.FieldByName('Anomaly_No').AsString;
    dtDateTime := qryData.FieldByName('Start_(UTC)').AsDateTime;
    FOnDataChanged(Self, sAnomalyNo, dtDateTime);
  End;
End;

Procedure TStarfixDatabaseProvider.qryDataAfterOpen(ADataSet: TDataSet);

  Procedure TrySetDisplayFormat(AField: TField; AFormat: String);
  Begin
    If AField Is TFloatField Then
      TFloatField(AField).DisplayFormat := AFormat;
  End;

Begin
  TrySetDisplayFormat(qryData.FieldByName('KP'), '0.000');
  TrySetDisplayFormat(qryData.FieldByName('Easting'), '0.00');
  TrySetDisplayFormat(qryData.FieldByName('Northing'), '0.00');
  TrySetDisplayFormat(qryData.FieldByName('Depth'), '0.00');
  TrySetDisplayFormat(qryData.FieldByName('Offset_(m)'), '0.00');
  TrySetDisplayFormat(qryData.FieldByName('Length_(m)'), '0.00');
  TrySetDisplayFormat(qryData.FieldByName('Width_(m)'), '0.00');
  TrySetDisplayFormat(qryData.FieldByName('Height_(m)'), '0.00');
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
  If (qryData.Active) And (qryData.RecordCount > 0) Then
    Result := qryData.FieldByName('Start_(UTC)').AsDateTime
  Else
    Result := 0;
End;

Function TStarfixDatabaseProvider.AnomalyReference: String;
Begin
  If (qryData.Active) And (qryData.RecordCount > 0) Then
    Result := qryData.FieldByName('Anomaly_No').AsString
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
