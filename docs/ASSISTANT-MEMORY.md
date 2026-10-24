# Ruma — riwayat dan pemulihan Asisten

20 Oktober 2026. **Selesai: Rules aktif, uji produksi lulus dan fixture dibersihkan.** APK normal terbaru sudah dipasang dan cold launch di VM.

## Perilaku dan batas

- Workspace Asisten per UID di `users/{uid}/assistant/session`: pesan/input terakhir, jawaban, hingga 10 percakapan sebelumnya sesuai batas ukuran, rentang jam tersedia, serta satu tinjauan draf gabungan atau perubahan catatan lama. Tidak menambah halaman atau mengirim riwayat/ledger ke provider.
- Data tetap Firestore, bukan SQLite atau salinan permanen di shared preferences. Perlu jaringan untuk memuat/menyimpan; kegagalan tidak menimpa state tersimpan. Input disimpan setelah jeda 500 ms dan ketika aplikasi menjadi inactive; label Menyimpan berarti perubahan belum seluruhnya dikonfirmasi. Force-kill sebelum pengakuan server dapat kehilangan suntingan terakhir, sehingga tidak dijanjikan pemulihan offline.
- Draf AI, item yang dikeluarkan, suntingan, saran waktu, revision, operationId dan ID target dipertahankan. Draf belum disetujui tetap tinjauan; memulihkan aplikasi tidak menjalankan model atau menyimpan agenda/transaksi otomatis.
- Sebelum mutasi catatan dimulai, snapshot attempted beserta ID operasi harus dikonfirmasi server. Jika checkpoint gagal, tidak ada mutasi data inti. Sesudah commit, status diperbarui; jika aplikasi berhenti sebelum status itu tersimpan, pemuatan berikutnya memeriksa receipt dan requestKey yang sama. Retry mempertahankan ID, bukan membuat draf/target baru.
- Tinjauan perubahan catatan terakhir juga menyimpan before/after serta undoOperationId. Receipt undo diperiksa saat pemuatan; perubahan target tetap diverifikasi repository. Ini bukan daftar undo untuk seluruh riwayat.
- Pemuatan tidak percaya flag applied dari snapshot tanpa receipt. UID dicek sebelum/sesudah I/O. Logout membersihkan tampilan akun; sebelum keluar aplikasi mencoba menyimpan workspace. Jika perubahan belum terkonfirmasi, tidak menjanjikan penyimpanan offline pada logout.
- Revision workspace diperiksa dalam transaksi. Perangkat lama tidak menimpa workspace baru; pengguna mendapat pilihan muat ulang dengan peringatan bahwa suntingan lokal yang belum tersimpan akan diganti. Tidak membuat sistem merge atau sinkronisasi realtime tambahan.
- Snapshot JSON dibatasi 160.000 karakter; riwayat terlama dipangkas terlebih dahulu. Pembacaan menolak schema tak dikenal, UID berbeda, ID/nilai/jenis tidak valid dan payload rusak. Consent provider tetap per sesi; pemulihan tidak mengirim ulang permintaan AI.

## Batas Rules aktif

`config/firebase/firestore.assistant-memory.rules` merupakan superset Rules pengingat saat ini. Hanya pemilik boleh membaca/menulis dokumen session dengan metadata/schema/ukuran/revision/waktu server yang sesuai. Tidak ada hak tambahan untuk mutasi ledger, receipt, kuota, inbox atau akun lain. JSON adalah workspace pengguna, bukan bukti otoritas transaksi. Tidak ada indeks, Worker, cron, IAM atau layanan berbayar baru.

Konfigurasi uji lokal: `firebase.assistant-memory.json`. `firebase.json` kini menunjuk Rules workspace Asisten setelah publikasi berhasil; indeks notifikasi yang ada tetap digunakan.

## Verifikasi selesai

