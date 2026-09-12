Unit DatabaseProvider;

{$mode ObjFPC}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}

Interface

Uses
  Classes, SysUtils, DataProvider, MediaTypes, Inifiles, mssqlconn, sqldb, dblib, DB, ExtCtrls;

Type

  { TDatabaseProvider }

  TDatabaseProvider = Class(TDataProvider)
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
    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;

    Procedure LoadSettings(AInifile: TIniFile); Override;
    Procedure SaveSettings(AInifile: TIniFile); Override;
  End;

Implementation

Uses
  FormMain, DialogMSSQLConnection, ThirdPartySupport, Dialogs, Controls, Forms;

  { TDatabaseProvider }

Constructor TDatabaseProvider.Create;
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
  qryAnomalies.SQL.Add('       DATEADD(S, E.TIMEDATE, ''1970-01-01'') As [DATETIME], ');
  qryAnomalies.SQL.Add('       E.[KP],                       ');
  qryAnomalies.SQL.Add('       E.[Type],                     ');
  qryAnomalies.SQL.Add('       E.[Anomaly_No],               ');
  qryAnomalies.SQL.Add('       E.Length As [Length_(m)],     ');
  qryAnomalies.SQL.Add('       E.Width As [Width_(m)],       ');
  qryAnomalies.SQL.Add('       E.Height As [Height_(m)],     ');
  qryAnomalies.SQL.Add('       E.Observed_Offset As [Offset_(m)],  ');
  qryAnomalies.SQL.Add('       E.[Clock],                    ');
  qryAnomalies.SQL.Add('       E.Comment As [Description]    ');
  qryAnomalies.SQL.Add('FROM dbo.Event_3 E       ');
  qryAnomalies.SQL.Add('WHERE E.ANOMALY=''1''    ');
  qryAnomalies.SQL.Add('ORDER BY [KP] Asc        ');

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

Destructor TDatabaseProvider.Destroy;
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

Function TDatabaseProvider.GetAnomalyDataSet: TDataSet;
Begin
  Result := qryAnomalies;
End;

Function TDatabaseProvider.GetReady: Boolean;
Begin
  Result := FConnection.Connected;
End;

Function TDatabaseProvider.Open: Boolean;
Var
  oDlg: TdlgMSSQLConnection;
  bDoConnection: Boolean;
Begin
  Result := False;
  If MSSQL.Available Then
  Begin
    oDlg := TdlgMSSQLConnection.Create(MainForm);
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
End;

Procedure TDatabaseProvider.DoAnomalyScrollTimer(Sender: TObject);
Var
  sAnomalyNo: String;
  dtDateTime: Double;
Begin
  tmrLoadAnomalyMedia.Enabled := False;

  If Ready And Assigned(FOnAnomalyChanged) Then
  Begin
    sAnomalyNo := qryAnomalies.FieldByName('Anomaly_No').AsString;
    dtDateTime := qryAnomalies.FieldByName('DATETIME').AsFloat;
    FOnAnomalyChanged(Self, sAnomalyNo, dtDateTime);
  End;
End;

Procedure TDatabaseProvider.qryAnomaliesAfterScroll(DataSet: TDataSet);
Begin
  // Restart the one-shot debounce timer
  tmrLoadAnomalyMedia.Enabled := False;
  tmrLoadAnomalyMedia.Enabled := True;
End;

Procedure TDatabaseProvider.qryAnomaliesAfterOpen(DataSet: TDataSet);
Begin
  With TFloatField(qryAnomalies.FieldByName('KP')) Do
  Begin
    DisplayFormat := '0.000';
    DisplayWidth := 7;
  End;
End;

Function TDatabaseProvider.GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
Var
  oVideoFile: TVideoFile;
Begin
  Result := TVideoFiles.Create;

  // Find the target videos
  If qryVideosforTime.Active Then
    qryVideosforTime.Close;

  // Split for testing purposes
  qryVideosforTime.ParamByName('TIMEDATE_ID').AsDateTime := ADateTime;
  qryVideosforTime.Open;

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

Procedure TDatabaseProvider.LoadSettings(AInifile: TIniFile);
Begin
  // Connection
  FDatabaseName := AInifile.ReadString('Database', 'DatabaseName', '');
  FServer := AInifile.ReadString('Database', 'Server', '');
  FUsername := AInifile.ReadString('Database', 'Username', '');
  FPassword := AInifile.ReadString('Database', 'Password', '');
  FPort := AInifile.ReadInteger('Database', 'Port', 1433);
End;

Procedure TDatabaseProvider.SaveSettings(AInifile: TIniFile);
Begin
  // Connection
  AInifile.WriteString('Database', 'DatabaseName', FDatabaseName);
  AInifile.WriteString('Database', 'Server', FServer);
  AInifile.WriteString('Database', 'Username', FUsername);
  AInifile.WriteString('Database', 'Password', FPassword);
  AInifile.WriteInteger('Database', 'Port', FPort);
End;

End.
