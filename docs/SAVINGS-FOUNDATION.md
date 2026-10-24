# Fondasi data tabungan Ruma

21 Oktober 2026. Tahap pertama penggantian anggaran menjadi tabungan. Kelanjutan implementasi UI dicatat di SAVINGS-UI.md. Agenda tetap dipertahankan. Perubahan ini menyiapkan model, repository dan kandidat Rules; halaman tabungan, diagram lingkaran dan tools agent belum dihubungkan.

## Perilaku

- Tujuan menyimpan nama, target rupiah bulat dan tanggal target opsional. Target Rp1–Rp1 miliar, nama 1–80 karakter, tanggal kalender 2000–2100. Tujuan yang tenggatnya lewat tetap dapat diedit.
- Tujuan baru dimulai dari Rp0. Mengubah nama, target atau tanggal tidak mengubah dana yang sudah disisihkan.
- Setoran dan penarikan menyimpan nominal Rp1–Rp1 miliar, tanggal paling lambat hari ini dalam WIB, dan catatan maksimal 1.000 karakter.
- Setoran mengurangi uang tersedia dan menambah dana tujuan. Penarikan membalik perpindahan ini. Keduanya tidak membuat transaksi pemasukan/pengeluaran, tidak mengubah saldo tercatat dan tidak masuk ringkasan pengeluaran bulanan.
- Uang tersedia = saldo tercatat − total tabungan. Setoran tidak boleh melebihi uang tersedia; penarikan tidak boleh melebihi dana tujuan. Batas tersedia berlaku pada seluruh tujuan, bukan per tujuan saja.
- Progres dibatasi visual 100%, tetapi nominal sesungguhnya tetap disimpan ketika dana melebihi target. Sisa target minimal Rp0. Menurunkan target di bawah dana yang ada diperbolehkan.
- Saldo tercatat dapat berkurang karena transaksi atau koreksi lama. Jika kemudian lebih kecil dari tabungan, uang tersedia ditampilkan sebagai nilai negatif; setoran baru ditolak dan penarikan tetap diperbolehkan. Tahap ini tidak menambahkan pembatasan baru pada CRUD transaksi yang sudah ada.
- Riwayat perpindahan dan receipt bersifat append-only. Penghapusan tujuan, edit/hapus perpindahan, dan urungkan belum termasuk tahap ini.

Contoh desain: saldo Rp820.000, tabungan Rp400.000, tersedia Rp420.000. Setoran Rp100.000 membuat tabungan Rp500.000 dan tersedia Rp320.000; saldo Rp820.000 dan pengeluaran Rp1.180.000 tetap.

## File dan penyimpanan

- `lib/data/savings.dart`: input, tujuan, perpindahan, mutasi, perhitungan progres/batas dana dan rekonsiliasi snapshot.
- `lib/data/savings_repository.dart`: repository Firestore konkret, mengikuti pola repository keuangan yang sudah ada. Tidak menambah paket atau database lokal.
- `users/{uid}/savingsGoals/{goalId}`: metadata tujuan, versi dan saldo alokasi tujuan.
- `users/{uid}/savingsMovements/{operationId}`: setoran/penarikan immutable. ID mengikuti ID operasi agar retry tidak membuat perpindahan kedua.
- `users/{uid}/state/savings`: total alokasi tabungan, versi dan ID operasi terakhir.
- `users/{uid}/state/core`: format yang lama dipertahankan. Setiap mutasi tabungan menaikkan `financeRevision` dan versi core, mempertahankan `agendaRevision`, saldo, lifetime income dan expense.
- `users/{uid}/operations/{operationId}`: receipt dengan jenis savings_goal_create/update atau savings_deposit/withdrawal, target dan request key.

Satu transaksi Firestore membaca receipt, core, tujuan dan ringkasan tabungan sebelum menulis tujuan, ringkasan, core, receipt serta perpindahan bila ada. Versi tujuan diperiksa saat edit/setor/tarik. ID operasi dan isi permintaan yang sama menjadi retry idempotent; memakai ID yang sama dengan isian berbeda ditolak. Versi usang tidak menimpa tujuan yang sudah berubah. Semua pembacaan mengharuskan server; tidak ada antrean tulis offline.

Baca snapshot membandingkan `financeRevision` sebelum/sesudah query, menjumlahkan seluruh riwayat per tujuan dan mencocokkannya dengan saldo tujuan serta total alokasi. Ringkasan yang tidak cocok ditolak. Riwayat diurutkan tanggal menurun dan ID sebagai urutan stabil untuk tanggal sama; ID bukan waktu pembuatan. Pagination internal memakai halaman 100 dokumen. Batas tugas kuliah: maksimal 1.000 tujuan dan 1.000 perpindahan per akun; melebihi batas ditolak secara eksplisit, tidak ditampilkan sebagian. Perlu pagination riwayat dan rekonsiliasi server sebelum meningkatkan batas.

