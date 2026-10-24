# Catatan pengembangan Ruma

Dokumentasi tiap tahap disimpan di docs/, bukti uji di docs/qa/. Tidak mencatat password, ID token, API key AI, atau private key server.

## 19 Oktober 2026 — fondasi Flutter dan akun

- Scaffold Flutter Android dibuat di root project, package id.ruma.app. Dokumen, desain, dan backend sebelumnya dipertahankan.
- Firebase Core/Auth serta flutter_svg dipasang; pubspec.lock mengunci versi yang terselesaikan.
- Konfigurasi Android Ruma diambil dari registrasi Firebase yang sudah ada. Hanya konfigurasi klien publik masuk aplikasi; secret NaraRouter dan service account tetap di server.
- Desain auth, beranda dan profil dibaca dari Figma; token, Manrope, ilustrasi dan maskot memakai aset lokal.
- Fokus tahap ini: daftar, masuk, akun sementara/link email, logout, nama panggilan, sesi login dan lima tab navigasi. Ledger dan percakapan AI belum disambungkan.
- Optimasi CPU proxy tetap ditunda sesuai CPU-FOLLOWUP.md. Tidak ada panggilan model tambahan untuk tahap ini.
- Hasil analisis, pengujian Android dan batas cakupan akan ditambahkan setelah verifikasi.

### Selesai: scaffold dan pemeriksaan tampilan

- flutter analyze: tidak ada temuan.
- flutter test: 3 pengujian lulus (validasi/penyamaran error akun, viewport 320×640 dengan teks 200%, dan navigasi lima tab).
- flutter build apk --debug: berhasil. APK ini belum menjadi release pengumpulan.
- Kartu bersama memakai Material agar efek sentuh terlihat. Navbar memakai ekspor SVG Figma terpisah untuk lingkaran dan wajah; aset badge lama memiliki child namespace yang tidak didukung renderer Flutter. Vektor sumber lama tidak diubah.
- Berikutnya: verifikasi SDK Firebase di perangkat Android dan bukti screenshot.

### Selesai: pengujian akun terisolasi di HP

- HP Android 36 tersambung melalui USB setelah koneksi nirkabel dan konfirmasi instalasi menghambat percobaan sebelumnya.
- Rangkaian Auth Emulator lulus: daftar langsung, anonymous, penautan UID, login salah/benar, logout batal/konfirmasi, nama dan navigasi. Fixture terakhir dihapus.
- Perbaikan skrip tes: tombol kembali kustom dikenali melalui tooltip, emulator localhost memakai pemetaan eksplisit, TestTextInput mengikuti client field setelah busy, dan konversi screenshot dilakukan per tes.
- Manrope diterapkan pada seluruh TextTheme; posisi konten shell dirapikan ke atas dan tab Asisten mempunyai titik aktif. Screenshot menunggu SVG selesai didekode agar bukti tidak menampilkan ikon kosong sementara.
- APK profile untuk pratinjau berhasil dibangun sekitar 30 MB; pemeriksaan exact-value tidak menemukan secret AI atau private key server yang diuji. Lihat qa/flutter/apk-inspection.json.
- Percobaan gabungan emulator + named production app sebelumnya gagal pada jaringan/link dan cleanup token. Pengujian produksi dipisah ke proses default app tersendiri. Cleanup satu fixture lama belum terkonfirmasi; tidak ada penulisan ledger atau panggilan model. Hasil produksi dan pemasangan APK normal menyusul.

### Selesai: Firebase produksi dan APK pratinjau

- Uji SDK Firebase pada default app produksi lulus: anonymous, penautan email dengan UID tetap, nama tersimpan/diperbarui, logout batal/konfirmasi, password salah ditolak dengan isian email tetap ada, login benar, daftar langsung dan lima tab. Fixture terakhir dihapus.
- Preflight HTTP Dart untuk kebijakan password dihapus karena menghambat pendaftaran. Form tetap divalidasi dan Firebase Auth memeriksa kebijakan server saat create/link. Tidak melemahkan Rules atau konfigurasi akun.
- flutter analyze: tanpa temuan; flutter test: 3 pengujian lulus. Hasil emulator dan produksi tersimpan terpisah di qa/flutter/.
- APK profile ARM64 dari lib/main.dart berhasil dibuat, dipasang dan cold launch pada HP Android 36. Firebase produksi aktif; bukan APK integration test. SHA-256 dan pemeriksaan exact-value secret server tersedia di qa/flutter/apk-inspection.json.
- Emulator lokal dihentikan, reverse port uji dilepas. Tidak mengubah billing, provider, Rules produksi atau kuota AI.
- Batas: ledger/CRUD manual, agent di Flutter, FCM/cron, pengujian keyboard asli/offline/process kill dan release signing belum selesai. Satu cleanup fixture lama tetap belum terkonfirmasi dan dicatat pada laporan fondasi.
- Berikutnya: repository dan form agenda/keuangan manual, disertai Security Rules per UID yang diuji sebelum deployment.

## 19 Oktober 2026 — agenda manual (selesai untuk slice sekali jalan)

- Menambahkan Cloud Firestore SDK, model/repository/store agenda, form bersama, detail dan daftar mingguan dengan timeline.
- Mendukung kegiatan sekali jalan, kuliah berwaktu, tugas tanpa waktu, deadline/durasi/prioritas/catatan, edit, selesai/buka kembali dan soft delete dengan konfirmasi.
- Simpan memakai transaksi agenda/core/receipt, versi dan revisi untuk konflik serta ID stabil untuk retry. Beranda membaca jumlah kegiatan dari store akun aktif.
- Rules rollout khusus agenda disiapkan; path fitur lain tetap ditolak. Kandidat Rules batch lama dipertahankan untuk regresi.
- 12 uji Rules dan 10 uji unit/widget lulus pada pemeriksaan awal. Uji Android serta status produksi akan ditambahkan setelah selesai.
- SQLite tidak ditambahkan; memory cache SDK dan baca server dipakai pada tahap ini. Pemulihan draf setelah process kill serta seri mingguan belum termasuk slice ini.

### Selesai: Rules dan uji produksi agenda

- Pengguna mengizinkan publikasi Rules agenda dan pengujian/cleanup data sintetis. File khusus agenda diterbitkan via Firebase Console; isi editor dicocokkan dengan file lokal. Bukti/hash berada di qa/agenda/deployment.json.
- 12 uji Rules, 10 uji unit/widget serta suite CRUD/UI SDK Android emulator lulus. Suite SDK Android produksi terpisah juga lulus: tambah/baca, edit, hapus, retry tanpa duplikasi, penolakan tanpa login dan akun lain.
- Dua akun Auth dan lima dokumen fixture produksi dibersihkan; lingkup hanya UID pengujian ini. Tidak menyentuh data akun lain, counter kuota, billing, IAM atau Worker. Tidak memanggil model AI. Fixture Auth historis yang belum terkonfirmasi tetap dicatat pada laporan fondasi.
- Emulator lokal/data demo, reverse port uji dan server preview sementara dibersihkan. Laporan tahap, cara menjalankan ulang, batas offline/seri dan bukti ada di AGENDA-IMPLEMENTATION.md.
- Berikutnya: transaksi, anggaran dan rangkuman keuangan manual; agent dan notifikasi menyusul kedua jalur manual.

