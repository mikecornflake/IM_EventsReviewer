Unit FrameVideo;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Inifiles,
  FrameBase, FrameVideoPlayer, FrameSyncedVideo, MediaTypes,
  FrameSettingsSyncedVideo;

Type

  { TfmeVideo }

  TfmeVideo = Class(TFrameBase)
    tmrSeekAfterLoadVideo: TTimer;
    Procedure tmrSeekAfterLoadVideoTimer(Sender: TObject);
  Private
    FImageGrabFolder: String;

    // UI
    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;

    // Tracking video playback status
    FPendingVideoTime: TDateTime;
    FSeekPending: Boolean;

    Procedure DoPlayerGrabImage(Sender: TObject; Const AFolder: String);
    Procedure DoReceiveTimeSeek(Sender: TObject);
    Procedure DoVideoLoaded(Sender: TObject);
    Procedure SetImageGrabFolder(Const AValue: String);
  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure LoadVideos(AVideoFiles: TVideoFiles; ASeekDateTime: TDateTime);

    Property ImageGrabFolder: String Read FImageGrabFolder Write SetImageGrabFolder;

    Procedure PopulateSettingsFrame(AFrame: TFrameSettingsSyncedVideo);
    Procedure ApplySettingsFrame(AFrame: TFrameSettingsSyncedVideo);

    Procedure LoadSettings(oInifile: TIniFile); Override;
    Procedure SaveSettings(oInifile: TIniFile); Override;
  End;

Implementation

Uses
  FormStarfixAnomalies, VideoEngineFactory, NavigationController, FrameVideoLibmpv;

  {$R *.lfm}

  { TfmeVideo }

Constructor TfmeVideo.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);

  fmeVideoPlayer := TFrameVideoPlayer.Create(Self);
  fmeVideoPlayer.Parent := Self;
  fmeVideoPlayer.Name := 'fmeVideoPlayer';
  fmeVideoPlayer.Align := alClient;
  fmeVideoPlayer.Autoplay := True;
  fmeVideoPlayer.ShowLabel := True;

  // Ensure the Video Player support multi channel playback
  fmeVideoPlayer.VideoEngineClass := TFrameSyncedVideo;

  // Currently multi channel functionality is only exposed through the Video Engine,
  // not the Video Player UI frame, so grab a reference of the instance
  fmeSyncedVideo := TFrameSyncedVideo(fmeVideoPlayer.PlaybackFrame);

  // Change this line to switch playback engines (mpv, vlc, mlplayer
  fmeSyncedVideo.VideoEngineClass := TVideoEngineFactory.DefaultClass;
  fmeVideoPlayer.Autoplay := False;
  fmeSyncedVideo.OnVideoLoaded := @DoVideoLoaded;

  frmStarfixReviewer.Messenger.Register(TIMMessageTime, @DoReceiveTimeSeek);
End;

Destructor TfmeVideo.Destroy;
Begin
  FreeAndNil(fmeVideoPlayer);

  Inherited Destroy;
End;

Procedure TfmeVideo.LoadSettings(oInifile: TIniFile);
Begin
  Inherited LoadSettings(oInifile);

  fmeVideoPlayer.LoadSettings(oInifile);
End;

Procedure TfmeVideo.SaveSettings(oInifile: TIniFile);
Begin
  fmeVideoPlayer.SaveSettings(oInifile);

  Inherited SaveSettings(oInifile);
End;

Procedure TfmeVideo.SetImageGrabFolder(Const AValue: String);
Begin
  If FImageGrabFolder = AValue Then
    Exit;
  FImageGrabFolder := AValue;

  fmeVideoPlayer.ImageGrabFolder := FImageGrabFolder;

  // Only override Player workflow if we've been given a working folder
  fmeVideoPlayer.OnGrabImage := @DoPlayerGrabImage;
  fmeVideoPlayer.ImageGrabHint := 'Selected images will be saved in ' + FImageGrabFolder;
End;

Procedure TfmeVideo.DoPlayerGrabImage(Sender: TObject; Const AFolder: String);
Begin
  // Let the UI decide what to do with the images
  frmStarfixReviewer.DoPlayerGrabImage(AFolder);
