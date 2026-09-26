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
  FormEventsReviewer, FormMain, DBSupport, LazLogger;

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
  dtDefaultMax, dtCurrentEnd: Extended;
  dtCurrentStart: TDateTime;
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
    FDataset.FieldDefs.Add('Colour_ID', ftString, 20);

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

        // Populate Colour_ID according to rules
        If FDataset.FieldByName('Start_Time').IsNull Then
          FDataset.FieldByName('Colour_ID').AsString := 'Red' // Invalid Start Time
        Else
        Begin
          // Is this video within DataProvider bounds
          If frmEventsReviewer.Settings.MaxVideoDuration > 0 Then
            dtDefaultMax := frmEventsReviewer.Settings.MaxVideoDuration / MinsPerDay
          Else
            dtDefaultMax := 15 / MinsPerDay;
          dtCurrentStart := FDataset.FieldByName('Start_Time').AsDateTime;
          dtCurrentEnd := ValueAsFloat(FDataset, 'End_Time', dtCurrentStart + dtDefaultMax);

          If (dtCurrentEnd < frmEventsReviewer.DataProvider.MinDateTime) Or
            (dtCurrentStart > frmEventsReviewer.DataProvider.MaxDateTime) Then
            FDataset.FieldByName('Colour_ID').AsString := 'clGray';
        End;

        FDataset.Post;
      Except
        On E: Exception Do
        Begin
          DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}, ' failed to load TVideoFile ',
            oVideo.Filename, ' ', oVideo.Folder, ' with error:', E.MEssage]);

          If FDataset.State In [dsInsert, dsEdit] Then
            FDataset.Cancel;
        End;
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

  If Not Assigned(FDataset) Then
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
      FormatDateTime('yyyy-mm-dd HH:nn:ss', oMessage.DateTime), INDENT_INC);
    Try
      DBSupport.GotoNearestValue(FDataset, 'Start_Time', oMessage.DateTime, SEEK_LAST_BEFORE);
    Finally
      frmEventsReviewer.SetStatusAndLog('Finished seek video file list', INDENT_DEC);
      frmEventsReviewer.Busy := False;
    End;
  End;
End;

End.
