# Fondasi Flutter Ruma

19 Oktober 2026. Laporan tahap fondasi Android dan akun. Fondasi dan akun sudah diverifikasi pada HP Android 36 melalui USB, dengan Auth Emulator dan Firebase produksi dalam proses terpisah. Ini bukan laporan seluruh fitur Ruma sudah selesai.

## Yang sudah dibuat

- Project Flutter Android di root Ruma, application ID `id.ruma.app`, label dan launcher Ruma.
- Tema Manrope, warna, komponen tombol/kartu/form, ikon SVG dan maskot dari aset desain yang tersedia.
- Welcome, masuk, daftar, persetujuan privasi, tampil/sembunyikan kata sandi, validasi dan pesan gagal yang mempertahankan isian.
- Firebase Authentication: email/password, akun sementara anonim, penautan email akun sementara dengan UID yang sama, logout dengan konfirmasi, dan perubahan nama panggilan.
- Startup mengikuti sesi Firebase SDK. Pergantian UID membuat ulang shell agar state tampilan akun sebelumnya tidak dipakai.
- Lima tab: Beranda, Agenda, Asisten, Keuangan, Profil. Ikon tanpa teks tetap mempunyai label aksesibilitas, tooltip dan area sentuh minimal 48 dp. Status bar memakai indikator Android asli.
- Beranda menempatkan ringkasan waktu dan uang setara. Profil memakai data akun sesungguhnya. Angka contoh Figma tidak disimpan sebagai saldo/transaksi pengguna.

Agenda, Asisten dan Keuangan baru mempunyai halaman pengantar; form CRUD, ledger, laporan dan percakapan AI belum tersambung. Beranda belum menghitung data Firestore. Profil tahap ini menyimpan nama melalui Firebase Auth, belum profil Firestore lengkap.

## Konfigurasi dan struktur

`lib/main.dart` menginisialisasi Firebase dan memilih welcome/shell menurut sesi. `lib/data/auth_session.dart` mengelola operasi Auth dan pesan kegagalan; `lib/app` berisi tema dan shell; `lib/features` berisi layar; `lib/ui` berisi komponen bersama. Tidak menambahkan state framework, framework agent atau database kedua.

Firebase diinisialisasi eksplisit memakai `lib/firebase_options.dart`. Nilainya berasal dari registrasi Android Ruma pada project `mobile-app-3479f`. Karena menggunakan `FirebaseOptions`, Google Services Gradle plugin tidak diperlukan. `android/app/google-services.json` hanya berisi client Ruma dari konfigurasi publik yang sudah diverifikasi. Konfigurasi SDK klien bukan secret NaraRouter atau private key server.

Default build terhubung ke Firebase Ruma. Flag `AUTH_EMULATOR=true` khusus pengujian mengalihkan SDK ke project `demo-ruma`, port 9096. Jangan membagikan APK target integration test sebagai APK aplikasi normal. Izin cleartext hanya pada manifest debug untuk emulator localhost.

Toolchain saat tahap ini: Flutter 3.47.7, Dart 3.13.5, JDK 17 untuk Android, AGP 9.1.0, Gradle 9.3.1. Dependency terselesaikan: firebase_core 5.0.0, firebase_auth 7.0.0, flutter_svg 2.3.0; lihat `pubspec.lock`. SDK Flutter menyediakan localization, widget test dan integration test.

Gradle memberi peringatan plugin Firebase masih memakai Kotlin Gradle Plugin. Build saat ini berhasil; evaluasi kompatibilitas saat Flutter/plugin diperbarui. Environment hanya diatur untuk proses project melalui `.local/android.env`, tanpa mengganti toolchain global.

## Aset

Aset runtime berada di `design/assets/ruma/`; font Manrope beserta lisensinya, ikon, ilustrasi dan launcher memakai sumber lokal. Semua SVG ditampilkan dengan `BoxFit.contain` untuk menjaga proporsi.

Badge navbar lama memiliki child SVG dengan namespace yang tidak didukung renderer. Sumber lama dipertahankan. Navbar memakai dua ekspor asli Figma, disusun sebagai lingkaran 48 dp dan wajah 32 dp:

- `mascot/nav-circle.svg`: ekspor `44094.svg` dari aset Figma `2e124233-4d73-459a-9c15-c6a079c80759`.
- `mascot/nav-face.svg`: ekspor `dd418.svg` dari aset yang sama.

Aset sudah dilokalkan; aplikasi tidak bergantung pada URL ekspor sementara. UI dibangun dari widget dan vektor, bukan gambar screenshot layar.

## Menjalankan pemeriksaan

Dari direktori root Ruma:

```bash
source .local/android.env
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

Untuk uji Auth terisolasi, jalankan Firebase Auth Emulator dengan Node/Java yang kompatibel:

```bash
firebase emulators:start --only auth --project demo-ruma --config firebase.json
adb reverse tcp:9096 tcp:9096
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/auth_flow_test.dart \
  --dart-define=AUTH_EMULATOR=true -d <device-id>