### Selesai: APK pratinjau agenda

- Build profile ARM64 dari lib/main.dart dengan Firebase produksi berhasil (40.3 MB). APK normal menggantikan harness pengujian di HP melalui instalasi USB; cold launch berhasil dan foreground id.ruma.app terkonfirmasi.
- Exact-value scan dua secret server aktif tidak menemukan kecocokan atau file privat di APK. Hash/ABI/batas pemeriksaan tersedia pada qa/agenda/apk-inspection.json; APK di output/apk/ruma-agenda-preview.apk.
- Analyzer akhir bersih setelah merapikan kurung driver test baru. Perubahan driver hanya lint, tidak mengubah aplikasi; pengujian tidak diulang tanpa alasan baru.
- README, metadata dan dokumen status diperbarui. Aplikasi belum final: keuangan manual adalah tahap berikutnya, diikuti agent/notifikasi. Pengulangan mingguan, draft process-kill, undo dan release signing belum termasuk tahap ini.

## 19 Oktober 2026 — keuangan manual (verifikasi lokal)

- Menambahkan model, repository, store keuangan; form bersama pemasukan/pengeluaran/edit dan anggaran, detail/soft delete, riwayat/pencarian/filter, laporan kategori serta angka Beranda.
- Selisih ledger lama/baru memperbarui core, satu/dua bulan dan receipt dalam satu transaksi. Anggaran tidak mengubah saldo; input memakai integer rupiah dan tanggal WIB. UID/version/retry mengikuti pola agenda.
- Kandidat Rules gabungan terpisah dari Rules agenda aktif. Batas evaluasi awal diperbaiki dengan menghitung map kontribusi sekali; 16 uji keuangan dan 12 regresi Rules agenda lulus. 17 unit/widget lulus; analyzer bersih pada pemeriksaan awal.
- ADB USB native tidak menemukan HP; backend libusb pada port lokal 5038 berhasil mengenali perangkat setelah pengguna mengaktifkan ulang USB debugging. Uji memakai emulator demo-ruma melalui reverse 9096/8086; tidak menulis produksi.
- Perbaikan UX: snackbar disembunyikan saat membuka form baru; tes menunggu pesan sementara sebelum menyentuh aksi di bawahnya. Detail memakai ikon settings-2/circle-alert sesuai desain, aset lokal dipertahankan tanpa stretch.
- Laporan lengkap: FINANCE-IMPLEMENTATION.md. Bukti SDK Android, APK dan status persetujuan produksi akan dilengkapi setelah selesai. Tidak ada model AI, Worker, billing atau IAM yang diubah.

### Koreksi dari uji SDK Android

- Pemeriksaan offline menemukan disableNetwork tidak menolak runTransaction sendiri pada lingkungan emulator Android yang diuji. Bukti red disimpan di qa/finance/offline-before-fix.log.
- Menambahkan preflight core Source.server sebelum callback tulis, sebagaimana pembacaan server yang sudah menjaga jalur agenda. Tidak menambah connectivity package atau antrean otomatis. Mengulang kasus offline dan memastikan ID yang gagal tidak muncul setelah enableNetwork.
- Beberapa percobaan sebelumnya terhenti oleh konfirmasi instalasi/putus USB, tooltip back berbahasa Indonesia dan snackbar sementara yang menutupi target tes. Driver memakai tooltip Kembali, menunggu pesan dan memulihkan reverse saat USB terhubung ulang; tidak menandai percobaan tersebut sebagai lulus.

### Selesai: verifikasi lokal dan kandidat publikasi keuangan

- Suite SDK/UI Android terakhir lulus, termasuk regresi offline setelah preflight Source.server. Enam screenshot tersedia dan diperiksa. Bukti di qa/finance/device-results.json.
- Pemeriksaan akhir: 17 unit/widget lulus, analyzer bersih, 16 uji Rules keuangan dan 12 regresi Rules agenda lulus pada file gabungan terakhir.
- APK profile ARM64 normal kandidat berhasil dibuat (sekitar 40.5 MB), exact-value scan key/PEM server tidak menemukan kecocokan/file privat. Hash tersedia di qa/finance/apk-inspection.json.
- Rules gabungan disiapkan pada editor Console dan dibandingkan dengan file lokal, belum dipublikasikan. Uji produksi serta cleanup exact UID telah disiapkan dengan guard eksplisit, belum dijalankan. Tidak mengubah firebase.json yang menunjuk Rules agenda aktif.

### Selesai: Rules produksi, SDK cloud, cleanup dan APK keuangan

- Pengguna mengizinkan publikasi/uji produksi serta APK normal. Rules gabungan diterbitkan pukul 22.02 WIB; firebase.json diperbarui untuk menunjuk file aktif. Bukti/hash ada di qa/finance/deployment.json.
- Uji cloud pertama berhenti pada budget karena skrip menganggap ringkasan bulan belum ada; guard versi menolak. Skrip memakai month.version yang benar, dan driver menyimpan hasil kegagalan agar cleanup dapat ditelusuri. Tidak mengubah app untuk meloloskan guard.
- Suite produksi final lulus: tambah/baca, angka saldo/periode, retry tanpa duplikasi, budget tidak mengubah saldo, edit lintas bulan, soft delete, penolakan tanpa login dan akun lain. Bukti qa/finance/cloud-results.json.
- Tiga akun sintetis tahap ini dihapus melalui SDK (satu percobaan awal + dua final); enam + sepuluh dokumen fixture dibersihkan dengan exact UID dan subkoleksinya diverifikasi kosong. Tidak menyentuh akun/data lain atau fixture Auth historis yang masih dicatat terpisah.
- APK normal profile ARM64 terbaru dipasang dan cold launch berhasil. Emulator/data demo dibersihkan, server dihentikan, reverse uji dilepas. Tidak mengaktifkan billing, mengubah IAM/Worker, memanggil model atau menambahkan SQLite.
- Berikutnya: integrasi agent percakapan/draf/persetujuan dengan jalur simpan manual yang sudah teruji, lalu notifikasi dan agenda lanjutan.

- Foreground normal id.ruma.app terkonfirmasi setelah cold launch. Screenshot terakhir yang bersamaan dengan input akun pengguna tidak disimpan; bukti normal memakai install/launch log. Tidak mengganggu interaksi HP selanjutnya.

## 19 Oktober 2026 — draf gabungan Asisten (kandidat lokal)

