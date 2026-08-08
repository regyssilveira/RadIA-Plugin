unit RadIA.Core.ApiSpecifications;

interface

type
  TRadIAApiStyle = (
    asMinimal,
    asControllers
  );

  TRadIAApiEndpoint = record
  private
    FName: string;
    FGroup: string;
    FMethod: string;
    FPath: string;
    FDescription: string;
    FStatusCode: Integer;
  public
    constructor Create(
      const AName: string;
      const AGroup: string;
      const AMethod: string;
      const APath: string;
      const ADescription: string;
      const AStatusCode: Integer
    );
    property Name: string read FName;
    property Group: string read FGroup;
    property Method: string read FMethod;
    property Path: string read FPath;
    property Description: string read FDescription;
    property StatusCode: Integer read FStatusCode;
  end;

  TRadIAApiSpecification = record
  private
    FSchemaVersion: Integer;
    FProjectName: string;
    FStyle: TRadIAApiStyle;
    FPort: Integer;
    FEnableSwagger: Boolean;
    FEnableCors: Boolean;
    FEnableLogging: Boolean;
    FEndpoints: TArray<TRadIAApiEndpoint>;
  public
    constructor Create(
      const AProjectName: string;
      const AStyle: TRadIAApiStyle;
      const APort: Integer;
      const AEnableSwagger: Boolean;
      const AEnableCors: Boolean;
      const AEnableLogging: Boolean;
      const AEndpoints: TArray<TRadIAApiEndpoint>
    );
    property SchemaVersion: Integer read FSchemaVersion;
    property ProjectName: string read FProjectName;
    property Style: TRadIAApiStyle read FStyle;
    property Port: Integer read FPort;
    property EnableSwagger: Boolean read FEnableSwagger;
    property EnableCors: Boolean read FEnableCors;
    property EnableLogging: Boolean read FEnableLogging;
    property Endpoints: TArray<TRadIAApiEndpoint> read FEndpoints;
  end;

  TRadIAApiSpecificationParser = class
  private
    class function ReadRequiredString(
      const AJson: TObject;
      const AName: string;
      const APath: string
    ): string; static;
  public
    class function Parse(
      const AProjectName: string;
      const AStyle: TRadIAApiStyle;
      const AJson: string
    ): TRadIAApiSpecification; static;
  end;

  TRadIAApiSpecificationValidator = class
  private
    class function IsIdentifier(const AValue: string): Boolean; static;
    class procedure ValidateEndpoint(
      const AEndpoint: TRadIAApiEndpoint;
      const AIndex: Integer
    ); static;
  public
    class procedure Validate(
      const ASpecification: TRadIAApiSpecification
    ); static;
  end;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.SysUtils;

{ TRadIAApiEndpoint }

constructor TRadIAApiEndpoint.Create(
  const AName: string;
  const AGroup: string;
  const AMethod: string;
  const APath: string;
  const ADescription: string;
  const AStatusCode: Integer
);
begin
  FName := AName;
  FGroup := AGroup;
  FMethod := UpperCase(AMethod);
  FPath := APath;
  FDescription := ADescription;
  FStatusCode := AStatusCode;
end;

{ TRadIAApiSpecification }

constructor TRadIAApiSpecification.Create(
  const AProjectName: string;
  const AStyle: TRadIAApiStyle;
  const APort: Integer;
  const AEnableSwagger: Boolean;
  const AEnableCors: Boolean;
  const AEnableLogging: Boolean;
  const AEndpoints: TArray<TRadIAApiEndpoint>
);
begin
  FSchemaVersion := 1;
  FProjectName := AProjectName;
  FStyle := AStyle;
  FPort := APort;
  FEnableSwagger := AEnableSwagger;
  FEnableCors := AEnableCors;
  FEnableLogging := AEnableLogging;
  FEndpoints := Copy(AEndpoints);
end;

{ TRadIAApiSpecificationParser }

class function TRadIAApiSpecificationParser.Parse(
  const AProjectName: string;
  const AStyle: TRadIAApiStyle;
  const AJson: string
): TRadIAApiSpecification;
var
  LArray: TJSONArray;
  LEndpoint: TJSONObject;
  LEndpoints: TArray<TRadIAApiEndpoint>;
  LIndex: Integer;
  LRoot: TJSONObject;
  LValue: TJSONValue;
