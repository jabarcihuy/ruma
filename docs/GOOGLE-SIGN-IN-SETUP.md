# Mengaktifkan login Google Ruma

Kode login Google memakai Firebase Authentication. Ini berbeda dari izin Google Calendar, yang tetap diminta saat pengguna memilih impor kalender.

## Konfigurasi Firebase

1. Di Firebase Console project `mobile-app-3479f`, buka **Authentication → Sign-in method** lalu aktifkan provider **Google**.
2. Aplikasi Android `id.ruma.app` sudah mendaftarkan sertifikat SHA-1 debug dan release. SHA-1 debug: `30:A9:63:A1:00:61:D0:82:F7:81:E7:2C:DF:19:26:8D:D9:E2:DF:97`. SHA-1 release: `2B:3E:5F:E6:17:6A:54:14:D4:C6:89:0D:47:14:1D:57:C7:62:0F:1D`.
3. `android/app/google-services.json` memiliki web OAuth client (`client_type: 3`). Setelah fingerprint didaftarkan, unduh ulang konfigurasi dari Firebase Console dan pastikan web OAuth client tetap ada; jangan membuat ID client sendiri.
4. Build ulang APK setelah mengganti konfigurasi. Uji login pada perangkat Android dengan akun yang diizinkan pada consent screen.

Tidak diperlukan password Google atau web client secret di aplikasi. Login dengan Google tidak meminta scope Calendar. Saat akun sementara ditautkan dari Profil, Firebase mempertahankan UID dan data yang sama. Jika Google sudah terhubung ke UID Ruma lain, Ruma membiarkan akun sementara tetap aktif dan menampilkan pesan untuk masuk ke akun yang benar.

## Status

Provider Google berstatus enabled di Firebase Console dan kedua fingerprint sudah terdaftar. APK debug `0.2.0+3` terbaru berhasil dibangun dan dipasang di emulator. Login nyata masih menunggu persetujuan ketentuan/privasi Ruma dan akun Google ditambahkan langsung oleh pengguna di emulator; APK release `0.2.0+3` sudah berhasil dibangun dan diverifikasi dengan tanda tangan ruma-release (Scheme v2).
