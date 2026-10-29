# Implementasi Asisten dan impor jadwal

27 Oktober 2026. Ruma 0.2.0+3. Worker `ruma-api` dan Firestore Rules sudah dipublikasikan ke produksi. Perubahan source di workspace masih lokal dan belum di-commit atau di-push. APK release 0.2.0 tersedia; APK lama tetap tersedia.

## Perilaku yang ditambahkan

- Percakapan berurutan dengan konteks maksimal delapan giliran terakhir. Jawaban singkat dapat melengkapi permintaan awal; koreksi merevisi usulan aktif. Sapaan/terima kasih tidak menghapus usulan. Composer tetap dapat digunakan saat ada usulan.
- Endpoint `/v2/agent/turn`; kontrak v1 dipertahankan untuk APK lama. Sistem tetap menggunakan `glm-5.3-flash`. Bukti simpan berasal dari receipt aplikasi, bukan ucapan model.
- Impor maksimal tiga gambar galeri, dengan pembesaran sumber dan koreksi per baris atau chat. Gambar diubah kembali menjadi piksel PNG untuk menghapus metadata, dibatasi 3 MB per gambar / 8 MB total. Gambar dikirim setelah persetujuan khusus.
- Baris yang buram/tidak lengkap tetap terlihat. Pengguna mengonfirmasi tanggal awal/akhir semester; pola mingguan berhenti pada akhir periode, inklusif. Hari pertama dihitung per kelas. Konflik diperiksa sepanjang periode, termasuk lebih dari 90 hari.
- Adapter Google Calendar baca saja, otorisasi terpisah dari login Firebase, pemilihan akun/kalender/periode, pagination, pembaruan manual, serta identitas/versi sumber. Tidak ada penulisan ke Google atau sinkronisasi latar.
- Pengulangan mingguan sederhana menjadi seri Ruma. Pembatalan/pergeseran pertemuan menjadi pengecualian. Jika seri memiliki pengecualian, pergantian hari utama saat impor diblokir dengan penjelasan; pertahankan hari sumber lalu sunting pertemuan di Agenda. Pengecualian ditampilkan dalam rincian tinjauan. Pola lain menjadi kegiatan pada tanggal tertentu; acara sepanjang hari memerlukan jam yang dipilih pengguna atau dikeluarkan dari impor.
- Perubahan sumber ditinjau bersama versi Ruma. Suntingan lokal memerlukan pilihan eksplisit. Hanya status pembatalan eksplisit menjadi usulan penghapusan; respons 404 tidak disamakan dengan pembatalan. Salinan yang telah dihapus tidak dibuat kembali diam-diam. Duplikat isi lintas sumber dilewati, tanpa otomatis menautkan kedua sumber.
- Simpan maksimal delapan perubahan bersama core revision dan receipt dalam satu transaksi. Lebih banyak jadwal dipilih dalam beberapa persetujuan yang jelas; tidak ada pemotongan atau commit sebagian otomatis. Pembaruan dengan reminder lama dapat meminta pilihan lebih kecil karena anggaran akses Rules. Batas seri aktif mengikuti aplikasi: 30.
- Jika hasil simpan tidak diketahui, penyuntingan dikunci dan percobaan ulang memakai identitas operasi yang sama. Usulan disimpan sebelum commit. Nilai keuangan tidak berubah.
- Informasi asal dipertahankan saat edit manual dan pada occurrence mingguan, lalu ditampilkan di detail Agenda. Navbar/maskot dan palet Ruma dipertahankan.

## Privasi dan penyimpanan

Hasil baca ledger tidak otomatis dimasukkan ke konteks model. Koreksi jadwal hanya mengirim nama, hari/tanggal, waktu, lokasi, pilihan baris dan percakapan koreksi; akun Google, event ID dan token tidak ikut dikirim. Izin koreksi ditanyakan tersendiri.

Token Calendar hanya berada dalam memori sesi halaman. Tidak ada client secret atau refresh token di aplikasi. Metadata sumber dimiliki UID Firebase yang melakukan impor. File gambar adalah salinan sementara dalam cache privat per UID; foto galeri asli tidak dihapus. Salinan dibersihkan setelah commit, logout, atau saat pemulihan menemukan usia lebih dari 24 jam; tidak ada janji penghapusan tepat 24 jam saat aplikasi tidak berjalan. Gambar mentah tidak masuk Firestore/session snapshot. Fixture Firestore lokal dibersihkan setelah pengujian; akun uji dihapus oleh suite dan proses emulator dihentikan.

## Validasi

Bukti sementara dan log berada pada `.local/assistant-implementation-20261027/` yang diabaikan Git. Pengujian memakai data sintetis dan project lokal `demo-ruma`, tanpa menulis jadwal/uang pengguna produksi.