adb reverse --remove tcp:9096
```

Firebase CLI 15.34.0 pada mesin ini dijalankan dengan Node 24 dan JDK 27 khusus emulator. Android tetap menggunakan JDK 17. Lokasi tool mesin disimpan privat di `.local/tooling.json`.

Mode produksi harus dipilih secara eksplisit dengan `--dart-define=AUTH_LIVE_TESTS=true` tanpa `AUTH_EMULATOR=true`; jangan menjalankannya tanpa kebutuhan. Satu proses hanya menguji satu backend, agar konfigurasi SDK emulator dan produksi tidak bercampur. Untuk produksi, gunakan `--dart-define=AUTH_EMULATOR=false --dart-define=AUTH_LIVE_TESTS=true`; pengaman tes menolak produksi tanpa flag izin eksplisit. Jalankan dengan ID run yang disimpan privat bila memerlukan pemulihan fixture setelah gangguan jaringan.

Uji integrasi membuat akun sintetis miliknya sendiri, menguji validasi, navigasi, anonymous, link email, logout batal/konfirmasi, kata sandi salah lalu login benar. Tes mencoba menghapus hanya akun miliknya setelah selesai. Hasil cleanup dilaporkan sebagai `fixtureDeleted`; jangan menganggap pembersihan berhasil jika tes atau cleanup gagal. Pengujian tidak memanggil model, mengirim push, atau menulis ledger. Jangan menghapus akun pengguna lain untuk membersihkan fixture.

## Hasil dan bukti

- `qa/flutter/analyze.log`: analisis tanpa temuan.
- `qa/flutter/widget-tests.log`: tiga pengujian lulus; validasi/pesan akun, layar 320×640 dengan teks 200%, dan navigasi lima tab.
- Build APK debug dan profile berhasil. Auth Emulator pada HP Android 36 melalui USB lulus: anonymous, link email mempertahankan UID, daftar langsung, logout batal/konfirmasi, login salah/benar, nama tersimpan/diperbarui, lima tab, dan cleanup fixture. Bukti: `qa/flutter/auth-emulator-results.json` dan `qa/flutter/auth-emulator-device.log`.
- Input integration test memakai TestTextInput agar client input diperbarui setelah field disabled/busy. Ini bukan bukti seluruh interaksi keyboard Android asli telah diuji. Screenshot menunggu decoding SVG selesai.
- APK aplikasi normal ada di `output/apk/ruma-foundation-preview.apk`: build profile ARM64 dari `lib/main.dart`, Firebase produksi, sekitar 30 MB. Bukan harness integration test dan belum release pengumpulan. Hash dan pemeriksaan nilai secret server ada di `qa/flutter/apk-inspection.json`.
- Firebase produksi juga lulus alur yang sama, termasuk daftar langsung dan cleanup fixture terakhir. Bukti: `qa/flutter/auth-production-results.json` dan `qa/flutter/auth-production-device.log`.
- APK normal berhasil dipasang dan cold launch berstatus `ok`; screenshot OS asli: `qa/flutter/preview-device.png`.
- `qa/flutter/password-policy.json`: kebijakan password project Firebase terverifikasi, minimum enam karakter. Form memakai minimum enam karakter sesuai konfigurasi yang diperiksa. Firebase Auth menegakkan persyaratan server saat create/link; tidak ada request Dart tambahan ke endpoint kebijakan sebelum mendaftar.

## Batas dan langkah berikutnya

Tahap ini belum membuktikan seluruh skenario penerimaan produk. Persistence sesi memakai SDK, tetapi pemulihan sesudah process kill, offline pada HP, pergantian perangkat dan release signing memerlukan pengujian lanjutan. Verifikasi email dan lupa kata sandi tetap ditunda.

Langkah berikutnya adalah data manual: selesaikan dan uji Security Rules per UID, repository agenda/transaksi/anggaran, form manual, serta ringkasan dengan sumber data tersimpan. Production Firestore masih deny-all sampai Rules tersebut siap. Selanjutnya hubungkan agent, tinjauan draf, dan notifikasi sesuai urutan `BUILD-PLAN.md`.

FCM ke perangkat, cron dan seluruh integrasi AI belum diterapkan pada Flutter ini. Tindak lanjut CPU proxy mengikuti `qa/CPU-FOLLOWUP.md`; tidak ada benchmark atau panggilan model tambahan pada tahap Auth.

## APK pratinjau

```bash
source .local/android.env
flutter build apk --profile --target-platform android-arm64 \
  --target lib/main.dart --dart-define=AUTH_EMULATOR=false
```

Profile dipakai untuk APK pratinjau yang lebih kecil daripada debug. Signing untuk distribusi akhir, ABI tambahan, dan pengujian pembaruan APK belum selesai.

## Catatan hasil sebelumnya

Pemeriksaan kebijakan password tambahan melalui HTTP Dart menghalangi daftar pada percobaan produksi. Preflight itu dihapus; form memvalidasi input dan Firebase Auth tetap menjadi validator server untuk create/link. Sesudah perubahan ini, seluruh alur produksi lulus.

Percobaan gabungan dengan named production app sebelumnya mengalami kegagalan jaringan/token saat cleanup. Pembersihan satu fixture sintetis dari percobaan lama belum terkonfirmasi (`auth-device-prior-failure.log`). Fixture pada rangkaian produksi terakhir dihapus dan dikonfirmasi. Tidak ada data agenda/keuangan yang ditulis oleh rangkaian ini.

Emulator Auth lokal dihentikan dan reverse port 9096 khusus pengujian dilepas setelah selesai. APK profile normal tetap terpasang pada HP. Tidak ada panggilan model tambahan dan tindak lanjut CPU tetap ditunda.
