unit RadIA.Core.AgentPricing;

interface

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
    property Provider: string read FProvider;
    property Model: string read FModel;
    property InputUsdPerMillionTokens: Double
      read FInputUsdPerMillionTokens;
    property OutputUsdPerMillionTokens: Double
      read FOutputUsdPerMillionTokens;
  end;

  TRadIAAgentPricingCatalog = class
  private
    FFileName: string;
    FDefaultRunBudgetMicros: Int64;
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
  System.JSON,
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

function TRadIAAgentPricingCatalog.TryResolve(
  const AProvider: string;
  const AModel: string;
  out APricing: TRadIAAgentPricing
): Boolean;
var
  LArray: TJSONArray;
  LBudgetUsd: Double;
  LIndex: Integer;
  LInputRate: Double;
  LItem: TJSONObject;
  LItemModel: string;
  LOutputRate: Double;
  LPass: Integer;
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
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EConvertError.Create(
        'Agent pricing catalog schema is not supported.'
      );
    if not SameText(LRoot.GetValue<string>('currency', ''), 'USD') then
      raise EConvertError.Create(
        'Agent pricing catalog currently supports only USD.'
      );
    LBudgetUsd := LRoot.GetValue<Double>(
      'defaultRunBudgetUsd',
      CDefaultBudgetUsd
    );
    if (LBudgetUsd <= 0) or (LBudgetUsd > 10000) then
      raise EConvertError.Create(
        'Agent default run budget must be between USD 0 and 10000.'
      );
    FDefaultRunBudgetMicros := Round(LBudgetUsd * 1000000);
    LArray := LRoot.GetValue<TJSONArray>('prices');
    if not Assigned(LArray) then
      Exit;
    for LPass := 0 to 1 do
    begin
      for LIndex := 0 to LArray.Count - 1 do
      begin
        if not (LArray.Items[LIndex] is TJSONObject) then
          Continue;
        LItem := TJSONObject(LArray.Items[LIndex]);
        if not SameText(
          LItem.GetValue<string>('provider', ''),
          AProvider
        ) then
          Continue;
        LItemModel := LItem.GetValue<string>('model', '');
        if (LPass = 0) and not SameText(LItemModel, AModel) then
          Continue;
        if (LPass = 1) and (LItemModel <> '*') then
          Continue;
        LInputRate := LItem.GetValue<Double>(
          'inputUsdPerMillionTokens',
          0
        );
        LOutputRate := LItem.GetValue<Double>(
          'outputUsdPerMillionTokens',
          0
        );
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
  finally
    LRoot.Free;
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
