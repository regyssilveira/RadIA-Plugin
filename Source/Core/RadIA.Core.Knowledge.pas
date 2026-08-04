unit RadIA.Core.Knowledge;

interface

uses
  System.Generics.Collections;

type
  TRadIAKnowledgeDocument = record
  private
    FContent: string;
    FFileName: string;
    FRevision: string;
  public
    constructor Create(
      const AFileName: string;
      const ARevision: string;
      const AContent: string
    );
    property FileName: string read FFileName;
    property Revision: string read FRevision;
    property Content: string read FContent;
  end;

  TRadIAKnowledgeChunk = record
  private
    FContent: string;
    FEndLine: Integer;
    FFileName: string;
    FId: string;
    FRevision: string;
    FStartLine: Integer;
    FSymbol: string;
  public
    constructor Create(
      const AId: string;
      const AFileName: string;
      const ARevision: string;
      const ASymbol: string;
      const AStartLine: Integer;
      const AEndLine: Integer;
      const AContent: string
    );
    property Id: string read FId;
    property FileName: string read FFileName;
    property Revision: string read FRevision;
    property Symbol: string read FSymbol;
    property StartLine: Integer read FStartLine;
    property EndLine: Integer read FEndLine;
    property Content: string read FContent;
  end;

  TRadIAKnowledgeSearchHit = record
  private
    FChunk: TRadIAKnowledgeChunk;
    FScore: Integer;
  public
    constructor Create(
      const AChunk: TRadIAKnowledgeChunk;
      const AScore: Integer
    );
    property Chunk: TRadIAKnowledgeChunk read FChunk;
    property Score: Integer read FScore;
  end;

  TRadIAKnowledgeRefreshResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FIndexedFiles: Integer;
    FProjectId: string;
    FRemovedFiles: Integer;
    FSkippedFiles: Integer;
    FSuccess: Boolean;
    FUpdatedFiles: Integer;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAKnowledgeRefreshResult; static;
    class function Succeeded(
      const AProjectId: string;
      const AIndexedFiles: Integer;
      const AUpdatedFiles: Integer;
      const ASkippedFiles: Integer;
      const ARemovedFiles: Integer
    ): TRadIAKnowledgeRefreshResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property ProjectId: string read FProjectId;
    property IndexedFiles: Integer read FIndexedFiles;
    property UpdatedFiles: Integer read FUpdatedFiles;
    property SkippedFiles: Integer read FSkippedFiles;
    property RemovedFiles: Integer read FRemovedFiles;
  end;

  TRadIAKnowledgeIndexSnapshot = record
  private
    FChunks: TArray<TRadIAKnowledgeChunk>;
    FProjectId: string;
  public
    constructor Create(
      const AProjectId: string;
      const AChunks: TArray<TRadIAKnowledgeChunk>
    );
    property ProjectId: string read FProjectId;
    property Chunks: TArray<TRadIAKnowledgeChunk> read FChunks;
  end;

  TRadIAKnowledgeStatus = record
  private
    FChunkCount: Integer;
    FFileCount: Integer;
    FLoaded: Boolean;
    FProjectId: string;
  public
    constructor Create(
      const AProjectId: string;
      const ALoaded: Boolean;
      const AFileCount: Integer;
      const AChunkCount: Integer
    );
    property ProjectId: string read FProjectId;
    property Loaded: Boolean read FLoaded;
    property FileCount: Integer read FFileCount;
    property ChunkCount: Integer read FChunkCount;
  end;

  TRadIAIndexedKnowledgeDocument = record
  private
    FChunks: TArray<TRadIAKnowledgeChunk>;
    FFileName: string;
    FRevision: string;
  public
    constructor Create(
      const AFileName: string;
      const ARevision: string;
      const AChunks: TArray<TRadIAKnowledgeChunk>
    );
    property FileName: string read FFileName;
    property Revision: string read FRevision;
    property Chunks: TArray<TRadIAKnowledgeChunk> read FChunks;
  end;

  IRadIAKnowledgeSource = interface
    ['{D2485D77-A112-49F8-B455-4732C7AD85FB}']
    function GetProjectId: string;
    function ListSourceFiles: TArray<string>;
    function ReadSourceFile(
      const AFileName: string;
      out ADocument: TRadIAKnowledgeDocument
    ): Boolean;
  end;

  IRadIAKnowledgeStore = interface
    ['{316150BB-C721-4B24-A40D-D4EB8DA77C3D}']
    function Load(
      const AProjectId: string;
      out ASnapshot: TRadIAKnowledgeIndexSnapshot
    ): Boolean;
    procedure Save(
      const ASnapshot: TRadIAKnowledgeIndexSnapshot
    );
    procedure Delete(const AProjectId: string);
    procedure Clear;
  end;

  IRadIAKnowledgeService = interface
    ['{51473B23-E6D4-4DF6-A79F-7D003415D83B}']
    function GetCurrentProjectId: string;
    function GetStatus(
      const AProjectId: string
    ): TRadIAKnowledgeStatus;
    function GetDocument(
      const AProjectId: string;
      const AFileName: string;
      out ADocument: TRadIAIndexedKnowledgeDocument
    ): Boolean;
    function RefreshProject: TRadIAKnowledgeRefreshResult;
    function Search(
      const AProjectId: string;
      const AQuery: string;
      const AMaxResults: Integer
    ): TArray<TRadIAKnowledgeSearchHit>;
    procedure ClearProject(const AProjectId: string);
    procedure Clear;
  end;

  TRadIALocalKnowledgeService = class(
    TInterfacedObject,
    IRadIAKnowledgeService
  )
  private type
    TRadIAKnowledgeFileRefresh = (
      kfrSkipped,
      kfrUpdated
    );

    TRadIAKnowledgeChunkEntry = class
    private
      FChunk: TRadIAKnowledgeChunk;
      FTokens: TDictionary<string, Integer>;
    public
      constructor Create(const AChunk: TRadIAKnowledgeChunk);
      destructor Destroy; override;
      function Score(const AQueryTokens: TArray<string>): Integer;
      property Chunk: TRadIAKnowledgeChunk read FChunk;
    end;

    TRadIAKnowledgeFileEntry = class
    private
      FChunks: TObjectList<TRadIAKnowledgeChunkEntry>;
      FRevision: string;
    public
      constructor Create(
        const ARevision: string;
        const AChunks: TArray<TRadIAKnowledgeChunk>
      );
      destructor Destroy; override;
      property Chunks: TObjectList<TRadIAKnowledgeChunkEntry>
        read FChunks;
      property Revision: string read FRevision;
    end;

    TRadIAKnowledgeProjectIndex = class
    private
      FFiles: TObjectDictionary<string, TRadIAKnowledgeFileEntry>;
    public
      constructor Create;
      destructor Destroy; override;
      property Files: TObjectDictionary<string, TRadIAKnowledgeFileEntry>
        read FFiles;
    end;
  private
    FProjects: TObjectDictionary<string, TRadIAKnowledgeProjectIndex>;
    FLoadedProjects: TDictionary<string, Boolean>;
    FSource: IRadIAKnowledgeSource;
    FStore: IRadIAKnowledgeStore;
    function BuildChunks(
      const ADocument: TRadIAKnowledgeDocument
    ): TArray<TRadIAKnowledgeChunk>;
    function GetOrCreateProject(
      const AProjectId: string
    ): TRadIAKnowledgeProjectIndex;
    function IsStructuralDeclaration(
      const ALine: string;
      out ASymbol: string
    ): Boolean;
    function NeedsDocumentUpdate(
      const AProjectId: string;
      const AFileName: string;
      const ARevision: string
    ): Boolean;
    function RefreshFile(
      const AProjectId: string;
      const AFileName: string
    ): TRadIAKnowledgeFileRefresh;
    procedure RemoveStaleFiles(
      const AProjectId: string;
      const AKnownFiles: TDictionary<string, Boolean>;
      out AIndexedFiles: Integer;
      out ARemovedFiles: Integer
    );
    procedure EnsureProjectLoaded(const AProjectId: string);
    function CreateSnapshot(
      const AProjectId: string
    ): TRadIAKnowledgeIndexSnapshot;
    procedure RestoreSnapshot(
      const ASnapshot: TRadIAKnowledgeIndexSnapshot
    );
    class function Tokenize(
      const AText: string
    ): TArray<string>; static;
  public
    constructor Create(
      const ASource: IRadIAKnowledgeSource;
      const AStore: IRadIAKnowledgeStore = nil
    );
    destructor Destroy; override;
    function GetCurrentProjectId: string;
    function GetStatus(
      const AProjectId: string
    ): TRadIAKnowledgeStatus;
    function GetDocument(
      const AProjectId: string;
      const AFileName: string;
      out ADocument: TRadIAIndexedKnowledgeDocument
    ): Boolean;
    function RefreshProject: TRadIAKnowledgeRefreshResult;
    function Search(
      const AProjectId: string;
      const AQuery: string;
      const AMaxResults: Integer
    ): TArray<TRadIAKnowledgeSearchHit>;
    procedure ClearProject(const AProjectId: string);
    procedure Clear;
  end;

