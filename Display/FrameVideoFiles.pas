Unit FrameVideoFiles;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, FrameBase, FrameGrids,
  BufDataset, DB, MediaTypes;

Type

  { TfmeVideoFiles }

  TfmeVideoFiles = Class(TFrameBase)
  Private
    FDataset: TBufDataset;
    fmeGrid: TFrameGrid;

  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure Load(AVideoFiles: TVideoFiles);
    Procedure Clear;
  End;

Implementation

Uses
  FormMain, DBSupport;

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
End;

Destructor TfmeVideoFiles.Destroy;
Begin
  FreeAndNil(fmeGrid);

  If FDataset.Active Then
    FDataset.Close;

  FreeAndNil(FDataset);
  Inherited Destroy;
End;

Procedure TfmeVideoFiles.Load(AVideoFiles: TVideoFiles);
Var
  oVideo: TVideoFile;
Begin
  MainForm.Busy := True;
  MainForm.Status:='Loading video files';
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
    MainForm.Status:='Finished loading video files';
    MainForm.Status:='';
    MainForm.Busy := False;
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

End.
