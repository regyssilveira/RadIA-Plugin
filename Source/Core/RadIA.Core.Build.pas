unit RadIA.Core.Build;

interface

uses
  RadIA.Core.Workspace;

type
  TRadIABuildMode = (
    bmMake,
    bmBuild,
    bmCheck,
    bmClean
  );

  TRadIABuildStatus = (
    bsIdle,
    bsRunning,
    bsSucceeded,
    bsFailed,
    bsCancelled,
    bsTimedOut,
    bsUnsupported
  );

  TRadIABuildRequest = record
  private
    FMode: TRadIABuildMode;
    FTimeoutMs: Cardinal;
    FClearMessages: Boolean;
  public
    constructor Create(
      const AMode: TRadIABuildMode;
      const ATimeoutMs: Cardinal;
      const AClearMessages: Boolean
    );
    property Mode: TRadIABuildMode read FMode;
    property TimeoutMs: Cardinal read FTimeoutMs;
    property ClearMessages: Boolean read FClearMessages;
  end;

  TRadIABuildResult = record
  private
    FSuccess: Boolean;
    FStatus: TRadIABuildStatus;
    FProjectFile: string;
    FConfiguration: string;
    FPlatform: string;
    FDurationMs: Int64;
    FMessages: TArray<TRadIACompilerMessage>;
    FErrorCode: string;
    FErrorMessage: string;
  public
    class function Completed(
      const AStatus: TRadIABuildStatus;
      const AProject: TRadIAProjectSnapshot;
      const ADurationMs: Int64;
      const AMessages: TArray<TRadIACompilerMessage>
    ): TRadIABuildResult; static;
    class function Failed(
      const AStatus: TRadIABuildStatus;
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIABuildResult; static;
    property Success: Boolean read FSuccess;
    property Status: TRadIABuildStatus read FStatus;
    property ProjectFile: string read FProjectFile;
    property Configuration: string read FConfiguration;
    property Platform: string read FPlatform;
    property DurationMs: Int64 read FDurationMs;
    property Messages: TArray<TRadIACompilerMessage> read FMessages;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
  end;

  IRadIABuildFacade = interface
    ['{48CD4CE6-9437-4D9D-AF56-32A3F28B521B}']
    function Execute(
      const ARequest: TRadIABuildRequest
    ): TRadIABuildResult;
    function Cancel: Boolean;
    function GetStatus: TRadIABuildStatus;
  end;

implementation

{ TRadIABuildRequest }

constructor TRadIABuildRequest.Create(
  const AMode: TRadIABuildMode;
  const ATimeoutMs: Cardinal;
  const AClearMessages: Boolean
);
begin
  FMode := AMode;
  FTimeoutMs := ATimeoutMs;
  FClearMessages := AClearMessages;
end;

{ TRadIABuildResult }

class function TRadIABuildResult.Completed(
  const AStatus: TRadIABuildStatus;
  const AProject: TRadIAProjectSnapshot;
  const ADurationMs: Int64;
  const AMessages: TArray<TRadIACompilerMessage>
): TRadIABuildResult;
var
  LMessage: TRadIACompilerMessage;
  LMessageCount: Integer;
begin
  Result.FSuccess := AStatus = bsSucceeded;
  Result.FStatus := AStatus;
  Result.FProjectFile := AProject.FileName;
  Result.FConfiguration := AProject.Configuration;
  Result.FPlatform := AProject.Platform;
  Result.FDurationMs := ADurationMs;
  SetLength(Result.FMessages, Length(AMessages));
  LMessageCount := 0;
  for LMessage in AMessages do
  begin
    if Result.FSuccess and (LMessage.Severity = cmsError) then
      Continue;
    Result.FMessages[LMessageCount] := LMessage;
    Inc(LMessageCount);
  end;
  SetLength(Result.FMessages, LMessageCount);
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
end;

class function TRadIABuildResult.Failed(
  const AStatus: TRadIABuildStatus;
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIABuildResult;
begin
  Result.FSuccess := False;
  Result.FStatus := AStatus;
  Result.FProjectFile := '';
  Result.FConfiguration := '';
  Result.FPlatform := '';
  Result.FDurationMs := 0;
  SetLength(Result.FMessages, 0);
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

end.