implementation

uses
  System.Character,
  System.Classes,
  System.Generics.Defaults,
  System.Hash,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  System.SysUtils;

const
  CInvalidProject = 'invalid_project';
  CMaxChunkCharacters = 12000;
  CMaxDocumentCharacters = 2 * 1024 * 1024;
  CMaxProjectFiles = 5000;

{ TRadIAKnowledgeDocument }

constructor TRadIAKnowledgeDocument.Create(
  const AFileName: string;
  const ARevision: string;
  const AContent: string
);
begin
  FFileName := AFileName;
  FRevision := ARevision;
  FContent := AContent;
end;

{ TRadIAKnowledgeChunk }

constructor TRadIAKnowledgeChunk.Create(
  const AId: string;
  const AFileName: string;
  const ARevision: string;
  const ASymbol: string;
  const AStartLine: Integer;
  const AEndLine: Integer;
  const AContent: string
);
begin
  FId := AId;
  FFileName := AFileName;
  FRevision := ARevision;
  FSymbol := ASymbol;
  FStartLine := AStartLine;
  FEndLine := AEndLine;
  FContent := AContent;
end;

{ TRadIAKnowledgeSearchHit }

constructor TRadIAKnowledgeSearchHit.Create(
  const AChunk: TRadIAKnowledgeChunk;
  const AScore: Integer
);
begin
  FChunk := AChunk;
  FScore := AScore;
