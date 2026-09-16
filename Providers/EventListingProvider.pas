Unit EventListingProvider;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, DataProvider, MediaTypes, Inifiles, DB, ExtCtrls, DBSupport,
  BufDataset, fpspreadsheet, xlsxOOXML;

Type

  { TEventListingProvider }

  TEventListingProvider = Class(TDataProvider)
  Private
    // Settings
    FFileName: String;
    FStartCol: Integer;
    FStartRow: Integer;
    FUTCOffset: TDateTime;

    // FPSreadsheet controls
    FSpreadsheet: TsWorkbook;
    FWorksheet: TsWorksheet;

    FEvents: TMemTable;

    Function CellText(ARow, ACol: Integer): String;
    Function CellFloat(ARow, ACol: Integer; Out AValue: Double): Boolean;
    Function CellDateTime(ARow, ACol: Integer; Out AValue: TDateTime): Boolean;
    Function RowIsEmpty(ARow: Integer): Boolean;

    Procedure CreateFields;
    Procedure LoadEvents;

    Procedure DoEventsAfterScroll(DataSet: TDataSet);
  Protected
    Function GetAnomalyDataSet: TDataSet; Override;
    Function GetReady: Boolean; Override;

  Public
    Constructor Create;
    Destructor Destroy; Override;

    Function Open: Boolean; Override;
    Function Refresh: Boolean; Override;
    Function Title: String; Override;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Override;
    Function AnomalyDateTime: TDateTime; Override;
    Function AnomalyReference: String;

    Procedure LoadSettings(AIniFile: TIniFile); Override;
    Procedure SaveSettings(AIniFile: TIniFile); Override;
  End;

Implementation

Uses
  fpsTypes;

Const
  HOURS_TO_DATETIME = 1 / HoursPerDay;

  { TEventListingProvider }

Constructor TEventListingProvider.Create;
Begin
  Inherited Create;

  FSpreadsheet := nil;
  FWorksheet := nil;

  FStartCol := 0;   // Column A
  FStartRow := 0;   // Row 1

  FUTCOffset := 1 / HoursPerDay;

  FEvents := TMemTable.Create;

  FEvents.Table.AfterScroll := @DoEventsAfterScroll;
End;


Destructor TEventListingProvider.Destroy;
Begin
  FreeAndNil(FSpreadsheet);
  FreeAndNil(FEvents);

  Inherited Destroy;
End;

Function TEventListingProvider.Open: Boolean;
Begin
  Result := False;

  FreeAndNil(FSpreadsheet);
  FWorksheet := nil;

  FFileName :=
    'D:\Projects\2026 06 24 - Fugro Saipem\507464_28IN_TEESSIDE_As-Laid_Event Listing_KP21.0000 to KP30.0000_Rev03.xlsx';

  FSpreadsheet := TsWorkbook.Create;

  Try
    FSpreadsheet.ReadFromFile(FFileName, sfOOXML);

    FWorksheet := FSpreadsheet.GetWorksheetByName('Event Header');

    If FWorksheet = nil Then
      Raise Exception.Create('Worksheet "Event Header" was not found in:' +
        LineEnding + FFileName);

    LoadEvents;

    Result := True;

    // Let the Application know we're now ready for it
    If Assigned(FOnProviderReady) Then
      FOnProviderReady(Self);
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

Function TEventListingProvider.GetAnomalyDataSet: TDataSet;
Begin
  Result := FEvents.Table;
End;


Function TEventListingProvider.GetReady: Boolean;
Begin
  Result :=
    Assigned(FEvents) And FEvents.Active;
End;


Function TEventListingProvider.AnomalyDateTime: TDateTime;
Begin
  Result := FEvents['Start'].AsDateTime;
End;


Function TEventListingProvider.AnomalyReference: String;
Begin
  Result := FEvents['Anomaly_No'].AsString;
End;

Procedure TEventListingProvider.LoadSettings(AIniFile: TIniFile);
Begin

End;

Procedure TEventListingProvider.SaveSettings(AIniFile: TIniFile);
Begin

End;


Function TEventListingProvider.Title: String;
Begin
  Result := 'Fugro Event Listing';
End;

Function TEventListingProvider.GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
Begin
  Result := nil;
End;

Procedure TEventListingProvider.CreateFields;
Begin
  FEvents.AddField('UNIQUE_ID', ftInteger);
  FEvents.AddField('Start', ftDateTime);
  FEvents.AddField('KP', ftFloat);
  FEvents.AddField('Type', ftString, 255);
  FEvents.AddField('Anomaly_No', ftString, 100);

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

Function TEventListingProvider.CellText(ARow, ACol: Integer): String;
Begin
  Result := Trim(FWorksheet.ReadAsText(ARow, ACol));
End;


