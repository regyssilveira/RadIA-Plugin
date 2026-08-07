program RadIARuntimeLab;

uses
  Vcl.Forms,
  RadIA.RuntimeLab.MainForm in 'RadIA.RuntimeLab.MainForm.pas' {RadIARuntimeLabMainForm},
  RadIA.RuntimeLab.TargetForm in 'RadIA.RuntimeLab.TargetForm.pas' {RadIARuntimeLabTargetForm};

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(
    TRadIARuntimeLabMainForm,
    RadIARuntimeLabMainForm
  );
  Application.Run;
end.
