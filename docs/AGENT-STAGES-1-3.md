# Ruma — pengerjaan agent tahap 1–3

Tanggal: 20 Oktober 2026. Pengguna meminta menjalankan tiga tahap: saran waktu, pembacaan agenda/uang, serta edit/hapus data lama dengan tinjauan dan urungkan.

**Selesai dan aktif:** implementasi lokal, Rules produksi, Worker versi `f0bc9c39`, dan uji empat panggilan model nyata lulus. Dua akun Auth serta sepuluh dokumen sintetis sudah dibersihkan; APK normal terbaru kembali terpasang di emulator.

## 1. Rekomendasi waktu

- Rentang kesediaan pengguna dapat dipilih di Asisten (awal 08.00–21.00 WIB). Rentang ini hanya berlaku pada sesi berjalan; belum menjadi preferensi tersimpan.
- AI mengusulkan tanggal/durasi. Jam eksplisit dari pesan dipertahankan; tanpa jam, aplikasi mencari slot secara deterministik dari agenda terbaru.
- Hingga tiga agenda dalam draf gabungan dipertimbangkan bersama, termasuk yang jamnya disebut eksplisit. Slot tidak boleh tumpang tindih dan harus selesai sebelum deadline jika diberikan.
- Saran tetap draf. Tanggal, jam, durasi dan deadline bisa disunting lewat form yang sudah ada. Jika tidak ada slot, tugas tetap belum dijadwalkan dan dinyatakan demikian.
- Saat simpan, bentrokan dan revisi diperiksa lagi. Data yang berubah tidak dipindahkan otomatis menggunakan persetujuan lama.

## 2. Pembacaan agenda dan uang

- Model memilih tool `read_records`: agenda satu tanggal, laporan satu bulan, atau riwayat satu bulan/kategori.
- Flutter menjalankan pembacaan melalui repository milik UID aktif. Model tidak menerima salinan ledger atau jawaban database; aplikasi menyusun hasil dengan angka yang sudah diverifikasi repository.
- Laporan memuat pemasukan, pengeluaran, kategori, anggaran/sisa dan saldo tercatat. Cakupan catatan dijelaskan; tidak mengaku mengetahui saldo bank/dompet.
- Daftar agenda maksimal 20 item dan riwayat maksimal 20 terbaru; jumlah keseluruhan dan indikator daftar dipersingkat tetap ditampilkan. Batas pembacaan repository tetap 500 agenda aktif / 1.000 dokumen transaksi per bulan, dengan penolakan eksplisit jika terlampaui.
- Pertanyaan baca tidak membuat draf atau operasi tulis. Tidak ada tool URL, SQL, path database, atau UID pilihan model.

## 3. Edit/hapus dan urungkan

- Satu catatan lama per tinjauan; penambahan tetap maksimal tiga agenda + tiga transaksi. Ini memakai ulang operasi CRUD atomik yang sudah ada.
- `prepare_change` memakai nama persis dan tanggal catatan lama. Transaksi memerlukan tanggal untuk menentukan bulan pencarian. Nol hasil atau beberapa hasil tidak menebak target.
- Agenda dapat diubah judul, tanggal/jam, durasi, deadline, atau status. Transaksi dapat diubah keterangan, nominal, kategori, atau tanggal. Jenis pemasukan/pengeluaran dan pengosongan deadline/jam belum menjadi patch AI; gunakan form manual jika perlu.
- Tinjauan menampilkan sebelum/sesudah; penghapusan menampilkan catatan yang tepat dan tombol persetujuan jelas. Membuka atau membatalkan draf tidak menulis data.
- Simpan memerlukan versi target yang cocok. Retry memakai ID operasi tetap dan receipt untuk mencegah duplikasi. Hasil belum pasti mengunci draf agar tidak diedit atau dibuang sebelum diperiksa ulang.
- Urungkan edit mengembalikan nilai sebelumnya; urungkan hapus memulihkan ID catatan yang sama. Versi diverifikasi lagi: catatan yang sudah berubah tidak ditimpa.
- Rules kandidat hanya mengizinkan pemulihan tombstone dengan isi persis sama; metadata versi/waktu/operasi berubah. Nominal, kategori, judul dan tanggal tidak boleh sekaligus diubah pada pemulihan. Saldo dan agregat bulan harus tepat.
- Tombol urungkan tersedia selama tinjauan masih terbuka, termasuk setelah berpindah tab; selesai/draf baru/logout/menutup aplikasi melepas snapshot memori. Belum tersedia riwayat urungkan lintas sesi. Receipt operasi tetap tersimpan sebagai bukti/idempotensi, bukan antarmuka riwayat lengkap.

## Perapian terkait

Label simpan jadwal kuliah diperbaiki. Saat keyboard terbuka, pengantar dan contoh Asisten disembunyikan agar input serta tombol Kirim memiliki ruang; navigasi bawah tetap disembunyikan seperti sebelumnya.

## Kontrak dan privasi

Satu panggilan model per pesan melalui endpoint, verifikasi token dan kuota yang sama. Allowlist server: `prepare_draft`, `read_records`, `prepare_change`, `ask_clarification`. Keluaran model divalidasi server dan Flutter; teks bebas tidak dianggap bukti simpan. Hanya pesan pengguna dikirim ke provider, tidak ada pembacaan lintas akun atau pengiriman ledger. Semua mutasi tetap menggunakan Firebase SDK dan Rules, tidak diberikan ke model.

Tidak menambah package, layanan berbayar, SQLite, push notification atau jadwal berulang pada tahap ini. Isu CPU tetap ditunda sesuai instruksi pengguna; tidak ada benchmark tambahan.

