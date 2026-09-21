Unit DataProvider;

{$mode ObjFPC}{$H+}
{$interfaces corba}

Interface

Uses
  Classes, SysUtils, MediaTypes, DB, Inifiles;

Type
  TDataChangedEvent = Procedure(Sender: TObject; Const AAnomalyNo: String;
    Const ADateTime: TDateTime) Of Object;

  { IIM_Persistent }
  IIM_Persistent = Interface
    Procedure LoadSettings(AInifile: TIniFile);
    Procedure SaveSettings(AInifile: TIniFile);
  End;

  { IDataProvider }
  IDataProvider = Interface
    Function GetFiltered: Boolean;

    Procedure SetFilter(Const AValue: String);
    Function GetFilter: String;

    Function GetOnProviderReady: TNotifyEvent;
    Procedure SetOnProviderReady(AValue: TNotifyEvent);

    Function GetOnDataChanged: TDataChangedEvent;
    Procedure SetOnDataChanged(AValue: TDataChangedEvent);
    Function GetReady: Boolean;

    Function GetDataSet: TDataSet;
    Function GetFilteredDataSet: TDataSet;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles;
    Function DateTime: TDateTime;

    Function Open: Boolean;
    Function Refresh: Boolean;
    Function Close: Boolean;

    Function Title: String;

    Property Ready: Boolean Read GetReady;

    Property DataSet: TDataSet Read GetDataSet;

    Property FilteredDataSet: TDataSet Read GetFilteredDataSet;
    Property Filtered: Boolean Read GetFiltered;
    Property Filter: String Read GetFilter Write SetFilter;

    // Events
    Property OnProviderReady: TNotifyEvent Read GetOnProviderReady Write SetOnProviderReady;
    Property OnDataChanged: TDataChangedEvent Read GetOnDataChanged Write SetOnDataChanged;
  End;

  { TDataProvider }
  TDataProvider = Class(TObject, IDataProvider, IIM_Persistent)
  Protected
    // State
    FLoaded: Boolean;
    FFilter: String;

    FOnProviderReady: TNotifyEvent;
    FOnDataChanged: TDataChangedEvent;

    Function GetDataSet: TDataSet; Virtual; Abstract;
    Function GetFilteredDataSet: TDataSet; Virtual; Abstract;

    Function GetFiltered: Boolean;
    Procedure SetFilter(Const AValue: String); Virtual;
    Function GetFilter: String; Virtual;

    Procedure DoProviderReady;
    Procedure DoAnomalyChanged(Const AAnomalyNo: String; Const ADateTime: TDateTime);

    Function GetReady: Boolean; Virtual; Abstract;

    Function GetOnProviderReady: TNotifyEvent;
    Procedure SetOnProviderReady(AValue: TNotifyEvent);

    Function GetOnDataChanged: TDataChangedEvent;
    Procedure SetOnDataChanged(AValue: TDataChangedEvent);
  Public
    Function Open: Boolean; Virtual; Abstract;
    Function Refresh: Boolean; Virtual; Abstract;
    Function Close: Boolean; Virtual; Abstract;

    Function Title: String; Virtual; Abstract;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Virtual; Abstract;

    Function DateTime: TDateTime; Virtual; Abstract;
    Function AnomalyReference: String; Virtual; Abstract;

    Procedure LoadSettings(AInifile: TIniFile); Virtual; Abstract;
    Procedure SaveSettings(AInifile: TIniFile); Virtual; Abstract;

    // Properties
    Property Ready: Boolean Read GetReady;

    Property DataSet: TDataSet Read GetDataSet;

    Property FilteredDataSet: TDataSet Read GetFilteredDataSet;
    Property Filtered: Boolean Read GetFiltered;
    Property Filter: String Read FFilter Write SetFilter;

    // Events
    Property OnProviderReady: TNotifyEvent Read GetOnProviderReady Write SetOnProviderReady;
    Property OnDataChanged: TDataChangedEvent Read GetOnDataChanged Write SetOnDataChanged;
  End;

Implementation

{ TDataProvider }

Function TDataProvider.GetFiltered: Boolean;
Begin
  Result := Trim(FFilter) <> '';
End;

Procedure TDataProvider.SetFilter(Const AValue: String);
Begin
  FFilter := AValue;
End;

Function TDataProvider.GetFilter: String;
Begin
  Result := FFilter;
End;

Procedure TDataProvider.DoProviderReady;
Begin
  If Assigned(FOnProviderReady) Then
    FOnProviderReady(Self);
End;

Procedure TDataProvider.DoAnomalyChanged(Const AAnomalyNo: String; Const ADateTime: TDateTime);
Begin
  If Assigned(FOnDataChanged) Then
    FOnDataChanged(Self, AAnomalyNo, ADateTime);
End;

Function TDataProvider.GetOnProviderReady: TNotifyEvent;
Begin
  Result := FOnProviderReady;
End;

Procedure TDataProvider.SetOnProviderReady(AValue: TNotifyEvent);
Begin
  FOnProviderReady := AValue;
End;

Function TDataProvider.GetOnDataChanged: TDataChangedEvent;
Begin
  Result := FOnDataChanged;
End;

Procedure TDataProvider.SetOnDataChanged(AValue: TDataChangedEvent);
Begin
  FOnDataChanged := AValue;
End;

End.
