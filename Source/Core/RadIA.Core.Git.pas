unit RadIA.Core.Git;

interface

type
  TRadIAGitResult = record
  private
    FSuccess: Boolean;
    FContentJson: string;
    FErrorCode: string;
    FErrorMessage: string;
  public
    class function Succeeded(
      const AContentJson: string
    ): TRadIAGitResult; static;
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAGitResult; static;
    property Success: Boolean read FSuccess;
    property ContentJson: string read FContentJson;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
  end;

  IRadIAGitFacade = interface
    ['{90680ACD-0CA0-4783-828A-3535A1B3CD36}']
    function GetStatus: TRadIAGitResult;
    function GetDiff(
      const APaths: TArray<string>
    ): TRadIAGitResult;
    function PreviewCommit(
      const APaths: TArray<string>;
      const AMessage: string
    ): TRadIAGitResult;
    function Commit(
      const APreviewId: string
    ): TRadIAGitResult;
  end;

implementation

class function TRadIAGitResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAGitResult;
begin
  Result.FSuccess := False;
  Result.FContentJson := '';
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIAGitResult.Succeeded(
  const AContentJson: string
): TRadIAGitResult;
begin
  Result.FSuccess := True;
  Result.FContentJson := AContentJson;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
end;

end.
