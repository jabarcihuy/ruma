# Ruma — implementasi pengingat dan notifikasi

20 Oktober 2026. **Publikasi dan uji FCM nyata selesai; fixture dibersihkan.** Role send-only sudah diberikan ke service account proxy, Rules dan indeks pengingat aktif, Worker serta cron per menit sudah dipublikasikan. Ini laporan implementasi, sedangkan NOTIFICATIONS.md menyimpan rancangan lengkap.

## Perilaku yang dibuat

- Profil → Notifikasi: pilihan notifikasi perangkat, tautan pengaturan Android, serta daftar maksimal 20 notifikasi terbaru. Inbox awal menampilkan keadaan kosong, bukan contoh pengingat palsu.
- Detail agenda → Atur pengingat: aktif/nonaktif dan pilihan 5, 10, 15, 30, atau 60 menit sebelumnya. Default nonaktif, saran 10 menit. Acuan waktu mulai, atau deadline untuk tugas tanpa waktu mulai. Kegiatan tanpa acuan yang masih akan datang tidak dapat diaktifkan.
- Tidak menawarkan pengingat tepat pada jam mulai: cron per menit dan penolakan pengiriman setelah acuan membuat pilihan 0 menit tidak dapat diandalkan. Ini pengingat melalui internet, bukan alarm presisi.
- Menyimpan pengingat tidak mengubah agenda, keuangan atau memanggil AI. Memindah/mengubah/menyelesaikan/menghapus/memulihkan agenda memperbarui dokumen pengingat dalam transaksi data yang sama. Agent memakai jalur CRUD yang sama.
- Mengubah judul/durasi tanpa mengubah acuan mempertahankan generation dan hasil kirim, sehingga tidak mengirim ulang peristiwa yang sama. Mengubah acuan/lead/keaktifan atau membatalkan/mengaktifkan kembali sumber menaikkan generation dan membatalkan lease lama.
- FCM membawa judul/isi generik serta UID/agenda/version/generation. Nama kegiatan, angka uang dan percakapan tidak masuk payload layar kunci. Foreground menampilkan satu kartu lokal dengan ID/tag stabil. Background dan proses aplikasi yang sudah berhenti memakai notification+data; penerimaan serta ketukan cold launch sudah dibuktikan pada APK normal di AVD.
- Ketukan hanya membuka agenda milik akun aktif. Payload lama membuka keadaan terbaru dengan pemberitahuan jadwal diperbarui. Target akun lain tidak dibaca. Inbox hanya dapat dibaca pemilik; hanya server membuatnya dan klien hanya menandai readAt.
- Pendaftaran token per instalasi/UID dan pembaruan token disiapkan. Pengguna meminta izin saat mengaktifkan fitur. Menonaktifkan/log out melepas pendaftaran server dan membersihkan kartu lokal; pemanggilan logout tidak digagalkan oleh koneksi offline. Saat offline, pendaftaran server mungkin belum terlepas, tetapi isi tetap generik dan pembukaan detail tetap dibatasi UID.

## Antrean server

Sumber: `backend/src/notifications.mjs`, `reminder-db.mjs`, dan entrypoint scheduled di Worker. Konfigurasi kandidat: `backend/wrangler.notifications.jsonc`.

- Cron target setiap menit, maksimal lima job per tick dan tiga perangkat aktif per job. Query collection-group `reminders`, bukan pemindaian akun. Indeks kandidat pada `config/firebase/firestore.notifications.indexes.json`.
- Claim dan penyimpanan memakai precondition updateTime atomik. Lease 60 detik diperbarui sebelum tiap pengiriman; sumber, generation dan pemilik lease diperiksa kembali. Jam server dipakai ulang per langkah, sehingga job berikutnya tidak memakai lease yang sudah kedaluwarsa dari awal tick.
- Hasil sukses tiap perangkat disimpan sebelum melanjutkan perangkat berikutnya. Retry hanya untuk kegagalan sementara, menunggu 1/2/5 menit serta Retry-After, maksimal lima percobaan dan hanya sebelum acuan. Token UNREGISTERED dinonaktifkan. Hasil gagal permanen tidak dikirim lagi saat perangkat lain perlu retry.
- Batas server awal: 100 percobaan job/hari global, 10/menit global dan 5/menit per UID; maksimal tiga pesan perangkat tiap job. Counter push terpisah dari counter AI. Job tanpa perangkat aktif menjadi failed; job lewat acuan menjadi expired. Tidak menjanjikan kirim tepat waktu atau exactly-once saat jawaban jaringan tidak diketahui.
- Presisi timestamp Firestore dipertahankan saat REST decode/encode. Tanpa itu, claim dapat menghilangkan mikrodetik acuan dan membuat edit judul dianggap perubahan waktu; regresinya tercakup uji adapter.
- Jadwal per menit berarti sekitar 1.440 query antrean per hari, ditambah pembacaan/penulisan saat ada job. Belum ada pengukuran kapasitas produksi; tidak mengaktifkan billing atau menjanjikan seluruh skala penggunaan gratis.

