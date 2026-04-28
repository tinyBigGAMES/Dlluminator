program CImporter;

uses
  Vcl.Forms,
  UMainForm in 'UMainForm.pas' {Form1},
  UMessageProtocol in 'UMessageProtocol.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Tablet Dark');
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
