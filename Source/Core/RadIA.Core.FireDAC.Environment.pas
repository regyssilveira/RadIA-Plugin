unit RadIA.Core.FireDAC.Environment;

interface

uses
  System.Generics.Collections,
  RadIA.Core.FireDAC.Configuration,
  RadIA.Core.FireDAC.Model;

type
  TRadIAFireDACEnvironmentAnalysis = class
  private
    FDriverIds: TList<string>;
    FDriverLinks: TList<string>;
    FFindings: TList<TRadIAFireDACFinding>;
    function Contains(const AValues: TList<string>; const AValue: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    procedure AnalyzeEntries(const AEntries: TArray<TRadIAFireDACConfigurationEntry>);
    function ToJson: string;
  end;

implementation

uses
  System.JSON,
  System.RegularExpressions,
  System.SysUtils;

constructor TRadIAFireDACEnvironmentAnalysis.Create;
begin
  inherited Create;
  FDriverIds := TList<string>.Create;
  FDriverLinks := TList<string>.Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
end;

destructor TRadIAFireDACEnvironmentAnalysis.Destroy;
begin
  FFindings.Free;
  FDriverLinks.Free;
  FDriverIds.Free;
  inherited;
end;

procedure TRadIAFireDACEnvironmentAnalysis.AddFinding(const AFinding: TRadIAFireDACFinding);
begin
  if FFindings.Count < CRadIAFireDACMaximumFindings then
    FFindings.Add(AFinding);
end;

function TRadIAFireDACEnvironmentAnalysis.Contains(
  const AValues: TList<string>;
  const AValue: string
): Boolean;
var
  LValue: string;
begin
  Result := False;
  for LValue in AValues do
    if SameText(LValue, AValue) then
      Exit(True);
end;

function DriverIdFromClass(const AClassName: string): string;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AClassName, '(?i)^TFDPhys([A-Za-z0-9_]+)DriverLink$');
  if LMatch.Success then
    Result := LMatch.Groups[1].Value
  else
    Result := '';
end;

procedure TRadIAFireDACEnvironmentAnalysis.AnalyzeEntries(
  const AEntries: TArray<TRadIAFireDACConfigurationEntry>
);
var
  LDriverId: string;
  LEntry: TRadIAFireDACConfigurationEntry;
begin
  for LEntry in AEntries do
  begin
    if LEntry.Kind = fcfgDriverLink then
      LDriverId := DriverIdFromClass(LEntry.ComponentClassName)
    else
      LDriverId := LEntry.DriverId;
    if LDriverId.IsEmpty then
      Continue;
    if LEntry.Kind = fcfgDriverLink then
    begin
      if not Contains(FDriverLinks, LDriverId) then
        FDriverLinks.Add(LDriverId);
    end
    else if not Contains(FDriverIds, LDriverId) then
      FDriverIds.Add(LDriverId);
  end;
end;

function TRadIAFireDACEnvironmentAnalysis.ToJson: string;
var
  LArray: TJSONArray;
  LDriverId: string;
  LFinding: TRadIAFireDACFinding;
  LRoot: TJSONObject;
begin
  for LDriverId in FDriverIds do
    if not Contains(FDriverLinks, LDriverId) then
      AddFinding(TRadIAFireDACFinding.Create(
        'firedac.environment.driver-link-not-declared',
        ffsInfo,
        ffcInformational,
        'FireDAC driver link is not declared in the project',
        'Static analysis found a DriverID without a matching physical driver-link component.',
        TRadIAFireDACFindingDetails.Create(
          TRadIAFireDACLocation.Create('', 0),
          LDriverId,
          'DriverID ' + LDriverId + ' has no matching project driver link.',
          'Confirm runtime driver availability or add the appropriate FireDAC driver-link unit.',
          False
        )
      ));
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    for LDriverId in FDriverIds do
      LArray.Add(LDriverId);
    LRoot.AddPair('configuredDriverIds', LArray);
    LArray := TJSONArray.Create;
    for LDriverId in FDriverLinks do
      LArray.Add(LDriverId);
    LRoot.AddPair('declaredDriverLinks', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(RadIAFireDACFindingToJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('verificationScope', 'static-project-configuration');
    LRoot.AddPair('connectionAttempted', TJSONBool.Create(False));
    LRoot.AddPair('driverInstallationAttempted', TJSONBool.Create(False));
    LRoot.AddPair('credentialsCollected', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

end.
