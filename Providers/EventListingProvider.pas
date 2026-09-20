Unit EventListingProvider;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, DataProvider, MediaTypes, Inifiles, DB, ExtCtrls, DBSupport,
  BufDataset, fpspreadsheet, xlsxOOXML, FrameEventListingSettings;

Type

  { TEventListingProvider }

  TEventListingProvider = Class(TDataProvider)
  Private
    // Settings
    FFileName: String;
    FWorksheetName: String;
    FStartCol: Integer;
    FStartRow: Integer;
    FUTCOffset: Double;

    // FPSreadsheet controls
    FSpreadsheet: TsWorkbook;
    FWorksheet: TsWorksheet;

    // Dataset
    FEvents: TMemTable;

    Function RowIsEmpty(ARow: Integer): Boolean;

    Procedure CreateFields;
    Procedure LoadEvents;

    Procedure DoEventsAfterScroll(ADataSet: TDataSet);
  Protected
    Function GetDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;

    Procedure DoReceiveTimeSeekMessage(Sender: TObject);
  Public
    Constructor Create;
    Destructor Destroy; Override;

    Function Open: Boolean; Override;
    Function Refresh: Boolean; Override;
    Function Close: Boolean; Override;

    Function Title: String; Override;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;
    Function DateTime: TDateTime; Override;
    Function AnomalyReference: String; Override;

    Procedure ApplySettingsFrame(AFrame: TFrameEventListingSettings);
    Procedure PopulateSettingsFrame(AFrame: TFrameEventListingSettings);

    Procedure LoadSettings(AIniFile: TIniFile); Override;
    Procedure SaveSettings(AIniFile: TIniFile); Override;
  End;

Implementation

Uses
  fpsTypes, SpreadsheetSupport, LazLogger, Dialogs, NavigationController,
  FormEventsReviewer;

  { TEventListingProvider }

Constructor TEventListingProvider.Create;
Begin
  Inherited Create;

  FLoaded := False;

  FSpreadsheet := nil;
  FWorksheet := nil;

  FStartCol := 0;   // Column A
  FStartRow := 0;   // Row 1

  FUTCOffset := 1;

  FEvents := TMemTable.Create;

  FEvents.Table.AfterScroll := @DoEventsAfterScroll;

  // Messages
  frmEventsReviewer.Messenger.Register(Self, TIMMessageTime, @DoReceiveTimeSeekMessage);
End;


Destructor TEventListingProvider.Destroy;
Begin
  FreeAndNil(FSpreadsheet);
  FreeAndNil(FEvents);

  Inherited Destroy;
End;

Function TEventListingProvider.Open: Boolean;
Var
  sMessage: String;
Begin
  FLoaded := False;
  Result := False;

  If Not FileExists(FFileName) Then
  Begin
    sMessage := 'Event Listing filename ' + FFileName + ' does not exist';
    DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}, ' ', sMessage]);
    ShowMessage(sMessage);

    Exit;
  End;

  FreeAndNil(FSpreadsheet);
  FWorksheet := nil;

  FSpreadsheet := TsWorkbook.Create;

  Try
    FSpreadsheet.ReadFromFile(FFileName, sfOOXML);

    FWorksheet := FSpreadsheet.GetWorksheetByName(FWorksheetName);

    If FWorksheet = nil Then
      Raise Exception.Create('Worksheet "Event Header" was not found in:' +
        LineEnding + FFileName);

    LoadEvents;

    Result := True;
    FLoaded := True;

    // Let the Application know we're now ready for it
    If Assigned(FOnProviderReady) Then
      FOnProviderReady(Self);

    // New fangled messaging marlarky :-)
    frmEventsReviewer.Messenger.BroadcastDataProviderReady(Self, Self);

    // We suppressed the first event being loaded, so broadcast it now manually
    DoEventsAfterScroll(FEvents.Table);
  Except
    FreeAndNil(FSpreadsheet);
    FWorksheet := nil;
    Raise;
  End;
End;

Function TEventListingProvider.Refresh: Boolean;
Begin
  Result := Open;
End;

Function TEventListingProvider.Close: Boolean;
Begin
  FLoaded := False;

  FreeAndNil(FSpreadsheet);
  FWorksheet := nil;

  FEvents.Close;
  FEvents.ClearAllRecords;

  Result := True;
End;

Function TEventListingProvider.GetDataSet: TDataSet;
Begin
  Result := FEvents.Table;
End;


Function TEventListingProvider.GetReady: Boolean;
Begin
  Result := FLoaded And Assigned(FEvents) And FEvents.Active;
End;


Function TEventListingProvider.DateTime: TDateTime;
Begin
  Result := FEvents['Start_(UTC)'].AsDateTime;
