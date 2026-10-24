# Ruma — paket aset v24

Paket pendamping desain Figma Ruma. Berisi aset terpisah, bukan gambar satu layar utuh.

## Isi

- `brand/`: ikon aplikasi, foreground transparan, monogram Ruma, dan ikon notifikasi.
- `launcher/`: PNG ikon aplikasi 48, 72, 96, 144, 192, 512, dan 1024 px; foreground 108, 162, 216, 324, 432, dan 1024 px; ikon notifikasi 24, 36, 48, 72, dan 96 px.
- `icons/`: SVG navigasi, aksi, form, dan status.
- `illustrations/`: kalender, pencarian, dan dompet.
- `fonts/`: font variabel Manrope dan lisensi OFL.
- `manifest.json`: daftar aset, ukuran, hash, dan sumber komponen Figma.

## Pemakaian di Flutter

Salin folder ini ke `assets/ruma/`, lalu daftarkan direktori aset dan font Manrope pada `pubspec.yaml`. SVG perlu dirender menggunakan dukungan SVG pada implementasi Flutter; PNG dapat dipakai langsung sebagai aset gambar.

Warna ikon antarmuka menggunakan `#20241F` sebagai warna dasar. Tint saat render untuk keadaan aktif, nonaktif, dan latar gelap. Ikon notifikasi menggunakan putih dengan latar transparan. Jangan gunakan ikon aplikasi berwarna sebagai ikon notifikasi kecil.

Untuk launcher Android, pemetaan ukuran ikon biasa adalah mdpi 48, hdpi 72, xhdpi 96, xxhdpi 144, dan xxxhdpi 192 px. Foreground adaptif menggunakan ukuran 108, 162, 216, 324, dan 432 px pada kepadatan yang sama; latar belakangnya warna solid `#CF4924`. Salin dengan nama resource Android yang valid saat implementasi.

Teks UI tetap dibuat sebagai widget teks, form sebagai input, dan chart sebagai komponen. Aset ini tidak menggantikan komponen editable pada Figma.

## Sumber

- Desain: [Ruma di Figma](https://www.figma.com/design/FE73TkpfpJrSuEX97IdrTX/Study-Match?node-id=229-4857).
- Ikon antarmuka: Lucide; lisensi disertakan pada `icons/LICENSE-Lucide.txt`.
- Font: [Manrope di Google Fonts](https://github.com/google/fonts/tree/main/ofl/manrope); lisensi disertakan pada `fonts/OFL.txt`.
- Monogram Ruma dan ilustrasi dompet dibuat untuk proyek ini. Ilustrasi kalender/pencarian diekspor dari komponen editable yang sudah ada.

## Batas prototype

Canvas tetap memiliki 82 frame produk dan 82 frame prototype. Pemilih periode menyediakan data contoh September–November 2026. September berupa ringkasan historis; contoh detail transaksi/CRUD tersedia pada Oktober. November menunjukkan keadaan belum ada transaksi. Prototype memakai contoh tindakan terakhir, belum menjalankan AI, input bebas, penyimpanan lokal Flutter, atau notifikasi perangkat.

PDF ditunda sesuai permintaan; paket ini tidak berisi PDF baru.


## Ikon kategori v24

Makanan memakai `icons/utensils.svg`, transportasi `icons/bus-front.svg`, kebutuhan kos `icons/house.svg`, dan kuliah `icons/book-open.svg`. Keempatnya menggunakan grid 24 × 24 serta stroke 2. Ikon baru berasal dari lucide-react v0.468.0, berlisensi ISC; lisensi disertakan. Ikon kategori dipakai pada catatan transaksi, sementara shortcut umum keuangan tetap memakai dompet.


## Teman Abstrak · v26

`mascot/abstract-friend.svg` adalah versi penuh 128 × 128; `abstract-friend-icon.svg` adalah wajah pada grid 24 × 24; `abstract-friend-badge.svg` adalah tombol Asisten 48 × 48. SVG digambar ulang untuk Ruma dari konsep pilihan pengguna, dengan warna datar dan bentuk vector editable. Ini ikon Asisten; ikon launcher Ruma tetap memakai identitas R.
