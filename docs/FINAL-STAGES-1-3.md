# Ruma — tahap akhir 1–3

21 Oktober 2026. **Pengaman output AI sudah aktif dan APK normal terbaru terpasang. Tes lokal dan replay SDK lulus; keberhasilan draf gabungan dari model secara konsisten belum terverifikasi.** Rincian diagnosis, bukti dan batas hasil terbaru ada pada bagian terakhir. Bukti kandidat lokal tetap dipertahankan sebagai riwayat sebelum publikasi.

## Perubahan

1. **Profil dan preferensi pribadi.** Bio maksimal 160 karakter, studi 80 karakter dan empat warna avatar. Nama tetap memakai Firebase Auth. Preferensi AI opsional: durasi bawaan 5–120 menit dan rentang saran dalam WIB. Durasi eksplisit dalam pesan dan pilihan saat meninjau draf tetap diutamakan. Data tersimpan per UID di `users/{uid}/settings/personal`, memakai revision CAS agar editor lama tidak menimpa revisi baru. Profil tidak ditambahkan ke konteks provider; ini personalisasi aturan, bukan pelatihan ulang model.
2. **Agenda mingguan.** Form kuliah memakai tombol ulang mingguan dan tanggal akhir opsional. Detail menyediakan perubahan satu pertemuan, mulai pertemuan ini, atau seluruh seri. Opsi lanjutan berada dalam bagian lipat. Tidak membuat ribuan dokumen dan tidak mengembalikan Ritme Harian. Pertemuan mempertahankan ID asal meskipun dipindah jam/tanggal. Pengecualian khusus tetap berlaku saat pola berikutnya diubah. Asisten bisa membaca, mengubah dan mengurungkan satu pertemuan; pembuatan seri dilakukan melalui form kuliah.
3. **Pengingat seri dan snooze.** Worker kandidat memvalidasi pertemuan lalu memajukan cursor ke pertemuan berikutnya setelah hasil terminal. Snooze lokal lima menit tersedia lewat detail dan aksi notifikasi foreground. Jadwal kegiatan serta waktu FCM tidak digeser. Perubahan agenda, sesi atau izin memicu rekonsiliasi snooze. Keuangan dan draf gabungan memakai receipt/validasi yang sudah ada.

## Batas rancangan

- Maksimal 30 seri aktif, 64 pengecualian, 16 perubahan fase dan payload pola 60.000 karakter. Ekspansi satu jendela maksimal 90 hari; kalender mengambil tanggal yang dipilih. Pembacaan agenda tetap maksimal 500 dokumen aktif.
- Pola disimpan pada dokumen agenda sebagai `recurrence`: `type`, `originDate`, `untilLocalDate`, `exceptions` dan `changes`. Dua peta terakhir berupa JSON berbatas yang divalidasi Flutter/Worker. Firestore Rules membatasi bentuk/ukuran dan pemilik, tetapi tidak dapat mengurai JSON tersebut. Dokumen inti, receipt, revisi dan pengingat tetap atomik.
- ID pertemuan adalah `seriesId__originalDate`; versinya mengikuti dokumen induk. Perubahan seri membuat tinjauan lama kedaluwarsa. Kunci operasi lama untuk agenda satu kali tetap kompatibel.
- Snooze maksimal 20 per instalasi. SharedPreferences menyimpan target/waktu/guard saja, bukan database agenda atau keuangan. Android memakai `inexactAllowWhileIdle`, tanpa izin exact alarm. Tidak menjamin bunyi tepat lima menit, khususnya ketika Doze. Setelah reboot aplikasi perlu dibuka untuk validasi ulang; tidak ada boot receiver. Perubahan remote ketika aplikasi tertutup/offline tidak bisa langsung membatalkan pengingat lokal yang sudah dijadwalkan.
- Tetap memakai Firestore; tidak menambah SQLite, sinkronisasi baru, upload foto, verifikasi email, lupa sandi, IAM, indeks, secret, billing atau cron baru. CPU tetap ditunda sesuai instruksi sebelumnya.

## Bukti verifikasi lokal

Bukti berada di `docs/qa/final-stages-1-3/`.

| Pemeriksaan | Hasil |
| --- | --- |
| Flutter | 56 lulus, termasuk regresi tata letak 320 px, teks 200%, keyboard dan navigasi |
| Backend Node | 32 lulus; termasuk cursor seri, pengecualian, kegagalan tertutup dan adapter Firestore |
| Firestore Rules emulator | 51 lulus; kepemilikan, revision, payload invalid dan operasi atomik |
| Total | **139 tes lokal lulus** |
| Analyzer | Tidak ada isu |
| Worker dry-run | Berhasil; tidak deploy |
| SDK/UI Android API 35 | Delapan kelompok alur lulus dalam 28 detik |
| Screenshot | Lima gambar native diperiksa, tanpa error layout |

