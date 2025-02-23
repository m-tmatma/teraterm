﻿chcp 65001 >nul
@echo off

rem folder は、patch を実行する .. から見た相対パス
set folder=openssl_patch

set cmdopt2=--binary --backup -p0
set cmdopt1=--dry-run %cmdopt2%


rem パッチコマンドの存在チェック
rem ..\%folder%\patch.exe, PATHが通っているpatch の優先順
pushd ..
set patchcmd="%folder%\patch.exe"
if exist %patchcmd% (
    popd
    goto cmd_true
)
popd

set patchcmd=patch
%patchcmd% -v
if %errorlevel% == 0 (goto cmd_true) else goto cmd_false

:cmd_true


:patch1
rem freeaddrinfo/getnameinfo/getaddrinfo API(WindowsXP以降)依存除去のため
findstr /c:"# undef AI_PASSIVE" ..\openssl\crypto\bio\bio_local.h
if ERRORLEVEL 1 goto fail1
goto patch2
:fail1
pushd ..
%patchcmd% %cmdopt1% < %folder%\ws2_32_dll_patch2.txt
%patchcmd% %cmdopt2% < %folder%\ws2_32_dll_patch2.txt
popd

:patch2
:patch3
:patch4


:patch5
rem WindowsMeでRAND_bytesで落ちる現象回避のため。
rem OpenSSL 1.0.2ではmethのNULLチェックがあったが、OpenSSL 1.1.1でなくなっている。
rem このNULLチェックはなくても問題はなく、本質はInitializeCriticalSectionAndSpinCountにあるため、
rem デフォルトでは適用しないものとする。
rem findstr /c:"added if meth is NULL pointer" ..\openssl\crypto\rand\rand_lib.c
rem if ERRORLEVEL 1 goto fail5
rem goto patch6
rem :fail5
rem pushd ..
rem %patchcmd% %cmdopt1% < %folder%\RAND_bytes.txt
rem %patchcmd% %cmdopt2% < %folder%\RAND_bytes.txt
rem popd


:patch6
rem WindowsMeでInitializeCriticalSectionAndSpinCountがエラーとなる現象回避のため。
findstr /c:"myInitializeCriticalSectionAndSpinCount" ..\openssl\crypto\threads_win.c
if ERRORLEVEL 1 goto fail6
goto patch7
:fail6
pushd ..
%patchcmd% %cmdopt1% < %folder%\atomic_api.txt
%patchcmd% %cmdopt2% < %folder%\atomic_api.txt
popd


:patch7
rem Windows98/Me/NT4.0ではCryptAcquireContextWによるエントロピー取得が
rem できないため、新しく処理を追加する。CryptAcquireContextWの利用は残す。
findstr /c:"CryptAcquireContextA" ..\openssl\crypto\rand\rand_win.c
if ERRORLEVEL 1 goto fail7
goto patch8
:fail7
pushd ..
%patchcmd% %cmdopt1% < %folder%\CryptAcquireContextW2.txt
%patchcmd% %cmdopt2% < %folder%\CryptAcquireContextW2.txt
popd


:patch8
rem Windows95では InterlockedCompareExchange と InterlockedCompareExchange が
rem 未サポートのため、別の処理で置き換える。
rem InitializeCriticalSectionAndSpinCount も未サポートだが、WindowsMe向けの
rem 処置に含まれる。
findstr /c:"INTERLOCKEDCOMPAREEXCHANGE" ..\openssl\crypto\threads_win.c
if ERRORLEVEL 1 goto fail8
goto patch9
:fail8
pushd ..
copy /b openssl\crypto\threads_win.c.orig openssl\crypto\threads_win.c.orig2
%patchcmd% %cmdopt1% < %folder%\atomic_api_win95.txt
%patchcmd% %cmdopt2% < %folder%\atomic_api_win95.txt
popd


rem Windows95では CryptAcquireContextW が未サポートのため、エラーで返すようにする。
rem エラー後は CryptAcquireContextA を使う。
:patch9
findstr /c:"myCryptAcquireContextW" ..\openssl\crypto\rand\rand_win.c
if ERRORLEVEL 1 goto fail9
goto patch10
:fail9
pushd ..
copy /b openssl\crypto\rand\rand_win.c.orig openssl\crypto\rand\rand_win.c.orig2
%patchcmd% %cmdopt1% < %folder%\CryptAcquireContextW_win95.txt
%patchcmd% %cmdopt2% < %folder%\CryptAcquireContextW_win95.txt
popd


:patch10


:patch_main_conf
rem 設定ファイルのバックアップを取る
if not exist "..\openssl\Configurations\10-main.conf.orig" (
    copy /y ..\openssl\Configurations\10-main.conf ..\openssl\Configurations\10-main.conf.orig
)

rem VS2005だと警告エラーでコンパイルが止まる問題への処置
perl -e "open(IN,'..\openssl\Configurations/10-main.conf');binmode(STDOUT);while(<IN>){s|/W3|/W1|;s|/WX||;print $_;}close(IN);" > conf.tmp
move conf.tmp ..\openssl\Configurations/10-main.conf

rem GetModuleHandleExW API(WindowsXP以降)依存除去のため
perl -e "open(IN,'..\openssl\Configurations/10-main.conf');binmode(STDOUT);while(<IN>){s|(dso_scheme(.+)"win32")|#$1|;print $_;}close(IN);" > conf.tmp
move conf.tmp ..\openssl\Configurations/10-main.conf

rem Debug buildのwarning LNK4099対策(Workaround)
perl -e "open(IN,'..\openssl\Configurations/10-main.conf');binmode(STDOUT);while(<IN>){s|/Zi|/Z7|;s|/WX||;print $_;}close(IN);" > conf.tmp
move conf.tmp ..\openssl\Configurations/10-main.conf


:patch_end
echo "パッチは適用されています"
goto end


:patchfail
echo "パッチが適用されていないようです"
set /P ANS="続行しますか？(y/n)"
if "%ANS%"=="y" (
    goto end
) else if "%ANS%"=="n" (
    echo "apply_patch.bat を終了します"
    exit /b 1
)
goto end


:cmd_false
echo パッチコマンドが見つかりません
echo 下記サイトからダウンロードして、..\%folder% に Git-x.xx.x-32-bit.tar.bz2 内の
echo patch.exe, msys-gcc_s-1.dll, msys-2.0.dll を配置してください
echo https://github.com/git-for-windows/git/releases/latest
echo.
goto patchfail


:end
@echo on
