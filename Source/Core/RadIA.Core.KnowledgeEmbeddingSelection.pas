unit RadIA.Core.KnowledgeEmbeddingSelection;

interface

uses
  RadIA.Core.Knowledge;

type
  IRadIAKnowledgeEmbeddingRemoteSettings = interface
    ['{77E93E91-C426-4F75-829C-EE30A13F68D0}']
    function GetConsentGranted: Boolean;
    function GetEnabled: Boolean;
    function TryCreateProvider(
      out AProvider: IRadIAKnowledgeEmbeddingProvider
    ): Boolean;
  end;

  TRadIAKnowledgeEmbeddingSelector = class(
    TInterfacedObject,
    IRadIAKnowledgeEmbeddingProvider
  )
  private
    FLocalProvider: IRadIAKnowledgeEmbeddingProvider;
    FRemoteSettings: IRadIAKnowledgeEmbeddingRemoteSettings;
    function SelectProvider: IRadIAKnowledgeEmbeddingProvider;
  public
    constructor Create(
      const ALocalProvider: IRadIAKnowledgeEmbeddingProvider;
      const ARemoteSettings: IRadIAKnowledgeEmbeddingRemoteSettings
    );
    function Embed(const AText: string): TArray<Single>;
    function GetDimensions: Integer;
    function GetId: string;
    function IsLocal: Boolean;
  end;

implementation

uses
  System.SysUtils;

constructor TRadIAKnowledgeEmbeddingSelector.Create(
  const ALocalProvider: IRadIAKnowledgeEmbeddingProvider;
  const ARemoteSettings: IRadIAKnowledgeEmbeddingRemoteSettings
);
begin
  inherited Create;
  if not Assigned(ALocalProvider) then
    raise EArgumentNilException.Create('ALocalProvider');
  if not Assigned(ARemoteSettings) then
    raise EArgumentNilException.Create('ARemoteSettings');
  FLocalProvider := ALocalProvider;
  FRemoteSettings := ARemoteSettings;
end;

function TRadIAKnowledgeEmbeddingSelector.Embed(
  const AText: string
): TArray<Single>;
begin
  Result := SelectProvider.Embed(AText);
end;

function TRadIAKnowledgeEmbeddingSelector.GetDimensions: Integer;
begin
  Result := SelectProvider.GetDimensions;
end;

function TRadIAKnowledgeEmbeddingSelector.GetId: string;
begin
  Result := SelectProvider.GetId;
end;

function TRadIAKnowledgeEmbeddingSelector.IsLocal: Boolean;
begin
  Result := SelectProvider.IsLocal;
end;

function TRadIAKnowledgeEmbeddingSelector.SelectProvider:
  IRadIAKnowledgeEmbeddingProvider;
var
  LRemoteProvider: IRadIAKnowledgeEmbeddingProvider;
begin
  Result := FLocalProvider;
  if not FRemoteSettings.GetEnabled then
    Exit;
  if not FRemoteSettings.GetConsentGranted then
    Exit;
  if FRemoteSettings.TryCreateProvider(LRemoteProvider) and
    Assigned(LRemoteProvider) then
    Result := LRemoteProvider;
end;

end.
