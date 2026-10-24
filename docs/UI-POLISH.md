# Ruma — perapian seluruh halaman Flutter

19 Oktober 2026. Ruang lingkup: merapikan halaman yang sudah diimplementasikan, mempertahankan identitas Ruma, navigasi, isi, dan alur penyimpanan. Tidak menambah fitur atau mengubah Figma/PDF, Rules, proxy, maupun database produksi.

## Cakupan halaman

| Kelompok | Halaman/keadaan yang diperiksa |
|---|---|
| Awal dan akun | Sambutan, masuk, daftar |
| Navigasi utama | Beranda, Agenda, Asisten, Keuangan, Profil |
| Agenda | Form tugas/kegiatan, form kuliah, detail agenda |
| Keuangan | Form pengeluaran, pemasukan, anggaran, riwayat, laporan, detail transaksi |
| Draf AI | Tinjauan gabungan dan hasil tersimpan |

Total 19 halaman/keadaan utama. Dialog ubah nama, batal, hapus, persetujuan AI, informasi akun dan privasi memakai pola yang sama; date/time picker tetap komponen Android/Material.

## Yang dirapikan

- Tingkat judul: label app bar halaman utama disamakan dengan halaman detail; judul utama tetap menonjol. Font Manrope dan warna oranye/sage/peach dipertahankan.
- `RumaPageBody` menyatukan batas lebar 600 dp, margin 24 dp, jarak atas 16 dp, scroll dan dismiss keyboard. Form akun, agenda, keuangan, detail dan laporan memakai wadah ini.
- Form masuk/daftar tidak lagi menyisakan footer tombol yang mendesak isi ketika keyboard terbuka. Seluruh isian, pesan validasi dan tindakan dapat digulir bersama.
- Navbar lima ikon tetap memakai urutan dan maskot sebelumnya. Saat keyboard terbuka, navbar disembunyikan sementara untuk memberi ruang pada isian dan kembali setelah keyboard ditutup.
- Kartu memakai radius umum 20 dp dan memotong efek tap sesuai sudutnya. Padding, judul/subjudul list, expansion, ikon kembali dan ikon perpindahan periode diseragamkan melalui tema/komponen bersama.
- `RumaActionPair` mengubah pasangan tombol menjadi susunan vertikal pada lebar sempit atau teks besar; dipakai pada Asisten, draf dan aksi keuangan. Label loading bisa membungkus tanpa terpotong.
- Ringkasan pemasukan/pengeluaran menyelaraskan tinggi label dan beralih ke susunan vertikal saat nominal atau ukuran teks membutuhkan ruang. Nominal tidak diperkecil untuk menyembunyikan masalah layout.
- Kalender mingguan dan kolom waktu mengikuti ukuran font; semua ikon tetap memiliki rasio 1:1.
- Ilustrasi sambutan memakai susunan mengalir pada layar kecil/teks besar agar contoh jadwal dan uang tidak bertumpuk.
- `RumaDialog` mempertahankan tampilan Material, tetapi menggulirkan seluruh isi **beserta tombolnya** ketika keyboard menyisakan ruang sempit. Tombol Batal/Simpan ubah nama kini memiliki latar yang konsisten.

Tidak mengubah repository, nominal, tanggal, algoritma jadwal, autentikasi, kuota AI, atau cara commit. API key tetap di backend.

## Bukti dan pengujian

