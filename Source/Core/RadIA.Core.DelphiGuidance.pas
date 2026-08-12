unit RadIA.Core.DelphiGuidance;

interface

type
  TRadIADelphiGuidanceRule = record
  private
    FArchitecture: string;
    FCitation: string;
    FFramework: string;
    FGuidance: string;
    FId: string;
    FPriority: Integer;
    FSchemaVersion: Integer;
    FTopic: string;
    FVersion: string;
  public
    constructor Create(
      const AId: string;
      const ATopic: string;
      const AVersion: string;
      const AFramework: string;
      const AArchitecture: string;
      const AGuidance: string;
      const APriority: Integer
    );
    function AppliesTo(
      const AVersion: string;
      const AFramework: string;
      const AArchitecture: string;
      const ATopic: string
    ): Boolean;
    property Id: string read FId;
    property SchemaVersion: Integer read FSchemaVersion;
    property Topic: string read FTopic;
    property Version: string read FVersion;
    property Framework: string read FFramework;
    property Architecture: string read FArchitecture;
    property Guidance: string read FGuidance;
    property Priority: Integer read FPriority;
    property Citation: string read FCitation;
  end;

  TRadIADelphiGuidanceQuery = record
  private
    FArchitecture: string;
    FFramework: string;
    FId: string;
    FMaxCount: Integer;
    FTopic: string;
    FVersion: string;
  public
    constructor Create(
      const AVersion: string;
      const AFramework: string;
      const AArchitecture: string;
      const ATopic: string;
      const AId: string;
      const AMaxCount: Integer
    );
    property Version: string read FVersion;
    property Framework: string read FFramework;
    property Architecture: string read FArchitecture;
    property Topic: string read FTopic;
    property Id: string read FId;
    property MaxCount: Integer read FMaxCount;
  end;

  IRadIADelphiGuidanceCatalog = interface
    ['{68675895-C3B8-46E3-8983-E56880927CD9}']
    function Query(
      const AQuery: TRadIADelphiGuidanceQuery
    ): TArray<TRadIADelphiGuidanceRule>;
    function BuildPromptContext(
      const AVersion: string;
      const AFramework: string;
      const AArchitecture: string;
      const AMaxCount: Integer
    ): string;
  end;

  TRadIADelphiGuidanceCatalog = class(
    TInterfacedObject,
    IRadIADelphiGuidanceCatalog
  )
  private
    FRules: TArray<TRadIADelphiGuidanceRule>;
    class function CreateBuiltInRules:
      TArray<TRadIADelphiGuidanceRule>; static;
  public
    constructor Create;
    function Query(
      const AQuery: TRadIADelphiGuidanceQuery
    ): TArray<TRadIADelphiGuidanceRule>;
    function BuildPromptContext(
      const AVersion: string;
      const AFramework: string;
      const AArchitecture: string;
      const AMaxCount: Integer
    ): string;
  end;

implementation

uses
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils;

const
  CSchemaVersion = 1;
  CMaximumQueryRules = 50;

function MatchesSelector(
  const ASelector: string;
  const AValue: string
): Boolean;
begin
  Result := SameText(ASelector, 'any') or
    SameText(AValue, 'any') or
    SameText(ASelector, AValue) or
    ContainsText(AValue, ASelector);
end;

{ TRadIADelphiGuidanceRule }

constructor TRadIADelphiGuidanceRule.Create(
  const AId: string;
  const ATopic: string;
  const AVersion: string;
  const AFramework: string;
  const AArchitecture: string;
  const AGuidance: string;
  const APriority: Integer
);
begin
  if Trim(AId) = '' then
    raise EArgumentException.Create('Guidance rule id must not be empty.');
  if Trim(ATopic) = '' then
    raise EArgumentException.Create('Guidance rule topic must not be empty.');
  if Trim(AGuidance) = '' then
    raise EArgumentException.Create('Guidance text must not be empty.');
  if (APriority < 0) or (APriority > 1000) then
    raise EArgumentOutOfRangeException.Create('Guidance priority is invalid.');
  FId := LowerCase(Trim(AId));
  FSchemaVersion := CSchemaVersion;
  FTopic := LowerCase(Trim(ATopic));
  FVersion := LowerCase(Trim(AVersion));
  FFramework := LowerCase(Trim(AFramework));
  FArchitecture := LowerCase(Trim(AArchitecture));
  FGuidance := Trim(AGuidance);
  FPriority := APriority;
  FCitation := '[radia-delphi:' + FId + '@' +
    IntToStr(FSchemaVersion) + ']';
end;

function TRadIADelphiGuidanceRule.AppliesTo(
  const AVersion: string;
  const AFramework: string;
  const AArchitecture: string;
  const ATopic: string
): Boolean;
begin
  Result := MatchesSelector(FVersion, AVersion) and
    MatchesSelector(FFramework, AFramework) and
    MatchesSelector(FArchitecture, AArchitecture) and
    ((Trim(ATopic) = '') or SameText(FTopic, ATopic));
end;

{ TRadIADelphiGuidanceQuery }

