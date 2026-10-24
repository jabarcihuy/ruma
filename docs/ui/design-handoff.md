# Ruma — handoff desain

> Status terkini: desain v32-expense-insight memuat 71 frame desain dan 71 frame prototype; PDF 12 halaman. Angka/revisi di bagian lama merupakan riwayat. Keputusan backend 18 Oktober 2026 memakai Firebase Auth, Firestore, FCM, dan proxy AI Cloudflare Workers Free. Lihat [keputusan arsitektur](../ARCHITECTURE.md); penundaan cloud data inti pada catatan lama sudah digantikan.

16 Oktober 2026 · v23-final-v1-draft

**72 frame desain + 72 frame prototype · 11 kelompok · 20 titik mulai produk + 1 launcher QA.**

[Canvas](https://www.figma.com/design/FE73TkpfpJrSuEX97IdrTX/Study-Match?node-id=35-66) · [Prototype](https://www.figma.com/proto/FE73TkpfpJrSuEX97IdrTX/Study-Match?page-id=42%3A53&node-id=44-9131&starting-point-node-id=44%3A9131&scaling=scale-down)

Navigasi: Beranda · Agenda · Asisten · Keuangan · Profil.


## Perampingan v22 — 72 frame

Canvas aktif dan prototype masing-masing memiliki **72 frame**, **11 kelompok**, dan **20 titik mulai**. Tiga belas frame dikeluarkan: sepuluh digabung ke layar bersama dan tiga fitur ditunda. Sign in, sign up, logout, history, personal preferences, filter riwayat, dan hapus riwayat tetap tersedia.

Yang ditunda hanya **quiet hours**, **feedback sesi**, dan **profile preview** pada revisi ini. Menyimpan profil langsung menerapkan avatar pilihan dan kembali ke Profil. Pengingat dasar dan izin notifikasi tetap ada. Penundaan cloud, suara, OCR, dan penundaan sebelumnya tetap berlaku.

Layar bersama mengikuti konteks masuk; pengguna tidak harus memilih mode lagi. Tambah/edit kegiatan memakai satu frame; tambah/ubah jadwal memakai satu frame; pemasukan/pengeluaran/edit transaksi memakai satu frame. Asisten agenda dan keuangan memakai satu tujuan navigasi dengan contoh yang sesuai konteks. Pilihan jam alternatif berubah di layar yang sama. Tinjauan agenda tunggal, transaksi tunggal, dan gabungan berbagi satu frame; detail kuliah/tugas berbagi satu frame. Hasil perkiraan durasi menyatu dengan draf.

Di Figma, konteks disusun sebagai kelompok native editable dengan binding variabel visible. Hanya satu konteks ditampilkan pada satu waktu. Kelompok konteks bukan phone frame tersembunyi yang dihitung sebagai pengurangan; tiga belas root prototype dan tiga belas wrapper layar lama benar-benar dikeluarkan dari canvas aktif. Implementasi Flutter dapat menggunakan satu form dengan data/konteks sesuai kebutuhan.

Validasi: **36 kasus deklarasi interaksi lulus**, **483 aksi navigasi diperiksa tanpa tujuan hilang**, serta tidak ditemukan wrapper bertumpuk/keluar section, konten sumber yang terpotong, atau ikon telepon yang melebar. Ini pemeriksaan deklarasi dan visual Figma, bukan pengujian aplikasi Flutter. Prototype tetap memakai data contoh, bukan input teks bebas atau AI nyata. Pada v23, batch contoh gabungan sudah terhubung ke Agenda dan Keuangan; batas simulasi dijelaskan pada bagian v23.

PDF tidak diperbarui sesuai permintaan. Versi v18 tetap disimpan.

## Layar bersama

| Layar lama | Frame bersama |
|---|---|
| `taskEdit` | `taskAdd` |
| `classEdit` | `classAdd` |
| `incomeAdd` | `expenseAdd` |
| `transactionEdit` | `expenseAdd` |
| `budgetChat` | `chat` |
| `slotAlt` | `slots` |
| `agentCreate` | `combinedDraft` |
| `budgetAIreview` | `combinedDraft` |
| `detailMetode` | `taskDetail` |
| `aiResult` | `chatDraft` |

## Kelompok aktif

| Kelompok | Frame |
|---|---|
| 01 · Mulai & akun | 4 |
| 02 · Ritme & jadwal | 5 |
| 03 · Agenda & kegiatan | 9 |
| 04 · Keadaan inti | 7 |
| 05 · Perubahan jadwal | 3 |
| 06 · Asisten pribadi | 6 |
| 07 · Agent: agenda & uang | 10 |
| 08 · Pengingat | 5 |
| 09 · Profil & pengaturan | 9 |
| 10 · Personalisasi profil | 1 |
| 11 · Keuangan pribadi | 13 |

Sumber data aktual: `ruma-design-state.json`, `ruma-screen-spec.json`, `ruma-final-v23-graph.json`, `ruma-final-v23-state.json`. Riwayat sebelum revisi: `archive/v21-before-reduction/`.


## Penyempurnaan v23 — draf final v1

Status: siap diuji pengguna, belum dinyatakan final berdasarkan uji kegunaan. Tetap 72 frame mobile pada 11 kelompok. Terdapat 20 titik mulai produk dan satu launcher QA di luar layar aplikasi. Launcher tidak menambah halaman produk.

- Ringkasan jumlah agenda dan transaksi mengikuti item yang dikeluarkan atau dipulihkan.
- Informasi nominal yang kurang dan hari tanpa slot ditangani di dalam draf yang sama. Agenda lain dan transaksi tetap tersedia. Memilih Rabu hanya memperbarui usulan; penyimpanan tetap memerlukan persetujuan.
- Simpan gagal mempertahankan draf dan edit. Tidak ada item yang dikomit sebagian. Tombol utama berubah menjadi “Coba simpan lagi”, tanpa dua tindakan utama yang sama.
- Item yang disetujui disalin sebagai hasil tersimpan. Mengedit draf berikutnya tidak mengubah hasil sebelumnya sebelum persetujuan.
- Dua agenda contoh muncul pada tanggal yang disetujui di Agenda. Transaksi muncul pada bagian tanggal 12 Oktober di riwayat. Saldo, sisa anggaran, kategori, grafik dan laporan mengikuti nominal contoh yang disimpan.
- Tautan “Lihat di Agenda” dan “Lihat di Keuangan” tersedia pada hasil. Filter riwayat dan pergantian bulan mempertahankan data periode yang sesuai.

Contoh validasi: pengeluaran Rp18.000 + Rp15.000 menghasilkan pengeluaran bulanan Rp1.213.000, saldo Rp787.000 dan sisa anggaran Rp287.000. Jika makan diubah menjadi Rp20.000 sebelum simpan, saldo menjadi Rp785.000. Kategori Kuliah pada contoh laporan masuk Lainnya dan diberi penjelasan.

Validasi: 28 pemeriksaan alur/struktur v23 lulus, 36 pemeriksaan regresi fitur yang dipertahankan lulus, dan 492 aksi navigasi tetap memiliki tujuan. Audit 72 frame sumber tidak menemukan wrapper bertumpuk, keluar section, atau konten utama terpotong. Komponen native editable, Manrope, serta ikon persegi dipertahankan. Pemeriksaan ini mengevaluasi deklarasi tindakan dan tampilan Figma; bukan pengujian AI/Flutter atau uji pengguna manusia.

Prototype memakai pesan dan nilai contoh, bukan AI nyata atau ketikan bebas. Satu batch gabungan contoh memperbarui agenda, riwayat, angka Beranda/Keuangan, kategori dan laporan; simpan ulang batch yang sama tidak menggandakan pengeluaran. Simulasi satu batch ini belum menjadi ledger persisten untuk banyak batch atau kombinasi seluruh mutasi lama. Detail transaksi gabungan tersedia baca-saja; edit dilakukan pada draf sebelum persetujuan. Implementasi Flutter wajib memakai penyimpanan dan validasi atomik sungguhan.

Panduan uji tiga tugas: `ruma-uji-pengguna-v1.md`. PDF tetap ditunda.


## Ikon kategori v24

Empat kategori memiliki ikon berbeda: makanan (alat makan), transportasi (bus), kebutuhan kos (rumah), dan kuliah (buku). Dua komponen baru dibuat, dua komponen lokal digunakan kembali. Diterapkan pada enam instance transaksi di desain sumber dan enam instance di prototype. Semua native editable, grid 24 × 24, stroke 2, dengan tampilan 20 × 20 pada slot transaksi. Warna mengikuti token Ruma. Shortcut umum keuangan tetap memakai dompet.

Paket SVG dan lisensi: `output/assets/ruma-assets-v24.zip`. Header agenda kosong dikonfirmasi benar pada ukuran normal; tidak diubah. Jumlah frame tetap 72 dan PDF tetap ditunda.


## Navbar v25 — opsi 2 diterapkan

Navbar aktif memakai panel putih mengambang 342 × 72, radius 16, dan bayangan lembut (offset y 4, blur 12, opacity 8%). Lima tab berukuran sama, sekitar 65,2 × 56, dengan ikon 22 × 22. Tab aktif memiliki latar peach lembut serta ikon/label oranye; tab lainnya memakai warna muted dengan opacity penuh. Urutan: Beranda · Agenda · Asisten · Keuangan · Profil.

Lima varian komponen bersama, 14 instance sumber, dan 14 instance prototype diperbarui tanpa mengganti ID navbar atau tujuan menu. Agenda kosong kini menandai Agenda sebagai tab aktif. Sebanyak 70 tujuan tombol navbar diperiksa dan valid. Jumlah produk tetap 72 frame; tiga preview perbandingan berada di board eksplorasi terpisah. PDF tidak diubah.


## Navbar dan maskot · v26

Navbar floating putih kini tanpa teks: Beranda, Agenda, Asisten, Keuangan, Profil. Tombol Asisten di tengah memakai maskot Teman Abstrak oranye dalam lingkaran gelap. Titik oranye menunjukkan halaman aktif. Ukuran panel 342 × 64, radius 24, target setiap tab 65,2 × 48, ikon samping 22 × 22, badge tengah 48 × 48. Maskot tersedia sebagai SVG penuh, ikon wajah, dan badge; seluruhnya vector editable di Figma.

Komponen diterapkan pada lima state navbar, 14 navbar sumber dan 14 navbar prototype. Pemeriksaan geometri, label tersembunyi, dan 70 tujuan tab prototype lulus. Jumlah layar produk tetap 72. Saat implementasi Flutter, beri nama aksesibilitas pada kelima tab karena teks tidak tampil; layer label tersembunyi di Figma adalah spesifikasi, bukan implementasi screen reader. PDF tetap ditunda.


## Keseimbangan waktu dan uang · v27

Ruma adalah aplikasi pribadi untuk mengelola waktu dan uang, dibantu agent AI. Kedua bidang menjadi inti yang setara. Beranda memiliki kartu Waktu hari ini dan Uang bulan ini, masing-masing 342 × 184, serta dua tindakan setara: Tambah agenda dan Catat transaksi. Timeline lengkap tetap tersedia di Agenda. Ringkasan uang menampilkan saldo, sisa anggaran, pengeluaran bulan ini, dan kategori pengeluaran terbesar.

Asisten menampilkan empat pintasan dalam grid 2 × 2: Atur agenda, Lihat agenda, Catat transaksi, dan Cek anggaran. Contoh gabungan menghasilkan dua agenda dan dua transaksi melalui draf yang harus ditinjau. Form manual agenda dan transaksi sama-sama tersedia. Welcome dan pengantar kanvas menjelaskan kedua fungsi.

Sebelas tombol/pintasan prototype mempertahankan tindakan serta pengaturan konteks aslinya. Empat angka keuangan Beranda terikat pada variabel yang diperbarui draf gabungan. Pemeriksaan layout baru tidak menemukan overflow. Jumlah layar tetap 72 sumber dan 72 prototype; fitur lama dipertahankan. Nilai dan pesan prototype adalah contoh. Hitung ringkasan serta kategori terbesar dari data aktual saat implementasi Flutter. PDF tetap ditunda.


## PDF untuk LMS · 17 Oktober 2026

PDF desain antarmuka terbaru tersedia pada `output/pdf/ruma-desain-antarmuka-lms.pdf`: 12 halaman, seluruh 72 layar aktif, sampul dan daftar isi, serta tautan desain/prototype. Ukuran sekitar 4,2 MB. Ini menggantikan status penundaan PDF pada catatan versi sebelumnya. Dokumen v18 tetap disimpan sebagai arsip.


## Kerapian v29

Time picker menggunakan kolom Jam/Menit yang sejajar dengan penanda baris pilihan. Shared chat memakai wrapper konteks umum/keuangan, area scroll konsisten, dan footer tetap. Tinggi deskripsi pintasan disamakan menjadi 36 px. Audit seluruh 72 desain dan 72 prototype selesai; tidak ada frame atau fitur yang dihapus. Rincian: `ruma-frame-tidiness-v29-audit.md`.

PDF LMS diperbarui setelah audit v29: 12 halaman, 72 layar, 4.21 MB. Halaman terdampak 1, 3, dan 5 sudah dirender ulang dan ditinjau secara visual.


## Revisi v31 - Ritme Harian dihapus

17 Oktober 2026: halaman Ritme Harian beserta pintasan Profil/Pengaturan dihapus. Tersisa 71 layar desain dan 71 layar prototype. Welcome tanpa akun dan persetujuan awal langsung ke Beranda. Tambah jadwal, pengulangan, perubahan pertemuan, dan pemilih tanggal/jam tetap tersedia. Saran waktu memakai agenda, deadline, durasi, dan rentang waktu permintaan; AI bertanya jika rentangnya belum jelas. Keterangan terkait jam aktif, istirahat, dan jeda otomatis disesuaikan. PDF tidak lagi menampilkan label Figma/Prototype di bawah setiap frame.
