# Agenda manual — tahap implementasi

19 Oktober 2026. Cakupan tahap ini: kuliah/kegiatan sekali jalan, tugas belum terjadwal, deadline, durasi, prioritas, catatan, detail, edit, selesai/buka kembali dan hapus dengan konfirmasi. Pengulangan mingguan, saran slot AI, pengingat dan urungkan tetap mengikuti tahap selanjutnya; bukan dihapus dari rancangan.

## Data dan jalur simpan

Flutter menggunakan cloud_firestore 7.0.0 dan Firebase Auth. Tidak menambahkan SQLite. Semua path berasal dari UID sesi aktif: users/{uid}/agenda, state/core dan operations. Status akun lama, listener dan hasil async dibuang ketika UID berubah. Form akun lama ditutup sebelum konteks akun baru dipakai.

Satu operasi menyimpan agenda, kenaikan agendaRevision, dan receipt operasi dalam satu Firestore transaction. ID agenda stabil selama form dibuka; retry isian yang sama memakai ID operasi sama. Waktu tersimpan UTC, ditampilkan WIB (Asia/Jakarta). Durasi 5–720 menit; tanggal/jam akhir diturunkan dari durasi. Tugas boleh tanpa waktu. Kuliah harus punya waktu. Deadline tidak boleh sebelum akhir kegiatan.

Pemeriksaan bentrokan menggunakan interval [mulai, selesai), mengabaikan agenda selesai/dibatalkan/terhapus. Query agenda dibaca di antara dua pembacaan revisi core; transaksi memeriksa revisi tersebut dan versi target sebelum menulis. Jika data berubah di perangkat lain, simpan ditolak tanpa menimpa versi baru. Tidak ada query atau panggilan AI di callback transaksi.

Penghapusan memakai deletedAt (soft delete), bukan menghapus dokumen permanen dari aplikasi. Tombstone tidak dapat diedit kembali pada tahap ini. Receipt append-only mencatat jenis tindakan, target, versi dan identitas permintaan untuk retry; belum menyediakan tombol urungkan.

## Aturan rollout

`config/firebase/firestore.agenda.rules` adalah Rules khusus tahap agenda. Hanya akun pemilik boleh membaca/menulis path yang divalidasi. Dokumen agenda, core dan receipt wajib konsisten dalam satu commit; operasi agenda tidak boleh mengubah saldo atau revisi keuangan. Path keuangan, pengingat, chat, perangkat dan usage tetap ditolak.

Kandidat lama `config/firebase/firestore.rules` dipertahankan untuk regresi potongan create-batch AI/keuangan. Kandidat itu tidak dipakai sebagai Rules rollout agenda. firebase.json menunjuk file agenda khusus, agar fitur yang belum tersambung tidak ikut dibuka.

Rules dipublikasikan ke mobile-app-3479f pada 19 Oktober 2026, sekitar 21:21 WIB, setelah pengguna mengizinkan publikasi dan uji sintetis. Isi editor dibandingkan dengan file lokal sebelum Publish. SHA-256 dan bukti Console: `qa/agenda/deployment.json` serta `rules-published.jpg`. Tidak mengubah billing, IAM, atau Worker.

## Offline dan batas tahap

Commit hanya dilakukan online dan hasil server yang dikonfirmasi yang disebut tersimpan. Aplikasi memakai memory cache SDK, tanpa persistence disk, untuk tahap ini. Pembacaan daftar selalu dari server; menonaktifkan jaringan tidak mengantrekan commit otomatis. Isian tetap ada selama form terbuka, dan meninggalkan isian berubah meminta konfirmasi. Pemulihan draf setelah process kill belum dibuat dan tidak diklaim tersedia.

Untuk tahap tugas kuliah ini, pembacaan agenda aktif dibatasi 500 item; jika melebihi batas, aplikasi menolak melanjutkan dengan pesan dan tidak diam-diam memotong daftar/pemeriksaan bentrokan. Query rentang dan ekspansi seri menjadi pekerjaan berikutnya sebelum batas dinaikkan. Zona waktu lain dan seri mingguan belum ditawarkan sebagai kontrol yang seolah sudah berfungsi.

## Bukti verifikasi