end;

{ TRadIAKnowledgeRefreshResult }

class function TRadIAKnowledgeRefreshResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAKnowledgeRefreshResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

{ TRadIAKnowledgeIndexSnapshot }

constructor TRadIAKnowledgeIndexSnapshot.Create(
  const AProjectId: string;
  const AChunks: TArray<TRadIAKnowledgeChunk>
);
begin
  FProjectId := AProjectId;
  FChunks := Copy(AChunks);
end;

{ TRadIAKnowledgeStatus }

constructor TRadIAKnowledgeStatus.Create(
  const AProjectId: string;
  const ALoaded: Boolean;
  const AFileCount: Integer;
  const AChunkCount: Integer
);
begin
  FProjectId := AProjectId;
  FLoaded := ALoaded;
  FFileCount := AFileCount;
  FChunkCount := AChunkCount;
end;

{ TRadIAIndexedKnowledgeDocument }

constructor TRadIAIndexedKnowledgeDocument.Create(
  const AFileName: string;
  const ARevision: string;
  const AChunks: TArray<TRadIAKnowledgeChunk>
);
begin
  FFileName := AFileName;
  FRevision := ARevision;
  FChunks := AChunks;
end;

class function TRadIAKnowledgeRefreshResult.Succeeded(
  const AProjectId: string;
  const AIndexedFiles: Integer;
  const AUpdatedFiles: Integer;
  const ASkippedFiles: Integer;
  const ARemovedFiles: Integer
): TRadIAKnowledgeRefreshResult;
begin
  Result.FSuccess := True;
  Result.FProjectId := AProjectId;
  Result.FIndexedFiles := AIndexedFiles;
  Result.FUpdatedFiles := AUpdatedFiles;
  Result.FSkippedFiles := ASkippedFiles;
  Result.FRemovedFiles := ARemovedFiles;
end;

{ TRadIALocalKnowledgeService.TRadIAKnowledgeChunkEntry }

constructor TRadIALocalKnowledgeService.TRadIAKnowledgeChunkEntry.Create(
  const AChunk: TRadIAKnowledgeChunk
);
var
  LCount: Integer;
  LToken: string;
begin
  inherited Create;
  FChunk := AChunk;
  FTokens := TDictionary<string, Integer>.Create;
  for LToken in Tokenize(AChunk.Content + ' ' + AChunk.Symbol) do
  begin
    if FTokens.TryGetValue(LToken, LCount) then
      FTokens[LToken] := LCount + 1
    else
      FTokens.Add(LToken, 1);
  end;
end;

destructor TRadIALocalKnowledgeService.TRadIAKnowledgeChunkEntry.Destroy;
begin
  FTokens.Free;
  inherited;
