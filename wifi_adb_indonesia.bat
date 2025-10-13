@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d %~dp0

:: ============================================================
::  wifi_adb.bat  —  Kotak Perkakas ADB Wi-Fi (all-in-one)
::  - setup      : aktifkan ADB via Wi-Fi untuk perangkat USB + inventaris JSON
::  - connect    : pilih dari daftar / IP manual, lalu jalankan scrcpy (preset + ekstra)
::  - list       : gabungkan & tampilkan perangkat dari JSON + status ADB
::  - usb-back   : kembalikan semua perangkat TCP ke mode USB
::  - disconnect : putus semua koneksi TCP ADB
::  - pair       : pairing ADB Wireless debugging (Android 11+)
:: ============================================================

set "FILE_SETUP=wifi_device_setup.json"
set "FILE_CONN=wifi_device_connect.json"

call :UI_INIT

:: ---------------- Pastikan ADB tersedia ----------------
:CHECK_ADB
where adb >nul 2>&1
if errorlevel 1 (
  title ADB tidak ditemukan
  echo %C_ERR%[KESALAHAN]%C_RST% adb tidak ditemukan di PATH
  echo Pasang "Android Platform Tools" dan tambahkan adb ke PATH
  echo Mencoba lagi dalam 5 detik - Tekan Ctrl+C untuk membatalkan
  timeout /t 5 >nul
  goto :CHECK_ADB
)
adb start-server >nul 2>&1

:: ---------------- Arahkan berdasarkan argumen -----------------
if /i "%~1"==""         goto :MAIN_MENU
if /i "%~1"=="help"     goto :MAIN_MENU
if /i "%~1"=="setup"    goto :CMD_SETUP
if /i "%~1"=="connect"  goto :CMD_CONNECT
if /i "%~1"=="list"     goto :CMD_LIST
if /i "%~1"=="usb-back" goto :CMD_USBBACK
if /i "%~1"=="disconnect" goto :CMD_DISCONNECT_ALL
if /i "%~1"=="pair"     goto :CMD_PAIR

echo Perintah tidak dikenal: %~1
echo Cara pakai: %~nx0 ^<setup^|connect^|list^|usb-back^|disconnect^|pair^|help^>
exit /b 1

:: ---------------- Menu utama ------------------------
:MAIN_MENU
title Kotak Perkakas ADB Wi-Fi
cls
call :UI_BAR
echo %C_TITLE%   A D B   W i - F i   T o o l b o x%C_RST%
call :UI_BAR
echo  %C_NUM%[1]%C_RST% %C_LBL%Setup   %C_DIM%: Aktifkan ADB via Wi-Fi (USB) + simpan ke %FILE_SETUP%%C_RST%
echo  %C_NUM%[2]%C_RST% %C_LBL%Connect %C_DIM%: Pilih dari daftar / IP manual → preset scrcpy + ekstra%C_RST%
echo  %C_NUM%[3]%C_RST% %C_LBL%List    %C_DIM%: Tampilkan perangkat dikenal (dari JSON) + status ADB%C_RST%
echo  %C_NUM%[4]%C_RST% %C_LBL%USB-Back All%C_DIM%: Kembalikan semua perangkat TCP ke USB%C_RST%
echo  %C_NUM%[5]%C_RST% %C_LBL%Disconnect All%C_DIM%: adb disconnect (semua endpoint)%C_RST%
echo  %C_NUM%[6]%C_RST% %C_LBL%Pair    %C_DIM%: Pairing debugging nirkabel (Android 11+)%C_RST%
echo  %C_NUM%[0]%C_RST% %C_LBL%Keluar%C_RST%
call :UI_BAR
set "m="
set /p m="%C_ASK%Pilih:%C_RST% "
if "%m%"=="1" goto :CMD_SETUP
if "%m%"=="2" goto :CMD_CONNECT
if "%m%"=="3" goto :CMD_LIST
if "%m%"=="4" goto :CMD_USBBACK
if "%m%"=="5" goto :CMD_DISCONNECT_ALL
if "%m%"=="6" goto :CMD_PAIR
if "%m%"=="0" exit /b 0
goto :MAIN_MENU

:: =========================================================
::  SETUP — Aktifkan ADB Wi-Fi untuk semua perangkat USB + inventaris
:: =========================================================
:CMD_SETUP
title Penyiapan ADB Wi-Fi - simpan ke %FILE_SETUP%
echo.
echo %C_H1%=== Aktifkan ADB via Wi-Fi untuk SEMUA perangkat USB ===%C_RST%
echo Info perangkat akan disimpan ke "%FILE_SETUP%"
echo Tekan Ctrl+C kapan saja untuk membatalkan.
echo.

if not exist "%FILE_SETUP%" ( >"%FILE_SETUP%" echo [] )

:WAIT_USB
set "COUNT=0"
for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (
  if "%%B"=="device" (
    echo %%A | findstr ":" >nul
    if errorlevel 1 (
      set /a COUNT+=1
      set "SERIAL[!COUNT!]=%%A"
    )
  )
)
if %COUNT%==0 (
  echo %C_NOTE%[USB] Menunggu perangkat USB dengan status device ... pastikan USB debugging AKTIF%C_RST%
  timeout /t 2 >nul
  goto :WAIT_USB
)