- `qa/agenda/rules-results.json` dan `rules-tests.tap`: 12 skenario Rules lokal, termasuk isolasi akun, rollback, metadata/receipt immutable, soft delete, validasi input dan revisi serentak.
- `qa/agenda/widget-tests.log`: pengujian lama dan baru, termasuk batas waktu/bentrokan, pergantian akun dengan hasil async terlambat, retry dan tampilan 320px dengan teks 200%.
- `qa/agenda/analyze.log`: pemeriksaan analisis kode.
- `qa/agenda/device-results.json` dan `device-test.log`: suite Android SDK + UI pada HP USB Android 36 dengan emulator lokal lulus. Mencakup CRUD, selesai/buka kembali, batal hapus, bentrokan, waktu bersebelahan, retry, versi usang, jaringan dimatikan dan isolasi akun. Lima screenshot tersimpan; form, detail dan timeline diperiksa visual.
- `qa/agenda/cloud-results.json` dan `cloud-device-test.log`: suite terpisah pada HP yang sama dengan Firebase **produksi** lulus. Tambah/baca ulang, edit status, soft delete, retry tanpa duplikasi dan penolakan akses tanpa sesi/akun lain terbukti melalui Flutter Android SDK.
- `qa/agenda/cloud-cleanup.json`: dua akun Auth sintetis dihapus melalui SDK; lima dokumen pada UID fixture (agenda, core, tiga receipt) dihapus dengan service account Datastore User yang sudah ada. Ketiga subkoleksi pada kedua UID diverifikasi kosong. Tidak memindai atau menghapus data akun lain. Catatan satu fixture Auth historis pada laporan fondasi tetap terpisah; tahap ini tidak mengklaim cleanup historis tersebut selesai.
- `qa/agenda/analyze.log`: analisis bersih; `widget-tests.log`: 10 pengujian lulus; `rules-results.json`: 12 skenario lulus. Pesan PERMISSION_DENIED pada log produksi adalah hasil pengujian negatif yang diharapkan.
- Emulator lokal dibersihkan/dihentikan; reverse port 9096/8086 dan server sementara 8971 dilepas setelah pengujian. Tidak ada panggilan model AI atau benchmark CPU.

## Berikutnya

Setelah agenda ini terverifikasi dan Rules produksi aktif, lanjutkan transaksi/anggaran manual dan rangkuman keuangan. Saran waktu/agent dan notifikasi dihubungkan setelah kedua alur manual memakai penyimpanan yang sama. Tidak ada panggilan model atau benchmark CPU dalam tahap agenda ini.

## Menjalankan pemeriksaan kembali

`flutter analyze` dan `flutter test` tidak menulis produksi. Suite `integration_test/agenda_flow_test.dart` hanya mengizinkan `AUTH_EMULATOR=true` (demo-ruma); Auth 9096 dan Firestore 8086 diteruskan ke HP melalui ADB reverse.

Suite produksi `integration_test/agenda_cloud_test.dart` sengaja memerlukan `AGENDA_LIVE_TESTS=true` dan `AUTH_EMULATOR=false`. Jangan jalankan sebagai pengujian rutin: ia membuat dua akun sintetis dan dokumen produksi. Driver `test_driver/agenda_cloud_test.dart` merekam UID, tanpa token. Cleanup terbatas `backend/tests/agenda-cloud-cleanup.mjs` hanya menerima manifest lulus dengan kedua akun sudah dihapus, tepat dua UID valid, koleksi agenda/state/operations dan flag `RUMA_CLEAN_AGENDA_FIXTURES=mobile-app-3479f`; tidak membuka izin baru. Pemakaian ulang harus masuk cakupan persetujuan uji produksi.

## APK pratinjau

`output/apk/ruma-agenda-preview.apk` dibangun dari `lib/main.dart`, mode profile, target Android ARM64, Firebase produksi (`AUTH_EMULATOR=false`). Ukuran 40.3 MB (desimal); bukan integration-test harness atau APK release pengumpulan. Build berhasil, install USB berhasil, cold launch Status ok dan topResumedActivity id.ruma.app diverifikasi. Screenshot normal `qa/agenda/06-normal-preview.png` memperlihatkan halaman awal setelah semua akun fixture keluar/dihapus.

SHA-256, ABI aplikasi, library native yang ikut dikemas dan hasil pemeriksaan secret ada di `qa/agenda/apk-inspection.json`. Exact-value scan key AI dan PEM server aktif (UTF-8/UTF-16) tidak menemukan kecocokan ataupun file privat dalam ZIP APK; ini pemeriksaan terbatas, bukan audit keamanan menyeluruh. Warning KGP dari plugin Firebase serta unchecked operations Firestore tidak menggagalkan build. Signing release pengumpulan belum disiapkan.

Perintah build ulang:

```bash
source .local/android.env
flutter build apk --profile --target-platform android-arm64 --target lib/main.dart --dart-define=AUTH_EMULATOR=false
```
