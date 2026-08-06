unit RadIA.Core.KnowledgePrivacy;

interface

uses
  RadIA.Core.Interfaces,
  RadIA.Core.Knowledge;

type
  TRadIAKnowledgePrivacyPolicy = class
  private
    class function IsListed(
      const AValue: string;
      const APatterns: string
    ): Boolean; static;
  public
    class function IsFileAllowed(
      const AConfig: IRadIAConfig;
      const AFileName: string
    ): Boolean; static;
    class function IsProjectAllowed(
      const AConfig: IRadIAConfig;
      const AProjectId: string
    ): Boolean; static;
  end;

  TRadIAConfigurableKnowledgeSource = class(
    TInterfacedObject,
    IRadIAKnowledgeSource
  )
  private
    FConfig: IRadIAConfig;
    FSource: IRadIAKnowledgeSource;
  public
    constructor Create(
      const AConfig: IRadIAConfig;
      const ASource: IRadIAKnowledgeSource
    );
    function GetProjectId: string;
    function ListSourceFiles: TArray<string>;
    function ReadSourceFile(
      const AFileName: string;
      out ADocument: TRadIAKnowledgeDocument
    ): Boolean;
  end;

  TRadIAConfigurableKnowledgeService = class(
    TInterfacedObject,
    IRadIAKnowledgeService
  )
  private
    FConfig: IRadIAConfig;
    FService: IRadIAKnowledgeService;
  public
    constructor Create(
      const AConfig: IRadIAConfig;
      const AService: IRadIAKnowledgeService
    );
    function GetCurrentProjectId: string;
    function GetStatus(
      const AProjectId: string
    ): TRadIAKnowledgeStatus;
    function GetDocument(
      const AProjectId: string;
      const AFileName: string;
      out ADocument: TRadIAIndexedKnowledgeDocument
    ): Boolean;
    function RefreshProject: TRadIAKnowledgeRefreshResult;
    function Search(
      const AProjectId: string;
      const AQuery: string;
      const AMaxResults: Integer
    ): TArray<TRadIAKnowledgeSearchHit>;
    procedure ClearProject(const AProjectId: string);
    procedure Clear;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  RadIA.Core.KnowledgeHistory;

constructor TRadIAConfigurableKnowledgeService.Create(
  const AConfig: IRadIAConfig;
  const AService: IRadIAKnowledgeService
);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise EArgumentNilException.Create('AConfig');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FConfig := AConfig;
  FService := AService;
end;

procedure TRadIAConfigurableKnowledgeService.Clear;
begin
  FService.Clear;
end;

procedure TRadIAConfigurableKnowledgeService.ClearProject(
  const AProjectId: string
);
begin
  FService.ClearProject(AProjectId);
end;

function TRadIAConfigurableKnowledgeService.GetCurrentProjectId: string;
begin
  Result := FService.GetCurrentProjectId;
end;

function TRadIAConfigurableKnowledgeService.GetDocument(
  const AProjectId: string;
  const AFileName: string;
  out ADocument: TRadIAIndexedKnowledgeDocument
): Boolean;
begin
  ADocument := Default(TRadIAIndexedKnowledgeDocument);
  if not TRadIAKnowledgePrivacyPolicy.IsProjectAllowed(
    FConfig,
    AProjectId
  ) then
    Exit(False);
  if not TRadIAKnowledgePrivacyPolicy.IsFileAllowed(
    FConfig,
    AFileName
  ) then
    Exit(False);
  if TRadIAApprovedHistoryKnowledgeSource.IsHistoryDocument(
    AFileName
  ) and not FConfig.KnowledgeApprovedHistoryEnabled then
    Exit(False);
  Result := FService.GetDocument(AProjectId, AFileName, ADocument);
end;

function TRadIAConfigurableKnowledgeService.GetStatus(
  const AProjectId: string
): TRadIAKnowledgeStatus;
begin
  if not TRadIAKnowledgePrivacyPolicy.IsProjectAllowed(
    FConfig,
    AProjectId
  ) then
    Exit(TRadIAKnowledgeStatus.Create(AProjectId, False, 0, 0));
  Result := FService.GetStatus(AProjectId);
end;

function TRadIAConfigurableKnowledgeService.RefreshProject:
  TRadIAKnowledgeRefreshResult;
begin
  Result := FService.RefreshProject;
end;

