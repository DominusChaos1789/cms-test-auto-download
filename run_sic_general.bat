@echo off
setlocal enabledelayedexpansion

rem =========================================================
rem Ajuste las 3 rutas y el patron de archivo si es necesario.
rem Se ejecutan en orden: Carpeta 1 completa, luego Carpeta 2, luego Carpeta 3.
rem =========================================================

set "CARPETA1=C:\CMS_Scripts\1_intervalos_llamadas"
set "CARPETA2=C:\CMS_Scripts\2_login_logout"
set "CARPETA3=C:\CMS_Scripts\3_roif_mensual"

set "LOG=%~dp0run_log.txt"
set "ESPERA=20"

echo ============================================== >> "%LOG%"
echo %date% %time% - INICIO EJECUCION >> "%LOG%"

taskkill /F /IM ACSApp.exe >nul 2>&1

call :EjecutarCarpeta "%CARPETA1%"
call :EjecutarCarpeta "%CARPETA2%"
call :EjecutarCarpeta "%CARPETA3%"

echo %date% %time% - FIN EJECUCION >> "%LOG%"
goto :fin

:EjecutarCarpeta
set "RUTA=%~1"
echo %date% %time% - Entrando a carpeta: %RUTA% >> "%LOG%"

if not exist "%RUTA%" (
    echo %date% %time% - ERROR: no existe la ruta %RUTA% >> "%LOG%"
    goto :eof
)

for %%F in ("%RUTA%\*.acsauto") do (
    echo %date% %time% - inicio "%%~nxF" >> "%LOG%"
    "%%~fF"
    timeout /t %ESPERA% /nobreak >nul
    echo %date% %time% - fin "%%~nxF" >> "%LOG%"
)

taskkill /F /IM ACSApp.exe >nul 2>&1
goto :eof

:fin
endlocal