- Pengguna memilih menyelesaikan draf gabungan dahulu. Menambahkan HTTP client endpoint tetap, persetujuan pemrosesan pesan, parser ketat, store per UID, layar Asisten/tinjauan/hasil, serta mode edit draf pada form manual yang sama. Tidak menambahkan package runtime.
- Menambahkan commit atomik maksimal 3 agenda + 3 transaksi, revisi persetujuan, konflik jadwal/data, receipt dan ID stabil. Hasil commit tak pasti mengunci edit sampai retry identik dapat diperiksa. Edit manual transaksi AI mempertahankan source ai.
- Kandidat Rules baru terpisah dari Rules produksi: 10 uji batch + 16 regresi keuangan + 12 regresi agenda lulus; 14 regresi backend dan 23 unit/widget/render lulus. Analyzer akhir bersih. Tidak memanggil provider atau mengubah layanan produksi.
- Render dengan Manrope dan aset lokal diperiksa. Indikator review 6×6 diunduh dari aset MCP node 279:5001; tidak mengubah file Figma/PDF. APK normal profile ARM64 kandidat 40.8 MB berhasil dibuat; pemindaian exact secret UTF-8/UTF-16 menemukan 0 kecocokan/file privat. Hash di qa/assistant/apk-inspection.json.
- ADB kembali mengenali HP setelah kedua server dimuat ulang dan backend libusb dipakai pada port 5038. Suite Android lokal mulai berjalan dan menulis fixture batch/edit ke emulator. Layar HP masuk Dozing/terkunci ketika pemeriksaan UI menunggu frame; pengguna diminta membukanya. Jangan menganggap suite perangkat lulus sebelum device-results tersedia.
- Rincian perilaku/batas dan langkah berikutnya ada di ASSISTANT-IMPLEMENTATION.md. Draf dan consent masih per sesi dalam memori; jam agenda harus disunting pengguna; baca/edit/hapus catatan lama via AI dan notifikasi belum termasuk tahap ini.

### Selesai: uji SDK/UI Android Asisten

- Setelah pengguna membuka HP, suite lokal lulus dalam 13 detik. Pemeriksaan native: 3+3 atomik lintas bulan, receipt retry, stale, overlap, offline, edit transaksi AI mempertahankan source, edit form draf tidak menyimpan, keluarkan item, dan simpan pilihan. Bukti qa/assistant/device-results.json + tiga screenshot diperiksa.
- Gangguan percobaan pertama berasal dari layar Dozing/terkunci dan koneksi USB yang sempat hilang; bukan kelulusan dan bukan alasan mengubah kode app. Helper menjaga layar menyala saat USB hanya selama test, memulihkan setting 0 di finally. Tidak menambahkan perubahan power setting ke aplikasi.
- Kandidat Rules disiapkan pada Console, readback clipboard cocok seluruh 23.319 karakter dengan file lokal. Tombol Publish belum ditekan; screenshot qa/assistant/rules-awaiting-publication.jpg. Publikasi dan uji cloud satu panggilan model menunggu konfirmasi.

- Sambil menunggu izin produksi, APK keuangan normal sebelumnya dipulihkan dengan install Success. Fixture emulator (termasuk percobaan terputus) dibersihkan; server emulator dihentikan dan reverse 9096/8086 dilepas. Kandidat Asisten tetap tersimpan terpisah, belum dipasang sebagai app produksi.

### Selesai: Asisten produksi, cleanup dan APK normal

- Pengguna memberi izin publikasi/uji produksi. Rules Asisten terbit pukul 22.52 WIB; firebase.json menunjuk file aktif, bukti screenshot/hash di qa/assistant. Tidak mengubah Worker, secret, IAM atau billing.
- Suite SDK produksi lulus 23 detik dengan satu panggilan model nyata: satu agenda + satu transaksi, tidak ada operasi sebelum persetujuan, commit/retry tidak menggandakan item, saldo -Rp18.000, serta penolakan tanpa login dan lintas UID. Ini melengkapi suite lokal 3+3/UI yang sudah lulus, bukan uji seluruh roadmap agent.
- Dua akun Auth sintetis dihapus melalui SDK. Cleanup exact UID menghapus lima dokumen fixture dan memverifikasi semua subkoleksi kosong; counter kuota dan data lain tidak disentuh. Fixture Auth lama yang belum dikonfirmasi dari tahap fondasi tidak dicampur ke klaim cleanup ini.
- APK normal profile ARM64 Asisten dipasang (Success) dan cold launch; file preview memiliki hash yang sama dengan kandidat yang dipindai. Pengaturan layar USB kembali 0, harness sudah diganti app normal. Docs/README/metadata diperbarui.
- Tahap create-only selesai. Berikutnya baca/edit/hapus catatan lama via AI; pencarian slot, notifikasi, pengulangan dan persistensi draf belum aktif. Catatan CPU tetap ditunda, tidak dibuka kembali karena uji ini lulus tanpa error CPU yang terkonfirmasi.

## 19 Oktober 2026 — perapian halaman Flutter Ruma

- Membaca panduan Impeccable/Ponytail, memeriksa tema/komponen dan screenshot native tahap sebelumnya. Menjaga brand dan fitur; tidak mengubah Figma/PDF/backend. Memakai konteks implementasi yang ada karena PRODUCT.md/DESIGN.md tidak tersedia; tidak membuat sistem visual baru.
- Menyatukan wadah halaman, hierarki app bar, kartu/list/form, tombol pasangan responsif dan indikator loading, scroll akun/keyboard, serta dialog yang seluruh isinya bisa digulir. Navbar tetap lima ikon dan memberi ruang saat keyboard muncul. Sambutan, kalender mingguan dan ringkasan uang mengikuti ruang/font yang tersedia.
- Matriks mencakup 19 halaman/keadaan pada tiga ukuran/orientasi, termasuk teks 200%, keyboard dan dialog. Ditemukan lalu diperbaiki overflow 14 px pada dialog profil mendatar + keyboard. 27 uji akhir lulus, analyzer bersih; detector satu kali tidak menemukan pola mekanis.
- Perangkat USB belum terdeteksi dan pengguna diminta menyambungkannya. Suite native 25 capture sudah disiapkan tetapi belum dijalankan; tidak mengklaim pemasangan atau kelulusan visual HP. APK normal baru disiapkan terpisah. Rincian di UI-POLISH.md.

- APK UI normal profile ARM64 40.8 MB selesai dibangun, hash dan scan secret 0 tercatat di qa/ui-polish/apk-inspection.json. Kontras pasangan warna utama minimal 4,53:1. Emulator persiapan dibersihkan/dihentikan. APK belum dipasang karena HP belum terdeteksi; tidak ada data produksi atau panggilan model pada tahap UI ini.

### Selesai: verifikasi HP, pemasangan dan PDF review

- Setelah USB terhubung, suite native UI lulus. Pengambilan pertama memiliki gambar berulang karena callback Android dijalankan setelah test; bukti visual diganti lewat capture native sinkron per layar, dengan pemeriksaan foreground. Menunggu ringkasan Beranda selesai, mengambil bagian bawah tinjauan dan mengembalikan hasil draf ke posisi atas. Tidak mengubah kode runtime aplikasi.
- 26 screenshot akhir unik diperiksa. Keyboard nyata, date/time picker, profil, draf, form, dan teks 130% tercakup. Analyzer tetap bersih; 27 unit/widget tests dari perubahan UI tetap lulus. Tidak membuat klaim uji seluruh fitur roadmap.
- APK UI normal dipasang Success, cold launch Status ok, foreground Ruma terkonfirmasi. Hash APK tidak berubah dari scan secret. Data emulator Auth/Firestore demo-ruma dibersihkan (200), reverse dilepas, server dihentikan, dan pengaturan layar dipulihkan ke 0. Tidak ada panggilan model/penulisan produksi.
- Atas permintaan pengguna, dibuat output/pdf/ruma-review-antarmuka.pdf: 9 halaman A4 mendatar dengan 26 screenshot bernomor, bookmark dan nama layar. Seluruh halaman dirender dan diperiksa; screenshot tidak di-stretch. Dokumentasi dan metadata diperbarui di docs/UI-POLISH.md, qa/ui-polish, README dan project-context.json.

