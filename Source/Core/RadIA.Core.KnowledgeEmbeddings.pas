unit RadIA.Core.KnowledgeEmbeddings;

interface

uses
  RadIA.Core.Knowledge;

type
  TRadIALocalHashEmbeddingProvider = class(
    TInterfacedObject,
    IRadIAKnowledgeEmbeddingProvider
  )
  private
    class function HashToken(const AToken: string): Cardinal; static;
    class function NormalizeToken(const AToken: string): string; static;
  public
    function GetId: string;
    function GetDimensions: Integer;
    function IsLocal: Boolean;
    function Embed(const AText: string): TArray<Single>;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils;

const
  CEmbeddingDimensions = 256;

function TRadIALocalHashEmbeddingProvider.Embed(
  const AText: string
): TArray<Single>;
var
  LBuilder: TStringBuilder;
  LCharacter: Char;
  LHash: Cardinal;
  LIndex: Integer;
  LMagnitude: Double;
  LToken: string;

  function IsTokenCharacter(const ACharacter: Char): Boolean;
  begin
    Result := (ACharacter = '_') or
      ((ACharacter >= '0') and (ACharacter <= '9')) or
      ((ACharacter >= 'A') and (ACharacter <= 'Z')) or
      ((ACharacter >= 'a') and (ACharacter <= 'z')) or
      (Ord(ACharacter) > 127);
  end;

  procedure AddToken;
  begin
    if LBuilder.Length < 2 then
    begin
      LBuilder.Clear;
      Exit;
    end;
    LToken := NormalizeToken(LBuilder.ToString);
    LHash := HashToken(LToken);
    LIndex := Integer(LHash mod CEmbeddingDimensions);
    if (LHash and $100) = 0 then
      Result[LIndex] := Result[LIndex] + 1
    else
      Result[LIndex] := Result[LIndex] - 1;
    LBuilder.Clear;
  end;

begin
  SetLength(Result, CEmbeddingDimensions);
  LBuilder := TStringBuilder.Create;
  try
    for LCharacter in AText do
    begin
      if IsTokenCharacter(LCharacter) then
        LBuilder.Append(LCharacter)
      else
        AddToken;
    end;
    AddToken;
  finally
    LBuilder.Free;
  end;
  LMagnitude := 0;
  for LIndex := 0 to Length(Result) - 1 do
    LMagnitude := LMagnitude + Sqr(Result[LIndex]);
  if LMagnitude <= 0 then
    Exit;
  LMagnitude := Sqrt(LMagnitude);
  for LIndex := 0 to Length(Result) - 1 do
    Result[LIndex] := Result[LIndex] / LMagnitude;
end;

function TRadIALocalHashEmbeddingProvider.GetDimensions: Integer;
begin
  Result := CEmbeddingDimensions;
end;

function TRadIALocalHashEmbeddingProvider.GetId: string;
begin
  Result := 'local-hash-v1';
end;

class function TRadIALocalHashEmbeddingProvider.HashToken(
  const AToken: string
): Cardinal;
var
  LCharacter: Char;
begin
  Result := 2166136261;
  for LCharacter in AToken do
  begin
    Result := Result xor Ord(LCharacter);
    Result := Result * 16777619;
  end;
end;

function TRadIALocalHashEmbeddingProvider.IsLocal: Boolean;
begin
  Result := True;
end;

class function TRadIALocalHashEmbeddingProvider.NormalizeToken(
  const AToken: string
): string;
begin
  Result := LowerCase(AToken);
  if MatchText(Result, ['create', 'creates', 'creating', 'new']) then
    Result := 'create'
  else if MatchText(Result, ['delete', 'deletes', 'deleting', 'remove']) then
    Result := 'delete'
  else if MatchText(Result, ['find', 'search', 'lookup', 'locate']) then
    Result := 'search'
  else if MatchText(Result, ['calculate', 'compute', 'sum', 'total']) then
    Result := 'calculate'
  else if MatchText(Result, ['error', 'exception', 'failure', 'fault']) then
    Result := 'error';
end;

end.