- **116 tes lokal lulus:** 43 Flutter unit/widget, 46 Rules (12 agenda + 16 keuangan + 10 batch + 4 notifikasi + 4 workspace), dan 27 backend tanpa jaringan provider. Analyzer akhir bersih. Bukti: `qa/assistant-memory/flutter-tests-final.log`, `rules-tests.tap`, `backend-tests.tap`, `analyzer-final.log`.
- Delapan tes Flutter khusus mencakup codec/ID/undo, payload rusak dan batas ukuran, pemulihan input/draf/riwayat, receipt setelah hasil commit belum terkonfirmasi, checkpoint gagal sebelum provider/commit, konflik perangkat/isolasi, serta lebar 320 px dan teks 200%.
- Suite SDK Android API35 lulus enam kelompok: pemulihan suntingan/item/ID, receipt batch tanpa duplikasi, edit/undo tanpa pengulangan, penolakan workspace lama, payload rusak tanpa penimpaan, dan perpindahan akun. Model sintetis; Auth/Firestore hanya `demo-ruma`. Bukti: `qa/assistant-memory/device-results.json` dan `01-native-restored-review.png`.
- **Restart proses nyata lulus:** aplikasi normal dengan backend demo dipasang, proses dihentikan, PID dipastikan tidak ada, lalu diluncurkan kembali. Draf dengan ID/operationId yang sama kembali sebagai *Menunggu persetujuan*. Jumlah receipt tetap 3 dan saldo tetap -Rp18.000; pembukaan tidak melakukan commit otomatis. Bukti: `cold-restart-results.json`, `cold-server-proof.json`, `02-real-process-restart-review.png`.
- Percobaan awal cold-test berakhir di Welcome karena pemasangan harness mengganti state Auth. Login fixture emulator-only disiapkan, lalu normal `lib/main.dart` dipasang kembali dengan data dipertahankan sebelum force-stop. Bukti percobaan awal tetap disimpan. Hasil final di atas tidak menganggap Welcome sebagai kelulusan pemulihan.
- APK kandidat normal `output/apk/ruma-assistant-memory-candidate.apk`: debug x86_64 untuk VM, 102.321.120 byte, SHA256 `2f6a960462bca6083ab5f986b0cc07bd97b72550e68b7db723a166db2c48c585`. Exact secret server UTF-8/UTF-16 dan file privat tidak ditemukan. Ini belum APK release/ARM64.
- Fixture lokal Auth/Firestore dibersihkan HTTP 200; emulator Firebase dihentikan, semua ADB reverse dilepas, pengaturan layar dikembalikan ke 1. APK normal notifikasi yang sudah aktif produksi dipasang kembali dan cold launch berhasil. AVD tetap terbuka; kandidat baru belum dipasang ke produksi. Bukti: `local-cleanup.json`, `vm-restored.json`, `03-prior-normal-restored.png`.
- Tahap ini melakukan **0 penulisan produksi, 0 panggilan AI nyata, 0 pengiriman FCM**. Uji ini tidak membuktikan pemulihan offline, setiap kondisi force-stop/Doze, perangkat fisik atau kualitas model baru.

## Publikasi dan uji produksi selesai

Pengguna menyetujui publikasi, maksimal dua akun sintetis, cleanup dan pemasangan APK normal. Hash seluruh sumber dan APK sesuai manifest yang disetujui; tidak mengubah kandidat selama publikasi.

- Rules terbit melalui Firebase Console pada **20 Oktober 2026 pukul 22.33 WIB** (versi sebelumnya 20.43 WIB). Sumber editor sebelum publikasi cocok persis dengan Rules notifikasi, dan sumber sesudah publikasi cocok persis dengan kandidat. Bukti: `publication.json`, `rules-before-publication.rules`, `rules-published-source.rules`, `rules-published.png`.
- Suite SDK produksi lulus dalam 11 detik: draf/input/ID pulih, hasil commit yang belum terkonfirmasi direkonsiliasi dari receipt sehingga retry tetap satu batch dan saldo -Rp18.000, riwayat pulih setelah store dibuat ulang, serta akun kedua ditolak membaca workspace akun pertama. Uji memakai draf sintetis langsung; tidak menguji ulang jawaban model. Bukti: `cloud-results.json`, `cloud-device-test.log`.
- Dua akun Auth sintetis dihapus melalui SDK. Cleanup exact UID menghapus **7 dokumen** (agenda, transaksi, agregat bulan, state, receipt dan dua workspace), kemudian memverifikasi subkoleksi fixture kosong. Data pengguna lain dan kuota tidak disentuh. Bukti: `cloud-cleanup.json`.
- APK normal `lib/main.dart` dari kandidat yang sama dipasang Success dan cold launch Status ok di VM. Hash tetap `2f6a960462bca6083ab5f986b0cc07bd97b72550e68b7db723a166db2c48c585`; tidak meninggalkan harness. Layar dikembalikan ke 1, reverse kosong, VM terbuka di Welcome sesudah akun uji dihapus. Ini debug x86_64; HP fisik/ARM64 dan release final belum diperbarui. Bukti: `normal-installed.json`, `04-production-normal-installed.png`.
- **0 panggilan AI, 0 FCM** pada publikasi ini. Tidak mengubah Worker, IAM, cron, indeks, secret atau billing. CPU tetap ditunda sesuai permintaan pengguna. Ringkasan akhir: `qa/assistant-memory/production-summary.json`.

Bukti kandidat/lokal di bagian sebelumnya merupakan urutan sebelum publikasi; `candidate-manifest.json` tetap disimpan sebagai rekaman kandidat yang mendapat persetujuan. Status aktif terbaru tercatat pada ringkasan produksi di atas.