## 19 Oktober 2026 - teks ringkas, kartu Asisten dan audit realisasi Figma

- Menjalankan revisi kartu yang ditandai pada PDF serta usulan pengurangan teks yang disetujui pengguna. Maskot 64x64 sejajar dengan isi pendek pada ruang cukup dan tersusun vertikal pada layar kecil/teks besar. Teks berulang/status siap/sukses dihapus, batas kemampuan dipindah ke tombol Tentang Asisten, dan konsekuensi penting tetap ditampilkan.
- RumaHeading mendukung subjudul kosong tanpa menyisakan gap. Form anggaran tidak lagi mengulang helper per isian. Keterangan waktu dipindahkan ke label WIB, petunjuk draf tanpa jam hanya muncul sebelum penyimpanan dan bila relevan. Tidak mengubah data, validasi, transaksi, atau backend.
- 27 uji lokal lulus dengan matriks 19 keadaan, teks 200%, landscape/keyboard dan dialog informasi Asisten. Analyzer bersih; render lokal diperiksa. APK normal profile ARM64 kandidat selesai dibangun (hash di qa/ui-copy/status.json); belum dipasang. Pengguna meminta menunda sambungan HP dan pengingat sekitar satu jam; pengingat thread dibuat. PDF lama dipertahankan dan ditandai belum memuat revisi ini.
- Membaca Figma melalui MCP: 5 page, 71 frame Prototype pada page 42:53; membandingkan 5 screenshot utama dan membaca 4 layar tambahan. Tidak mengubah kanvas Figma. Laporan memisahkan kesamaan brand, perbedaan tata letak, dan kemampuan yang belum diimplementasikan. Bukti di qa/figma-comparison.
- Menjawab pertanyaan VM: KVM usable pada i5-12450H, RAM 16 GB, ruang kosong 53 GB; emulator binary sudah ada 821 MB, system image belum ada. Android 15 Google APIs x86_64 unduhan resmi 1.738.815.903 byte. Rekomendasi satu AVD dengan RAM 2-3 GB dan ruang tambahan perkiraan 6-10 GB; belum memasang image/AVD.

## 20 Oktober 2026 - Android Emulator dan PDF laporan per frame

- Pengguna melanjutkan sesudah jeda download dan meminta pengujian VM + laporan PDF per frame. AVD Ruma_API35/Pixel 5 berhasil boot (API35 Google APIs x86_64), RAM2GB/2core/KVM; data partition diatur2GB. Launcher dan dokumentasi ada di scripts/start-android-emulator.sh serta ANDROID-EMULATOR.md.
- Suite native utama akhir lulus dengan 27 screenshot, memakai data Auth/Firestore lokal demo-ruma. Percobaan pertama gagal karena race pembaruan inset IME; assertion dipertahankan dan harness menunggu inset native. Tutorial stylus Gboard terdeteksi dalam screenshot; handwriting AVD dimatikan dan uji keyboard khusus lulus. Bukti gagal disimpan, screenshot22 akhir berasal dari uji khusus. Data fixture Besok diselaraskan ke hari berikutnya. Tidak mengubah kode app.
- Evaluasi UI per layar:21 LULUS,5 CATATAN,1 PERLU REVISI. Temuan utama tombol Simpan tanpa waktu pada form kuliah yang mewajibkan jam; belum diperbaiki karena tahap ini pengujian/pelaporan. Catatan lain meliputi kepadatan Beranda, hari yang bergulir, kelengkapan Profil, jam draf manual dan posisi tombol Kirim saat IME muncul.
- PDF output/pdf/ruma-report-per-frame.pdf selesai:10 halaman,27 screenshot native bernomor dengan status/cek/catatan. Label/hash diverifikasi, seluruh halaman dirender Poppler dan diperiksa. PDF lama dipertahankan sebagai arsip.
- Analyzer akhir bersih. APK normal debug x86_64 lib/main.dart dipasang Success dan cold launch Status ok di AVD; tidak meninggalkan harness sebagai app normal. Fixture lokal dibersihkan(200), Firebase emulator dihentikan, reverse dilepas dan screen setting dipulihkan1. AVD tetap terbuka.0 panggilan AI/penulisan produksi. APK ARM64 HP tidak dipasang ulang.
- Pengingat USB sudah pernah disampaikan; automation satu kali dijeda agar tidak mengirim ulang. Status/proyek/README dan laporan di docs diperbarui.

## 20 Oktober 2026 — agent tahap 1–3, kandidat lokal lulus

- Mengimplementasikan saran slot beberapa agenda dalam rentang kesediaan yang bisa diubah, mempertahankan waktu eksplisit dan mempertimbangkan blocker/agenda lain di draf/deadline. Tinjauan dan form manual tetap dipakai.
- Menambah allowlist tool baca, edit/hapus dan klarifikasi. Aplikasi membaca data per UID dan menyusun laporan dengan angka database; model tidak diberi ledger, path atau hak commit. Satu perubahan lama per tinjauan, exact target + expected version, receipt stabil, dan undo selama tinjauan terbuka. Rules kandidat memulihkan tombstone persis dengan ledger/bulan yang sesuai.
- 32 tes Flutter, 17 backend dan 38 Rules lokal lulus; analyzer bersih. Suite native Android API35 lulus sembilan kelompok pemeriksaan/enam tangkapan layar dengan respons model sintetis dan SDK Firebase nyata. Percobaan pertama gagal karena status keyboard terhapus di body Scaffold; status kini diteruskan MainShell, assertion posisi tombol Kirim yang sama lulus. Rincian sebelum/sesudah dan hasil undo diperjelas.
- APK normal debug x86_64 dibangun, scan secret exact UTF-8/UTF-16 nol dan file privat nol; dipasang Success/cold launch Status ok di VM. Worker dry-run berhasil. Fixture lokal dibersihkan HTTP 200, reverse dilepas, layar kembali 1, app normal menggantikan harness.
- Kandidat belum dipublikasikan: server produksi masih versi sebelumnya. Suite empat panggilan model sintetis dan cleanup exact UID disiapkan tetapi belum dijalankan. 0 model nyata/penulisan produksi tahap ini. CPU, FCM, seri, SQLite, persistensi chat dan undo lintas sesi tidak ditambahkan. Laporan dan hash ada di AGENT-STAGES-1-3.md serta qa/agent-stages-1-3/candidate-manifest.json.

### Selesai: publikasi dan uji produksi agent tahap 1–3

