Unit SpreadsheetSupport;

{$mode ObjFPC}{$H+}

Interface

// ALL ChatGPT
Uses
  Classes, SysUtils, FPSpreadsheet;

Procedure GetWorksheetNames(Const AFilename: String; AStrings: TStrings);

Function CellText(AWorksheet: TsWorksheet; ARow, ACol: Integer): String;
Function CellFloat(AWorksheet: TsWorksheet; ARow, ACol: Integer; Out AValue: Double): Boolean;
Function CellDateTime(AWorksheet: TsWorksheet; ARow, ACol: Integer;
  Out AValue: TDateTime): Boolean;

Function ColumnIndexToName(AColumn: Integer): String;
Function ColumnNameToIndex(Const AColumn: String): Integer;
Function RowIndexToName(ARow: Integer): String;
Function RowNameToIndex(Const ARow: String): Integer;


Implementation

Uses
  fpsTypes;

Procedure GetWorksheetNames(Const AFilename: String; AStrings: TStrings);
Var
  oWorkbook: TsWorkbook;
  i: Integer;
Begin
  If Not Assigned(AStrings) Then
    Exit;

  AStrings.BeginUpdate;
  Try
    AStrings.Clear;

    oWorkbook := TsWorkbook.Create;
    Try
      oWorkbook.ReadFromFile(AFilename);

      For i := 0 To oWorkbook.GetWorksheetCount - 1 Do
        AStrings.Add(oWorkbook.GetWorksheetByIndex(i).Name);
    Finally
      oWorkbook.Free;
    End;

  Finally
    AStrings.EndUpdate;
  End;
End;

Function CellText(AWorksheet: TsWorksheet; ARow, ACol: Integer): String;
Begin
  Result := Trim(AWorksheet.ReadAsText(ARow, ACol));
End;

Function CellFloat(AWorksheet: TsWorksheet; ARow, ACol: Integer; Out AValue: Double): Boolean;
Var
  s: String;
Begin
  Result := False;
  AValue := 0;

  If AWorksheet = nil Then
    Exit;

  s := CellText(AWorksheet, ARow, ACol);

  If s = '' Then
    Exit;

  // First try FPSpreadsheet's actual numeric value.
  Try
    AValue := AWorksheet.ReadAsNumber(ARow, ACol);
    Result := True;
  Except
    // Fall through to textual conversion.
  End;

  If Not Result Then
    Result := TryStrToFloat(s, AValue);
End;

Function CellDateTime(AWorksheet: TsWorksheet; ARow, ACol: Integer;
  Out AValue: TDateTime): Boolean;
Var
  s: String;
Begin
  Result := False;
  AValue := 0;

  If AWorksheet = nil Then
    Exit;

  s := CellText(AWorksheet, ARow, ACol);

  If s = '' Then
    Exit;

  Try
    AWorksheet.ReadAsDateTime(ARow, ACol, AValue);
    Result := True;
  Except
    // Some deliverables may contain textual dates.
  End;

  If Not Result Then
    Result := TryStrToDateTime(s, AValue);
End;

Function ColumnIndexToName(AColumn: Integer): String;
Var
  i: Integer;
Begin
  Result := '';

  If AColumn < 0 Then
    Exit;

  i := AColumn;

  Repeat
    Result := Chr(Ord('A') + (i Mod 26)) + Result;
    i := (i Div 26) - 1;
  Until i < 0;
End;

Function ColumnNameToIndex(Const AColumn: String): Integer;
Var
  i: Integer;
  s: String;
Begin
  Result := -1;
  s := UpperCase(Trim(AColumn));

  If s = '' Then
    Exit;

  Result := 0;

  For i := 1 To Length(s) Do
  Begin
    If Not (s[i] In ['A'..'Z']) Then
    Begin
      Result := -1;
      Exit;
    End;

    Result := Result * 26 + (Ord(s[i]) - Ord('A') + 1);
  End;

  Dec(Result);
End;

Function RowIndexToName(ARow: Integer): String;
Begin
  If ARow >= 0 Then
    Result := IntToStr(ARow + 1)
  Else
    Result := '';
End;

Function RowNameToIndex(Const ARow: String): Integer;
Var
  iRow: Integer;
Begin
  If TryStrToInt(Trim(ARow), iRow) And (iRow > 0) Then
    Result := iRow - 1
  Else
    Result := -1;
End;

End.
