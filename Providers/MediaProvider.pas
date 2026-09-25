Unit MediaProvider;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, MediaTypes;

Type

  { TMediaProvider }

  TMediaProvider = Class
  Private
    FFolder: String;

    // Video File list
    FVideos: TVideoFiles;

  Public
    Constructor Create; Virtual;
    Destructor Destroy; Override;

    Procedure Refresh;

    Procedure ScanVideoFiles(AFolder: String);
    Function LookupFolder(AVideoFilename: String): String;

    Function VideoFilesForDateTime(Const ADateTime: TDateTime; AMaxVideoDurationMinutes: Integer): TVideoFiles;

    Property Videos: TVideoFiles Read FVideos;
  End;

Implementation

Uses
  Dialogs;

{ TMediaProvider }

Constructor TMediaProvider.Create;
Begin
  // Video Filename/Folder lookup...
  FVideos := TVideoFiles.Create(True);
  FVideos.InferInfoFromFilename := True;

  FFolder := '';
End;

Destructor TMediaProvider.Destroy;
Begin
  FreeAndNil(FVideos);

  Inherited Destroy;
End;

Procedure TMediaProvider.Refresh;
Begin
  ScanVideoFiles(FFolder);
End;

Procedure TMediaProvider.ScanVideoFiles(AFolder: String);
Begin
  FFolder := AFolder;
  FVideos.Clear;

  // Populate VideoFilenames
  If (AFolder <> '') And DirectoryExists(AFolder) Then
  Begin
    FVideos.ScanFolder(AFolder);

    If FVideos.Errors.Count > 0 Then
      ShowMessage(FVideos.Errors.Text);
  End;
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

Function TMediaProvider.VideoFilesForDateTime(Const ADateTime: TDateTime; AMaxVideoDurationMinutes: Integer): TVideoFiles;
Var
  i: Integer;
  oVideo: TVideoFile;
  oBest: TVideoFile;
  slBestByChannel: TStringList;
  iChannelIndex: Integer;
  dtMaxAge: TDateTime;
Begin
  Result := TVideoFiles.Create(False);

  slBestByChannel := TStringList.Create;
  Try
    slBestByChannel.Sorted := True;
    slBestByChannel.Duplicates := dupIgnore;
    slBestByChannel.OwnsObjects := False;

    dtMaxAge := AMaxVideoDurationMinutes / MinsPerDay;

    For i := 0 To FVideos.Count - 1 Do
    Begin
      oVideo := FVideos[i];

      // Find all videos within the valid window
      If Not oVideo.ContainsTime(ADateTime, dtMaxAge) Then
        Continue;

      iChannelIndex := slBestByChannel.IndexOf(oVideo.Channel);

      If iChannelIndex < 0 Then
      Begin
        slBestByChannel.AddObject(oVideo.Channel, oVideo);
      End
      Else
      Begin
        oBest := TVideoFile(slBestByChannel.Objects[iChannelIndex]);

        // Keep the most recently started ovideo for this channel.
        If oVideo.StartDateTime > oBest.StartDateTime Then
          slBestByChannel.Objects[iChannelIndex] := oVideo;
      End;
    End;

    // Return references to the selected videos.
    For i := 0 To slBestByChannel.Count - 1 Do
      Result.Add(TVideoFile(slBestByChannel.Objects[i]));

  Finally
    slBestByChannel.Free;
  End;
End;

End.
