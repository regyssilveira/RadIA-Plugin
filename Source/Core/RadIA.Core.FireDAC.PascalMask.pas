unit RadIA.Core.FireDAC.PascalMask;

interface

function RadIAMaskPascalNonCode(const AContent: string): string;

implementation

uses
  System.SysUtils;

type
  TRadIAPascalMaskState = (pmsCode, pmsString, pmsBraceComment, pmsParenComment, pmsLineComment);

function RadIAMaskPascalNonCode(const AContent: string): string;
var
  I: Integer;
  LChars: TArray<Char>;
  LState: TRadIAPascalMaskState;
begin
  LChars := AContent.ToCharArray;
  LState := pmsCode;
  I := Low(LChars);
  while I <= High(LChars) do
  begin
    case LState of
      pmsCode:
        if LChars[I] = '''' then
          LState := pmsString
        else if LChars[I] = '{' then
          LState := pmsBraceComment
        else if (LChars[I] = '(') and (I < High(LChars)) and (LChars[I + 1] = '*') then
          LState := pmsParenComment
        else if (LChars[I] = '/') and (I < High(LChars)) and (LChars[I + 1] = '/') then
          LState := pmsLineComment;
      pmsString:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if (AContent.Chars[I] = '''') and (I < High(LChars)) and (AContent.Chars[I + 1] = '''') then
          begin
            Inc(I);
            LChars[I] := ' ';
          end
          else if AContent.Chars[I] = '''' then
            LState := pmsCode;
        end;
      pmsBraceComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if AContent.Chars[I] = '}' then
            LState := pmsCode;
        end;
      pmsParenComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if (AContent.Chars[I] = '*') and (I < High(LChars)) and (AContent.Chars[I + 1] = ')') then
          begin
            Inc(I);
            LChars[I] := ' ';
            LState := pmsCode;
          end;
        end;
      pmsLineComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if CharInSet(AContent.Chars[I], [#10, #13]) then
            LState := pmsCode;
        end;
    end;
    Inc(I);
  end;
  Result := string.Create(LChars);
end;

end.
