﻿chcp 65001 >nul
echo %~dp0\install_linkchecker.bat

pushd %~dp0

if "%CMAKE_COMMAND%" == "" (
   call ..\ci_scripts\find_cmake.bat
)

"%CMAKE_COMMAND%" -P install_linkchecker.cmake

popd

if not "%NOPAUSE%" == "1" pause