End;


Function TEventListingProvider.AnomalyReference: String;
Begin
  Result := FEvents['Anomaly_No'].AsString;
End;

Procedure TEventListingProvider.ApplySettingsFrame(AFrame: TFrameEventListingSettings);
Begin
  FFileName := AFrame.Filename;
  FWorksheetName := AFrame.Worksheet;
  FStartCol := AFrame.StartCol;
  FStartRow := AFrame.StartRow;
  FUTCOffset := AFrame.UTC_Offset;
End;

Procedure TEventListingProvider.PopulateSettingsFrame(AFrame: TFrameEventListingSettings);
Begin
  AFrame.Filename := FFileName;
  AFrame.Worksheet := FWorksheetName;
  AFrame.StartCol := FStartCol;
  AFrame.StartRow := FStartRow;
  AFrame.UTC_Offset := FUTCOffset;
End;

Procedure TEventListingProvider.LoadSettings(AIniFile: TIniFile);
Begin
  FFileName := AIniFile.ReadString('EventListing', 'Filename', '');
  FWorksheetName := AIniFile.ReadString('EventListing', 'Worksheet', '');
  FStartCol := AIniFile.ReadInteger('EventListing', 'StartCol', 0);
  FStartRow := AIniFile.ReadInteger('EventListing', 'StartRow', 0);
  FUTCOffset := AIniFile.ReadFloat('EventListing', 'UTCOffset', 1);
End;

Procedure TEventListingProvider.SaveSettings(AIniFile: TIniFile);
Begin
  AIniFile.WriteString('EventListing', 'Filename', FFileName);
  AIniFile.WriteString('EventListing', 'Worksheet', FWorksheetName);
  AIniFile.WriteInteger('EventListing', 'StartCol', FStartCol);
  AIniFile.WriteInteger('EventListing', 'StartRow', FStartRow);
  AIniFile.WriteFloat('EventListing', 'UTCOffset', FUTCOffset);
End;

Function TEventListingProvider.Title: String;
Begin
  Result := 'Fugro Event Listing';

  If Ready And (FFileName <> '') Then
    Result += ': ' + ExtractFilename(FFileName);
End;

Function TEventListingProvider.GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
Begin
  Result := nil;
End;

Procedure TEventListingProvider.CreateFields;
Begin
  FEvents.AddField('UNIQUE_ID', ftInteger);
  FEvents.AddField('Start_(UTC)', ftDateTime);
  FEvents.AddField('KP', ftFloat);
  FEvents.AddField('Type', ftString, 255);

  FEvents.AddField('Anomaly_No', ftString, 100);
  FEvents.AddField('Anomaly', ftString, 1);
  FEvents.AddField('Colour_ID', ftString, 100);


  FEvents.AddField('Length_(m)', ftFloat);
  FEvents.AddField('Width_(m)', ftFloat);
  FEvents.AddField('Height_(m)', ftFloat);
  FEvents.AddField('Offset_(m)', ftFloat);

  FEvents.AddField('Clock', ftString, 100);
  FEvents.AddField('Description', ftString, 2048);

  FEvents.AddField('Easting', ftFloat);
  FEvents.AddField('Northing', ftFloat);
  FEvents.AddField('Depth', ftFloat);
End;

Function TEventListingProvider.RowIsEmpty(ARow: Integer): Boolean;
Begin
  Result :=
    (CellText(FWorksheet, ARow, FStartCol + 0) = '') And
    (CellText(FWorksheet, ARow, FStartCol + 1) = '') And
    (CellText(FWorksheet, ARow, FStartCol + 2) = '') And
    (CellText(FWorksheet, ARow, FStartCol + 16) = '');
End;

Procedure TEventListingProvider.LoadEvents;
Var
  iRow: Integer;

  dtDate, dtTime, dtStart, dtOffset: TDateTime;

  dValue: Double;

  sType: String;
  sSubType, sTemp: String;
