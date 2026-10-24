# Keuangan manual — implementasi Ruma

19 Oktober 2026. Keuangan manual selesai untuk cakupan tahap ini: Rules gabungan aktif dan uji SDK Android lokal/produksi lulus. Pengguna secara eksplisit mengizinkan publikasi, pengujian sintetis, cleanup dan pemasangan APK normal. Bukti terbaru berada di `qa/finance/`.

## Cakupan

- Dashboard saldo tercatat seumur pencatatan; pemasukan/pengeluaran untuk bulan terpilih. Saldo tidak mengambil data bank/dompet yang belum dicatat dan dapat negatif.
- Satu form untuk pemasukan, pengeluaran dan edit: nominal rupiah bulat, kategori sesuai jenis, tanggal paling lambat hari ini dalam WIB, dan catatan opsional. Form mempertahankan isian ketika validasi/simpan gagal dan mengonfirmasi sebelum membuang perubahan.
- Detail, edit dengan ID tetap, hapus dengan konfirmasi Batalkan/Hapus transaksi. Penghapusan dari aplikasi bersifat soft delete, mengoreksi angka laporan dan tidak membuka hard delete.
- Anggaran total bulanan dengan empat batas kategori opsional. Jumlah batas kategori tidak melebihi total. Batas kosong berbeda dari Rp0; kosongkan total dan seluruh kategori untuk melepas anggaran. Anggaran tidak menambah/mengurangi saldo.
- Riwayat periode terpilih, pencarian catatan/kategori, filter jenis/kategori; tampilkan 20 item lalu Tampilkan lagi. Laporan arus kas periode, kategori dan porsi pengeluaran. Progress anggaran maksimal 100%, tetapi nilai kelebihan tetap ditulis.
- Beranda menggabungkan ringkasan agenda dan uang dengan bobot kartu yang sama. Label uang tidak menyatakan bulan berjalan jika pengguna memilih bulan lain.

Kategori pengeluaran mengikuti model domain: makan, transport, kebutuhan kos, lainnya. Pemasukan: uang saku, kerja, pemasukan lain. Rencana belanja tidak dicatat sebagai transaksi aktual. Tidak menambahkan bank, utang, SQLite, PDF, atau fitur AI/notifikasi baru pada tahap ini.

## Data dan konsistensi

Model dan repository konkret di `lib/data/finance.dart` serta `finance_repository.dart`, memakai dependency Firestore yang sudah tersedia. Tidak menambah paket atau lapisan abstraksi produksi.

Sebelum transaksi, repository memerlukan satu pembacaan core dari server (Source.server) untuk memastikan jalur online tersedia. Satu transaksi Firestore kemudian membaca receipt, core, target dan ringkasan bulan terdampak sebelum menulis. Ia menyimpan catatan, satu/dua ringkasan bulan, core dan receipt secara atomik. Edit/hapus membalik kontribusi lama dahulu: jenis, nominal, kategori dan bulan dapat berubah tanpa meninggalkan total di bulan lama. Anggaran menulis bulan/core/receipt dengan total uang tetap. Perubahan keuangan menaikkan financeRevision; agendaRevision dipertahankan. Agenda lama tetap mempertahankan angka keuangan saat menyimpan.

ID entitas dan ID operasi stabil selama retry isian yang sama. Receipt append-only menyimpan identitas permintaan dan versi. Isian berbeda tidak boleh memakai receipt lama; versi entitas/anggaran yang sudah berubah ditolak. Tombstone tidak dapat diedit atau dipulihkan pada slice ini. Konfirmasi pengguna adalah perilaku aplikasi; Rules tidak diklaim membuktikan sentuhan tombol.

Pada perebutan inisialisasi core/bulan yang sama, server dapat menolak satu permintaan sebelum SDK mengulangnya. Tidak ada partial commit: pengguna mempertahankan isian dan dapat retry dengan ID yang sama. Uji serentak memverifikasi bahwa retry merekonsiliasi tepat dua transaksi tanpa saldo hilang/dobel. Tidak mengulang panggilan model atau menyembunyikan kegagalan tulis.

