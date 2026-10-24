# Ruma — tabungan dan diagram pengeluaran

Tanggal: 21 Oktober 2026. Status: rancangan Figma untuk ditinjau pengguna; belum diterapkan ke Flutter atau backend.

## Keputusan cakupan

Fitur yang diganti adalah **anggaran**, bukan agenda. Agenda dan manajemen waktu dipertahankan. Tujuan tabungan menggantikan form batas pengeluaran; laporan keuangan menampilkan diagram lingkaran pengeluaran per kategori. Tidak menambah tab navigasi: tabungan diakses dari Keuangan.

File: https://www.figma.com/design/FE73TkpfpJrSuEX97IdrTX/Study-Match

Halaman: `35:53` Full product design dan `42:53` Interactive prototype.

## Frame

| Frame | Design | Prototype | Isi |
|---|---|---|---|
| Keuangan | 144:11489 | 146:19711 | Saldo tercatat, uang tersedia, total tabungan, pemasukan/pengeluaran dan pintasan |
| Daftar tabungan | 422:5127 | 426:6430 | Total tabungan, dua tujuan, progres dan pintasan Asisten |
| Detail tujuan | 422:5228 | 426:6537 | Target dana darurat, progres, setor/tarik, edit tujuan dan riwayat |
| Form tujuan | 144:11753 | 146:19749 | Nama, target dan tanggal opsional; berbagi form tambah/edit |
| Setoran/penarikan | 422:5348 | 426:6655 | Jenis perpindahan, tujuan, nominal, tanggal dan catatan opsional |
| Tinjauan AI tabungan | 422:5412 | 426:6721 | Permintaan, nominal, dampak pada tabungan/uang tersedia, simpan/ubah/batal |
| Laporan pengeluaran | 144:13661 | 146:20051 | Diagram lingkaran, empat kategori, nominal, persentase dan pintasan Asisten |

Empat frame baru ditambahkan. Tiga frame lama diperbarui/digunakan ulang. Jumlah layar aplikasi menjadi **75 pada masing-masing halaman**, sebelumnya 71. Launcher QA di prototype tidak dihitung sebagai layar aplikasi. Kelompok Keuangan berisi 17 layar, disusun empat kolom mengikuti alur pengguna.

Beranda dan konteks keuangan Asisten diselaraskan ke tabungan. Layar edit/hapus transaksi melalui AI dipertahankan; nama internal lama berawalan budget diganti agar tidak menyiratkan fitur anggaran masih aktif. Komponen anggaran lama dalam pustaka tidak dihapus, tetapi tidak digunakan pada rancangan layar aktif yang diperbarui.

## Perhitungan contoh

- Pemasukan Rp2.000.000 − pengeluaran Rp1.180.000 = saldo tercatat Rp820.000.
- Dana darurat Rp300.000 + buku semester depan Rp100.000 = total tabungan Rp400.000.
- Saldo tercatat Rp820.000 − dana tabungan Rp400.000 = uang tersedia Rp420.000.
- Dana darurat Rp300.000 / Rp1.000.000 = 30%; buku Rp100.000 / Rp100.000 = 100%.
- Draf setoran Rp100.000: dana darurat menjadi Rp400.000 dan uang tersedia Rp320.000. Saldo tercatat dan pengeluaran tidak berubah.

Diagram: makan Rp640.000 (54,2%), transportasi Rp180.000 (15,3%), kos/tagihan Rp260.000 (22,0%), lainnya Rp100.000 (8,5%). Total Rp1.180.000 dan 100%. Setoran/penarikan adalah perpindahan dana; tidak masuk pemasukan atau pengeluaran maupun diagram ini.

## Komponen dan prototype

Layer teks, tombol, field, kartu dan sektor diagram tetap native/editable. Tidak ada gambar raster sebagai pengganti keseluruhan layar. Memakai Manrope serta warna oranye, sage dan latar Ruma yang ada. Tombol/link/field/navbar memakai instance komponen lokal; kartu tujuan aktif/tercapai serta baris kategori ditambahkan ke area komponen (`422:4931`). Ikon Asisten memakai teman abstrak Ruma.

Tujuh frame prototype berukuran 390×844. Konten panjang memakai vertical scrolling; navbar pada layar bertab berada di bagian bawah viewport. Transisi navigasi dissolve 0,2 detik. Variabel prototype mengganti judul setor/tarik dan tambah/edit tujuan. Pintasan pemasukan/pengeluaran mengaktifkan konteks form bersama yang sesuai.

## Verifikasi

- Tujuh komposisi desain diperiksa melalui screenshot; prototype laporan juga diperiksa dalam viewport mobile.
- Seluruh teks pada tujuh frame baru/diperbarui maksimal dua baris, termasuk keterangan.
- Audit struktur menemukan 27 aksi navigasi pada tujuh frame; seluruh tujuan masih ada dan berada di halaman prototype yang sama.
- Tidak ada teks anggaran pada wrapper layar aplikasi aktif; jumlah layar desain/prototype masing-masing 75.
- Tinggi baris tombol diperbaiki agar tidak menimpa kartu. Progres tujuan tercapai memakai komponen penuh 100%.
- Screenshot ada di `docs/qa/savings-figma/`; berkas before-* adalah kondisi sebelum perubahan.

Pemeriksaan interaksi dilakukan pada struktur aksi Figma, bukan pengujian otomatis klik browser. Data tetap contoh statis: tombol simpan menavigasi antarmockup, belum melakukan penyimpanan atau perhitungan dinamis. Detail tujuan yang dirancang untuk skenario klik adalah dana darurat; kartu buku menampilkan contoh tujuan tercapai. Form, error validasi dan simulasi mutasi penuh dapat disempurnakan saat implementasi setelah rancangan disetujui.

## Langkah berikutnya

Review rancangan tabungan dan diagram bersama pengguna. Setelah disetujui, rancang perubahan model/repository/Rules dan kemampuan agent, kemudian implementasikan di Flutter. Status kode anggaran yang ada belum diubah oleh pekerjaan ini. Tidak membuat PDF, APK, deployment atau panggilan model/FCM pada tahap ini.
