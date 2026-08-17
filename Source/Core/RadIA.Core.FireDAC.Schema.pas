unit RadIA.Core.FireDAC.Schema;

interface

uses
  System.Generics.Collections,
  System.JSON,
  RadIA.Core.FireDAC.Model;

const
  CRadIAFireDACMaximumSchemaExpectations = 2048;

type
  TRadIAFireDACSchemaExpectation = record
  private
    FColumnName: string;
    FDataType: string;
    FLocation: TRadIAFireDACLocation;
    FNullable: string;
    FTableName: string;
  public
    constructor Create(
      const ATableName: string;
      const AColumnName: string;
      const ADataType: string;
      const ANullable: string;
      const ALocation: TRadIAFireDACLocation
    );
    property ColumnName: string read FColumnName;
    property DataType: string read FDataType;
    property Location: TRadIAFireDACLocation read FLocation;
    property Nullable: string read FNullable;
    property TableName: string read FTableName;
  end;

  TRadIAFireDACSchemaComparison = class
  private
    FCheckedColumnCount: Integer;
    FFindings: TList<TRadIAFireDACFinding>;
    FTruncated: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    function ToJson: string;
    property CheckedColumnCount: Integer read FCheckedColumnCount write FCheckedColumnCount;
    property Truncated: Boolean read FTruncated write FTruncated;
  end;

  TRadIAFireDACSchemaComparator = class
  private
    function Affinity(const ADataType: string): string;
    function FindColumn(const ATable: TJSONObject; const AName: string): TJSONObject;
    function FindTable(const ASchema: TJSONObject; const AName: string): TJSONObject;
    procedure CompareColumn(
      const AExpectation: TRadIAFireDACSchemaExpectation;
      const AColumn: TJSONObject;
      const AResult: TRadIAFireDACSchemaComparison
    );
  public
    function Compare(
      const ASchema: TJSONObject;
      const AExpectations: TArray<TRadIAFireDACSchemaExpectation>
    ): TRadIAFireDACSchemaComparison;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils;

constructor TRadIAFireDACSchemaExpectation.Create(
  const ATableName: string;
  const AColumnName: string;
  const ADataType: string;
  const ANullable: string;
  const ALocation: TRadIAFireDACLocation
);
begin
  FTableName := ATableName;
  FColumnName := AColumnName;
  FDataType := ADataType;
  FNullable := ANullable;
  FLocation := ALocation;
end;

constructor TRadIAFireDACSchemaComparison.Create;
begin
  inherited Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
end;

destructor TRadIAFireDACSchemaComparison.Destroy;
begin
  FFindings.Free;
  inherited;
end;

procedure TRadIAFireDACSchemaComparison.AddFinding(const AFinding: TRadIAFireDACFinding);
begin
  if FFindings.Count >= CRadIAFireDACMaximumFindings then
  begin
    FTruncated := True;
    Exit;
  end;
  FFindings.Add(AFinding);
end;

