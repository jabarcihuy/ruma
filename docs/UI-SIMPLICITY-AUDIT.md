# Audit kemudahan penggunaan dan keseimbangan UI

22 Oktober 2026 — implementasi Flutter Ruma. Audit ini meninjau halaman aktif melalui kode, pengujian widget, dan render lokal dengan font Manrope. Bukan audit ulang seluruh frame Figma, bukan bukti uji pengguna, dan bukan screenshot Android terbaru.

## Perubahan

- Judul halaman utama memakai skala 24/32 yang sama; judul sambutan tetap lebih besar. Margin halaman 24, jarak antarkartu 12–16, serta tombol yang membungkus di layar sempit dipertahankan.
- Hapus keterangan berulang di menu keuangan, edit tujuan, dan pembuka form tabungan. Sambutan cukup satu kalimat pengantar AI.
- Beranda menggunakan label tindakan “Buka Asisten AI”. Kartu waktu dan uang tetap memakai komponen ringkasan yang sama; tinggi mengikuti isi, tidak dipaksa sama sampai meninggalkan ruang kosong berlebihan.
- Pilihan cepat durasi 15/30/60 menit pada agenda dan preferensi memakai komponen bersama `RumaDurationChoices`. Durasi bebas tetap bisa diketik; pilihan chip mengikuti angka yang diketik. Kontrol nonaktif saat menyimpan.
- Preferensi memakai judul bagian “Jam saran AI (WIB)” di atas dua kontrol waktu. Hapus catatan di bawah yang mengulang fungsi bagian tersebut.
- Saran pesan Asisten menjadi satu grup Wrap agar tidak menyisakan baris buatan. Hapus keterangan durasi berulang di setiap item draf; angka durasi, penanda jam usulan, dan tombol Ubah tetap tersedia.
- Laporan hanya membuat kartu kategori yang memiliki pengeluaran. Kondisi kosong mendapat satu pesan. Persentase diringkas menjadi “% dari total”; angka dan indikator proporsi tetap ada.
- Ringkas petunjuk notifikasi menjadi “Atur pengingat lewat detail kegiatan.”

## Audit per halaman / kelompok keadaan

| Halaman | Hasil dan tindakan |
|---|---|
| Sambutan | Hapus subtitle yang mengulang pengantar; pertahankan ilustrasi dan dua jalur masuk. |
| Masuk | Pertahankan label, autofill, tombol tampilkan sandi, dan satu tindakan utama. |
| Daftar / tautkan email | Tetap ringkas; aturan sandi, persetujuan privasi, serta peringatan akun sementara diperlukan. |
| Beranda | Samakan ukuran judul dan perjelas akses AI; komponen ringkasan waktu/uang tetap sejajar secara hierarki. |
| Agenda mingguan | Judul disamakan; kalender, filter, tambah, timeline dan keadaan kosong tetap. |
| Form tugas / kuliah / edit seri | Tambah chip durasi; tanggal dan jam tetap melalui picker, opsi lanjutan tetap dilipat. |
| Detail agenda | Tidak dipangkas: status, waktu, deadline, prioritas, catatan, dan ruang lingkup seri diperlukan untuk bertindak. |
| Pengingat kegiatan | Pilihan waktu lewat dropdown; batas keterlambatan pengiriman dan validasi tetap. |
| Notifikasi | Ringkas petunjuk dan label riwayat; switch serta tautan pengaturan Android tetap. |
| Asisten percakapan | Judul konsisten, saran pesan dalam satu grup responsif; petunjuk utama tetap satu kalimat. |
| Riwayat Asisten | Tetap dalam bagian lipat; pesan pengguna dan balasan tidak dipotong. |
| Tinjauan gabungan | Hapus catatan durasi berulang; jumlah item, persetujuan, ubah/keluarkan item tetap. |
| Tinjauan edit/hapus/pemulihan | Pertahankan perbandingan sebelum/sesudah dan konfirmasi; jangan memangkas dampak tindakan. |
| Keuangan | Hapus subtitle tiga menu yang mengulang judul; saldo, pemasukan/pengeluaran dan tabungan tetap dibedakan. |
| Form pemasukan / pengeluaran / edit | Pertahankan dropdown kategori, nominal, tanggal dan catatan opsional dalam bagian lipat. Keterangan transaksi sudah terjadi tetap untuk mencegah pencatatan rencana. |
| Riwayat transaksi | Pencarian, filter dan tampilkan lagi tetap; nominal dan tanggal tidak disembunyikan. |
| Detail transaksi | Nominal menjadi fokus; edit/hapus tetap terpisah dan hapus memakai konfirmasi. |
| Laporan bulanan | Ringkas keterangan persentase dan hilangkan kartu Rp0; periode serta total tetap terlihat. Diagram lingkaran masih tahap terpisah. |
| Daftar tabungan | Progres, saldo dan status tercapai sudah cukup; komponen tujuan tetap konsisten. |
| Detail tabungan | Hilangkan subtitle Edit tujuan; progres, setor/tarik dan riwayat tetap. |
| Buat / edit tujuan | Hapus pengantar berulang; chip ikon, target dan tanggal opsional tetap. Penjelasan edit target tidak memindahkan dana dipertahankan. |
| Setoran / penarikan | Hapus pengantar berulang; jumlah tersedia, saldo tujuan dan keterangan perpindahan dana tetap. |
| Profil | Judul disamakan; kelompok akun, preferensi, notifikasi dan privasi tetap. |
| Kustomisasi profil | Tambah jarak antarbaris chip warna agar tidak berdesakan ketika membungkus. |
| Preferensi AI | Chip durasi dan judul bagian jam mengganti kebutuhan membaca catatan panjang. |
| Dialog privasi / izin AI / batal / hapus / keluar | Pertahankan informasi konsekuensi dan persetujuan; dialog dapat digulir. |

Anggaran lama masih diuji untuk regresi, tetapi bukan halaman aktif dan tidak diaktifkan kembali.

## Batas audit

Teks keterangan dibuat singkat pada ukuran normal; tidak dipotong paksa menjadi dua baris ketika aksesibilitas memperbesar font. Nama, catatan pengguna, angka uang, pesan error dan konsekuensi tindakan boleh memanjang. Komponen mengikuti isi agar angka tetap terbaca.

Render memakai fixture sintetis dan beberapa jalur halaman langsung, sehingga navbar/status bar Android tidak direproduksi penuh. Notifikasi yang membutuhkan stream Firestore ditinjau dari kode; pengingat memiliki tes layout tersendiri. Tidak ada panggilan AI/FCM, penulisan produksi, deployment Rules, pemasangan APK, atau perubahan Figma pada tahap ini. Persetujuan publikasi Rules wishlist sebelumnya masih menunggu jawaban.

Bukti berada di `docs/qa/ui-simplicity/`; hasil akhir pengujian dicatat dalam `verification.json`. Tes profil diperbaiki agar menunggu scroll setelah input dan membuka halaman sebagai route yang dapat ditutup; sekarang juga memeriksa nilai benar-benar tersimpan, bukan hanya tidak ada exception.

## Hasil akhir

78 tes Flutter lulus tanpa peringatan hit-test; analyzer bersih. Suite visual berisi lima tes: tiga ukuran layar, perilaku chip durasi, dan navigasi saat keyboard muncul. 25 varian halaman dirender untuk pemeriksaan (termasuk form anggaran lama sebagai regresi). Pratinjau menggunakan angka besar sintetis untuk menguji pembungkusan nominal. Bukti bukan hasil uji produksi atau klaim bahwa pengguna pasti lebih cepat; kemudahan penggunaan nyata tetap perlu dicoba oleh pengguna.