end;

function TRadIALocalKnowledgeService.TRadIAKnowledgeChunkEntry.Score(
  const AQueryTokens: TArray<string>
): Integer;
var
  LCount: Integer;
  LToken: string;
begin
  Result := 0;
  for LToken in AQueryTokens do
  begin
    if FTokens.TryGetValue(LToken, LCount) then
      Inc(Result, 10 + Min(LCount, 10));
    if ContainsText(FChunk.Symbol, LToken) then
      Inc(Result, 20);
  end;
end;

{ TRadIALocalKnowledgeService.TRadIAKnowledgeFileEntry }

constructor TRadIALocalKnowledgeService.TRadIAKnowledgeFileEntry.Create(
  const ARevision: string;
  const AChunks: TArray<TRadIAKnowledgeChunk>
);
var
  LChunk: TRadIAKnowledgeChunk;
begin
  inherited Create;
  FRevision := ARevision;
  FChunks := TObjectList<TRadIAKnowledgeChunkEntry>.Create(True);
  for LChunk in AChunks do
    FChunks.Add(TRadIAKnowledgeChunkEntry.Create(LChunk));
end;

destructor TRadIALocalKnowledgeService.TRadIAKnowledgeFileEntry.Destroy;
begin
  FChunks.Free;
  inherited;
end;

{ TRadIALocalKnowledgeService.TRadIAKnowledgeProjectIndex }

constructor TRadIALocalKnowledgeService.TRadIAKnowledgeProjectIndex.Create;
begin
  inherited;
  FFiles := TObjectDictionary<string, TRadIAKnowledgeFileEntry>.Create(
    [doOwnsValues]
  );
end;

destructor TRadIALocalKnowledgeService.TRadIAKnowledgeProjectIndex.Destroy;
begin
  FFiles.Free;
  inherited;
end;

{ TRadIALocalKnowledgeService }

function TRadIALocalKnowledgeService.BuildChunks(
  const ADocument: TRadIAKnowledgeDocument
): TArray<TRadIAKnowledgeChunk>;
var
  LChunks: TList<TRadIAKnowledgeChunk>;
  LContent: TStringBuilder;
  LEndLine: Integer;
  LIndex: Integer;
  LLines: TStringList;
  LStartLine: Integer;
  LSymbol: string;
  LNextSymbol: string;

  procedure FlushChunk;
  var
    LChunkContent: string;
    LChunkId: string;
  begin
    if LContent.Length = 0 then
      Exit;
    LChunkContent := LContent.ToString;
    LChunkId := THashSHA2.GetHashString(
      ADocument.FileName + ':' +
      LStartLine.ToString + ':' +
      ADocument.Revision
    );
    LChunks.Add(
      TRadIAKnowledgeChunk.Create(
        LChunkId,
        ADocument.FileName,
        ADocument.Revision,
        LSymbol,
        LStartLine,
        LEndLine,
        LChunkContent
      )
    );
    LContent.Clear;
  end;

begin
  LChunks := TList<TRadIAKnowledgeChunk>.Create;
  LContent := TStringBuilder.Create;
  LLines := TStringList.Create;
  try
    LLines.Text := ADocument.Content;
    LStartLine := 1;
    LEndLine := 0;
    LSymbol := TPath.GetFileName(ADocument.FileName);
    for LIndex := 0 to LLines.Count - 1 do
    begin
      if IsStructuralDeclaration(
        LLines[LIndex],
        LNextSymbol
      ) and (LContent.Length > 0) then
      begin
        FlushChunk;
        LStartLine := LIndex + 1;
        LSymbol := LNextSymbol;
      end;

      if LContent.Length > 0 then
        LContent.AppendLine;
      LContent.Append(LLines[LIndex]);
      LEndLine := LIndex + 1;
      if LContent.Length >= CMaxChunkCharacters then
      begin
        FlushChunk;
        LStartLine := LIndex + 2;
        LSymbol := TPath.GetFileName(ADocument.FileName);
      end;
    end;
    FlushChunk;
    Result := LChunks.ToArray;
  finally
    LLines.Free;
    LContent.Free;
    LChunks.Free;
  end;
end;

procedure TRadIALocalKnowledgeService.Clear;
begin
  TMonitor.Enter(FProjects);
  try
    FProjects.Clear;
    FLoadedProjects.Clear;
  finally
    TMonitor.Exit(FProjects);
  end;
  if Assigned(FStore) then
    FStore.Clear;
end;

