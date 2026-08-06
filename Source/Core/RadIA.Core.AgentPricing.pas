unit RadIA.Core.AgentPricing;

interface

uses
  System.JSON;

type
  TRadIAAgentPricing = record
  private
    FProvider: string;
    FModel: string;
    FInputUsdPerMillionTokens: Double;
    FOutputUsdPerMillionTokens: Double;
  public
    constructor Create(
      const AProvider: string;
      const AModel: string;
      const AInputUsdPerMillionTokens: Double;
      const AOutputUsdPerMillionTokens: Double
    );
    function EstimateCostMicros(
      const APromptTokens: Integer;
      const ACompletionTokens: Integer
    ): Int64;
    function IsConfigured: Boolean;
  end;

  TRadIAAgentPricingCatalog = class
  private
    FFileName: string;
    FDefaultRunBudgetMicros: Int64;
    procedure LoadCatalogSettings(const ARoot: TJSONObject);
    function PricingMatches(
      const AItem: TJSONObject;
      const AProvider: string;
      const AModel: string;
      const AExactModel: Boolean
    ): Boolean;
    function TryResolvePass(
      const APrices: TJSONArray;
      const AProvider: string;
      const AModel: string;
      const AExactModel: Boolean;
      out AMatched: Boolean;
      out APricing: TRadIAAgentPricing
    ): Boolean;
    procedure ValidateRate(
      const AName: string;
      const AValue: Double
    );
  public
    constructor Create(const AFileName: string);
    procedure EnsureTemplate;
    function TryResolve(
      const AProvider: string;
      const AModel: string;
      out APricing: TRadIAAgentPricing
    ): Boolean;
    property DefaultRunBudgetMicros: Int64
      read FDefaultRunBudgetMicros;
  end;

implementation

uses
  System.IOUtils,
  System.Math,
  System.SysUtils;

const
  CDefaultBudgetUsd = 5.0;
  CMaxRateUsdPerMillionTokens = 10000.0;

{ TRadIAAgentPricing }

constructor TRadIAAgentPricing.Create(
  const AProvider: string;
  const AModel: string;
  const AInputUsdPerMillionTokens: Double;
  const AOutputUsdPerMillionTokens: Double
);
begin
  FProvider := AProvider;
  FModel := AModel;
  FInputUsdPerMillionTokens := AInputUsdPerMillionTokens;
  FOutputUsdPerMillionTokens := AOutputUsdPerMillionTokens;
end;

function TRadIAAgentPricing.EstimateCostMicros(
  const APromptTokens: Integer;
  const ACompletionTokens: Integer
): Int64;
var
  LCostUsd: Extended;
begin
  LCostUsd :=
    (Max(APromptTokens, 0) * FInputUsdPerMillionTokens / 1000000) +
    (Max(ACompletionTokens, 0) * FOutputUsdPerMillionTokens / 1000000);
  Result := Round(LCostUsd * 1000000);
end;

function TRadIAAgentPricing.IsConfigured: Boolean;
begin
  Result := (Trim(FProvider) <> '') and (Trim(FModel) <> '') and
    ((FInputUsdPerMillionTokens > 0) or
    (FOutputUsdPerMillionTokens > 0));
end;

{ TRadIAAgentPricingCatalog }

constructor TRadIAAgentPricingCatalog.Create(
  const AFileName: string
);
begin
  inherited Create;
  if Trim(AFileName) = '' then
    raise EArgumentException.Create(
      'Agent pricing catalog file name must not be empty.'
    );
  FFileName := TPath.GetFullPath(AFileName);
  FDefaultRunBudgetMicros := Round(CDefaultBudgetUsd * 1000000);
end;

procedure TRadIAAgentPricingCatalog.EnsureTemplate;
var
  LDirectory: string;
  LRoot: TJSONObject;
