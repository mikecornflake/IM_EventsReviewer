Unit FramePipelineEvents;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, FrameBase, PipelineEventMap, FramePipelineView,
  IMMessaging, AppMessaging;

Type

  { TfmePipelineEvents }

  TfmePipelineEvents = Class(TFrameBase)
  Private
    fmePipelineView: TFramePipelineView;

    Procedure DoReceiveSeekKPMessage(AMessage: TIMMessage);

    Procedure DoOnRangeClick(Sender: TObject; ARange: TPipelineEventRange; ATitle: String);
    Function GetKP: Double;
  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure LoadData;

    Procedure Clear;

    Property KP: Double Read GetKP;
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
  fmePipelineView.sbPipelineDisplay.Visible := False;

  fmePipelineView.OnRangeClick := @DoOnRangeClick;

  frmEventsReviewer.MessageBus.Subscribe(self, TIMMessageKP, @DoReceiveSeekKPMessage);
End;

Destructor TfmePipelineEvents.Destroy;
Begin
  FreeAndNil(fmePipelineView);

  Inherited Destroy;
End;

Procedure TfmePipelineEvents.LoadData;
Begin
  frmEventsReviewer.DataProvider.PopulatePipelineView(fmePipelineView);
End;

Procedure TfmePipelineEvents.Clear;
Begin
  fmePipelineView.Clear;
End;

Procedure TfmePipelineEvents.DoReceiveSeekKPMessage(AMessage: TIMMessage);
Begin
  If AMessage Is TIMMessageKP Then
    fmePipelineView.KP := TIMMessageKP(AMessage).KP;
End;

Procedure TfmePipelineEvents.DoOnRangeClick(Sender: TObject; ARange: TPipelineEventRange;
  ATitle: String);
Begin
  frmEventsReviewer.MessageBus.BroadcastKP(self, ARange.StartKP);
End;

Function TfmePipelineEvents.GetKP: Double;
Begin
  Result := fmePipelineView.KP;
End;

End.
