unit RadIA.Core.Extensions;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  RadIA.Core.Tools;

const
  CRadIAToolExtensionApiVersion = 1;

type
  ERadIAToolExtension = class(Exception);
  ERadIAInvalidToolExtension = class(ERadIAToolExtension);
  ERadIAToolExtensionAlreadyRegistered = class(ERadIAToolExtension);
  ERadIAToolExtensionPrefixAlreadyRegistered = class(
    ERadIAToolExtension
  );
  ERadIAToolExtensionHostUnavailable = class(ERadIAToolExtension);

  TRadIAToolExtensionDescriptor = record
  private
    FId: string;
    FVersion: string;
    FToolPrefix: string;
    FMinimumApiVersion: Integer;
    FMaximumApiVersion: Integer;
  public
    constructor Create(
      const AId: string;
      const AVersion: string;
      const AToolPrefix: string;
      const AMinimumApiVersion: Integer;
      const AMaximumApiVersion: Integer
    );
    property Id: string read FId;
    property Version: string read FVersion;
    property ToolPrefix: string read FToolPrefix;
    property MinimumApiVersion: Integer read FMinimumApiVersion;
    property MaximumApiVersion: Integer read FMaximumApiVersion;
  end;

  IRadIAToolExtensionRegistrar = interface
    ['{19EA5029-4E2D-4827-91DB-D12DB1DE993F}']
    procedure AddTool(const ATool: IRadIATool);
  end;

  IRadIAToolExtension = interface
    ['{E41454E3-404F-4890-83DC-440F1A7099CA}']
    function GetDescriptor: TRadIAToolExtensionDescriptor;
    procedure RegisterTools(
      const ARegistrar: IRadIAToolExtensionRegistrar
    );
    property Descriptor: TRadIAToolExtensionDescriptor
      read GetDescriptor;
  end;

  IRadIAToolExtensionRegistration = interface
    ['{37B32FD6-3816-4C3B-A6ED-7D58824CBA6F}']
    function GetExtensionId: string;
    property ExtensionId: string read GetExtensionId;
  end;

  IRadIAToolExtensionHost = interface
    ['{3DA71B89-3489-441C-88AB-72C2FB8EEFE4}']
    function RegisterExtension(
      const AExtension: IRadIAToolExtension
    ): IRadIAToolExtensionRegistration;
    procedure UnregisterExtension(const AExtensionId: string);
    function GetDescriptors: TArray<TRadIAToolExtensionDescriptor>;
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;

  TRadIAToolExtensionHost = class(
    TInterfacedObject,
    IRadIAToolExtensionHost
  )
  private
    type
      TRadIARegisteredExtension = record
        Descriptor: TRadIAToolExtensionDescriptor;
        Extension: IRadIAToolExtension;
        ToolNames: TArray<string>;
      end;
  private
    FRegistry: IRadIAToolRegistry;
    FExtensions: TDictionary<string, TRadIARegisteredExtension>;
    procedure ValidateDescriptor(
      const ADescriptor: TRadIAToolExtensionDescriptor
    );
    procedure ValidateAvailability(
      const ADescriptor: TRadIAToolExtensionDescriptor
    );
    procedure ValidateTools(
      const ADescriptor: TRadIAToolExtensionDescriptor;
      const ATools: TArray<IRadIATool>
    );
  public
    constructor Create(const ARegistry: IRadIAToolRegistry);
    destructor Destroy; override;
    function RegisterExtension(
      const AExtension: IRadIAToolExtension
    ): IRadIAToolExtensionRegistration;
    procedure UnregisterExtension(const AExtensionId: string);
    function GetDescriptors: TArray<TRadIAToolExtensionDescriptor>;
    function GetCount: Integer;
  end;

function RegisterRadIAToolExtension(
  const AExtension: IRadIAToolExtension
): IRadIAToolExtensionRegistration;
function GetRadIAToolExtensionApiVersion: Integer;
procedure SetRadIAToolExtensionHost(
  const AHost: IRadIAToolExtensionHost
);

implementation

uses
  System.Generics.Defaults;

