unit RadIA.OTA.KnowledgeNotifier;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.ExtCtrls,
  RadIA.Core.KnowledgeScheduler;

type
  TRadIAKnowledgeModuleAttachment = record
  private
    FModuleIdentity: NativeUInt;
    FNotifierIndex: Integer;
  public
    constructor Create(
      const AModuleIdentity: NativeUInt;
      const ANotifierIndex: Integer
    );
    property ModuleIdentity: NativeUInt read FModuleIdentity;
    property NotifierIndex: Integer read FNotifierIndex;
  end;

  TRadIAOTAKnowledgeNotifier = class(TComponent)
  private
    FAttachments:
      TDictionary<string, TRadIAKnowledgeModuleAttachment>;
    FInstalled: Boolean;
    FModuleNotifier: IInterface;
    FScheduler: IRadIAKnowledgeRefreshScheduler;
    FTimer: TTimer;
    function TryFindAttachment(
      const AModuleIdentity: NativeUInt;
      out AFileName: string;
      out AAttachment: TRadIAKnowledgeModuleAttachment
    ): Boolean;
    procedure RefreshAttachments;
    procedure TimerEvent(Sender: TObject);
  public
    constructor Create(
      AOwner: TComponent;
      const AScheduler: IRadIAKnowledgeRefreshScheduler
    ); reintroduce;
    destructor Destroy; override;
    class function SupportsSourceFile(
      const AFileName: string
    ): Boolean; static;
    procedure Install;
    procedure Uninstall;
  end;

function CreateRadIAKnowledgeModuleNotifier(
  const AScheduler: IRadIAKnowledgeRefreshScheduler
): IInterface;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  RadIA.Core.Logger,
  RadIA.Core.Types;

type
  TRadIAKnowledgeModuleNotifier = class(
    TNotifierObject,
    IOTAModuleNotifier
  )
  private
    FScheduler: IRadIAKnowledgeRefreshScheduler;
  public
    constructor Create(
      const AScheduler: IRadIAKnowledgeRefreshScheduler
    );
    procedure AfterSave;
    procedure BeforeSave;
    function CheckOverwrite: Boolean;
    procedure Destroyed;
    procedure Modified;
    procedure ModuleRenamed(const NewName: string);
  end;

{ TRadIAKnowledgeModuleAttachment }

constructor TRadIAKnowledgeModuleAttachment.Create(
  const AModuleIdentity: NativeUInt;
  const ANotifierIndex: Integer
);
begin
  FModuleIdentity := AModuleIdentity;
  FNotifierIndex := ANotifierIndex;
end;

{ TRadIAKnowledgeModuleNotifier }

procedure TRadIAKnowledgeModuleNotifier.AfterSave;
begin
  FScheduler.MarkDirty;
end;

procedure TRadIAKnowledgeModuleNotifier.BeforeSave;
begin
  if True then ;
end;

function TRadIAKnowledgeModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

constructor TRadIAKnowledgeModuleNotifier.Create(
  const AScheduler: IRadIAKnowledgeRefreshScheduler
);
begin
  inherited Create;
  FScheduler := AScheduler;
end;

procedure TRadIAKnowledgeModuleNotifier.Destroyed;
begin
  FScheduler.MarkDirty;
end;

procedure TRadIAKnowledgeModuleNotifier.Modified;
begin
  FScheduler.MarkDirty;
end;

procedure TRadIAKnowledgeModuleNotifier.ModuleRenamed(
  const NewName: string
);
begin
  FScheduler.MarkDirty;
end;

{ TRadIAOTAKnowledgeNotifier }

function CreateRadIAKnowledgeModuleNotifier(
  const AScheduler: IRadIAKnowledgeRefreshScheduler
): IInterface;
begin
  if not Assigned(AScheduler) then
    raise EArgumentNilException.Create('AScheduler');
  Result := TRadIAKnowledgeModuleNotifier.Create(AScheduler);
end;

constructor TRadIAOTAKnowledgeNotifier.Create(
  AOwner: TComponent;
  const AScheduler: IRadIAKnowledgeRefreshScheduler
);
begin
  inherited Create(AOwner);
  if not Assigned(AScheduler) then
    raise EArgumentNilException.Create('AScheduler');
  FScheduler := AScheduler;
  FAttachments :=
    TDictionary<string, TRadIAKnowledgeModuleAttachment>.Create;
  FModuleNotifier := CreateRadIAKnowledgeModuleNotifier(FScheduler);
end;

destructor TRadIAOTAKnowledgeNotifier.Destroy;
begin
  Uninstall;
  FModuleNotifier := nil;
  FAttachments.Free;
  inherited;
end;

procedure TRadIAOTAKnowledgeNotifier.Install;
begin
  if FInstalled then
    Exit;
  FInstalled := True;
  RefreshAttachments;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 500;
  FTimer.OnTimer := TimerEvent;
  FTimer.Enabled := True;