## Integrasi Android

Package baru: `firebase_messaging 17.0.0`, `flutter_local_notifications 22.3.2`, `shared_preferences 2.5.6` sesuai lockfile. Google Services Gradle plugin 4.5.0 menyediakan resource Firebase native untuk penerimaan sebelum Dart berjalan. Plugin hanya diterapkan pada build produksi; `AUTH_EMULATOR=true` tetap menginisialisasi demo-ruma secara eksplisit dan tidak memuat inisialisasi proyek produksi.

POST_NOTIFICATIONS, channel `ruma_agenda_v1` dan ikon native tersedia. Auto-init FCM nonaktif sampai pilihan pengguna diaktifkan. Metode pengaturan Android memakai MethodChannel kecil, tanpa package tambahan. Java 17/desugaring dan DSL ApplicationExtension mengikuti AGP9 yang sudah dipakai proyek.

HTTP v1 sender pada tahap ini tetap memakai registration token. API getToken/onTokenRefresh/deleteToken masih tersedia pada plugin 17 tetapi deprecated menuju FID; adapter menandai penggunaan secara lokal, bukan menurunkan seluruh dependency Firebase. Migrasi protokol FID harus dipastikan bersama endpoint pengiriman sebelum API token dihapus. Token tidak dicetak atau dimasukkan ke prompt.

## Bukti lokal

Direktori: `docs/qa/notifications/`.

- 35 tes Flutter akhir lulus, termasuk generation, pilihan waktu, payload tap, lebar 320 dengan teks 200%, dan regresi halaman yang sudah ada.
- 27 tes backend akhir lulus: lease serentak, waktu kedaluwarsa/sumber berubah, retry parsial, Retry-After, token invalid, kegagalan permanen, cap kuota, inbox satu per ID, timestamp presisi dan cache OAuth berbeda scope, serta regresi agent/auth/proxy/kuota.
- Rules: empat tes pengingat ditambah 12 agenda + 16 keuangan + 10 batch lulus pada kandidat. Klien tidak dapat menulis hasil dispatch atau inbox palsu, membaca akun lain, atau mengubah agenda tanpa menyinkronkan pengingat yang sudah ada.
- Suite SDK/UI Android API35 x86_64 lulus dalam 16 detik: simpan tanpa perubahan tidak menaikkan generation; pemindahan/complete/reopen/delete/restore atomik; dua tampilan foreground memakai satu kartu native; payload lama membuka data terbaru dan UID lain tidak membuka detail. Tiga screenshot diperiksa.
- Suite native memakai Auth/Firestore **demo-ruma lokal**. Izin Android diberikan khusus fixture AVD melalui helper loopback setelah APK test terpasang. Respons foreground dimasukkan langsung ke handler. Ini **bukan** bukti FCM nyata, dialog izin pengguna, pengiriman saat app tertutup, token refresh produksi, atau dua perangkat fisik.
- Percobaan awal fixture widget bersarang Scaffold diperbaiki pada harness; hasil akhir 35 tes bersih. Uji native awal menunggu navigasi terlalu singkat, lalu percobaan berikutnya kehilangan izin ketika APK test dipasang ulang. Harness kini menunggu route dan memberikan izin setelah instalasi fixture. Assertion tetap dipertahankan; log percobaan ada di attempt-1/ dan attempt-2/.
- Build APK normal debug x86_64 dan dry-run Worker sudah berhasil. Pemeriksaan akhir/hash dan hasil cleanup dicatat di candidate-manifest.json setelah finalisasi.
- Panggilan model AI: 0. Pengiriman FCM nyata: 0. Penulisan produksi: 0 pada tahap lokal ini.

