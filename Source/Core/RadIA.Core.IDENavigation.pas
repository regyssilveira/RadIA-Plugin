unit RadIA.Core.IDENavigation;

interface

type
  TRadIAUnitSymbol = record
  private
    FKind: string;
    FName: string;
    FLine: Integer;
  public
    constructor Create(
      const AKind: string;
      const AName: string;
      const ALine: Integer
    );
    property Kind: string read FKind;
    property Name: string read FName;
    property Line: Integer read FLine;
  end;

  TRadIAIDEAction = record
  private
    FName: string;
    FCaption: string;
    FEnabled: Boolean;
  public
    constructor Create(
      const AName: string;
      const ACaption: string;
      const AEnabled: Boolean
    );
    property Name: string read FName;
    property Caption: string read FCaption;
    property Enabled: Boolean read FEnabled;
  end;

  TRadIANavigationResult = record
  private
    FSuccess: Boolean;
    FFileName: string;
    FLine: Integer;
    FColumn: Integer;
    FMessage: string;
  public
    class function Failed(
      const AMessage: string
    ): TRadIANavigationResult; static;
    class function Succeeded(
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer;
      const AMessage: string
    ): TRadIANavigationResult; static;
    function ToDiagnosticText: string;
    property Success: Boolean read FSuccess;
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property Message: string read FMessage;
  end;

  IRadIAIDENavigationFacade = interface
    ['{E11487A6-D8A5-45C7-AE2F-0219B672BC01}']
    function ListProjectGroupProjects: TArray<string>;
    function GetProjectDependencies: TArray<string>;
    function GetUnitSymbols(
      const AMaxSymbols: Integer
    ): TArray<TRadIAUnitSymbol>;
    function NavigateToFile(
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer
    ): TRadIANavigationResult;
    function NavigateToSymbol(
      const ASymbol: string
    ): TRadIANavigationResult;
    function ListIDEActions: TArray<TRadIAIDEAction>;
    function ExecuteIDEAction(
      const AActionName: string
    ): TRadIANavigationResult;
  end;

  TRadIAUnitSymbolScanner = class
  private
    class function ExtractRoutineName(
      const ALine: string
    ): string; static;
    class function ExtractTypeName(
      const ALine: string
    ): string; static;
    class function RoutineKind(
      const ALine: string
    ): string; static;
    class function TypeKind(
      const ALine: string
    ): string; static;
  public
    class function Scan(
      const AContent: string;
      const AMaxSymbols: Integer
    ): TArray<TRadIAUnitSymbol>; static;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils;

{ TRadIAUnitSymbol }

constructor TRadIAUnitSymbol.Create(
  const AKind: string;
  const AName: string;
  const ALine: Integer
);
begin
  FKind := AKind;
  FName := AName;
  FLine := ALine;
end;

{ TRadIAIDEAction }

constructor TRadIAIDEAction.Create(
  const AName: string;
  const ACaption: string;
  const AEnabled: Boolean
);
begin
  FName := AName;
  FCaption := ACaption;
  FEnabled := AEnabled;
end;

{ TRadIANavigationResult }

class function TRadIANavigationResult.Failed(
  const AMessage: string
): TRadIANavigationResult;
begin
  Result := Default(TRadIANavigationResult);
  Result.FMessage := AMessage;
end;

class function TRadIANavigationResult.Succeeded(
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer;
  const AMessage: string
): TRadIANavigationResult;
begin
  Result := Default(TRadIANavigationResult);
  Result.FSuccess := True;
  Result.FFileName := AFileName;
  Result.FLine := ALine;
  Result.FColumn := AColumn;
  Result.FMessage := AMessage;
end;

function TRadIANavigationResult.ToDiagnosticText: string;
begin
  Result := Format(
    '%s|%s|%d|%d|%s',
    [
      BoolToStr(Success, True),
      FileName,
      Line,
      Column,
      Message
    ]
  );
end;

{ TRadIAUnitSymbolScanner }

class function TRadIAUnitSymbolScanner.ExtractRoutineName(
  const ALine: string
): string;
var
  LEndIndex: Integer;
  LStartIndex: Integer;
  LText: string;
begin
  LText := Trim(ALine);
  if StartsText('class ', LText) then
    Delete(LText, 1, Length('class '));
  LStartIndex := Pos(' ', LText);
  if LStartIndex = 0 then
    Exit('');
  LText := Trim(Copy(LText, LStartIndex + 1, MaxInt));
  LEndIndex := 1;
  while (LEndIndex <= Length(LText)) and
    not CharInSet(LText[LEndIndex], ['(', ':', ';', ' ', '=']) do
    Inc(LEndIndex);
  Result := Copy(LText, 1, LEndIndex - 1);
end;

class function TRadIAUnitSymbolScanner.ExtractTypeName(
  const ALine: string
): string;
var
  LEqualsIndex: Integer;
begin
  LEqualsIndex := Pos('=', ALine);
  if LEqualsIndex = 0 then
    Exit('');
  Result := Trim(Copy(ALine, 1, LEqualsIndex - 1));
  if Pos(' ', Result) > 0 then
    Result := '';
end;

class function TRadIAUnitSymbolScanner.RoutineKind(
  const ALine: string
): string;
var
  LText: string;
begin
  LText := Trim(ALine);
  if StartsText('class ', LText) then
    Delete(LText, 1, Length('class '));
  if StartsText('procedure ', LText) then
    Exit('procedure');
  if StartsText('function ', LText) then
    Exit('function');
  if StartsText('constructor ', LText) then
    Exit('constructor');
  if StartsText('destructor ', LText) then
    Exit('destructor');
  Result := '';
end;

class function TRadIAUnitSymbolScanner.Scan(
  const AContent: string;
  const AMaxSymbols: Integer
): TArray<TRadIAUnitSymbol>;
var
  LKind: string;
  LLineIndex: Integer;
  LLines: TStringList;
  LName: string;
  LSymbols: TList<TRadIAUnitSymbol>;
begin
  if AMaxSymbols <= 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  LLines := TStringList.Create;
  LSymbols := TList<TRadIAUnitSymbol>.Create;
  try
    LLines.Text := AContent;
    for LLineIndex := 0 to LLines.Count - 1 do
    begin
      LKind := RoutineKind(LLines[LLineIndex]);
      if LKind <> '' then
        LName := ExtractRoutineName(LLines[LLineIndex])
      else
      begin
        LKind := TypeKind(LLines[LLineIndex]);
        if LKind <> '' then
          LName := ExtractTypeName(LLines[LLineIndex])
        else
          LName := '';
      end;
      if LName <> '' then
        LSymbols.Add(
          TRadIAUnitSymbol.Create(
            LKind,
            LName,
            LLineIndex + 1
          )
        );
      if LSymbols.Count >= AMaxSymbols then
        Break;
    end;
    Result := LSymbols.ToArray;
  finally
    LSymbols.Free;
    LLines.Free;
  end;
end;

class function TRadIAUnitSymbolScanner.TypeKind(
  const ALine: string
): string;
var
  LText: string;
begin
  LText := LowerCase(Trim(ALine));
  if Pos('= class', LText) > 0 then
    Exit('class');
  if Pos('= record', LText) > 0 then
    Exit('record');
  if Pos('= interface', LText) > 0 then
    Exit('interface');
  if Pos('= enum', LText) > 0 then
    Exit('enum');
  Result := '';
end;

end.