procedure TRadIALocalKnowledgeService.ClearProject(
  const AProjectId: string
);
begin
  TMonitor.Enter(FProjects);
  try
    FProjects.Remove(AProjectId);
    FLoadedProjects.Remove(AProjectId);
  finally
    TMonitor.Exit(FProjects);
  end;
  if Assigned(FStore) then
    FStore.Delete(AProjectId);
end;

constructor TRadIALocalKnowledgeService.Create(
  const ASource: IRadIAKnowledgeSource;
  const AStore: IRadIAKnowledgeStore
);
begin
  inherited Create;
  if not Assigned(ASource) then
    raise EArgumentNilException.Create('ASource');
  FSource := ASource;
  FStore := AStore;
  FLoadedProjects := TDictionary<string, Boolean>.Create;
  FProjects :=
    TObjectDictionary<string, TRadIAKnowledgeProjectIndex>.Create(
      [doOwnsValues]
    );
end;

destructor TRadIALocalKnowledgeService.Destroy;
begin
  FProjects.Free;
  FLoadedProjects.Free;
  inherited;
end;

function TRadIALocalKnowledgeService.CreateSnapshot(
  const AProjectId: string
): TRadIAKnowledgeIndexSnapshot;
var
  LChunk: TRadIAKnowledgeChunkEntry;
  LChunks: TList<TRadIAKnowledgeChunk>;
  LFile: TRadIAKnowledgeFileEntry;
  LIndex: TRadIAKnowledgeProjectIndex;
begin
  LChunks := TList<TRadIAKnowledgeChunk>.Create;
  try
    TMonitor.Enter(FProjects);
    try
      if FProjects.TryGetValue(AProjectId, LIndex) then
      begin
        for LFile in LIndex.Files.Values do
        begin
          for LChunk in LFile.Chunks do
            LChunks.Add(LChunk.Chunk);
        end;
      end;
    finally
      TMonitor.Exit(FProjects);
    end;
    Result := TRadIAKnowledgeIndexSnapshot.Create(
      AProjectId,
      LChunks.ToArray
    );
  finally
    LChunks.Free;
  end;
end;

procedure TRadIALocalKnowledgeService.EnsureProjectLoaded(
  const AProjectId: string
);
var
  LAlreadyLoaded: Boolean;
  LSnapshot: TRadIAKnowledgeIndexSnapshot;
begin
  if Trim(AProjectId) = '' then
    Exit;

  TMonitor.Enter(FProjects);
  try
    LAlreadyLoaded := FLoadedProjects.ContainsKey(AProjectId);
  finally
    TMonitor.Exit(FProjects);
  end;
  if LAlreadyLoaded then
    Exit;

  if Assigned(FStore) and FStore.Load(AProjectId, LSnapshot) and
    SameText(LSnapshot.ProjectId, AProjectId) then
    RestoreSnapshot(LSnapshot)
  else
  begin
    TMonitor.Enter(FProjects);
    try
      FLoadedProjects.AddOrSetValue(AProjectId, True);
    finally
      TMonitor.Exit(FProjects);
    end;
  end;
end;

function TRadIALocalKnowledgeService.GetOrCreateProject(
  const AProjectId: string
): TRadIAKnowledgeProjectIndex;
begin
  if not FProjects.TryGetValue(AProjectId, Result) then
  begin
    Result := TRadIAKnowledgeProjectIndex.Create;
    FProjects.Add(AProjectId, Result);
  end;
end;

function TRadIALocalKnowledgeService.GetCurrentProjectId: string;
begin
  Result := FSource.GetProjectId;
end;

function TRadIALocalKnowledgeService.GetDocument(
  const AProjectId: string;
  const AFileName: string;
  out ADocument: TRadIAIndexedKnowledgeDocument
): Boolean;
var
  LChunk: TRadIAKnowledgeChunkEntry;
  LChunks: TList<TRadIAKnowledgeChunk>;
  LFile: TRadIAKnowledgeFileEntry;
  LFileName: string;
  LIndex: TRadIAKnowledgeProjectIndex;
