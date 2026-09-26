Unit CampaignRules;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, fgl, IniFiles;

Type

  { TCampaignEventRule }

  TCampaignEventRule = Class
  Private
    FDisplayName: String;
    FInclude: TStringList;
    FExclude: TStringList;
  Public
    Constructor Create;
    Destructor Destroy; Override;

    // Returns True if this Rule is to be used
    Function TestEventname(AEventname: String): Boolean;

    // If Event name contains any of these, then use this rule
    Property IncludeKeywords: TStringList Read FInclude;

    // If Event name then includes of these keywords, no longer use the rule
    Property ExcludeKeywords: TStringList Read FExclude;

    // If the rule is to be used then use this instead of Eventname
    Property DisplayName: String Read FDisplayName Write FDisplayName;
  End;

  { TCampaignEventRules }

  TCampaignEventRules = Class(Specialize TFPGObjectList<TCampaignEventRule>)
  Public
    Function ProcessedEventname(AEventname: String): String;

    // Make a COPY of the Source
    Procedure CopyFrom(ASource: TCampaignEventRules);

    Procedure LoadSettings(AInifile: TInifile; ASectionPrefix: String);
    Procedure SaveSettings(AInifile: TInifile; ASectionPrefix: String);
  End;



Implementation

{ TCampaignEventRule }

Constructor TCampaignEventRule.Create;
Begin
  Inherited Create;

  FInclude := TStringList.Create;
  FExclude := TStringList.Create;
End;

Destructor TCampaignEventRule.Destroy;
Begin
  FreeAndNil(FExclude);
  FreeAndNil(FInclude);

  Inherited Destroy;
End;

Function TCampaignEventRule.TestEventname(AEventname: String): Boolean;
Var
  sKeyword: String;
Begin
  Result := False;

  For sKeyword In FInclude Do
    If AEventname.Contains(sKeyword, True) Then
    Begin
      Result := True;
      Break;
    End;

  If Not Result Then
    Exit;

  For sKeyword In FExclude Do
    If AEventname.Contains(sKeyword, True) Then
      Exit(False);
End;

{ TCampaignEventRules }

Function TCampaignEventRules.ProcessedEventname(AEventname: String): String;
Var
  oRule: TCampaignEventRule;
Begin
  Result := AEventname;

  For oRule In Self Do
    If oRule.TestEventname(AEventname) Then
    Begin
      Result := oRule.DisplayName;
      Break;
    End;
End;

// Makes a COPY of the Source,
Procedure TCampaignEventRules.CopyFrom(ASource: TCampaignEventRules);
Var
  oSourceRule, oRuleCopy: TCampaignEventRule;
Begin
  Clear;

  For oSourceRule In ASource Do
  Begin
    oRuleCopy := TCampaignEventRule.Create;
    Try
      oRuleCopy.DisplayName := oSourceRule.DisplayName;
      oRuleCopy.IncludeKeywords.CommaText := oSourceRule.IncludeKeywords.CommaText;
      oRuleCopy.ExcludeKeywords.CommaText := oSourceRule.ExcludeKeywords.CommaText;

      Add(oRuleCopy);
      oRuleCopy := nil; // List now owns it
    Finally
      oRuleCopy.Free;
    End;
  End;
End;

Procedure TCampaignEventRules.LoadSettings(AInifile: TInifile; ASectionPrefix: String);
Var
  i, iCount: Integer;
  sSection: String;
  oRule: TCampaignEventRule;
Begin
  Clear;

  iCount := AInifile.ReadInteger(ASectionPrefix, 'Count', 0);

  For i := 0 To iCount - 1 Do
  Begin
    sSection := ASectionPrefix + '.Rule' + i.ToString;

    oRule := TCampaignEventRule.Create;
    Try
      oRule.DisplayName := AInifile.ReadString(sSection, 'DisplayName', '');
      oRule.IncludeKeywords.CommaText := AInifile.ReadString(sSection, 'Include', '');
      oRule.ExcludeKeywords.CommaText := AInifile.ReadString(sSection, 'Exclude', '');

      Add(oRule);
      oRule := nil; // List now owns it
    Finally
      oRule.Free;
    End;
  End;
End;

Procedure TCampaignEventRules.SaveSettings(AInifile: TInifile; ASectionPrefix: String);
Var
  i: Integer;
  sSection: String;
  oRule: TCampaignEventRule;
Begin
  AInifile.WriteInteger(ASectionPrefix, 'Count', Count);

  For i := 0 To Count - 1 Do
  Begin
    oRule := Items[i];
    sSection := ASectionPrefix + '.Rule' + i.ToString;

    AInifile.WriteString(sSection, 'DisplayName', oRule.DisplayName);
    AInifile.WriteString(sSection, 'Include', oRule.IncludeKeywords.CommaText);
    AInifile.WriteString(sSection, 'Exclude', oRule.ExcludeKeywords.CommaText);
  End;
End;

End.
