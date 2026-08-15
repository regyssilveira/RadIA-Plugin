unit RadIA.Core.PromptTemplates;

interface

uses
  System.JSON, System.Generics.Collections;

type
  { Represents a single prompt template }
  TPromptTemplate = record
    Name: string;
    Description: string;
    Template: string;
    IsProjectGenerator: Boolean;
    SlashCommand: string;
    IsSystem: Boolean;
    IsCustomized: Boolean;
  end;

  { Manages prompt templates with persistence in AppData }
  TPromptTemplateManager = class
  private
    FTemplates: TList<TPromptTemplate>;        // Active combined list
    FDefaultTemplates: TList<TPromptTemplate>; // Hardcoded system defaults
    FUserTemplates: TList<TPromptTemplate>;    // User overrides and custom templates loaded from json
    FFilePath: string;

    procedure CreateDefaultTemplates;
    function FindUserTemplate(const AName: string; out ATemplate: TPromptTemplate): Boolean;
    function FindDefaultTemplate(const AName: string; out ATemplate: TPromptTemplate): Boolean;
    procedure ParseTemplateJsonArray(AArr: TJSONArray);
    function IsLegacyReviewTemplate(const ATemplate: string): Boolean;
    function NormalizeLineEndings(const AText: string): string;
    procedure BuildActiveTemplates;
    procedure CleanRedundantUserTemplates;
  public
    constructor Create(const ABaseDir: string = '');
    destructor Destroy; override;

    procedure Load;
    procedure Save;
    procedure AddTemplate(const AName, ADescription, ATemplate: string; const AIsProjectGenerator: Boolean = False;
        const ASlashCommand: string = '');
    procedure DeleteTemplate(const AName: string);
    procedure RestoreDefaultTemplate(const AName: string);
    procedure RestoreDefaultTemplates;
    function GetTemplates: TArray<TPromptTemplate>;
    function FindTemplate(const AName: string; out ATemplate: TPromptTemplate): Boolean;
    function ResolveTemplate(const AName: string; const AActiveCode: string): string;

    { Backup / Restore }
    procedure ExportToFile(const AFileName: string);
    function ImportFromFile(const AFileName: string; const AMerge: Boolean; out AErrorMsg: string): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, RadIA.Core.Logger;

{ TPromptTemplateManager }

constructor TPromptTemplateManager.Create(const ABaseDir: string);
begin
  inherited Create;
  FTemplates := TList<TPromptTemplate>.Create;
  FDefaultTemplates := TList<TPromptTemplate>.Create;
  FUserTemplates := TList<TPromptTemplate>.Create;
  if ABaseDir.IsEmpty then
    FFilePath := TPath.Combine(TPath.GetHomePath, 'RadIA\templates.json')
  else
    FFilePath := TPath.Combine(ABaseDir, 'templates.json');
end;

destructor TPromptTemplateManager.Destroy;
begin
  FTemplates.Free;
  FDefaultTemplates.Free;
  FUserTemplates.Free;
  inherited Destroy;
end;

procedure TPromptTemplateManager.CreateDefaultTemplates;
  procedure AddDefault(const AName, ADescription, ATemplate: string; const AIsProjectGenerator: Boolean = False;
      const ASlashCommand: string = '');
  var
    LTemplate: TPromptTemplate;
  begin
    LTemplate.Name := AName;
    LTemplate.Description := ADescription;
    LTemplate.Template := ATemplate;
    LTemplate.IsProjectGenerator := AIsProjectGenerator;
    LTemplate.SlashCommand := ASlashCommand;
    LTemplate.IsSystem := True;
    LTemplate.IsCustomized := False;
    FDefaultTemplates.Add(LTemplate);
  end;