- Pengguna menyetujui publikasi Worker/Rules dan maksimal empat panggilan AI sintetis. Hash keempat berkas kandidat diverifikasi sebelum publikasi. Melalui sesi dashboard yang sudah tersedia, Rules pemulihan persis berhasil terbit dan Worker `f0bc9c39` menjadi Active/Latest (sebelumnya `c6bedf81`). Tidak membuat kredensial CLI atau mengubah IAM/billing/Secret.
- Suite Android produksi lulus dalam 65 detik dengan tepat empat panggilan model: gabungan dua agenda dan satu transaksi, saran slot, simpan/retry tanpa duplikasi, baca laporan tanpa menulis operasi, edit/undo agenda, delete/restore transaksi dengan saldo -Rp18.000 → Rp0 → -Rp18.000, dan isolasi UID. Bukti qa/agent-stages-1-3/cloud-results.json dan cloud-test.log.
- Dua akun Auth sintetis dihapus melalui SDK; cleanup exact UID menghapus 10 dokumen fixture dan memverifikasi semua subkoleksi kosong. Counter kuota dipertahankan. Percobaan cleanup awal gagal koneksi, lalu berhasil memakai dukungan proxy jaringan Node; tidak mengulang panggilan model.
- APK normal debug x86_64 yang hash/scan-nya sama dipasang kembali di VM (Success), cold launch Status ok dan foreground Ruma. Pengaturan layar kembali 1. Tidak meninggalkan harness, tidak memperbarui HP ARM64/PDF, dan tidak membuka kembali pekerjaan CPU yang ditunda. Dokumentasi, README dan metadata diperbarui.

## 20 Oktober 2026 — kandidat pengingat dasar dan notifikasi lokal

- Membuat pengaturan notifikasi melalui Profil, pengingat per agenda dengan acuan mulai/deadline dan lead 5/10/15/30/60 menit, inbox 20 terbaru, token per instalasi/UID, foreground lokal dan routing payload ke agenda terbaru dengan pemeriksaan akun. Default nonaktif; belum mengaktifkan produksi.
- Menghubungkan perubahan agenda dan job secara atomik, termasuk edit/hapus/undo dari Asisten. Backend kandidat mempunyai query antrean bounded, lease/CAS/renewal, revalidasi generation/sumber, retry parsial dan Retry-After, token invalid, cap push terpisah dan inbox satu ID. Timestamp REST mempertahankan presisi Firestore. Tidak menambahkan AI cron.
- Memasang package FCM/local notifications/shared preferences; resource Firebase native memakai Google Services4.5.0 khusus build produksi agar emulator tetap demo-ruma. Android channel/icon/permission/desugaring tersedia. API token legacy ditandai karena kontrak HTTPv1 belum bermigrasi ke FID.
- 35 Flutter + 27 backend + 42 Rules lokal lulus; analyzer bersih. SDK/UI Android16detik lulus dengan3screenshot: konfigurasi/no-op, move/complete/reopen/delete/restore atomik, kartu foregroundIDstabil, tap lama/UIDlain. Ini respons lokal yang dimasukkan ke handler, bukan FCM nyata. Izin diberikan khusus fixture AVD setelah instalasi. Kesalahan harness awal (Scaffold bersarang, waktu tunggu route, izin ter-reset saat reinstall) diperbaiki, bukan disamarkan sebagai kegagalan layanan produksi.
- APK kandidat normal x86_64 dan dry-run Worker berhasil; manifest/hash/scan tercatat di qa/notifications. Fixture demo-ruma dibersihkan HTTP 200. Paket harness dilepas; APK agent normal sebelumnya dipulihkan sampai Rules baru kompatibel. Tidak ada model/FCM nyata atau penulisan produksi.
- Berikutnya memerlukan izin khusus: role rumaFcmSender hanya cloudmessaging.messages.create pada service account proxy yang sudah ada, Rules+indeks+Worker, cron tiapmenit, maksimal3FCM ke akun/agendaAVDsintetis dan cleanup exactUID. Snooze/seri tetap di luar potongan dasar ini. Lihat NOTIFICATION-IMPLEMENTATION.md.

## 20 Oktober 2026 — publikasi pengingat produksi

- Pengguna menyetujui role send-only, Rules/indeks/Worker, cron tiap menit, maksimal 3 pesan FCM sintetis dan cleanup.
- Custom role rumaFcmSender hanya cloudmessaging.messages.create diberikan kepada service account proxy yang sudah ada. Rules pengingat dipublikasikan, indeks collection-group CICAgOjXh4EK Enabled, Worker kode37c46502 aktif, NOTIFICATIONS_ENABLED=true dan cron Every minute tersimpan. Konfigurasi lokal diselaraskan.
- Pendaftaran perangkat dan penulisan pengingat produksi telah berhasil di suite native. Pengiriman FCM masih menunggu cron baru aktif; belum dinyatakan lulus. Bukti UI tersimpan di docs/qa/notifications/. Tidak menambah key/billing atau panggilan model.

## 20 Oktober 2026 — FCM produksi terverifikasi dan cleanup selesai

- Tepat3 pesan nyata: foreground pada callback SDK, background dan ketukan native ke agenda, lalu proses berhenti dan cold tap pada APK normal. Job akhir attempts1; quota push global3. Tidak memanggil model.
- Timeout aktivasi cron, benturan fixture kedua, dan HTTP chunked harness didiagnosis serta dicatat tanpa mengubah validator/fitur aplikasi. Semua5 akun sintetis serta24 dokumen dibersihkan exactUID, counter dipertahankan. Token cleanup sementara dihapus.
- APK normal x86_64 terpasang dengan hash cocok kandidat; data dan izin perangkat khusus fixture dipulihkan. Analyzer akhir bersih. Konfigurasi aktif, metadata, README dan NOTIFICATION-IMPLEMENTATION.md diselaraskan; bukti di docs/qa/notifications/production-summary.json.
- Snooze, pengulangan mingguan, dialog izin manual, force-stop/Doze dan perangkat fisik tetap belum diverifikasi/diimplementasikan sesuai batas laporan. Tidak membuat PDF atau mengubah desain.


## 20 Oktober 2026 — kandidat riwayat dan pemulihan Asisten

- Menambahkan workspace Firestore per UID: input, jawaban, hingga 10 percakapan sebelumnya, preferensi rentang jam, serta tinjauan batch atau perubahan catatan/undo. Riwayat tampil lewat bagian lipat pada halaman Asisten; tidak menambah halaman. Riwayat tidak otomatis dikirim ke provider. Tidak menambah SQLite atau menyatakan pemulihan offline.
- Snapshot menyimpan ID target/operasi/revision/flags; checkpoint dikonfirmasi sebelum mutasi, receipt exact requestKey diperiksa ketika pulih. Workspace memakai revision CAS agar perangkat lama tidak menimpa data baru. Payload rusak gagal tertutup, akun diisolasi dan status simpan/retry/reload ditampilkan.
- 43 tes Flutter + 46 Rules + 27 backend = 116 lulus; analyzer akhir bersih. Suite SDK Android API35 lulus enam kelompok. Restart proses nyata pada APK normal dengan backend demo mengembalikan draf yang sama sebagai menunggu persetujuan; receipt tetap 3, saldo tetap -Rp18.000, tidak ada commit otomatis. Percobaan awal harness kehilangan sesi Auth; fixture login emulator-only memperbaiki metode uji dan bukti percobaan dipertahankan.
- APK normal kandidat debug x86_64 dibangun; scan exact secret server UTF-8/UTF-16 dan file privat nol. Hash serta bukti di qa/assistant-memory/candidate-manifest.json. Fixture Auth/Firestore lokal dibersihkan HTTP 200, Firebase emulator dihentikan, reverse dilepas, layar kembali 1. APK normal notifikasi produksi sebelumnya dipulihkan dan cold launch berhasil; VM tetap terbuka.
- 0 penulisan produksi, 0 model nyata dan 0 FCM pada tahap ini. Kandidat Rules hanya menambah workspace owner; belum dipublikasikan. Maksimal dua akun sintetis untuk uji SDK produksi dan cleanup exact UID sudah disiapkan, tanpa AI/FCM. Meminta izin setelah kandidat konkret siap. Worker/IAM/cron/billing tidak berubah; CPU tetap ditunda. Rincian lengkap di ASSISTANT-MEMORY.md.