## Verifikasi

Bukti: `docs/qa/agent-stages-1-3/`.

- Flutter unit/widget: 32 lulus pada pemeriksaan akhir.
- Backend: 17 lulus, mencakup validasi tool baru dan regresi auth/proxy/kuota.
- Rules lokal: 12 agenda + 16 keuangan + 10 batch lulus; pemulihan persis diizinkan, pemulihan sekaligus mengubah konten ditolak.
- Android API35 x86_64: lulus satu suite native dengan sembilan kelompok pemeriksaan dan enam screenshot. Saran 3 agenda + 1 transaksi, baca tanpa tulis, edit dan undo, delete/restore, stale undo, bentrokan, pergantian akun, dan keyboard diuji. Keluaran model disimulasikan, sedangkan Firebase SDK/database/Rules dan UI Android nyata. Ini belum bukti kemampuan pemilihan tool oleh model produksi.
- Analyzer bersih; build APK normal debug x86_64 berhasil. APK `output/apk/ruma-agent-tools-preview.apk` dipasang Success dan cold launch Status ok; foreground Ruma terkonfirmasi. SHA/scan exact secret UTF-8/UTF-16: nol kecocokan, nol berkas privat. Ini APK VM, bukan APK ARM64 HP/release final.
- Worker dry-run berhasil (44,15 KiB; gzip 14,17 KiB), tanpa deploy. Kandidat dan hash pada `candidate-manifest.json`.
- Worker dan Rules yang hash-nya cocok dengan kandidat telah dipublikasikan setelah izin pengguna; model nyata dan Firebase produksi lulus melalui Android API35. Bukti publikasi pada `production-publication.json`, `rules-published.png`, dan `worker-published.png`.
- Panggilan model nyata: tepat 4. Penulisan produksi hanya fixture sintetis yang diizinkan beserta counter kuota normal. Tidak mengubah data akun pengguna lain.

### Temuan dan perbaikan uji native

Percobaan pertama meluluskan alur data tetapi gagal pada posisi tombol Kirim (bawah tombol 619 vs batas viewport 548 logical px). `Scaffold` menghapus inset keyboard pada MediaQuery body, sehingga halaman Asisten tidak melihatnya. MainShell kini meneruskan status keyboard secara eksplisit; assertion yang sama lulus pada percobaan kedua. Tombol Kirim sepenuhnya terlihat, tidak ada overflow. Teks sesudah urungkan dan rincian deadline turut diperjelas dalam satu batch perbaikan. Log gagal tetap ada di `attempt-1/`.

Enam screenshot native diperiksa; tidak mengubah Figma/PDF. Fixture Auth dan Firestore lokal dibersihkan (HTTP200), reverse port dilepas, pengaturan layar dipulihkan ke 1. App normal menggantikan harness di VM.

## Verifikasi produksi — selesai

Sesudah persetujuan pengguna, Worker dan Rules dipublikasikan lalu diuji melalui `integration_test/agent_tools_cloud_test.dart` dengan flag eksplisit `AGENT_TOOLS_LIVE_TESTS=true`. Suite membatasi empat panggilan model (draf gabungan, baca laporan, edit agenda, hapus transaksi), memakai paling banyak dua akun sintetis, menguji simpan/urungkan/retry/isolasi, dan menghapus akun fixture. Cleanup dokumen hanya boleh membaca manifest suite ini, maksimal 20 dokumen per subkoleksi fixture, melalui `RUMA_CLEAN_AGENT_TOOLS_FIXTURES=mobile-app-3479f node backend/tests/assistant-cloud-cleanup.mjs`. Tidak memindai pengguna lain atau menghapus counter kuota.

Uji produksi lulus dalam 65 detik: dua agenda memperoleh saran slot dan satu pengeluaran tercatat setelah persetujuan; retry tidak menggandakan data; laporan membaca angka yang benar tanpa menulis operasi; edit agenda bisa diurungkan; hapus transaksi mengembalikan saldo ke nol, dan undo memulihkan ID yang sama serta saldo -Rp18.000; pembacaan oleh akun lain ditolak.

Dua akun Auth sintetis dihapus oleh SDK. Cleanup exact UID menghapus 10 dokumen agenda/transaksi/bulan/core/receipt dan memverifikasi seluruh subkoleksi fixture kosong. Counter kuota dipertahankan. Percobaan cleanup pertama mengalami koneksi jaringan timeout; percobaan melalui konfigurasi proxy jaringan yang tersedia berhasil, tanpa menambah panggilan model. Bukti `cloud-results.json`, `cloud-cleanup.json`, `cloud-test.log`, `cloud-cleanup.log`.

APK normal `output/apk/ruma-agent-tools-preview.apk` dipasang kembali (Success), cold launch Status ok dan foreground Ruma terkonfirmasi. Hash tetap sama dengan hasil scan sebelum pengujian. VM dibiarkan terbuka, pengaturan layar kembali 1. Tidak meninggalkan test harness sebagai aplikasi normal. Tidak memasang ulang APK HP ARM64 dan tidak membuat PDF baru.

## Berikutnya

Tahap 1–3 selesai untuk batas yang dijelaskan di atas. Kandidat sudah menjadi versi aktif. Notifikasi/FCM, jadwal berulang, preferensi tersimpan, percakapan berkonteks dan urungkan lintas sesi masih memerlukan tahap terpisah; belum mulai dikerjakan. Catatan CPU tetap ditunda, tanpa benchmark tambahan atau error CPU yang dikonfirmasi dalam suite ini.
