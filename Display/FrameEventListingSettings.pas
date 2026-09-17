Unit FrameEventListingSettings;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, StdCtrls, EditBtn, FrameBase;

Type

  { TFrameEventListingSettings }

  TFrameEventListingSettings = Class(TFrameBase)
    cboWorksheet: TComboBox;
    edtRow: TEdit;
    edtFilename: TFileNameEdit;
    edtCol: TEdit;
    edtUTCOffset: TEdit;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
  Private
    Function GetFilename: String;
    Function GetStartCol: Integer;
    Function GetStartRow: Integer;
    Function GetUTCOffset: Double;
    Function GetWorksheet: String;
    Procedure SetFilename(Const AValue: String);
    Procedure SetStartCol(Const AValue: Integer);
    Procedure SetStartRow(Const AValue: Integer);
    Procedure SetUTCOffset(Const AValue: Double);
    Procedure SetWorksheet(Const AValue: String);

  Public

    Property Filename: String Read GetFilename Write SetFilename;
    Property Worksheet: String Read GetWorksheet Write SetWorksheet;
    Property StartCol: Integer Read GetStartCol Write SetStartCol;
    Property StartRow: Integer Read GetStartRow Write SetStartRow;
    Property UTC_Offset: Double Read GetUTCOffset Write SetUTCOffset;

  End;

Implementation

Uses
  SpreadsheetSupport;

  {$R *.lfm}

  { TFrameEventListingSettings }

Function TFrameEventListingSettings.GetFilename: String;
Begin
  Result := edtFilename.Text;
End;

Function TFrameEventListingSettings.GetStartCol: Integer;
Begin
  Result := ColumnNameToIndex(edtCol.Text);
End;

Function TFrameEventListingSettings.GetStartRow: Integer;
Begin
  Result := RowNameToIndex(edtRow.Text);
End;

Function TFrameEventListingSettings.GetUTCOffset: Double;
Begin
  Result := 0;
  TryStrToFloat(edtUTCOffset.Text, Result);
End;

Function TFrameEventListingSettings.GetWorksheet: String;
Begin
  Result := cboWorksheet.Text;
End;

Procedure TFrameEventListingSettings.SetFilename(Const AValue: String);
Begin
  edtFilename.Text := AValue;
End;

Procedure TFrameEventListingSettings.SetStartCol(Const AValue: Integer);
Begin
  edtCol.Text := ColumnIndexToName(AValue);
End;

Procedure TFrameEventListingSettings.SetStartRow(Const AValue: Integer);
Begin
  edtRow.Text := RowIndexToName(AValue);
End;

Procedure TFrameEventListingSettings.SetUTCOffset(Const AValue: Double);
Begin
  edtUTCOffset.Text := Format('%.1f', [AValue]);
End;

Procedure TFrameEventListingSettings.SetWorksheet(Const AValue: String);
Begin
  cboWorksheet.Text := AValue;
End;

End.