function TRadIAFireDACSchemaComparison.ToJson: string;
var
  LArray: TJSONArray;
  LFinding: TRadIAFireDACFinding;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('dialect', 'sqlite');
    LRoot.AddPair('checkedColumnCount', TJSONNumber.Create(FCheckedColumnCount));
    LRoot.AddPair('truncated', TJSONBool.Create(FTruncated));
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(RadIAFireDACFindingToJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('queryExecuted', TJSONBool.Create(False));
    LRoot.AddPair('schemaReadOnly', TJSONBool.Create(True));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACSchemaComparator.Affinity(const ADataType: string): string;
var
  LValue: string;
begin
  LValue := ADataType.ToUpper;
  if ContainsText(LValue, 'INT') then
    Exit('integer');
  if ContainsText(LValue, 'CHAR') or ContainsText(LValue, 'CLOB') or
    ContainsText(LValue, 'TEXT') or ContainsText(LValue, 'STRING') then
    Exit('text');
  if ContainsText(LValue, 'BLOB') or ContainsText(LValue, 'BINARY') or
    ContainsText(LValue, 'BYTES') then
    Exit('blob');
  if ContainsText(LValue, 'REAL') or ContainsText(LValue, 'FLOA') or
    ContainsText(LValue, 'DOUB') then
    Exit('real');
  if LValue.IsEmpty then
    Exit('blob');
  Result := 'numeric';
end;

function TRadIAFireDACSchemaComparator.FindTable(
  const ASchema: TJSONObject;
  const AName: string
): TJSONObject;
var
  LItem: TJSONValue;
  LObjects: TJSONArray;
begin
  Result := nil;
  LObjects := ASchema.GetValue<TJSONArray>('objects');
  if not Assigned(LObjects) then
    Exit;
  for LItem in LObjects do
    if (LItem is TJSONObject) and
      SameText(TJSONObject(LItem).GetValue<string>('name', ''), AName) and
      SameText(TJSONObject(LItem).GetValue<string>('objectType', ''), 'table') then
      Exit(TJSONObject(LItem));
end;

function TRadIAFireDACSchemaComparator.FindColumn(
  const ATable: TJSONObject;
  const AName: string
): TJSONObject;
var
  LColumns: TJSONArray;
  LItem: TJSONValue;
begin
  Result := nil;
  LColumns := ATable.GetValue<TJSONArray>('columns');
  if not Assigned(LColumns) then
    Exit;
  for LItem in LColumns do
    if (LItem is TJSONObject) and
      SameText(TJSONObject(LItem).GetValue<string>('name', ''), AName) then
      Exit(TJSONObject(LItem));
end;

procedure TRadIAFireDACSchemaComparator.CompareColumn(
  const AExpectation: TRadIAFireDACSchemaExpectation;
  const AColumn: TJSONObject;
  const AResult: TRadIAFireDACSchemaComparison
);
var
  LActualType: string;
  LNotNull: Boolean;
begin
  LActualType := AColumn.GetValue<string>('dataType', '');
  if not AExpectation.DataType.IsEmpty and
    not SameText(Affinity(AExpectation.DataType), Affinity(LActualType)) then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.schema.type-mismatch', ffsMedium, ffcStrong,
      'FireDAC type differs from SQLite affinity',
      'The expected code type and SQLite column affinity are different.',
      TRadIAFireDACFindingDetails.Create(
        AExpectation.Location, AExpectation.TableName + '.' + AExpectation.ColumnName,
        'Expected ' + Affinity(AExpectation.DataType) + '; schema reports ' + Affinity(LActualType) + '.',
        'Review the FireDAC field or DTO type before applying a change.', False
      )
    ));
  LNotNull := AColumn.GetValue<Boolean>('notNull', False);
  if SameText(AExpectation.Nullable, 'true') and LNotNull then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.schema.nullability-mismatch', ffsMedium, ffcStrong,
      'FireDAC nullability differs from SQLite schema',
      'Code permits null while the SQLite column is declared NOT NULL.',
      TRadIAFireDACFindingDetails.Create(
        AExpectation.Location, AExpectation.TableName + '.' + AExpectation.ColumnName,
        'Code nullable=true; schema notNull=true.',
        'Align the code contract or schema through a separately reviewed migration.', False
      )
    ));
  if SameText(AExpectation.Nullable, 'false') and not LNotNull then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.schema.nullability-mismatch', ffsMedium, ffcStrong,
      'FireDAC nullability differs from SQLite schema',
      'Code requires a value while the SQLite column permits null.',
      TRadIAFireDACFindingDetails.Create(
        AExpectation.Location, AExpectation.TableName + '.' + AExpectation.ColumnName,
        'Code nullable=false; schema notNull=false.',
        'Align the code contract or schema through a separately reviewed migration.', False
      )
    ));
  if SameText(Affinity(LActualType), 'blob') then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.schema.blob-column', ffsInfo, ffcInformational,
      'SQLite column stores binary content',
      'BLOB values require bounded handling and must not be included in AI context by default.',
      TRadIAFireDACFindingDetails.Create(
        AExpectation.Location, AExpectation.TableName + '.' + AExpectation.ColumnName,
        'SQLite affinity is blob.', 'Keep binary values out of reports and prompts.', False
      )
    ));
  if AColumn.GetValue<Boolean>('sensitive', False) then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.schema.sensitive-column', ffsInfo, ffcProven,
      'SQLite column name indicates sensitive data',
      'The local database service classified this column as sensitive.',
      TRadIAFireDACFindingDetails.Create(
        AExpectation.Location, AExpectation.TableName + '.' + AExpectation.ColumnName,
        'Schema metadata reports sensitive=true.',
        'Preserve redaction in previews, exports, logs, and AI prompts.', False
      )
    ));
end;

function TRadIAFireDACSchemaComparator.Compare(
  const ASchema: TJSONObject;
  const AExpectations: TArray<TRadIAFireDACSchemaExpectation>
): TRadIAFireDACSchemaComparison;
var
  LColumn: TJSONObject;
  LExpectation: TRadIAFireDACSchemaExpectation;
  LTable: TJSONObject;
begin
  Result := TRadIAFireDACSchemaComparison.Create;
  try
    for LExpectation in AExpectations do
    begin
      if Result.CheckedColumnCount >= CRadIAFireDACMaximumSchemaExpectations then
      begin
        Result.Truncated := True;
        Break;
      end;
      Result.CheckedColumnCount := Result.CheckedColumnCount + 1;
      LTable := FindTable(ASchema, LExpectation.TableName);
      if not Assigned(LTable) then
      begin
        Result.AddFinding(TRadIAFireDACFinding.Create(
          'firedac.schema.table-missing', ffsHigh, ffcProven,
          'Expected SQLite table is missing',
          'A table referenced by the FireDAC code is absent from the authorized schema.',
          TRadIAFireDACFindingDetails.Create(
            LExpectation.Location, LExpectation.TableName,
            'The schema contains no table named ' + LExpectation.TableName + '.',
            'Review the database selection or prepare a separately consented migration.', False
          )
        ));
        Continue;
      end;
      LColumn := FindColumn(LTable, LExpectation.ColumnName);
      if not Assigned(LColumn) then
      begin
        Result.AddFinding(TRadIAFireDACFinding.Create(
          'firedac.schema.column-missing', ffsHigh, ffcProven,
          'Expected SQLite column is missing',
          'A column expected by the FireDAC code is absent from the authorized schema.',
          TRadIAFireDACFindingDetails.Create(
            LExpectation.Location, LExpectation.TableName + '.' + LExpectation.ColumnName,
            'The table exists but the expected column does not.',
            'Review the code mapping or prepare a separately consented migration.', False
          )
        ));
        Continue;
      end;
      CompareColumn(LExpectation, LColumn, Result);
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
