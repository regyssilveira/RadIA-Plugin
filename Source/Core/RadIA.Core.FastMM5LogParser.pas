unit RadIA.Core.FastMM5LogParser;

interface

uses
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAMemoryLogParseResult = record
  private
    FContentJson: string;
    FEventCount: Integer;
    FTotalBytes: Int64;
    FTruncated: Boolean;
  public
    constructor Create(
      const AContentJson: string;
      const AEventCount: Integer;
      const ATotalBytes: Int64;
      const ATruncated: Boolean
    );
    property ContentJson: string read FContentJson;
    property EventCount: Integer read FEventCount;
    property TotalBytes: Int64 read FTotalBytes;
    property Truncated: Boolean read FTruncated;
  end;

  TRadIAFastMM5LogParser = class
  private
    function BuildEvent(
      const ABlock: string;
      out ASize: Int64
    ): TObject;
    function BuildFrame(const ALine: string): TObject;
    function EventKind(const ABlock: string): string;
    function ExtractBracketValues(
      const ALine: string
    ): TArray<string>;
    function ExtractInt64(
      const ABlock: string;
      const APrefix: string
    ): Int64;
    function ExtractText(
      const ABlock: string;
      const APrefix: string
    ): string;
    function IsEventBlock(const ABlock: string): Boolean;
  public
    function Parse(
      const AContent: string;
      const AMaxBytes: Int64;
      const AAlreadyTruncated: Boolean = False
    ): TRadIAMemoryLogParseResult;
  end;

  TRadIAMemoryLogCollector = class
  private
    FBuffer: TObject;
    FMaxBytes: Int64;
    FTruncated: Boolean;
  public
    constructor Create(const AMaxBytes: Int64);
    destructor Destroy; override;
    procedure AppendOutputDebugString(const AText: string);
    procedure LoadFile(const AFileName: string);
    function Complete: TRadIAMemoryLogParseResult;
  end;

procedure RegisterRadIAFastMM5LogTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.FastMM5;

type
  TRadIAParseMemoryLogTool = class(TInterfacedObject, IRadIATool)
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FWorkspace: IRadIAWorkspaceFacade;
    function ParseLogPath(const AArgumentsJson: string): string;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CLogInputSchema =
    '{"type":"object","required":["logPath"],"properties":{' +
    '"logPath":{"type":"string","minLength":1}},"additionalProperties":false}';
  CLogOutputSchema =
    '{"type":"object","required":["schemaVersion","truncated","summary",' +
    '"events"],"properties":{"schemaVersion":{"type":"integer"},' +
    '"truncated":{"type":"boolean"},"summary":{"type":"object"},' +
    '"events":{"type":"array"}}}';

constructor TRadIAMemoryLogParseResult.Create(
  const AContentJson: string;
  const AEventCount: Integer;
  const ATotalBytes: Int64;
  const ATruncated: Boolean
);
begin
  FContentJson := AContentJson;
  FEventCount := AEventCount;
  FTotalBytes := ATotalBytes;
  FTruncated := ATruncated;
end;

function TRadIAFastMM5LogParser.ExtractText(
  const ABlock: string;
  const APrefix: string
): string;
var
  LEndIndex: Integer;
  LStartIndex: Integer;
