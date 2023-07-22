@ECHO OFF

rem Convert (load) 1C configuration from 1C:EDT format to 1C configuration file (*.cf)
rem %1 - path to folder contains configuration files in 1C:EDT format
rem %2 - path to 1C configuration file (*.cf)
rem %3 - convertion tool to use:
rem      ibcmd - ibcmd tool (default)
rem      designer - batch run of 1C:Designer

IF not defined V8_VERSION set V8_VERSION=8.3.20.2290
IF not defined V8_TEMP set V8_TEMP=%TEMP%\1c

set V8_TOOL="C:\Program Files\1cv8\%V8_VERSION%\bin\1cv8.exe"
set IBCMD_TOOL="C:\Program Files\1cv8\%V8_VERSION%\bin\ibcmd.exe"
FOR /F "usebackq tokens=1 delims=" %%i IN (`where ring`) DO (
    set RING_TOOL="%%i"
)

set IB_PATH=%V8_TEMP%\tmp_db
set XML_PATH=%V8_TEMP%\tmp_xml
set WS_PATH=%V8_TEMP%\edt_ws

set CONFIG_PATH=%1
IF defined CONFIG_PATH set CONFIG_PATH=%CONFIG_PATH:"=%
set CONFIG_FILE=%2
IF defined CONFIG_FILE (
    set CONFIG_FILE=%CONFIG_FILE:"=%
    set CONFIG_FILE_PATH=%~dp2
)
set CONV_TOOL=%3
IF defined CONV_TOOL (
    set CONV_TOOL=%CONV_TOOL:"=%
) ELSE set CONV_TOOL=ibcmd

IF not defined CONFIG_PATH (
    echo Missed parameter 1 "path to folder contains configuration files in 1C:EDT format"
    exit /b 1
)
IF not defined CONFIG_FILE (
    echo Missed parameter 2 "path to 1C configuration file (*.cf)"
    exit /b 1
)

echo Clear temporary files...
IF exist "%V8_TEMP%" rd /S /Q "%V8_TEMP%"
md "%V8_TEMP%"
md "%IB_PATH%"
md "%XML_PATH%"
md "%WS_PATH%"
IF not exist "%CONFIG_FILE_PATH%" md "%CONFIG_FILE_PATH%"

echo Export "%CONFIG_PATH%" to 1C:Designer XML format "%XML_PATH%"...
call %RING_TOOL% edt workspace export --project "%CONFIG_PATH%" --configuration-files "%XML_PATH%" --workspace-location "%WS_PATH%"

IF "%CONV_TOOL%" equ "designer" (
    echo Creating infobase "%IB_PATH%"...
    %V8_TOOL% CREATEINFOBASE File=%IB_PATH%; /DisableStartupDialogs

    echo Loading infobase "%IB_PATH%" configuration from XML-files "%XML_PATH%"...
    %V8_TOOL% DESIGNER /IBConnectionString File=%IB_PATH%; /DisableStartupDialogs /LoadConfigFromFiles %XML_PATH%
) ELSE (
    echo Creating infobase "%IB_PATH%" with configuration from XML-files "%XML_PATH%"...
    %IBCMD_TOOL% infobase create --db-path="%IB_PATH%" --create-database --import="%XML_PATH%"
)

echo Export infobase "%IB_PATH%" configuration to "%CONFIG_FILE%"...
IF "%CONV_TOOL%" equ "designer" (
    %V8_TOOL% DESIGNER /IBConnectionString File=%IB_PATH%; /DisableStartupDialogs /DumpCfg %CONFIG_FILE%
) ELSE (
    %IBCMD_TOOL% infobase config save --db-path="%IB_PATH%" "%CONFIG_FILE%"
)

echo Clear temporary files...
IF exist "%V8_TEMP%" rd /S /Q "%V8_TEMP%"
