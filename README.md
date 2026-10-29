# Ruma

Release **0.2.0+3** menambahkan chat berkonteks, impor gambar jadwal semester, dan adapter Google Calendar satu arah. Worker v2 dan Firestore Rules sudah dipublikasikan. Login Google Firebase Auth dan ikon launcher bermaskot sudah ditambahkan ke source workspace; konfigurasi OAuth belum siap, dan APK release di bawah belum memuat perubahan terbaru. [Unduh APK 0.2.0+3](output/apk/ruma-0.2.0-release.apk). Status dan hasil uji: [laporan implementasi](docs/ASSISTANT-CHAT-IMPORT-IMPLEMENTATION.md), [panduan konfigurasi login Google](docs/GOOGLE-SIGN-IN-SETUP.md).

**25 Oktober 2026 — audit usability lima alur:** konteks tanggal agenda, keterlihatan hari pilihan, kontrol tanggal transaksi, hasil simpan lintas bulan, dan pemulihan tabungan Beranda diperbaiki. 84 tes Flutter dan delapan skenario Android lulus. [Laporan dan batas pengujian](docs/USABILITY-AUDIT.md), [protokol uji mahasiswa](docs/USER-TEST-PROTOCOL.md), serta [APK kandidat lokal 0.1.1+2](output/apk/ruma-0.1.1-usability-candidate.apk) siap. Uji mahasiswa belum dijalankan.

**25 Oktober 2026 — lingkungan pengujian dipulihkan:** Flutter/Android SDK, Firebase Emulator dan AVD khusus Ruma siap. Analyzer bersih; 78 tes Flutter, 35 tes backend, 64 tes Rules serta alur autentikasi Android lulus. [Cara menjalankan dan batas verifikasi](docs/LOCAL-TEST-SETUP.md).

**21 Oktober 2026 — Beranda diperbarui:** kegiatan/deadline terdekat, saldo, pengeluaran dan sisa anggaran kini memakai dua ringkasan berpola sama. Angka mengikuti data tercatat dan bulan berjalan. 50 tes Flutter serta uji SDK/visual Android lulus; APK normal [ruma-home-summary.apk](output/apk/ruma-home-summary.apk) terpasang di VM. [Dokumentasi dan batas](docs/HOME-SUMMARY.md).

**20 Oktober 2026 — riwayat dan pemulihan Asisten aktif:** input, hingga 10 percakapan sebelumnya dan tinjauan draf disimpan per akun di Firestore. Restart proses memulihkan draf tanpa commit otomatis; 116 tes lokal dan uji produksi dua akun lulus. Rules aktif, 2 akun/7 dokumen sintetis dibersihkan, APK normal terbaru dipasang di VM. [Hasil dan batas](docs/ASSISTANT-MEMORY.md).

**20 Oktober 2026 — pengingat agenda aktif:** atur pengingat dari detail agenda dan notifikasi dari Profil. Rules/indeks/Worker/cron per menit sudah dipublikasikan. 104 tes lokal dan 3 pesan FCM nyata di AVD membuktikan foreground, background/tap, serta proses aplikasi berhenti/cold tap. Lima akun sintetis dan 24 dokumen sudah dibersihkan. APK normal VM: [ruma-notifications-candidate.apk](output/apk/ruma-notifications-candidate.apk), debug x86_64. [Bukti dan batas](docs/NOTIFICATION-IMPLEMENTATION.md). Snooze, pengulangan mingguan serta validasi force-stop/Doze/perangkat fisik belum termasuk.


**20 Oktober 2026 — agent tahap 1–3 aktif:** saran jam kosong untuk beberapa agenda, pembacaan agenda/laporan/riwayat, serta edit/hapus satu catatan lama dengan tinjauan dan urungkan. Worker dan Rules produksi dipublikasikan; empat panggilan AI nyata lulus dan fixture sudah dibersihkan. APK normal x86_64 terbaru terpasang di VM: [ruma-agent-tools-preview.apk](output/apk/ruma-agent-tools-preview.apk). [Dokumentasi lengkap dan batas](docs/AGENT-STAGES-1-3.md). Bagian tahap sebelumnya di bawah menyimpan riwayat pengembangan.

