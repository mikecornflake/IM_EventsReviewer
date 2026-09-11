Unit MediaProvider;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, VideoFileMap;

Type

  { TMediaProvider }

  TMediaProvider = Class
  Private
    // Video File list
    FVideoFileMap: TVideoFileFolderMap;

  Public
    Constructor Create; Virtual;
    Destructor Destroy; Override;

    Procedure ScanVideoFiles(AFolder: String);
    Function LookupFolder(AVideoFilename: String): String;

    Property VideoFileMap: TVideoFileFolderMap Read FVideoFileMap;
  End;

Implementation

{ TMediaProvider }

Constructor TMediaProvider.Create;
Begin
  // Video Filename/Folder lookup...
  FVideoFileMap := TVideoFileFolderMap.Create;
End;

Destructor TMediaProvider.Destroy;
Begin
  FreeAndNil(FVideoFileMap);

  Inherited Destroy;
End;

Procedure TMediaProvider.ScanVideoFiles(AFolder: String);
begin
  // Populate VideoFilenames
  If DirectoryExists(AFolder) Then
    FVideoFileMap.ScanFolder(AFolder);
end;

Function TMediaProvider.LookupFolder(AVideoFilename: String): String;
begin
  Result := FVideoFileMap.LookupFolder(AVideoFilename);
end;

End.
