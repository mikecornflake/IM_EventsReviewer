Unit FrameVideo;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Inifiles,
  FrameBase, FrameVideoPlayer, FrameSyncedVideo, MediaTypes,
  FrameSettingsSyncedVideo, IMMessaging, AppMessaging;

Type

  { TfmeVideo }

  TfmeVideo = Class(TFrameBase)
    tmrSeekAfterLoadVideo: TTimer;
    Procedure tmrSeekAfterLoadVideoTimer(Sender: TObject);
  Private
    // State
    FLastTimeSent: TDateTime;
    FLastBroadcastTick: QWord;
    FPendingSeek: Boolean;
    FPendingSeekTime: TDateTime;

    // Settings
    FImageGrabFolder: String;

    // UI
    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;

    // Tracking video playback status
    FPendingVideoTime: TDateTime;
    FSeekPending: Boolean;

    Procedure DoPlayerGrabImage(Sender: TObject; Const AFolder: String);
    Procedure DoReceiveTimeSeekMessage(AMessage: TIMMessage);
    Procedure DoVideoLoaded(Sender: TObject);
    Function GetGrabImageBtnEnabled: Boolean;
    Function GetImageGrabHint: String;
    Function GetVideoTrackbarSeek: Boolean;
    Procedure SetGrabImageBtnEnabled(Const AValue: Boolean);
    Procedure SetImageGrabFolder(Const AValue: String);

    Procedure DoVideoPositionChange(Sender: TObject; ADateTime: TDateTime);
    Procedure SetImageGrabHint(Const AValue: String);
  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure LoadVideos(AVideoFiles: TVideoFiles; ASeekDateTime: TDateTime);
    Procedure Clear;

    Procedure PopulateSettingsFrame(AFrame: TFrameSettingsSyncedVideo);
    Procedure ApplySettingsFrame(AFrame: TFrameSettingsSyncedVideo);

    Procedure LoadSettings(oInifile: TIniFile); Override;
    Procedure SaveSettings(oInifile: TIniFile); Override;

    // We have a synced playback engine.  This will only return the filename
    // of the first (master) filename
    Function MasterFilename: String;

    Property VideoTrackbarSeek: Boolean Read GetVideoTrackbarSeek;

    Property ImageGrabHint: String Read GetImageGrabHint Write SetImageGrabHint;
    Property ImageGrabFolder: String Read FImageGrabFolder Write SetImageGrabFolder;
    Property GrabImageBtnEnabled: Boolean Read GetGrabImageBtnEnabled
      Write SetGrabImageBtnEnabled;
  End;

Const
  TWO_SEC = 2 / (24 * 60 * 60);

Implementation

Uses
  FormEventsReviewer, VideoEngineFactory, FrameVideoLibmpv;

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
  fmeVideoPlayer.OnVideoPositionChange := @DoVideoPositionChange;

  // Ensure the Video Player support multi channel playback
  fmeVideoPlayer.VideoEngineClass := TFrameSyncedVideo;

  // Currently multi channel functionality is only exposed through the Video Engine,
  // not the Video Player UI frame, so grab a reference of the instance
  fmeSyncedVideo := TFrameSyncedVideo(fmeVideoPlayer.PlaybackFrame);

  // Change this line to switch playback engines (mpv, vlc, mlplayer
  fmeSyncedVideo.VideoEngineClass := TVideoEngineFactory.DefaultClass;
  fmeVideoPlayer.Autoplay := False;
  fmeSyncedVideo.OnVideoLoaded := @DoVideoLoaded;

  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageTime, @DoReceiveTimeSeekMessage);

  FLastTimeSent := 0;
  FPendingSeek := False;
  FPendingSeekTime := 0;
  FLastBroadcastTick := 0;
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

Function TfmeVideo.MasterFilename: String;
begin
  Result := fmeSyncedVideo.Filename;
end;

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