End;

Procedure TfmeVideo.DoReceiveTimeSeek(Sender: TObject);
Var
  oMessage: TIMMessageTime;
  oVideoFiles: TVideoFiles;
Begin
  If Not (Sender Is TIMMessageTime) Then
    Exit;

  oMessage := TIMMessageTime(Sender);

  // Do I need to load new Video?
  If (fmeSyncedVideo.StartDateTime <= oMessage.DateTime) And
    (oMessage.DateTime <= fmeSyncedVideo.EndDateTime) Then
  Begin
    // No, we just need to seek to the new time
    fmeSyncedVideo.PositionAsTime := oMessage.DateTime;
  End
  Else
  Begin
    // Yes, videos need to be updated

    // Does the Data Provider know anything about Videos?
    oVideoFiles := frmStarfixReviewer.DataProvider.GetVideoFilesForTime(oMessage.DateTime);

    // If not, ask the Media Provider...
    If Not Assigned(oVideoFiles) Then
      oVideoFiles := frmStarfixReviewer.MediaProvider.VideoFilesForDateTime(oMessage.DateTime);

    Try
      LoadVideos(oVideoFiles, oMessage.DateTime);
    Finally
      oVideoFiles.Free;
    End;
  End;
End;

Procedure TfmeVideo.LoadVideos(AVideoFiles: TVideoFiles; ASeekDateTime: TDateTime);
var
  oVideoFile: TVideoFile;
  sFolder: String;
Begin
  If AVideoFiles.Count = 0 Then
  Begin
    fmeVideoPlayer.Clear;

    // TODO: Implement fmeSyncedVideo.clear
    //       Not done now as this will require testing all Video modules
    fmeSyncedVideo.ClearVideoCount;
    fmeSyncedVideo.ClearUnloadedVideoFrames;
  End
  Else
  Begin
    frmStarfixReviewer.Busy := True;
    frmStarfixReviewer.DisableAutoSizing;
    Try
      fmeSyncedVideo.BeginLoadVideos;
      Try
        For oVideoFile In AVideoFiles Do
        Begin
          sFolder := IncludeTrailingBackslash(
            frmStarfixReviewer.MediaProvider.LookupFolder(oVideoFile.Filename));

          If FileExists(sFolder + oVideoFile.Filename) Then
            fmeSyncedVideo.Load(sFolder + oVideoFile.Filename,
              oVideoFile.Channel, oVideoFile.StartDateTime);
        End;
      Finally
        fmeSyncedVideo.EndLoadVideos;
        FSeekPending := True;
      End;

      If fmeSyncedVideo.VideoFileCount > 0 Then
      Begin
        // Pause the video (this is anomaly review, user will want to study the start)
        fmeSyncedVideo.Pause;

        // Seek
        fmeSyncedVideo.PositionAsTime := ASeekDateTime;
        FPendingVideoTime := ASeekDateTime;

        fmeVideoPlayer.RefreshUI;
      End;
    Finally
      frmStarfixReviewer.EnableAutoSizing;
      frmStarfixReviewer.Busy := False;
    End;
  End;
End;

Procedure TfmeVideo.PopulateSettingsFrame(AFrame: TFrameSettingsSyncedVideo);
Begin
  fmeSyncedVideo.PopulateSettingsFrame(AFrame);
End;

Procedure TfmeVideo.ApplySettingsFrame(AFrame: TFrameSettingsSyncedVideo);
Begin
  fmeSyncedVideo.ApplySettingsFrame(AFrame);
End;

Procedure TfmeVideo.DoVideoLoaded(Sender: TObject);
Begin
  tmrSeekAfterLoadVideo.Enabled := True;
End;

Procedure TfmeVideo.tmrSeekAfterLoadVideoTimer(Sender: TObject);
Begin
  tmrSeekAfterLoadVideo.Enabled := False;

  If FSeekPending Then
  Begin
    FSeekPending := False;
    fmeSyncedVideo.PositionAsTime := FPendingVideoTime;
  End;
End;

End.
