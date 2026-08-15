unit RadIA.Core.DelphiLintAdapter;

interface

uses
  System.SysUtils;

type
  TRadIADelphiLintRequest = record
  private
    FBaseDirectory: string;
    FFiles: TArray<string>;
    FProjectKey: string;
    FProjectPropertiesPath: string;
    FSonarToken: string;
    FSonarUrl: string;
  public
    constructor Create(
      const ABaseDirectory: string;
      const AFiles: TArray<string>;
      const ASonarUrl: string;
      const AProjectKey: string;
      const ASonarToken: string;
      const AProjectPropertiesPath: string
    );
    property BaseDirectory: string read FBaseDirectory;
    property Files: TArray<string> read FFiles;
    property ProjectKey: string read FProjectKey;
    property ProjectPropertiesPath: string read FProjectPropertiesPath;
    property SonarToken: string read FSonarToken;
    property SonarUrl: string read FSonarUrl;
  end;

  TRadIADelphiLintResult = record
  private
    FError: string;
    FResponseJson: string;
    FStatus: string;
  public
    constructor Create(
      const AStatus: string;
      const AResponseJson: string;
      const AError: string
    );
    function Succeeded: Boolean;
    property Error: string read FError;
    property ResponseJson: string read FResponseJson;
    property Status: string read FStatus;
  end;

  IRadIADelphiLintAdapter = interface
    ['{45A66061-5B8D-4BE8-A20C-A775503A13F4}']
    function Analyze(
      const ARequest: TRadIADelphiLintRequest;
      const ATimeoutMs: Cardinal
    ): TRadIADelphiLintResult;
  end;

  TRadIADelphiLintProtocol = class
  public
    class function BuildMessage(
      const ACategory: Byte;
      const AId: Integer;
      const AJson: string
    ): TBytes; static;
    class function DecodeHeader(
      const AHeader: TBytes;
      out ACategory: Byte;
      out AId: Integer;
      out APayloadLength: Integer
    ): Boolean; static;
  end;

function CreateRadIADelphiLintAdapter: IRadIADelphiLintAdapter;

implementation

uses
  System.IniFiles,
  System.IOUtils,
  System.JSON,
  IdGlobal,
  IdTCPClient,
  Winapi.Windows;

const
  CAnalyze = 30;
  CAnalyzeError = 36;
  CAnalyzeResult = 35;
  CHeaderSize = 9;
  CInitialize = 20;
  CInitializeError = 26;
  CInitialized = 25;
  CQuit = 15;
  CStartupTimeoutMs = 10000;
  CDefaultSonarDelphiVersion = '1.12.1';

type
  TRadIADelphiLintAdapter = class(TInterfacedObject, IRadIADelphiLintAdapter)
  private
    function BuildAnalyzeJson(const ARequest: TRadIADelphiLintRequest): string;
    function BuildInitializeJson(const ARequest: TRadIADelphiLintRequest): string;
    function DelphiLintDirectory: string;
    function FindJar: string;
    function ResolveJava: string;
    function SonarDelphiVersion: string;
    function StartServer(
      const AJava: string;
      const AJar: string;
      const APortFile: string;
      out AProcess: TProcessInformation;
      out AError: string
    ): Boolean;
    function WaitForPort(
      const APortFile: string;
      const AProcess: TProcessInformation;
      out APort: Integer
    ): Boolean;
    function Exchange(
      const AClient: TIdTCPClient;
      const ACategory: Byte;
      const AId: Integer;
      const AJson: string;
      out AResponseCategory: Byte;
      out AResponseJson: string
    ): Boolean;
    function AnalyzeConnected(
      const ARequest: TRadIADelphiLintRequest;
      const APort: Integer;
      const ATimeoutMs: Cardinal
    ): TRadIADelphiLintResult;
  public
    function Analyze(
      const ARequest: TRadIADelphiLintRequest;
      const ATimeoutMs: Cardinal
    ): TRadIADelphiLintResult;
  end;

function ReadBigEndianInteger(const ABytes: TBytes; const AOffset: Integer): Integer;
begin
  Result := (Integer(ABytes[AOffset]) shl 24) or
    (Integer(ABytes[AOffset + 1]) shl 16) or
    (Integer(ABytes[AOffset + 2]) shl 8) or
    Integer(ABytes[AOffset + 3]);
end;

