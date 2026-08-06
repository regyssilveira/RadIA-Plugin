unit RadIA.Tests.KnowledgeEmbeddingSelection;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Knowledge,
  RadIA.Core.KnowledgeEmbeddingSelection;

type
  TTestEmbeddingProvider = class(
    TInterfacedObject,
    IRadIAKnowledgeEmbeddingProvider
  )
  private
    FId: string;
    FIsLocal: Boolean;
  public
    constructor Create(const AId: string; const AIsLocal: Boolean);
    function Embed(const AText: string): TArray<Single>;
    function GetDimensions: Integer;
    function GetId: string;
    function IsLocal: Boolean;
  end;

  TTestRemoteEmbeddingSettings = class(
    TInterfacedObject,
    IRadIAKnowledgeEmbeddingRemoteSettings
  )
  private
    FConsentGranted: Boolean;
    FCreateSucceeds: Boolean;
    FEnabled: Boolean;
    FProvider: IRadIAKnowledgeEmbeddingProvider;
  public
    function GetConsentGranted: Boolean;
    function GetEnabled: Boolean;
    function TryCreateProvider(
      out AProvider: IRadIAKnowledgeEmbeddingProvider
    ): Boolean;
    property ConsentGranted: Boolean
      read FConsentGranted write FConsentGranted;
    property CreateSucceeds: Boolean
      read FCreateSucceeds write FCreateSucceeds;
    property Enabled: Boolean read FEnabled write FEnabled;
    property Provider: IRadIAKnowledgeEmbeddingProvider
      read FProvider write FProvider;
  end;

  [TestFixture]
  TTestKnowledgeEmbeddingSelector = class
  private
    FLocal: IRadIAKnowledgeEmbeddingProvider;
    FRemote: IRadIAKnowledgeEmbeddingProvider;
    FSettings: TTestRemoteEmbeddingSettings;
    FSelector: IRadIAKnowledgeEmbeddingProvider;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure DefaultsToLocalWhenRemoteIsDisabled;
    [Test]
    procedure RejectsRemoteWithoutSeparateConsent;
    [Test]
    procedure UsesRemoteOnlyWhenEnabledAndConsented;
    [Test]
    procedure FallsBackToLocalWhenRemoteCreationFails;
  end;

implementation

constructor TTestEmbeddingProvider.Create(
  const AId: string;
  const AIsLocal: Boolean
);
begin
  inherited Create;
  FId := AId;
  FIsLocal := AIsLocal;
end;

function TTestEmbeddingProvider.Embed(
  const AText: string
): TArray<Single>;
begin
  Result := [Length(AText)];
end;

function TTestEmbeddingProvider.GetDimensions: Integer;
begin
  Result := 1;
end;

function TTestEmbeddingProvider.GetId: string;
begin
  Result := FId;
end;

function TTestEmbeddingProvider.IsLocal: Boolean;
begin
  Result := FIsLocal;
end;

function TTestRemoteEmbeddingSettings.GetConsentGranted: Boolean;
begin
  Result := FConsentGranted;
end;

function TTestRemoteEmbeddingSettings.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

function TTestRemoteEmbeddingSettings.TryCreateProvider(
  out AProvider: IRadIAKnowledgeEmbeddingProvider
): Boolean;
begin
  AProvider := nil;
  Result := FCreateSucceeds;
  if Result then
    AProvider := FProvider;
end;

procedure TTestKnowledgeEmbeddingSelector.Setup;
var
  LSettings: IRadIAKnowledgeEmbeddingRemoteSettings;
begin
  FLocal := TTestEmbeddingProvider.Create('local', True);
  FRemote := TTestEmbeddingProvider.Create('remote', False);
  FSettings := TTestRemoteEmbeddingSettings.Create;
  FSettings.Provider := FRemote;
  FSettings.CreateSucceeds := True;
  LSettings := FSettings;
  FSelector := TRadIAKnowledgeEmbeddingSelector.Create(FLocal, LSettings);
end;

procedure TTestKnowledgeEmbeddingSelector.DefaultsToLocalWhenRemoteIsDisabled;
begin
  FSettings.ConsentGranted := True;

  Assert.AreEqual('local', FSelector.GetId);
  Assert.IsTrue(FSelector.IsLocal);
end;

procedure TTestKnowledgeEmbeddingSelector.FallsBackToLocalWhenRemoteCreationFails;
begin
  FSettings.Enabled := True;
  FSettings.ConsentGranted := True;
  FSettings.CreateSucceeds := False;

  Assert.AreEqual('local', FSelector.GetId);
end;

procedure TTestKnowledgeEmbeddingSelector.RejectsRemoteWithoutSeparateConsent;
begin
  FSettings.Enabled := True;

  Assert.AreEqual('local', FSelector.GetId);
  Assert.IsTrue(FSelector.IsLocal);
end;

procedure TTestKnowledgeEmbeddingSelector.UsesRemoteOnlyWhenEnabledAndConsented;
begin
  FSettings.Enabled := True;
  FSettings.ConsentGranted := True;

  Assert.AreEqual('remote', FSelector.GetId);
  Assert.IsFalse(FSelector.IsLocal);
  Assert.AreEqual<Single>(4, FSelector.Embed('test')[0]);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestKnowledgeEmbeddingSelector);

end.
