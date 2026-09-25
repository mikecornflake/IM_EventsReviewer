Unit MediaTypes;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, fgl;

Type
  { TVideoFile }
  TVideoFile = Class
  Public
    Filename: String;
    Folder: String;
    Channel: String;
    StartDateTime: TDateTime;
    EndDateTime: TDateTime;

    InferredConfidence: Integer; // 0..100
    InferredFormatName: String;

    Procedure InferMissingInfo;

    // ADefaultDuration is only used if EndDateTime=0
    Function ContainsTime(Const ADateTime: TDateTime; Const ADefaultDuration: TDateTime): Boolean;
  End;

  { TVideoFiles }
  TVideoFiles = Class(Specialize TFPGObjectList<TVideoFile>)
  Private
    FInferInfoFromFilename: Boolean;
    FFilenameIndex: TStringList;
    FErrors: TStringList;

    Procedure InternalScanFolder(Const AFolder: String);
  Public
    Constructor Create(AFreeObjects: Boolean = True);
    Destructor Destroy; Override;

    Procedure Clear;

    Function AddVideo(AVideoFile: TVideoFile): Integer;

    Procedure ScanFolder(Const AFolder: String);
    Function Find(Const AFilename: String): TVideoFile;

    // Attempt to populate StartDateTime and Channel from filename
    Property InferInfoFromFilename: Boolean Read FInferInfoFromFilename
      Write FInferInfoFromFilename;

    Property Errors: TStringList Read FErrors;
  End;

Implementation

Uses
  InspectionSupport, FileSupport, LazLogger;

  { TVideoFile }

Procedure TVideoFile.InferMissingInfo;
Var
  oInfo: TInspectionFilenameInfo;
Begin
  If TryParseInspectionFilename(Filename, oInfo) Then
  Begin
    If (StartDateTime = 0) Then
      StartDateTime := oInfo.DateTime;

    If (Channel = '') Then
      Channel := oInfo.Channel;

    InferredConfidence := oInfo.Confidence;
    InferredFormatName := oInfo.FormatName;
  End;
End;

// ADefaultDuration is only used if EndDateTime is invalid
Function TVideoFile.ContainsTime(Const ADateTime: TDateTime;
  Const ADefaultDuration: TDateTime): Boolean;
Var
  dtEffectiveEnd: TDateTime;
Begin
  If EndDateTime > StartDateTime Then
    dtEffectiveEnd := EndDateTime
  Else
    dtEffectiveEnd := StartDateTime + ADefaultDuration;

  Result := (ADateTime >= StartDateTime) And (ADateTime <= dtEffectiveEnd);
End;

{ TVideoFiles }

Constructor TVideoFiles.Create(AFreeObjects: Boolean);
Begin
  Inherited Create(AFreeObjects);

  FFilenameIndex := TStringList.Create;
  FFilenameIndex.Duplicates := dupError;
  FFilenameIndex.Sorted := True;

  FErrors := TStringList.Create;

  FInferInfoFromFilename := False;
End;

Destructor TVideoFiles.Destroy;
Begin
  FreeAndNil(FErrors);
  FreeAndNil(FFilenameIndex);

  Inherited Destroy;
End;

Procedure TVideoFiles.Clear;
Begin
  FErrors.Clear;
  FFilenameIndex.Clear;
  Inherited Clear;
End;

Function TVideoFiles.AddVideo(AVideoFile: TVideoFile): Integer;
Var
  iIndex: Integer;
  iExistingSize, iDuplicateSize: Int64;
  oExisting: TVideoFile;
  sExisting, sDuplicate, sError: String;
Const
  ErrorDuplicate = 'Duplicate files found - see application log';
Begin
  Result := -1;

  If FInferInfoFromFilename Then
    AVideoFile.InferMissingInfo;

  iIndex := FFilenameIndex.IndexOf(AVideoFile.Filename);
  If iIndex = -1 Then
  Begin
    Result := Add(AVideoFile);
    FFilenameIndex.AddObject(AVideoFile.Filename, AVideoFile);
  End
  Else
  Begin
    oExisting := TVideoFile(FFilenameIndex.Objects[iIndex]);

    sExisting := IncludeTrailingPathDelimiter(oExisting.Folder) + oExisting.Filename;
    sDuplicate := IncludeTrailingPathDelimiter(AVideoFile.Folder) + AVideoFile.Filename;

    iExistingSize := FileSize(sExisting);
    iDuplicateSize := FileSize(sDuplicate);

    If (iExistingSize >= 0) And (iDuplicateSize >= 0) And
      (iExistingSize = iDuplicateSize) Then
    Begin
      DebugLn(['TVideoFiles.AddVideo: Duplicate videos found. ', sExisting,
        ' and ', sDuplicate]);

      If FErrors.IndexOf(ErrorDuplicate)=-1 Then
        FErrors.Add(ErrorDuplicate);
    End
    Else
    Begin
      sError := 'Duplicate videos with different or unreadable sizes. Existing: ' +
        sExisting + LineEnding + 'Duplicate: ' + sDuplicate;
      FErrors.Add(sError);
    End;

    If FreeObjects Then
      FreeAndNil(AVideoFile);
  End;
End;

Procedure TVideoFiles.InternalScanFolder(Const AFolder: String);
Var
  srFile: TSearchRec;
  sPath: String;
  sExt: Rawbytestring;
  oVideoFile: TVideoFile;
Begin
  sPath := IncludeTrailingPathDelimiter(AFolder);

  If FindFirst(sPath + '*', faAnyFile, srFile) = 0 Then
  Try
    Repeat
      If (srFile.Name = '.') Or (srFile.Name = '..') Then
        Continue;

      If (srFile.Attr And faDirectory) <> 0 Then
        InternalScanFolder(sPath + srFile.Name)
      Else
      Begin
        sExt := ExtractFileExt(srFile.Name);
        If IsVideo(sExt) Then
        Begin
          oVideoFile := TVideoFile.Create;
          oVideoFile.Filename := srFile.Name;
          oVideoFile.Folder := sPath;

          AddVideo(oVideoFile);
        End;
      End;
    Until FindNext(srFile) <> 0;
  Finally
    FindClose(srFile);
  End;
End;

Procedure TVideoFiles.ScanFolder(Const AFolder: String);
Begin
  {$IFNDEF RELEASE}
  DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}, ' ', AFolder]);
  {$ENDIF}

  Clear;

  InternalScanFolder(AFolder);
End;

Function TVideoFiles.Find(Const AFilename: String): TVideoFile;
Var
  i: Integer;
Begin
  Result := nil;

  i := FFilenameIndex.IndexOf(AFilename);

  If i >= 0 Then
    Result := TVideoFile(FFilenameIndex.Objects[i]);
End;

End.