set "SEEN_IPS= "
set "DUP_IP="
for /l %%I in (1,1,%COUNT%) do (
  set "SER=!SERIAL[%%I]!"
  echo.
  call :UI_SEP
  echo Inisialisasi %%I/%COUNT%%  SERIAL: !SER!
  set "USBSTATE="
  for /f "usebackq delims=" %%s in (`adb -s !SER! get-state 2^>nul`) do set "USBSTATE=%%s"

  set "MODEL=" & set "BRAND=" & set "DEVNAME=" & set "VER=" & set "SDK="
  set "SIZE="  & set "DPI="   & set "BATT="    & set "SSID_CUR=" & set "IP_CUR=" & set "ENDP_CUR="

  if /i "!USBSTATE!"=="device" (
    adb -s !SER! tcpip 5555 >nul 2>&1
    adb -s !SER! wait-for-device >nul 2>&1

    call :GET_WIFI_IP "!SER!" IP_CUR

    for /f "usebackq delims=" %%M in (`adb -s !SER! shell getprop ro.product.model 2^>nul`) do if not defined MODEL set "MODEL=%%M"
    for /f "usebackq delims=" %%B in (`adb -s !SER! shell getprop ro.product.brand 2^>nul`) do if not defined BRAND set "BRAND=%%B"
    for /f "usebackq delims=" %%V in (`adb -s !SER! shell getprop ro.build.version.release 2^>nul`) do if not defined VER set "VER=%%V"
    for /f "usebackq delims=" %%K in (`adb -s !SER! shell getprop ro.build.version.sdk 2^>nul`) do if not defined SDK set "SDK=%%K"
    for /f "usebackq delims=" %%D in (`adb -s !SER! shell getprop ro.product.device 2^>nul`) do if not defined DEVNAME set "DEVNAME=%%D"

    for /f "tokens=1,* delims=:" %%a in ('adb -s !SER! shell wm size 2^>nul ^| findstr /c:"Physical size"') do set "SIZE=%%b"
    for /f "tokens=* delims= " %%z in ("!SIZE!") do set "SIZE=%%z"
    for /f "tokens=1,* delims=:" %%a in ('adb -s !SER! shell wm density 2^>nul ^| findstr /c:"Physical density"') do set "DPI=%%b"
    for /f "tokens=* delims= " %%z in ("!DPI!") do set "DPI=%%z"

    for /f "tokens=1,* delims=:" %%a in ('adb -s !SER! shell dumpsys battery 2^>nul ^| findstr /r "^ *level:"') do set "BATT=%%b"
    for /f "tokens=* delims= " %%z in ("!BATT!") do set "BATT=%%z"

    for /f "tokens=1,* delims=:" %%a in ('adb -s !SER! shell dumpsys wifi 2^>nul ^| findstr /c:"mWifiInfo SSID"') do if not defined SSID_CUR set "SSID_CUR=%%b"
    if not defined SSID_CUR (
      for /f "tokens=1,* delims=:" %%a in ('adb -s !SER! shell dumpsys wifi 2^>nul ^| findstr /c:"SSID"') do if not defined SSID_CUR set "SSID_CUR=%%b"
    )
    for /f "tokens=1 delims=," %%t in ("!SSID_CUR!") do set "SSID_CUR=%%t"
    for /f "tokens=* delims= " %%z in ("!SSID_CUR!") do set "SSID_CUR=%%z"
    set "SSID_CUR=!SSID_CUR:"=!"
    if /i "!SSID_CUR!"=="<unknown ssid>" set "SSID_CUR="
    if "!SSID_CUR!"=="=" set "SSID_CUR="

    if defined IP_CUR (
      set "ENDP_CUR=!IP_CUR!:5555"
      echo.!SEEN_IPS! | findstr /c:" !IP_CUR! " >nul && set "DUP_IP=1" || set "SEEN_IPS=!SEEN_IPS!!IP_CUR! "
      adb disconnect !ENDP_CUR! >nul 2>&1
      adb connect   !ENDP_CUR! >nul 2>&1
    )
  ) else (
    echo %C_ERR%[USB] Perangkat belum siap melalui USB saat ini%C_RST%
  )

  echo MEREK      : !BRAND!
  echo MODEL      : !MODEL!
  echo PERANGKAT  : !DEVNAME!
  echo ANDROID    : !VER!  SDK !SDK!
  if defined SIZE (echo RESOLUSI   : !SIZE!) else echo RESOLUSI   : tidak diketahui
  if defined DPI  (echo DPI        : !DPI!)  else echo DPI        : tidak diketahui
  if defined BATT (echo BATERAI    : !BATT!%%) else echo BATERAI    : tidak diketahui
  if defined SSID_CUR (echo SSID       : !SSID_CUR!) else echo SSID       : tidak tersedia
  if defined IP_CUR (
    echo IP_WIFI    : !IP_CUR!
    echo ADB_TCP    : !ENDP_CUR!
  ) else (
    echo IP_WIFI    : tidak tersedia
    echo ADB_TCP    : tidak tersedia
  )

  REM --- simpan per-index untuk ringkasan yang akurat ---
  set "MODEL_A[%%I]=!MODEL!"
  set "IP_A[%%I]=!IP_CUR!"
  set "EP_A[%%I]=!ENDP_CUR!"

  call :JFIELD BRAND      J_BRAND
  call :JFIELD MODEL      J_MODEL
  call :JFIELD DEVNAME    J_DEVICE
  call :JFIELD VER        J_ANDROID
  call :JFIELD SDK        J_SDK
  call :JFIELD SIZE       J_RES
  call :JFIELD DPI        J_DPI
  call :JFIELD BATT       J_BATT
  call :JFIELD SSID_CUR   J_SSID
  call :JFIELD IP_CUR     J_IP
  call :JFIELD ENDP_CUR   J_EP

  >__entry.tmp echo {"timestamp":"%date% %time%","serial":"!SER!","brand":!J_BRAND!,"model":!J_MODEL!,"device":!J_DEVICE!,"android":!J_ANDROID!,"sdk":!J_SDK!,"resolution":!J_RES!,"dpi":!J_DPI!,"battery":!J_BATT!,"ssid":!J_SSID!,"ip":!J_IP!,"endpoint":!J_EP!}
  call :JSON_APPEND_DEDUP "%FILE_SETUP%"
  del /q __entry.tmp >nul 2>&1
)

if defined DUP_IP (
  echo.
  echo %C_WARN%[PERINGATAN]%C_RST% IP Wi-Fi duplikat terdeteksi di antarmuka/perangkat.
  echo Gunakan satu SSID atau Windows Mobile Hotspot agar tiap perangkat mendapat IP unik.
)

echo.
echo %C_H1%===== RINGKASAN =====%C_RST%
echo  No  Serial               Model                  IP              Endpoint          Status
echo  --  -------------------- ---------------------- --------------- ----------------- -------
for /l %%I in (1,1,%COUNT%) do (
  set "SER=!SERIAL[%%I]!"
  set "MODEL=!MODEL_A[%%I]!"
  set "IPX=!IP_A[%%I]!"
  set "EPX=!EP_A[%%I]!"
  set "STATE=offline"
  if defined EPX (
    for /f "usebackq delims=" %%s in (`adb -s !EPX! get-state 2^>nul`) do set "STATE=%%s"
  )
  set "SERPAD=!SER!                    "
  set "SERPAD=!SERPAD:~0,20!"
  set "MODPAD=!MODEL!                  "
  set "MODPAD=!MODPAD:~0,22!"
  set "IPPAD=!IPX!           "
  set "IPPAD=!IPPAD:~0,15!"
  set "EPPAD=!EPX!            "
  set "EPPAD=!EPPAD:~0,17!"
  echo  %%I   !SERPAD! !MODPAD! !IPPAD! !EPPAD! !STATE!
)

echo.
echo Data disimpan ke "%FILE_SETUP%"
if /i "%~1"=="" (
  echo Tekan tombol apa saja untuk kembali ke menu...
  pause >nul
  goto :MAIN_MENU
) else exit /b 0

:: =========================================================
::  CONNECT — Pilih dari daftar/JSON atau IP manual → scrcpy
:: =========================================================
:CMD_CONNECT
title ADB Wi-Fi Connect + preset scrcpy
echo.
echo %C_H1%=== Sambungkan ke Android via ADB Wi-Fi dan jalankan scrcpy ===%C_RST%
echo 1) Pastikan ponsel dan PC pada SSID Wi-Fi yang sama
echo 2) ADB via Wi-Fi harus aktif (dari Setup atau Wireless debugging)
echo.

where scrcpy >nul 2>&1
if errorlevel 1 (
  echo %C_WARN%[PERINGATAN]%C_RST% scrcpy tidak ditemukan di PATH — kamu tetap bisa adb connect,
  echo tetapi mirroring layar tidak akan berjalan. Pasang scrcpy untuk mirroring.
)

set "ip="
set "TARGET="
call :OFFER_LIST_COMBINED
if not defined ip (
  set /p ip="Masukkan IP Android [bawaan 192.168.43.1] atau Tekan Enter untuk bawaan: "
  if "%ip%"=="" set "ip=192.168.43.1"
)
if not defined TARGET set "TARGET=%ip%:5555"