begin
  FDefaultTemplates.Clear;
  AddDefault(
    'Review Clean Code Delphi',
    'Review Pascal code applying Clean Code and SOLID',
    'Review this Delphi Pascal code. Be concise and list only actionable issues:'#13#10#13#10 +
    '```pascal'#13#10'{code}'#13#10'```',
    False,
    '/review'
  );
  AddDefault(
    'Explain Code',
    'Explain the selected Delphi Pascal code',
    'Explain this Delphi Pascal code briefly. Focus on intent and important details only:'#13#10#13#10 +
    '```pascal'#13#10'{code}'#13#10'```',
    False,
    '/explain'
  );
  AddDefault(
    'Document Complete Unit',
    'Generate XML documentation for classes and methods',
    'Generate Delphi XML documentation for this unit. Return only the documentation/code changes needed:'#13#10#13#10 +
    '```pascal'#13#10'{code}'#13#10'```',
    False,
    '/doc'
  );
  AddDefault(
    'Create DUnitX Mock',
    'Generate unit tests using DUnitX for the class',
    'Create focused DUnitX tests for this Delphi code. Return code first and keep notes brief:'#13#10#13#10 +
    '```pascal'#13#10'{code}'#13#10'```',
    False,
    '/test'
  );
  AddDefault(
    'Analyze Performance',
    'Identify bottlenecks and memory leaks in the code',
    'Analyze this Delphi code for performance risks, leaks, or redundant work. Be concise:'#13#10#13#10 +
    '```pascal'#13#10'{code}'#13#10'```',
    False,
    '/performance'
  );
  AddDefault(
    'Analyze Stack Trace',
    'Analyze exception stack trace and suggest root cause fixes',
    'Call AnalyzeProjectStackTrace first for the following Delphi stack trace/error log:'#13#10#13#10 +
        '{stacktrace}'#13#10#13#10'Use its resolved files, lines, confidence, and NavigateToFile when ' +
        'navigation is requested. Here is the active unit context:'#13#10#13#10'{code}',
    False,
    '/stacktrace'
  );
  AddDefault(
    'Review Leaks and SOLID',
    'Run static analysis on the unit for memory leaks and SOLID principles',
    'Perform static analysis on this Delphi code for bugs, exceptions, memory leaks, and SOLID issues.'#13#10 +
    'Be concise: list only findings that are actionable, with location/context and suggested fix.'#13#10#13#10 +
    '```pascal'#13#10'{code}'#13#10'```',
    False,
    '/bugs'
  );
  AddDefault(
    'Create Project Delphi',
    'Generate a complete Delphi project from specification with file paths',
    'You are a Senior Delphi Software Architect. Create a complete, fully functional and compilable ' +
        'Delphi project based on the following specification:'#13#10 +
    '"{specification}"'#13#10#13#10 +
    'Provide all necessary files (such as .dpr, .pas, .dfm) so the project is complete and ready to ' +
        'compile and run. Follow these strict rules:'#13#10 +
    '1. Do not use placeholders or omit any code. Write the entire implementation.'#13#10 +
    '2. You MUST start the very first line of EVERY code block with a filepath comment representing ' +
        'the relative path of that file in the project directory.'#13#10 +
    'Use the following format for each file block:'#13#10 +
    '```pascal'#13#10 +
    '// filepath: ProjectName.dpr'#13#10 +
    'program ProjectName;'#13#10 +
    '...'#13#10 +
    '```'#13#10 +
    'and for forms:'#13#10 +
    '```dfm'#13#10 +
    '// filepath: uMain.dfm'#13#10 +
    'object MainForm: TMainForm'#13#10 +
    '...'#13#10 +
    'end'#13#10 +
    '```'#13#10 +
    '3. Ensure all unit linkages, main program blocks, form definitions, and class declarations match ' +
        'and compile correctly together.'#13#10 +
    '4. Memory Safety, Type Safety and Dependencies:'#13#10 +
    '   - Enforce proper "uses" clauses: Double-check that every unit imports all units required for its ' +
    'compilation (e.g. System.Generics.Collections for generic lists, System.Classes for persistence/lists, ' +
    'System.SysUtils for exceptions/guid, Vcl.Dialogs/Forms/Controls/Graphics/StdCtrls/ExtCrts for VCL ' +
        'UI controls, etc.).'#13#10 +
    '   - Use strongly typed generic collections (from System.Generics.Collections like TList<T> or ' +
        'TDictionary<K,V>) instead of legacy non-generic collections (like TList without generic type ' +
        'parameters). Never use raw non-generic lists.',
    True,
    '/createproject'
  );
  AddDefault(
    'Create Project Delphi Architecture',
    'Generate a SOLID clean architecture Delphi project from specification with files paths',
    'You are a Senior Delphi Software Architect. Create a complete, fully functional, compilable, and ' +
        'highly structured Delphi project based on the following specification:'#13#10 +
    '"{specification}"'#13#10#13#10 +
    'Provide all necessary files (such as .dpr, .pas, .dfm) so the project is complete and ready to ' +
        'compile and run. Follow these strict rules:'#13#10 +
    '1. Do not use placeholders or omit any code. Write the entire implementation.'#13#10 +
    '2. You MUST start the very first line of EVERY code block with a filepath comment representing ' +
        'the relative path of that file in the project directory.'#13#10 +
    'Use the following format for each file block:'#13#10 +
    '```pascal'#13#10 +
    '// filepath: ProjectName.dpr'#13#10 +
    'program ProjectName;'#13#10 +
    '...'#13#10 +
    '```'#13#10 +
    'and for forms:'#13#10 +
    '```dfm'#13#10 +
    '// filepath: uMain.dfm'#13#10 +
    'object MainForm: TMainForm'#13#10 +
    '...'#13#10 +
    'end'#13#10 +
    '```'#13#10 +
    '3. Architectural Best Practices (SOLID & Clean Code):'#13#10 +
    '   - Enforce Single Responsibility Principle (SRP): Segregate business logic, calculations, and data access ' +
    'into pure Object Pascal classes or services. Do not write business logic inside UI form event handlers ' +
    '(OnClick, OnCreate, etc.). Event handlers should only call domain services.'#13#10 +
    '   - Dependency Inversion (DIP): Use interfaces (IInterface) to decouple objects where appropriate.'#13#10 +
    '4. Memory Safety & Resource Management:'#13#10 +
    '   - Prevent memory leaks: Every time an object is instantiated locally, wrap its usage inside ' +
        'a try..finally block and free it in the finally block.'#13#10 +
    '5. Delphi Naming Style Guide Conventions:'#13#10 +
    '   - Types and classes must be prefixed with "T" (e.g., TDomainService).'#13#10 +
    '   - Interfaces must be prefixed with "I" (e.g., IDomainService).'#13#10 +
    '   - Private class fields must be prefixed with "F" (e.g., FCount).'#13#10 +
    '   - Method parameters/arguments must be prefixed with "A" (e.g., AInputText).'#13#10 +
    '   - Local variables inside methods must be prefixed with "L" (e.g., LResultObj).'#13#10 +
    '6. Modern Object Pascal Features:'#13#10 +
    '   - Use strong typing, enums, advanced records, and generics (from System.Generics.Collections like ' +
    'TList<T> or TDictionary<K,V>) instead of legacy Pointer lists or untyped structures. NEVER use raw ' +
    'non-generic collections like TList without a type parameter (TList<T>) if you import ' +
    'System.Generics.Collections, and always specify its generic arguments.'#13#10 +
    '7. Compile-Ready Integration:'#13#10 +
    '   - Ensure all unit linkages, main program blocks, form definitions, and class declarations match ' +
        'and compile correctly together without external third-party dependencies unless explicitly ' +
        'requested.'#13#10 +
    '   - Double-check the "uses" clause of every unit: ensure every type, class, record, interface or ' +
    'collection used is properly imported (e.g. System.Generics.Collections for generic lists, ' +
    'System.Classes for persistence/lists, System.SysUtils for exceptions/guid, ' +
    'Vcl.Dialogs/Forms/Controls/Graphics/StdCtrls/ExtCtrls for VCL UI controls, etc.). ' +
    'Do not miss any unit dependency.',
    True,
    '/createprojectarch'
  );
  AddDefault(
    'Optimize SQL Query',
    'Analyze and optimize the selected SQL query string',
    'Optimize this SQL query. Suggest indexes, join optimization, syntax corrections, ' +
    'and general improvements contextually:'#13#10#13#10 +
    '```sql'#13#10'{code}'#13#10'```',
    False,
    '/sqloptimize'
  );
  AddDefault(
    'Scan Compiler and OS Warnings',
    'Scan code for potential compiler warnings, thread-safety issues, and Windows GDI resource leaks',
    'Analyze this Delphi code for potential compiler warnings (such as uninitialized variables, unreachable ' +
        'code, implicit typecasts, ' +
    'and unused units), thread-safety violations (like unsafe VCL concurrency usage or race conditions), ' +
        'and Windows resource leaks ' +
    '(such as unreleased GDI handles like Pen, Brush, Font, or handles without proper try..finally protection). ' +
    'Be concise, list findings location/context, and provide clean refactored suggestions:'#13#10#13#10 +
    '```pascal'#13#10'{code}'#13#10'```',
    False,
    '/scanwarnings'
  );
