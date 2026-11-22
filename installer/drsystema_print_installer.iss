; Script Inno Setup para gerar o instalador DRSystemaPrintSetup.exe
; Requer Inno Setup 6 (https://jrsoftware.org/isdl.php)

#define MyAppName "DRSystema Print"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "DRSystema"
#define MyAppURL "https://drsystema.com.br"
#define MyAppExeName "drsystema_print.exe"

[Setup]
AppId={{C90A6753-DD06-46C1-93D2-539E7F3EFD95}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\installer_output
OutputBaseFilename=DRSystemaPrintSetup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Iniciar automaticamente com o Windows"; GroupDescription: "Inicialização:"

[Files]
; Copia todos os arquivos da compilação de Release do Flutter
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Inicia com o Windows se a tarefa estiver marcada
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
{ Página customizada: configuração da API de conversão XML.
  Grava a escolha em api_url.txt ao lado do .exe — o app importa
  na primeira execução e apaga o arquivo. }
var
  ApiPage: TWizardPage;
  RadioOficial, RadioPropria, RadioDepois: TNewRadioButton;
  EditSenha, EditUrl: TNewEdit;
  LblSenha, LblUrl: TNewLabel;

procedure ApiRadioClick(Sender: TObject);
begin
  EditSenha.Enabled := RadioOficial.Checked;
  EditUrl.Enabled := RadioPropria.Checked;
end;

procedure InitializeWizard;
begin
  ApiPage := CreateCustomPage(wpSelectTasks,
    'API de Conversão XML (opcional)',
    'Permite imprimir arquivos XML fiscais direto do aplicativo');

  RadioOficial := TNewRadioButton.Create(ApiPage);
  RadioOficial.Parent := ApiPage.Surface;
  RadioOficial.Caption := 'Usar API oficial DRSystema (senha do dia — a URL vem do servidor)';
  RadioOficial.Top := 0;
  RadioOficial.Left := 0;
  RadioOficial.Width := ApiPage.SurfaceWidth;
  RadioOficial.OnClick := @ApiRadioClick;

  LblSenha := TNewLabel.Create(ApiPage);
  LblSenha.Parent := ApiPage.Surface;
  LblSenha.Caption := 'Senha do dia (DR + DDMMAAAA, ex.: DR05032025):';
  LblSenha.Top := 26;
  LblSenha.Left := 24;

  EditSenha := TNewEdit.Create(ApiPage);
  EditSenha.Parent := ApiPage.Surface;
  EditSenha.Top := 42;
  EditSenha.Left := 24;
  EditSenha.Width := 250;

  RadioPropria := TNewRadioButton.Create(ApiPage);
  RadioPropria.Parent := ApiPage.Surface;
  RadioPropria.Caption := 'Minha própria API (URL completa do arquivo no seu servidor)';
  RadioPropria.Top := 78;
  RadioPropria.Left := 0;
  RadioPropria.Width := ApiPage.SurfaceWidth;
  RadioPropria.OnClick := @ApiRadioClick;

  LblUrl := TNewLabel.Create(ApiPage);
  LblUrl.Parent := ApiPage.Surface;
  LblUrl.Caption := 'URL (ex.: https://seudominio.com.br/php_api/imprimir_xml.php?token=SEU_TOKEN):';
  LblUrl.Top := 104;
  LblUrl.Left := 24;
  LblUrl.Width := ApiPage.SurfaceWidth;
  LblUrl.AutoSize := True;

  EditUrl := TNewEdit.Create(ApiPage);
  EditUrl.Parent := ApiPage.Surface;
  EditUrl.Top := 120;
  EditUrl.Left := 24;
  EditUrl.Width := ApiPage.SurfaceWidth - 40;

  RadioDepois := TNewRadioButton.Create(ApiPage);
  RadioDepois.Parent := ApiPage.Surface;
  RadioDepois.Caption := 'Configurar depois (no aplicativo, em Preferências)';
  RadioDepois.Top := 158;
  RadioDepois.Left := 0;
  RadioDepois.Width := ApiPage.SurfaceWidth;
  RadioDepois.Checked := True;
  RadioDepois.OnClick := @ApiRadioClick;

  ApiRadioClick(nil);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  FinalUrl: String;
begin
  if CurStep = ssPostInstall then
  begin
    FinalUrl := '';
    if RadioOficial.Checked and (Trim(EditSenha.Text) <> '') then
      { O app troca a senha pela URL oficial via validador remoto —
        a URL real nunca fica gravada no instalador }
      FinalUrl := 'senha:' + Trim(EditSenha.Text)
    else if RadioPropria.Checked and (Trim(EditUrl.Text) <> '') then
      FinalUrl := 'url:' + Trim(EditUrl.Text);
    if FinalUrl <> '' then
      SaveStringToFile(ExpandConstant('{app}\api_url.txt'), FinalUrl, False);
  end;
end;