echo.
echo %C_LBL%[ADB]%C_RST% menghubungkan ke %TARGET% ...
adb disconnect %TARGET% >nul 2>&1
adb connect   %TARGET%

set "STATE="
for /f "usebackq delims=" %%s in (`adb -s %TARGET% get-state 2^>nul`) do set "STATE=%%s"
if /i not "%STATE%"=="device" (
  echo.
  echo %C_ERR%[KESALAHAN]%C_RST% Gagal terhubung sebagai "device". Status saat ini: "%STATE%"
  echo Periksa IP Wi-Fi, SSID, dan pastikan ADB via Wi-Fi aktif di ponsel.
  if /i "%~1"=="" (
    echo Tekan tombol apa saja untuk kembali...
    pause >nul & goto :MAIN_MENU
  ) else exit /b 2
)

call :PRINT_DEVICE_INFO "%TARGET%"
call :SAVE_CONNECT_JSON "%TARGET%"
call :CHECK_STAY_AWAKE_SUPPORT "%TARGET%"

:: Preset kualitas video
set "choice="
:PROMPT_PRESET
echo.
echo Pilih preset scrcpy:
echo   %C_NUM%[1]%C_RST% Rendah      : --video-bit-rate 2M   --max-size 800
echo   %C_NUM%[2]%C_RST% Bawaan      : --video-bit-rate 8M   --max-size 1080
echo   %C_NUM%[3]%C_RST% Tinggi      : --video-bit-rate 16M  --max-size 1440
echo   %C_NUM%[4]%C_RST% SangatTinggi: --video-bit-rate 24M  --max-size 1440
echo   %C_NUM%[5]%C_RST% Ultra       : --video-bit-rate 32M  --max-size 2160
echo   %C_NUM%[6]%C_RST% Ekstrem     : --video-bit-rate 64M  --max-size 2160
echo   %C_NUM%[7]%C_RST% SuperEkstrem: --video-bit-rate 72M  --max-size 2160
set /p choice="Masukkan 1-7: "
if "%choice%"=="1" (set "SCRCPY_OPTS=--video-bit-rate 2M --max-size 800") ^
else if "%choice%"=="2" (set "SCRCPY_OPTS=--video-bit-rate 8M --max-size 1080") ^
else if "%choice%"=="3" (set "SCRCPY_OPTS=--video-bit-rate 16M --max-size 1440") ^
else if "%choice%"=="4" (set "SCRCPY_OPTS=--video-bit-rate 24M --max-size 1440") ^
else if "%choice%"=="5" (set "SCRCPY_OPTS=--video-bit-rate 32M --max-size 2160") ^
else if "%choice%"=="6" (set "SCRCPY_OPTS=--video-bit-rate 64M --max-size 2160") ^
else if "%choice%"=="7" (set "SCRCPY_OPTS=--video-bit-rate 72M --max-size 2160") ^
else (echo Pilihan tidak valid. Coba lagi.& goto :PROMPT_PRESET)

if /i "!STAY_OK!"=="1" ( set "SCRCPY_OPTS=%SCRCPY_OPTS% --stay-awake" ) ^
else (
  echo.
  echo %C_NOTE%[CATATAN]%C_RST% "stay-awake" tidak diizinkan pada perangkat/ROM ini; melanjutkan tanpa opsi itu.
)

:: ====== EKSTRA (tombol UX modern; semua opsi resmi scrcpy) ======
echo.
echo %C_H1%Ekstra (opsional):%C_RST% Tekan Enter untuk lewati atau isi Y/N
set "yn="
set /p yn="Selalu di atas? (--always-on-top) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --always-on-top"
set "yn="
set /p yn="Jendela tanpa batas? (--window-borderless) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --window-borderless"
set "yn="
set /p yn="Layar penuh? (--fullscreen) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --fullscreen"
set "yn="
set /p yn="Bisukan audio? (--no-audio) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --no-audio"
set "yn="
set /p yn="Matikan layar perangkat? (-S/--turn-screen-off) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% -S"
set "yn="
set /p yn="Gunakan H.265/HEVC? (--video-codec=h265) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --video-codec=h265"
set "yn="
set /p yn="Batasi ke 60 fps? (--max-fps 60) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --max-fps 60"

set "ttl="
set /p ttl="Judul jendela kustom? (--window-title) [kosong = lewati]: "
if not "%ttl%"=="" set "SCRCPY_OPTS=%SCRCPY_OPTS% --window-title \"%ttl%\""

set "pos="
set /p pos="Atur X,Y,Lebar,Tinggi? (contoh: 100,80,900,1600) [lewati=Enter]: "
if not "%pos%"=="" (
  for /f "tokens=1-4 delims=," %%x in ("%pos%") do (
    set "SCRCPY_OPTS=%SCRCPY_OPTS% --window-x=%%x --window-y=%%y --window-width=%%z --window-height=%%w"
  )
)

set "yn="
set /p yn="Rekam ke MP4? (--record file.mp4) [y/N]: "
if /i "%yn%"=="y" (
  set "recfile="
  set /p recfile="  Nama file [bawaan record.mp4]: "
  if "%recfile%"=="" set "recfile=record.mp4"
  set "SCRCPY_OPTS=%SCRCPY_OPTS% --record \"%recfile%\""
)

echo.
echo Menjalankan scrcpy dengan:
echo   %SCRCPY_OPTS%

where scrcpy >nul 2>&1 && (
  scrcpy -s %TARGET% %SCRCPY_OPTS%
) || (
  echo.
  echo %C_INFO%[INFO]%C_RST% scrcpy tidak terpasang, melewati peluncuran mirroring.
)

if /i "%~1"=="" (echo.& echo Tekan tombol apa saja untuk kembali ke menu...& pause >nul& goto :MAIN_MENU) else exit /b 0

:: =========================================
::  LIST — Gabungkan file JSON & tampilkan status ADB (READ-ONLY, no PowerShell)
:: =========================================
:CMD_LIST
title Daftar perangkat dikenal (READ-ONLY)

echo.
echo %C_H1%=== Membaca daftar perangkat dari JSON (hanya baca) ===%C_RST%
set "SZ1=?"
set "SZ2=?"
if exist "%FILE_SETUP%" for %%F in ("%FILE_SETUP%") do set "SZ1=%%~zF"
if exist "%FILE_CONN%"  for %%F in ("%FILE_CONN%")  do set "SZ2=%%~zF"
echo   %C_DIM%Info file:%C_RST% %FILE_SETUP% (size=%SZ1%) ^| %FILE_CONN% (size=%SZ2%)

:: Bangun daftar gabungan TANPA PowerShell
del /q ip_list.tmp >nul 2>&1
call :BUILD_COMBINED_LIST "ip_list.tmp"

:: Jika tidak ada output, jatuh ke diagnostik
if not exist ip_list.tmp goto :LIST_FALLBACK
for %%# in (ip_list.tmp) do if "%%~z#"=="0" goto :LIST_FALLBACK
findstr /r /n "." ip_list.tmp >nul 2>&1 || goto :LIST_FALLBACK