end;

function TPromptTemplateManager.FindUserTemplate(const AName: string; out ATemplate: TPromptTemplate): Boolean;
var
  LTemp: TPromptTemplate;
begin
  Result := False;
  for LTemp in FUserTemplates do
  begin
    if SameText(LTemp.Name, AName) then
    begin
      ATemplate := LTemp;
      Exit(True);
    end;
  end;
end;

function TPromptTemplateManager.FindDefaultTemplate(const AName: string; out ATemplate: TPromptTemplate): Boolean;
var
  LTemp: TPromptTemplate;
begin
  Result := False;
  for LTemp in FDefaultTemplates do
  begin
    if SameText(LTemp.Name, AName) then
    begin
      ATemplate := LTemp;
      Exit(True);
    end;
  end;
end;

procedure TPromptTemplateManager.BuildActiveTemplates;
var
  LDefaultTemp: TPromptTemplate;
  LUserTemp: TPromptTemplate;
  LTemp: TPromptTemplate;
  LDummy: TPromptTemplate;
begin
  FTemplates.Clear;

  // 1. Process default system templates and apply user overrides (overlays)
  for LDefaultTemp in FDefaultTemplates do
  begin
    if FindUserTemplate(LDefaultTemp.Name, LTemp) then
    begin
      LTemp.IsSystem := True;
      LTemp.IsCustomized := True;
      FTemplates.Add(LTemp);
    end
    else
    begin
      LTemp := LDefaultTemp;
      LTemp.IsSystem := True;
      LTemp.IsCustomized := False;
      FTemplates.Add(LTemp);
    end;
  end;

  // 2. Process custom templates created purely by the user
  for LUserTemp in FUserTemplates do
  begin
    if not FindDefaultTemplate(LUserTemp.Name, LDummy) then
    begin
      LTemp := LUserTemp;
      LTemp.IsSystem := False;
      LTemp.IsCustomized := False;
      FTemplates.Add(LTemp);
    end;
  end;