Refresh setelah commit dibedakan dari keberhasilan tulis. Jika commit sudah dikonfirmasi tetapi query ringkasan gagal, UI menyatakan “Tersimpan. Ringkasan belum termuat” dan meminta muat ulang; tidak menawarkan membuat transaksi baru. Angka lama disembunyikan selama loading/error. Pergantian UID membuang snapshot dan hasil async lama, serta menutup form akun lama melalui lifecycle MainShell yang sudah ada.

## Rules dan keamanan

`config/firebase/firestore.finance.rules` adalah Rules gabungan agenda + keuangan manual yang sudah dipublikasikan pada mobile-app-3479f pukul 22.02 WIB. Isi editor dibandingkan dengan file lokal sebelum Publish. `firebase.json` kini menunjuk file aktif tersebut; `firebase.finance.json` tetap dapat dipakai untuk pengujian emulator. Snapshot Rules agenda sebelumnya dan kandidat batch lama dipertahankan sebagai riwayat, bukan target deployment terbaru.

Rules memeriksa UID, skema/tipe/enum, integer Rp1–1 miliar, tanggal kalender nyata dan batas hari WIB, metadata immutable, kenaikan versi/revisi, receipt dan keterkaitan semua dokumen. Core, jumlah periode dan setiap total kategori harus cocok dengan selisih transaksi lama/baru. Perubahan transaksi harus menyertakan kedua ringkasan saat pindah bulan; anggaran tidak boleh mengubah pemasukan/pengeluaran. Path AI, pengingat, perangkat, usage dan lainnya tetap default deny. Service account tidak diubah; tidak ada role baru atau billing diaktifkan.

Percobaan awal melebihi batas 1000 ekspresi evaluasi Rules. Perhitungan kontribusi berulang diganti menjadi map kontribusi lama/baru yang dihitung sekali; pemeriksaan yang sudah diwajibkan pada dokumen tujuan tidak diduplikasi. Uji positif dan adversarial, termasuk commit lintas bulan, diulang setelah perbaikan. Fungsi tidak terpakai dihapus. Tidak melepas pemeriksaan rumus untuk mengejar kelulusan.