## Cakupan publikasi yang disetujui

Rules `config/firebase/firestore.notifications.rules` sekarang aktif setelah persetujuan pengguna, bersama indeksnya. `firebase.json` dan konfigurasi Worker aktif sudah diselaraskan. Catatan prosedur publikasi yang dijalankan:

1. Buat custom role proyek `rumaFcmSender` sesuai `config/firebase/ruma-fcm-sender-role.json`, hanya permission `cloudmessaging.messages.create`. Berikan pada service account **ruma-ai-proxy@mobile-app-3479f.iam.gserviceaccount.com** yang Secret-nya sudah ada. Tidak perlu key baru atau role Owner/Editor/FCM Admin.
2. Publikasikan Rules dan indeks, tunggu indeks siap; publikasikan Worker kandidat, set `NOTIFICATIONS_ENABLED=true`, aktifkan Cron Trigger setiap menit. Endpoint AI dan batas model tetap sama.
3. Uji maksimal tiga pesan FCM ke instalasi AVD, dengan akun/agenda sintetis: foreground, background/ditutup biasa, ketuk notifikasi ke agenda terbaru. Hapus fixture Auth, device, agenda, pengingat, inbox dan receipt exact UID sesudah uji; pertahankan counter kuota.
4. Pasang APK normal kandidat sesudah server kompatibel, dokumentasikan keadaan yang benar-benar lulus. Tidak mengklaim FCM aktif hanya karena kode dan Console tersedia.

## Batas tahap ini

Snooze lima menit, rekonsiliasi snooze setelah restart, seri mingguan dan notifikasi keuangan tidak ditambahkan pada potongan dasar ini. Pengingat kelas/tugas saat ini sekali jalan. Dua perangkat nyata, force-stop/battery optimization, backlog produksi serta keterlambatan aktual belum diuji. Inbox dibatasi 20 terbaru; belum ada paging. Isu CPU proxy lama tetap ditunda sesuai instruksi pengguna; tidak ada benchmark tambahan atau klaim kelulusan CPU baru.

## Referensi primer

