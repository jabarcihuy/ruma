# Halaman Tabungan — Ruma

21 Oktober 2026. Implementasi UI tabungan dan integrasi ringkasan setelah fondasi data. Kandidat diuji dengan Firebase Emulator. Pembaruan 22 Oktober: Rules tabungan telah dipublikasikan; hasil verifikasi produksi dicatat pada bagian akhir.

## Yang berubah

- Keuangan mengganti kartu dan akses anggaran dengan saldo tercatat, uang tersedia, total tabungan serta pintasan Tabungan. Laporan dan riwayat kini dapat dibuka langsung. Pilihan bulan tetap tersedia.
- Daftar tujuan menampilkan total alokasi, uang tersedia, progres tiap tujuan dan tombol tambah. Tujuan aktif ditampilkan sebelum tujuan tercapai, lalu diurutkan nama agar urutannya tidak bergantung pada ID acak Firestore.
- Detail tujuan menampilkan target/tanggal opsional, progres, Setor/Tarik, edit tujuan dan riwayat. Penarikan dinonaktifkan jika saldo tujuan nol. Riwayat ditampilkan 20 catatan per langkah.
- Form tujuan mendukung buat/edit nama, target rupiah dan tanggal opsional yang dapat dikosongkan. Tujuan baru selalu Rp0; edit target tidak mengubah dana.
- Form bersama setor/tarik mempertahankan nominal/catatan, tanggal aktual dalam WIB dan informasi sumber dana. Nominal divalidasi rupiah bulat; pembatasan dana dan versi tetap diperiksa oleh repository dan Rules.
- Beranda mengganti sisa anggaran dengan total tabungan serta uang tersedia. Agenda dan akses Asisten tetap ada. Angka tabungan hanya digabung dengan snapshot keuangan yang revisinya cocok.
- Navbar yang sama dipakai pada daftar/detail, mempertahankan lima tujuan serta maskot 32 px pada lingkaran 48 px. Memilih menu menutup route tabungan dan kembali ke tujuan utama; form menyembunyikan navbar.
- UI anggaran tidak lagi ditampilkan pada dashboard/laporan aktif. Field/model, repository dan data anggaran lama tetap dipertahankan untuk kompatibilitas dan belum dimigrasi menjadi saldo tabungan.

Tanggal, nama, nominal, jumlah tujuan dan isi riwayat berasal dari akun aktif, bukan angka contoh Figma. Tanggal target menggunakan picker native; status bar memakai sistem Android.

## Sumber desain dan aset

Figma FE73TkpfpJrSuEX97IdrTX: daftar `422:5127`, detail `422:5228`, form tujuan `144:11753`, perpindahan `422:5348`, Keuangan `144:11489`. Context resolusi lengkap beserta screenshot dibaca melalui figma-design-to-code sebelum implementasi. Manrope, warna oranye/sage/cream, kartu radius 24, gap 12, field/tombol 48 px dan tata letak adaptif mengikuti komponen Ruma yang ada.

Ikon arrow-left, wallet, shield-check, calendar-days, chevron-right dan book-open memakai SVG lokal yang cocok dengan komponen Figma. Navbar memakai nav-circle.svg dan nav-face.svg yang sudah ada. Tidak memasang paket ikon/grafik, mengubah path SVG atau memakai screenshot sebagai UI. Tombol hapus tanggal memakai kontrol sistem dengan tooltip. Pemeriksaan file/slot/geometri: `qa/savings-ui/assets-check.json`.

Perbedaan yang disengaja: layar kosong, error, loading, catatan panjang, tanggal aktual dan validasi ditambahkan agar rancangan dapat dipakai; teks/urutan mengikuti data nyata. CTA yang menjanjikan draf AI tabungan belum ditampilkan di halaman tabungan karena tools agent-nya merupakan tahap terpisah. Asisten untuk fitur yang sudah ada tetap tersedia lewat navbar. Diagram lingkaran belum dikerjakan pada tahap ini; laporan kategori lama tetap berfungsi tanpa anggaran.

## Konsistensi state dan form

`SavingsStore` menggunakan generation token untuk mengabaikan hasil baca lama dan hasil setelah dispose. Snapshot dibersihkan saat loading/error; tidak menampilkan Rp0 sebagai pengganti kegagalan memuat saldo. Perubahan keuangan manual atau Asisten memicu pemuatan tabungan kembali; perubahan tabungan memuat ulang FinanceStore. Perbedaan revisi yang ditemukan saat membuka tabungan memicu penyegaran ledger, sehingga ringkasan tidak menggabungkan dua versi data.

Store terikat lifecycle akun MainShell. Saat UID berganti, route lama ditutup, store dibuang dan repository menolak sesi lama. Selama simpan, kontrol dan navigasi kembali form dikunci. Isian gagal tidak dibuang. Mutasi dengan isi sama menggunakan ID operasi yang sama untuk retry; perubahan isi menghasilkan ID baru dengan ID tujuan serta versi awal tetap. Versi usang harus dimuat ulang dari daftar/detail sebelum membuka form lagi; tidak menimpa diam-diam.

Simpan yang sudah dikonfirmasi tetap berhasil meskipun refresh gagal. Snapshot lama disembunyikan dan pengguna mendapat pesan tersimpan + muat ulang; tidak mengarahkan pembuatan setoran baru untuk mengatasi refresh. Konfirmasi membuang isian dipakai untuk back dan Batalkan. SnackBar halaman sebelumnya dihapus ketika membuka form, setelah uji VM menemukan pesan sukses dapat menutupi tombol Batalkan.

