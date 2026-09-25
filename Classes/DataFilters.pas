Unit DataFilters;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, fgl;

Type

  { TDataFilter }

  TDataFilter = Class
  Private
    FCaption: String;
    FFilter: String;
    FImageIndex: Integer;
    FOnExecute: TNotifyEvent;
    Procedure SetOnExecute(Const AValue: TNotifyEvent);
  Public
    Constructor Create(AImageIndex: Integer; ACaption: String; AFilter: String;
      ACallback: TNotifyEvent);

    Property ImageIndex: Integer Read FImageIndex Write FImageIndex;
    Property Caption: String Read FCaption Write FCaption;
    Property Filter: String Read FFilter Write FFilter;

    Property OnExecute: TNotifyEvent Read FOnExecute Write SetOnExecute;
  End;

  { TDataFilters }
  TDataFilters = Class(Specialize TFPGObjectList<TDataFilter>);

Implementation

{ TDataFilter }

Procedure TDataFilter.SetOnExecute(Const AValue: TNotifyEvent);
Begin
  If FOnExecute = AValue Then Exit;
  FOnExecute := AValue;
End;

Constructor TDataFilter.Create(AImageIndex: Integer; ACaption: String;
  AFilter: String; ACallback: TNotifyEvent);
Begin
  FImageIndex := AImageIndex;
  FCaption := ACaption;
  FFilter := AFilter;
  FOnExecute := ACallback;
End;

End.