- Analyzer bersih dan 93 tes Flutter lulus, termasuk konteks pendek, revisi usulan, migrasi snapshot, pemulihan identitas commit, konversi Calendar, pagination, batas periode, teks 200% pada lebar 320, dan percobaan ulang setelah hasil simpan tidak diketahui.
- 43 tes backend lulus: validasi konteks, autentikasi/kuota, kontrak lama, ekstraksi gambar, koreksi, provenance lintas giliran, notifikasi dan pengulangan.
- 68 tes Firestore Rules lulus: regresi agenda/keuangan/batch/notifikasi/workspace/profil/tabungan dan empat kasus impor. Delapan seri baru dapat disimpan bersama; enam pembaruan dengan reminder lama juga diuji. UID lain, receipt/core/item hilang, versi palsu dan sembilan item ditolak.
- Probe provider selama pengembangan memakai data sintetis: satu gambar berisi empat kelas terbaca sesuai sumber; jawaban pendek menghasilkan agenda berdurasi 60 menit; koreksi memindahkan hanya Basis Data ke Kamis. Lima request dipakai selama pengembangan, termasuk dua keluaran yang ditolak lalu diperbaiki melalui prompt/normalisasi. Probe itu tidak mengirim data pengguna dan tidak melakukan retry otomatis.
- Candidate bundle lulus Wrangler dry-run sebelum deployment. Worker `ruma-api` kini aktif pada versi `da716d11` (sebelumnya `359dcc2b`); isi editor cocok dengan kandidat sebelum deploy, versi aktif dan endpoint live terverifikasi setelah reload. Editor tidak berhasil dibaca penuh setelah reload, jadi exact code readback pascadeploy tidak tercapai. Native Android Kotlin dan plugin gambar berhasil dikompilasi.

APK release: [ruma-0.2.0-release.apk](../output/apk/ruma-0.2.0-release.apk), 63.725.292 byte. Package `id.ruma.app`, versionName `0.2.0`, versionCode `3`. SHA-256: `6b2c7dd8f1888fd1c6da7a74a713236db465d89c11078cfce27582266a462708`. `apksigner verify` lulus dengan APK Signature Scheme v2; signer sama dengan APK Ruma sebelumnya (SHA-1 `2B:3E:5F:E6:17:6A:54:14:D4:C6:89:0D:47:14:1D:57:C7:62:0F:1D`). APK lama tidak ditimpa.

Walkthrough Android API 37 ke Firebase produksi lulus enam kelompok skenario menggunakan akun dan jadwal sintetis: commit dua seri secara atomik, 18 pertemuan berulang, receipt retry tanpa duplikasi, refresh tanpa duplikasi, perlindungan suntingan lokal, keuangan tidak berubah, konflik setelah 90 hari, serta pembatalan dengan tombstone. Provider AI tidak dipanggil dalam uji SDK ini. Auth fixture dihapus dan delapan dokumen Firestore fixture dibersihkan; cleanup memverifikasi tidak ada dokumen tersisa dan tidak menyentuh data pengguna lain. Kalender dalam uji memakai baris sintetis; otorisasi akun Google nyata belum diuji. CPU kasus gambar terbesar di Cloudflare produksi belum diukur. Belum ada uji mahasiswa/TalkBack atau kamera karena MVP memakai galeri. Lihat [hasil pengujian publish](qa/assistant-chat-import-publish/results.json) dan bukti [Worker aktif](qa/assistant-chat-import-publish/worker-published.png) serta [Rules terbit](qa/assistant-chat-import-publish/rules-published.png).

## Retest Worker — 28 Oktober 2026

Worker produksi kembali lulus smoke test dengan data sintetis: lima request tanpa autentikasi/kredensial valid ditolak (`401`); chat, ekstraksi empat kelas dari gambar, dan koreksi jadwal masing-masing berhasil (`200`). Tiga panggilan AI digunakan, tidak ada ledger yang ditulis, dan akun Firebase uji dihapus. Semua 43 tes backend offline juga lulus. Detail tersanitasi ada di [hasil QA](qa/assistant-chat-import-publish/results.json).

## Login Google Ruma — 28 Oktober 2026

Opsi Firebase Auth dengan Google ditambahkan pada halaman akun dan alur penautan akun sementara. Menautkan akun sementara mempertahankan UID dan data; jika kredensial Google sudah dipakai UID lain, Ruma tidak mengganti sesi atau memindahkan data otomatis. Ikon launcher Android diperbarui memakai maskot Teman Abstrak. Kedua perubahan UI ini belum masuk ke APK release 0.2.0+3. Firebase Google provider dilaporkan sudah diaktifkan pengguna, tetapi OAuth web client belum ada di `google-services.json`; ikuti [panduan konfigurasi](GOOGLE-SIGN-IN-SETUP.md) sebelum build dan uji login nyata. Izin Google Calendar tetap terpisah.

## Sisa verifikasi integrasi Calendar

1. Pastikan Google Calendar API, layar consent/test users, OAuth Android, serta scope baca Calendar tersedia pada proyek Google yang sesuai. Package `id.ruma.app`, signer release SHA-1 `2B:3E:5F:E6:17:6A:54:14:D4:C6:89:0D:47:14:1D:57:C7:62:0F:1D`. `google-services.json` tidak memuat OAuth client; keadaan Console belum diverifikasi. AuthorizationClient tidak meminta web client secret.
2. Uji akun Google nyata: pilih akun berbeda dari login Ruma, batalkan izin, baca kalender, impor ulang, pindahkan/batalkan satu pertemuan, lalu pastikan Google tetap tidak berubah. Sampai itu berhasil, otorisasi Calendar belum siap dinyatakan terverifikasi untuk pengguna.
3. Ukur CPU Worker pada gambar terbesar yang diizinkan (3 MB per gambar, 8 MB total) untuk memastikan batas runtime produksi.

APK release menggunakan endpoint v2 dan Rules yang sudah aktif. Build selesai, ditandatangani, dan diverifikasi; belum diunggah ke Play Store. Integrasi Calendar tetap baca saja dan memerlukan verifikasi akun nyata di atas.