:: ===== Tampilkan ringkasan seperti contoh kamu =====
echo.
echo %C_H1%===== RINGKASAN =====%C_RST%
echo  No  Serial               Model                  IP              Endpoint          Status
echo  --  -------------------- ---------------------- --------------- ----------------- -------
set /a __row=0
for /f "usebackq tokens=1-5 delims=|" %%A in ("ip_list.tmp") do (
  set /a __row+=1
  set "SER=%%A"
  set "MOD=%%B"
  set "IPX=%%C"
  set "EPX=%%D"
  set "STATE=offline"
  for /f "usebackq delims=" %%S in (`adb -s %%D get-state 2^>nul`) do set "STATE=%%S"

  set "SERPAD=!SER!                    "
  set "SERPAD=!SERPAD:~0,20!"
  set "MODPAD=!MOD!                  "
  set "MODPAD=!MODPAD:~0,22!"
  set "IPPAD=!IPX!           "
  set "IPPAD=!IPPAD:~0,15!"
  set "EPPAD=!EPX!            "
  set "EPPAD=!EPPAD:~0,17!"

  echo  !__row!   !SERPAD! !MODPAD! !IPPAD! !EPPAD! !STATE!
)

echo.
set "sel="
set /p sel="Pilih No untuk CONNECT (Enter=Kembali): "
if "%sel%"=="" goto :MAIN_MENU

:: Validasi angka sederhana
for /f "delims=0123456789" %%x in ("%sel%") do set "sel="
if "%sel%"=="" goto :MAIN_MENU

set /a __idx=0
set "TARGET=" & set "SER=" & set "IPX=" & set "MOD="
for /f "usebackq tokens=1-5 delims=|" %%A in ("ip_list.tmp") do (
  set /a __idx+=1
  if "!__idx!"=="%sel%" (
    set "SER=%%A"
    set "MOD=%%B"
    set "IPX=%%C"
    set "TARGET=%%D"
  )
)

if not defined TARGET (
  echo.
  echo %C_ERR%[KESALAHAN]%C_RST% Nomor tidak valid.
  echo Tekan tombol apa saja untuk kembali...
  pause >nul
  goto :MAIN_MENU
)

:: === Langsung pakai alur CONNECT seperti menu [2] ===
call :CONNECT_FROM_LIST "%TARGET%"
goto :MAIN_MENU


:LIST_FALLBACK
echo.
echo %C_WARN%[INFO]%C_RST% Tidak bisa membangun daftar gabungan (ip_list.tmp kosong/tiada).
echo %C_DIM%Menampilkan isi mentah file JSON sebagai diagnostik:%C_RST%
if exist "%FILE_SETUP%" (
  echo --- %FILE_SETUP% ---
  type "%FILE_SETUP%"
) else (
  echo (file %FILE_SETUP% tidak ada)
)
echo.
if exist "%FILE_CONN%" (
  echo --- %FILE_CONN% ---
  type "%FILE_CONN%"
) else (
  echo (file %FILE_CONN% tidak ada)
)
echo.
echo %C_DIM%(Jalankan %C_NUM%1%C_DIM%:Setup atau %C_NUM%2%C_DIM%:Connect untuk mengisi data jika kosong)%C_RST%

echo.
echo Tekan tombol apa saja untuk kembali ke menu...
pause >nul
goto :MAIN_MENU


:: =========================================
::  SUB: CONNECT_FROM_LIST — alur sama seperti CMD_CONNECT
::  Arg1: endpoint target (contoh: 192.168.43.1:5555)
:: =========================================
:CONNECT_FROM_LIST
setlocal EnableDelayedExpansion
set "TARGET=%~1"

echo.
echo %C_LBL%[ADB]%C_RST% connect ke %TARGET% ...
adb disconnect %TARGET% >nul 2>&1
adb connect %TARGET%

set "STATE="
for /f "usebackq delims=" %%s in (`adb -s %TARGET% get-state 2^>nul`) do set "STATE=%%s"
if /i not "%STATE%"=="device" (
  echo.
  echo %C_ERR%[KESALAHAN]%C_RST% Gagal terhubung sebagai "device". Status saat ini: "%STATE%"
  echo Periksa IP/endpoint pada JSON dan bahwa ADB via Wi-Fi aktif di ponsel.
  echo Tekan tombol apa saja untuk kembali...
  pause >nul
  endlocal & goto :eof
)

call :PRINT_DEVICE_INFO "%TARGET%"
call :SAVE_CONNECT_JSON "%TARGET%"
call :CHECK_STAY_AWAKE_SUPPORT "%TARGET%"

:: ====== Preset kualitas video (sama seperti di CMD_CONNECT) ======
set "choice="
:PROMPT_PRESET_FROM_LIST
echo.
echo Pilih preset scrcpy:
echo   %C_NUM%[1]%C_RST% Rendah      : --video-bit-rate 2M   --max-size 800
echo   %C_NUM%[2]%C_RST% Bawaan      : --video-bit-rate 8M   --max-size 1080
echo   %C_NUM%[3]%C_RST% Tinggi      : --video-bit-rate 16M  --max-size 1440
echo   %C_NUM%[4]%C_RST% SangatTinggi: --video-bit-rate 24M  --max-size 1440
echo   %C_NUM%[5]%C_RST% Ultra       : --video-bit-rate 32M  --max-size 2160
echo   %C_NUM%[6]%C_RST% Ekstrem     : --video-bit-rate 64M  --max-size 2160
echo   %C_NUM%[7]%C_RST% SuperEkstrem: --video-bit-rate 72M  --max-size 2160
set /p choice="Masukkan 1-7: "
if "%choice%"=="1" (set "SCRCPY_OPTS=--video-bit-rate 2M --max-size 800") ^
else if "%choice%"=="2" (set "SCRCPY_OPTS=--video-bit-rate 8M --max-size 1080") ^
else if "%choice%"=="3" (set "SCRCPY_OPTS=--video-bit-rate 16M --max-size 1440") ^
else if "%choice%"=="4" (set "SCRCPY_OPTS=--video-bit-rate 24M --max-size 1440") ^
else if "%choice%"=="5" (set "SCRCPY_OPTS=--video-bit-rate 32M --max-size 2160") ^
else if "%choice%"=="6" (set "SCRCPY_OPTS=--video-bit-rate 64M --max-size 2160") ^
else if "%choice%"=="7" (set "SCRCPY_OPTS=--video-bit-rate 72M --max-size 2160") ^
else (echo Pilihan tidak valid. Coba lagi.& goto :PROMPT_PRESET_FROM_LIST)

if /i "!STAY_OK!"=="1" ( set "SCRCPY_OPTS=%SCRCPY_OPTS% --stay-awake" ) ^
else (
  echo.
  echo %C_NOTE%[CATATAN]%C_RST% "stay-awake" tidak diizinkan pada perangkat/ROM ini; melanjutkan tanpa opsi itu.
)