Acuan teknis: [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [Rules Timestamp](https://firebase.google.com/docs/reference/rules/rules.Timestamp), [Rules String](https://firebase.google.com/docs/reference/rules/rules.String). Angka dan state keberhasilan mengacu pada hasil uji proyek, bukan hanya dokumentasi.

## Offline, periode dan batas

Uji Android awal (`qa/finance/offline-before-fix.log`) menemukan disableNetwork SDK tidak menolak runTransaction saja pada lingkungan uji ini: operasi langsung berhasil. Repository ditambah preflight Source.server agar mematikan jaringan SDK juga menghentikan jalur tulis sebelum callback transaksi. Suite Android tetap memeriksa dokumen ID baru tidak tercipta setelah jaringan diaktifkan kembali. Ini bukan bukti pengujian airplane mode fisik; pengujian jaringan nyata masih terpisah.

Seperti agenda, memakai memory cache SDK tanpa persistence disk. Pembacaan server, commit online; tidak ada antrean tulis otomatis. Pemulihan form setelah process kill dan CRUD offline penuh belum dibuat. SQLite tidak ditambahkan.

Query bulan menggunakan equality monthKey dan halaman 100 dokumen dengan cursor; seluruh halaman dibaca sebelum pencarian/laporan dianggap lengkap. Batas tahap ini 1000 dokumen per bulan termasuk tombstone; lebih dari itu ditolak secara eksplisit, bukan dipotong diam-diam. UI menampilkan 20 item per langkah dari hasil yang sudah lengkap. Jumlah pemasukan/pengeluaran/kategori dihitung ulang dari ledger bulan lalu dibandingkan dengan ringkasan; ketidaksesuaian tidak ditampilkan sebagai angka sah. Tidak mengklaim rekonsiliasi semua bulan seumur pencatatan pada setiap baca.

Tanggal transaksi tetap tanggal lokal YYYY-MM-DD dalam WIB; tidak ikut bergeser karena zona perangkat. Periode anggaran 2000–2100. Laporan menghitung seluruh bulan terpilih, bukan mengklaim 14 hari contoh desain. UI tidak realtime lintas perangkat; muat ulang periode untuk angka terbaru.

## Desain dan aset

Konteks/screenshot Figma dibaca melalui skill figma-design-to-code: dashboard 144:11489, anggaran 144:11753, form 144:11905, detail 144:12391, riwayat 144:12702, laporan 144:13661 dan empty 144:13866 pada file FE73TkpfpJrSuEX97IdrTX. Tidak mengedit kanvas atau PDF.

Flutter memakai Manrope, token Ruma dan komponen RumaCard/Button/Icon yang ada. Navbar bersama dan status bar native tidak digambar ulang. Aset lokal dipakai dengan BoxFit.contain: wallet, message-circle, settings-2, circle-alert, search, utensils, bus-front, house, chevron dan ilustrasi wallet. Pilihan sebelumnya dipertahankan: satu form bersama, opsi tambahan dilipat; akses Asisten baru menuju tab yang tersedia, belum mengklaim autofill AI berfungsi. Statistik contoh Figma diganti data nyata. Filter ditempatkan pada riwayat yang sama untuk mengurangi perpindahan halaman.

## Verifikasi dan status

- `qa/finance/flutter-tests.log`: 17 pengujian unit/widget lama + baru lulus, meliputi parsing rupiah, tanggal, anggaran kosong/nol, overspending, lifecycle UID, retry, refresh setelah commit gagal, viewport 320×640 dan text scale 200%.
- `qa/finance/rules-results.json`: 16 skenario keuangan lokal lulus; validasi, rekening per UID, edit lintas bulan/jenis/kategori, saldo negatif, retry, soft delete, anggaran, pemalsuan agregat, commit tanpa bulan/receipt, serta konkurensi.
- `qa/finance/agenda-regression.json`: 12 skenario Rules agenda lulus dengan kandidat gabungan. Flag eksplisit RUMA_FINANCE_RULES=1 pada suite lama mengarahkan file dan output regresi terpisah; bukti lama tidak ditimpa.
- `qa/finance/device-results.json` dan `device-test.log`: suite SDK Android + UI di HP fisik Android 36 lulus pada emulator demo-ruma. Tambah pemasukan/pengeluaran, edit ID tetap, batal/hapus, anggaran tidak mengubah saldo, perpindahan bulan/jenis, retry, versi usang, offline tidak mengantre, interoperabilitas agenda dan isolasi akun lulus. Dua entri “+2” pada log mencakup tearDownAll; ini satu suite integrasi, bukan dua suite.
- Enam screenshot 01–06 tersimpan; dashboard, form, detail, laporan dan Beranda diperiksa visual. Ikon dan ilustrasi mengikuti slot/aset lokal; `assets-check.json` mencatat file nonkosong dan geometry. Laporan nol setelah penghapusan diuji tanpa pembagian nol; dashboard sebelumnya menunjukkan progress nonnol.
- `qa/finance/analyze.log`: analisis akhir tanpa temuan. `build-preview.log`: build profile ARM64 lib/main.dart dengan Firebase produksi berhasil, sekitar 40.5 MB. `output/apk/ruma-finance-preview.apk` adalah kandidat normal, bukan harness; sudah dipasang melalui USB menggantikan harness pengujian sesudah Rules aktif dan uji produksi lulus. Hash dan pemeriksaan exact-value dua secret server tidak menemukan kecocokan/file privat: `apk-inspection.json`. Ini bukan audit keamanan menyeluruh atau signing release final.
- `qa/finance/deployment.json`: isi editor dibandingkan dengan file lokal dan cocok; Rules dipublikasikan pukul 22.02 WIB. Bukti `rules-published.jpg` dan SHA-256 tersedia. Tidak mengubah IAM, billing, Worker atau kuota AI.
- `qa/finance/cloud-results.json` serta `cloud-device-test.log`: uji produksi SDK Flutter Android lulus untuk tambah/baca/perhitungan, retry tanpa duplikasi, anggaran tidak mengubah saldo, edit lintas bulan/kategori, soft delete dan penolakan tanpa sesi/akun lain. Tidak mengklaim uji ini menggantikan seluruh UI; alur UI diuji dengan SDK yang sama di emulator.
- Percobaan produksi pertama (`cloud-first-failed.log`) menolak set anggaran karena skrip belum memberikan versi bulan yang sudah ada. Guard versi repository bekerja; skrip diperbaiki untuk memakai month.version, tanpa mengubah aturan/app. Fixture percobaan itu dibersihkan: satu akun Auth melalui finally SDK dan enam dokumen exact UID; bukti `cloud-first-failed.json` serta `cloud-first-failed-cleanup.json`.
- Percobaan produksi final membuat dua akun sintetis; keduanya dihapus melalui SDK. `cloud-cleanup.json` mengonfirmasi sepuluh dokumen fixture final dibersihkan dan subkoleksi transactions/months/state/operations pada kedua UID kosong. Total tahap ini tiga akun dan 16 dokumen unik dibersihkan. Tidak memindai/menghapus akun lain, data agenda, usage atau fixture historis yang belum terkonfirmasi pada laporan fondasi.
- `launch-preview.log`: cold launch APK normal Status ok; foreground id.ruma.app diverifikasi. Bukti pemasangan dan launch disimpan sebagai log; tidak menambahkan screenshot saat pengguna mulai mengisi form akun di HP. Emulator demo/data lokal dibersihkan dan dihentikan; reverse 9096/8086 dilepas.

## Menjalankan ulang

Gunakan JDK17 dari `.local/android.env` untuk Flutter. Emulator Firebase memerlukan JDK27, project `demo-ruma`, config `firebase.finance.json`, Auth 9096 dan Firestore 8086 pada loopback. Suite Node menolak host non-loopback.

```bash
flutter analyze
flutter test
FIRESTORE_EMULATOR_HOST=127.0.0.1:8086 node --test backend/tests/finance.rules.test.mjs
RUMA_FINANCE_RULES=1 FIRESTORE_EMULATOR_HOST=127.0.0.1:8086 node --test backend/tests/agenda.rules.test.mjs
flutter drive --driver=test_driver/finance_test.dart --target=integration_test/finance_flow_test.dart -d DEVICE_ID --dart-define=AUTH_EMULATOR=true
```

Suite Android menolak mode produksi. Gunakan ADB reverse 9096/8086 dan jangan menyerahkan APK integration test sebagai APK normal. Permission instalasi pada HP tetap diselesaikan pengguna. APK normal sudah dipasang sesudah uji. Untuk HP ini, koneksi ADB libusb pada port 5038 dipakai karena backend native tidak mendeteksi USB: prefix `ADB_SERVER_SOCKET=tcp:localhost:5038` pada Flutter dan `adb -P 5038` pada perintah ADB; server dapat disiapkan dengan `ADB_LIBUSB=1 adb -P 5038 start-server`. Port reverse 9096/8086 tidak diperlukan untuk Firebase produksi.

## Berikutnya

Tahap berikutnya adalah menghubungkan agent Flutter ke repository agenda/keuangan yang sama: percakapan, klarifikasi singkat, draf yang bisa ditinjau/edit dan persetujuan sebelum commit. Setelah itu notifikasi serta dukungan agenda lanjutan sesuai scope. Optimasi CPU proxy tetap ditunda; tidak ada panggilan model dalam tahap keuangan manual ini.

## Guard uji produksi dan cleanup

`integration_test/finance_cloud_test.dart` memerlukan `FINANCE_LIVE_TESTS=true` dan `AUTH_EMULATOR=false`; driver menulis hasil termasuk ketika gagal agar fixture dapat ditelusuri. `finally` hanya menghapus akun yang UID-nya tercatat sebagai fixture suite ini, tidak menghapus akun yang sudah ada sebelum tes. UID marker tidak memuat token atau password.

Cleanup memakai service account Datastore User yang sudah diizinkan. Skrip hanya menerima nama manifest yang diizinkan, project mobile-app-3479f, suite finance_cloud_test, satu/dua UID dengan format yang sah dan sudah terdaftar sebagai dihapus dari Auth, serta koleksi transactions/months/state/operations. Batas dokumen dan prefix path diperiksa; tidak memindai users secara global. Jalankan hanya dalam cakupan izin pengujian produksi, dengan flag eksplisit RUMA_CLEAN_FINANCE_FIXTURES=mobile-app-3479f. Manifest percobaan gagal pertama direkonstruksi dari marker UID dan finally SDK yang selesai tanpa error; semua path dokumennya diverifikasi kosong.
