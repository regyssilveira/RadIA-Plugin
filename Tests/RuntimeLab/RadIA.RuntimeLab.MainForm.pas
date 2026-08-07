unit RadIA.RuntimeLab.MainForm;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TRadIARuntimeLabMainForm = class(TForm)
    btnFailOnCancel: TButton;
    btnFailOnOpen: TButton;
    lblInstructions: TLabel;
    procedure btnFailOnCancelClick(Sender: TObject);
    procedure btnFailOnOpenClick(Sender: TObject);
  private
    procedure ShowTargetForm(const AFailOnOpen: Boolean);
  end;

var
  RadIARuntimeLabMainForm: TRadIARuntimeLabMainForm;

implementation

{$R *.dfm}

uses
  RadIA.RuntimeLab.TargetForm;

procedure TRadIARuntimeLabMainForm.btnFailOnCancelClick(
  Sender: TObject
);
begin
  ShowTargetForm(False);
end;

procedure TRadIARuntimeLabMainForm.btnFailOnOpenClick(
  Sender: TObject
);
begin
  ShowTargetForm(True);
end;

procedure TRadIARuntimeLabMainForm.ShowTargetForm(
  const AFailOnOpen: Boolean
);
var
  LTargetForm: TRadIARuntimeLabTargetForm;
begin
  LTargetForm := TRadIARuntimeLabTargetForm.Create(nil);
  try
    LTargetForm.FailOnOpen := AFailOnOpen;
    LTargetForm.ShowModal;
  finally
    LTargetForm.Free;
  end;
end;

end.
