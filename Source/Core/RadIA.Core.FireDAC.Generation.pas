unit RadIA.Core.FireDAC.Generation;

interface

uses
  RadIA.Core.GeneratedArtifacts,
  RadIA.Core.Tools;

procedure RegisterRadIAFireDACGenerationTools(
  const ARegistry: IRadIAToolRegistry;
  const AArtifacts: IRadIAGeneratedArtifactService
);

implementation

uses
  System.Classes,
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.RegularExpressions,
  System.SysUtils;

type
  TRadIAFireDACGenerationKind = (fgkRepository, fgkDataModule, fgkQuery, fgkDto, fgkTests);

  TRadIAFireDACGenerationTool = class(TInterfacedObject, IRadIATool)
  private
    FArtifacts: IRadIAGeneratedArtifactService;
    FKind: TRadIAFireDACGenerationKind;
    function BuildContent(
      const AUnitName: string;
      const AEntityName: string;
      const ATableName: string
    ): string;
    function ResultToToolResult(
      const AResult: TRadIAGeneratedArtifactResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIAFireDACGenerationKind;
      const AArtifacts: IRadIAGeneratedArtifactService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CGenerationInputSchema =
    '{"type":"object","required":["unitName","entityName"],"properties":{' +
    '"unitName":{"type":"string","minLength":7,"maxLength":128},' +
    '"entityName":{"type":"string","minLength":1,"maxLength":64},' +
    '"tableName":{"type":"string","maxLength":128},' +
    '"relativeDirectory":{"type":"string","maxLength":512},' +
    '"registerInProject":{"type":"boolean"}},"additionalProperties":false}';
  CGenerationOutputSchema =
    '{"type":"object","required":["previewId","fileName","content","sha256","state"]}';

function IsIdentifier(const AValue: string): Boolean;
begin
  Result := TRegEx.IsMatch(AValue, '^[A-Za-z_][A-Za-z0-9_]*$');
end;

function IsUnitName(const AValue: string): Boolean;
begin
  Result := AValue.StartsWith('RadIA.', True) and
    TRegEx.IsMatch(AValue, '^RadIA\.[A-Za-z_][A-Za-z0-9_.]*$');
end;

constructor TRadIAFireDACGenerationTool.Create(
  const AKind: TRadIAFireDACGenerationKind;
  const AArtifacts: IRadIAGeneratedArtifactService
);
begin
  inherited Create;
  if not Assigned(AArtifacts) then
    raise EArgumentNilException.Create('AArtifacts');
  FKind := AKind;
  FArtifacts := AArtifacts;
end;

procedure AddUnitHeader(const ALines: TStrings; const AUnitName: string);
begin
  ALines.Add('unit ' + AUnitName + ';');
  ALines.Add('');
  ALines.Add('interface');
  ALines.Add('');
end;

procedure BuildDto(const ALines: TStrings; const AEntityName: string);
begin
  ALines.Add('type');
  ALines.Add('  TRadIA' + AEntityName + 'DTO = record');
  ALines.Add('  private');
  ALines.Add('    FId: Int64;');
  ALines.Add('  public');
  ALines.Add('    property Id: Int64 read FId write FId;');
  ALines.Add('  end;');
end;

procedure BuildRepository(
  const ALines: TStrings;
  const AEntityName: string;
  const ATableName: string
);
begin
  ALines.Add('uses');
  ALines.Add('  FireDAC.Comp.Client;');
  ALines.Add('');
  ALines.Add('type');
  ALines.Add('  TRadIA' + AEntityName + 'Repository = class');
  ALines.Add('  private');
  ALines.Add('    FConnection: TFDConnection;');
  ALines.Add('  public');
  ALines.Add('    constructor Create(const AConnection: TFDConnection);');
  ALines.Add('    function BuildSelectSql: string;');
  ALines.Add('  end;');
  ALines.Add('');
  ALines.Add('implementation');
  ALines.Add('');
  ALines.Add('constructor TRadIA' + AEntityName + 'Repository.Create(const AConnection: TFDConnection);');
  ALines.Add('begin');
  ALines.Add('  inherited Create;');
  ALines.Add('  FConnection := AConnection;');
  ALines.Add('end;');
  ALines.Add('');
  ALines.Add('function TRadIA' + AEntityName + 'Repository.BuildSelectSql: string;');
  ALines.Add('begin');
  ALines.Add('  Result := ''select * from ' + ATableName + ''';');
  ALines.Add('end;');
end;

procedure BuildDataModule(const ALines: TStrings; const AEntityName: string);
begin
  ALines.Add('uses');
  ALines.Add('  System.Classes,');
  ALines.Add('  FireDAC.Comp.Client;');
  ALines.Add('');
  ALines.Add('type');
  ALines.Add('  TRadIA' + AEntityName + 'DataModule = class(TDataModule)');
  ALines.Add('  private');
  ALines.Add('    FConnection: TFDConnection;');
  ALines.Add('  public');
  ALines.Add('    constructor Create(AOwner: TComponent); override;');
  ALines.Add('    destructor Destroy; override;');
  ALines.Add('    property Connection: TFDConnection read FConnection;');
  ALines.Add('  end;');
  ALines.Add('');
  ALines.Add('implementation');
  ALines.Add('');
  ALines.Add('constructor TRadIA' + AEntityName + 'DataModule.Create(AOwner: TComponent);');
  ALines.Add('begin');
  ALines.Add('  inherited;');
  ALines.Add('  FConnection := TFDConnection.Create(nil);');
  ALines.Add('end;');
  ALines.Add('');
  ALines.Add('destructor TRadIA' + AEntityName + 'DataModule.Destroy;');
  ALines.Add('begin');
  ALines.Add('  FConnection.Free;');
  ALines.Add('  inherited;');
  ALines.Add('end;');
end;

procedure BuildQuery(
  const ALines: TStrings;
  const AEntityName: string;
  const ATableName: string
);
begin
  ALines.Add('uses');
  ALines.Add('  FireDAC.Comp.Client;');
  ALines.Add('');
  ALines.Add('type');
  ALines.Add('  TRadIA' + AEntityName + 'Query = class sealed');
  ALines.Add('  public');
  ALines.Add('    class procedure Configure(const AQuery: TFDQuery); static;');
  ALines.Add('  end;');
  ALines.Add('');
  ALines.Add('implementation');
  ALines.Add('');
  ALines.Add('class procedure TRadIA' + AEntityName + 'Query.Configure(const AQuery: TFDQuery);');
  ALines.Add('begin');
  ALines.Add('  AQuery.SQL.Text := ''select * from ' + ATableName + ''';');
  ALines.Add('end;');
end;

procedure BuildTests(const ALines: TStrings; const AEntityName: string);
begin
  ALines.Add('uses');
  ALines.Add('  DUnitX.TestFramework;');
  ALines.Add('');
  ALines.Add('type');
  ALines.Add('  [TestFixture]');
  ALines.Add('  TRadIA' + AEntityName + 'Tests = class');
  ALines.Add('  public');
  ALines.Add('    [Test]');
  ALines.Add('    procedure GeneratedFixtureIsReady;');
  ALines.Add('  end;');
  ALines.Add('');
  ALines.Add('implementation');
  ALines.Add('');
  ALines.Add('procedure TRadIA' + AEntityName + 'Tests.GeneratedFixtureIsReady;');
  ALines.Add('begin');
  ALines.Add('  Assert.IsTrue(True);');
  ALines.Add('end;');
  ALines.Add('');
  ALines.Add('initialization');
  ALines.Add('  TDUnitX.RegisterTestFixture(TRadIA' + AEntityName + 'Tests);');
end;

function TRadIAFireDACGenerationTool.BuildContent(
  const AUnitName: string;
  const AEntityName: string;
  const ATableName: string
): string;
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.LineBreak := sLineBreak;
    AddUnitHeader(LLines, AUnitName);
    case FKind of
      fgkRepository: BuildRepository(LLines, AEntityName, ATableName);
      fgkDataModule: BuildDataModule(LLines, AEntityName);
      fgkQuery: BuildQuery(LLines, AEntityName, ATableName);
      fgkDto: BuildDto(LLines, AEntityName);
      fgkTests: BuildTests(LLines, AEntityName);
    end;
    if FKind = fgkDto then
    begin
      LLines.Add('');
      LLines.Add('implementation');
    end;
    LLines.Add('');
    LLines.Add('end.');
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function TRadIAFireDACGenerationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LDirectory: string;
  LEntityName: string;
  LFileName: string;
  LResult: TRadIAGeneratedArtifactResult;
  LTableName: string;
  LUnitName: string;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
  try
    LUnitName := LArguments.GetValue<string>('unitName', '').Trim;
    LEntityName := LArguments.GetValue<string>('entityName', '').Trim;
    LTableName := LArguments.GetValue<string>('tableName', '').Trim;
    if not IsUnitName(LUnitName) or not IsIdentifier(LEntityName) then
      Exit(TRadIAToolResult.Failed('invalid_name', 'A RadIA unit name and valid entity identifier are required.'));
    if FKind in [fgkRepository, fgkQuery] then
    begin
      if not IsIdentifier(LTableName) then
        Exit(TRadIAToolResult.Failed('invalid_table', 'A simple table identifier is required.'));
    end;
    LDirectory := LArguments.GetValue<string>('relativeDirectory', 'Source');
    LFileName := TPath.Combine(LDirectory, LUnitName + '.pas');
    LResult := FArtifacts.Prepare(
      LFileName,
      BuildContent(LUnitName, LEntityName, LTableName),
      LArguments.GetValue<Boolean>('registerInProject', True)
    );
    Result := ResultToToolResult(LResult);
  finally
    LArguments.Free;
  end;
end;

function TRadIAFireDACGenerationTool.ResultToToolResult(
  const AResult: TRadIAGeneratedArtifactResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(AResult.ErrorCode, AResult.ErrorMessage));
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('fileName', AResult.Preview.FileName);
    LJson.AddPair('content', AResult.Preview.Content);
    LJson.AddPair('sha256', AResult.Preview.Revision);
    LJson.AddPair('state', 'prepared');
    LJson.AddPair('expiresAtUtc', DateToISO8601(AResult.Preview.ExpiresAtUtc, True));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAFireDACGenerationTool.GetDescriptor: TRadIAToolDescriptor;
begin
  case FKind of
    fgkRepository:
      Result := TRadIAToolDescriptor.Create(
        'GenerateFireDACRepositoryPreview',
        '1.0.0',
        'Prepares a deterministic FireDAC repository preview without creating files.',
        CGenerationInputSchema,
        CGenerationOutputSchema,
        trReadOnly
      );
    fgkDataModule:
      Result := TRadIAToolDescriptor.Create(
        'GenerateFireDACDataModulePreview',
        '1.0.0',
        'Prepares a deterministic FireDAC data module preview without creating files.',
        CGenerationInputSchema,
        CGenerationOutputSchema,
        trReadOnly
      );
    fgkQuery:
      Result := TRadIAToolDescriptor.Create(
        'GenerateFireDACQueryPreview',
        '1.0.0',
        'Prepares a deterministic FireDAC query preview without creating files.',
        CGenerationInputSchema,
        CGenerationOutputSchema,
        trReadOnly
      );
    fgkDto:
      Result := TRadIAToolDescriptor.Create(
        'GenerateFireDACDTOPreview',
        '1.0.0',
        'Prepares a deterministic FireDAC DTO preview without creating files.',
        CGenerationInputSchema,
        CGenerationOutputSchema,
        trReadOnly
      );
    fgkTests:
      Result := TRadIAToolDescriptor.Create(
        'GenerateFireDACTests',
        '1.0.0',
        'Prepares a deterministic FireDAC DUnitX test preview without creating files.',
        CGenerationInputSchema,
        CGenerationOutputSchema,
        trReadOnly
      );
  end;
  Result := Result.WithExecutionOptions(10000, True);
end;

procedure RegisterRadIAFireDACGenerationTools(
  const ARegistry: IRadIAToolRegistry;
  const AArtifacts: IRadIAGeneratedArtifactService
);
var
  LKind: TRadIAFireDACGenerationKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  for LKind := Low(TRadIAFireDACGenerationKind) to High(TRadIAFireDACGenerationKind) do
    ARegistry.RegisterTool(TRadIAFireDACGenerationTool.Create(LKind, AArtifacts));
end;

end.