Suite Android memakai Firebase emulator `demo-ruma` dan respons model sintetis: profil/pref tersimpan, konflik/ubah/undo/cakupan seri, snooze terjadwal lalu dibatalkan setelah perubahan, preferensi durasi dan draf campuran tanpa duplikasi, edit/undo pertemuan melalui Asisten tanpa mengubah uang, simpan form/revision lama ditolak, aksi seri/snooze di UI, serta isolasi akun kedua. Persetujuan AI tidak dipulihkan otomatis ketika store dimuat ulang.

Percobaan awal menemukan konflik semu terhadap induk seri sendiri; repository bersama diperbaiki, bukan pemeriksaan konflik dihapus. Percobaan kedua menemukan skrip uji belum memberikan persetujuan AI setelah store baru; skrip diperbaiki mengikuti perilaku aplikasi. Bukti kegagalan dipertahankan dalam `attempt-1/` dan `attempt-2/`.

**0 penulisan produksi, 0 panggilan model nyata dan 0 FCM nyata pada tahap lokal ini.** Belum membuktikan cron seri produksi, penerimaan FCM seri nyata, kualitas respons model nyata dengan preferensi baru, seluruh kondisi Doze/reboot, HP fisik atau APK release ARM64.

## Rekaman kandidat sebelum publikasi

- Rules: `config/firebase/firestore.final-stages.rules`; konfigurasi emulator `firebase.final-stages.json`. Konfigurasi aktif `firebase.json` tetap memakai `firestore.assistant-memory.rules`.
- Worker: `backend/src/recurrence.mjs`, `backend/src/notifications.mjs`, konfigurasi `backend/wrangler.notifications.jsonc`. Versi produksi sebelumnya tetap `c3759e9e-c2d6-4004-a2be-e6009ad04fe5`.
- APK normal kandidat: `output/apk/ruma-final-stages-1-3-candidate.apk`, target `lib/main.dart`, debug x86_64. Hash, sumber, ukuran serta hasil scan secret tercatat di `candidate-manifest.json`; ini belum APK release final.
- Data Auth/Firestore emulator dibersihkan HTTP 200, emulator Firebase dihentikan dan reverse dilepas. Font 1.0/stay-on 1 dipulihkan. VM dikembalikan ke APK Home normal sebelumnya yang kompatibel dengan Rules produksi, cold launch berhasil. Kandidat baru belum dipasang sebagai aplikasi produksi aktif.

Langkah yang memerlukan persetujuan: memublikasikan Rules profil/seri dan Worker ke `mobile-app-3479f`/`ruma-api`, menguji maksimal dua akun sintetis, satu panggilan AI dan satu percobaan pengiriman FCM ke VM, menghentikan job jika percobaan gagal, membersihkan fixture exact UID, lalu memasang APK normal kandidat. Tidak mengubah IAM, indeks atau billing. Harness opt-in tersedia di `integration_test/final_stages_cloud_test.dart`; cleanup berbatas memakai `RUMA_CLEAN_FINAL_STAGES_FIXTURES=mobile-app-3479f`. Kuota global historis dipertahankan.

## Referensi implementasi platform

- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications): penjadwalan Android dan receiver native.
- [timezone](https://pub.dev/packages/timezone): waktu penjadwalan UTC. Dependensi yang sebelumnya transitif dipakai langsung; tidak menambah framework state management.


## Publikasi produksi dan hasil aktual

Pengguna menyetujui Rules/Worker, maksimal dua akun sintetis, satu permintaan AI dan satu percobaan FCM, cleanup serta pemasangan APK normal.

- Rules profil/seri terbit **21 Oktober 2026 pukul 08.23 WIB** melalui Firebase Console. Editor sebelum publikasi persis Rules assistant-memory; setelah publikasi persis kandidat final-stages. `firebase.json` kini memakai `firestore.final-stages.rules`.
- Worker **774700f2-baa7-48c8-ada9-a417fb6d88db** aktif 100%, bundle persis hasil dry-run. Tidak mengubah IAM, indeks, secret, cron atau billing. Bukti `publication.json`, sumber backup/published serta screenshot Rules/Worker.
- Profil/preferensi tersimpan dan pulih di produksi. Akun kedua mendapat preferensi awal sendiri dan ditolak membaca profil pertama. Kedua pemeriksaan ini lulus.
- **Satu FCM nyata diterima SDK Android.** Inbox generation 1 tersimpan dengan tanggal pertemuan. Setelah cleanup client, job nonaktif generation 3: ini menunjukkan cursor sempat maju ke generation 2 sebelum pembatalan final menaikkan generation menjadi 3. Counter push global hari ini 1. Pemeriksaan Android active-notification serta snooze produksi belum sempat dijalankan: suite awal terhenti ketika pembacaan job Firestore melewati timeout 15 detik. Tidak mengulangi FCM. Snooze tetap sudah lulus suite SDK lokal, bukan klaim lulus produksi. Bukti `fcm-server-proof.json` dan `cloud-attempt-1/`.
- Sisa anggaran diuji dengan akun kedua, tanpa membuat job push baru. **Permintaan AI gagal HTTP 502**, sehingga preferensi pada jawaban AI nyata dan commit campuran produksi pada potongan ini belum terverifikasi. Cloudflare mencatat outcome `ok`, wall 16.480 ms dan CPU 10 ms; tidak ada `exceededCpu`/Error 1102. Angka ini bukan benchmark CPU dan tidak memicu optimasi CPU yang ditunda. Penyebab 502 belum dapat dibedakan antara provider_unavailable dan invalid_model_output karena client hanya menampilkan pesan aman berdasarkan status HTTP. Jangan menganggap masalah sudah diperbaiki. Bukti `ai-failure.json`, `cloud-results.json` dan `cloud-completion-test.log`.
- Tepat satu reservasi AI untuk UID fixture kedua, nol untuk fixture pertama. Counter global AI bernilai 2 dan mencakup request di luar fixture ini; tidak digunakan sebagai jumlah panggilan uji. Tidak melakukan retry tersembunyi atau mereset kuota.
- **Dua akun Auth dihapus melalui SDK; sembilan dokumen fixture dihapus dan subkoleksi diverifikasi kosong.** Cleanup exact UID mencakup settings, device, reminder dan inbox selain data/domain/receipt/workspace. Counter historis serta pengguna lain tidak disentuh. Node fetch host sempat timeout; cleanup kemudian memakai adapter curl ke endpoint Google yang sama, tanpa menyimpan token. Bukti `cloud-cleanup.json`.
- APK normal `output/apk/ruma-final-stages-1-3.apk` dipasang Success dan cold launch Status ok di VM. Hash APK yang benar-benar terpasang cocok persis kandidat: `293272776d37ae720454cf0a11a684cb476f68acedd72f063407989c7481184e`. Harness sudah diganti. Welcome diperiksa, reverse kosong, font 1.0/stay-on 1. Ini debug x86_64; bukan release ARM64 atau uji HP fisik. Bukti `normal-installed.json` dan `07-normal-installed.png`.

Status akhir: implementasi serta 139 tes lokal lulus; profil/isolasi dan penerimaan FCM produksi terverifikasi, tetapi **seluruh uji produksi belum lulus karena AI 502**. Transport diagnostik opt-in sudah disiapkan di `integration_test/final_stages_ai_diagnostic_test.dart`: bentuk request aplikasi yang sama, satu request per run, hanya status/kode error allowlist disimpan tanpa token, prompt atau body provider. Belum dijalankan. Meminta tambahan maksimal dua permintaan AI/dua akun sintetis untuk diagnosis dan verifikasi, tanpa FCM tambahan. Tidak menambah layanan atau fitur.


## Diagnosis AI lanjutan — selesai dalam batas yang disetujui

Pengguna mengizinkan tambahan maksimal dua permintaan AI dan dua akun sintetis, tanpa FCM. **Terpakai dua permintaan AI, dua akun dan nol FCM tambahan; tidak ada retry tersembunyi.**

1. Tes diagnostik native mengembalikan `HTTP 502: invalid_model_output`. Ini membuktikan penolakan validasi output, bukan bukti provider sedang offline atau CPU limit. Aturan tepat yang gagal pada respons awal tetap tidak diketahui karena payload awal tidak direkam. Akun diagnostik dihapus dan dua dokumennya dibersihkan. Bukti `ai-diagnostic-1.log`, `ai-diagnostic-1/cloud-results.json`, `ai-diagnostic-1/cloud-cleanup.json`.
2. Satu panggilan terakhir langsung ke provider menggunakan model, tools, prompt sistem, batas output dan pesan sintetis yang sama. Respons HTTP 200 memiliki model/finish reason yang benar dan tool `prepare_draft` yang valid secara bentuk, **tetapi hanya berisi transaksi Rp18.000 dan melewatkan kalimat agenda**. Ini bukan keberhasilan draf gabungan. Fixture hanya menyimpan bagian respons sintetis yang diperlukan validasi, tanpa reasoning, API key atau header autentikasi. Bukti `provider-repro.json`, `provider-fixture.json`; lock mencegah skrip capture dipanggil ulang tanpa sengaja.
3. Regresi pada seam `Worker.handle` dibuat sebelum perbaikan: dua dari tiga kasus gagal, termasuk fixture asli yang masih lolos sebagai draf parsial. Setelah perbaikan, tiga kasus lulus dan keseluruhan backend 35 lulus. Bukti `incomplete-draft-before.tap`, `ai-fix-backend.tap`.

### Perbaikan yang diterapkan

- Output `prepare_draft` diperiksa terhadap kalimat bermakna yang terpisah tanda baca. Jika satu kalimat tidak tercakup dalam kutipan item, server meminta klarifikasi dan mengirim **nol item**. Sapaan sederhana dan tanda titik nominal rupiah diperiksa dalam regresi. Ini pengaman konservatif berbasis cakupan kutipan, **bukan bukti pemahaman NLP lengkap**: kehilangan bagian di dalam satu kalimat masih mungkin dan semua draf tetap harus ditinjau pengguna.
- `invalid_model_output` kini menghasilkan klarifikasi bertipe `incomplete_draft`, bukan pesan layanan tidak tersedia. Tidak melonggarkan validasi model/tool/angka/tanggal/kutipan. Autentikasi, kuota, status kegagalan provider yang sebenarnya, persetujuan dan receipt tetap berlaku. Tidak ada pengulangan model otomatis.
- Flutter menerima reason allowlist baru dan menampilkan teks tetap: **“Draf belum lengkap. Perjelas kegiatan atau transaksinya.”** Isi bebas model tidak boleh menjadi klaim simpan. Reason asing dan klarifikasi yang membawa item tetap ditolak.

### Verifikasi sesudah perbaikan

- **57 tes Flutter + 35 backend + 51 Rules yang tidak berubah = 143 pemeriksaan lokal lulus**; analyzer bersih. Rules tidak dipublikasikan ulang karena tidak berubah.
- Replay fixture asli melalui `Worker.handle` berubah dari draf uang parsial menjadi HTTP 200/klarifikasi tanpa item. Model tidak dipanggil lagi. Ini replay lokal kode Worker, bukan request autentik ke Worker produksi setelah perbaikan.
- Satu akun sintetis terakhir dipakai untuk SDK Android + Firestore produksi, memakai respons replay melalui localhost. Empat kelompok pemeriksaan lulus dalam 12 detik: preferensi pulih, klarifikasi tanpa agenda/uang/receipt, pemulihan klarifikasi tanpa kirim otomatis, dan UI tanpa tindakan menyimpan draf parsial. Saldo tetap nol dan operations kosong. Akun serta dua dokumennya dibersihkan. Bukti `cloud-results.json`, `cloud-cleanup.json`, `ai-replay-device.log`. `08-ai-clarification.png` adalah capture harness SDK terisolasi yang tidak memakai seluruh pembungkus MainShell; bukan bukti layout final seluruh aplikasi.
- Worker **359dcc2b-f7e5-494f-83d2-20583c620db5** aktif 100%; kode editor persis bundle dry-run baru. Bukti `ai-fix-publication.json`, sumber sebelum/sesudah dan screenshot. Tidak mengubah Rules, model, IAM, secret, indeks, cron atau billing.
- APK normal terbaru `output/apk/ruma-ai-output-guard.apk` dibangun dari `lib/main.dart`, debug x86_64. SHA-256 **03c1837417af11b5aa9aebbbed6cdf5c2b84988f1b3a7a08dcae90893416e268**. Pemeriksaan exact secret server UTF-8/UTF-16 serta nama file privat nol. APK normal menggantikan harness di VM; bukti pemasangan/hash/cold launch ada di `ai-fix-normal-installed.json`.
- Tambahan empat dokumen dan dua akun pada diagnosis ini dibersihkan exact UID; kumulatif seluruh tahap **empat akun dan tiga belas dokumen**. Counter kuota tidak dihapus. Capture provider langsung berada di luar counter Worker, tetapi tetap dihitung dalam dua permintaan yang diizinkan. Pengiriman FCM seluruh tahap tetap satu, tanpa pengiriman tambahan pada diagnosis.

**Batas hasil akhir:** penanganan output tidak valid/tidak lengkap sudah diperbaiki dan teruji; respons awal model tidak dipulihkan dan tidak boleh dianggap sudah dipahami sampai field yang salah. Belum ada panggilan model baru melalui Worker produksi sesudah pengaman dipublikasikan, dan belum ada bukti baru draf gabungan berhasil dari model nyata. Kualitas keluaran model masih perlu dipantau. APK lama di HP perlu diperbarui agar mengenal klarifikasi baru; APK normal terbaru hanya dipasang di VM. Tidak membuat PDF atau mengubah Figma.
