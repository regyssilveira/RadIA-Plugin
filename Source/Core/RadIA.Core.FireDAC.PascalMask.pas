unit RadIA.Core.FireDAC.PascalMask;

interface

function RadIAMaskPascalNonCode(const AContent: string): string;

implementation

uses
  System.SysUtils;

type
  TRadIAPascalMaskState = (pmsCode, pmsString, pmsBraceComment, pmsParenComment, pmsLineComment);

  TRadIAPascalMasker = class
  private
    FCharacters: TArray<Char>;
    FContent: string;
    FIndex: Integer;
    FState: TRadIAPascalMaskState;
    procedure EnterState;
    procedure MaskCurrentCharacter;
    procedure ProcessBraceComment;
    procedure ProcessCharacter;
    procedure ProcessLineComment;
    procedure ProcessParenComment;
    procedure ProcessString;
  public
    constructor Create(const AContent: string);
    function Execute: string;
  end;

constructor TRadIAPascalMasker.Create(const AContent: string);
begin
  inherited Create;
  FContent := AContent;
  FCharacters := AContent.ToCharArray;
  FIndex := Low(FCharacters);
  FState := pmsCode;
end;

procedure TRadIAPascalMasker.EnterState;
begin
  if FCharacters[FIndex] = '''' then
    FState := pmsString
  else if FCharacters[FIndex] = '{' then
    FState := pmsBraceComment
  else if (FIndex < High(FCharacters)) and
    (FCharacters[FIndex] = '(') and (FCharacters[FIndex + 1] = '*') then
    FState := pmsParenComment
  else if (FIndex < High(FCharacters)) and
    (FCharacters[FIndex] = '/') and (FCharacters[FIndex + 1] = '/') then
    FState := pmsLineComment;
end;

function TRadIAPascalMasker.Execute: string;
begin
  while FIndex <= High(FCharacters) do
  begin
    ProcessCharacter;
    Inc(FIndex);
  end;
  Result := string.Create(FCharacters);
end;

procedure TRadIAPascalMasker.MaskCurrentCharacter;
begin
  if not CharInSet(FCharacters[FIndex], [#10, #13]) then
    FCharacters[FIndex] := ' ';
end;

procedure TRadIAPascalMasker.ProcessBraceComment;
begin
  MaskCurrentCharacter;
  if FContent.Chars[FIndex] = '}' then
    FState := pmsCode;
end;

procedure TRadIAPascalMasker.ProcessCharacter;
begin
  case FState of
    pmsCode: EnterState;
    pmsString: ProcessString;
    pmsBraceComment: ProcessBraceComment;
    pmsParenComment: ProcessParenComment;
    pmsLineComment: ProcessLineComment;
  end;
end;

procedure TRadIAPascalMasker.ProcessLineComment;
begin
  MaskCurrentCharacter;
  if CharInSet(FContent.Chars[FIndex], [#10, #13]) then
    FState := pmsCode;
end;

procedure TRadIAPascalMasker.ProcessParenComment;
begin
  MaskCurrentCharacter;
  if (FIndex < High(FCharacters)) and
    (FContent.Chars[FIndex] = '*') and (FContent.Chars[FIndex + 1] = ')') then
  begin
    Inc(FIndex);
    FCharacters[FIndex] := ' ';
    FState := pmsCode;
  end;
end;

procedure TRadIAPascalMasker.ProcessString;
begin
  MaskCurrentCharacter;
  if (FContent.Chars[FIndex] = '''') and (FIndex < High(FCharacters)) and
    (FContent.Chars[FIndex + 1] = '''') then
  begin
    Inc(FIndex);
    FCharacters[FIndex] := ' ';
  end
  else if FContent.Chars[FIndex] = '''' then
    FState := pmsCode;
end;

function RadIAMaskPascalNonCode(const AContent: string): string;
var
  LMasker: TRadIAPascalMasker;
begin
  LMasker := TRadIAPascalMasker.Create(AContent);
  try
    Result := LMasker.Execute;
  finally
    LMasker.Free;
  end;
end;

end.