Function TEventListingProvider.CellFloat(ARow, ACol: Integer; Out AValue: Double): Boolean;
Var
  s: String;
Begin
  Result := False;
  AValue := 0;

  If FWorksheet = nil Then
    Exit;

  s := CellText(ARow, ACol);

  If s = '' Then
    Exit;

  // First try FPSpreadsheet's actual numeric value.
  Try
    AValue := FWorksheet.ReadAsNumber(ARow, ACol);
    Result := True;
  Except
    // Fall through to textual conversion.
  End;

  If Not Result Then
    Result := TryStrToFloat(s, AValue);
End;


Function TEventListingProvider.CellDateTime(ARow, ACol: Integer; Out AValue: TDateTime): Boolean;
Var
  s: String;
Begin
  Result := False;
  AValue := 0;

  If FWorksheet = nil Then
    Exit;

  s := CellText(ARow, ACol);

  If s = '' Then
    Exit;

  Try
    FWorksheet.ReadAsDateTime(ARow, ACol, AValue);
    Result := True;
  Except
    // Some deliverables may contain textual dates.
  End;

  If Not Result Then
    Result := TryStrToDateTime(s, AValue);
End;

Function TEventListingProvider.RowIsEmpty(ARow: Integer): Boolean;
Begin
  Result :=
    (CellText(ARow, FStartCol + 0) = '') And (CellText(ARow, FStartCol + 1) = '') And
    (CellText(ARow, FStartCol + 2) = '') And (CellText(ARow, FStartCol + 16) = '');
End;

Procedure TEventListingProvider.LoadEvents;
Var
  iRow: Integer;

  dtDate: TDateTime;
  dtTime: TDateTime;
  dtStart: TDateTime;

  dValue: Double;

  sType: String;
  sSubType: String;
Begin
  FEvents.Close;
  FEvents.ClearAllRecords;
  CreateFields;

  If FWorksheet = nil Then
    Exit;

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
        If CellDateTime(iRow, FStartCol + 0, dtDate) Then
        Begin
          dtStart := Trunc(dtDate);

          If CellDateTime(iRow, FStartCol + 1, dtTime) Then
            dtStart := dtStart + Frac(dtTime);

          dtStart := Trunc(dtDate) + Frac(dtTime);

          // Event Listing time -> UTC
          dtStart := dtStart - FUTCOffset;

          FEvents['Start'].AsDateTime := dtStart;
        End;

        // KP = F
        If CellFloat(iRow, FStartCol + 5, dValue) Then
          FEvents['KP'].AsFloat := dValue;

        // Type = C + '-' + D
        sType := CellText(iRow, FStartCol + 2);
        sSubType := CellText(iRow, FStartCol + 3);

        If (sType <> '') And (sSubType <> '') Then
          FEvents['Type'].AsString := sType + '-' + sSubType
        Else If sType <> '' Then
          FEvents['Type'].AsString := sType
        Else
          FEvents['Type'].AsString := sSubType;

        // Anomaly_No = Q
        FEvents['Anomaly_No'].AsString :=
          CellText(iRow, FStartCol + 16);

        // Dimensions = K, L, M
        If CellFloat(iRow, FStartCol + 10, dValue) Then
          FEvents['Length_(m)'].AsFloat := dValue;

        If CellFloat(iRow, FStartCol + 11, dValue) Then
          FEvents['Width_(m)'].AsFloat := dValue;

        If CellFloat(iRow, FStartCol + 12, dValue) Then
          FEvents['Height_(m)'].AsFloat := dValue;

        // No Fugro Event Listing equivalent currently.
        FEvents['Offset_(m)'].Clear;

        // Clock = O
        FEvents['Clock'].AsString :=
          CellText(iRow, FStartCol + 14);

        // Description = R
        FEvents['Description'].AsString :=
          CellText(iRow, FStartCol + 17);

        // Position = H, I, J
        If CellFloat(iRow, FStartCol + 7, dValue) Then
          FEvents['Easting'].AsFloat := dValue;

        If CellFloat(iRow, FStartCol + 8, dValue) Then
          FEvents['Northing'].AsFloat := dValue;

        If CellFloat(iRow, FStartCol + 9, dValue) Then
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

Procedure TEventListingProvider.DoEventsAfterScroll(DataSet: TDataSet);
Var
  sAnomalyNo: String;
  dtDateTime: TDateTime;
Begin
  If Ready And Assigned(FOnAnomalyChanged) And Not FEvents.Table.ControlsDisabled Then
  Begin
    sAnomalyNo := FEvents['Anomaly_No'].AsString;
    dtDateTime := FEvents['Start'].AsDateTime;
    FOnAnomalyChanged(Self, sAnomalyNo, dtDateTime);
  End;
End;

End.
