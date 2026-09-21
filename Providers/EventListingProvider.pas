Unit EventListingProvider;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, DataProvider, MediaTypes, Inifiles, DB, ExtCtrls, DBSupport,
  BufDataset, fpspreadsheet, xlsxOOXML, FrameEventListingSettings, IMMessaging, AppMessaging;

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
    FMaster: TMemTable;
    FFilteredDataset: TBufDataset;
    FUpdatingFilteredDataset: Boolean;
    FUpdatingMasterDataset: Boolean;

    Procedure DatasetAfterOpen(ADataSet: TDataSet);
    Function RowIsEmpty(ARow: Integer): Boolean;

    Procedure CreateFields;
    Procedure LoadEvents;

    Procedure DoMasterAfterScroll(ADataSet: TDataSet);
    Procedure DoFilterAfterScroll(ADataSet: TDataSet);
  Protected
    Function GetDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;

    Function GetFilteredDataSet: TDataSet; Override;
    Procedure SetFilter(Const AValue: String); Override;

    Procedure DoReceiveTimeSeekMessage(AMessage: TIMMessage);
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
  fpsTypes, SpreadsheetSupport, LazLogger, Dialogs, FormEventsReviewer;

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

  FMaster := TMemTable.Create;
  FMaster.Table.AfterScroll := @DoMasterAfterScroll;
  FMaster.Table.AfterOpen := @DatasetAfterOpen;
  FUpdatingMasterDataset := False;

  FFilteredDataset := TBufDataset.Create(nil);
  FFilteredDataset.AfterScroll := @DoFilterAfterScroll;
  FFilteredDataset.AfterOpen := @DatasetAfterOpen;
  FUpdatingFilteredDataset := False;


  // Messages
  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageTime, @DoReceiveTimeSeekMessage);
End;


Destructor TEventListingProvider.Destroy;
Begin
  FreeAndNil(FSpreadsheet);
  FreeAndNil(FMaster);
  FreeAndNil(FFilteredDataset);

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

    // Everything that must happen before the rest of the application
    // sees the provider as ready has now happened.
    frmEventsReviewer.MessageBus.BroadcastDataProviderReady(Self, Self);

    // We suppressed the first event being loaded, so broadcast it now manually
    DoMasterAfterScroll(FMaster.Table);
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

  FMaster.Close;
  FMaster.ClearAllRecords;

  Result := True;
End;

Function TEventListingProvider.GetDataSet: TDataSet;
Begin
  Result := FMaster.Table;
End;

Function TEventListingProvider.GetReady: Boolean;
Begin
  Result := FLoaded And Assigned(FMaster) And FMaster.Active;
End;

Function TEventListingProvider.GetFilteredDataSet: TDataSet;
Begin
  Result := FFilteredDataset;
End;

Procedure TEventListingProvider.SetFilter(Const AValue: String);
Begin
  Inherited SetFilter(AValue);

  If Filtered Then
  Begin
    BuildFilteredDataset(FMaster.Table, FFilteredDataset, AValue);

    FFilteredDataset.Open;
  End
  Else If FFilteredDataset.Active Then
    FFilteredDataset.Close;

  frmEventsReviewer.MessageBus.BroadcastFilterChanged(Self, Self);
End;


Function TEventListingProvider.DateTime: TDateTime;
Begin
  Result := FMaster['Start_(UTC)'].AsDateTime;
End;


