@echo off
setlocal enabledelayedexpansion

rem =========================================================
rem Lanzador CMS Supervisor - variante "nexa-ods-sync".
rem Ejecuta cada .acsauto EN ORDEN, nunca en paralelo, con limpieza
rem de proceso antes/despues de cada uno para evitar sobrecargar
rem el servidor CMS Avaya.
rem
rem Al terminar los 3 scripts, MUEVE (copia y luego borra el origen)
rem los archivos exportados hacia el servidor Nexa/ODS, replicando
rem el nombre de cada carpeta de origen como subcarpeta del destino.
rem Esta variante ya no exporta a WFM (Intervalos) ni a la copia ETL
rem (ROIF/Adherencia), asi que solo hay una carpeta de origen por reporte.
rem
rem Ajuste CARPETA y la lista de scripts si cambia la ubicacion.
rem =========================================================

set "CARPETA=C:\CMS_Scripts"
set "LOG=%~dp0run_log.txt"
set "ESPERA=60"

set "SCRIPTS=1_Intervalos_Merged.acsauto 2_ROIF_Mensual_Merged.acsauto 3_Adherencia_Merged.acsauto"

rem Carpeta destino en el servidor Nexa/ODS. Cada carpeta de origen se
rem replica debajo con el mismo nombre.
set "DEST_ROOT=<NEXA_SYNC_DEST_ROOT>"

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

echo %date% %time% - INICIO MOVIMIENTO A NEXA/ODS >> "%LOG%"

rem --- Intervalos / DEO ---
robocopy "\\<FILE_SERVER_IP>\AdminInfo\<CLIENT>\13. LOG" "%DEST_ROOT%\13. LOG" /MOV /E /R:2 /W:5 >> "%LOG%" 2>&1
robocopy "\\<FILE_SERVER_IP>\AdminInfo\<CLIENT>\INTERVALOS" "%DEST_ROOT%\INTERVALOS" /MOV /E /R:2 /W:5 >> "%LOG%" 2>&1
robocopy "\\<FILE_SERVER_IP>\AdminInfo\<CLIENT>\16. DEO" "%DEST_ROOT%\16. DEO" /MOV /E /R:2 /W:5 >> "%LOG%" 2>&1

rem --- ROIF Mensual ---
robocopy "\\<FILE_SERVER_IP>\AdminInfo\<CLIENT>\12. ROIF MENSUAL" "%DEST_ROOT%\12. ROIF MENSUAL" /MOV /E /R:2 /W:5 >> "%LOG%" 2>&1

rem --- Adherencia ---
robocopy "\\<FILE_SERVER_IP>\AdminInfo\<CLIENT>\08. ADHERENCIA CLARO SAC" "%DEST_ROOT%\08. ADHERENCIA CLARO SAC" /MOV /E /R:2 /W:5 >> "%LOG%" 2>&1
robocopy "\\<FILE_SERVER_IP>\AdminInfo\<CLIENT>\15. ADHERENCIA CLARO EMPRESAS" "%DEST_ROOT%\15. ADHERENCIA CLARO EMPRESAS" /MOV /E /R:2 /W:5 >> "%LOG%" 2>&1

echo %date% %time% - FIN MOVIMIENTO A NEXA/ODS >> "%LOG%"
echo %date% %time% - FIN EJECUCION >> "%LOG%"
endlocal
