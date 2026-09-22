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
    Procedure DoReceiveDataProviderReady(AMessage: TIMMessage);
  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;
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

  frmEventsReviewer.MessageBus.Subscribe(self, TIMMessageKP, @DoReceiveSeekKPMessage);
  frmEventsReviewer.MessageBus.Subscribe(self, TIMMessageDataProviderReady,
    @DoReceiveDataProviderReady);
End;

Destructor TfmePipelineEvents.Destroy;
Begin
  FreeAndNil(fmePipelineView);

  Inherited Destroy;
End;

Procedure TfmePipelineEvents.DoReceiveSeekKPMessage(AMessage: TIMMessage);
Begin
  If AMessage Is TIMMessageKP Then
    fmePipelineView.KP := TIMMessageKP(AMessage).KP;
End;

Procedure TfmePipelineEvents.DoReceiveDataProviderReady(AMessage: TIMMessage);
Begin
   frmEventsReviewer.DataProvider.PopulatePipelineView(fmePipelineView);
End;

End.
