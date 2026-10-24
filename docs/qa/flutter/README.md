# Bukti fondasi Flutter — 19 Oktober 2026

Hasil terakhir: analisis tanpa temuan, tiga pengujian unit/widget lulus, alur Auth Emulator dan Firebase produksi lulus pada HP Android 36. APK profile normal berhasil dipasang dan dibuka.

## Bukti utama

- [Analisis](analyze.log) dan [unit/widget](widget-tests.log).
- [Auth Emulator: hasil](auth-emulator-results.json) dan [log perangkat](auth-emulator-device.log).
- [Firebase produksi: hasil](auth-production-results.json) dan [log perangkat](auth-production-device.log).
- [Build APK normal](build-preview.log), [instalasi](install-preview.log), [cold launch](launch-preview.log), dan [inspeksi/hash APK](apk-inspection.json).
- [Screenshot APK normal pada HP](preview-device.png).
- [Beranda](production-03-home.png), [profil akun sementara](production-04-profile-temporary.png), [form daftar](production-05-signup.png), dan [profil terdaftar](production-06-profile-registered.png) dari integration test produksi.

Nama Naya dan email example.invalid adalah fixture sintetis. Hasil terakhir mengonfirmasi fixture emulator/produksi dihapus. Skrip tidak mencetak password atau ID token; input UI diprogram melalui TestTextInput. Screenshot integration test memotret surface Flutter, sedangkan preview-device.png menyertakan status bar Android asli.

## Riwayat kegagalan

Log auth-device.log/auth-device-prior-failure.log dan auth-production-policy-failure.log adalah hasil sebelum perbaikan, bukan hasil akhir. Percobaan awal terkendala konfirmasi pemasangan, koneksi emulator, client input tes, konversi screenshot, dan preflight kebijakan password. Setiap penyebab ditindaklanjuti sebelum hasil terakhir di atas.

Satu pembersihan fixture dari percobaan named-app produksi lama belum terkonfirmasi karena error user-token-expired. Status ini disimpan pada setup-audit.json dan laporan fondasi; jangan menyamakan cleanup terakhir yang lulus dengan bukti seluruh percobaan lama bersih.

Tidak menguji ledger, agent dalam Flutter, FCM, offline, process kill, keyboard Android asli secara menyeluruh, atau APK release. Tidak ada panggilan model/benchmark CPU pada tahap ini. Laporan dan langkah berikutnya: [FLUTTER-FOUNDATION.md](../../FLUTTER-FOUNDATION.md).