:: ====== Extras (opsional) ======
echo.
echo %C_H1%Ekstra (opsional):%C_RST% Tekan Enter untuk lewati atau isi Y/N
set "yn="
set /p yn="Selalu di atas? (--always-on-top) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --always-on-top"
set "yn="
set /p yn="Jendela tanpa batas? (--window-borderless) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --window-borderless"
set "yn="
set /p yn="Layar penuh? (--fullscreen) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --fullscreen"
set "yn="
set /p yn="Bisukan audio? (--no-audio) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --no-audio"
set "yn="
set /p yn="Matikan layar perangkat? (-S/--turn-screen-off) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% -S"
set "yn="
set /p yn="Gunakan H.265/HEVC? (--video-codec=h265) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --video-codec=h265"
set "yn="
set /p yn="Batasi ke 60 fps? (--max-fps 60) [y/N]: "
if /i "%yn%"=="y" set "SCRCPY_OPTS=%SCRCPY_OPTS% --max-fps 60"

set "ttl="
set /p ttl="Judul jendela kustom? (--window-title) [kosong = lewati]: "
if not "%ttl%"=="" set "SCRCPY_OPTS=%SCRCPY_OPTS% --window-title \"%ttl%\""

set "pos="
set /p pos="Atur X,Y,Lebar,Tinggi? (contoh: 100,80,900,1600) [lewati=Enter]: "
if not "%pos%"=="" (
  for /f "tokens=1-4 delims=," %%x in ("%pos%") do (
    set "SCRCPY_OPTS=%SCRCPY_OPTS% --window-x=%%x --window-y=%%y --window-width=%%z --window-height=%%w"
  )
)

set "yn="
set /p yn="Rekam ke MP4? (--record file.mp4) [y/N]: "
if /i "%yn%"=="y" (
  set "recfile="
  set /p recfile="  Nama file [bawaan record.mp4]: "
  if "%recfile%"=="" set "recfile=record.mp4"
  set "SCRCPY_OPTS=%SCRCPY_OPTS% --record \"%recfile%\""
)

echo.
echo Menjalankan scrcpy dengan:
echo   %SCRCPY_OPTS%

where scrcpy >nul 2>&1 && (
  scrcpy -s %TARGET% %SCRCPY_OPTS%
) || (
  echo.
  echo %C_INFO%[INFO]%C_RST% scrcpy tidak terpasang, melewati peluncuran mirroring.
)

echo.
echo Tekan tombol apa saja untuk kembali...
pause >nul
endlocal & goto :eof



:: =========================================
::  SUB: BUILD_COMBINED_LIST  → hasilkan ip_list.tmp
::  Format baris: serial|model|ip|endpoint|source
::  - Tahan BOM UTF-8
::  - Dukung JSON objek tunggal {..} atau array [..]
::  - Dedup per IP
:: =========================================
:BUILD_COMBINED_LIST
set "OUT=%~1"
del /f /q "%OUT%" >nul 2>&1

if exist "%FILE_SETUP%" call :PARSE_JSON_FILE "%FILE_SETUP%" "%OUT%"
if exist "%FILE_CONN%"  call :PARSE_JSON_FILE "%FILE_CONN%"  "%OUT%"
goto :eof


:: =========================================
::  SUB: PARSE_JSON_FILE  (pure batch, tolerant UTF-8 BOM)
::  Arg1: path JSON, Arg2: output file
::  Format output: serial|model|ip|endpoint|source
:: =========================================
:PARSE_JSON_FILE
setlocal EnableDelayedExpansion
set "PTH=%~1"
set "OUTF=%~2"

for %%# in ("%PTH%") do set "SRC=%%~nx#"

set "SER=" & set "MOD=" & set "IPX=" & set "EPX="

for /f "usebackq delims=" %%L in ("%PTH%") do (
  set "L=%%L"

  rem — buang BOM varian umum (kadang tampil 'ï»¿', kadang '∩╗┐')
  set "L=!L:ï»¿=!"
  set "L=!L:∩╗┐=!"

  rem — split pertama kali ketemu titik dua => kunci di %%k, nilai di %%l
  for /f "tokens=1,* delims=:" %%k in ("!L!") do (
    set "K=%%k"
    set "V=%%l"

    rem -- normalisasi kunci: trim kiri, buang kutip & koma & spasi ekstra
    for /f "tokens=* delims= " %%z in ("!K!") do set "K=%%z"
    set "K=!K:"=!"
    set "K=!K:,=!"
    set "K=!K: =!"

    if /i "!K!"=="serial"   ( set "TMP=!V!" & call :CLEANVAL TMP SER )
    if /i "!K!"=="model"    ( set "TMP=!V!" & call :CLEANVAL TMP MOD )
    if /i "!K!"=="ip"       ( set "TMP=!V!" & call :CLEANVAL TMP IPX )
    if /i "!K!"=="endpoint" ( set "TMP=!V!" & call :CLEANVAL TMP EPX )
  )

  rem — jika ketemu penutup objek, commit satu baris
  if not "!L!"=="!L:}=!" (
    if not defined EPX if defined IPX set "EPX=!IPX!:5555"
    if defined SER if defined MOD if defined IPX if defined EPX (
      rem dedup per IP
      set "DUP="
      if exist "!OUTF!" (
        findstr /c:"|!IPX!|" "!OUTF!" >nul 2>&1 && set "DUP=1"
      )
      if not defined DUP (
        >>"!OUTF!" echo !SER!^|!MOD!^|!IPX!^|!EPX!^|!SRC!
      )
    )
    set "SER=" & set "MOD=" & set "IPX=" & set "EPX="
  )
)

endlocal & goto :eof


:: =========================================
::  SUB: CLEANVAL  (bersihkan nilai JSON -> polos)
::  Arg1: var sumber (nama), Arg2: var tujuan (nama)
:: =========================================
:CLEANVAL
setlocal EnableDelayedExpansion
set "v=!%~1!"

rem buang koma di ujung, kutip, dan spasi awal/akhir
set "v=!v:,=!"
set "v=!v:"=!"
for /f "tokens=* delims= " %%z in ("!v!") do set "v=%%z"
:__trim_end
if "!v:~-1!"==" " (set "v=!v:~0,-1!" & goto :__trim_end)

rem kosongkan jika 'null'
if /i "!v!"=="null" set "v="

endlocal & if defined v (set "%~2=%v%") else set "%~2="
goto :eof



:: =================================================
::  USB-BACK — Kembalikan semua perangkat TCP ke USB
:: =================================================
:CMD_USBBACK
title USB-Back semua perangkat TCP
echo.
echo Mengalihkan semua endpoint TCP kembali ke USB...
for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (
  echo %%A | findstr ":" >nul
  if not errorlevel 1 (
    echo   - %%A  ^> usb
    adb -s %%A usb >nul 2>&1
  )
)
echo Selesai.
if /i "%~1"=="" (echo.& pause & goto :MAIN_MENU) else exit /b 0

:: =================================================
::  DISCONNECT — adb disconnect (semua)
:: =================================================
:CMD_DISCONNECT_ALL
title adb disconnect (semua)
echo.
echo Memutus semua endpoint ADB TCP...
adb disconnect >nul 2>&1
echo Selesai.
if /i "%~1"=="" (echo.& pause & goto :MAIN_MENU) else exit /b 0