type
  TRadIAToolExtensionRegistrar = class(
    TInterfacedObject,
    IRadIAToolExtensionRegistrar
  )
  private
    FTools: TList<IRadIATool>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddTool(const ATool: IRadIATool);
    function ToArray: TArray<IRadIATool>;
  end;

  TRadIAToolExtensionRegistration = class(
    TInterfacedObject,
    IRadIAToolExtensionRegistration
  )
  private
    FExtensionId: string;
    FHost: IRadIAToolExtensionHost;
  public
    constructor Create(
      const AExtensionId: string;
      const AHost: IRadIAToolExtensionHost
    );
    destructor Destroy; override;
    function GetExtensionId: string;
  end;

var
  GExtensionHost: IRadIAToolExtensionHost;
  GExtensionHostLock: TObject;

function IsPascalIdentifier(const AValue: string): Boolean;
var
  LChar: Char;
  LIndex: Integer;
begin
  Result := False;
  if AValue = '' then
    Exit;
  if not CharInSet(AValue[Low(AValue)], ['A'..'Z']) then
    Exit;
  for LIndex := Low(AValue) to High(AValue) do
  begin
    LChar := AValue[LIndex];
    if not CharInSet(LChar, ['A'..'Z', 'a'..'z', '0'..'9']) then
      Exit;
  end;
  Result := True;
end;

{ TRadIAToolExtensionDescriptor }

constructor TRadIAToolExtensionDescriptor.Create(
  const AId: string;
  const AVersion: string;
  const AToolPrefix: string;
  const AMinimumApiVersion: Integer;
  const AMaximumApiVersion: Integer
);
begin
  FId := AId;
  FVersion := AVersion;
  FToolPrefix := AToolPrefix;
  FMinimumApiVersion := AMinimumApiVersion;
  FMaximumApiVersion := AMaximumApiVersion;
end;

{ TRadIAToolExtensionRegistrar }

constructor TRadIAToolExtensionRegistrar.Create;
begin
  inherited Create;
  FTools := TList<IRadIATool>.Create;
end;

destructor TRadIAToolExtensionRegistrar.Destroy;
begin
  FTools.Free;
  inherited;
end;

procedure TRadIAToolExtensionRegistrar.AddTool(
  const ATool: IRadIATool
);
begin
  FTools.Add(ATool);
end;

function TRadIAToolExtensionRegistrar.ToArray: TArray<IRadIATool>;
begin
  Result := FTools.ToArray;
end;

{ TRadIAToolExtensionRegistration }

constructor TRadIAToolExtensionRegistration.Create(
  const AExtensionId: string;
  const AHost: IRadIAToolExtensionHost
);
begin
  inherited Create;
  FExtensionId := AExtensionId;
  FHost := AHost;
end;

destructor TRadIAToolExtensionRegistration.Destroy;
begin
  if Assigned(FHost) then
    FHost.UnregisterExtension(FExtensionId);
  FHost := nil;
  inherited;
end;

function TRadIAToolExtensionRegistration.GetExtensionId: string;
begin
  Result := FExtensionId;
end;

{ TRadIAToolExtensionHost }

constructor TRadIAToolExtensionHost.Create(
  const ARegistry: IRadIAToolRegistry
);
begin
  inherited Create;
  if not Assigned(ARegistry) then
    raise ERadIAInvalidToolExtension.Create(
      'Tool registry must be assigned.'
    );
  FRegistry := ARegistry;
  FExtensions :=
    TDictionary<string, TRadIARegisteredExtension>.Create(
      TIStringComparer.Ordinal
    );
end;

destructor TRadIAToolExtensionHost.Destroy;
var
  LExtensionIds: TArray<string>;
  LExtensionId: string;
begin
  TMonitor.Enter(FExtensions);
  try
    LExtensionIds := FExtensions.Keys.ToArray;
  finally
    TMonitor.Exit(FExtensions);
  end;
  for LExtensionId in LExtensionIds do
    UnregisterExtension(LExtensionId);
  FExtensions.Free;
  FRegistry := nil;
  inherited;
