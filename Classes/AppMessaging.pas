Unit AppMessaging;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, IMMessaging;

Type
  { TIMMessageTime }

  TIMMessageTime = Class(TIMMessage)
  Public
    DateTime: TDateTime;
  End;

  { TIMMessageKP }

  TIMMessageKP = Class(TIMMessage)
  Public
    KP: Extended;
  End;

  { TIMMessageVideosLoaded }

  TIMMessageVideosLoaded = Class(TIMMessage)
  Public
    StartDateTime, EndDateTime, PendingSeekDateTime: TDateTime
  End;

  TIMMessageDataProviderReady = Class(TIMMessage);
  TIMMessageFilterChanged = Class(TIMMessage);
  TIMMessageVideosUnLoaded = Class(TIMMessage);

  { TMessageController }

  { TAppMessageBus }

  TAppMessageBus = Class(TMessageBus)
  Public
    Procedure BroadcastVideosLoaded(ASender: TObject;
      AStartDateTime, AEndDateTime, APendingSeekTime: TDateTime);
    Procedure BroadcastTime(ASender: TObject; ADateTime: TDateTime);
    Procedure BroadcastKP(ASender: TObject; AKP: Extended);
  End;

Implementation

Procedure TAppMessageBus.BroadcastVideosLoaded(ASender: TObject;
  AStartDateTime, AEndDateTime, APendingSeekTime: TDateTime);
Var
  oMessage: TIMMessageVideosLoaded;
Begin
  oMessage := TIMMessageVideosLoaded.Create;
  Try
    oMessage.Sender := ASender;
    oMessage.StartDateTime := AStartDateTime;
    oMessage.EndDateTime := AEndDateTime;
    oMessage.PendingSeekDateTime := APendingSeekTime;

    Broadcast(oMessage);
  Finally
    oMessage.Free;
  End;
End;

Procedure TAppMessageBus.BroadcastTime(ASender: TObject; ADateTime: TDateTime);
Var
  oMessage: TIMMessageTime;
Begin
  oMessage := TIMMessageTime.Create;
  Try
    oMessage.Sender := ASender;
    oMessage.DateTime := ADateTime;

    Broadcast(oMessage);
  Finally
    oMessage.Free;
  End;
End;

Procedure TAppMessageBus.BroadcastKP(ASender: TObject; AKP: Extended);
Var
  oMessage: TIMMessageKP;
Begin
  oMessage := TIMMessageKP.Create;
  Try
    oMessage.Sender := ASender;
    oMessage.KP := AKP;

    Broadcast(oMessage);
  Finally
    oMessage.Free;
  End;
End;


End.
