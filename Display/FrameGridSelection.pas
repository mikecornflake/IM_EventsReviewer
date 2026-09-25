Unit FrameGridSelection;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, ComCtrls, FrameEditor, DB;

Type

  { TfmeGridSelection }

  TfmeGridSelection = Class(TFrameEditorBase)
    grdSelection: TStringGrid;
    ImageList1: TImageList;
    ToolBar1: TToolBar;
    btnSelectAll: TToolButton;
    btnToggleSelection: TToolButton;
    btnClearSelection: TToolButton;

    Procedure btnClearSelectionClick(Sender: TObject);
    Procedure btnSelectAllClick(Sender: TObject);
    Procedure btnToggleSelectionClick(Sender: TObject);
    Procedure grdSelectionGetCellHint(Sender: TObject; ACol, ARow: Integer; Var HintText: String);

    Procedure grdSelectionMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    Procedure grdSelectionPrepareCanvas(Sender: TObject; ACol, ARow: Integer;
      aState: TGridDrawState);
  Private
    FDataset: TDataset;
    Function GetSelected(ARecordIndex: Integer): Boolean;
    Procedure SetDataset(Const AValue: TDataset);

    Procedure LoadData;
    Procedure SetSelected(ARecordIndex: Integer; Const AValue: Boolean);

  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Property Dataset: TDataset Read FDataset Write SetDataset;

    Property Selected[ARecordIndex: Integer]: Boolean Read GetSelected Write SetSelected;
  End;

Implementation

Uses
  StrUtils, Math;

  {$R *.lfm}

  { TfmeGridSelection }

Constructor TfmeGridSelection.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);
End;

Destructor TfmeGridSelection.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TfmeGridSelection.grdSelectionPrepareCanvas(Sender: TObject;
  ACol, ARow: Integer; aState: TGridDrawState);
Begin
  If ARow = 0 Then
    grdSelection.Canvas.Font.Style := grdSelection.Canvas.Font.Style + [fsBold];

  If (ARow < grdSelection.FixedRows) Then
    Exit;

  If grdSelection.Cells[0, ARow] = 'Y' Then
    grdSelection.Canvas.Brush.Color := clHighlight;
End;

Procedure TfmeGridSelection.grdSelectionGetCellHint(Sender: TObject;
  ACol, ARow: Integer; Var HintText: String);
Begin
  HintText := grdSelection.Cells[ACol, ARow];
End;

Procedure TfmeGridSelection.btnSelectAllClick(Sender: TObject);
Var
  iRow: Integer;
Begin
  For iRow := 1 To grdSelection.RowCount - 1 Do
    grdSelection.Cells[0, iRow] := 'Y';

  grdSelection.Invalidate;
End;

Procedure TfmeGridSelection.btnToggleSelectionClick(Sender: TObject);
Var
  iRow: Integer;
Begin
  For iRow := 1 To grdSelection.RowCount - 1 Do
    If grdSelection.Cells[0, iRow] = 'Y' Then
      grdSelection.Cells[0, iRow] := 'N'
    Else
      grdSelection.Cells[0, iRow] := 'Y';

  grdSelection.Invalidate;
End;

Procedure TfmeGridSelection.btnClearSelectionClick(Sender: TObject);
Var
  iRow: Integer;
Begin
  For iRow := 1 To grdSelection.RowCount - 1 Do
    grdSelection.Cells[0, iRow] := 'N';

  grdSelection.Invalidate;
End;

Procedure TfmeGridSelection.grdSelectionMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
Var
  iCol, iRow: Integer;
Begin
  If Button <> mbLeft Then
    Exit;

  grdSelection.MouseToCell(X, Y, iCol, iRow);

  // Ignore headers and the checkbox column.
  If (iRow < grdSelection.FixedRows) Or (iCol <= 0) Then
    Exit;

  If grdSelection.Cells[0, iRow] = 'Y' Then
    grdSelection.Cells[0, iRow] := 'N'
  Else
    grdSelection.Cells[0, iRow] := 'Y';

  grdSelection.Invalidate;
End;

Procedure TfmeGridSelection.SetDataset(Const AValue: TDataset);
Begin
  If FDataset = AValue Then
    Exit;

  FDataset := AValue;

  LoadData;
End;

Function TfmeGridSelection.GetSelected(ARecordIndex: Integer): Boolean;
Var
  iRow: Integer;
Begin
  Result := False;

  // ARecordIndex is zero-based; grid row 0 is the header.
  iRow := ARecordIndex + 1;

  If (iRow < grdSelection.FixedRows) Or (iRow >= grdSelection.RowCount) Then
    Exit;

  Result := grdSelection.Cells[0, iRow] = 'Y';