constructor TRadIADelphiGuidanceQuery.Create(
  const AVersion: string;
  const AFramework: string;
  const AArchitecture: string;
  const ATopic: string;
  const AId: string;
  const AMaxCount: Integer
);
begin
  if (AMaxCount < 1) or (AMaxCount > CMaximumQueryRules) then
    raise EArgumentOutOfRangeException.Create(
      'Guidance maxCount must be between 1 and 50.'
    );
  FVersion := Trim(AVersion);
  FFramework := Trim(AFramework);
  FArchitecture := Trim(AArchitecture);
  FTopic := Trim(ATopic);
  FId := LowerCase(Trim(AId));
  FMaxCount := AMaxCount;
end;

{ TRadIADelphiGuidanceCatalog }

constructor TRadIADelphiGuidanceCatalog.Create;
begin
  inherited Create;
  FRules := CreateBuiltInRules;
end;

function TRadIADelphiGuidanceCatalog.BuildPromptContext(
  const AVersion: string;
  const AFramework: string;
  const AArchitecture: string;
  const AMaxCount: Integer
): string;
var
  LRule: TRadIADelphiGuidanceRule;
  LRules: TArray<TRadIADelphiGuidanceRule>;
begin
  LRules := Query(
    TRadIADelphiGuidanceQuery.Create(
      AVersion,
      AFramework,
      AArchitecture,
      '',
      '',
      AMaxCount
    )
  );
  Result := '';
  for LRule in LRules do
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + '- ' + LRule.Citation + ' ' + LRule.Guidance;
  end;
end;

class function TRadIADelphiGuidanceCatalog.CreateBuiltInRules:
  TArray<TRadIADelphiGuidanceRule>;
begin
  Result := [
    TRadIADelphiGuidanceRule.Create(
      'language-string-indexing',
      'language',
      'any',
      'any',
      'any',
      'Desktop Delphi strings are one-based; iterate characters with Low and High.',
      100
    ),
    TRadIADelphiGuidanceRule.Create(
      'memory-object-lifetime',
      'memory',
      'any',
      'any',
      'any',
      'Protect locally created objects with try..finally and release them with Free.',
      100
    ),
    TRadIADelphiGuidanceRule.Create(
      'threads-vcl-main-thread',
      'threads',
      'any',
      'vcl',
      'any',
      'Marshal VCL changes from worker threads through TThread.Queue or Synchronize.',
      100
    ),
    TRadIADelphiGuidanceRule.Create(
      'threads-fmx-main-thread',
      'threads',
      'any',
      'fmx',
      'any',
      'Keep FMX control mutations on the application main thread.',
      100
    ),
    TRadIADelphiGuidanceRule.Create(
      'vcl-component-ownership',
      'vcl',
      'any',
      'vcl',
      'any',
      'Respect component ownership and avoid freeing components owned by another component.',
      90
    ),
    TRadIADelphiGuidanceRule.Create(
      'fmx-platform-services',
      'fmx',
      'any',
      'fmx',
      'any',
      'Use FMX platform services instead of assuming a Windows-only implementation.',
      90
    ),
    TRadIADelphiGuidanceRule.Create(
      'delphi12-supported-baseline',
      'compatibility',
      '12',
      'any',
      'any',
      'Generate code that compiles with the Delphi 12 RTL and compiler.',
      110
    ),
    TRadIADelphiGuidanceRule.Create(
      'delphi13-supported-baseline',
      'compatibility',
      '13',
      'any',
      'any',
      'Generate code that compiles with the Delphi 13 RTL and compiler.',
      110
    ),
    TRadIADelphiGuidanceRule.Create(
      'ide64-pointer-safety',
      'compatibility',
      '13',
      'any',
      'ide64',
      'Do not truncate handles or pointers; use NativeInt, NativeUInt, or typed handles.',
      120
    ),
    TRadIADelphiGuidanceRule.Create(
      'dfm-pas-consistency',
      'designer',
      'any',
      'vcl',
      'any',
      'Keep DFM components, event handlers, fields, and Pascal declarations consistent.',
      105
    ),
    TRadIADelphiGuidanceRule.Create(
      'unit-interface-imports',
      'architecture',
      'any',
      'any',
      'any',
      'Keep uses in implementation unless a public declaration requires the imported type.',
      80
    ),
    TRadIADelphiGuidanceRule.Create(
      'routine-parameter-limit',
      'quality',
      'any',
      'any',
      'any',
      'Use a parameter record or object when a routine would exceed seven parameters.',
      80
    )
  ];
end;

function TRadIADelphiGuidanceCatalog.Query(
  const AQuery: TRadIADelphiGuidanceQuery
): TArray<TRadIADelphiGuidanceRule>;
var
  LIndex: Integer;
  LList: TList<TRadIADelphiGuidanceRule>;
  LRule: TRadIADelphiGuidanceRule;
begin
  LList := TList<TRadIADelphiGuidanceRule>.Create;
  try
    for LRule in FRules do
    begin
      if (AQuery.Id <> '') and not SameText(LRule.Id, AQuery.Id) then
        Continue;
      if not LRule.AppliesTo(
        AQuery.Version,
        AQuery.Framework,
        AQuery.Architecture,
        AQuery.Topic
      ) then
        Continue;
      LIndex := 0;
      while (LIndex < LList.Count) and
        (LList[LIndex].Priority >= LRule.Priority) do
        Inc(LIndex);
      LList.Insert(LIndex, LRule);
    end;
    while LList.Count > AQuery.MaxCount do
      LList.Delete(LList.Count - 1);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