begin
  Result := '';
  LStartIndex := Pos(APrefix, ABlock);
  if LStartIndex = 0 then
    Exit;
  Inc(LStartIndex, Length(APrefix));
  LEndIndex := LStartIndex;
  while (LEndIndex <= Length(ABlock)) and
    not CharInSet(ABlock[LEndIndex], [#13, #10]) do
    Inc(LEndIndex);
  Result := Trim(Copy(ABlock, LStartIndex, LEndIndex - LStartIndex));
end;

function TRadIAFastMM5LogParser.ExtractInt64(
  const ABlock: string;
  const APrefix: string
): Int64;
var
  LIndex: Integer;
  LText: string;
begin
  LText := ExtractText(ABlock, APrefix);
  LIndex := 1;
  while (LIndex <= Length(LText)) and
    CharInSet(LText[LIndex], ['0'..'9']) do
    Inc(LIndex);
  Result := StrToInt64Def(Copy(LText, 1, LIndex - 1), 0);
end;

function TRadIAFastMM5LogParser.EventKind(
  const ABlock: string
): string;
begin
  if ContainsText(ABlock, 'A memory block has been leaked.') then
    Exit('leak');
  if ContainsText(ABlock, 'A virtual method was called on a freed object.') then
  begin
    if SameText(ExtractText(ABlock, 'Virtual method:'), 'BeforeDestruction') then
      Exit('doubleFree');
    Exit('useAfterFree');
  end;
  if ContainsText(ABlock, 'header has been corrupted') then
    Exit('headerCorruption');
  if ContainsText(ABlock, 'footer has been corrupted') then
    Exit('footerCorruption');
  Result := '';
end;

function TRadIAFastMM5LogParser.IsEventBlock(
  const ABlock: string
): Boolean;
begin
  Result := not EventKind(ABlock).IsEmpty;
end;

function TRadIAFastMM5LogParser.ExtractBracketValues(
  const ALine: string
): TArray<string>;
var
  LCloseIndex: Integer;
  LOpenIndex: Integer;
  LValues: TList<string>;
begin
  LValues := TList<string>.Create;
  try
    LOpenIndex := Pos('[', ALine);
    while LOpenIndex > 0 do
    begin
      LCloseIndex := PosEx(']', ALine, LOpenIndex + 1);
      if LCloseIndex = 0 then
        Break;
      LValues.Add(
        Copy(ALine, LOpenIndex + 1, LCloseIndex - LOpenIndex - 1)
      );
      LOpenIndex := PosEx('[', ALine, LCloseIndex + 1);
    end;
    Result := LValues.ToArray;
  finally
    LValues.Free;
  end;
end;

function TRadIAFastMM5LogParser.BuildFrame(
  const ALine: string
): TObject;
var
  LAddress: string;
  LFrame: TJSONObject;
  LLineNumber: Integer;
  LValues: TArray<string>;
begin
  LValues := ExtractBracketValues(ALine);
  if Length(LValues) = 0 then
    Exit(nil);
  LAddress := Trim(Copy(ALine, 1, Pos('[', ALine) - 1));
  LFrame := TJSONObject.Create;
  LFrame.AddPair('addressId', LowerCase(LAddress.PadLeft(16, '0')));
  LFrame.AddPair('fileName', LValues[0]);
  if Length(LValues) > 1 then
    LFrame.AddPair('moduleName', LValues[1])
  else
    LFrame.AddPair('moduleName', '');
  if Length(LValues) > 2 then
    LFrame.AddPair('routineName', LValues[2])
  else
    LFrame.AddPair('routineName', '');
  LLineNumber := 0;
  if Length(LValues) > 3 then
    LLineNumber := StrToIntDef(LValues[3], 0);
  LFrame.AddPair('lineNumber', LLineNumber);
  Result := LFrame;
end;

function TRadIAFastMM5LogParser.BuildEvent(
  const ABlock: string;
  out ASize: Int64
): TObject;
var
  LClassName: string;
  LEvent: TJSONObject;
  LFingerprintFrame: string;
  LFingerprintMaterial: string;
  LFrame: TObject;
  LFrames: TJSONArray;
  LKind: string;
  LLine: string;
  LLines: TStringList;
begin
  LKind := EventKind(ABlock);
  ASize := ExtractInt64(ABlock, 'The size is:');
  if ASize = 0 then
    ASize := ExtractInt64(ABlock, 'The block size is');
  LClassName := ExtractText(
    ABlock,
    'The block is currently used for an object of class:'
  );
  if LClassName.IsEmpty then
    LClassName := ExtractText(ABlock, 'Freed object class:');
  LEvent := TJSONObject.Create;
  LFrames := TJSONArray.Create;
  LEvent.AddPair('kind', LKind);
  LEvent.AddPair('className', LClassName);
  LEvent.AddPair('blockSize', TJSONNumber.Create(ASize));
  LEvent.AddPair('allocationCount', 1);
  LEvent.AddPair('totalBytes', TJSONNumber.Create(ASize));
  LEvent.AddPair(
    'allocationNumber',
    TJSONNumber.Create(ExtractInt64(ABlock, 'The allocation number is:'))
  );
  LEvent.AddPair('frames', LFrames);
  LLines := TStringList.Create;
  try
    LFingerprintFrame := '';
    LLines.Text := ABlock;
    for LLine in LLines do
    begin
      LFrame := BuildFrame(LLine);
      if Assigned(LFrame) then
      begin
        if LFrames.Count < 100 then
          LFrames.AddElement(LFrame as TJSONValue)
        else
          LFrame.Free;
        if LFingerprintFrame.IsEmpty and
          ContainsText(LLine, '.pas]') and
          not ContainsText(LLine, '[FastMM5.pas]') then
          LFingerprintFrame := Copy(LLine, Pos('[', LLine), MaxInt);
      end;
    end;
  finally
    LLines.Free;
  end;
  LFingerprintMaterial :=
    LKind + '|' + LClassName + '|' + LFingerprintFrame;
  LEvent.AddPair(
    'fingerprint',
    LowerCase(THashSHA2.GetHashString(LFingerprintMaterial))
  );
  Result := LEvent;
end;

function TRadIAFastMM5LogParser.Parse(
  const AContent: string;
  const AMaxBytes: Int64;
  const AAlreadyTruncated: Boolean
): TRadIAMemoryLogParseResult;
var
  LBlock: TStringBuilder;
  LBytes: TBytes;
  LContent: string;
  LEvent: TObject;
  LEventCount: Integer;
  LEvents: TJSONArray;
  LLine: string;
  LLines: TStringList;
  LRoot: TJSONObject;
  LResourceTruncated: Boolean;
  LSize: Int64;
  LSummary: TJSONObject;
  LTotalBytes: Int64;
  LTruncated: Boolean;

  procedure CompleteBlock;
  var
    LBlockText: string;
  begin
    LBlockText := LBlock.ToString;
    if IsEventBlock(LBlockText) then
    begin
      if LEventCount >= 1000 then
      begin
        LResourceTruncated := True;
        LBlock.Clear;
        Exit;
      end;
      LEvent := BuildEvent(LBlockText, LSize);
      LEvents.AddElement(LEvent as TJSONValue);
      Inc(LEventCount);
      Inc(LTotalBytes, LSize);
    end;
    LBlock.Clear;
  end;

begin
  if (AMaxBytes < 1024) or (AMaxBytes > 1073741824) then
    raise EArgumentOutOfRangeException.Create('AMaxBytes');
  LBytes := TEncoding.UTF8.GetBytes(AContent);
  LTruncated := AAlreadyTruncated or (Length(LBytes) > AMaxBytes);
  if LTruncated then
    SetLength(LBytes, AMaxBytes);
  LContent := TEncoding.UTF8.GetString(LBytes);
  LRoot := TJSONObject.Create;
  LEvents := TJSONArray.Create;
  LSummary := TJSONObject.Create;
  LLines := TStringList.Create;
  LBlock := TStringBuilder.Create;
  try
    LEventCount := 0;
    LResourceTruncated := False;
    LTotalBytes := 0;
    LLines.Text := LContent;
    for LLine in LLines do
    begin
      if StartsText('--------------------------------', LLine) then
        CompleteBlock
      else
        LBlock.AppendLine(LLine);
    end;
    CompleteBlock;
    LRoot.AddPair('schemaVersion', 1);
    LTruncated := LTruncated or LResourceTruncated;
    LRoot.AddPair('truncated', TJSONBool.Create(LTruncated));
    LSummary.AddPair('eventCount', LEventCount);
    LSummary.AddPair('totalUnexpectedBytes', TJSONNumber.Create(LTotalBytes));
    LRoot.AddPair('summary', LSummary);
    LRoot.AddPair('events', LEvents);
    Result := TRadIAMemoryLogParseResult.Create(
      LRoot.ToJSON,
      LEventCount,
      LTotalBytes,
      LTruncated
    );
  finally
    LBlock.Free;
    LLines.Free;
    LRoot.Free;
  end;
end;

constructor TRadIAMemoryLogCollector.Create(const AMaxBytes: Int64);
begin
  inherited Create;
  if (AMaxBytes < 1024) or (AMaxBytes > 1073741824) then
    raise EArgumentOutOfRangeException.Create('AMaxBytes');
  FMaxBytes := AMaxBytes;
  FBuffer := TStringBuilder.Create;
end;

destructor TRadIAMemoryLogCollector.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TRadIAMemoryLogCollector.AppendOutputDebugString(
  const AText: string
);
var
  LBuffer: TStringBuilder;
  LBytes: TBytes;
  LRemaining: Int64;
begin
  if AText.IsEmpty then
    Exit;
  LBuffer := TStringBuilder(FBuffer);
  TMonitor.Enter(LBuffer);
  try
    LRemaining := FMaxBytes -
      TEncoding.UTF8.GetByteCount(LBuffer.ToString);
    if LRemaining <= 0 then
    begin
      FTruncated := True;
      Exit;
    end;
    LBytes := TEncoding.UTF8.GetBytes(AText + sLineBreak);
    if Length(LBytes) > LRemaining then
    begin
      SetLength(LBytes, Integer(LRemaining));
      FTruncated := True;
    end;
    LBuffer.Append(TEncoding.UTF8.GetString(LBytes));
  finally
    TMonitor.Exit(LBuffer);
  end;
end;

procedure TRadIAMemoryLogCollector.LoadFile(const AFileName: string);
var
  LBytes: TBytes;
  LFile: TFileStream;
  LReadCount: Integer;
  LRequested: Integer;
begin
  LFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    LRequested := Integer(FMaxBytes) + 1;
    SetLength(LBytes, LRequested);
    LReadCount := LFile.Read(LBytes[0], LRequested);
    SetLength(LBytes, LReadCount);
  finally
    LFile.Free;
  end;
  if Length(LBytes) > FMaxBytes then
  begin
    SetLength(LBytes, Integer(FMaxBytes));
    FTruncated := True;
  end;
  AppendOutputDebugString(TEncoding.UTF8.GetString(LBytes));
end;

function TRadIAMemoryLogCollector.Complete:
  TRadIAMemoryLogParseResult;
var
  LContent: string;
  LParser: TRadIAFastMM5LogParser;
begin
  TMonitor.Enter(FBuffer);
  try
    LContent := TStringBuilder(FBuffer).ToString;
  finally
    TMonitor.Exit(FBuffer);
  end;
  LParser := TRadIAFastMM5LogParser.Create;
  try
    Result := LParser.Parse(LContent, FMaxBytes, FTruncated);
  finally
    LParser.Free;
  end;
end;

constructor TRadIAParseMemoryLogTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
end;

function TRadIAParseMemoryLogTool.ParseLogPath(
  const AArgumentsJson: string
): string;
var
  LRoot: TJSONObject;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    Result := LRoot.GetValue<string>('logPath', '');
  finally
    LRoot.Free;
  end;
end;

function TRadIAParseMemoryLogTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCollector: TRadIAMemoryLogCollector;
  LFastMMSettings: TRadIAFastMM5Settings;
  LFastMMStore: TRadIAFastMM5SettingsStore;
  LLogPath: string;
  LProject: TRadIAProjectSnapshot;
  LResult: TRadIAMemoryLogParseResult;
  LValidation: TRadIAPathValidation;
begin
  LLogPath := ParseLogPath(ARequest.ArgumentsJson);
  if LLogPath.IsEmpty then
    Exit(
      TRadIAToolResult.Failed(
        'missing_log_path',
        'logPath is required.'
      )
    );
  LProject := FWorkspace.GetActiveProject;
  LValidation := FBoundary.ValidatePath(LProject.RootPath, LLogPath);
  if not LValidation.Allowed then
    Exit(
      TRadIAToolResult.Failed(
        LValidation.ErrorCode,
        LValidation.ErrorMessage
      )
    );
  if not TFile.Exists(LValidation.ResolvedPath) then
    Exit(TRadIAToolResult.Failed('log_not_found', 'Log file not found.'));
  LFastMMStore := TRadIAFastMM5SettingsStore.Create;
  try
    LFastMMSettings := LFastMMStore.Load;
  finally
    LFastMMStore.Free;
  end;
  LCollector := TRadIAMemoryLogCollector.Create(
    LFastMMSettings.Limits.MaxLogBytes
  );
  try
    LCollector.LoadFile(LValidation.ResolvedPath);
    LResult := LCollector.Complete;
  finally
    LCollector.Free;
  end;
  Result := TRadIAToolResult.Succeeded(
    LResult.ContentJson,
    LResult.Truncated
  );
end;

function TRadIAParseMemoryLogTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ParseMemoryDiagnosticLog',
    '1.0.0',
    'Parses a bounded FastMM5 log inside the active workspace into structured, fingerprinted memory events.',
    CLogInputSchema,
    CLogOutputSchema,
    trReadOnly
  );
end;

procedure RegisterRadIAFastMM5LogTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(
    TRadIAParseMemoryLogTool.Create(AWorkspace, ABoundary)
  );
end;

end.