begin
  LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(LRoot) then
    raise EArgumentException.Create(
      'API specification must be a valid JSON object.'
    );
  try
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EArgumentException.Create(
        'API specification schemaVersion must be 1.'
      );
    LValue := LRoot.GetValue('endpoints');
    if not (LValue is TJSONArray) then
      raise EArgumentException.Create(
        'API specification endpoints must be an array.'
      );
    LArray := TJSONArray(LValue);
    SetLength(LEndpoints, LArray.Count);
    for LIndex := 0 to LArray.Count - 1 do
    begin
      if not (LArray.Items[LIndex] is TJSONObject) then
        raise EArgumentException.CreateFmt(
          'API specification endpoints[%d] must be an object.',
          [LIndex]
        );
      LEndpoint := TJSONObject(LArray.Items[LIndex]);
      LEndpoints[LIndex] := TRadIAApiEndpoint.Create(
        ReadRequiredString(LEndpoint, 'name', Format('endpoints[%d]', [LIndex])),
        LEndpoint.GetValue<string>('group', 'General'),
        ReadRequiredString(LEndpoint, 'method', Format('endpoints[%d]', [LIndex])),
        ReadRequiredString(LEndpoint, 'path', Format('endpoints[%d]', [LIndex])),
        LEndpoint.GetValue<string>('description', ''),
        LEndpoint.GetValue<Integer>('statusCode', 200)
      );
    end;
    Result := TRadIAApiSpecification.Create(
      AProjectName,
      AStyle,
      LRoot.GetValue<Integer>('port', 8080),
      LRoot.GetValue<Boolean>('enableSwagger', AStyle = asControllers),
      LRoot.GetValue<Boolean>('enableCors', False),
      LRoot.GetValue<Boolean>('enableLogging', True),
      LEndpoints
    );
    TRadIAApiSpecificationValidator.Validate(Result);
  finally
    LRoot.Free;
  end;
end;

class function TRadIAApiSpecificationParser.ReadRequiredString(
  const AJson: TObject;
  const AName: string;
  const APath: string
): string;
begin
  Result := TJSONObject(AJson).GetValue<string>(AName, '').Trim;
  if Result = '' then
    raise EArgumentException.CreateFmt(
      'API specification %s.%s must not be empty.',
      [APath, AName]
    );
end;

{ TRadIAApiSpecificationValidator }

class function TRadIAApiSpecificationValidator.IsIdentifier(
  const AValue: string
): Boolean;
var
  LChar: Char;
  LIndex: Integer;
begin
  Result := (AValue <> '') and CharInSet(AValue[Low(AValue)], ['A'..'Z', 'a'..'z', '_']);
  if not Result then
    Exit;
  for LIndex := Low(AValue) + 1 to High(AValue) do
  begin
    LChar := AValue[LIndex];
    if not CharInSet(LChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
  end;
end;

class procedure TRadIAApiSpecificationValidator.Validate(
  const ASpecification: TRadIAApiSpecification
);
var
  LEndpoint: TRadIAApiEndpoint;
  LIndex: Integer;
  LRouteKeys: TDictionary<string, Boolean>;
  LRouteKey: string;
begin
  if (ASpecification.Port < 1) or (ASpecification.Port > 65535) then
    raise EArgumentException.Create(
      'API specification port must be between 1 and 65535.'
    );
  if Length(ASpecification.Endpoints) = 0 then
    raise EArgumentException.Create(
      'API specification requires at least one endpoint.'
    );
  if Length(ASpecification.Endpoints) > 100 then
    raise EArgumentException.Create(
      'API specification supports at most 100 endpoints.'
    );
  LRouteKeys := TDictionary<string, Boolean>.Create;
  try
    for LIndex := Low(ASpecification.Endpoints) to High(ASpecification.Endpoints) do
    begin
      LEndpoint := ASpecification.Endpoints[LIndex];
      ValidateEndpoint(LEndpoint, LIndex);
      LRouteKey := UpperCase(LEndpoint.Method + ' ' + LEndpoint.Path);
      if LRouteKeys.ContainsKey(LRouteKey) then
        raise EArgumentException.CreateFmt(
          'API specification contains duplicate route %s.',
          [LRouteKey]
        );
      LRouteKeys.Add(LRouteKey, True);
    end;
  finally
    LRouteKeys.Free;
  end;
end;

class procedure TRadIAApiSpecificationValidator.ValidateEndpoint(
  const AEndpoint: TRadIAApiEndpoint;
  const AIndex: Integer
);
begin
  if not IsIdentifier(AEndpoint.Name) then
    raise EArgumentException.CreateFmt(
      'API specification endpoints[%d].name must be a Pascal identifier.',
      [AIndex]
    );
  if not IsIdentifier(AEndpoint.Group) then
    raise EArgumentException.CreateFmt(
      'API specification endpoints[%d].group must be a Pascal identifier.',
      [AIndex]
    );
  if not MatchText(AEndpoint.Method, ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) then
    raise EArgumentException.CreateFmt(
      'API specification endpoints[%d].method is unsupported.',
      [AIndex]
    );
  if not AEndpoint.Path.StartsWith('/') then
    raise EArgumentException.CreateFmt(
      'API specification endpoints[%d].path must start with "/".',
      [AIndex]
    );
  if AEndpoint.Path.Contains('''') or AEndpoint.Path.Contains(#13) or
    AEndpoint.Path.Contains(#10) then
    raise EArgumentException.CreateFmt(
      'API specification endpoints[%d].path contains unsafe characters.',
      [AIndex]
    );
  if (AEndpoint.StatusCode < 100) or (AEndpoint.StatusCode > 599) then
    raise EArgumentException.CreateFmt(
      'API specification endpoints[%d].statusCode is invalid.',
      [AIndex]
    );
end;

end.
