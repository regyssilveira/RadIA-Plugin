program RadIARuntimeLab;

uses
  Vcl.Forms,
  RadIA.Core.RuntimeAutomation in '..\..\Source\Core\RadIA.Core.RuntimeAutomation.pas',
  RadIA.Core.RuntimeVclAdapter in '..\..\Source\Core\RadIA.Core.RuntimeVclAdapter.pas',
  RadIA.Runtime.VclAdapter in '..\..\Source\Runtime\RadIA.Runtime.VclAdapter.pas',
  RadIA.Runtime.VclServer in '..\..\Source\Runtime\RadIA.Runtime.VclServer.pas',
  RadIA.RuntimeLab.MainForm in 'RadIA.RuntimeLab.MainForm.pas' {RadIARuntimeLabMainForm},
  RadIA.RuntimeLab.TargetForm in 'RadIA.RuntimeLab.TargetForm.pas' {RadIARuntimeLabTargetForm};

var
  RadIARuntimeVclServer: TRadIARuntimeVclServer;

begin
  RadIARuntimeVclServer := TRadIARuntimeVclServer.Create;
  try
    RadIARuntimeVclServer.Start;
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.CreateForm(
      TRadIARuntimeLabMainForm,
      RadIARuntimeLabMainForm
    );
    Application.Run;
  finally
    RadIARuntimeVclServer.Free;
  end;
end.