begin
  Result := False;
  ADocument := Default(TRadIAIndexedKnowledgeDocument);
  if (Trim(AProjectId) = '') or (Trim(AFileName) = '') then
    Exit;
  EnsureProjectLoaded(AProjectId);
  LChunks := TList<TRadIAKnowledgeChunk>.Create;
  try
    TMonitor.Enter(FProjects);
    try
      if not FProjects.TryGetValue(AProjectId, LIndex) then
        Exit;
      LFile := nil;
      for LFileName in LIndex.Files.Keys do
      begin
        if SameText(LFileName, AFileName) then
        begin
          LFile := LIndex.Files[LFileName];
          Break;
        end;
      end;
      if not Assigned(LFile) then
        Exit;
      for LChunk in LFile.Chunks do
        LChunks.Add(LChunk.Chunk);
      ADocument := TRadIAIndexedKnowledgeDocument.Create(
        AFileName,
        LFile.Revision,
        LChunks.ToArray
      );
      Result := True;
    finally
      TMonitor.Exit(FProjects);
    end;
  finally
    LChunks.Free;
  end;
end;

function TRadIALocalKnowledgeService.GetStatus(
  const AProjectId: string
): TRadIAKnowledgeStatus;
var
  LChunkCount: Integer;
  LFile: TRadIAKnowledgeFileEntry;
  LFileCount: Integer;
  LIndex: TRadIAKnowledgeProjectIndex;
  LLoaded: Boolean;
begin
  if Trim(AProjectId) = '' then
    Exit(TRadIAKnowledgeStatus.Create('', False, 0, 0));
  EnsureProjectLoaded(AProjectId);
  LChunkCount := 0;
  LFileCount := 0;
  TMonitor.Enter(FProjects);
  try
    LLoaded := FLoadedProjects.ContainsKey(AProjectId);
    if FProjects.TryGetValue(AProjectId, LIndex) then
    begin
      LFileCount := LIndex.Files.Count;
      for LFile in LIndex.Files.Values do
        Inc(LChunkCount, LFile.Chunks.Count);
    end;
  finally
    TMonitor.Exit(FProjects);
  end;
  Result := TRadIAKnowledgeStatus.Create(
    AProjectId,
    LLoaded,
    LFileCount,
    LChunkCount
  );
end;

function TRadIALocalKnowledgeService.IsStructuralDeclaration(
  const ALine: string;
  out ASymbol: string
): Boolean;
var
  LLine: string;
begin
  LLine := Trim(ALine);
  ASymbol := LLine;
  if Length(ASymbol) > 160 then
    ASymbol := Copy(ASymbol, Low(ASymbol), 160);
  LLine := LowerCase(LLine);
  Result := LLine.StartsWith('unit ') or
    LLine.StartsWith('interface') or
    LLine.StartsWith('implementation') or
    LLine.StartsWith('type') or
    (Pos(' = class', LLine) > 0) or
    (Pos(' = record', LLine) > 0) or
    (Pos(' = interface', LLine) > 0) or
    LLine.StartsWith('procedure ') or
    LLine.StartsWith('function ') or
    LLine.StartsWith('constructor ') or
    LLine.StartsWith('destructor ') or
    LLine.StartsWith('class procedure ') or
    LLine.StartsWith('class function ');
end;

function TRadIALocalKnowledgeService.NeedsDocumentUpdate(
  const AProjectId: string;
  const AFileName: string;
  const ARevision: string
): Boolean;
var
  LEntry: TRadIAKnowledgeFileEntry;
  LIndex: TRadIAKnowledgeProjectIndex;
begin
  TMonitor.Enter(FProjects);
  try
    LIndex := GetOrCreateProject(AProjectId);
    Result := not LIndex.Files.TryGetValue(AFileName, LEntry) or
      not SameText(LEntry.Revision, ARevision);
  finally
    TMonitor.Exit(FProjects);
  end;
end;

function TRadIALocalKnowledgeService.RefreshProject:
  TRadIAKnowledgeRefreshResult;
var
  LFileName: string;
  LFiles: TArray<string>;
  LIndexedFiles: Integer;
  LKnownFiles: TDictionary<string, Boolean>;
  LProjectId: string;
  LRemovedFiles: Integer;
  LSkippedFiles: Integer;
  LSnapshot: TRadIAKnowledgeIndexSnapshot;
  LUpdatedFiles: Integer;