### Selesai: publikasi dan uji produksi pemulihan Asisten

- Pengguna menyetujui Rules workspace, uji maksimal dua akun sintetis, cleanup dan pemasangan normal. Hash sumber/APK sesuai kandidat. Rules terbit 22.33 WIB melalui Firebase Console; sumber editor persis sebelum/sesudah publikasi dicadangkan. firebase.json diarahkan ke firestore.assistant-memory.rules; indeks notifikasi tetap.
- Suite SDK produksi lulus dalam 11 detik: pemulihan draf/input/ID, receipt setelah commit belum terkonfirmasi tanpa duplikasi (satu batch, saldo -Rp18.000), riwayat setelah store dibuat ulang, dan isolasi akun. Tidak memanggil model atau FCM.
- Kedua akun Auth dihapus melalui SDK. Cleanup exact UID menghapus 7 dokumen, memverifikasi semua subkoleksi fixture kosong, tidak menyentuh data pengguna lain/kuota. Bukti cloud-results.json dan cloud-cleanup.json di qa/assistant-memory.
- APK normal kandidat yang sama dipasang Success, cold launch Status ok, Welcome dan foreground Ruma diperiksa. Hash/scan secret tetap; harness diganti, reverse kosong, layar kembali 1, VM tetap terbuka. HP/ARM64/release belum diperbarui. Worker/IAM/cron/secret/billing tidak berubah, CPU tetap ditunda. Laporan ASSISTANT-MEMORY.md serta production-summary.json, README, arsitektur/data dan metadata diperbarui.


## 21 Oktober 2026 — Beranda merangkum waktu dan uang

- Mengganti dua kartu paragraf dengan hierarki ringkas: kegiatan hari ini/belum dijadwalkan, kegiatan berlangsung/berikutnya, deadline prioritas, saldo tercatat, pengeluaran dan sisa/kelebihan anggaran. Kartu memakai pola, tipografi, ikon dan akses halaman yang setara; Asisten tetap di atas. Kegiatan/deadline membuka detail ID yang tepat. Tidak menambah route.
- Memakai store/repository yang ada. Beranda kembali ke bulan berjalan setelah laporan historis; periode Keuangan ikut direset, data lama tidak diberi label bulan ini saat memuat. Tick menit/resume mengikuti WIB, status selesai/batal dikeluarkan dari daftar terdekat, deadline terlewat dan null/nol/kelebihan anggaran dibedakan.
- 50 tes Flutter lulus (7 baru), analyzer bersih, matriks semua halaman tetap lulus; sumber/hasil di docs/qa/home-summary. Native Android API35 lulus tiga kelompok SDK dengan empat screenshot. Font 130% sempat diverifikasi terpisah; default final sesudah label empty state diratakan lulus. Harness pageBack awal diganti dengan tombol Kembali yang memang dipakai aplikasi; bukti awal disimpan.
- APK normal debug x86_64 ruma-home-summary.apk dibangun, scan exact secret/file privat nol, dipasang Success/cold launch Status ok dan Welcome diperiksa. Seluruh fixture lokal dibersihkan HTTP 200, emulator Firebase dihentikan, reverse kosong, font 1.0 dan stay-on 1 dipulihkan. VM tetap terbuka. 0 model/FCM/penulisan produksi. Tidak mengubah Figma/PDF, backend, Rules atau billing; CPU tetap ditunda. Rincian dan hash di HOME-SUMMARY.md serta qa/home-summary/status.json.

## 21 Oktober 2026 — kandidat tahap akhir 1–3

- Implementasi profil/pref per UID dengan revision CAS, avatar preset, durasi/rentang saran opsional; nilai eksplisit pengguna dipertahankan dan profil tidak dikirim ke model. Agenda kuliah mingguan memakai pola berbatas, ID pertemuan stabil, edit satu/mulai saat ini/seluruh seri dan atomik receipt/revisi/pengingat. Asisten membaca/edit/undo pertemuan lewat jalur lama.
- Worker kandidat memajukan cursor seri dan menjaga sourceVersion saat finalisasi lease. Snooze lima menit lokal memakai Android inexact, validasi owner/source/generation, pembatalan saat perubahan/resume dan serialisasi operasi. Tidak menambah SQLite, exact alarm, IAM atau billing.
- 56 Flutter + 32 backend + 51 Rules = 139 lulus, analyzer bersih, dry-run Worker berhasil. SDK/UI Android API35 lulus delapan kelompok alur dan lima screenshot diperiksa. Percobaan awal konflik dengan induk sendiri diperbaiki di repository; skrip consent setelah pemulihan store juga diperbaiki. Bukti awal dipertahankan.
- APK normal debug x86_64 kandidat dibuat dan pemeriksaan secret/hash dicatat pada manifest QA. Fixture emulator dibersihkan, emulator Firebase dihentikan dan reverse/layar dipulihkan. VM dikembalikan ke APK Home normal yang kompatibel sampai Rules baru dipublikasikan. Tidak ada penulisan produksi, model nyata atau FCM pada tahap ini. Publikasi Rules/Worker serta uji produksi berbatas menunggu persetujuan. CPU tetap ditunda. Lihat FINAL-STAGES-1-3.md.

### Publikasi tahap 1–3; verifikasi produksi belum seluruhnya lulus

- Rules final-stages terbit 08.23 WIB, Worker 774700f2-baa7-48c8-ada9-a417fb6d88db aktif; backup dan sumber publikasi cocok persis kandidat. Firebase config aktif diselaraskan. Tidak mengubah IAM/indeks/secret/cron/billing.
- Profil/preferensi serta isolasi dua akun lulus produksi. Satu FCM diterima SDK dan inbox tersimpan; generation 3 setelah pembatalan membuktikan cursor sempat maju. Suite awal terhenti timeout baca Firestore 15 detik, sehingga active-notification/snooze produksi belum terverifikasi. FCM tidak diulang.
- Satu permintaan AI pada akun kedua mendapat HTTP 502. Outcome Worker ok, CPU 10 ms, bukan CPU limit. Kode provider_unavailable vs invalid_model_output belum diketahui; uji AI nyata belum lulus. Counter per UID 0/1; counter global 2 tidak spesifik fixture. Batas uji dipatuhi, tidak ada retry otomatis.
- Kedua akun Auth serta sembilan dokumen fixture dibersihkan, subkoleksi kosong, kuota historis dipertahankan. APK normal yang hash-nya sama kandidat dipasang/cold launch di VM; harness diganti, reverse kosong dan layar dipulihkan.
- Transport diagnostik test-only disiapkan untuk menyimpan HTTP status/kode allowlist tanpa rahasia; belum dijalankan. Membutuhkan tambahan anggaran uji AI yang disetujui pengguna. Rincian dan batas bukti di FINAL-STAGES-1-3.md serta qa/final-stages-1-3/production-summary.json. Tidak mengklaim semua produksi lulus.

### Diagnosis lanjutan dan pengaman output AI

