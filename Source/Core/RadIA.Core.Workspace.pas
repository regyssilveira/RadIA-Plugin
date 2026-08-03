unit RadIA.Core.Workspace;

interface

type
  TRadIACompilerMessageSeverity = (
    cmsInfo,
    cmsWarning,
    cmsError,
    cmsFatal
  );

  TRadIAIDEState = record
  private
    FVersionName: string;
    FPlatform: string;
    FShuttingDown: Boolean;
    FCapabilities: TArray<string>;
  public
    constructor Create(
      const AVersionName: string;
      const APlatform: string;
      const AShuttingDown: Boolean;
      const ACapabilities: TArray<string>
    );
    property VersionName: string read FVersionName;
    property Platform: string read FPlatform;
    property ShuttingDown: Boolean read FShuttingDown;
    property Capabilities: TArray<string> read FCapabilities;
  end;

  TRadIAProjectSnapshot = record
  private
    FName: string;
    FFileName: string;
    FRootPath: string;
    FConfiguration: string;
    FPlatform: string;
  public
    constructor Create(
      const AName: string;
      const AFileName: string;
      const ARootPath: string;
      const AConfiguration: string;
      const APlatform: string
    );
    property Name: string read FName;
    property FileName: string read FFileName;
    property RootPath: string read FRootPath;
    property Configuration: string read FConfiguration;
    property Platform: string read FPlatform;
  end;

  TRadIAEditorContent = record
  private
    FUnitName: string;
    FFileName: string;
    FContent: string;
    FRevision: string;
    FOriginalLength: Integer;
    FTruncated: Boolean;
  public
    constructor Create(
      const AUnitName: string;
      const AFileName: string;
      const AContent: string;
      const ARevision: string;
      const AOriginalLength: Integer;
      const ATruncated: Boolean
    );
    property UnitName: string read FUnitName;
    property FileName: string read FFileName;
    property Content: string read FContent;
    property Revision: string read FRevision;
    property OriginalLength: Integer read FOriginalLength;
    property Truncated: Boolean read FTruncated;
  end;

  TRadIAEditorSelection = record
  private
    FContent: string;
    FLine: Integer;
    FColumn: Integer;
  public
    constructor Create(
      const AContent: string;
      const ALine: Integer;
      const AColumn: Integer
    );
    property Content: string read FContent;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

  TRadIAEditorPosition = record
  private
    FLine: Integer;
    FColumn: Integer;
  public
    constructor Create(
      const ALine: Integer;
      const AColumn: Integer
    );
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

  TRadIACompilerMessage = record
  private
    FSeverity: TRadIACompilerMessageSeverity;
    FText: string;
    FFileName: string;
    FLine: Integer;
    FColumn: Integer;
  public
    constructor Create(
      const ASeverity: TRadIACompilerMessageSeverity;
      const AText: string;
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer
    );
    property Severity: TRadIACompilerMessageSeverity read FSeverity;
    property Text: string read FText;
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

  IRadIAWorkspaceFacade = interface
    ['{5C54C44F-78ED-43EE-84AF-53B66EF153E2}']
    function GetIDEState: TRadIAIDEState;
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
    function GetEditorContent(
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetCompilerMessages(
      const AMaxCount: Integer
    ): TArray<TRadIACompilerMessage>;
  end;

implementation

{ TRadIAIDEState }

constructor TRadIAIDEState.Create(
  const AVersionName: string;
  const APlatform: string;
  const AShuttingDown: Boolean;
  const ACapabilities: TArray<string>
);
begin
  FVersionName := AVersionName;
  FPlatform := APlatform;
  FShuttingDown := AShuttingDown;
  FCapabilities := Copy(ACapabilities);
end;

{ TRadIAProjectSnapshot }

constructor TRadIAProjectSnapshot.Create(
  const AName: string;
  const AFileName: string;
  const ARootPath: string;
  const AConfiguration: string;
  const APlatform: string
);
begin
  FName := AName;
  FFileName := AFileName;
  FRootPath := ARootPath;
  FConfiguration := AConfiguration;
  FPlatform := APlatform;
end;

{ TRadIAEditorContent }

constructor TRadIAEditorContent.Create(
  const AUnitName: string;
  const AFileName: string;
  const AContent: string;
  const ARevision: string;
  const AOriginalLength: Integer;
  const ATruncated: Boolean
);
begin
  FUnitName := AUnitName;
  FFileName := AFileName;
  FContent := AContent;
  FRevision := ARevision;
  FOriginalLength := AOriginalLength;
  FTruncated := ATruncated;
end;

{ TRadIAEditorSelection }

constructor TRadIAEditorSelection.Create(
  const AContent: string;
  const ALine: Integer;
  const AColumn: Integer
);
begin
  FContent := AContent;
  FLine := ALine;
  FColumn := AColumn;
end;

{ TRadIAEditorPosition }

constructor TRadIAEditorPosition.Create(
  const ALine: Integer;
  const AColumn: Integer
);
begin
  FLine := ALine;
  FColumn := AColumn;
end;

{ TRadIACompilerMessage }

constructor TRadIACompilerMessage.Create(
  const ASeverity: TRadIACompilerMessageSeverity;
  const AText: string;
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer
);
begin
  FSeverity := ASeverity;
  FText := AText;
  FFileName := AFileName;
  FLine := ALine;
  FColumn := AColumn;
end;

end.