:: =================================================
::  PAIR — Pairing debugging nirkabel
:: =================================================
:CMD_PAIR
title ADB Pair (Wireless debugging)
echo.
echo %C_H1%=== ADB Wireless debugging (Android 11+) ===%C_RST%
set "PAIR_EP="
set /p PAIR_EP="Masukkan endpoint pairing (mis. 192.168.1.10:37187): "
if "%PAIR_EP%"=="" (echo Endpoint wajib diisi.& if /i "%~1"=="" (pause & goto :MAIN_MENU) else exit /b 1)

set "PAIR_CODE="
set /p PAIR_CODE="Masukkan kode pairing (6 digit): "

echo.
echo adb pair %PAIR_EP%
if not "%PAIR_CODE%"=="" (
  (echo %PAIR_CODE%) | adb pair %PAIR_EP%
) else (
  adb pair %PAIR_EP%
)

echo.
echo Jika pairing sukses, sambungkan endpoint perangkat (biasanya IP:5555).
set "C_EP="
set /p C_EP="Endpoint untuk connect [bawaan turunan dari IP:5555]: "
if "%C_EP%"=="" (
  for /f "tokens=1 delims=:" %%h in ("%PAIR_EP%") do set "C_EP=%%h:5555"
)
adb connect %C_EP%
if /i "%~1"=="" (echo.& pause & goto :MAIN_MENU) else exit /b 0

:: ===================== SUBROUTIN =====================

:ENSURE_JSON_ARRAY
set "PTH=%~1"
if not defined PTH goto :eof

rem -- Kalau PowerShell ada, pakai yang lama (biar rapi):
where powershell >nul 2>&1 && (
  powershell -NoProfile -Command ^
   "$ErrorActionPreference='SilentlyContinue';" ^
   "$p='%PTH%';" ^
   "if (!(Test-Path -LiteralPath $p)) { '[]' | Set-Content -LiteralPath $p -Encoding UTF8; exit }" ^
   "$raw = Get-Content -Raw -LiteralPath $p;" ^
   "try{ $obj = $raw | ConvertFrom-Json } catch { $obj=$null }" ^
   "if ($null -ne $obj) { if ($obj -is [array]) { exit } else { @($obj) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8; exit } }" ^
   "$raw2 = '[' + ($raw -replace '}\s*[\r\n]+\s*{','},{') + ']';" ^
   "try{ $arr = $raw2 | ConvertFrom-Json }catch{ $arr=@() }" ^
   "($arr | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $p -Encoding UTF8"
  goto :eof
)

rem -- Fallback murni Batch: bungkus/konversi isi sekarang jadi array
if not exist "%PTH%" ( >"%PTH%" echo [] & goto :eof )

del /q "__arr.tmp" >nul 2>&1
setlocal EnableDelayedExpansion
set "ACC=" & set "INOBJ="

for /f "usebackq delims=" %%L in ("%PTH%") do (
  set "L=%%L"
  set "L=!L:ï»¿=!" & set "L=!L:∩╗┐=!"
  for /f "tokens=* delims= " %%z in ("!L!") do set "T=%%z"

  if not defined INOBJ (
    echo !T! | findstr /b /c:"{" >nul && ( set "INOBJ=1" & set "ACC=%%L" )
  ) else (
    set "ACC=!ACC!%%L"
  )

  if not "%%L"=="%%L:}=%%" (
    if defined INOBJ (
      >>"__arr.tmp" echo !ACC!
      set "ACC=" & set "INOBJ="
    )
  )
)
endlocal

> "%PTH%" echo [
setlocal EnableDelayedExpansion
set /a N=0
for /f "usebackq delims=" %%O in ("__arr.tmp") do (
  if not "%%O"=="" (
    set /a N+=1
    if !N! gtr 1 (>>"%PTH%" echo  , %%O) else (>>"%PTH%" echo   %%O)
  )
)
endlocal & >>"%PTH%" echo ]
del /q "__arr.tmp" >nul 2>&1
goto :eof



:JSON_APPEND_DEDUP
set "PTH=%~1"
if not exist "%PTH%" ( >"%PTH%" echo [] )

rem -- Coba cabang PowerShell dulu (kalau ada), termasuk dedup by IP:
where powershell >nul 2>&1 && (
  powershell -NoProfile -Command ^
   "$ErrorActionPreference='SilentlyContinue';" ^
   "$p='%PTH%';" ^
   "$entry = Get-Content -Raw -LiteralPath '__entry.tmp' | ConvertFrom-Json;" ^
   "try{ $cur = if (Test-Path -LiteralPath $p){ Get-Content -Raw -LiteralPath $p | ConvertFrom-Json } else { @() } }catch{ $cur=$null }" ^
   "if ($null -eq $cur) { $raw = if (Test-Path -LiteralPath $p){ Get-Content -Raw -LiteralPath $p } else { '' }; $raw2='['+($raw -replace '}\s*[\r\n]+\s*{','},{')+']'; try{ $cur=$raw2|ConvertFrom-Json }catch{ $cur=@() } }" ^
   "$arr = if ($cur -is [array]) { $cur } else { @($cur) }" ^
   "$newip = [string]$entry.ip; $done=$false; for($i=0;$i -lt $arr.Count;$i++){ if([string]$arr[$i].ip -eq $newip -and $newip){ $arr[$i]=$entry; $done=$true; break } }" ^
   "if(-not $done){ $arr += $entry }" ^
   "$arr | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8"
  goto :eof
)

rem -- Fallback murni Batch: rebuild array = (objek lama) + (entri baru)
call :ENSURE_JSON_ARRAY "%PTH%"

del /q "__arr.tmp" >nul 2>&1
setlocal EnableDelayedExpansion
set "ACC=" & set "INOBJ="

for /f "usebackq delims=" %%L in ("%PTH%") do (
  set "L=%%L"
  set "L=!L:ï»¿=!" & set "L=!L:∩╗┐=!"
  for /f "tokens=* delims= " %%z in ("!L!") do set "T=%%z"

  if not defined INOBJ (
    echo !T! | findstr /b /c:"{" >nul && ( set "INOBJ=1" & set "ACC=%%L" )
  ) else (
    set "ACC=!ACC!%%L"
  )

  if not "%%L"=="%%L:}=%%" (
    if defined INOBJ (
      >>"__arr.tmp" echo !ACC!
      set "ACC=" & set "INOBJ="
    )
  )
)

rem + tambahkan entri baru (satu baris)
for /f "usebackq delims=" %%E in ("__entry.tmp") do (
  if not "%%E"=="" >>"__arr.tmp" echo %%E
)

> "%PTH%" echo [
set /a N=0
for /f "usebackq delims=" %%O in ("__arr.tmp") do (
  if not "%%O"=="" (
    set /a N+=1
    if !N! gtr 1 (>>"%PTH%" echo  , %%O) else (>>"%PTH%" echo   %%O)
  )
)
>>"%PTH%" echo ]
endlocal
del /q "__arr.tmp" >nul 2>&1
goto :eof


