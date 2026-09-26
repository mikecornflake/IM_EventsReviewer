Unit FrameVideoFiles;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, FrameBase, FrameGrids,
  BufDataset, DB, MediaTypes, AppMessaging, IMMessaging;

Type

  { TfmeVideoFiles }

  TfmeVideoFiles = Class(TFrameBase)
  Private
    FDataset: TBufDataset;
    fmeGrid: TFrameGrid;

    Procedure DoReceiveSeekTimeMessage(AMessage: TIMMessage);
  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure Load(AVideoFiles: TVideoFiles);
    Procedure Clear;
  End;

Implementation

Uses
  FormEventsReviewer, FormMain, DBSupport;

  {$R *.lfm}

  { TfmeVideoFiles }

Constructor TfmeVideoFiles.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);

  fmeGrid := TFrameGrid.Create(Self);
  fmeGrid.Name := 'fmeGrid';
  fmeGrid.Parent := Self;
  fmeGrid.Align := alClient;

  FDataset := nil;

  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageTime, @DoReceiveSeekTimeMessage);
End;

Destructor TfmeVideoFiles.Destroy;
Begin
  FreeAndNil(fmeGrid);

  If Assigned(FDataset) Then
  Begin
    If FDataset.Active Then
      FDataset.Close;

    FreeAndNil(FDataset);
  End;

  Inherited Destroy;
End;

Procedure TfmeVideoFiles.Load(AVideoFiles: TVideoFiles);
Var
  oVideo: TVideoFile;
Begin
  frmEventsReviewer.Busy := True;
  frmEventsReviewer.SetStatusAndLog('Loading video files', INDENT_INC);
  Try
    Clear;

    If Not Assigned(FDataset) Then
      FDataset := TBufDataset.Create(Self);

    FDataset.FieldDefs.Add('Filename', ftString, 255);
    FDataset.FieldDefs.Add('Folder', ftString, 1024);
    FDataset.FieldDefs.Add('Channel', ftString, 255);
    FDataset.FieldDefs.Add('Start_Time', ftDateTime);  //  StartDateTime
    FDataset.FieldDefs.Add('End_Time', ftDateTime);    //  EndDateTime
    FDataset.FieldDefs.Add('Confidence', ftInteger);   //  InferredConfidence
    FDataset.FieldDefs.Add('Format', ftString, 255);   //  InferredFormatName

    FDataset.CreateDataset;

    For oVideo In AVideoFiles Do
    Begin
      FDataset.Append;
      Try
        FDataset.FieldByName('Filename').AsString := oVideo.Filename;
        FDataset.FieldByName('Folder').AsString := oVideo.Folder;
        FDataset.FieldByName('Channel').AsString := oVideo.Channel;
        If oVideo.StartDateTime > 0 Then
          FDataset.FieldByName('Start_Time').AsDateTime := oVideo.StartDateTime;
        If oVideo.EndDateTime > 0 Then
          FDataset.FieldByName('End_Time').AsDateTime := oVideo.EndDateTime;
        FDataset.FieldByName('Confidence').AsInteger := oVideo.InferredConfidence;
        FDataset.FieldByName('Format').AsString := oVideo.InferredFormatName;

        FDataset.Post;
      Except
        FDataset.Cancel;
      End;
    End;

    FDataset.Open;
    FDataset.IndexFieldNames := 'Start_Time';
    fmeGrid.DataSet := FDataset;

    fmeGrid.InitialiseDBGrid(False);
  Finally
    frmEventsReviewer.SetStatusAndLog('Finished loading video files', INDENT_DEC, True);
    frmEventsReviewer.Busy := False;
  End;
End;

Procedure TfmeVideoFiles.Clear;
Begin
  If Assigned(FDataset) And FDataset.Active Then
  Begin
    FDataset.Close;
    FDataset.Clear;
  End;
End;

Procedure TfmeVideoFiles.DoReceiveSeekTimeMessage(AMessage: TIMMessage);
Var
  oMessage: TIMMessageTime;
  dtCurrentStart, dtCurrentEnd, dtDefaultMax: TDateTime;
Begin
  If Not (AMessage Is TIMMessageTime) Then
    Exit;

  // Only change video if absolutely needed
  If Not (FDataset.Active) Or (FDataset.IsEmpty) Then
    Exit;

  oMessage := TIMMessageTime(AMessage);

  If frmEventsReviewer.Settings.MaxVideoDuration > 0 Then
    dtDefaultMax := frmEventsReviewer.Settings.MaxVideoDuration / MinsPerDay
  Else
    dtDefaultMax := 15 / MinsPerDay;

  dtCurrentStart := FDataset.FieldByName('Start_Time').AsDateTime;
  dtCurrentEnd := ValueAsFloat(FDataset, 'End_Time', dtCurrentStart + dtDefaultMax);

  If (oMessage.DateTime < dtCurrentStart) Or (oMessage.DateTime > dtCurrentEnd) Then
  Begin
    frmEventsReviewer.Busy := True;
    frmEventsReviewer.SetStatusAndLog('Seeking video file list to ' +
      FormatDateTime('yyyy-mm-dd HH:ss:ss', oMessage.DateTime), INDENT_INC);
    Try
      DBSupport.GotoNearestValue(FDataset, 'Start_Time', oMessage.DateTime, SEEK_LAST_BEFORE);
    Finally
      frmEventsReviewer.SetStatusAndLog('Finished seek video file list', INDENT_DEC);
      frmEventsReviewer.Busy := False;
    End;
  End;
End;

End.
