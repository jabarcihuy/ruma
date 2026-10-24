# Android Emulator untuk Ruma

20 Oktober 2026. Sistem Android berhasil dipasang pada 19 Oktober; pengguna meminta jeda setelah download. Pada 20 Oktober pengguna meminta pengujian di VM dilanjutkan, dan perangkat virtual berhasil boot serta menjalankan Ruma.

## Konfigurasi yang sudah berjalan

- AVD: `Ruma_API35`, profil Pixel 5.
- Android 15 / API 35, Google APIs x86_64, system image revision 9.
- Android Emulator 37.1.11, KVM terdeteksi usable.
- RAM 2048 MB, 2 core, GPU auto, layar 1080 x 2340 / density 440.
- Partisi data 2 GB; kamera dan audio dimatikan melalui launcher.
- Perkiraan pemakaian disk terukur: system image 3.5 GiB, data AVD 1.6 GiB, binary emulator 821 MiB. Cache build dan APK dihitung terpisah.
- Zona waktu Asia/Jakarta. Pengaturan `stylus_handwriting_enabled=0` pada AVD menghindari tutorial stylus Gboard saat uji keyboard standar. Pengaturan ini hanya mengubah perangkat virtual.

Konfigurasi berada di `/home/ael/.android/avd/Ruma_API35.avd/config.ini`. Tidak memasang seluruh Android Studio atau VM desktop terpisah.

## Menjalankan kembali

Buka **Ruma Android Emulator** dari menu aplikasi Linux. Launcher desktop: `/home/ael/.local/share/applications/ruma-android-emulator.desktop`.

Alternatif dari direktori proyek:

```bash
./scripts/start-android-emulator.sh
```

Script memakai SDK pada `.local/android.env` dan ADB port 5038; serial default perangkat virtual pertama adalah `emulator-5554`. Jalankan satu instance AVD yang sama, bukan dua sekaligus.

## APK dan hasil uji

APK normal khusus emulator: `output/apk/ruma-emulator-preview.apk`, target `lib/main.dart`, mode debug x86_64, sekitar 151 MiB. Sudah dipasang dengan hasil Success dan cold launch Status ok. Ini berbeda dari APK profile ARM64 untuk HP; jangan menggantikan file ARM64 dengan APK emulator.

Emulator dibiarkan terbuka dengan app normal setelah pengujian. Backend Firebase emulator lokal telah dibersihkan dan dihentikan. Pengguna boleh masuk ke akun melalui APK normal sendiri; pengujian otomatis tidak memakai kredensial pengguna.

Lihat [laporan pengujian](EMULATOR-TEST-REPORT.md), `qa/android-emulator/boot.log`, dan `qa/ui-copy-device/normal-install.log`. Bukti teknis pengujian memakai Firebase lokal `demo-ruma`; tidak memanggil AI produksi.