End;


Procedure TfmeGridSelection.SetSelected(ARecordIndex: Integer; Const AValue: Boolean);
Var
  iRow: Integer;
Begin
  // ARecordIndex is zero-based; grid row 0 is the header.
  iRow := ARecordIndex + 1;

  If (iRow < grdSelection.FixedRows) Or (iRow >= grdSelection.RowCount) Then
    Exit;

  If AValue Then
    grdSelection.Cells[0, iRow] := 'Y'
  Else
    grdSelection.Cells[0, iRow] := 'N';
End;

Procedure TfmeGridSelection.LoadData;
Const
  CheckBoxWidth = 36;
  MinColumnWidth = 70;
  MaxColumnWidth = 150;
  ColumnPadding = 20;
Var
  bmOriginal: TBookmark;
  i, iCol, iRow: Integer;
  iWidth: Integer;
  sValue: String;
  oField: TField;
  aFields: Array Of TField;
  aWidths: Array Of Integer;
Begin
  grdSelection.Options := grdSelection.Options + [goEditing];

  // Clear the grid, including any columns from a previous dataset.
  grdSelection.Columns.Clear;
  grdSelection.FixedCols := 0;
  grdSelection.FixedRows := 0;
  grdSelection.ColCount := 1;
  grdSelection.RowCount := 1;
  grdSelection.Cells[0, 0] := '';

  If (FDataset = nil) Or Not FDataset.Active Then
    Exit;

  grdSelection.BeginUpdate;
  Try
    // Build the field list, excluding fields ending in _ID.
    SetLength(aFields, 0);

    For i := 0 To FDataset.FieldCount - 1 Do
    Begin
      oField := FDataset.Fields[i];

      If AnsiEndsText('_ID', oField.FieldName) Then
        Continue;

      SetLength(aFields, Length(aFields) + 1);
      aFields[High(aFields)] := oField;
    End;

    // Checkbox column + one column per visible field.
    grdSelection.ColCount := Length(aFields) + 1;
    grdSelection.FixedRows := 1;
    grdSelection.RowCount := 2;

    SetLength(aWidths, grdSelection.ColCount);

    // Column 0: checkbox.
    With grdSelection.Columns.Add Do
    Begin
      Title.Caption := '';
      Width := CheckBoxWidth;
      ButtonStyle := cbsCheckboxColumn;
      ValueChecked := 'Y';
      ValueUnChecked := 'N';
      ReadOnly := False;
    End;

    aWidths[0] := CheckBoxWidth;

    // Create the dataset columns.
    For i := 0 To High(aFields) Do
    Begin
      iCol := i + 1;

      With grdSelection.Columns.Add Do
      Begin
        Title.Caption := aFields[i].DisplayLabel;
        Width := MinColumnWidth;
        ReadOnly := True;
      End;

      aWidths[iCol] := grdSelection.Canvas.TextWidth(aFields[i].DisplayLabel) + ColumnPadding;
    End;

    // Load records without triggering dataset scroll events.
    bmOriginal := FDataset.GetBookmark;
    FDataset.DisableControls;
    Try
      iRow := 1;

      FDataset.First;

      While Not FDataset.EOF Do
      Begin
        If iRow >= grdSelection.RowCount Then
          grdSelection.RowCount := iRow + 1;

        grdSelection.Cells[0, iRow] := 'N';
        //grdSelection.CheckboxState[0, iRow] := cbUnchecked;
        //grdSelection.Checked[0, iRow] := False;

        For i := 0 To High(aFields) Do
        Begin
          iCol := i + 1;

          sValue := aFields[i].DisplayText;
          grdSelection.Cells[iCol, iRow] := sValue;

          iWidth := grdSelection.Canvas.TextWidth(sValue) + ColumnPadding;

          If iWidth > aWidths[iCol] Then
            aWidths[iCol] := iWidth;
        End;

        Inc(iRow);
        FDataset.Next;
      End;

      // Leave one empty data row if the dataset contains no records.
      If iRow = 1 Then
        grdSelection.RowCount := 2
      Else
        grdSelection.RowCount := iRow;

      If FDataset.BookmarkValid(bmOriginal) Then
        FDataset.GotoBookmark(bmOriginal);

    Finally
      FDataset.FreeBookmark(bmOriginal);
      FDataset.EnableControls;
    End;

    // Apply calculated widths.
    For i := 1 To grdSelection.ColCount - 1 Do
      grdSelection.ColWidths[i] :=
        EnsureRange(aWidths[i], MinColumnWidth, MaxColumnWidth);

    grdSelection.ColWidths[0] := CheckBoxWidth;

  Finally
    grdSelection.EndUpdate;
  End;
End;

End.
