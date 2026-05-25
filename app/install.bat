@echo off
REM ===========================================================================
REM  SwiftIPTV - install.bat
REM  Verifica/instala toolchain (VS2022 BuildTools, CMake, Qt 6, libMPV, NSIS),
REM  compila, roda windeployqt, copia a libmpv-2.dll, gera o SwiftIPTV-Setup.exe
REM  e abre a pasta final.
REM
REM  IMPORTANTE (leia): instalar TUDO automaticamente e ambicioso e fragil.
REM   - Requer 'winget' (App Installer) e internet.
REM   - O Qt e baixado via aqtinstall (sem conta Qt).
REM   - A libmpv-dev e baixada de uma URL versionada que PODE expirar (404):
REM     se falhar, baixe o 'mpv-dev-x86_64-*.7z' manualmente, extraia e defina
REM     a variavel MPV_ROOT (com include\mpv\client.h e lib\mpv.lib) antes de rodar.
REM   - Voce pode sobrescrever QT_DIR e MPV_ROOT no ambiente para pular downloads.
REM ===========================================================================

setlocal enableextensions enabledelayedexpansion
cd /d "%~dp0"
title SwiftIPTV - Instalador e Build

REM ---------- Configuracao (pode sobrescrever via "set VAR=..." antes) --------
if not defined QT_VERSION set "QT_VERSION=6.5.3"
if not defined QT_ARCH    set "QT_ARCH=win64_msvc2019_64"
set "QT_KIT=msvc2019_64"
set "BUILD_DIR=build"
set "THIRD=%~dp0third_party"
set "QT_INSTALL_ROOT=%~dp0Qt"
if not defined MPV_DEV_URL set "MPV_DEV_URL=https://sourceforge.net/projects/mpv-player-windows/files/libmpv/mpv-dev-x86_64-20240825-git-09a35e1.7z/download"
set "NEED_RESTART=0"

REM ---------- Elevacao (precisa de admin p/ instalar dependencias) ------------
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Solicitando privilegios de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo ===========================================================
echo   SwiftIPTV - preparando ambiente de build
echo ===========================================================
echo.

set "HAVE_WINGET=1"
where winget >nul 2>&1 || set "HAVE_WINGET=0"
if "%HAVE_WINGET%"=="0" echo [aviso] winget nao encontrado. Instalacoes automaticas podem falhar.

REM ===========================================================================
REM  1) Visual Studio 2022 (Build Tools, workload C++)
REM ===========================================================================
echo [1/8] Verificando Visual Studio 2022 (compilador C++)...
call :detect_vs
if not defined VS_PATH (
    echo      ... nao encontrado. Instalando Build Tools (pode demorar)...
    if "%HAVE_WINGET%"=="1" (
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended"
    )
    call :detect_vs
)
if not defined VS_PATH (
    echo [ERRO] Visual Studio / Build Tools com C++ nao encontrado.
    echo        Instale "Desktop development with C++" e rode novamente.
    goto :fail
)
echo      OK: %VS_PATH%

REM ===========================================================================
REM  2) CMake
REM ===========================================================================
echo [2/8] Verificando CMake...
if exist "%ProgramFiles%\CMake\bin\cmake.exe" set "PATH=%ProgramFiles%\CMake\bin;%PATH%"
where cmake >nul 2>&1
if errorlevel 1 (
    echo      ... instalando CMake...
    if "%HAVE_WINGET%"=="1" winget install --id Kitware.CMake -e --accept-source-agreements --accept-package-agreements
    if exist "%ProgramFiles%\CMake\bin\cmake.exe" set "PATH=%ProgramFiles%\CMake\bin;%PATH%"
)
where cmake >nul 2>&1 || ( echo [ERRO] CMake indisponivel nesta sessao. Reabra o terminal e rode de novo. & goto :fail )
echo      OK

REM ===========================================================================
REM  3) Python + aqtinstall  (apenas se QT_DIR nao foi fornecido)
REM ===========================================================================
echo [3/8] Verificando Qt %QT_VERSION% ...
if defined QT_DIR if exist "%QT_DIR%\bin\windeployqt.exe" goto :qt_ok
if exist "%QT_INSTALL_ROOT%\%QT_VERSION%\%QT_KIT%\bin\windeployqt.exe" (
    set "QT_DIR=%QT_INSTALL_ROOT%\%QT_VERSION%\%QT_KIT%"
    goto :qt_ok
)