function TRadIAConfigurableKnowledgeService.Search(
  const AProjectId: string;
  const AQuery: string;
  const AMaxResults: Integer
): TArray<TRadIAKnowledgeSearchHit>;
var
  LHit: TRadIAKnowledgeSearchHit;
  LHits: TList<TRadIAKnowledgeSearchHit>;
begin
  if not TRadIAKnowledgePrivacyPolicy.IsProjectAllowed(
    FConfig,
    AProjectId
  ) then
    Exit(nil);
  LHits := TList<TRadIAKnowledgeSearchHit>.Create;
  try
    for LHit in FService.Search(AProjectId, AQuery, AMaxResults) do
    begin
      if TRadIAKnowledgePrivacyPolicy.IsFileAllowed(
        FConfig,
        LHit.Chunk.FileName
      ) and (
        FConfig.KnowledgeApprovedHistoryEnabled or
        not TRadIAApprovedHistoryKnowledgeSource.IsHistoryDocument(
          LHit.Chunk.FileName
        )
      ) then
        LHits.Add(LHit);
    end;
    Result := LHits.ToArray;
  finally
    LHits.Free;
  end;
end;

constructor TRadIAConfigurableKnowledgeSource.Create(
  const AConfig: IRadIAConfig;
  const ASource: IRadIAKnowledgeSource
);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise EArgumentNilException.Create('AConfig');
  if not Assigned(ASource) then
    raise EArgumentNilException.Create('ASource');
  FConfig := AConfig;
  FSource := ASource;
end;

function TRadIAConfigurableKnowledgeSource.GetProjectId: string;
begin
  Result := FSource.GetProjectId;
end;

function TRadIAConfigurableKnowledgeSource.ListSourceFiles:
  TArray<string>;
var
  LFileName: string;
  LFiles: TList<string>;
  LProjectId: string;
begin
  LProjectId := GetProjectId;
  if not TRadIAKnowledgePrivacyPolicy.IsProjectAllowed(
    FConfig,
    LProjectId
  ) then
    Exit(nil);
  LFiles := TList<string>.Create;
  try
    for LFileName in FSource.ListSourceFiles do
    begin
      if TRadIAKnowledgePrivacyPolicy.IsFileAllowed(
        FConfig,
        LFileName
      ) then
        LFiles.Add(LFileName);
    end;
    Result := LFiles.ToArray;
  finally
    LFiles.Free;
  end;
end;

function TRadIAConfigurableKnowledgeSource.ReadSourceFile(
  const AFileName: string;
  out ADocument: TRadIAKnowledgeDocument
): Boolean;
begin
  ADocument := Default(TRadIAKnowledgeDocument);
  if not TRadIAKnowledgePrivacyPolicy.IsProjectAllowed(
    FConfig,
    GetProjectId
  ) then
    Exit(False);
  if not TRadIAKnowledgePrivacyPolicy.IsFileAllowed(
    FConfig,
    AFileName
  ) then
    Exit(False);
  Result := FSource.ReadSourceFile(AFileName, ADocument);
end;

class function TRadIAKnowledgePrivacyPolicy.IsFileAllowed(
  const AConfig: IRadIAConfig;
  const AFileName: string
): Boolean;
begin
  Result := Assigned(AConfig) and
    not IsListed(AFileName, AConfig.KnowledgeExcludedFiles);
end;

class function TRadIAKnowledgePrivacyPolicy.IsListed(
  const AValue: string;
  const APatterns: string
): Boolean;
var
  LItem: string;
  LItems: TArray<string>;
  LNormalizedItem: string;
  LNormalizedValue: string;
begin
  Result := False;
  LNormalizedValue := AValue.Trim.ToLower;
  if LNormalizedValue.IsEmpty or APatterns.Trim.IsEmpty then
    Exit;
  LItems := APatterns.Replace(',', ';')
    .Replace(#13, ';')
    .Replace(#10, ';')
    .Split([';']);
  for LItem in LItems do
  begin
    LNormalizedItem := LItem.Trim.ToLower;
    if not LNormalizedItem.IsEmpty and
      LNormalizedValue.Contains(LNormalizedItem) then
      Exit(True);
  end;
end;

class function TRadIAKnowledgePrivacyPolicy.IsProjectAllowed(
  const AConfig: IRadIAConfig;
  const AProjectId: string
): Boolean;
begin
  Result := Assigned(AConfig) and
    not IsListed(AProjectId, AConfig.KnowledgeExcludedProjects);
end;

end.
