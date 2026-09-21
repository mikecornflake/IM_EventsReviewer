Unit FramePipelineEvents;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, FrameBase, PipelineEventMap, FramePipelineView,
  IMMessaging, AppMessaging, DB;

Type

  { TfmePipelineEvents }

  TfmePipelineEvents = Class(TFrameBase)
  Private
    FDataset: TDataset;
    fmePipelineView: TFramePipelineView;

    Procedure ClearData;
    Procedure DoReceiveSeekKPMessage(AMessage: TIMMessage);
    Procedure DoReceiveDataProviderReady(AMessage: TIMMessage);
    Procedure LoadData;
    Procedure SetDataset(Const AValue: TDataset);
  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Property Dataset: TDataset Read FDataset Write SetDataset;
  End;

Implementation

Uses
  FormEventsReviewer, LazLogger;

  {$R *.lfm}

  { TfmePipelineEvents }

Constructor TfmePipelineEvents.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);

  fmePipelineView := TFramePipelineView.Create(self);
  fmePipelineView.Parent := self;
  fmePipelineView.Align := alClient;
  fmePipelineView.GraphMode := pdStartLength;

  FDataset := nil;

  frmEventsReviewer.MessageBus.Subscribe(self, TIMMessageKP, @DoReceiveSeekKPMessage);
  frmEventsReviewer.MessageBus.Subscribe(self, TIMMessageDataProviderReady,
    @DoReceiveDataProviderReady);
End;

Destructor TfmePipelineEvents.Destroy;
Begin
  FreeAndNil(fmePipelineView);

  Inherited Destroy;
End;

Procedure TfmePipelineEvents.SetDataset(Const AValue: TDataset);
Begin
  If FDataset = AValue Then
    Exit;

  FDataset := AValue;
End;

Procedure TfmePipelineEvents.LoadData;
Var
  bmOriginal: TBookMark;
  oKP, oLen, oType, oAnom: TField;
  sType: String;
  dKP, dLen: Extended;
Begin
  If Not FDataset.Active Then
    Exit;

  ClearData;

  frmEventsReviewer.Status := 'Loading chart';

  oKP := FDataset.FieldByName('KP');
  oLen := FDataset.FieldByName('Length_(m)');
  oType := FDataset.FieldByName('Type');
  oAnom := FDataset.FieldByName('Anomaly');

  FDataset.DisableControls;
  bmOriginal := FDataset.GetBookmark;
  Try
    FDataset.First;
    fmePipelineView.BeginUpdate;

    While Not FDataset.EOF Do
    Begin
      sType := oType.AsString;
      dKP := oKP.AsExtended;
      If (oLen.IsNull) Or (oLen.AsFloat <= 1) Then
        dLen := 0.001
      Else
        dLen := oLen.AsFloat / 1000;

      If sType.Contains(' Joint') Then
        sType := 'Fieldjoint';

      If Not sType.Contains(' End') Then
        fmePipelineView.AddData(sType, dKP, dLen, (oAnom.AsString = 'Y'));

      FDataset.Next;
    End;
    FDataset.GotoBookmark(bmOriginal);
  Finally
    FDataset.FreeBookmark(bmOriginal);
    FDataset.EnableControls;
    fmePipelineView.EndUpdate;

    frmEventsReviewer.Status := '';
  End;
End;

Procedure TfmePipelineEvents.ClearData;
Begin
  fmePipelineView.Clear;
End;


Procedure TfmePipelineEvents.DoReceiveSeekKPMessage(AMessage: TIMMessage);
Begin
  If AMessage Is TIMMessageKP Then
    fmePipelineView.KP := TIMMessageKP(AMessage).KP;
End;

Procedure TfmePipelineEvents.DoReceiveDataProviderReady(AMessage: TIMMessage);
Begin
  LoadData;
End;

End.
