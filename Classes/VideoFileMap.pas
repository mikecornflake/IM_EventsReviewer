Unit VideoFileMap;

{$mode ObjFPC}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}

Interface

Uses
  Classes, SysUtils, fgl;

Type

  { TVideoFileFolderMap }

  TVideoFileFolderMap = Class(Specialize TFPGMap<String, String>)
  Private
    Procedure InternalScanFolder(Const AFolder: String);
  Public
    Procedure ScanFolder(Const AFolder: String);
    Function LookupFolder(Const AFilename: String): String;
  End;

Implementation

Uses
  FileSupport;

  { TVideoFileFolderMap }

Procedure TVideoFileFolderMap.InternalScanFolder(Const AFolder: String);
Var
  srFile: TSearchRec;
  sPath: String;
  sExt: Rawbytestring;
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
        If IndexOf(srFile.Name) >= 0 Then
          // TODO, Improve.report duplicate filename
          Raise Exception.CreateFmt('TVideoFileFolderMap: Duplicate file found %s',
            [sPath + srFile.Name])
        Else
        Begin
          sExt := ExtractFileExt(srFile.Name);
          If IsVideo(sExt) Then
            Add(srFile.Name, sPath);
        End;
      End;
    Until FindNext(srFile) <> 0;
  Finally
    FindClose(srFile);
  End;
End;

Procedure TVideoFileFolderMap.ScanFolder(Const AFolder: String);
Begin
  Clear;

  Sorted := False;
  InternalScanFolder(AFolder);
  Sorted := True;
End;

Function TVideoFileFolderMap.LookupFolder(Const AFilename: String): String;
Var
  iIndex: Integer;
Begin
  iIndex := IndexOf(AFilename);

  If (iIndex >= 0) Then
    Result := IncludeTrailingBackslash(Data[iIndex])
  Else
    Result := '';
End;

End.