echo      ... Qt nao encontrado. Preparando aqtinstall (precisa de Python)...
set "PYCMD="
where py >nul 2>&1 && set "PYCMD=py -3"
if not defined PYCMD ( where python >nul 2>&1 && set "PYCMD=python" )
if not defined PYCMD (
    if "%HAVE_WINGET%"=="1" winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    where py >nul 2>&1 && set "PYCMD=py -3"
)
if not defined PYCMD ( echo [ERRO] Python indisponivel nesta sessao. Reabra o terminal e rode de novo. & goto :fail )

echo      ... instalando aqtinstall...
%PYCMD% -m pip install --upgrade pip >nul
%PYCMD% -m pip install --upgrade aqtinstall
echo      ... baixando Qt %QT_VERSION% (%QT_ARCH%). Isso demora alguns minutos...
%PYCMD% -m aqt install-qt windows desktop %QT_VERSION% %QT_ARCH% -O "%QT_INSTALL_ROOT%"
set "QT_DIR=%QT_INSTALL_ROOT%\%QT_VERSION%\%QT_KIT%"

:qt_ok
if not exist "%QT_DIR%\bin\windeployqt.exe" (
    echo [ERRO] Qt nao encontrado em "%QT_DIR%".
    echo        Defina QT_DIR para a pasta do kit msvc (ex.: C:\Qt\6.5.3\msvc2019_64).
    goto :fail
)
echo      OK: %QT_DIR%

REM ===========================================================================
REM  4) NSIS (opcional - para gerar o instalador)
REM ===========================================================================
echo [4/8] Verificando NSIS...
if exist "%ProgramFiles(x86)%\NSIS\makensis.exe" set "PATH=%ProgramFiles(x86)%\NSIS;%PATH%"
where makensis >nul 2>&1
if errorlevel 1 (
    if "%HAVE_WINGET%"=="1" winget install --id NSIS.NSIS -e --accept-source-agreements --accept-package-agreements
    if exist "%ProgramFiles(x86)%\NSIS\makensis.exe" set "PATH=%ProgramFiles(x86)%\NSIS;%PATH%"
)
where makensis >nul 2>&1 && (echo      OK) || (echo      [aviso] NSIS ausente - o instalador sera pulado.)

REM ===========================================================================
REM  5) libMPV (dev: headers + import lib + dll)
REM ===========================================================================
echo [5/8] Verificando libMPV...
if defined MPV_ROOT if exist "%MPV_ROOT%\include\mpv\client.h" if exist "%MPV_ROOT%\lib\mpv.lib" goto :mpv_ok
set "MPV_ROOT=%THIRD%\mpv"
if exist "%MPV_ROOT%\include\mpv\client.h" if exist "%MPV_ROOT%\lib\mpv.lib" goto :mpv_ok

REM 7-Zip para extrair o pacote .7z
set "SEVENZIP="
where 7z >nul 2>&1 && set "SEVENZIP=7z"
if not defined SEVENZIP if exist "%ProgramFiles%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
if not defined SEVENZIP (
    if "%HAVE_WINGET%"=="1" winget install --id 7zip.7zip -e --accept-source-agreements --accept-package-agreements
    if exist "%ProgramFiles%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
)
if not defined SEVENZIP ( echo [ERRO] 7-Zip necessario para extrair a libmpv. & goto :mpv_manual )

mkdir "%THIRD%" 2>nul
mkdir "%MPV_ROOT%" 2>nul
set "MPV_7Z=%THIRD%\mpv-dev.7z"
echo      ... baixando libmpv-dev...
curl -L --fail -o "%MPV_7Z%" "%MPV_DEV_URL%"
if not exist "%MPV_7Z%" ( echo [ERRO] Falha ao baixar a libmpv-dev. & goto :mpv_manual )

echo      ... extraindo...
"%SEVENZIP%" x -y -o"%MPV_ROOT%\raw" "%MPV_7Z%" >nul

set "MPV_DEF="
for /r "%MPV_ROOT%\raw" %%f in (*.def) do set "MPV_DEF=%%f"
set "MPV_DLL_SRC="
for /r "%MPV_ROOT%\raw" %%f in (libmpv-2.dll) do set "MPV_DLL_SRC=%%f"

if exist "%MPV_ROOT%\raw\include" xcopy /e /i /y "%MPV_ROOT%\raw\include" "%MPV_ROOT%\include" >nul
if not exist "%MPV_ROOT%\include\mpv\client.h" ( echo [ERRO] headers da mpv nao encontrados no pacote. & goto :mpv_manual )
if not defined MPV_DEF ( echo [ERRO] arquivo .def da mpv nao encontrado no pacote. & goto :mpv_manual )