end;

function TPromptTemplateManager.NormalizeLineEndings(const AText: string): string;
begin
  Result := AText.Replace(#13#10, #10).Replace(#13, #10);
end;

function TPromptTemplateManager.IsLegacyReviewTemplate(const ATemplate: string): Boolean;
const
  LEGACY_REVIEW_TEMPLATE =
    'Review the following Delphi Pascal code block applying Clean Code, readability, and optimization ' +
        'principles:'#10#10'{code}';
begin
  Result := NormalizeLineEndings(ATemplate) = LEGACY_REVIEW_TEMPLATE;
end;

procedure TPromptTemplateManager.CleanRedundantUserTemplates;

  function ProcessLegacyReviewTemplate(const AUser: TPromptTemplate;
    const AIndex: Integer; var AChanged: Boolean): Boolean;
  var
    LTemp: TPromptTemplate;
  begin
    Result := False;
    if SameText(AUser.Name, 'Review Clean Code Delphi') then
    begin
      if SameText(AUser.SlashCommand, '/explain') then
      begin
        LTemp := AUser;
        LTemp.SlashCommand := '/review';
        FUserTemplates[AIndex] := LTemp;
        AChanged := True;
      end;

      if IsLegacyReviewTemplate(AUser.Template) then
      begin
        FUserTemplates.Delete(AIndex);
        AChanged := True;
        Result := True;
      end;
    end;
  end;

  function ProcessLegacyProjectTemplate(const AUser: TPromptTemplate;
    const AIndex: Integer; var AChanged: Boolean): Boolean;
  begin
    Result := False;
    if SameText(AUser.Name, 'Create Project Delphi') or SameText(AUser.Name, 'Create Project Delphi Architecture') then
    begin
      if not AUser.Template.Contains('uses') or not AUser.Template.Contains('Generics') then
      begin
        FUserTemplates.Delete(AIndex);
        AChanged := True;
        Result := True;
      end;
    end;
  end;

  function ProcessRedundantDefaultTemplate(const AUser: TPromptTemplate;
    const AIndex: Integer; var AChanged: Boolean): Boolean;
  var
    LDefault: TPromptTemplate;
  begin
    Result := False;
    if FindDefaultTemplate(AUser.Name, LDefault) then
    begin
      if (AUser.Description = LDefault.Description) and
         (NormalizeLineEndings(AUser.Template) = NormalizeLineEndings(LDefault.Template)) and
         (AUser.IsProjectGenerator = LDefault.IsProjectGenerator) and
         (AUser.SlashCommand = LDefault.SlashCommand) then
      begin
        FUserTemplates.Delete(AIndex);
        AChanged := True;
        Result := True;
      end;
    end;
  end;

var
  I: Integer;
  LUser: TPromptTemplate;
  LChanged: Boolean;
begin
  LChanged := False;
  for I := FUserTemplates.Count - 1 downto 0 do
  begin
    LUser := FUserTemplates[I];

    if ProcessLegacyReviewTemplate(LUser, I, LChanged) then Continue;
    if ProcessLegacyProjectTemplate(LUser, I, LChanged) then Continue;
    ProcessRedundantDefaultTemplate(LUser, I, LChanged);
  end;

  if LChanged then
  begin
    Save;
  end;
end;

procedure TPromptTemplateManager.ParseTemplateJsonArray(AArr: TJSONArray);
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LTemplate: TPromptTemplate;
begin
  for LVal in AArr do
  begin
    if LVal is TJSONObject then
    begin
      LObj := LVal as TJSONObject;
      LTemplate.Name := LObj.GetValue<string>('name', '');
      LTemplate.Description := LObj.GetValue<string>('description', '');
      LTemplate.Template := LObj.GetValue<string>('template', '');
      LTemplate.IsProjectGenerator := LObj.GetValue<Boolean>('isProjectGenerator', False);
      LTemplate.SlashCommand := LObj.GetValue<string>('slashCommand', '');
      LTemplate.IsSystem := False;     // Set in BuildActiveTemplates
      LTemplate.IsCustomized := False; // Set in BuildActiveTemplates

      if not LTemplate.Name.IsEmpty then
        FUserTemplates.Add(LTemplate);
    end;
  end;
end;

procedure TPromptTemplateManager.Load;
var
  LJsonContent: string;
  LParsedVal: TJSONValue;
begin
  FUserTemplates.Clear;

  // Always reload fresh default templates
  CreateDefaultTemplates;

  if not TFile.Exists(FFilePath) then
  begin
    BuildActiveTemplates;
    Exit;
  end;

  try
    LJsonContent := TFile.ReadAllText(FFilePath, TEncoding.UTF8);
    if LJsonContent.Trim.IsEmpty then
    begin
      BuildActiveTemplates;
      Exit;
    end;

    LParsedVal := TJSONObject.ParseJSONValue(LJsonContent);
    if Assigned(LParsedVal) then
    begin
      try
        if LParsedVal is TJSONArray then
          ParseTemplateJsonArray(LParsedVal as TJSONArray);
      finally
        LParsedVal.Free;
      end;
    end;
  except
    on E: Exception do
      TLogger.Log('TPromptTemplateManager.Load: Failed to load templates: ' + E.Message, 'Core');
  end;

  CleanRedundantUserTemplates;
  BuildActiveTemplates;
end;

procedure TPromptTemplateManager.Save;
var
  LJsonArr: TJSONArray;
  LObj: TJSONObject;
  LTemplate: TPromptTemplate;
begin
  ForceDirectories(TPath.GetDirectoryName(FFilePath));

  LJsonArr := TJSONArray.Create;
  try
    // Save only user modifications and user templates (avoid saving raw default system templates)
    for LTemplate in FUserTemplates do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('name', LTemplate.Name);
      LObj.AddPair('description', LTemplate.Description);
      LObj.AddPair('template', LTemplate.Template);
      LObj.AddPair('isProjectGenerator', TJSONBool.Create(LTemplate.IsProjectGenerator));
      LObj.AddPair('slashCommand', LTemplate.SlashCommand);
      LJsonArr.AddElement(LObj);
    end;

    TFile.WriteAllText(FFilePath, LJsonArr.ToJSON, TEncoding.UTF8);
  finally
    LJsonArr.Free;
  end;
end;

procedure TPromptTemplateManager.AddTemplate(const AName, ADescription, ATemplate: string;
    const AIsProjectGenerator: Boolean = False; const ASlashCommand: string = '');

var
  LTemplate: TPromptTemplate;
  I: Integer;
  LIsDefault: Boolean;
  LDefaultTemp: TPromptTemplate;
begin
  LIsDefault := False;
  for LDefaultTemp in FDefaultTemplates do
  begin
    if SameText(LDefaultTemp.Name, AName) then
    begin
      LIsDefault := True;
      Break;
    end;
  end;

  { Override existing template in FUserTemplates if name matches }
  for I := 0 to FUserTemplates.Count - 1 do
  begin
    if SameText(FUserTemplates[I].Name, AName) then
    begin
      LTemplate.Name := AName;
      LTemplate.Description := ADescription;
      LTemplate.Template := ATemplate;
      LTemplate.IsProjectGenerator := AIsProjectGenerator;
      LTemplate.SlashCommand := ASlashCommand;
      LTemplate.IsSystem := LIsDefault;
      LTemplate.IsCustomized := LIsDefault;
      FUserTemplates[I] := LTemplate;

      BuildActiveTemplates;
      Exit;
    end;
  end;

  LTemplate.Name := AName;
  LTemplate.Description := ADescription;
  LTemplate.Template := ATemplate;
  LTemplate.IsProjectGenerator := AIsProjectGenerator;
  LTemplate.SlashCommand := ASlashCommand;
  LTemplate.IsSystem := LIsDefault;
  LTemplate.IsCustomized := LIsDefault;
  FUserTemplates.Add(LTemplate);

  BuildActiveTemplates;
end;

procedure TPromptTemplateManager.DeleteTemplate(const AName: string);
var
  I: Integer;
begin
  for I := FUserTemplates.Count - 1 downto 0 do
  begin
    if SameText(FUserTemplates[I].Name, AName) then
    begin
      FUserTemplates.Delete(I);
      Break;
    end;
  end;

  BuildActiveTemplates;
end;

procedure TPromptTemplateManager.RestoreDefaultTemplate(const AName: string);
var
  I: Integer;
begin
  // Restoring a default template simply means removing its overlay from user templates list
  for I := FUserTemplates.Count - 1 downto 0 do
  begin
    if SameText(FUserTemplates[I].Name, AName) then
    begin
      FUserTemplates.Delete(I);
      Break;
    end;
  end;

  BuildActiveTemplates;
  Save;
end;

procedure TPromptTemplateManager.RestoreDefaultTemplates;
begin
  // Remove all user overrides and custom templates
  FUserTemplates.Clear;
  BuildActiveTemplates;
  Save;
end;

function TPromptTemplateManager.GetTemplates: TArray<TPromptTemplate>;
begin
  Result := FTemplates.ToArray;
end;

function TPromptTemplateManager.FindTemplate(const AName: string; out ATemplate: TPromptTemplate): Boolean;
var
  LTemp: TPromptTemplate;
begin
  for LTemp in FTemplates do
  begin
    if SameText(LTemp.Name, AName) then
    begin
      ATemplate := LTemp;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TPromptTemplateManager.ResolveTemplate(const AName: string; const AActiveCode: string): string;
var
  LTemp: TPromptTemplate;
begin
  if FindTemplate(AName, LTemp) then
  begin
    Result := LTemp.Template.Replace('{code}', AActiveCode);
  end;
end;

procedure TPromptTemplateManager.ExportToFile(const AFileName: string);
var
  LJsonArr: TJSONArray;
  LObj: TJSONObject;
  LTemplate: TPromptTemplate;
begin
  LJsonArr := TJSONArray.Create;
  try
    // Export active templates (combined system + custom templates)
    for LTemplate in FTemplates do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('name', LTemplate.Name);
      LObj.AddPair('description', LTemplate.Description);
      LObj.AddPair('template', LTemplate.Template);
      LObj.AddPair('isProjectGenerator', TJSONBool.Create(LTemplate.IsProjectGenerator));
      LObj.AddPair('slashCommand', LTemplate.SlashCommand);
      LJsonArr.AddElement(LObj);
    end;
    TFile.WriteAllText(AFileName, LJsonArr.ToJSON, TEncoding.UTF8);
  finally
    LJsonArr.Free;
  end;
end;

function TPromptTemplateManager.ImportFromFile(const AFileName: string; const AMerge: Boolean;
    out AErrorMsg: string): Boolean;
var
  LJsonContent: string;
  LParsedVal: TJSONValue;
  LJsonArr: TJSONArray;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LTemplate: TPromptTemplate;
  LImportedTemplates: TList<TPromptTemplate>;
begin
  Result := False;
  AErrorMsg := '';

  if not TFile.Exists(AFileName) then
  begin
    AErrorMsg := 'File not found.';
    Exit;
  end;

  try
    LJsonContent := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      AErrorMsg := 'Failed to read file: ' + E.Message;
      Exit;
    end;
  end;

  if LJsonContent.Trim.IsEmpty then
  begin
    AErrorMsg := 'File is empty.';
    Exit;
  end;

  LParsedVal := TJSONObject.ParseJSONValue(LJsonContent);
  if not Assigned(LParsedVal) then
  begin
    AErrorMsg := 'Invalid JSON syntax.';
    Exit;
  end;

  LImportedTemplates := TList<TPromptTemplate>.Create;
  try
    try
      if not (LParsedVal is TJSONArray) then
      begin
        AErrorMsg := 'Invalid templates format. Root must be a JSON array.';
        Exit;
      end;

      LJsonArr := LParsedVal as TJSONArray;
      for LVal in LJsonArr do
      begin
        if not (LVal is TJSONObject) then
        begin
          AErrorMsg := 'Invalid template item format. Each item must be a JSON object.';
          Exit;
        end;

        LObj := LVal as TJSONObject;
        LTemplate.Name := LObj.GetValue<string>('name', '');
        LTemplate.Description := LObj.GetValue<string>('description', '');
        LTemplate.Template := LObj.GetValue<string>('template', '');
        LTemplate.IsProjectGenerator := LObj.GetValue<Boolean>('isProjectGenerator', False);
        LTemplate.SlashCommand := LObj.GetValue<string>('slashCommand', '');
        LTemplate.IsSystem := False;
        LTemplate.IsCustomized := False;

        if LTemplate.Name.IsEmpty then
        begin
          AErrorMsg := 'Invalid template item: "name" property is mandatory.';
          Exit;
        end;

        if LTemplate.Template.IsEmpty then
        begin
          AErrorMsg := 'Invalid template item: "template" property is mandatory.';
          Exit;
        end;

        LImportedTemplates.Add(LTemplate);
      end;

      { Apply to list }
      if not AMerge then
      begin
        FUserTemplates.Clear;
      end;

      for LTemplate in LImportedTemplates do
      begin
        AddTemplate(
          LTemplate.Name,
          LTemplate.Description,
          LTemplate.Template,
          LTemplate.IsProjectGenerator,
          LTemplate.SlashCommand
        );
      end;

      CleanRedundantUserTemplates;
      BuildActiveTemplates;
      Save;
      Result := True;

    except
      on E: Exception do
      begin
        AErrorMsg := 'Error parsing templates data: ' + E.Message;
      end;
    end;
  finally
    LImportedTemplates.Free;
    LParsedVal.Free;
  end;
end;

end.
