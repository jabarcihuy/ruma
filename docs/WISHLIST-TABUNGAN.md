# Target tabungan / wishlist — Ruma

22 Oktober 2026. Penyempurnaan tujuan tabungan yang ada, tanpa menu atau halaman tambahan. Pengguna menyetujui rekomendasi wishlist; pekerjaan ini menyiapkan kandidat lokal, belum mengubah Firebase produksi.

## Perilaku

- Satu halaman Tabungan untuk wishlist, pendidikan, liburan dan dana darurat. Nama, target rupiah, tanggal opsional serta setor/tarik tetap memakai alur lama.
- Form buat/edit memiliki lima pilihan ikon: Umum, Gadget, Pendidikan, Liburan, Dana darurat. Label menjelaskan ikon, bukan pembatas kategori: pengguna tetap bebas memberi nama tujuannya.
- Kartu daftar/detail menunjukkan ikon, dana terkumpul dari target, progres dan dana yang masih kurang. Target terpenuhi ditandai centang serta teks tebal “Target tercapai”. Penarikan/kenaikan target menghitung status kembali dari saldo aktual; tidak menyimpan flag selesai yang bisa kedaluwarsa.
- Tombol detail “Tambah tabungan” membuka form setoran yang sama. Penarikan tetap tersedia; saldo tercatat, pemasukan dan pengeluaran tidak berubah karena alokasi tabungan.
- Ikon tersimpan sebagai `iconId` opsional pada savingsGoals. Tujuan lama tanpa field ini memakai wallet; tidak memerlukan migrasi massal. Repository mempertahankan ikon saat setor/tarik, dan request key memasukkan ikon agar retry dengan pilihan baru tidak dianggap sama.
- Kandidat Rules membatasi nilai ikon ke lima ID. Field opsional menjaga kompatibilitas klien lama; perubahan ikon hanya lewat edit tujuan, tidak disisipkan dalam setoran/penarikan. Batas dana, pasangan dokumen atomik, versi dan kepemilikan UID tidak berubah.

## Implementasi dan aset

Model/repository: lib/data/savings.dart dan savings_repository.dart. Form/kartu: lib/features/savings/savings_form.dart dan savings_page.dart. SVG square 24×24: wallet, book-open, shield-check yang sudah ada, ditambah headphones dan plane. Semua slot memakai BoxFit.contain; tidak menambah paket. Pilihan menggunakan ChoiceChip dengan semantics selected, label, area sentuh native dan Wrap untuk layar sempit. Pemeriksaan visual pertama menemukan centang native menimpa SVG; showCheckmark dinonaktifkan dan pilihan ditunjukkan melalui warna/garis berkontras.

Kandidat: config/firebase/firestore.wishlist.rules dan firebase.wishlist.json. Perbedaannya dari Rules aktif hanya menerima field iconId opsional dengan enum ketat. firebase.json tetap menunjuk firestore.savings.rules. APK normal kandidat debug x86_64 disiapkan terpisah; jangan dipakai untuk menyimpan ikon ke produksi sebelum Rules dipublikasikan.

## Verifikasi

Bukti: docs/qa/wishlist/.

- Analyzer bersih. 77 tes Flutter lulus; setelah perapian chip, sembilan tes savings UI/store dikonfirmasi kembali. Suite penuh mencatat dua peringatan tap personal-settings-save dari tes layar sempit yang berada di luar perubahan ini; bukan kegagalan savings. Uji Android memakai tap hit-test fatal.
- 13 tes Rules tabungan/wishlist lulus: data legacy, semua pilihan ikon, enum invalid, transfer mempertahankan ikon, transfer yang mengubah ikon ditolak, serta batas dana/isolasi yang lama.
- 51 tes Rules regresi agenda, finance, batch, notifikasi, workspace dan profil/seri lulus terhadap kandidat. Percobaan awal suite agenda memakai flag fitur yang tidak lengkap; dua ekspektasi suite tidak cocok dengan Rules gabungan. Setelah flag fitur aktif disamakan dengan konteks kandidat, 51 tes lulus tanpa melonggarkan Rules. Log awal dipertahankan terpisah.
- Enam kelompok uji native Android pertama lulus: create/edit ikon, readback Firestore, setor/tarik, retry/validasi dana, target tercapai dan sinkronisasi ringkasan. Screenshot awal di first-visual-pass; hasil konfirmasi akhir ditulis android-results.json dan PNG folder utama setelah perapian chip.
- Uji produksi sudah disiapkan dengan WISHLIST_LIVE_TESTS=true bersama SAVINGS_LIVE_TESTS=true. Belum dijalankan. Maksimal dua akun sintetis, nol AI/FCM dan cleanup terikat manifest; memerlukan persetujuan untuk publikasi serta uji produksi baru.

## Batas dan berikutnya

Fitur ini belum menambahkan tools agent tabungan, rekomendasi cicilan otomatis, transfer bank atau notifikasi khusus target. Wishlist bukan transaksi belanja: dana tidak dibelanjakan otomatis saat target tercapai. Figma/PDF belum diperbarui pada tahap Flutter ini.

Berikutnya: persetujuan publikasi Rules ikon dan uji produksi terbatas, lalu pemasangan APK normal kandidat. Diagram lingkaran pengeluaran dan agent tabungan tetap tahap berikutnya. Status final, hash artefak dan cleanup dicatat di qa/wishlist/verification.json.

Hasil akhir: analyzer bersih, 77 tes Flutter, 13 Rules tabungan/wishlist + 51 regresi, sembilan tes widget konfirmasi dan enam kelompok UI Android lulus. Sembilan screenshot akhir disimpan di folder utama. Kandidat APK normal telah dibangun; hash APK dan Rules ada di verification.json. Auth/Firestore demo-ruma dibersihkan (HTTP 200), reverse port dilepas, APK normal tabungan sebelumnya dipulihkan dan cold launch berhasil. VM serta Firebase Emulator dihentikan setelah verifikasi. Tidak ada perubahan produksi pada tahap wishlist ini.

## Rollout produksi — 22 Oktober 2026

Pengguna meminta “terapkan ke prod dan build apk release”. Rules wishlist dipublikasikan melalui Firebase Console; sebelum perubahan Rules aktif cocok persis dengan kandidat savings sebelumnya, lalu hasil publikasi wishlist dibaca ulang setelah reload dan cocok persis dengan kandidat. SHA-256 `0217e0247e06a58a9332b1e782bb008c3fc4472784b2437e1db59701f380ee6b`. firebase.json kini menunjuk kandidat wishlist.

Lima kelompok uji SDK Android produksi lulus menggunakan dua akun sintetis, tanpa AI/FCM. Kedua akun dihapus; 21 dokumen fixture dibersihkan dan keenam koleksi uji per UID diverifikasi kosong. Bukti: qa/wishlist/cloud-results.json, cloud-cleanup.json, dan qa/release/deployment.json. Log PERMISSION_DENIED pada uji isolasi adalah penolakan yang diharapkan terhadap akses UID lain.

APK release dengan signing khusus dan UI terbaru dicatat terpisah di [ANDROID-RELEASE.md](ANDROID-RELEASE.md). Bagian “belum produksi” di atas merupakan riwayat sebelum persetujuan rollout.