Procedure TfmeVideo.DoVideoPositionChange(Sender: TObject; ADateTime: TDateTime);
Begin
  // TWO_SEC filter is for meaningful video change - ROV really won't move that much
  // within two seconds.

  // Video has changed position, either due to user interaction with fmeVideoPlayer,
  //  or due to us moving the video in response to TIMMessageTime
  If FPendingSeek Then
  Begin
    If Abs(ADateTime - FPendingSeekTime) <= TWO_SEC Then
    Begin
      // We've reached the requested position.
      FPendingSeek := False;
      FPendingSeekTime := 0;

      // This one is legitimate and may be broadcast.
    End
    Else
      Exit;  // intermediate mpv noise, e.g. newly loaded video at 00:00
  End;

  //  Even if the video has moved a meaningful amount, only send the signal once per second
  If (Abs(ADateTime - FLastTimeSent) > TWO_SEC) And (GetTickCount64 -
    FLastBroadcastTick >= 1000) Then
  Begin
    FLastTimeSent := ADateTime;
    FLastBroadcastTick := GetTickCount64;

    frmEventsReviewer.MessageBus.BroadcastTime(Self, ADateTime);
  End;
End;

Procedure TfmeVideo.SetImageGrabHint(Const AValue: String);
Begin
  fmeVideoPlayer.ImageGrabHint := AValue;
End;

Procedure TfmeVideo.DoPlayerGrabImage(Sender: TObject; Const AFolder: String);
Begin
  // Let the UI decide what to do with the images
  frmEventsReviewer.DoPlayerGrabImage(AFolder);
End;

Procedure TfmeVideo.DoReceiveTimeSeekMessage(AMessage: TIMMessage);
Var
  oMessage: TIMMessageTime;
  oVideoFiles: TVideoFiles;
Begin
  If Not (AMessage Is TIMMessageTime) Then
    Exit;

  oMessage := TIMMessageTime(AMessage);

  FPendingSeek := True;
  FPendingSeekTime := oMessage.DateTime;

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
    oVideoFiles := frmEventsReviewer.DataProvider.GetVideoFilesForTime(oMessage.DateTime);

    // If not, ask the Media Provider...
    // Media Provider may have to guess based off start time only, so provide a default
    // Max Video duration
    If Not Assigned(oVideoFiles) Then
      oVideoFiles := frmEventsReviewer.MediaProvider.VideoFilesForDateTime(
        oMessage.DateTime, frmEventsReviewer.Settings.MaxVideoDuration);

    Try
      LoadVideos(oVideoFiles, oMessage.DateTime);
    Finally
      oVideoFiles.Free;
    End;
  End;
End;

Procedure TfmeVideo.LoadVideos(AVideoFiles: TVideoFiles; ASeekDateTime: TDateTime);
Var
  oVideoFile: TVideoFile;
  sFolder: String;
Begin
  If AVideoFiles.Count = 0 Then
    Clear
  Else
  Begin
    FPendingSeek := True;
    FPendingSeekTime := ASeekDateTime;

    frmEventsReviewer.Busy := True;
    frmEventsReviewer.DisableAutoSizing;
    Try
      fmeSyncedVideo.BeginLoadVideos;
      Try
        For oVideoFile In AVideoFiles Do
        Begin
          sFolder := IncludeTrailingBackslash(
            frmEventsReviewer.MediaProvider.LookupFolder(oVideoFile.Filename));

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
      frmEventsReviewer.EnableAutoSizing;
      frmEventsReviewer.Busy := False;
    End;
  End;
End;

Procedure TfmeVideo.Clear;
Begin
  fmeVideoPlayer.Clear;

  // TODO: Implement fmeSyncedVideo.clear
  //       Not done now as this will require testing all Video modules
  fmeSyncedVideo.ClearVideoCount;
  fmeSyncedVideo.ClearUnloadedVideoFrames;

  // Clear any pending seeks
  tmrSeekAfterLoadVideo.Enabled := False;
  FSeekPending := False;
  FPendingSeek := False;
  FPendingSeekTime := 0;
  FPendingVideoTime := 0;
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

Function TfmeVideo.GetGrabImageBtnEnabled: Boolean;
Begin
  Result := fmeVideoPlayer.GrabImageBtnEnabled;
End;

Function TfmeVideo.GetImageGrabHint: String;
Begin
  Result := fmeVideoPlayer.ImageGrabHint;
End;

Function TfmeVideo.GetVideoTrackbarSeek: Boolean;
Begin
  Result := fmeVideoPlayer.VideoTrackbarSeek;
End;

Procedure TfmeVideo.SetGrabImageBtnEnabled(Const AValue: Boolean);
Begin
  fmeVideoPlayer.GrabImageBtnEnabled := AValue;
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
