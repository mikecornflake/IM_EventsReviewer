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
  End;

  { TVideoFiles }
  TVideoFiles = Class(Specialize TFPGObjectList<TVideoFile>)
  Private
    FInferInfoFromFilename: Boolean;
    FFilenameIndex: TStringList;

    Procedure InternalScanFolder(Const AFolder: String);
  Public
    Constructor Create;
    Destructor Destroy; Override;

    Procedure Clear;

    Function AddVideo(AVideoFile: TVideoFile): Integer;

    Procedure ScanFolder(Const AFolder: String);
    Function Find(Const AFilename: String): TVideoFile;

    // Attempt to populate StartDateTime and Channel from filename
    Property InferInfoFromFilename: Boolean Read FInferInfoFromFilename
      Write FInferInfoFromFilename;
  End;

Implementation

Uses
  InspectionSupport, FileSupport;

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

{ TVideoFiles }

Constructor TVideoFiles.Create;
Begin
  Inherited Create(True);

  FFilenameIndex := TStringList.Create;
  FFilenameIndex.Duplicates := dupError;
  FFilenameIndex.Sorted := True;

  FInferInfoFromFilename := False;
End;

Destructor TVideoFiles.Destroy;
Begin
  FreeAndNil(FFilenameIndex);

  Inherited Destroy;
End;

Procedure TVideoFiles.Clear;
Begin
  FFilenameIndex.Clear;
  Inherited Clear;
End;

Function TVideoFiles.AddVideo(AVideoFile: TVideoFile): Integer;
Begin
  If FInferInfoFromFilename Then
    AVideoFile.InferMissingInfo;

  FFilenameIndex.AddObject(AVideoFile.Filename, AVideoFile);
  Result := Add(AVideoFile);
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
  Clear;

  InternalScanFolder(AFolder);
End;

Function TVideoFiles.Find(Const AFilename: String): TVideoFile;
var
  i: Integer;
Begin
  Result := nil;

  i := FFilenameIndex.IndexOf(AFilename);

  If i >= 0 Then
    Result := TVideoFile(FFilenameIndex.Objects[i]);
End;

End.
