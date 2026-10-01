@echo off
setlocal enabledelayedexpansion

rem =========================================================
rem Lanzador CMS Supervisor - version "un script por grupo de reporte".
rem Ejecuta cada .acsauto EN ORDEN, nunca en paralelo, con limpieza
rem de proceso antes/despues de cada uno para evitar sobrecargar
rem el servidor CMS Avaya.
rem
rem Ajuste CARPETA y la lista de scripts si cambia la ubicacion.
rem =========================================================

set "CARPETA=C:\CMS_Scripts"
set "LOG=%~dp0run_log.txt"
set "ESPERA=60"

set "SCRIPTS=1_Intervalos_Merged.acsauto 2_ROIF_Mensual_Merged.acsauto 3_Adherencia_Merged.acsauto"

echo ============================================== >> "%LOG%"
echo %date% %time% - INICIO EJECUCION >> "%LOG%"

taskkill /F /IM ACSApp.exe >nul 2>&1

for %%S in (%SCRIPTS%) do (
    set "RUTA=%CARPETA%\%%S"
    if exist "!RUTA!" (
        echo %date% %time% - inicio "%%S" >> "%LOG%"
        "!RUTA!"
        echo %date% %time% - fin "%%S" >> "%LOG%"
        taskkill /F /IM ACSApp.exe >nul 2>&1
        timeout /t %ESPERA% /nobreak >nul
    ) else (
        echo %date% %time% - ERROR: no existe !RUTA! >> "%LOG%"
    )
)

echo %date% %time% - FIN EJECUCION >> "%LOG%"
endlocal