- Analyzer bersih: `qa/ui-polish/analyze.log`.
- **27 uji Flutter lulus**: `qa/ui-polish/tests.log`.
- Matriks layout mencakup 19 halaman/keadaan pada 390×844, 320×640 dengan teks 200%, serta 844×390 mendatar. Isian akun dan dialog profil juga diperiksa dengan inset keyboard 220 dp; navbar diperiksa saat IME muncul/hilang. Ini uji layout widget, bukan klaim uji native HP.
- Uji tambahan menemukan overflow dialog ubah nama 14 px ketika mendatar + keyboard. Bukti sebelum perbaikan: `qa/ui-polish/dialog-before-fix.log`. Pola dialog bersama diperbaiki dan matriks akhir lulus. Perubahan tes lama hanya menambahkan scroll sebelum mengetuk tombol akun yang kini berada dalam konten.
- Pemindaian mekanis satu kali mengembalikan `[]`: `qa/ui-polish/detector.json`. Pemindai terutama ditujukan untuk web; hasil ini tidak menggantikan pemeriksaan Flutter/native.
- Acuan visual awal diperiksa dari screenshot native tahap Auth, Agenda, Keuangan dan Asisten sebelumnya. Font, aset, warna dan ukuran ikon tetap mengikuti implementasi tersebut. Tidak membuat ilustrasi baru atau mengganti desain brand.

## APK dan verifikasi perangkat

APK normal profile ARM64 berhasil dibangun (40.8 MB) sebagai `output/apk/ruma-ui-preview.apk` (target `lib/main.dart`). Detail hash dan pemeriksaan secret dicatat pada `qa/ui-polish/apk-inspection.json` dari build akhir (`build-final.log`); pemindaian exact API key/private key UTF-8/UTF-16 menemukan 0 kecocokan/file privat. Pemeriksaan kontras pasangan warna utama lulus 4,53:1 atau lebih (`contrast.json`).

HP Android 24117RN76O terhubung melalui USB. Suite native lokal **lulus**: 26 screenshot unik pada semua halaman/keadaan di atas, termasuk dialog nama/privasi, date/time picker, keyboard nyata, teks 130%, serta bagian bawah tinjauan draf. Screenshot diperiksa dalam satu batch dan bagian Beranda/hasil draf dikonfirmasi setelah koreksi waktu pengambilan. Tidak ditemukan overflow baru yang membutuhkan perubahan kode aplikasi. Bukti: `qa/ui-polish/device-results.json` dan `device-test.log`.

Pengambilan pertama lulus secara fungsi tetapi callback Android baru berjalan setelah test, sehingga gambar berulang. Gambar tersebut **tidak dipakai** sebagai bukti visual/PDF. Harness diperbaiki: tiap keadaan meminta capture melalui HTTP loopback lokal port 8766 yang diteruskan ADB, lalu host memeriksa Ruma berada di foreground sebelum `adb exec-out screencap`. Tidak memotret aplikasi lain. Beranda menunggu pembacaan selesai dan hasil draf dikembalikan ke posisi atas sebelum diambil. Ini perubahan alat uji saja; tidak masuk APK normal.

APK normal `lib/main.dart` dipasang dengan hasil **Success**, cold launch **Status: ok**, dan foreground `id.ruma.app` terkonfirmasi (`normal-install.log`). Pengaturan layar dikembalikan ke nilai awal **0**. Fixture Auth/Firestore project lokal `demo-ruma` dihapus (HTTP 200), reverse port dilepas, dan emulator dihentikan. **0 panggilan model, 0 penulisan produksi, tanpa perubahan Rules/proxy/IAM.**

## PDF untuk permintaan revisi

Pengguna meminta screenshot dalam PDF. Hasil: `output/pdf/ruma-review-antarmuka.pdf`, **9 halaman A4 mendatar berisi 26 screenshot native**. Nomor dan nama layar ditulis di atas gambar serta tersedia bookmark PDF; layar 26 adalah bagian bawah layar 20. Maksimal tiga layar per lembar, gambar mempertahankan rasio asli, tanpa footer Figma/prototype. Semua gambar memakai data sintetis; PDF menampilkan viewport, bukan klaim seluruh isi scroll dalam satu gambar.

Dibuat lewat `scripts/build-ui-review-pdf.py`; label/26 sumber unik diperiksa, semua halaman dirender Poppler dan susunan diperiksa, termasuk detail halaman 8 dan 9. Bukti `qa/ui-polish/pdf-verification.json`. Untuk revisi, sebutkan nomor layar dan elemen, misalnya “layar 09, kartu saldo terlalu besar”.