- Memakai diagnosing-bugs: satu tes diagnostik mengonfirmasi invalid_model_output, lalu satu capture provider sintetis dengan payload sama. Model/finish reason valid, tetapi tool hanya mengembalikan pengeluaran dan melewatkan agenda. Tidak menganggap respons format-valid sebagai keberhasilan gabungan. Tepat dua permintaan tambahan; tidak ada model/FCM tambahan sesudah itu.
- Regresi Worker.handle dari fixture asli merah sebelum fix, hijau setelah fix. Guard cakupan kalimat/kutipan meminta klarifikasi bila kalimat terlewat; invalid_model_output juga menjadi klarifikasi tanpa item. Validasi dan persetujuan tidak dilonggarkan, tidak ada model retry otomatis. Flutter memakai reason allowlist dan teks kode, menolak item pada klarifikasi/reason asing.
- 57 Flutter + 35 backend + 51 Rules tidak berubah = 143 lokal lulus, analyzer bersih. SDK Android dengan Firestore produksi dan replay localhost lulus empat kelompok dalam 12 detik: profil/pref, tanpa mutasi ledger/receipt, klarifikasi pulih tanpa kirim/commit, serta UI tanpa tindakan simpan parsial. Ini bukan panggilan model live setelah fix. Screenshot harness terisolasi bukan audit layout MainShell.
- Worker 359dcc2b-f7e5-494f-83d2-20583c620db5 aktif 100%, kode persis bundle. Tidak mengubah Rules/model/IAM/indeks/cron/secret/billing. APK normal ruma-ai-output-guard.apk dibangun, scan secret nol, dipasang mengganti harness; hash dan sumber di ai-fix-manifest.json.
- Dua akun dan empat dokumen tambahan dibersihkan exact UID. Kumulatif tahap empat akun/tiga belas dokumen; kuota dipertahankan. Tidak mengklaim model selalu benar atau draf gabungan live sudah lulus. Budget tambahan habis; tidak meminta ulang otomatis. Rincian FINAL-STAGES-1-3.md.

## 21 Oktober 2026 — Figma: tabungan menggantikan anggaran

- Menyiapkan rancangan terlebih dahulu sesuai permintaan: agenda tetap ada; anggaran diganti tabungan; laporan memakai diagram lingkaran pengeluaran.
- Empat frame baru (daftar/detail tabungan, perpindahan dana, tinjauan AI) dan tiga frame inti diperbarui (Keuangan, form tujuan, laporan), beserta Beranda dan copy Asisten. Masing-masing halaman Figma kini 75 layar aplikasi; launcher QA terpisah.
- Mempertahankan komponen native/editable dan identitas Ruma; menambahkan komponen kartu tujuan/progres dan baris kategori. Alur Keuangan disusun empat kolom pada canvas.
- Tujuh frame prototype 390×844 memakai konten scroll dan transisi; mode setor/tarik serta tambah/edit berbagi form. Audit 27 aksi navigasi tanpa tujuan yang hilang. Screenshot diperiksa, termasuk perbaikan tinggi baris tombol, warna latar dan progres 100%; teks keterangan maksimal dua baris.
- Batas: contoh statis dan navigasi mockup; belum ada mutasi data atau uji klik otomatis. Implementasi Flutter, backend, Rules dan APK tidak berubah. Tidak membuat PDF atau memakai panggilan AI/FCM.
- Rincian/perhitungan/batas dan langkah berikutnya: FIGMA-SAVINGS-REDESIGN.md; screenshot: qa/savings-figma/. Berikutnya review pengguna sebelum implementasi.

## 21 Oktober 2026 — fondasi data tabungan (selesai lokal)

- Menambahkan model tujuan, setoran/penarikan dan snapshot tabungan serta repository Firestore konkret. Tidak menambah dependensi, database lokal atau lapisan abstraksi.
- Tujuan baru Rp0, edit target tidak memindahkan dana. Setoran/penarikan hanya mengubah alokasi dan uang tersedia; transaksi, laporan bulanan dan saldo tercatat tidak berubah. Deposit dibatasi dana tersedia seluruh tujuan; penarikan dibatasi dana tujuan. Kekurangan dana setelah koreksi pengeluaran tetap terlihat sebagai tersedia negatif.
- Satu transaksi atomik mengikat tujuan, perpindahan append-only, ringkasan, core/revisi dan receipt. Versi usang serta retry dengan isian berbeda ditolak. Baca server merekonsiliasi saldo per tujuan dengan seluruh riwayat; UID lama ditolak setelah pergantian akun. Batas 1.000 dokumen/koleksi ditampilkan sebagai error jika terlampaui.
- Kandidat firestore.savings.rules dan firebase.savings.json ditambahkan. firebase.json, Rules produksi dan data anggaran lama dipertahankan. Suite Rules lama mendapat flag opt-in RUMA_SAVINGS_RULES agar kandidat dapat diuji tanpa menimpa bukti sebelumnya.
- Verifikasi: analyzer bersih; 67 tes Flutter termasuk 10 unit tabungan; 12 tes Rules tabungan + 51 regresi lulus; enam kelompok uji repository melalui SDK Android VM lulus. SDK membuktikan saldo/ledger/anggaran utuh, retry, invalid/stale rollback, offline tanpa antrean dan isolasi dua akun/signed-out.
- Fixture Auth/Firestore demo-ruma dibersihkan, reverse port dilepas dan APK normal ruma-ai-output-guard.apk dipulihkan di VM. Tidak mengubah produksi, mengirim AI/FCM atau membuat APK produksi baru.
- Rincian/batas: SAVINGS-FOUNDATION.md dan qa/savings/verification.json. Berikutnya halaman daftar/detail/form tabungan sesuai Figma; publikasi Rules dibahas ketika UI siap. Agent dan diagram lingkaran belum termasuk tahap ini.

## 21 Oktober 2026 — halaman Tabungan dan ringkasan uang

- Implementasi daftar/detail tujuan, form buat/edit, dan form bersama setor/tarik sesuai context Figma terbaru. Semua angka memakai repository akun aktif; tujuan aktif ditampilkan sebelum yang tercapai. Riwayat dipaginasi 20 item dalam snapshot lengkap.
- Mengganti anggaran pada UI Keuangan/Beranda dengan tabungan dan uang tersedia. Dashboard mengikuti kartu sage, akses Tabungan serta laporan/riwayat langsung. UI laporan tidak menampilkan batas anggaran; kode/data lama belum dihapus. Diagram lingkaran dan agent tabungan tetap tahap selanjutnya.
- SavingsStore mengelola loading/error, generation token, disposal, double submit dan commit sukses/refresh gagal. Sinkronisasi revisi menjaga angka Keuangan, Beranda dan tabungan tidak dicampur dari versi berbeda. Navbar yang sama dipakai daftar/detail; form mempertahankan isian dan konfirmasi pembuangan.
- Uji VM awal menemukan SnackBar lama menutupi Batalkan. Perbaikannya menghapus pesan sebelum membuka form; ditambah regresi widget serta tap-hit-test fatal pada integrasi. Screenshot akhir diekspor dari render tree Android agar layer SVG yang dipertahankan ikut tergambar; arsip percobaan dipisahkan.
- Verifikasi: analyzer bersih, 75 tes Flutter (termasuk delapan tes store/widget baru), 12 uji Rules kandidat dan enam kelompok alur SDK/UI Android lulus. Tanggal, nominal dan perubahan angka ledger diverifikasi terhadap Firestore Emulator demo-ruma; tidak memanggil AI/FCM atau menulis produksi.
- APK normal debug x86_64 kandidat telah dibangun; belum dipublikasikan sebagai rilis atau dipasang dengan Rules produksi baru. Detail hasil, hash, screenshot dan status cleanup tersedia di SAVINGS-UI.md serta qa/savings-ui/verification.json.
- Berikutnya: persetujuan publikasi Rules tabungan dan uji produksi terisolasi, kemudian diagram lingkaran dan tools agent. Firebase produksi tetap memakai Rules final-stages.