begin
  if TFile.Exists(FFileName) then
    Exit;
  LDirectory := TPath.GetDirectoryName(FFileName);
  TDirectory.CreateDirectory(LDirectory);
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('currency', 'USD');
    LRoot.AddPair(
      'defaultRunBudgetUsd',
      TJSONNumber.Create(CDefaultBudgetUsd)
    );
    LRoot.AddPair('prices', TJSONArray.Create);
    TFile.WriteAllText(FFileName, LRoot.Format(2), TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAAgentPricingCatalog.LoadCatalogSettings(
  const ARoot: TJSONObject
);
var
  LBudgetUsd: Double;
begin
  if ARoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
    raise EConvertError.Create(
      'Agent pricing catalog schema is not supported.'
    );
  if not SameText(ARoot.GetValue<string>('currency', ''), 'USD') then
    raise EConvertError.Create(
      'Agent pricing catalog currently supports only USD.'
    );
  LBudgetUsd := ARoot.GetValue<Double>(
    'defaultRunBudgetUsd',
    CDefaultBudgetUsd
  );
  if (LBudgetUsd <= 0) or (LBudgetUsd > 10000) then
    raise EConvertError.Create(
      'Agent default run budget must be between USD 0 and 10000.'
    );
  FDefaultRunBudgetMicros := Round(LBudgetUsd * 1000000);
end;

function TRadIAAgentPricingCatalog.PricingMatches(
  const AItem: TJSONObject;
  const AProvider: string;
  const AModel: string;
  const AExactModel: Boolean
): Boolean;
var
  LItemModel: string;
begin
  if not SameText(AItem.GetValue<string>('provider', ''), AProvider) then
    Exit(False);
  LItemModel := AItem.GetValue<string>('model', '');
  if AExactModel then
    Result := SameText(LItemModel, AModel)
  else
    Result := LItemModel = '*';
end;

function TRadIAAgentPricingCatalog.TryResolve(
  const AProvider: string;
  const AModel: string;
  out APricing: TRadIAAgentPricing
): Boolean;
var
  LArray: TJSONArray;
  LMatched: Boolean;
  LRoot: TJSONObject;
  LText: string;
begin
  Result := False;
  APricing := Default(TRadIAAgentPricing);
  EnsureTemplate;
  LText := TFile.ReadAllText(FFileName, TEncoding.UTF8);
  LRoot := TJSONObject.ParseJSONValue(LText) as TJSONObject;
  if not Assigned(LRoot) then
    raise EConvertError.Create('Agent pricing catalog is not valid JSON.');
  try
    LoadCatalogSettings(LRoot);
    LArray := LRoot.GetValue<TJSONArray>('prices');
    if not Assigned(LArray) then
      Exit;
    Result := TryResolvePass(
      LArray,
      AProvider,
      AModel,
      True,
      LMatched,
      APricing
    );
    if not LMatched then
      Result := TryResolvePass(
        LArray,
        AProvider,
        AModel,
        False,
        LMatched,
        APricing
      );
  finally
    LRoot.Free;
  end;
end;

function TRadIAAgentPricingCatalog.TryResolvePass(
  const APrices: TJSONArray;
  const AProvider: string;
  const AModel: string;
  const AExactModel: Boolean;
  out AMatched: Boolean;
  out APricing: TRadIAAgentPricing
): Boolean;
var
  LIndex: Integer;
  LInputRate: Double;
  LItem: TJSONObject;
  LItemModel: string;
  LOutputRate: Double;
begin
  Result := False;
  AMatched := False;
  for LIndex := 0 to APrices.Count - 1 do
  begin
    if not (APrices[LIndex] is TJSONObject) then
      Continue;
    LItem := TJSONObject(APrices[LIndex]);
    if not PricingMatches(LItem, AProvider, AModel, AExactModel) then
      Continue;
    AMatched := True;
    LItemModel := LItem.GetValue<string>('model', '');
    LInputRate := LItem.GetValue<Double>('inputUsdPerMillionTokens', 0);
    LOutputRate := LItem.GetValue<Double>('outputUsdPerMillionTokens', 0);
    ValidateRate('input', LInputRate);
    ValidateRate('output', LOutputRate);
    APricing := TRadIAAgentPricing.Create(
      AProvider,
      LItemModel,
      LInputRate,
      LOutputRate
    );
    Exit(APricing.IsConfigured);
  end;
end;

procedure TRadIAAgentPricingCatalog.ValidateRate(
  const AName: string;
  const AValue: Double
);
begin
  if (AValue < 0) or
    (AValue > CMaxRateUsdPerMillionTokens) or IsNan(AValue) then
    raise EConvertError.CreateFmt(
      'Agent %s token rate is outside the supported range.',
      [AName]
    );
end;

end.