end;

function TRadIAToolExtensionHost.GetCount: Integer;
var
  LPair: TPair<string, TRadIARegisteredExtension>;
begin
  TMonitor.Enter(FExtensions);
  try
    Result := 0;
    for LPair in FExtensions do
      Inc(Result);
  finally
    TMonitor.Exit(FExtensions);
  end;
end;

function TRadIAToolExtensionHost.GetDescriptors:
  TArray<TRadIAToolExtensionDescriptor>;
var
  LIndex: Integer;
  LPair: TPair<string, TRadIARegisteredExtension>;
begin
  TMonitor.Enter(FExtensions);
  try
    Result := [];
    LIndex := 0;
    for LPair in FExtensions do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[LIndex] := LPair.Value.Descriptor;
      Inc(LIndex);
    end;
  finally
    TMonitor.Exit(FExtensions);
  end;
  TArray.Sort<TRadIAToolExtensionDescriptor>(
    Result,
    TComparer<TRadIAToolExtensionDescriptor>.Construct(
      function(
        const ALeft: TRadIAToolExtensionDescriptor;
        const ARight: TRadIAToolExtensionDescriptor
      ): Integer
      begin
        Result := CompareText(ALeft.Id, ARight.Id);
      end
    )
  );
end;

function TRadIAToolExtensionHost.RegisterExtension(
  const AExtension: IRadIAToolExtension
): IRadIAToolExtensionRegistration;
var
  LDescriptor: TRadIAToolExtensionDescriptor;
  LEntry: TRadIARegisteredExtension;
  LIndex: Integer;
  LRegistrar: TRadIAToolExtensionRegistrar;
  LTools: TArray<IRadIATool>;
begin
  if not Assigned(AExtension) then
    raise ERadIAInvalidToolExtension.Create(
      'Tool extension must be assigned.'
    );
  LDescriptor := AExtension.Descriptor;
  ValidateDescriptor(LDescriptor);
  TMonitor.Enter(FExtensions);
  try
    ValidateAvailability(LDescriptor);
  finally
    TMonitor.Exit(FExtensions);
  end;

  LRegistrar := TRadIAToolExtensionRegistrar.Create;
  try
    AExtension.RegisterTools(LRegistrar);
    LTools := LRegistrar.ToArray;
  finally
    LRegistrar.Free;
  end;
  ValidateTools(LDescriptor, LTools);

  TMonitor.Enter(FExtensions);
  try
    ValidateAvailability(LDescriptor);
    FRegistry.RegisterTools(LTools);
    LEntry.Descriptor := LDescriptor;
    LEntry.Extension := AExtension;
    SetLength(LEntry.ToolNames, Length(LTools));
    for LIndex := Low(LTools) to High(LTools) do
      LEntry.ToolNames[LIndex] := LTools[LIndex].Descriptor.Name;
    FExtensions.Add(LDescriptor.Id, LEntry);
  finally
    TMonitor.Exit(FExtensions);
  end;
  Result := TRadIAToolExtensionRegistration.Create(
    LDescriptor.Id,
    Self
  );
end;

procedure TRadIAToolExtensionHost.UnregisterExtension(
  const AExtensionId: string
);
var
  LEntry: TRadIARegisteredExtension;
begin
  TMonitor.Enter(FExtensions);
  try
    if not FExtensions.TryGetValue(AExtensionId, LEntry) then
      Exit;
    FRegistry.UnregisterTools(LEntry.ToolNames);
    FExtensions.Remove(AExtensionId);
  finally
    TMonitor.Exit(FExtensions);
  end;
end;

procedure TRadIAToolExtensionHost.ValidateAvailability(
  const ADescriptor: TRadIAToolExtensionDescriptor
);
var
  LEntry: TRadIARegisteredExtension;
