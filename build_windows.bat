@echo off
echo ========================================================
echo       DRSystema Print - Compilador Windows Release
echo ========================================================
echo.

echo 1. Obtendo dependencias do Flutter...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Falha ao baixar dependencias do Flutter.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo 2. Executando testes unitarios...
call flutter test
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Falha nos testes unitarios.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo 3. Compilando o executavel nativo para Windows (Release)...
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Falha ao compilar para Windows.
    echo Certifique-se de que o Visual Studio com ferramentas C++ esta instalado.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================================
echo  SUCESSO! O executavel foi gerado em:
echo  build\windows\x64\runner\Release\drsystema_print.exe
echo ========================================================
echo.
pause