- [FCM Flutter: izin, foreground, background, dan ketukan](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api)
- [Firebase Android dan Google Services plugin](https://firebase.google.com/docs/android/setup)
- [Permission FCM dan roles](https://docs.cloud.google.com/iam/docs/roles-permissions/firebasecloudmessaging)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications), serta README versi yang terpasang untuk desugaring/channel.

### Riwayat finalisasi lokal sebelum publikasi

Total 104 tes lokal akhir (35 Flutter, 27 backend, 42 Rules) lulus. Analyzer bersih dan APK normal kandidat berhasil dibangun. Manifest menyimpan hash sumber, konfigurasi, dan rencana izin. Scan exact key server UTF-8/UTF-16 serta file privat dicatat di apk-inspection.json. Fixture Auth/Firestore demo-ruma dibersihkan HTTP200 dan reverse dilepas. APK agent tahap sebelumnya dipulihkan sebagai aplikasi normal selama menunggu Rules pengingat dipublikasikan; ini mencegah pengguna memakai APK baru terhadap izin database lama. Setelah test harness selesai, paketnya sudah dilepas sehingga izin fixture tidak bertahan. Tidak mengaktifkan FCM/cron produksi, tidak mengubah IAM, dan tidak membuat PDF baru.

### Publikasi produksi — selesai

Persetujuan pengguna: “Izinkan publikasi dan uji FCM”. Custom role `projects/mobile-app-3479f/roles/rumaFcmSender` dibuat dengan satu permission `cloudmessaging.messages.create`, lalu diberikan kepada `ruma-ai-proxy`. Console mengonfirmasi Policy updated. Rules dipublikasikan melalui Console dengan readback cocok dengan kandidat. Indeks collection-group `CICAgOjXh4EK` berstatus Enabled. Worker kode `37c46502` aktif setelah readback kode lengkap; variabel `NOTIFICATIONS_ENABLED=true` dan Cron Trigger Every minute tersimpan. Konfigurasi lokal aktif diselaraskan. Tidak membuat key, mengubah billing, atau memanggil model. Bukti screenshot tersedia di direktori QA. Uji penerimaan native dan hasil server berhasil; rincian bukti di bawah.

### Bukti FCM nyata

Cron baru mulai mengeksekusi setelah propagasi konfigurasi. Percobaan pertama menunggu empat menit tanpa claim/pengiriman lalu timeout; akun serta 4 dokumen dibersihkan. Percobaan berikutnya membuktikan FCM foreground, tetapi fixture agenda kedua berbenturan dengan fixture pertama dan ditolak jalur CRUD. Assertion tidak dilonggarkan dan pemeriksaan benturan aplikasi tidak diubah. Akun serta 5 dokumen dibersihkan. Screenshot 01-real-fcm-foreground.png membuktikan kartu native dari callback pesan sebenarnya.

Uji khusus background berikutnya lulus: perangkat terdaftar, Worker mengirim sekali, Android menampilkan notifikasi saat aplikasi berada di Home, alat uji mengetuk kartu Android, dan route membuka agenda yang cocok. Inbox server berisi satu dokumen; job berstatus sent dengan attempts=1 sebelum cleanup. Akun dan 5 dokumen dibersihkan. Bukti cloud-results.json, background-host-result.json dan screenshot 02/03. Dua pesan pertama berhasil tanpa retry. Pesan ketiga serta cold launch dibuktikan pada bagian berikutnya. Tidak ada panggilan AI.

### Hasil akhir aplikasi tertutup dan cleanup

APK normal dipasang kembali mempertahankan fixture Auth, kemudian proses aplikasi dihentikan dengan am kill setelah berada di Home. Ini bukan force-stop. Host memastikan pidof kosong sebelum pengiriman. Cron mengirim pengingat ketiga dengan attempts=1 dan satu perangkat sent. Android menampilkan kartu; ketukan menghidupkan APK normal dan membuka “QA FCM aplikasi ditutup”. Bukti: terminated-results.json, terminated-dispatch.json, screenshot04/05. SHA256 APK terpasang cocok persis dengan kandidat normal, bukan APK test.

Percobaan awal penyiapan terminated menolak HTTP chunked dari harness sehingga manifest belum sampai. Ini diperbaiki dengan Content-Length eksplisit. Job fixture awal belum pernah dicoba kirim (SDK memeriksa attempts=0), dibatalkan, perangkat dilepas, dan Auth dihapus sebelum fixture berikutnya dibuat. Empat dokumennya ikut cleanup exact UID. Pengujian ini tidak melonggarkan aturan aplikasi. Token akun sintetis sempat disimpan sementara di .local dengan mode0600 untuk menghapus akun sendiri melalui Firebase Auth REST; file itu sudah dihapus.

**Total akhir: 3 pesan FCM nyata, 3 job tereservasi, 0 panggilan AI; 5 akun Auth sintetis dan 24 dokumen Firestore dibersihkan.** Counter kuota dipertahankan. Keadaan pengingat/device/inbox diperiksa kosong hanya pada UID fixture; tidak memindai atau menghapus akun lain. AVD hanya berisi fixture QA: data aplikasi sintetis dibersihkan dan izin notifikasi yang diberikan harness dicabut, sehingga pengguna tetap mengaktifkan fitur sendiri. APK normal debug x86_64 tetap terpasang dan cold launch berhasil. Screen stay-on dikembalikan ke nilai1, reverse loopback dilepas.

104 tes lokal sebelumnya tetap menjadi bukti untuk hash sumber kandidat; analyzer terakhir bersih setelah perubahan harness dan dokumentasi. FCM foreground, background/tap dan terminated/cold tap merupakan tambahan uji produksi di AVD API35, bukan klaim dua perangkat fisik, dialog izin manual, force-stop, Doze atau seluruh merek HP. Isu CPU lama tetap ditunda; tidak ada benchmark tambahan. Tidak membuat PDF atau mengubah Figma pada tahap ini.

Pemeriksaan visual akhir 06-normal-app-after-cleanup.png menunjukkan halaman sambutan APK normal, tanpa akun atau data fixture yang masih terbuka.
