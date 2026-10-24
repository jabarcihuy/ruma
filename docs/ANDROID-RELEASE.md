# APK release Ruma

22 Oktober 2026. Pengguna meminta penerapan produksi dan APK release setelah perapian UI.

## Signing

Build release memakai alias `ruma-release` dengan keystore PKCS12 RSA 3072-bit khusus Ruma. Konfigurasi Gradle membaca `android/key.properties`; tidak lagi menandatangani release memakai kunci debug. Debug build tetap memakai signing debug.

File privat yang perlu dibackup secara aman bersama-sama:

- `.local/signing/ruma-release.jks`
- `android/key.properties`

Keduanya diabaikan `.gitignore`; akses file dibatasi ke pemilik. Jangan masukkan keduanya ke APK, PDF, repository, atau folder yang dibagikan. Kehilangan kunci dapat menghalangi pembaruan APK yang telah dipasang dengan tanda tangan ini.

## Build

Dari direktori project, gunakan:

```bash
source .local/android.env
flutter build apk --release
```

Gunakan tahap pub/regenerasi bawaan Flutter ketika beralih dari debug/integration test ke release. Pada SDK lokal, `--no-pub` melewati regenerasi registrant sehingga sisa plugin `integration_test` dapat membuat kompilasi release gagal. Percobaan pertama tersimpan di `docs/qa/release/build.log`; hasil perbaikan di `build-confirmation.log`.

Tanpa `AUTH_EMULATOR`, APK menggunakan Firebase produksi `mobile-app-3479f`. APK universal memuat ABI ARM32, ARM64 dan x86_64 sehingga dapat dipasang di HP dan VM yang sesuai. Artefak final dan checksum dicatat di `docs/qa/release/verification.json`.

## Pemasangan

APK release dengan kunci baru tidak dapat langsung memperbarui APK debug lama yang menggunakan package ID sama (`id.ruma.app`). Android akan menolak perbedaan tanda tangan. Sebelum menghapus versi debug pada HP, pastikan akun sudah ditautkan ke email dan kredensial masuk dapat digunakan kembali; akun sementara dapat kehilangan akses. Data draf lokal juga dapat hilang saat uninstall. Tahap ini tidak menghapus atau memasang aplikasi pada HP pengguna.

Untuk pembaruan berikutnya, pakai kunci release yang sama serta naikkan version code. Versi awal ini tetap `0.1.0+1`.

## Produksi dan verifikasi

Rules wishlist menerima `iconId` opsional yang tervalidasi untuk tujuan tabungan; akses per UID dan batas dana tetap. Tidak mengubah IAM, billing, Worker atau jadwal FCM karena tahap ini hanya mengubah UI dan validasi ikon tabungan.

Bukti publikasi, uji cloud sintetis, cleanup, sertifikat APK dan hasil peluncuran akan dicatat di `docs/qa/release/` serta `docs/qa/wishlist/`. Ini adalah build sideload; belum publikasi Google Play dan belum klaim uji semua fitur pada release.

## Hasil akhir

Rules produksi aktif dan exact readback setelah reload cocok dengan kandidat. Lima kelompok uji SDK produksi lulus; dua akun dan 21 dokumen sintetis dibersihkan. Build release selesai dalam 125,6 detik setelah regenerasi registrant diperbaiki.

Artefak: `output/apk/ruma-0.1.0-release.apk`, 62.302.774 byte (62,3 MB), SHA-256 `420395562bc501829a5e9c5ef56abfb299e43faf94be70d8516cddd7dc394aed`. Tanda tangan APK v2 valid dengan sertifikat Ruma; manifest/package VM tidak memiliki flag DEBUGGABLE. Arsip mapping R8: `output/apk/ruma-0.1.0-r8-mapping.txt`.

APK exact ini dipasang di VM API 35: hash instalasi sama, cold launch Status ok, Firebase berhasil inisialisasi, layar sambutan tampil dan tidak ditemukan FATAL EXCEPTION pada log runtime yang diperiksa. Uji SDK menggunakan harness debug; pemeriksaan release terbatas pada instalasi dan cold launch. HP pengguna tidak diubah. Perintah uninstall awal VM mengembalikan DELETE_FAILED_INTERNAL_ERROR, tetapi install berhasil dan hash APK terpasang cocok.

Peringatan migrasi KGP dari plugin Firebase dan filesystem watcher tercatat di log; tidak menggagalkan build akhir. Tidak ada pemanggilan AI/FCM, perubahan IAM/billing, atau publikasi Google Play.