Aplikasi Flutter untuk membantu mahasiswa mengelola waktu dan uang dengan agent AI.

Folder ini menjadi direktori utama proyek Ruma. Firebase Auth, agenda manual sekali jalan dan keuangan manual sudah berfungsi dan lulus uji SDK pada HP, baik emulator maupun produksi. [Laporan agenda](docs/AGENDA-IMPLEMENTATION.md) memuat fitur, bukti, Rules aktif dan batas tahap.

APK ARM64 yang terakhir dipasang dan cold launch di HP: [ruma-ui-preview.apk](output/apk/ruma-ui-preview.apk), sekitar 40.8 MB. Auth, agenda manual, keuangan manual dan **Asisten draf gabungan** memakai Firebase produksi. Satu pesan dapat menyiapkan maksimal 3 agenda + 3 transaksi aktual; pengguna bisa mengubah/mengeluarkan item lalu menyimpan pilihan secara atomik.

[Implementasi Asisten](docs/ASSISTANT-IMPLEMENTATION.md) memuat 23 uji Flutter, 38 uji Rules, uji SDK/UI HP serta satu panggilan AI nyata yang lulus. Fixture sintetis dibersihkan. Jam agenda disunting manual; draf belum persisten setelah restart. AI baca/edit/hapus catatan lama, notifikasi, seri mingguan dan release final masih tahap berikutnya. Tidak menambahkan SQLite.

Perapian UI seluruh 19 halaman/keadaan sudah diterapkan; 27 uji Flutter lulus, termasuk layar kecil, teks 200%, mendatar dan keyboard. Suite native 26 keadaan lulus; APK UI normal sudah dipasang dan cold launch di HP. [PDF review 9 halaman](output/pdf/ruma-review-antarmuka.pdf) memuat 26 screenshot bernomor. Rincian: [UI-POLISH.md](docs/UI-POLISH.md).

Teks keterangan dan kartu Asisten sudah diringkas pada kandidat [APK UI ringkas ARM64](output/apk/ruma-ui-ringkas-preview.apk). Pada 20 Oktober, pengujian native dilanjutkan di Android Emulator API35: 27 screenshot dan uji keyboard khusus lulus; APK normal x86_64 sudah dipasang di AVD. [PDF terbaru: laporan per layar](output/pdf/ruma-report-per-frame.pdf) memuat 10 halaman dengan status/catatan, termasuk satu temuan label tombol form kuliah. PDF sebelumnya adalah arsip sebelum revisi teks. Lihat [hasil uji](docs/EMULATOR-TEST-REPORT.md), [cara menjalankan AVD](docs/ANDROID-EMULATOR.md), [perapian teks](docs/UI-COPY-REFINEMENT.md), dan [perbandingan Figma](docs/FIGMA-IMPLEMENTATION-AUDIT.md).

## Acuan proyek

- [Asisten: implementasi draf, hasil uji lokal dan batas](docs/ASSISTANT-IMPLEMENTATION.md)

- [Keuangan manual, hasil uji dan batas](docs/FINANCE-IMPLEMENTATION.md)
- [Agenda manual, hasil uji dan batas](docs/AGENDA-IMPLEMENTATION.md)
- [Fondasi Flutter dan cara menjalankan](docs/FLUTTER-FOUNDATION.md)
- [Catatan setiap tahap pengembangan](docs/DEVELOPMENT-LOG.md)