## Verifikasi dan bukti

- Analyzer dan seluruh tes Flutter dicatat di `qa/savings-ui/analyze.log` serta `flutter-tests.log`.
- Tes baru mencakup hasil baca usang, disposal, double submit, commit sukses/refresh gagal, nominal invalid, retry ID tetap/berubah, pembatalan, empty/error/retry, teks 200%, keyboard dan lebar 320 px.
- Suite native `integration_test/savings_ui_test.dart` hanya dapat dijalankan dengan AUTH_EMULATOR=true. Ia membuat akun/data sintetis demo-ruma, memakai form dan repository nyata, serta menolak tap ke kontrol yang tertutup.
- Enam kelompok skenario Android: buat tujuan Rp0; penolakan dana tidak cukup dan perbaikan isian; edit tanpa mengubah alokasi; tujuan kedua mencapai 100%; Batalkan lalu lanjut edit dan penarikan; navigasi utama serta konsistensi Beranda/Keuangan dengan ledger tetap.
- Data uji: pemasukan Rp2.000.000 dan pengeluaran Rp1.180.000 (empat kategori). Dua tujuan menyimpan Rp300.000 dan Rp100.000; penarikan Rp50.000 membuat total tabungan Rp350.000, tersedia Rp470.000, saldo tercatat tetap Rp820.000. Lima transaksi asal tidak bertambah karena perpindahan tabungan.
- Screenshot PNG tiap layar diperiksa visual dan disimpan tanpa membuat PDF. Percobaan pertama serta diagnosis pesan sukses yang menutupi tombol diarsipkan di `qa/savings-ui/attempt-1/`; bukti akhir berada di folder utama. Perbaikan ditambah pengujian regresi.
- Uji ulang Rules tabungan memakai kandidat yang sama dengan fondasi; rincian dan hash di verification.json. Tidak ada AI, FCM, billing, IAM atau penulisan produksi dalam pengujian ini.

Hasil akhir: analyzer bersih, 75 tes Flutter, 12 skenario Rules dan enam kelompok uji Android lulus. Sembilan PNG akhir diekspor dari render tree aktif setelah repaint layer SVG. Fixture Auth/Firestore demo-ruma dibersihkan dan reverse port dilepas; APK normal sebelumnya ruma-ai-output-guard.apk dipulihkan di VM sambil menunggu persetujuan produksi.

Status angka hasil akhir, hash APK/Rules dan cleanup ada di `qa/savings-ui/verification.json`. APK integration-test tidak dipakai sebagai APK normal.

## Status produksi dan berikutnya

22 Oktober 2026: `firebase.json` sekarang menunjuk `config/firebase/firestore.savings.rules`. Pengguna mengizinkan publikasi, maksimal dua akun sintetis, cleanup dan pemasangan APK normal di VM. Rules dipublikasikan melalui Firebase Console; seluruh isi editor dibandingkan dengan kandidat sebelum publikasi dan kembali setelah reload. Hash Rules tetap `338c3dba7a5a55f793ed8894851f44b0f30ba6abc486563e0e2b2ae58fe848f3`. Bukti: `qa/savings-ui/deployment.json` dan `rules-published.png`.

Uji produksi native Android (`integration_test/savings_cloud_test.dart`) memakai opt-in `SAVINGS_LIVE_TESTS=true` dan memverifikasi project mobile-app-3479f. Lima kelompok lulus: tujuan awal Rp0; setoran lintas tujuan/rekonsiliasi/progres 100%/retry idempoten; penolakan dana berlebih/penarikan berlebih/versi usang/ID operasi dengan isi berbeda; edit dan penarikan menjaga ledger serta data anggaran lama; isolasi lintas akun dan setelah keluar. Uji offline tetap mengacu bukti Emulator sebelumnya, tidak diulang pada produksi.

Dua akun sintetis dihapus oleh suite. Cleanup administratif dibatasi UID keluaran suite dan enam koleksi fixture yang diketahui; 21 dokumen dihapus dan seluruh koleksi fixture diverifikasi kosong. Tidak menyentuh akun/data pengguna lain. Hasil: `cloud-results.json`, `cloud-cleanup.json`, `cloud-test.log`; analyzer setelah penambahan suite bersih (`cloud-analyze.log`). Tidak ada panggilan model/FCM, perubahan IAM, indeks, Worker atau billing pada tahap ini.

APK normal `output/apk/ruma-savings-ui-candidate.apk` (debug x86_64, konfigurasi Firebase produksi) dipasang menggantikan harness di Ruma_API35. Cold launch berhasil, `Status: ok`, Activity id.ruma.app/.MainActivity, dan layar awal normal diperiksa pada `normal-apk-launched.png`. SHA APK tetap `d85bc7b9bea8986b9125b6c42a654e741a9d4b5ddce9781f173d07017d4154bf`. Ini APK pengujian VM, belum APK release bertanda tangan. VM dihentikan setelah verifikasi; APK tetap terpasang.

Berikutnya: diagram lingkaran pengeluaran, kemudian kemampuan agent tabungan. Belum menghapus kode/data anggaran lama. Pengujian produksi ini membuktikan repository dan Rules tabungan; UI telah diverifikasi dengan data sintetis Emulator sebelumnya, bukan uji UI produksi dengan akun pengguna nyata.

Penyempurnaan wishlist 22 Oktober (ikon, copy dan status) dicatat terpisah di WISHLIST-TABUNGAN.md. Kandidatnya belum dipublikasikan; status produksi pada bagian sebelumnya tetap berlaku.
