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

    Function RowIsEmpty(ARow: Integer): Boolean;
    Procedure CreateFields;
    Procedure LoadEvents;

  Protected
    Function GetDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;
  Public
    Constructor Create; Override;
    Destructor Destroy; Override;

    Function Open: Boolean; Override;
    Function Refresh: Boolean; Override;
    Function Close: Boolean; Override;

    Function Title: String; Override;

    Procedure ApplySettingsFrame(AFrame: TFrameEventListingSettings);
    Procedure PopulateSettingsFrame(AFrame: TFrameEventListingSettings);

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;

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
  FMaster.Table.AfterOpen := @DoDatasetAfterOpen;
  FUpdatingMasterDataset := False;
End;


Destructor TEventListingProvider.Destroy;
Begin
  FreeAndNil(FSpreadsheet);
  FreeAndNil(FMaster);

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
    frmEventsReviewer.MessageBus.Broadcast(Self, TIMMessageDataProviderReady);

    // We suppressed the first event being loaded, so broadcast it now manually
    DoMasterAfterScroll(FMaster.Table);
  Except
    FreeAndNil(FSpreadsheet);
    FWorksheet := nil;
    Raise;
  End;
End;

Function TEventListingProvider.Refresh: Boolean;
var
  dtCurrent: TDateTime;
Begin
  // Remember State
  dtCurrent := DateTime;

  Result := Open;

  // Try to restore State
  Self.GotoNearestValue(FFieldStartTime, dtCurrent, -1);
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

Function TEventListingProvider.Title: String;
Begin
  Result := 'Fugro Event Listing';

  If Ready And (FFileName <> '') Then
    Result += ': ' + ExtractFilename(FFileName);
End;

Procedure TEventListingProvider.CreateFields;
Begin
  FMaster.AddField('UNIQUE_ID', ftInteger);
  FMaster.AddField(FFieldStartTime, ftDateTime);
  FMaster.AddField(FFieldStartKP, ftFloat);
  FMaster.AddField('Type', ftString, 255);

  FMaster.AddField('Description', ftString, 2048);

  FMaster.AddField(FFieldAnomalyReference, ftString, 100);
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

          // Event Listing time -> UTC
          dtStart := dtStart - dtOffset;

          FMaster[FFieldStartTime].AsDateTime := dtStart;
        End;

        // KP = F
        If CellFloat(FWorksheet, iRow, FStartCol + 5, dValue) Then
          FMaster[FFieldStartKP].AsFloat := dValue;

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

        FMaster[FFieldAnomalyReference].AsString := sTemp;

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

Function TEventListingProvider.GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
Begin
  Result := nil;
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

End.
