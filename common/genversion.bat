@ECHO OFF
SETLOCAL

PUSHD "%~dp0"

IF EXIST "..\..\..\..\..\build.user.bat" CALL "..\..\..\..\..\build.user.bat"

IF NOT DEFINED MPCHC_GIT     IF DEFINED GIT     (SET MPCHC_GIT=%GIT%)
IF NOT DEFINED MPCHC_MSYS    IF DEFINED MSYS    (SET MPCHC_MSYS=%MSYS%)       ELSE (GOTO MissingVar)

IF NOT EXIST "%MPCHC_MSYS%"    GOTO MissingVar

SET PATH=%MPCHC_MSYS%\bin;%MPCHC_GIT%\cmd;%PATH%
FOR %%G IN (bash.exe) DO (SET FOUND=%%~$PATH:G)
IF NOT DEFINED FOUND GOTO MissingVar

bash.exe ./version.sh


:END
POPD
ENDLOCAL
EXIT /B


:MissingVar
ECHO Not all build dependencies were found.
ECHO.
ECHO See "..\..\..\..\..\docs\Compilation.md" for more information.
ENDLOCAL
EXIT /B 1