Function TEventListingProvider.AnomalyReference: String;
Begin
  Result := FMaster['Anomaly_No'].AsString;
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
  FMaster.AddField('UNIQUE_ID', ftInteger);
  FMaster.AddField('Start_(UTC)', ftDateTime);
  FMaster.AddField('KP', ftFloat);
  FMaster.AddField('Type', ftString, 255);

  FMaster.AddField('Description', ftString, 2048);

  FMaster.AddField('Anomaly_No', ftString, 100);
  FMaster.AddField('Anomaly', ftString, 1);

  FMaster.AddField('Colour_ID', ftString, 100);

  FMaster.AddField('Length_(m)', ftFloat);
  FMaster.AddField('Width_(m)', ftFloat);
  FMaster.AddField('Height_(m)', ftFloat);
  FMaster.AddField('Offset_(m)', ftFloat);
  FMaster.AddField('Clock', ftString, 100);

  FMaster.AddField('Easting', ftFloat);
  FMaster.AddField('Northing', ftFloat);
  FMaster.AddField('Depth', ftFloat);
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
  FMaster.Close;
  FMaster.ClearAllRecords;
  CreateFields;

  If FWorksheet = nil Then
    Exit;

  dtOffset := FUTCOffset / HoursPerDay;

  FMaster.Open;
  FMaster.Table.DisableControls;
  Try
    // FStartRow is the HEADER row.
    For iRow := FStartRow + 1 To FWorksheet.GetLastRowIndex Do
    Begin
      If RowIsEmpty(iRow) Then
        Continue;

      FMaster.Table.Append;

      Try
        // Give offline events a stable ID within this import.
        FMaster['UNIQUE_ID'].AsInteger := iRow + 1;

        // Start = A + B
        If CellDateTime(FWorksheet, iRow, FStartCol + 0, dtDate) Then
        Begin
          dtStart := Trunc(dtDate);

          If CellDateTime(FWorksheet, iRow, FStartCol + 1, dtTime) Then
            dtStart := dtStart + Frac(dtTime);

          dtStart := Trunc(dtDate) + Frac(dtTime);

          // Event Listing time -> UTC
          dtStart := dtStart - dtOffset;

          FMaster['Start_(UTC)'].AsDateTime := dtStart;
        End;

        // KP = F
        If CellFloat(FWorksheet, iRow, FStartCol + 5, dValue) Then
          FMaster['KP'].AsFloat := dValue;

        // Type = C + '-' + D
        sType := CellText(FWorksheet, iRow, FStartCol + 2);
        sSubType := CellText(FWorksheet, iRow, FStartCol + 3);

        If (sType <> '') And (sSubType <> '') Then
          FMaster['Type'].AsString := sType + '-' + sSubType
        Else If sType <> '' Then
          FMaster['Type'].AsString := sType
        Else
          FMaster['Type'].AsString := sSubType;

        // Anomaly_No = Q
        sTemp := Trim(CellText(FWorksheet, iRow, FStartCol + 16));

        If sTemp <> '' Then
        Begin
          FMaster['Anomaly'].AsString := 'Y';
          FMaster['Colour_ID'].AsString := 'Red';
        End
        Else
        Begin
          FMaster['Anomaly'].AsString := 'N';
          FMaster['Colour_ID'].AsString := '';
        End;

        FMaster['Anomaly_No'].AsString := sTemp;

        // Dimensions = K, L, M
        If CellFloat(FWorksheet, iRow, FStartCol + 10, dValue) Then
          FMaster['Length_(m)'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 11, dValue) Then
          FMaster['Width_(m)'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 12, dValue) Then
          FMaster['Height_(m)'].AsFloat := dValue;

        // No Fugro Event Listing equivalent currently.
        FMaster['Offset_(m)'].Clear;

        // Clock = O
        FMaster['Clock'].AsString := CellText(FWorksheet, iRow, FStartCol + 14);

        // Description = R
        FMaster['Description'].AsString := CellText(FWorksheet, iRow, FStartCol + 17);

        // Position = H, I, J
        If CellFloat(FWorksheet, iRow, FStartCol + 7, dValue) Then
          FMaster['Easting'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 8, dValue) Then
          FMaster['Northing'].AsFloat := dValue;

        If CellFloat(FWorksheet, iRow, FStartCol + 9, dValue) Then
          FMaster['Depth'].AsFloat := dValue;

        FMaster.Table.Post;
      Except
        FMaster.Table.Cancel;
        Raise;
      End;
    End;
  Finally
    FMaster.Table.EnableControls;
  End;

  FMaster.Table.First;
End;

Procedure TEventListingProvider.DoMasterAfterScroll(ADataSet: TDataSet);
Var
  sAnomalyNo: String;
  dtDateTime: TDateTime;
  dKP: Extended;
Begin
  If Ready And Assigned(FOnDataChanged) And Not ADataSet.ControlsDisabled Then
  Begin
    sAnomalyNo := ADataSet.FieldByName('Anomaly_No').AsString;
    dtDateTime := ADataSet.FieldByName('Start_(UTC)').AsDateTime;
    dKP := ADataSet.FieldByName('KP').AsExtended;

    FOnDataChanged(Self, sAnomalyNo, dtDateTime);

    If Not FUpdatingMasterDataset Then
      frmEventsReviewer.MessageBus.BroadcastTime(Self, dtDateTime);

    frmEventsReviewer.MessageBus.BroadcastKP(Self, dKP);
  End;
End;

Procedure TEventListingProvider.DoFilterAfterScroll(ADataSet: TDataSet);
Begin
  If FUpdatingFilteredDataset Then
    Exit;

  If Ready And FMaster.Table.Active And FFilteredDataset.Active And Not
    ADataSet.ControlsDisabled Then
    FMaster.Table.RecNo := FFilteredDataset.FieldByName(MASTER_RECNO_FIELD).AsInteger;
End;

Procedure TEventListingProvider.DatasetAfterOpen(ADataSet: TDataSet);

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

Procedure TEventListingProvider.DoReceiveTimeSeekMessage(AMessage: TIMMessage);
Var
  oMessage: TIMMessageTime;
  oKP: TField;
  dStartKP: Extended;
  dtThreshold: TDateTime;
Begin
  If Not (AMessage Is TIMMessageTime) Then
    Exit;

  If Ready And (FMaster.Table.Active) And (FMaster.Table.RecordCount > 0) Then
  Begin
    oMessage := TIMMessageTime(AMessage);

    // Are we being asked to jump to a potentially distant point on the video?
    If frmEventsReviewer.ExactTimeSeek Then
      dtThreshold := -1
    Else
      dtThreshold := 10 / SecsPerDay;

    oKP := FMaster.Table.FieldByName('KP');
    dStartKP := oKP.AsExtended;

    FUpdatingMasterDataset := True;
    Try
      If GotoNearestTime(FMaster.Table, 'Start_(UTC)', oMessage.DateTime, dtThreshold) Then
      Begin
        // The above suppressed OnAfterScroll, so we need to manually raise
        DoMasterAfterScroll(FMaster.Table);
      End;
    Finally
      FUpdatingMasterDataset := False;
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

End.