begin
  LProjectId := Trim(FSource.GetProjectId);
  if LProjectId = '' then
    Exit(TRadIAKnowledgeRefreshResult.Failed(
      CInvalidProject,
      'No active project is available for indexing.'
    ));
  EnsureProjectLoaded(LProjectId);
  LFiles := FSource.ListSourceFiles;
  if Length(LFiles) > CMaxProjectFiles then
    SetLength(LFiles, CMaxProjectFiles);

  LKnownFiles := TDictionary<string, Boolean>.Create;
  try
    LUpdatedFiles := 0;
    LSkippedFiles := 0;
    LRemovedFiles := 0;
    TMonitor.Enter(FProjects);
    try
      GetOrCreateProject(LProjectId);
    finally
      TMonitor.Exit(FProjects);
    end;
    for LFileName in LFiles do
    begin
      if Trim(LFileName) = '' then
        Continue;
      LKnownFiles.AddOrSetValue(LFileName, True);
      if RefreshFile(LProjectId, LFileName) = kfrUpdated then
        Inc(LUpdatedFiles)
      else
        Inc(LSkippedFiles);
    end;

    RemoveStaleFiles(
      LProjectId,
      LKnownFiles,
      LIndexedFiles,
      LRemovedFiles
    );
    if Assigned(FStore) then
    begin
      LSnapshot := CreateSnapshot(LProjectId);
      FStore.Save(LSnapshot);
    end;
    Result := TRadIAKnowledgeRefreshResult.Succeeded(
      LProjectId,
      LIndexedFiles,
      LUpdatedFiles,
      LSkippedFiles,
      LRemovedFiles
    );
  finally
    LKnownFiles.Free;
  end;
end;

function TRadIALocalKnowledgeService.RefreshFile(
  const AProjectId: string;
  const AFileName: string
): TRadIAKnowledgeFileRefresh;
var
  LChunks: TArray<TRadIAKnowledgeChunk>;
  LDocument: TRadIAKnowledgeDocument;
  LEntry: TRadIAKnowledgeFileEntry;
  LIndex: TRadIAKnowledgeProjectIndex;
begin
  Result := kfrSkipped;
  if not FSource.ReadSourceFile(AFileName, LDocument) or
    (Length(LDocument.Content) > CMaxDocumentCharacters) then
    Exit;
  if not NeedsDocumentUpdate(
    AProjectId,
    AFileName,
    LDocument.Revision
  ) then
    Exit;
  LChunks := BuildChunks(LDocument);
  TMonitor.Enter(FProjects);
  try
    LIndex := GetOrCreateProject(AProjectId);
    if LIndex.Files.TryGetValue(AFileName, LEntry) and
      SameText(LEntry.Revision, LDocument.Revision) then
      Exit;
    LEntry := TRadIAKnowledgeFileEntry.Create(
      LDocument.Revision,
      LChunks
    );
    LIndex.Files.AddOrSetValue(AFileName, LEntry);
    Result := kfrUpdated;
  finally
    TMonitor.Exit(FProjects);
  end;
end;

procedure TRadIALocalKnowledgeService.RemoveStaleFiles(
  const AProjectId: string;
  const AKnownFiles: TDictionary<string, Boolean>;
  out AIndexedFiles: Integer;
  out ARemovedFiles: Integer
);
var
  LIndex: TRadIAKnowledgeProjectIndex;
  LStoredFile: string;
  LToRemove: TList<string>;
begin
  ARemovedFiles := 0;
  LToRemove := TList<string>.Create;
  try
    TMonitor.Enter(FProjects);
    try
      LIndex := GetOrCreateProject(AProjectId);
      for LStoredFile in LIndex.Files.Keys do
        if not AKnownFiles.ContainsKey(LStoredFile) then
          LToRemove.Add(LStoredFile);
      for LStoredFile in LToRemove do
      begin
        LIndex.Files.Remove(LStoredFile);
        Inc(ARemovedFiles);
      end;
      AIndexedFiles := LIndex.Files.Count;
      FLoadedProjects.AddOrSetValue(AProjectId, True);
    finally
      TMonitor.Exit(FProjects);
    end;
  finally
    LToRemove.Free;
  end;
end;

procedure TRadIALocalKnowledgeService.RestoreSnapshot(
  const ASnapshot: TRadIAKnowledgeIndexSnapshot
);
var
  LChunk: TRadIAKnowledgeChunk;
  LChunksByFile: TObjectDictionary<string, TList<TRadIAKnowledgeChunk>>;
  LFileChunks: TList<TRadIAKnowledgeChunk>;
  LFileName: string;
  LIndex: TRadIAKnowledgeProjectIndex;