Repository terikat UID saat dibuat. Perubahan/sesi logout menolak operasi lama; pembacaan setelah query/commit juga memeriksa sesi. Rules membatasi baca/query/tulis ke pemilik UID. Dua akun tidak berbagi dana tersedia.

## Kandidat Rules dan status produksi

`config/firebase/firestore.savings.rules` diturunkan dari Rules final-stages. Ia menambah skema ketat, keterkaitan dokumen atomik, pemeriksaan saldo sumber/tujuan, metadata/versi dan hak akses tabungan. Aturan agenda, keuangan lama, profil, Asisten dan notifikasi dipertahankan; suite regresi dapat memilih kandidat dengan `RUMA_SAVINGS_RULES=1`.

`firebase.savings.json` hanya konfigurasi kandidat untuk emulator/publikasi di tahap berikutnya. **firebase.json dan Rules produksi tidak diganti**. UI belum membuat SavingsRepository, jadi aplikasi produksi tetap berjalan dengan perilaku lama. Anggaran lama dan field ringkasannya tidak dihapus atau dimigrasi menjadi uang tabungan: batas belanja bukan uang yang benar-benar disisihkan.

Tidak ada deployment Worker, IAM, billing, panggilan AI/FCM atau penulisan produksi dalam pekerjaan ini. Publikasi kandidat ke produksi membutuhkan persetujuan terpisah ketika UI tabungan siap diuji.

## Verifikasi

Bukti tersimpan di `docs/qa/savings/`:

- `unit-tests.log`: 10 tes baru, validasi, perhitungan, batas dana, retry key, progres dan rekonsiliasi.
- `flutter-tests.log`: 67 tes Flutter lama+baru lulus.
- `rules-results.json` / `rules-tests.log`: 12 skenario tabungan lulus, termasuk dana bersama antar tujuan, overdraw, pemalsuan angka, dokumen tidak lengkap, immutability, retry, concurrency, dan isolasi UID.
- `rules-regression.log`: 51 tes Rules fitur lama lulus terhadap kandidat tabungan. Penolakan PERMISSION_DENIED dalam skenario negatif adalah hasil yang diharapkan.
- `analyze.log`, `android-sdk.log`, `android-results.json`, `verification.json`: pemeriksaan final dan status SDK Android. Analyzer bersih. Enam kelompok skenario SDK Android lulus: inisialisasi core, setoran/retry, rollback validasi, edit/penarikan dengan ledger dan anggaran utuh, offline tanpa antrean, serta pergantian/isolasi akun. Status akhir dirangkum di verification.json.

Fixture Firestore/Auth pada demo-ruma dibersihkan setelah uji; reverse port dilepas. APK normal sebelumnya (ruma-ai-output-guard.apk) dipasang kembali di VM, bukan APK harness tabungan. Tidak membuat APK produksi baru karena UI belum dihubungkan.

Uji Rules menggunakan fixture sintetis pada demo-ruma lokal. Suite Android menguji repository Dart nyata dan SDK Firebase native; bukan koneksi Firebase produksi. Tidak mengklaim pengujian UI tabungan karena halaman belum diimplementasikan.

## Menjalankan ulang

Flutter memerlukan JDK17 sesuai `.local/android.env`; Firebase emulator memakai JDK27. Jalankan emulator Auth 9096 dan Firestore 8086 pada loopback project demo-ruma, lalu:

```bash
flutter analyze
flutter test
FIRESTORE_EMULATOR_HOST=127.0.0.1:8086 node --test backend/tests/savings.rules.test.mjs
```

Untuk regresi: `RUMA_SAVINGS_RULES=1 RUMA_FINAL_STAGES_RULES=1 RUMA_NOTIFICATIONS_RULES=1 RUMA_AGENT_RULES=1 RUMA_FINANCE_RULES=1 RUMA_QA_DIR=docs/qa/savings FIRESTORE_EMULATOR_HOST=127.0.0.1:8086 node --test --test-concurrency=1 backend/tests/{agenda,finance,batch,notifications,assistant-memory,final-stages}.rules.test.mjs`. Jalankan secara serial karena suite berbagi emulator dan membersihkan fixture. Jalankan suite tabungan kembali setelah regresi untuk memuat kandidat sebelum Android.

Uji Android: `flutter drive --driver=test_driver/savings_test.dart --target=integration_test/savings_foundation_test.dart -d emulator-5554 --dart-define=AUTH_EMULATOR=true`, setelah reverse port 8086/9096 dan VM siap. Jangan memakai APK integration test sebagai APK normal.

## Berikutnya

Implementasikan daftar/detail tujuan dan form setor/tarik sesuai Figma dengan repository yang sama; tampilkan total tabungan/uang tersedia di Keuangan dan Beranda. Setelah UI siap, minta persetujuan publikasi Rules dan uji produksi terbatas. Diagram lingkaran membaca pengeluaran yang sudah ada; tools tabungan untuk agent menyusul. Data dan UI anggaran tetap dipertahankan sampai penggantinya selesai.
