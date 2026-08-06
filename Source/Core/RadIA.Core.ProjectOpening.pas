unit RadIA.Core.ProjectOpening;

interface

type
  IRadIAProjectOpeningFacade = interface
    ['{B1705EF8-27C7-4C06-A01D-4BBE09C61543}']
    function OpenProject(const AProjectFileName: string): Boolean;
    function CloseProject(const AProjectFileName: string): Boolean;
  end;

implementation

end.