Begin
  FEvents.Close;
  FEvents.ClearAllRecords;
  CreateFields;

  If FWorksheet = nil Then
    Exit;

  dtOffset := FUTCOffset / HoursPerDay;

  FEvents.Open;
  FEvents.Table.DisableControls;
  Try
    // FStartRow is the HEADER row.
    For iRow := FStartRow + 1 To FWorksheet.GetLastRowIndex Do
    Begin
      If RowIsEmpty(iRow) Then
        Continue;

      FEvents.Table.Append;

      Try
        // Give offline events a stable ID within this import.
        FEvents['UNIQUE_ID'].AsInteger := iRow + 1;

        // Start = A + B
        If CellDateTime(FWorksheet, iRow, FStartCol + 0, dtDate) Then
        Begin
          dtStart := Trunc(dtDate);

          If CellDateTime(FWorksheet, iRow, FStartCol + 1, dtTime) Then
            dtStart := dtStart + Frac(dtTime);

          dtStart := Trunc(dtDate) + Frac(dtTime);

          // Event Listing time -> UTC
          dtStart := dtStart - dtOffset;

          FEvents['Start_(UTC)'].AsDateTime := dtStart;
        End;

        // KP = F
        If CellFloat(FWorksheet, iRow, FStartCol + 5, dValue) Then
          FEvents['KP'].AsFloat := dValue;

        // Type = C + '-' + D
        sType := CellText(FWorksheet, iRow, FStartCol + 2);
        sSubType := CellText(FWorksheet, iRow, FStartCol + 3);

        If (sType <> '') And (sSubType <> '') Then
          FEvents['Type'].AsString := sType + '-' + sSubType
        Else If sType <> '' Then
          FEvents['Type'].AsString := sType
        Else
          FEvents['Type'].AsString := sSubType;

        // Anomaly_No = Q
        sTemp := Trim(CellText(FWorksheet, iRow, FStartCol + 16));

        If sTemp <> '' Then
        Begin
          FEvents['Anomaly'].AsString := 'Y';
          FEvents['Colour_ID'].AsString := 'Red';
        End
        Else
        Begin
          FEvents['Anomaly'].AsString := 'N';
          FEvents['Colour_ID'].AsString := '';
        End;

        FEvents['Anomaly_No'].AsString := sTemp;

        // Dimensions = K, L, M
        If CellFloat(FWorksheet, iRow, FStartCol + 10, dValue) Then
          FEvents['Length_(m)'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 11, dValue) Then
          FEvents['Width_(m)'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 12, dValue) Then
          FEvents['Height_(m)'].AsFloat := dValue;

        // No Fugro Event Listing equivalent currently.
        FEvents['Offset_(m)'].Clear;

        // Clock = O
        FEvents['Clock'].AsString := CellText(FWorksheet, iRow, FStartCol + 14);

        // Description = R
        FEvents['Description'].AsString := CellText(FWorksheet, iRow, FStartCol + 17);

        // Position = H, I, J
        If CellFloat(FWorksheet, iRow, FStartCol + 7, dValue) Then
          FEvents['Easting'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 8, dValue) Then
          FEvents['Northing'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 9, dValue) Then
          FEvents['Depth'].AsFloat := dValue;

        FEvents.Table.Post;
      Except
        FEvents.Table.Cancel;
        Raise;
      End;
    End;
  Finally
    FEvents.Table.EnableControls;
  End;

  FEvents.Table.First;
End;

Procedure TEventListingProvider.DoEventsAfterScroll(ADataSet: TDataSet);
Var
  sAnomalyNo: String;
  dtDateTime: TDateTime;
  dKP: Extended;
Begin
  If Ready And Assigned(FOnDataChanged) And Not FEvents.Table.ControlsDisabled Then
  Begin
    sAnomalyNo := FEvents['Anomaly_No'].AsString;
    dtDateTime := FEvents['Start_(UTC)'].AsDateTime;
    dKP := FEvents['KP'].AsExtended;

    FOnDataChanged(Self, sAnomalyNo, dtDateTime);

    frmEventsReviewer.Messenger.BroadcastTime(Self, dtDateTime);
    frmEventsReviewer.Messenger.BroadcastKP(Self, dKP);
  End;
End;

Procedure TEventListingProvider.DoReceiveTimeSeekMessage(Sender: TObject);
Var
  oMessage: TIMMessageTime;
  oKP: TField;
  dStartKP: Extended;
  dtThreshold: TDateTime;
Begin
  If Not (Sender Is TIMMessageTime) Then
    Exit;

  If Ready And (FEvents.Table.Active) And (FEvents.Table.RecordCount > 0) Then
  Begin
    oMessage := TIMMessageTime(Sender);

    // Are we being asked to jump to a potentially distant point on the video?
    If frmEventsReviewer.ExactTimeSeek Then
      dtThreshold := -1
    Else
      dtThreshold := 10 / SecsPerDay;

    oKP := FEvents.Table.FieldByName('KP');
    dStartKP := oKP.AsExtended;

    GotoNearestTime(FEvents.Table, 'Start_(UTC)', oMessage.DateTime, dtThreshold);

    If (abs(dStartKP - oKP.AsExtended) > 0.001) Then
      frmEventsReviewer.Messenger.BroadcastKP(Self, oKP.AsExtended);
  End;
End;

End.