## 22 Oktober 2026 — publikasi dan verifikasi produksi tabungan

- Publikasi kandidat Rules tabungan ke mobile-app-3479f sesuai izin pengguna; isi terverifikasi persis setelah reload. firebase.json dan project-context.json mengikuti Rules aktif.
- Lima kelompok uji native Android produksi lulus: tujuan/setor/tarik, rekonsiliasi/idempotensi, validasi dana/versi, kompatibilitas ledger/anggaran lama serta isolasi akun. Analyzer bersih.
- Menggunakan dua akun sintetis; keduanya dihapus. Cleanup terikat manifest menghapus 21 dokumen fixture dan memverifikasi enam koleksi per UID kosong. Nol AI/FCM, tanpa perubahan IAM/billing/Worker.
- APK normal debug x86_64 tabungan dipasang di VM Ruma_API35 dan cold launch berhasil. Harness tidak ditinggalkan sebagai aplikasi normal; VM dihentikan setelah verifikasi.
- Dokumentasi dan bukti: SAVINGS-UI.md, qa/savings-ui/deployment.json, cloud-results.json, cloud-cleanup.json dan normal-apk-launched.png. Berikutnya diagram lingkaran, kemudian tools agent tabungan.

## 22 Oktober 2026 — target wishlist dalam Tabungan

- Menambahkan lima pilihan ikon pada form tujuan yang sama, ikon pada kartu, copy dana kurang serta penanda target tercapai. Tombol detail menjadi Tambah tabungan. Tidak menambah halaman/menu, rekomendasi cicilan atau tools AI baru.
- iconId opsional menjaga kompatibilitas tujuan lama, ikut request key dan dipertahankan saat setor/tarik. Kandidat Rules hanya menerima lima ID ikon; tidak mengubah batas dana atau kepemilikan. Rules aktif produksi tidak diganti.
- Analyzer bersih; 77 tes Flutter, 13 tes Rules tabungan/wishlist, 51 tes regresi, sembilan tes widget konfirmasi serta enam kelompok UI native Android lulus. Pemeriksaan pertama menemukan centang ChoiceChip menimpa SVG; diperbaiki dan hasil akhir dikonfirmasi sekali.
- Percobaan regresi pertama memakai flag fitur lama yang belum lengkap; log diarsipkan. Regresi akhir memakai semua flag fitur gabungan sesuai kandidat dan lulus tanpa pelonggaran Rules.
- Kandidat APK normal debug x86_64 disimpan sebagai output/apk/ruma-wishlist-candidate.apk. Fixture lokal dibersihkan, reverse dilepas, APK tabungan normal sebelumnya dipulihkan dan VM dihentikan. Nol AI/FCM atau penulisan produksi.
- Rincian: WISHLIST-TABUNGAN.md dan qa/wishlist/verification.json. Berikutnya izin publikasi/uji produksi terbatas, lalu diagram lingkaran dan tools agent tabungan.

## 22 Oktober 2026 — audit teks dan keseimbangan UI

Ringkas keterangan menu/form, samakan judul halaman utama, gabungkan grup chip Asisten, tambah pilihan durasi bersama, dan hilangkan kartu laporan kategori tanpa pengeluaran. Tinjau halaman utama, form, detail, riwayat, tabungan, profil serta pengingat; pertahankan informasi konsekuensi/izin. 78 tes Flutter lulus, analyzer bersih, layout diuji normal/sempit 200%/lanskap. Tes preferensi kini memeriksa nilai tersimpan melalui route yang realistis. Render lokal dan audit per halaman: [UI-SIMPLICITY-AUDIT.md](UI-SIMPLICITY-AUDIT.md). Tidak memasang APK atau memublikasikan Rules; persetujuan rollout wishlist tetap tertunda.

## 22 Oktober 2026 — produksi wishlist dan APK release

Atas instruksi pengguna, terbitkan Rules wishlist, verifikasi exact readback, jalankan lima kelompok uji SDK produksi dengan dua akun sintetis, lalu bersihkan kedua akun dan 21 dokumen fixture. Signing release khusus disiapkan secara privat; build universal 0.1.0+1 berhasil setelah memperbaiki regenerasi registrant integration_test dari --no-pub. APK 62,3 MB ditandatangani dan diverifikasi, dipasang di VM, hash instalasi cocok dan cold launch/Firebase init berhasil. 78 tes Flutter dan 64 tes Rules sebelumnya menjadi baseline. Tidak mengubah HP, IAM, billing atau Worker; nol AI/FCM. Dokumentasi: [ANDROID-RELEASE.md](ANDROID-RELEASE.md), bukti: qa/release/verification.json.

## 24 Oktober 2026 — pemulihan konteks, kelengkapan .gitignore, dan publikasi GitHub

- Memulihkan konteks proyek pada sesi Antigravity dari folder backup `ruma-20261022-164938-01a12a84-2e7a-70c1-8312-f658de8338a7/` dan memverifikasi integritas SHA-256 (`rollout-*.jsonl` serta `percakapan-ruma.md` cocok).
- Melengkapi `.gitignore` untuk mengecualikan folder backup sesi (`ruma-[0-9]*/`, `rollout-*.jsonl`), direktori sementara (`tmp/`), state AI/IDE lokal (`.gemini/`, `.codex/`, `.agent/`, `.agents/`, `.idea/`, `.vscode/`), ekstensi kunci privat tambahan (`*.p12`, `*.pfx`, `*.pem`, `*.key`), serta artefak build/log Flutter dan Android.
- Menginisialisasi repository Git lokal pada branch `main`, menghubungkan remote `origin` ke `git@github.com:jabarcihuy/ruma.git`, lalu membuat commit awal (`a2d5918`, 1.174 file) dan melakukan push ke GitHub.
- Verifikasi: pemeriksaan file terlacak memastikan seluruh kredensial lokal (`.local/`, `android/key.properties`), artefak APK (`output/apk/`), `node_modules/`, dan arsip backup sesi berukuran besar terabaikan dengan benar; tidak ada kunci privat atau service account yang bocor ke repository.
- Batas: riwayat commit sebelum inisialisasi baru tidak tersedia karena metadata `.git` dari mesin sebelumnya tidak ikut tersalin; toolchain Flutter/Android SDK pada `/home/abdulinux` serta dependency lokal `backend/` belum disiapkan ulang.
- Berikutnya: penyesuaian path Flutter/Android SDK dan dependency `backend/` di lingkungan `/home/abdulinux`, dilanjutkan implementasi diagram lingkaran pengeluaran dan tools AI untuk tabungan/wishlist.
