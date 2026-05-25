@echo off
REM ---------------------------------------------------------------------------
REM  Roda o SwiftIPTV apontando para a lista de teste local (smoke_test.m3u).
REM  Pula o login e vai direto ao player para validar a reproducao.
REM ---------------------------------------------------------------------------
cd /d "%~dp0"

set "SWIFTIPTV_LOCAL_M3U=%~dp0smoke_test.m3u"

set "EXE=build\Release\SwiftIPTV.exe"
if not exist "%EXE%" set "EXE=build\SwiftIPTV.exe"
if not exist "%EXE%" (
    echo [ERRO] Nao encontrei o executavel. Rode install.bat primeiro.
    pause
    exit /b 1
)

echo Abrindo SwiftIPTV em modo de teste com 3 canais...
start "" "%EXE%"
