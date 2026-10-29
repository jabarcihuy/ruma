# Lingkungan pengujian lokal Ruma

25 Oktober 2026. Lingkungan dipulihkan pada mesin saat ini untuk melanjutkan audit sistem dan usability. Status mesin lama di dokumen lain tetap merupakan riwayat.

## Toolchain

- Flutter 3.47.8 / Dart 3.13.7, melalui instalasi FVM milik pengguna.
- Android SDK pada `$HOME/Android/Sdk`: platform 36 untuk aplikasi, platform 34/35 yang diminta plugin, Build Tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1.
- Java menggunakan JBR 25.0.3 bawaan Android Studio. Tidak memasang JDK global tambahan.
- Android Emulator 37.2.12, system image Android API 37 Google Play x86_64 yang sudah dipasang pengguna.
- AVD terpisah `Ruma_Audit_API_37`: layar 720×1600, density 320, RAM 1536 MB, dua core, kamera nonaktif. AVD `Medium_Phone_API_37.0` milik pengguna tidak diubah.
- KVM terverifikasi dapat dipakai melalui `emulator -accel-check`.
- Node 24.22.1, Firebase CLI 15.34.1 lokal di `.tools/test-runtime/`, Firestore Emulator 1.22.0.
- Engine Impeccable 0.1.5 sudah dapat menjawab `engine-probe`. Tidak memasang skill baru.

`android/local.properties`, `.local/android.env`, dan path keystore pada `android/key.properties` telah disesuaikan dari mesin sebelumnya. Konfigurasi privat tetap diabaikan Git; kunci, alias dan password signing tidak diganti. Dependency Flutter dan backend dipulihkan sesuai lockfile; tidak menaikkan versi dependency aplikasi.

Build pertama menemukan output cache yang masih menunjuk `/home/ael/...`. `flutter clean` dan regenerasi dependency dijalankan; cache proyek `android/.gradle` lama dipindahkan ke `.local/qa-20261025/old-project-gradle`. APK release di `output/apk/` tetap tersedia. Cache ini tidak perlu dipindahkan ulang pada build normal berikutnya.

## Menjalankan ulang

Dari root proyek:

```bash
source .local/android.env
flutter analyze
flutter test
npm --prefix backend test
```

Firebase Emulator memakai project sintetis `demo-ruma`, Auth port 9096 dan Firestore port 8086. Jalankan pada terminal terpisah:

```bash
source .local/android.env
JAVA_TOOL_OPTIONS='-Xmx512m' .tools/test-runtime/node_modules/.bin/firebase \
  emulators:start --only auth,firestore --project demo-ruma --config firebase.json
```

AVD uji memakai ADB default port 5037. Ini berbeda dari script lama `scripts/start-android-emulator.sh` yang menunjuk `Ruma_API35` dan port 5038. Untuk profil yang baru:

```bash
source .local/android.env
emulator -avd Ruma_Audit_API_37 -no-window -no-audio -no-snapshot \
  -memory 1536 -cores 2 -gpu host -feature -Vulkan
```

Hilangkan `-no-window` jika ingin melihat jendela emulator. Pada audit lanjutan, `-gpu host -feature -Vulkan` berhasil memakai Mesa Intel OpenGL; ini menggantikan mode software awal. Jika driver host bermasalah, mode software yang pernah diuji adalah `-gpu swiftshader -feature -Vulkan`. Jangan menjalankan dua instance AVD yang sama.

Untuk build aplikasi uji yang terhubung ke Firebase lokal:

```bash
source .local/android.env
flutter build apk --debug --dart-define=AUTH_EMULATOR=true \
  --dart-define=AUTH_EMULATOR_HOST=10.0.2.2 \
  --dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2
```

`10.0.2.2` adalah alamat host dari Android Emulator. Build tanpa `AUTH_EMULATOR=true` memakai konfigurasi Firebase produksi. Pengujian setup tidak memerlukan login CLI Firebase, secret provider AI, atau akses akun produksi.

Untuk memulihkan dependency backend atau Firebase CLI di masa mendatang:

```bash
npm --prefix backend ci --ignore-scripts
npm install --prefix .tools/test-runtime --save-exact --ignore-scripts firebase-tools@15.34.1
```

## Verifikasi

- Analyzer: bersih.
- Tes Flutter: 78 lulus.
- Backend: 14 tes utama dan 21 tes tambahan lulus.
- Rules wishlist/tabungan: 13 tes lulus; regresi agenda, finance, batch, notifikasi, workspace dan profil/seri: 51 tes lulus.
- Firebase Auth/Firestore Emulator: berhasil menyala di loopback pada project `demo-ruma`.
- AVD: berhasil cold boot dan melaporkan `sys.boot_completed=1`.
- APK debug x86_64 untuk `integration_test/auth_flow_test.dart`: berhasil dibangun setelah cache lama dibersihkan.
- Uji SDK/UI autentikasi pada AVD API 37: lulus. Akun sementara, penautan UID ke email, nama profil, pembatalan logout, logout/login, password salah, isian tetap setelah gagal, pendaftaran langsung dan navigasi lima tab diperiksa. Akun fixture dihapus; enam screenshot dan laporan `auth/auth-emulator-results.json` tersedia di folder bukti lokal.
- Uji autentikasi memakai `RumaApp` tanpa repository Firestore pada shell. Ini belum menjadi walkthrough penuh CRUD agenda, transaksi, tabungan, atau Asisten di Android. Perilaku domain/widget dan Rules terkait diperiksa pada suite terpisah di atas.

Runner `test_driver/integration_test.dart` sekarang menerima `RUMA_QA_DIR`, seperti runner lain di proyek. Contoh uji autentikasi setelah Firebase Emulator dan AVD menyala:

```bash
source .local/android.env
RUMA_QA_DIR=.local/qa-20261025/auth flutter drive -d emulator-5554 \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/auth_flow_test.dart \
  --dart-define=AUTH_EMULATOR=true \
  --dart-define=AUTH_EMULATOR_HOST=10.0.2.2
```

Gunakan serial dari `adb devices` jika berbeda. `RUMA_QA_DIR` menghindari penimpaan screenshot/laporan pengujian lama; tanpa variabel ini tujuan runner tetap `docs/qa/flutter`.

Log dan screenshot sesi ini disimpan di `.local/qa-20261025/`, tidak masuk Git. Pengujian Rules tidak mengubah snapshot QA historis yang sudah dilacak. Chrome yang belum ditemukan oleh `flutter doctor` tidak diperlukan untuk target Android ini.

AVD, Firebase Emulator dan daemon Gradle dihentikan setelah pengujian. AVD API 37 dengan image Google Play dan render software masih memakai sekitar 5 GB memori host saat uji; mesin mengalami tekanan memori dan frame lambat. Hasil pengujian ini membuktikan fungsi, bukan performa pada HP pengguna. Jalankan build dan emulator bergantian bila memori terbatas.

Build tetap mengeluarkan pemberitahuan migrasi Kotlin dari plugin Firebase dan peringatan API native Java; keduanya tidak menggagalkan hasil akhir. Tidak menaikkan dependency aplikasi untuk menghilangkan peringatan tersebut. Pengujian setup tidak memanggil AI/FCM dan tidak mengubah produksi; belum membuktikan usability pada mahasiswa atau notifikasi/baterai pada HP fisik.
