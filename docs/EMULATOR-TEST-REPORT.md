# Ruma - hasil uji emulator dan laporan per frame

20 Oktober 2026. Pengguna meminta aplikasi diuji pada VM yang sudah dipasang dan hasil per frame disusun dalam satu PDF.

## Hasil

- Android Emulator Pixel 5 / API 35 berhasil boot dengan KVM, 2 GB RAM dan 2 core.
- Suite utama akhir **lulus**, mencapture **27 keadaan layar/dialog**. Pemeriksaan UI: **21 LULUS, 5 CATATAN, 1 PERLU REVISI**. Definisi status ada pada halaman pertama PDF; ini bukan klaim seluruh fungsi produk selesai.
- Pengujian keyboard khusus **lulus** setelah penyesuaian alat uji dan konfigurasi AVD. Keyboard nyata teramati melalui inset platform, navbar hilang, dan input tetap terlihat.
- Analyzer akhir bersih. 27 unit/widget tests dari tahap copy sebelumnya tetap menjadi bukti terpisah; angka 27 screenshot bukan jumlah unit test baru.
- APK normal debug x86_64 dipasang Success dan cold launch Status ok. Tidak meninggalkan integration harness sebagai aplikasi yang dipakai pengguna.
- Fixture Auth dan Firestore lokal `demo-ruma` dibersihkan (HTTP 200). Reverse port dilepas, Firebase emulator dihentikan, pengaturan layar dikembalikan ke nilai awal 1. Android AVD tetap terbuka. **0 panggilan model dan 0 penulisan produksi.**

## Temuan yang belum diperbaiki

1. **Layar 07 / form kuliah:** tombol “Simpan tanpa waktu” bertentangan dengan label tanggal/jam yang wajib. Rekomendasi: “Simpan jadwal”. Kondisi label berada pada `lib/features/agenda/agenda_form.dart`; validasi data tetap melarang kuliah tanpa waktu. Kode aplikasi tidak diubah pada sesi pengujian ini.
2. Beranda masih berupa ringkasan sederhana dengan ruang kosong cukup besar, belum setara kepadatan informasi Figma.
3. Tujuh hari kalender tidak seluruhnya terlihat bersamaan; strip hari dapat digulir horizontal.
4. Profil belum memiliki seluruh studi/bio/avatar/preferensi rancangan. Draf AI belum memilih jam kosong otomatis dan belum membaca/edit/hapus catatan lama.
5. Saat keyboard Asisten pertama muncul, tombol Kirim belum terlihat utuh pada viewport awal. Laporan mencatat perlunya menggulir; tidak mengklaim submit pesan telah diuji.

## Percobaan awal dan koreksi alat uji

Percobaan pertama berhenti karena pemeriksaan navbar dilakukan sebelum pembaruan inset keyboard diproses. Log dan screenshot awal disimpan di `qa/ui-copy-device/attempt-1`. Harness kini menunggu **inset native > 0**, lalu membangun ulang frame sebelum memeriksa navbar. Assertion tidak dihapus atau dilonggarkan. Suite akhir lulus.

Pemeriksaan screenshot menemukan tutorial stylus Gboard menutupi layar keyboard. Pengaturan handwriting dimatikan pada **AVD milik proyek** saja, kemudian `integration_test/ui_keyboard_test.dart` dijalankan khusus. Screenshot 22 akhir berasal dari uji khusus yang lulus (`keyboard-results.json`), sementara 26 gambar lain berasal dari suite utama (`device-results.json`).

Fixture draf “Besok” juga diperbaiki menjadi tanggal hari berikutnya. Ini hanya data uji, bukan perubahan interpretasi tanggal agent. Draf disisipkan secara sintetis agar pengujian UI tidak memanggil provider.

## Cakupan dan batas

Mengunjungi seluruh layar yang diimplementasikan, membuka dialog profil/privasi/informasi, memilih tanggal menuju pemilih jam, membatalkan pemilih jam, membuka keyboard nyata dan teks 130%, serta menyimpan satu agenda + satu transaksi secara atomik pada backend lokal. Form panjang dan daftar tetap scrollable; screenshot adalah viewport, bukan satu gambar seluruh konten panjang.

Tidak mengulang seluruh submit form manual, login/daftar email, edit/hapus catatan, deduplikasi receipt, pengingat/push, uji performa, atau panggilan model nyata. Beberapa route dibuka langsung oleh harness; keterbatasan tiap layar dijelaskan di PDF. Pengujian 27 keadaan ini bukan pengujian seluruh 71 frame/state rancangan Figma.

## Artefak

- PDF terbaru: `output/pdf/ruma-report-per-frame.pdf` - **10 halaman A4 mendatar**, 27 screenshot native, nomor/nama layar, status, hal yang diperiksa dan catatan per layar.
- Data laporan: `qa/ui-copy-device/frame-report.json`.
- Hasil utama: `device-results.json`, `device-test.log` pada folder yang sama.
- Uji keyboard: `keyboard-results.json`, `keyboard-recheck.log`.
- PDF dibuat oleh `scripts/build-emulator-report.py`; sumber gambar unik/hash dan pemeriksaan label tersimpan di `pdf-verification.json`.
- Semua 10 halaman dirender Poppler dan diperiksa, termasuk detail halaman ringkasan, temuan form kuliah dan keyboard. Tidak ada teks terpotong atau screenshot diregangkan pada hasil akhir.
- PDF `ruma-review-antarmuka.pdf` sebelumnya tetap arsip 19 Oktober. Gunakan laporan baru untuk menilai revisi teks/kartu terbaru.

Pengingat USB satu kali sudah disampaikan sebelumnya. Otomasinya dijeda agar tidak mengirim ulang setelah pengujian dapat diselesaikan di emulator.
