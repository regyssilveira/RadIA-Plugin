unit RadIA.RuntimeLab.TargetForm;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TRadIARuntimeLabTargetForm = class(TForm)
    btnCancel: TButton;
    lblScenario: TLabel;
    procedure btnCancelClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FFailOnOpen: Boolean;
    procedure TriggerDeterministicAccessViolation;
  public
    property FailOnOpen: Boolean read FFailOnOpen write FFailOnOpen;
  end;

implementation

{$R *.dfm}

uses
  System.SysUtils;

type
  PRadIARuntimeLabPayload = ^TRadIARuntimeLabPayload;
  TRadIARuntimeLabPayload = record
    Value: Integer;
  end;

var
  GMemoryLeakFixture: TObject;

procedure TRadIARuntimeLabTargetForm.btnCancelClick(
  Sender: TObject
);
begin
  if SameText(
    GetEnvironmentVariable('RADIA_MEMORY_DIAGNOSTIC_SMOKE'),
    '1'
  ) then
  begin
    GMemoryLeakFixture := TStringList.Create;
    TStringList(GMemoryLeakFixture).Add('deterministic runtime leak');
    ModalResult := mrCancel;
    Exit;
  end;
  TriggerDeterministicAccessViolation;
end;

procedure TRadIARuntimeLabTargetForm.FormShow(Sender: TObject);
begin
  if FFailOnOpen then
    TriggerDeterministicAccessViolation;
end;

procedure TRadIARuntimeLabTargetForm.TriggerDeterministicAccessViolation;
var
  LPayload: PRadIARuntimeLabPayload;
begin
  LPayload := nil;
  LPayload^.Value := 1;
end;

end.