:GET_WIFI_IP
:: %1 = SERIAL (dalam tanda kutip), %2 = nama variabel keluaran
set "%2="
for /f "usebackq tokens=4" %%x in (`adb -s %~1 shell ip -o -4 addr show wlan0 2^>nul`) do (
  for /f "delims=/ " %%q in ("%%x") do if not defined %2 set "%2=%%q"
)
if not defined %2 (
  for /f "usebackq tokens=1,2" %%a in (`adb -s %~1 shell ip -f inet addr show wlan0 2^>nul ^| findstr /r /c:"inet "`) do (
    for /f "delims=/ " %%q in ("%%b") do if not defined %2 set "%2=%%q"
  )
)
if not defined %2 (
  for /f "usebackq tokens=2,4" %%i in (`adb -s %~1 shell ip -o -4 addr show 2^>nul`) do (
    echo %%i | findstr /i "wlan p2p ap softap" >nul && (
      for /f "delims=/ " %%q in ("%%j") do if not defined %2 set "%2=%%q"
    )
  )
)
if not defined %2 (
  for /f "usebackq delims=" %%r in (`adb -s %~1 shell getprop dhcp.wlan0.ipaddress 2^>nul`) do set "%2=%%r"
)
set "%2=!%2: =!"
goto :eof

:JFIELD
set "%2=null"
set "VAL=!%1!"
if not "!VAL!"=="" (
  set "VAL=!VAL:"=!" 
  set "%2="!VAL!""
)
goto :eof

:PRINT_DEVICE_INFO
set "SER=%~1"
set "MODEL=" & set "BRAND=" & set "DEVNAME=" & set "VER=" & set "SDK="
set "SIZE="  & set "DPI="   & set "BATT="    & set "SSID_CUR=" & set "IP_CUR="

for /f "usebackq delims=" %%M in (`adb -s %SER% shell getprop ro.product.model 2^>nul`) do if not defined MODEL set "MODEL=%%M"
for /f "usebackq delims=" %%B in (`adb -s %SER% shell getprop ro.product.brand 2^>nul`) do if not defined BRAND set "BRAND=%%B"
for /f "usebackq delims=" %%V in (`adb -s %SER% shell getprop ro.build.version.release 2^>nul`) do if not defined VER set "VER=%%V"
for /f "usebackq delims=" %%K in (`adb -s %SER% shell getprop ro.build.version.sdk 2^>nul`) do if not defined SDK set "SDK=%%K"
for /f "usebackq delims=" %%D in (`adb -s %SER% shell getprop ro.product.device 2^>nul`) do if not defined DEVNAME set "DEVNAME=%%D"

for /f "tokens=1,* delims=:" %%a in ('adb -s %SER% shell wm size 2^>nul ^| findstr /c:"Physical size"') do set "SIZE=%%b"
for /f "tokens=* delims= " %%z in ("!SIZE!") do set "SIZE=%%z"
for /f "tokens=1,* delims=:" %%a in ('adb -s %SER% shell wm density 2^>nul ^| findstr /c:"Physical density"') do set "DPI=%%b"
for /f "tokens=* delims= " %%z in ("!DPI!") do set "DPI=%%z"

for /f "tokens=1,* delims=:" %%a in ('adb -s %SER% shell dumpsys battery 2^>nul ^| findstr /r "^ *level:"') do set "BATT=%%b"
for /f "tokens=* delims= " %%z in ("!BATT!") do set "BATT=%%z"

for /f "tokens=1,* delims=:" %%a in ('adb -s %SER% shell dumpsys wifi 2^>nul ^| findstr /c:"mWifiInfo SSID"') do if not defined SSID_CUR set "SSID_CUR=%%b"
if not defined SSID_CUR (
  for /f "tokens=1,* delims=:" %%a in ('adb -s %SER% shell dumpsys wifi 2^>nul ^| findstr /c:"SSID"') do if not defined SSID_CUR set "SSID_CUR=%%b"
)
for /f "tokens=1 delims=," %%t in ("!SSID_CUR!") do set "SSID_CUR=%%t"
for /f "tokens=* delims= " %%z in ("!SSID_CUR!") do set "SSID_CUR=%%z"
set "SSID_CUR=!SSID_CUR:"=!"
if /i "!SSID_CUR!"=="<unknown ssid>" set "SSID_CUR="
if "!SSID_CUR!"=="=" set "SSID_CUR="

call :GET_WIFI_IP "%SER%" IP_CUR
if not defined IP_CUR (
  for /f "tokens=1 delims=:" %%h in ("%SER%") do set "IP_CUR=%%h"
)
echo !IP_CUR! | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul || set "IP_CUR="

echo.
call :UI_SEP
echo MEREK      : !BRAND!
echo MODEL      : !MODEL!
echo PERANGKAT  : !DEVNAME!
echo ANDROID    : !VER!  SDK !SDK!
if defined SIZE (echo RESOLUSI   : !SIZE!) else echo RESOLUSI   : tidak diketahui
if defined DPI  (echo DPI        : !DPI!)  else echo DPI        : tidak diketahui
if defined BATT (echo BATERAI    : !BATT!%%) else echo BATERAI    : tidak diketahui
if defined SSID_CUR (echo SSID       : !SSID_CUR!) else echo SSID       : tidak tersedia
if defined IP_CUR (
  echo IP_WIFI    : !IP_CUR!
  echo ADB_TCP    : !IP_CUR!:5555
) else (
  echo IP_WIFI    : tidak tersedia
  echo ADB_TCP    : %SER%
)
call :UI_SEP
echo.
goto :eof

:CHECK_STAY_AWAKE_SUPPORT
set "STAY_OK=0"
set "CURR="
for /f "usebackq delims=" %%g in (`adb -s %~1 shell settings get global stay_on_while_plugged_in 2^>nul`) do set "CURR=%%g"
if "%CURR%"=="" set "CURR=0"
adb -s %~1 shell settings put global stay_on_while_plugged_in 7 >nul 2>&1
set "NOW="
for /f "usebackq delims=" %%g in (`adb -s %~1 shell settings get global stay_on_while_plugged_in 2^>nul`) do set "NOW=%%g"
if "%NOW%"=="7" (
  set "STAY_OK=1"
  adb -s %~1 shell settings put global stay_on_while_plugged_in %CURR% >nul 2>&1
)
goto :eof


:SAVE_CONNECT_JSON
rem Simpan entri koneksi KE FILE (skip jika device+model sudah ada).
rem Arg1: endpoint target (contoh: 192.168.43.1:5555)
setlocal EnableDelayedExpansion

if not defined FILE_CONN set "FILE_CONN=wifi_device_connect.json"
set "TARGET_IN=%~1"

rem --- Ekstrak host dari TARGET (untuk IP_SAVE) ---
set "IP_SAVE="
for /f "tokens=1 delims=:" %%h in ("%TARGET_IN%") do set "IP_SAVE=%%h"

rem --- Ambil serial nyata (kalau gagal, pakai TARGET) ---
set "SER_REAL="
for /f "usebackq delims=" %%x in (`adb -s "!TARGET_IN!" get-serialno 2^>nul`) do set "SER_REAL=%%x"
if "!SER_REAL!"=="" set "SER_REAL=!TARGET_IN!"

rem --- Jika PRINT_DEVICE_INFO sebelumnya isi IP_CUR, pakai itu ---
if defined IP_CUR set "IP_SAVE=!IP_CUR!"

