Unit DataProvider;

{$mode ObjFPC}{$H+}
{$interfaces corba}

Interface

Uses
  Classes, SysUtils, MediaTypes, DB, Inifiles;

Type
  TAnomalyChangedEvent = Procedure(Sender: TObject; Const AAnomalyNo: String;
    Const ADateTime: TDateTime) Of Object;

  { IIM_Persistent }
  IIM_Persistent = Interface
    Procedure LoadSettings(AInifile: TIniFile);
    Procedure SaveSettings(AInifile: TIniFile);
  End;


  { IAnomalyProvider }
  IAnomalyProvider = Interface
    Function GetOnProviderReady: TNotifyEvent;
    Procedure SetOnProviderReady(AValue: TNotifyEvent);

    Function GetOnAnomalyChanged: TAnomalyChangedEvent;
    Procedure SetOnAnomalyChanged(AValue: TAnomalyChangedEvent);
    Function GetReady: Boolean;

    Function GetAnomalyDataSet: TDataSet;

    // TODO Think long and hard - should these be here?
    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
    Function AnomalyDateTime: TDateTime;

    Function Open: Boolean;

    Function Title: String;

    // Properties
    Property AnomalyDataSet: TDataSet Read GetAnomalyDataSet;
    Property Ready: Boolean Read GetReady;

    // Events
    Property OnProviderReady: TNotifyEvent Read GetOnProviderReady Write SetOnProviderReady;
    Property OnAnomalyChanged: TAnomalyChangedEvent Read GetOnAnomalyChanged
      Write SetOnAnomalyChanged;
  End;

  { TDataProvider }
  TDataProvider = Class(TObject, IAnomalyProvider, IIM_Persistent)
  Protected
    FOnProviderReady: TNotifyEvent;
    FOnAnomalyChanged: TAnomalyChangedEvent;

    Function GetAnomalyDataSet: TDataSet; Virtual; Abstract;

    Procedure DoProviderReady;
    Procedure DoAnomalyChanged(Const AAnomalyNo: String; Const ADateTime: TDateTime);

    Function GetReady: Boolean; Virtual; Abstract;

    Function GetOnProviderReady: TNotifyEvent;
    Procedure SetOnProviderReady(AValue: TNotifyEvent);

    Function GetOnAnomalyChanged: TAnomalyChangedEvent;
    Procedure SetOnAnomalyChanged(AValue: TAnomalyChangedEvent);
  Public
    Function Open: Boolean; Virtual; Abstract;

    Function Title: String; Virtual; Abstract;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Virtual; Abstract;
    Function AnomalyDateTime: TDateTime; Virtual; Abstract;

    Property AnomalyDataSet: TDataSet Read GetAnomalyDataSet;

    Procedure LoadSettings(AInifile: TIniFile); Virtual; Abstract;
    Procedure SaveSettings(AInifile: TIniFile); Virtual; Abstract;

    // Properties
    Property Ready: Boolean Read GetReady;

    // Events
    Property OnProviderReady: TNotifyEvent Read GetOnProviderReady Write SetOnProviderReady;
    Property OnAnomalyChanged: TAnomalyChangedEvent Read GetOnAnomalyChanged
      Write SetOnAnomalyChanged;
  End;

Implementation

{ TDataProvider }

Procedure TDataProvider.DoProviderReady;
Begin
  If Assigned(FOnProviderReady) Then
    FOnProviderReady(Self);
End;

Procedure TDataProvider.DoAnomalyChanged(Const AAnomalyNo: String; Const ADateTime: TDateTime);
Begin
  If Assigned(FOnAnomalyChanged) Then
    FOnAnomalyChanged(Self, AAnomalyNo, ADateTime);
End;

Function TDataProvider.GetOnProviderReady: TNotifyEvent;
Begin
  Result := FOnProviderReady;
End;

Procedure TDataProvider.SetOnProviderReady(AValue: TNotifyEvent);
Begin
  FOnProviderReady := AValue;
End;

Function TDataProvider.GetOnAnomalyChanged: TAnomalyChangedEvent;
Begin
  Result := FOnAnomalyChanged;
End;

Procedure TDataProvider.SetOnAnomalyChanged(AValue: TAnomalyChangedEvent);
Begin
  FOnAnomalyChanged := AValue;
End;

End.