procedure WriteBigEndianInteger(
  var ABytes: TBytes;
  const AOffset: Integer;
  const AValue: Integer
);
begin
  ABytes[AOffset] := Byte((AValue shr 24) and $FF);
  ABytes[AOffset + 1] := Byte((AValue shr 16) and $FF);
  ABytes[AOffset + 2] := Byte((AValue shr 8) and $FF);
  ABytes[AOffset + 3] := Byte(AValue and $FF);
end;

constructor TRadIADelphiLintRequest.Create(
  const ABaseDirectory: string;
  const AFiles: TArray<string>;
  const ASonarUrl: string;
  const AProjectKey: string;
  const ASonarToken: string;
  const AProjectPropertiesPath: string
);
begin
  FBaseDirectory := ABaseDirectory;
  FFiles := Copy(AFiles);
  FSonarUrl := ASonarUrl;
  FProjectKey := AProjectKey;
  FSonarToken := ASonarToken;
  FProjectPropertiesPath := AProjectPropertiesPath;
end;

constructor TRadIADelphiLintResult.Create(
  const AStatus: string;
  const AResponseJson: string;
  const AError: string
);
begin
  FStatus := AStatus;
  FResponseJson := AResponseJson;
  FError := AError;
end;

function TRadIADelphiLintResult.Succeeded: Boolean;
begin
  Result := SameText(FStatus, 'passed');
end;

class function TRadIADelphiLintProtocol.BuildMessage(
  const ACategory: Byte;
  const AId: Integer;
  const AJson: string
): TBytes;
var
  LPayload: TBytes;
begin
  LPayload := TEncoding.UTF8.GetBytes(AJson);
  SetLength(Result, CHeaderSize + Length(LPayload));
  Result[0] := ACategory;
  WriteBigEndianInteger(Result, 1, AId);
  WriteBigEndianInteger(Result, 5, Length(LPayload));
  if Length(LPayload) > 0 then
    Move(LPayload[0], Result[CHeaderSize], Length(LPayload));
end;

class function TRadIADelphiLintProtocol.DecodeHeader(
  const AHeader: TBytes;
  out ACategory: Byte;
  out AId: Integer;
  out APayloadLength: Integer
): Boolean;
begin
  Result := Length(AHeader) = CHeaderSize;
  if not Result then
    Exit;
  ACategory := AHeader[0];
  AId := ReadBigEndianInteger(AHeader, 1);
  APayloadLength := ReadBigEndianInteger(AHeader, 5);
  Result := (APayloadLength >= 0) and (APayloadLength <= 16 * 1024 * 1024);
end;

function TRadIADelphiLintAdapter.DelphiLintDirectory: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable('APPDATA'), 'DelphiLint');
end;

function TRadIADelphiLintAdapter.FindJar: string;
var
  LFiles: TArray<string>;
  LIni: TIniFile;
begin
  Result := '';
  LIni := TIniFile.Create(TPath.Combine(DelphiLintDirectory, 'delphilint.ini'));
  try
    Result := LIni.ReadString('Resources', 'ServerJarOverride', '');
  finally
    LIni.Free;
  end;
  if TFile.Exists(Result) then
    Exit;
  Result := '';
  if not TDirectory.Exists(DelphiLintDirectory) then
    Exit;
  LFiles := TDirectory.GetFiles(
    DelphiLintDirectory,
    'delphilint-server-*.jar',
    TSearchOption.soTopDirectoryOnly
  );
  if Length(LFiles) > 0 then
    Result := LFiles[High(LFiles)];
end;

function SearchExecutable(const AName: string): string;
var
  LBuffer: array[0..MAX_PATH] of Char;
  LFilePart: PChar;
  LLength: DWORD;
begin
  Result := '';
  LFilePart := nil;
  LLength := SearchPath(
    nil,
    PChar(AName),
    nil,
    Length(LBuffer),
    LBuffer,
    LFilePart
  );
  if (LLength > 0) and (LLength < DWORD(Length(LBuffer))) then
    SetString(Result, LBuffer, LLength);
end;

function TRadIADelphiLintAdapter.ResolveJava: string;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(TPath.Combine(DelphiLintDirectory, 'delphilint.ini'));
  try
    Result := LIni.ReadString('Resources', 'JavaExeOverride', '');
  finally
    LIni.Free;
  end;
  if TFile.Exists(Result) then
    Exit;
  Result := TPath.Combine(GetEnvironmentVariable('JAVA_HOME'), 'bin\java.exe');
  if TFile.Exists(Result) then
    Exit;
  Result := SearchExecutable('java.exe');