rem --- Siapkan field JSON dari metadata terakhir ---
call :JFIELD BRAND      J_BRAND
call :JFIELD MODEL      J_MODEL
call :JFIELD DEVNAME    J_DEVICE
call :JFIELD VER        J_ANDROID
call :JFIELD SDK        J_SDK
call :JFIELD SIZE       J_RES
call :JFIELD DPI        J_DPI
call :JFIELD BATT       J_BATT
call :JFIELD SSID_CUR   J_SSID

set "J_IP=null"
if defined IP_SAVE (
  set "VAL=!IP_SAVE!"
  set "VAL=!VAL:"=!"
  set "J_IP="!VAL!""
)

set "EP_SAVE="
if defined IP_SAVE (set "EP_SAVE=!IP_SAVE!:5555") else set "EP_SAVE=!TARGET_IN!"
call :JFIELD EP_SAVE J_EP

> "__entry.tmp" echo {"timestamp":"%date% %time%","serial":"!SER_REAL!","brand":!J_BRAND!,"model":!J_MODEL!,"device":!J_DEVICE!,"android":!J_ANDROID!,"sdk":!J_SDK!,"resolution":!J_RES!,"dpi":!J_DPI!,"battery":!J_BATT!,"ssid":!J_SSID!,"ip":!J_IP!,"endpoint":!J_EP!}

rem --- Tarik semua objek lama (array/NDJSON/objek tunggal) jadi 1-baris/objek ---
del /q "__arr2.tmp" >nul 2>&1
if exist "%FILE_CONN%" (
  set "ACC=" & set "INOBJ="
  for /f "usebackq delims=" %%L in ("%FILE_CONN%") do (
    set "L=%%L"
    set "L=!L:ï»¿=!" & set "L=!L:∩╗┐=!"
    if not defined INOBJ (
      echo !L! | findstr /c:"{" >nul && ( set "INOBJ=1" & set "ACC=!L!" )
    ) else (
      set "ACC=!ACC!!L!"
    )
    echo !L! | findstr /c:"}" >nul && if defined INOBJ (
      >>"__arr2.tmp" echo !ACC!
      set "ACC=" & set "INOBJ="
    )
  )
)

rem --- Cek DUP berdasarkan device+model: kalau ada, SKIP append ---
set "DUP=0"
set "PAT_DEV=\"device\":\"!DEVNAME!\""
set "PAT_MOD=\"model\":\"!MODEL!\""

if exist "__arr2.tmp" (
  del /q "__flt1.tmp" "__flt2.tmp" >nul 2>&1
  for /f "usebackq delims=" %%Q in ("__arr2.tmp") do (
    set "Q=%%Q"
    echo !Q! | findstr /c:"%PAT_DEV%" >nul && >>"__flt1.tmp" echo !Q!
  )
  if exist "__flt1.tmp" (
    for /f "usebackq delims=" %%R in ("__flt1.tmp") do (
      set "R=%%R"
      echo !R! | findstr /c:"%PAT_MOD%" >nul && >>"__flt2.tmp" echo !R!
    )
  )
  if exist "__flt2.tmp" for %%# in ("__flt2.tmp") do if not "%%~z#"=="0" set "DUP=1"
)

if not "%DUP%"=="1" (
  rem --- belum ada pasangan device+model -> tambahkan entri baru ---
  type "__entry.tmp" >> "__arr2.tmp"
) else (
  echo %C_INFO%[SKIP]%C_RST% Kombinasi device+model sudah ada, tidak menambah entri baru.
)

rem --- Tulis ulang sebagai ARRAY JSON valid ---
> "%FILE_CONN%" echo [
set /a __N=0
for /f "usebackq delims=" %%O in ("__arr2.tmp") do (
  if not "%%O"=="" (
    set /a __N+=1
    if !__N! gtr 1 (>>"%FILE_CONN%" echo   , %%O) else (>>"%FILE_CONN%" echo   %%O)
  )
)
>>"%FILE_CONN%" echo ]

del /q "__entry.tmp" "__arr2.tmp" "__flt1.tmp" "__flt2.tmp" >nul 2>&1

for %%F in ("%FILE_CONN%") do echo %C_INFO%[WRITE]%C_RST% Tersimpan ke "%%~nxF" (size=%%~zF)

endlocal & goto :eof



:REWRITE_AS_ARRAY
rem Arg1: file yang berisi objek per baris, Arg2: file tujuan JSON array
setlocal EnableDelayedExpansion
set "IN=%~1"
set "DST=%~2"

> "%DST%" echo [
set /a N=0
for /f "usebackq delims=" %%O in ("%IN%") do (
  if not "%%O"=="" (
    set /a N+=1
    if !N! gtr 1 (>>"%DST%" echo   , %%O) else (>>"%DST%" echo   %%O)
  )
)
>>"%DST%" echo ]
endlocal & goto :eof



:OFFER_LIST_COMBINED
del /f /q ip_list.tmp >nul 2>&1
call :BUILD_COMBINED_LIST "ip_list.tmp"
if not exist ip_list.tmp goto :eof
for %%# in (ip_list.tmp) do if "%%~z#"=="0" goto :eof

echo.
echo %C_H1%Perangkat tersedia (gabungan dari %FILE_SETUP% dan %FILE_CONN%)%C_RST%
echo  Id  IP               Endpoint           Model                Sumber
echo  --  ---------------  -----------------  --------------------  ---------------------

set /a i=0
for /f "usebackq tokens=1-5 delims=|" %%a in ("ip_list.tmp") do (
  set /a i+=1
  set "ser=%%a" & set "mod=%%b" & set "ipx=%%c" & set "epx=%%d" & set "src=%%e"
  set "mod1=!mod!                    "
  set "mod1=!mod1:~0,20!"
  echo  !i!   !ipx!    !epx!   !mod1!  !src!
)

echo    0   -- manual --      (ketik IP baru)
echo.
set "sel="
set /p sel="Pilih Id (atau 0 untuk IP manual): "
if "%sel%"=="" goto :eof
if "%sel%"=="0" goto :eof

set /a j=0
for /f "usebackq tokens=1-5 delims=|" %%a in ("ip_list.tmp") do (
  set /a j+=1
  if "!j!"=="%sel%" (
    rem ambil IP & endpoint yang benar dari kolom ke-3 dan ke-4
    set "ip=%%c"
    set "TARGET=%%d"
  )
)
goto :eof



:: ================= Pembantu UI =================
:UI_INIT
:: Dukungan escape ANSI + palet warna

for /f "delims=" %%e in ('echo prompt $E^| cmd') do set "ESC=%%e"
set "C_RST=%ESC%[0m"
set "C_TITLE=%ESC%[95m"
set "C_H1=%ESC%[96m"
set "C_NUM=%ESC%[93m"
set "C_LBL=%ESC%[97m"
set "C_DIM=%ESC%[90m"
set "C_INFO=%ESC%[94m"
set "C_WARN=%ESC%[93m"
set "C_ERR=%ESC%[91m"
set "C_NOTE=%ESC%[92m"
set "C_TAB=%ESC%[38;5;81m"
set "C_ASK=%ESC%[38;5;219m"
goto :eof

:UI_BAR
echo %ESC%[90m===========================================================%C_RST%
goto :eof

:UI_SEP
echo %ESC%[90m-----------------------------------------------------------%C_RST%
goto :eof