echo      ... gerando import lib (mpv.lib) com lib.exe...
mkdir "%MPV_ROOT%\lib" 2>nul
call "%VS_PATH%\VC\Auxiliary\Build\vcvars64.bat" >nul
lib /def:"%MPV_DEF%" /name:libmpv-2.dll /out:"%MPV_ROOT%\lib\mpv.lib" /machine:x64
if not exist "%MPV_ROOT%\lib\mpv.lib" ( echo [ERRO] Falha ao gerar mpv.lib. & goto :mpv_manual )

if defined MPV_DLL_SRC copy /y "%MPV_DLL_SRC%" "%MPV_ROOT%\libmpv-2.dll" >nul

:mpv_ok
set "MPV_DLL=%MPV_ROOT%\libmpv-2.dll"
if not exist "%MPV_DLL%" for /r "%MPV_ROOT%" %%f in (libmpv-2.dll) do set "MPV_DLL=%%f"
echo      OK: %MPV_ROOT%

REM ===========================================================================
REM  6) Configurar + compilar
REM ===========================================================================
echo [6/8] Configurando e compilando (Release)...
cmake -S . -B "%BUILD_DIR%" -G "Visual Studio 17 2022" -A x64 -DCMAKE_PREFIX_PATH="%QT_DIR%" -DMPV_ROOT="%MPV_ROOT%"
if errorlevel 1 ( echo [ERRO] Falha no cmake configure. & goto :fail )
cmake --build "%BUILD_DIR%" --config Release
if errorlevel 1 ( echo [ERRO] Falha na compilacao. & goto :fail )

set "OUT=%BUILD_DIR%\Release"
if not exist "%OUT%\SwiftIPTV.exe" set "OUT=%BUILD_DIR%"
if not exist "%OUT%\SwiftIPTV.exe" ( echo [ERRO] SwiftIPTV.exe nao foi gerado. & goto :fail )
echo      OK

REM ===========================================================================
REM  7) windeployqt + copiar DLLs + smoke test
REM ===========================================================================
echo [7/8] Deploy do Qt (windeployqt)...
"%QT_DIR%\bin\windeployqt.exe" --release --qmldir qml "%OUT%\SwiftIPTV.exe"
if errorlevel 1 echo      [aviso] windeployqt retornou erro - verifique a saida acima.

if exist "%MPV_DLL%" copy /y "%MPV_DLL%" "%OUT%\" >nul && echo      libmpv-2.dll copiada.
if not exist "%OUT%\libmpv-2.dll" echo      [aviso] libmpv-2.dll NAO encontrada - o app nao abrira sem ela.
copy /y "smoke_test.m3u" "%OUT%\" >nul 2>&1

REM ===========================================================================
REM  8) Instalador NSIS
REM ===========================================================================
echo [8/8] Gerando instalador (setup.exe)...
where makensis >nul 2>&1
if errorlevel 1 (
    echo      [aviso] NSIS ausente - pulando geracao do setup.exe.
) else (
    makensis installer.nsi
    if exist "SwiftIPTV-Setup.exe" ( echo      OK: SwiftIPTV-Setup.exe ) else ( echo      [aviso] Instalador nao foi gerado. )
)

echo.
echo ===========================================================
echo   CONCLUIDO!
echo   Executavel: %OUT%\SwiftIPTV.exe
if exist "SwiftIPTV-Setup.exe" echo   Instalador: %~dp0SwiftIPTV-Setup.exe
echo   Teste rapido: rode  run_smoke_test.bat  (3 canais de teste)
echo ===========================================================
if "%NEED_RESTART%"=="1" echo [nota] Algumas dependencias podem exigir reabrir o terminal.
echo.

explorer "%OUT%"
pause
exit /b 0

REM ===========================================================================
REM  Subrotinas
REM ===========================================================================
:detect_vs
set "VS_PATH="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto :eof
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_PATH=%%i"
goto :eof

:mpv_manual
echo.
echo --------------------------------------------------------------------
echo  LIBMPV MANUAL:
echo   1) Baixe "mpv-dev-x86_64-*.7z" (shinchiro / SourceForge mpv-player-windows).
echo   2) Extraia em uma pasta, por ex. C:\libs\mpv (deve conter include\mpv\client.h).
echo   3) Abra "x64 Native Tools Command Prompt for VS 2022" nessa pasta e rode:
echo        lib /def:mpv.def /name:libmpv-2.dll /out:lib\mpv.lib /machine:x64
echo   4) Rode:  set MPV_ROOT=C:\libs\mpv  e  install.bat  de novo.
echo --------------------------------------------------------------------
goto :fail

:fail
echo.
echo *** Processo interrompido. Veja as mensagens acima. ***
pause
exit /b 1