end;

function TRadIADelphiLintAdapter.SonarDelphiVersion: string;
var
  LIni: TIniFile;
begin
  LIni := TIniFile.Create(TPath.Combine(DelphiLintDirectory, 'delphilint.ini'));
  try
    Result := LIni.ReadString(
      'Server',
      'SonarDelphiVersionOverride',
      CDefaultSonarDelphiVersion
    );
  finally
    LIni.Free;
  end;
end;

function TRadIADelphiLintAdapter.BuildInitializeJson(
  const ARequest: TRadIADelphiLintRequest
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('bdsPath', ExtractFileDir(ExtractFileDir(ParamStr(0))));
    LJson.AddPair('compilerVersion', Format('%.1f', [CompilerVersion],
      TFormatSettings.Invariant));
    LJson.AddPair('sonarHostUrl', ARequest.SonarUrl);
    LJson.AddPair('apiToken', ARequest.SonarToken);
    LJson.AddPair('sonarDelphiVersion', SonarDelphiVersion);
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIADelphiLintAdapter.BuildAnalyzeJson(
  const ARequest: TRadIADelphiLintRequest
): string;
var
  LFile: string;
  LFiles: TJSONArray;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LFiles := TJSONArray.Create;
    for LFile in ARequest.Files do
      LFiles.Add(LFile);
    LJson.AddPair('inputFiles', LFiles);
    LJson.AddPair('baseDir', ARequest.BaseDirectory);
    LJson.AddPair('projectPropertiesPath', ARequest.ProjectPropertiesPath);
    LJson.AddPair('sonarHostUrl', ARequest.SonarUrl);
    LJson.AddPair('projectKey', ARequest.ProjectKey);
    LJson.AddPair('apiToken', ARequest.SonarToken);
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIADelphiLintAdapter.StartServer(
  const AJava: string;
  const AJar: string;
  const APortFile: string;
  out AProcess: TProcessInformation;
  out AError: string
): Boolean;
var
  LCommandLine: string;
  LStartup: TStartupInfo;
begin
  ZeroMemory(@AProcess, SizeOf(AProcess));
  ZeroMemory(@LStartup, SizeOf(LStartup));
  LStartup.cb := SizeOf(LStartup);
  LStartup.dwFlags := STARTF_USESHOWWINDOW;
  LStartup.wShowWindow := SW_HIDE;
  LCommandLine := Format('"%s" -jar "%s" "%s"', [AJava, AJar, APortFile]);
  Result := CreateProcess(
    nil,
    PChar(LCommandLine),
    nil,
    nil,
    False,
    CREATE_NO_WINDOW,
    nil,
    PChar(ExtractFileDir(AJar)),
    LStartup,
    AProcess
  );
  if not Result then
    AError := SysErrorMessage(GetLastError);
end;

function TRadIADelphiLintAdapter.WaitForPort(
  const APortFile: string;
  const AProcess: TProcessInformation;
  out APort: Integer
): Boolean;
var
  LStarted: UInt64;
  LText: string;
begin
  APort := 0;
  LStarted := GetTickCount64;
  repeat
    if WaitForSingleObject(AProcess.hProcess, 0) = WAIT_OBJECT_0 then
      Exit(False);
    LText := TFile.ReadAllText(APortFile, TEncoding.UTF8).Trim;
    if TryStrToInt(LText, APort) and (APort > 0) and (APort <= 65535) then
      Exit(True);
    Sleep(50);
  until GetTickCount64 - LStarted >= CStartupTimeoutMs;
  Result := False;
end;

function TRadIADelphiLintAdapter.Exchange(
  const AClient: TIdTCPClient;
  const ACategory: Byte;
  const AId: Integer;
  const AJson: string;
  out AResponseCategory: Byte;
  out AResponseJson: string
): Boolean;
var
  LHeader: TIdBytes;
  LId: Integer;
  LLength: Integer;
  LMessage: TBytes;
  LPayload: TIdBytes;
begin
  LMessage := TRadIADelphiLintProtocol.BuildMessage(ACategory, AId, AJson);
  AClient.IOHandler.Write(TIdBytes(LMessage));
  AClient.IOHandler.ReadBytes(LHeader, CHeaderSize, False);
  Result := TRadIADelphiLintProtocol.DecodeHeader(
    TBytes(LHeader),
    AResponseCategory,
    LId,
    LLength
  ) and (LId = AId);
  if not Result then
    Exit;
  AClient.IOHandler.ReadBytes(LPayload, LLength, False);
  AResponseJson := TEncoding.UTF8.GetString(TBytes(LPayload));
end;

function TRadIADelphiLintAdapter.AnalyzeConnected(
  const ARequest: TRadIADelphiLintRequest;
  const APort: Integer;
  const ATimeoutMs: Cardinal
): TRadIADelphiLintResult;
var
  LCategory: Byte;
  LClient: TIdTCPClient;
  LError: string;
  LResponse: string;
begin
  LClient := TIdTCPClient.Create(nil);
  try
    LClient.Host := '127.0.0.1';
    LClient.Port := APort;
    LClient.ConnectTimeout := Integer(ATimeoutMs);
    LClient.ReadTimeout := Integer(ATimeoutMs);
    LClient.Connect;
    if not Exchange(LClient, CInitialize, 1, BuildInitializeJson(ARequest),
      LCategory, LResponse) or (LCategory <> CInitialized) then
    begin
      if LCategory = CInitializeError then
        LError := LResponse
      else
        LError := 'Unexpected DelphiLint initialization response.';
      Exit(TRadIADelphiLintResult.Create('initialize-error', '', LError));
    end;
    if not Exchange(LClient, CAnalyze, 2, BuildAnalyzeJson(ARequest),
      LCategory, LResponse) or (LCategory <> CAnalyzeResult) then
    begin
      if LCategory = CAnalyzeError then
        LError := LResponse
      else
        LError := 'Unexpected DelphiLint analysis response.';
      Exit(TRadIADelphiLintResult.Create('analysis-error', '', LError));
    end;
    LClient.IOHandler.Write(TIdBytes(
      TRadIADelphiLintProtocol.BuildMessage(CQuit, 3, 'null')
    ));
    Result := TRadIADelphiLintResult.Create('passed', LResponse, '');
  finally
    LClient.Free;
  end;
end;

function TRadIADelphiLintAdapter.Analyze(
  const ARequest: TRadIADelphiLintRequest;
  const ATimeoutMs: Cardinal
): TRadIADelphiLintResult;
var
  LError: string;
  LJar: string;
  LJava: string;
  LPort: Integer;
  LPortFile: string;
  LProcess: TProcessInformation;
begin
  LJar := FindJar;
  if LJar.IsEmpty then
    Exit(TRadIADelphiLintResult.Create('jar-missing', '',
      'DelphiLint server jar was not found.'));
  LJava := ResolveJava;
  if LJava.IsEmpty then
    Exit(TRadIADelphiLintResult.Create('java-missing', '',
      'Java was not found in DelphiLint settings, JAVA_HOME, or PATH.'));
  LPortFile := TPath.GetTempFileName;
  ZeroMemory(@LProcess, SizeOf(LProcess));
    try
      try
        if not StartServer(LJava, LJar, LPortFile, LProcess, LError) then
          Exit(TRadIADelphiLintResult.Create('startup-error', '', LError));
        if not WaitForPort(LPortFile, LProcess, LPort) then
          Exit(TRadIADelphiLintResult.Create('startup-timeout', '',
            'DelphiLint server did not publish its local port in time.'));
        Result := AnalyzeConnected(ARequest, LPort, ATimeoutMs);
      except
        on E: Exception do
          Result := TRadIADelphiLintResult.Create(
            'protocol-error',
            '',
            E.Message
          );
      end;
  finally
    if LProcess.hProcess <> 0 then
    begin
      if WaitForSingleObject(LProcess.hProcess, 2000) = WAIT_TIMEOUT then
        TerminateProcess(LProcess.hProcess, 1);
      CloseHandle(LProcess.hThread);
      CloseHandle(LProcess.hProcess);
    end;
    TFile.Delete(LPortFile);
  end;
end;

function CreateRadIADelphiLintAdapter: IRadIADelphiLintAdapter;
begin
  Result := TRadIADelphiLintAdapter.Create;
end;

end.