begin
  LChunksByFile :=
    TObjectDictionary<string, TList<TRadIAKnowledgeChunk>>.Create(
      [doOwnsValues]
    );
  LIndex := TRadIAKnowledgeProjectIndex.Create;
  try
    for LChunk in ASnapshot.Chunks do
    begin
      if not LChunksByFile.TryGetValue(LChunk.FileName, LFileChunks) then
      begin
        LFileChunks := TList<TRadIAKnowledgeChunk>.Create;
        LChunksByFile.Add(LChunk.FileName, LFileChunks);
      end;
      LFileChunks.Add(LChunk);
    end;
    for LFileName in LChunksByFile.Keys do
    begin
      LFileChunks := LChunksByFile[LFileName];
      if LFileChunks.Count > 0 then
        LIndex.Files.Add(
          LFileName,
          TRadIAKnowledgeFileEntry.Create(
            LFileChunks[0].Revision,
            LFileChunks.ToArray
          )
        );
    end;

    TMonitor.Enter(FProjects);
    try
      if not FLoadedProjects.ContainsKey(ASnapshot.ProjectId) then
      begin
        FProjects.AddOrSetValue(ASnapshot.ProjectId, LIndex);
        LIndex := nil;
        FLoadedProjects.AddOrSetValue(ASnapshot.ProjectId, True);
      end;
    finally
      TMonitor.Exit(FProjects);
    end;
  finally
    LIndex.Free;
    LChunksByFile.Free;
  end;
end;

function TRadIALocalKnowledgeService.Search(
  const AProjectId: string;
  const AQuery: string;
  const AMaxResults: Integer
): TArray<TRadIAKnowledgeSearchHit>;
var
  LChunkEntry: TRadIAKnowledgeChunkEntry;
  LFileEntry: TRadIAKnowledgeFileEntry;
  LHits: TList<TRadIAKnowledgeSearchHit>;
  LIndex: TRadIAKnowledgeProjectIndex;
  LQueryTokens: TArray<string>;
  LScore: Integer;
begin
  if (Trim(AProjectId) = '') or
    (Trim(AQuery) = '') or
    (AMaxResults < 1) then
    Exit(nil);
  LQueryTokens := Tokenize(AQuery);
  if Length(LQueryTokens) = 0 then
    Exit(nil);
  EnsureProjectLoaded(AProjectId);

  LHits := TList<TRadIAKnowledgeSearchHit>.Create;
  try
    TMonitor.Enter(FProjects);
    try
      if not FProjects.TryGetValue(AProjectId, LIndex) then
        Exit(nil);
      for LFileEntry in LIndex.Files.Values do
      begin
        for LChunkEntry in LFileEntry.Chunks do
        begin
          LScore := LChunkEntry.Score(LQueryTokens);
          if LScore > 0 then
            LHits.Add(
              TRadIAKnowledgeSearchHit.Create(
                LChunkEntry.Chunk,
                LScore
              )
            );
        end;
      end;
    finally
      TMonitor.Exit(FProjects);
    end;

    LHits.Sort(
      TComparer<TRadIAKnowledgeSearchHit>.Construct(
        function(
          const ALeft: TRadIAKnowledgeSearchHit;
          const ARight: TRadIAKnowledgeSearchHit
        ): Integer
        begin
          Result := ARight.Score - ALeft.Score;
          if Result = 0 then
            Result := CompareText(
              ALeft.Chunk.FileName,
              ARight.Chunk.FileName
            );
        end
      )
    );
    if LHits.Count > AMaxResults then
      LHits.DeleteRange(AMaxResults, LHits.Count - AMaxResults);
    Result := LHits.ToArray;
  finally
    LHits.Free;
  end;
end;

class function TRadIALocalKnowledgeService.Tokenize(
  const AText: string
): TArray<string>;
var
  LBuilder: TStringBuilder;
  LCharacter: Char;
  LTokens: TList<string>;

  procedure FlushToken;
  var
    LToken: string;
  begin
    if LBuilder.Length < 2 then
    begin
      LBuilder.Clear;
      Exit;
    end;
    LToken := LowerCase(LBuilder.ToString);
    if not LTokens.Contains(LToken) then
      LTokens.Add(LToken);
    LBuilder.Clear;
  end;

begin
  LBuilder := TStringBuilder.Create;
  LTokens := TList<string>.Create;
  try
    for LCharacter in AText do
    begin
      if LCharacter.IsLetterOrDigit or
        (LCharacter = '_') then
        LBuilder.Append(LCharacter)
      else
        FlushToken;
    end;
    FlushToken;
    Result := LTokens.ToArray;
  finally
    LTokens.Free;
    LBuilder.Free;
  end;
end;

end.