end;

class function TRadIAOTAKnowledgeNotifier.SupportsSourceFile(
  const AFileName: string
): Boolean;
var
  LExtension: string;
begin
  LExtension := LowerCase(TPath.GetExtension(AFileName));
  Result := (LExtension = '.pas') or
    (LExtension = '.dpr') or
    (LExtension = '.dpk') or
    (LExtension = '.inc');
end;

procedure TRadIAOTAKnowledgeNotifier.RefreshAttachments;
var
  LCurrentFiles: TDictionary<string, Boolean>;
  LFileName: string;
  LIndex: Integer;
  LExistingAttachment: TRadIAKnowledgeModuleAttachment;
  LExistingFileName: string;
  LModule: IOTAModule;
  LModuleIdentity: NativeUInt;
  LModuleServices: IOTAModuleServices;
  LNotifier: IOTAModuleNotifier;
  LNotifierIndex: Integer;
  LStaleFiles: TList<string>;
begin
  if GIsShuttingDown or
    not Supports(
      BorlandIDEServices,
      IOTAModuleServices,
      LModuleServices
    ) then
    Exit;

  LCurrentFiles := TDictionary<string, Boolean>.Create;
  LStaleFiles := TList<string>.Create;
  try
    Supports(FModuleNotifier, IOTAModuleNotifier, LNotifier);
    for LIndex := 0 to LModuleServices.ModuleCount - 1 do
    begin
      LModule := LModuleServices.Modules[LIndex];
      if not Assigned(LModule) then
        Continue;
      LFileName := LModule.FileName;
      if not SupportsSourceFile(LFileName) then
        Continue;
      LCurrentFiles.AddOrSetValue(LFileName, True);
      LModuleIdentity := NativeUInt(Pointer(LModule));
      if TryFindAttachment(
        LModuleIdentity,
        LExistingFileName,
        LExistingAttachment
      ) then
      begin
        if not SameText(LExistingFileName, LFileName) then
        begin
          FAttachments.Remove(LExistingFileName);
          FAttachments.AddOrSetValue(
            LFileName,
            LExistingAttachment
          );
        end;
      end
      else
      begin
        LNotifierIndex := LModule.AddNotifier(LNotifier);
        if LNotifierIndex >= 0 then
          FAttachments.Add(
            LFileName,
            TRadIAKnowledgeModuleAttachment.Create(
              LModuleIdentity,
              LNotifierIndex
            )
          );
      end;
      LModule := nil;
    end;

    for LFileName in FAttachments.Keys do
    begin
      if not LCurrentFiles.ContainsKey(LFileName) then
        LStaleFiles.Add(LFileName);
    end;
    for LFileName in LStaleFiles do
      FAttachments.Remove(LFileName);
  finally
    LStaleFiles.Free;
    LCurrentFiles.Free;
  end;
end;

function TRadIAOTAKnowledgeNotifier.TryFindAttachment(
  const AModuleIdentity: NativeUInt;
  out AFileName: string;
  out AAttachment: TRadIAKnowledgeModuleAttachment
): Boolean;
var
  LPair: TPair<string, TRadIAKnowledgeModuleAttachment>;
begin
  AFileName := '';
  AAttachment := Default(TRadIAKnowledgeModuleAttachment);
  for LPair in FAttachments do
  begin
    if LPair.Value.ModuleIdentity = AModuleIdentity then
    begin
      AFileName := LPair.Key;
      AAttachment := LPair.Value;
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TRadIAOTAKnowledgeNotifier.TimerEvent(Sender: TObject);
begin
  if GIsShuttingDown then
  begin
    FTimer.Enabled := False;
    FScheduler.Stop;
    Exit;
  end;
  RefreshAttachments;
  FScheduler.Poll;
end;

procedure TRadIAOTAKnowledgeNotifier.Uninstall;
var
  LFileName: string;
  LIndex: Integer;
  LModule: IOTAModule;
  LModuleServices: IOTAModuleServices;
begin
  if not FInstalled then
    Exit;
  FInstalled := False;
  FScheduler.Stop;
  if Assigned(FTimer) then
  begin
    FTimer.Enabled := False;
    FreeAndNil(FTimer);
  end;

  if not GIsShuttingDown and Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
  begin
    for LIndex := 0 to LModuleServices.ModuleCount - 1 do
    begin
      LModule := LModuleServices.Modules[LIndex];
      if not Assigned(LModule) then
        Continue;
      LFileName := LModule.FileName;
      if FAttachments.ContainsKey(LFileName) then
      begin
        try
          LModule.RemoveNotifier(
            FAttachments[LFileName].NotifierIndex
          );
        except
          on E: Exception do
            TLogger.Log(
              'Knowledge notifier removal failed: ' + E.Message,
              'Knowledge'
            );
        end;
      end;
      LModule := nil;
    end;
  end;
  FAttachments.Clear;
end;

end.