- [Status penyiapan layanan aktual](docs/SETUP.md)
- [Keputusan arsitektur terkini](docs/ARCHITECTURE.md)
- [Urutan persiapan dan build](docs/BUILD-PLAN.md)
- [Firebase dan model data](docs/FIREBASE-DATA.md)
- [Kontrak agent dan proxy](docs/AGENT-PROXY.md)
- [Push notification dan pengingat](docs/NOTIFICATIONS.md)
- [Peta layar Flutter](docs/SCREEN-MAP.md)
- [Kriteria penerimaan](docs/ACCEPTANCE.md)
- [PRD terbaru](docs/PRD.md)
- [Spesifikasi layar](docs/ui/screen-spec.json)
- [Handoff desain](docs/ui/design-handoff.md)
- [Indeks frame](docs/ui/export-manifest.json)
- [Catatan struktur Figma](docs/ui/design-state.json)
- [PDF desain antarmuka](design/pdf/ruma-desain-antarmuka-lms.pdf)
- [Desain Figma](https://www.figma.com/design/FE73TkpfpJrSuEX97IdrTX/Study-Match?node-id=35-66)

## Status saat penyiapan

18 Oktober 2026, revisi desain v32-expense-insight: 71 frame desain, 71 frame prototype, dan PDF 12 halaman. Ritme Harian dihapus. Arsitektur versi awal dikunci: Flutter Android, Firebase Authentication, Cloud Firestore, FCM, serta Cloudflare Workers Free sebagai proxy NaraRouter. Pengingat lokal menjadi pelengkap FCM. Perubahan data melalui AI ditinjau dan disetujui pengguna sebelum disimpan.

Rencana lama data lokal saja digantikan oleh keputusan database cloud di atas. Rancangan data/offline, kontrak agent, pemicu notifikasi, pemetaan layar, dan kriteria penerimaan telah ditulis. Konfigurasi publik, secret lokal, dan toolchain Android telah disiapkan; bukti integrasi aplikasi/Worker/Firebase masih diperlukan. Implementasi fondasi Flutter dimulai 19 Oktober 2026; ledger, agent dalam aplikasi dan notifikasi belum tersambung.

Project Firebase mobile-app-3479f dipakai khusus untuk Ruma, Android id.ruma.app terdaftar, Auth aktif, Firestore Jakarta dengan Rules khusus agenda per UID aktif, FCM v1 aktif, dan proxy ruma-api sudah terdeploy. Fondasi Flutter Android sudah dibuat; lihat laporan fondasi untuk batas dan bukti uji terkini. [Laporan cloud](docs/qa/CLOUD-INTEGRATION.md) memuat bukti JWT/AI/kuota dan catatan CPU build terbaru 13/4 ms. Optimasi CPU [ditunda](docs/qa/CPU-FOLLOWUP.md) atas keputusan pengguna dan dibuka kembali jika uji aplikasi menemukan error terkait CPU; tahap fondasi Flutter dapat dilanjutkan.

19 Oktober 2026: sesudah perbaikan prompt/guard, [5/5 uji agent](docs/qa/agent-policy-check.json), batas output, 20 pemeriksaan Node/Rules dan satu uji kuota serentak lulus. Regresi cloud menambah bukti autentikasi, kuota dan 14 uji Node terbaru. [Panduan backend](backend/README.md) menjelaskan cakupan potongan integrasi. Pengiriman FCM ke HP, Rules seluruh fitur dan CPU terburuk belum lulus; hasil terbatas ini bukan kelulusan seluruh aplikasi.

Dokumen desain berasal dari arsip rancangan sebelumnya; spesifikasi teknis dan status layanan diperbarui di folder proyek ini.

Kandidat tahap akhir 1–3: profil/preferensi AI, agenda mingguan dan snooze sudah diimplementasikan serta lulus 139 tes lokal dan delapan kelompok uji Android. **Rules/Worker sudah aktif dan APK normal terbaru terpasang di VM. Profil/isolasi serta FCM terverifikasi. Output AI yang tidak valid/tidak lengkap kini meminta klarifikasi; 143 tes lokal dan replay SDK lulus, tetapi konsistensi draf gabungan model nyata belum terverifikasi.** Rincian, batasan, APK kandidat dan bukti: [laporan tahap 1–3](docs/FINAL-STAGES-1-3.md).

APK normal VM terbaru: [ruma-ai-output-guard.apk](output/apk/ruma-ai-output-guard.apk), debug x86_64. Diagnosis dan batas hasil AI: [tahap 1–3](docs/FINAL-STAGES-1-3.md).