begin
  if FExtensions.ContainsKey(ADescriptor.Id) then
    raise ERadIAToolExtensionAlreadyRegistered.CreateFmt(
      'Tool extension "%s" is already registered.',
      [ADescriptor.Id]
    );
  for LEntry in FExtensions.Values do
  begin
    if SameText(
      LEntry.Descriptor.ToolPrefix,
      ADescriptor.ToolPrefix
    ) then
      raise ERadIAToolExtensionPrefixAlreadyRegistered.CreateFmt(
        'Tool prefix "%s" is already owned by extension "%s".',
        [ADescriptor.ToolPrefix, LEntry.Descriptor.Id]
      );
  end;
end;

procedure TRadIAToolExtensionHost.ValidateDescriptor(
  const ADescriptor: TRadIAToolExtensionDescriptor
);
begin
  if not IsPascalIdentifier(ADescriptor.Id) then
    raise ERadIAInvalidToolExtension.Create(
      'Extension ID must use alphanumeric PascalCase.'
    );
  if Trim(ADescriptor.Version) = '' then
    raise ERadIAInvalidToolExtension.Create(
      'Extension version must not be empty.'
    );
  if not IsPascalIdentifier(ADescriptor.ToolPrefix) then
    raise ERadIAInvalidToolExtension.Create(
      'Tool prefix must use alphanumeric PascalCase.'
    );
  if (ADescriptor.MinimumApiVersion < 1) or
    (ADescriptor.MaximumApiVersion <
      ADescriptor.MinimumApiVersion) then
    raise ERadIAInvalidToolExtension.Create(
      'Extension API range must be positive and ordered.'
    );
  if (ADescriptor.MinimumApiVersion > GetRadIAToolExtensionApiVersion) or
    (ADescriptor.MaximumApiVersion < GetRadIAToolExtensionApiVersion) then
    raise ERadIAInvalidToolExtension.CreateFmt(
      'Extension API range %d..%d is incompatible with API %d.',
      [
        ADescriptor.MinimumApiVersion,
        ADescriptor.MaximumApiVersion,
        GetRadIAToolExtensionApiVersion
      ]
    );
end;

procedure TRadIAToolExtensionHost.ValidateTools(
  const ADescriptor: TRadIAToolExtensionDescriptor;
  const ATools: TArray<IRadIATool>
);
var
  LTool: IRadIATool;
begin
  if Length(ATools) = 0 then
    raise ERadIAInvalidToolExtension.Create(
      'Extension must register at least one tool.'
    );
  for LTool in ATools do
  begin
    if not Assigned(LTool) then
      raise ERadIAInvalidToolExtension.Create(
        'Extension tool must be assigned.'
      );
    if not LTool.Descriptor.Name.StartsWith(
      ADescriptor.ToolPrefix,
      True
    ) or
      (Length(LTool.Descriptor.Name) =
        Length(ADescriptor.ToolPrefix)) then
      raise ERadIAInvalidToolExtension.CreateFmt(
        'Tool "%s" must use extension prefix "%s".',
        [LTool.Descriptor.Name, ADescriptor.ToolPrefix]
      );
  end;
end;

function GetRadIAToolExtensionApiVersion: Integer;
begin
  Result := CRadIAToolExtensionApiVersion;
end;

function RegisterRadIAToolExtension(
  const AExtension: IRadIAToolExtension
): IRadIAToolExtensionRegistration;
var
  LHost: IRadIAToolExtensionHost;
begin
  TMonitor.Enter(GExtensionHostLock);
  try
    LHost := GExtensionHost;
  finally
    TMonitor.Exit(GExtensionHostLock);
  end;
  if not Assigned(LHost) then
    raise ERadIAToolExtensionHostUnavailable.Create(
      'RadIA tool extension host is unavailable.'
    );
  Result := LHost.RegisterExtension(AExtension);
end;

procedure SetRadIAToolExtensionHost(
  const AHost: IRadIAToolExtensionHost
);
begin
  TMonitor.Enter(GExtensionHostLock);
  try
    GExtensionHost := AHost;
  finally
    TMonitor.Exit(GExtensionHostLock);
  end;
end;

initialization
  GExtensionHostLock := TObject.Create;

finalization
  GExtensionHost := nil;
  GExtensionHostLock.Free;

end.
