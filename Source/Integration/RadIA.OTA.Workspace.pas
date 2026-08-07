unit RadIA.OTA.Workspace;

interface

uses
  System.Classes,
  RadIA.Core.Interfaces,
  RadIA.Core.Workspace,
  RadIA.Core.Patches;

type
  TRadIAOTAWorkspaceFacade = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade,
    IRadIAEditorMutationFacade,
    IRadIAEditorPersistenceFacade
  )
  private
    FIDEAdapter: IRadIAIDEAdapter;
    FEditorAdapter: IRadIAEditorAdapter;
    procedure RunOnMainThread(const AAction: TThreadProcedure);
  public
    constructor Create(
      const AIDEAdapter: IRadIAIDEAdapter;
      const AEditorAdapter: IRadIAEditorAdapter
    );
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
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
    function ReadContent(
      const AFileName: string;
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function ReloadFile(const AFileName: string): Boolean;
  end;

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  Winapi.Windows,
  RadIA.Core.Types,
  RadIA.OTA.TextReader;

const
  CWorkspaceUnavailable = 'The IDE workspace is shutting down.';

function FindSourceEditor(
  const AFileName: string
): IOTASourceEditor;
var
  LEditorIndex: Integer;
  LModule: IOTAModule;
  LModuleIndex: Integer;
  LModuleServices: IOTAModuleServices;
  LSourceEditor: IOTASourceEditor;
begin
  Result := nil;
  if not Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    Exit;
  for LModuleIndex := 0 to LModuleServices.ModuleCount - 1 do
  begin
    LModule := LModuleServices.Modules[LModuleIndex];
    if not Assigned(LModule) then
      Continue;
    for LEditorIndex := 0 to LModule.ModuleFileCount - 1 do
    begin
      if Supports(
        LModule.ModuleFileEditors[LEditorIndex],
        IOTASourceEditor,
        LSourceEditor
      ) and SameFileName(LSourceEditor.FileName, AFileName) then
        Exit(LSourceEditor);
    end;
  end;
end;

function ReloadModuleFile(const AFileName: string): Boolean;
var
  LActionServices: IOTAActionServices;
begin
  Result := False;
  if not Supports(
    BorlandIDEServices,
    IOTAActionServices,
    LActionServices
  ) then
    Exit;
  Result := LActionServices.ReloadFile(AFileName);
end;

function GetActiveProjectFromOTA: IOTAProject;
var
  LModuleServices: IOTAModuleServices;
begin
  Result := nil;
  if Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    Result := LModuleServices.GetActiveProject;
end;

function GetCurrentModuleFileName: string;
var
  LEditBuffer: IOTAEditBuffer;
  LEditorServices: IOTAEditorServices;
  LModule: IOTAModule;
  LModuleServices: IOTAModuleServices;
begin
  Result := '';
  if Supports(
    BorlandIDEServices,
    IOTAEditorServices,
    LEditorServices
  ) then
  begin
    LEditBuffer := LEditorServices.TopBuffer;
    if Assigned(LEditBuffer) and (LEditBuffer.FileName <> '') then
      Exit(LEditBuffer.FileName);
  end;

  if not Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    Exit;

  LModule := LModuleServices.CurrentModule;
  if Assigned(LModule) then
    Result := LModule.FileName;
end;

function PrepareEditorWriterContent(const AContent: string): string;
begin
  Result := AContent;
  if Result.EndsWith(sLineBreak) then
    Delete(
      Result,
      Length(Result) - Length(sLineBreak) + 1,
      Length(sLineBreak)
    )
  else if Result.EndsWith(#10) then
    Delete(Result, Length(Result), 1);
end;

function ReplaceEditorContent(
  const ASourceEditor: IOTASourceEditor;
  const AContent: string
): Boolean;
var
  LCurrentContent: string;
  LEditWriter: IOTAEditWriter;
  LUtf8Bytes: TBytes;
  LUtf8Text: UTF8String;
begin
  Result := False;
  LCurrentContent := ReadRadIAEditReaderText(ASourceEditor.CreateReader);
  LUtf8Bytes := TEncoding.UTF8.GetBytes(LCurrentContent);
  LEditWriter := ASourceEditor.CreateUndoableWriter;
  if not Assigned(LEditWriter) then
    Exit;
  LEditWriter.CopyTo(0);
  if Length(LUtf8Bytes) > 0 then
    LEditWriter.DeleteTo(Length(LUtf8Bytes));
  LUtf8Text := UTF8Encode(PrepareEditorWriterContent(AContent));
  LEditWriter.Insert(PAnsiChar(LUtf8Text));
  LEditWriter := nil;
  Result := True;
end;

function TryApplyEditorContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
var
  LCurrentContent: string;
  LCurrentRevision: string;
  LSourceEditor: IOTASourceEditor;
begin
  Result := False;
  LSourceEditor := FindSourceEditor(AFileName);
  if not Assigned(LSourceEditor) then
    Exit;
  LCurrentContent := ReadRadIAEditReaderText(LSourceEditor.CreateReader);
  LCurrentRevision := THashSHA2.GetHashString(LCurrentContent);
  AAppliedRevision := LCurrentRevision;
  if not SameText(LCurrentRevision, AExpectedRevision) then
    Exit;
  if not ReplaceEditorContent(LSourceEditor, ANewContent) then
    Exit;
  AAppliedRevision := THashSHA2.GetHashString(
    ReadRadIAEditReaderText(LSourceEditor.CreateReader)
  );
  Result := SameText(
    AAppliedRevision,
    THashSHA2.GetHashString(ANewContent)
  );
  if Result then
    Exit;
  if ReplaceEditorContent(LSourceEditor, LCurrentContent) then
    AAppliedRevision := THashSHA2.GetHashString(
      ReadRadIAEditReaderText(LSourceEditor.CreateReader)
    );
end;

{ TRadIAOTAWorkspaceFacade }

constructor TRadIAOTAWorkspaceFacade.Create(
  const AIDEAdapter: IRadIAIDEAdapter;
  const AEditorAdapter: IRadIAEditorAdapter
);
begin
  inherited Create;
  if not Assigned(AIDEAdapter) then
    raise EArgumentNilException.Create('AIDEAdapter');
  if not Assigned(AEditorAdapter) then
    raise EArgumentNilException.Create('AEditorAdapter');
  FIDEAdapter := AIDEAdapter;
  FEditorAdapter := AEditorAdapter;
end;

function TRadIAOTAWorkspaceFacade.ApplyContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
var
  LAppliedRevision: string;
  LResult: Boolean;
begin
  LAppliedRevision := '';
  LResult := False;
  RunOnMainThread(
    procedure
    begin
      LResult := TryApplyEditorContent(
        AFileName,
        AExpectedRevision,
        ANewContent,
        LAppliedRevision
      );
    end
  );
  AAppliedRevision := LAppliedRevision;
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.ReadContent(
  const AFileName: string;
  const AMaxCharacters: Integer
): TRadIAEditorContent;
var
  LResult: TRadIAEditorContent;
begin
  RunOnMainThread(
    procedure
    var
      LContent: string;
      LOriginalLength: Integer;
      LSourceEditor: IOTASourceEditor;
      LTruncated: Boolean;
    begin
      LSourceEditor := FindSourceEditor(AFileName);
      if not Assigned(LSourceEditor) then
      begin
        LResult := Default(TRadIAEditorContent);
        Exit;
      end;
      LContent := ReadRadIAEditReaderText(
        LSourceEditor.CreateReader
      );
      LOriginalLength := Length(LContent);
      LTruncated := (AMaxCharacters > 0) and
        (LOriginalLength > AMaxCharacters);
      if LTruncated then
        SetLength(LContent, AMaxCharacters);
      LResult := TRadIAEditorContent.Create(
        TPath.GetFileNameWithoutExtension(AFileName),
        AFileName,
        LContent,
        THashSHA2.GetHashString(LContent),
        LOriginalLength,
        LTruncated
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.ReloadFile(
  const AFileName: string
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    begin
      LResult := ReloadModuleFile(AFileName);
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.GetActiveProject:
  TRadIAProjectSnapshot;
var
  LResult: TRadIAProjectSnapshot;
begin
  RunOnMainThread(
    procedure
    var
      LProject: IOTAProject;
    begin
      LProject := GetActiveProjectFromOTA;
      if not Assigned(LProject) then
      begin
        LResult := Default(TRadIAProjectSnapshot);
        Exit;
      end;

      LResult := TRadIAProjectSnapshot.Create(
        FIDEAdapter.GetActiveProjectName,
        LProject.FileName,
        ExtractFilePath(LProject.FileName),
        LProject.CurrentConfiguration,
        LProject.CurrentPlatform
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.GetActiveUnit: string;
var
  LResult: string;
begin
  RunOnMainThread(
    procedure
    begin
      LResult := FIDEAdapter.GetActiveUnitName;
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
var
  LResult: TArray<TRadIACompilerMessage>;
begin
  RunOnMainThread(
    procedure
    var
      LErrorMessage: string;
      LFileName: string;
      LLine: Integer;
    begin
      SetLength(LResult, 0);
      if AMaxCount <= 0 then
        Exit;
      if not FIDEAdapter.GetLastCompilerError(
        LErrorMessage,
        LFileName,
        LLine
      ) then
        Exit;

      SetLength(LResult, 1);
      LResult[0] := TRadIACompilerMessage.Create(
        cmsError,
        LErrorMessage,
        LFileName,
        LLine,
        0
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.GetCursorPosition:
  TRadIAEditorPosition;
var
  LResult: TRadIAEditorPosition;
begin
  RunOnMainThread(
    procedure
    begin
      LResult := TRadIAEditorPosition.Create(
        FEditorAdapter.GetCursorLine,
        FEditorAdapter.GetCursorColumn
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
var
  LResult: TRadIAEditorContent;
begin
  RunOnMainThread(
    procedure
    var
      LContent: string;
      LFileName: string;
      LOriginalLength: Integer;
      LRevision: string;
      LTruncated: Boolean;
    begin
      LContent := FEditorAdapter.GetText;
      LFileName := GetCurrentModuleFileName;
      LOriginalLength := Length(LContent);
      LRevision := THashSHA2.GetHashString(LContent);
      LTruncated := (AMaxCharacters >= 0) and
        (LOriginalLength > AMaxCharacters);
      if LTruncated then
        LContent := Copy(LContent, Low(LContent), AMaxCharacters);

      LResult := TRadIAEditorContent.Create(
        FEditorAdapter.GetActiveUnitName,
        LFileName,
        LContent,
        LRevision,
        LOriginalLength,
        LTruncated
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.GetEditorSelection:
  TRadIAEditorSelection;
var
  LResult: TRadIAEditorSelection;
begin
  RunOnMainThread(
    procedure
    begin
      LResult := TRadIAEditorSelection.Create(
        FEditorAdapter.GetSelectedText,
        FEditorAdapter.GetCursorLine,
        FEditorAdapter.GetCursorColumn
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.GetIDEState: TRadIAIDEState;
var
  LResult: TRadIAIDEState;
begin
  RunOnMainThread(
    procedure
    var
      LCapabilities: TArray<string>;
      LPlatform: string;
    begin
      LCapabilities := [
        'EditorRead',
        'ProjectRead',
        'CompilerMessages',
        'LiveFormRead',
        'DebuggerRead',
        'KnowledgeLocal'
      ];
      {$IFDEF WIN64}
      LPlatform := 'Win64';
      {$ELSE}
      LPlatform := 'Win32';
      {$ENDIF}
      LResult := TRadIAIDEState.Create(
        FIDEAdapter.GetDelphiVersionName,
        LPlatform,
        GIsShuttingDown,
        LCapabilities
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.ListOpenFiles: TArray<string>;
var
  LResult: TArray<string>;
begin
  RunOnMainThread(
    procedure
    var
      LFileNames: TList<string>;
      LIndex: Integer;
      LModule: IOTAModule;
      LModuleServices: IOTAModuleServices;
    begin
      SetLength(LResult, 0);
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;

      LFileNames := TList<string>.Create;
      try
        for LIndex := 0 to LModuleServices.ModuleCount - 1 do
        begin
          LModule := LModuleServices.Modules[LIndex];
          if Assigned(LModule) and (LModule.FileName <> '') then
            LFileNames.Add(LModule.FileName);
        end;
        LResult := LFileNames.ToArray;
      finally
        LFileNames.Free;
      end;
    end
  );
  Result := LResult;
end;

function TRadIAOTAWorkspaceFacade.ListProjectUnits: TArray<string>;
var
  LResult: TArray<string>;
begin
  RunOnMainThread(
    procedure
    var
      LFileNames: TList<string>;
      LIndex: Integer;
      LModuleInfo: IOTAModuleInfo;
      LProject: IOTAProject;
    begin
      SetLength(LResult, 0);
      LProject := GetActiveProjectFromOTA;
      if not Assigned(LProject) then
        Exit;

      LFileNames := TList<string>.Create;
      try
        for LIndex := 0 to LProject.GetModuleCount - 1 do
        begin
          LModuleInfo := LProject.GetModule(LIndex);
          if Assigned(LModuleInfo) and (LModuleInfo.FileName <> '') then
            LFileNames.Add(LModuleInfo.FileName);
        end;
        LResult := LFileNames.ToArray;
      finally
        LFileNames.Free;
      end;
    end
  );
  Result := LResult;
end;

procedure TRadIAOTAWorkspaceFacade.RunOnMainThread(
  const AAction: TThreadProcedure
);
begin
  if GIsShuttingDown then
    raise EInvalidOperation.Create(CWorkspaceUnavailable);

  if GetCurrentThreadId = MainThreadID then
    AAction()
  else
    TThread.Synchronize(nil, AAction);
end;

end.
