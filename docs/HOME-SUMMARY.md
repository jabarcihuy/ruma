# Ruma — Beranda: ringkasan waktu dan uang

21 Oktober 2026. **Selesai: 50 tes lokal, suite SDK/visual Android dan pemasangan APK normal di VM lulus.** Tidak mengubah Figma atau membuat PDF pada tahap ini.

## Yang berubah

- Dua kartu memakai pola visual yang sama: judul/ikon, ringkasan utama, dua rincian, lalu akses ke halaman terkait. Warna peach/sage menandai waktu/uang; font, navbar, tema dan aset yang sudah ada dipertahankan. Tidak membuat halaman baru.
- **Waktu hari ini:** jumlah kegiatan berstatus planned yang beririsan dengan hari ini menurut WIB dan jumlah planned yang belum dijadwalkan. Kegiatan terdekat memilih yang masih berlangsung terlebih dahulu atau jadwal mendatang. Sesi yang berakhir tepat saat ini sudah dikeluarkan dari daftar terdekat.
- **Deadline:** tugas planned dengan deadline paling awal, termasuk yang terlewat. Tugas completed/cancelled dikeluarkan. Label Terlewat membuat keterlambatan jelas; tugas tanpa jam tetap dapat menjadi deadline terdekat. Ringkasan menampilkan satu deadline prioritas, bukan seluruh daftar.
- Kegiatan/deadline bisa diketuk untuk membuka detail ID yang tepat. Lihat agenda/keuangan menuju tab terkait; akses Asisten tetap menonjol di bagian atas. Judul kegiatan panjang dibatasi dua baris pada ringkasan dan tersedia lengkap di detail.
- **Uang bulan ini:** saldo tercatat total dari state, pengeluaran bulan berjalan, serta sisa anggaran total bulan berjalan. Sumber sama dengan Keuangan; tidak menghitung uang bank/dompet yang belum dicatat. Anggaran null berarti Belum diatur, nol tetap nol, saldo negatif tetap tampil, dan kelebihan anggaran disebut Lewat anggaran beserta nominalnya.
- Beranda kembali memakai bulan berjalan ketika dibuka dari laporan bulan lain. Karena memakai FinanceStore yang sama, pilihan periode Keuangan ikut kembali ke bulan berjalan; tidak mempertahankan filter historis saat melewati Beranda. Data bulan lama tidak diberi label bulan ini selama pemuatan.
- Kembali ke Beranda memuat ulang agenda/keuangan. Selama Beranda terbuka, jam/tanggal diperbarui setiap menit dan pergantian bulan memuat periode baru. Resume memuat ulang sumber; timer dilepas saat keluar dari Beranda. Batas zona waktu implementasi tetap WIB.
- Loading/error tidak menampilkan angka lama, menampilkan pesan pendek dan tindakan muat ulang jika gagal. Keadaan data kosong menampilkan jumlah/nilai nol yang berasal dari snapshot sah; tidak memakai data contoh.

## Verifikasi lokal

- 50 tes Flutter lulus (43 regresi + 7 khusus Beranda), analyzer bersih. Bukti `qa/home-summary/flutter-tests-final.log` dan `analyzer-final.log`.
- Tes khusus mencakup prioritas berlangsung/terlewat, status selesai/batal, batas akhir interval, detail ID tepat, ganti bulan historis, angka database, null/nol/kelebihan anggaran/saldo negatif, loading/error/retry, pergantian bulan pada pukul 00.00 WIB, serta konten panjang pada 320 px/teks 200% dan mendatar.
- Matriks seluruh halaman yang sudah ada tetap lulus pada 390×844, 320×640/teks 200% dan 844×390. Assertion label navigasi lama Uang tercatat diperbarui menjadi Uang bulan ini sesuai revisi yang diminta; assertion tersebut diselaraskan sebelum kelulusan akhir.
- Pemindaian mekanis satu kali tidak menemukan pola yang ditandai (`detector.json`); ini tidak menggantikan bukti visual/native.

## Batas tahap

Tidak menambah preferensi/profil, pengulangan, snooze, SQLite, layanan backend atau izin database. Tidak memanggil provider AI atau FCM. Tidak membuat data uji produksi. APK target tahap ini debug x86_64 untuk VM; ARM64/perangkat fisik dan release final tetap terpisah. SDK memakai project lokal demo-ruma. Seluruh fixture Auth/Firestore dibersihkan HTTP 200; emulator Firebase dihentikan dan ADB reverse dilepas.


## Verifikasi Android dan hasil akhir

- AVD Ruma_API35, Android 15/API35, 1080×2340, x86_64. Suite native final lulus dalam 13 detik, tiga kelompok: angka ringkasan sama dengan repository SDK; deadline membuka ID detail yang tepat; kembali dari laporan historis memuat bulan berjalan dan nominal yang benar. Data uji: pemasukan Rp1.500.000, pengeluaran Rp18.000, saldo Rp1.482.000, anggaran Rp700.000 dan sisa Rp682.000. Bukti `qa/home-summary/device-results.json` dan `device-test.log`.
- Empat screenshot final mencakup data kosong, data terisi, bagian uang, dan kembali dari periode historis. Font sistem 130% juga diuji dalam run tersendiri (`font-130/`), sebelum koreksi akhir posisi label empty state; font kembali 1.0 dan run final default berhasil. Layout 320 px/teks 200% serta mendatar diuji pada widget, bukan klaim uji native pada semua perangkat.
- Percobaan native pertama berhenti setelah detail berhasil dibuka karena `pageBack()` mencari tombol bawaan. Ruma memakai tombol ber-tooltip Kembali; harness disesuaikan tanpa mengubah perilaku navigasi aplikasi. Bukti awal dipertahankan di `attempt-1/`. Pemeriksaan visual berikutnya menemukan label empty state tidak sejajar; kedua rincian kartu kini rata atas melalui opsi alignment RumaActionPair, dengan default komponen lain tetap sama. Regresi 50 tes dan native final lulus setelah koreksi.
- APK normal `lib/main.dart` sudah dipasang, cold launch Status ok, foreground Ruma/Welcome diperiksa. File `output/apk/ruma-home-summary.apk`, debug x86_64, **102.330.071 byte**, SHA256 `5984d42bdf535566749f3fb48948d8b853d315b130248302dfeda6929aa12fc2`. Scan exact secret server UTF-8/UTF-16 dan file privat menemukan 0. Bukti `apk-inspection.json`, `normal-install.log`, `normal-state.json`, `05-normal-installed.png`. Percobaan pm clear mengembalikan Failed karena paket sudah dilepas runner; pemasangan normal berikutnya Success dan tidak meninggalkan harness.
- Semua fixture lokal dari percobaan dibersihkan, Auth/Firestore HTTP 200, Firebase emulator dihentikan, reverse kosong, font kembali 1.0, pengaturan stay-on kembali 1 dan VM tetap terbuka. 0 penulisan produksi/panggilan AI/pengiriman FCM. Tidak memublikasikan Rules, Worker, indeks, IAM atau billing. CPU tetap ditunda. Bukti `local-cleanup.json` dan `normal-state.json`.

Metadata dan hash sumber akhir ada di `qa/home-summary/status.json`. APK HP ARM64/release dan PDF review sebelumnya belum diperbarui oleh tahap ini.
