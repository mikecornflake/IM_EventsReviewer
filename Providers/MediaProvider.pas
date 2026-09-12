Unit MediaProvider;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, MediaTypes;

Type

  { TMediaProvider }

  TMediaProvider = Class
  Private
    // Video File list
    FVideos: TVideoFiles;

  Public
    Constructor Create; Virtual;
    Destructor Destroy; Override;

    Procedure ScanVideoFiles(AFolder: String);
    Function LookupFolder(AVideoFilename: String): String;

    Property Videos: TVideoFiles Read FVideos;
  End;

Implementation

{ TMediaProvider }

Constructor TMediaProvider.Create;
Begin
  // Video Filename/Folder lookup...
  FVideos := TVideoFiles.Create;
  FVideos.InferInfoFromFilename := False;
End;

Destructor TMediaProvider.Destroy;
Begin
  FreeAndNil(FVideos);

  Inherited Destroy;
End;

Procedure TMediaProvider.ScanVideoFiles(AFolder: String);
Begin
  // Populate VideoFilenames
  If DirectoryExists(AFolder) Then
    FVideos.ScanFolder(AFolder);
End;

Function TMediaProvider.LookupFolder(AVideoFilename: String): String;
Var
  oVideo: TVideoFile;
Begin
  oVideo := FVideos.Find(AVideoFilename);
  If Assigned(oVideo) Then
    Result := oVideo.Folder
  Else
    Result := '';
End;

End.
