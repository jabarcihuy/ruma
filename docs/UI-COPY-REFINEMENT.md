# Ruma - teks ringkas dan kartu Asisten

19 Oktober 2026. Pengguna meminta kartu Asisten pada halaman 7 PDF dirapikan, kemudian menyetujui usulan pengurangan keterangan di seluruh halaman.

## Perubahan

| Bagian | Hasil |
|---|---|
| Kartu Asisten | Maskot 64x64 di kanan teks, padding 20, jarak 16; susunan vertikal pada lebar sempit atau teks besar. Tidak lagi ada area kosong tinggi di atas judul. |
| Isi kartu | “Waktu & uang, tertata.” dan “Ceritakan, lalu tinjau sebelum disimpan.” |
| Petunjuk Asisten | Tombol informasi berlabel aksesibel “Tentang Asisten” memuat batas 3 agenda + 3 transaksi aktual dan keterbatasan baca/edit/hapus catatan lama. Status kartu hanya muncul saat memproses. |
| Masuk/daftar | Subjudul promosi dihapus; syarat kata sandi menjadi “Minimal 6 karakter.”; label, validasi, privasi dan ketentuan tetap ada. |
| Beranda | Sapaan menjadi “Halo, [nama]!”; data ringkasan tetap sama. |
| Agenda/form/detail | Subjudul berulang dan keterangan tombol edit/hapus dihapus. WIB dekat label waktu. Konfirmasi kehilangan perubahan tetap ada, lebih pendek. |
| Keuangan/riwayat/laporan | Subjudul yang mengulang saldo/pemilih bulan dihapus. Form transaksi: “Untuk transaksi yang sudah terjadi.” |
| Anggaran | Helper opsional tidak diulang per field; satu petunjuk di akhir menjelaskan batas boleh kosong dan cara melepas anggaran. Validasi jumlah kategori terhadap total tetap aktif. |
| Profil | Subjudul umum dan penjelasan menu privasi yang berulang dihapus; risiko akun sementara dan logout dipertahankan. |
| Draf AI | Keterangan uang aktual yang berulang dihapus. Draf tanpa jam diberi satu petunjuk sebelum penyimpanan, hanya saat relevan. Kartu “Penyimpanan selesai” dihapus karena judul sudah “Sudah tersimpan”. Status commit tak pasti tetap terlihat. |

`RumaHeading` menerima subjudul null dan tidak menyisakan gap kosong. Tidak mengubah query, validasi, izin, model, nominal, metode commit, atau fitur roadmap.

## Verifikasi

- 27 uji Flutter lulus: `qa/ui-copy/tests.log`. Matriks halaman mencakup layar normal, sempit dengan teks 200%, mendatar, keyboard, serta akses dialog informasi Asisten.
- Analyzer bersih: `qa/ui-copy/analyze.log`.
- Render Flutter lokal dengan font Manrope dan MaterialIcons diperiksa: `qa/ui-copy/render-chat.png` dan `render-review.png`. Ini bukan screenshot native HP.
- APK normal profile ARM64: `output/apk/ruma-ui-ringkas-preview.apk`; hash/ukuran dan status di `qa/ui-copy/status.json`.
- 0 panggilan AI dan 0 penulisan produksi pada tahap ini. Tidak mengubah Figma.

## Penundaan awal dan pemeriksaan lanjutan

Pada 19 Oktober pengguna meminta menunda sambungan USB. Saat itu APK baru belum dipasang dan PDF belum diperbarui; `output/pdf/ruma-review-antarmuka.pdf` tetap bukti screenshot versi sebelumnya. Jangan menganggap 26 capture native tahap sebelumnya sebagai pengujian revisi ini.

Setelah HP tersedia atau pengguna mengizinkan penyiapan Android Emulator: jalankan suite `integration_test/ui_polish_test.dart` dengan data sintetis lokal, periksa screenshot baru, pasang APK normal, lalu buat ulang PDF dan catat hasilnya. APK emulator perlu dibangun untuk x86_64; kandidat di atas khusus ARM64 HP.

Pada 20 Oktober pengujian dilanjutkan di Android Emulator API35: 27 capture dan uji keyboard khusus lulus. APK normal x86_64 sudah dipasang di AVD, tanpa memasang ulang kandidat ARM64 di HP. PDF terbaru adalah `output/pdf/ruma-report-per-frame.pdf` (10 halaman), berisi status/catatan tiap layar termasuk satu temuan label tombol kuliah. Lihat [laporan lengkap](EMULATOR-TEST-REPORT.md).
