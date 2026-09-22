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

  TIMMessageDataProviderReady = Class(TIMMessage);
  TIMMessageFilterChanged = Class(TIMMessage);

  { TMessageController }

  { TAppMessageBus }

  TAppMessageBus = Class(TMessageBus)
  Public
    Procedure BroadcastTime(ASender: TObject; ADateTime: TDateTime);
    Procedure BroadcastKP(ASender: TObject; AKP: Extended);
  End;

Implementation

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
