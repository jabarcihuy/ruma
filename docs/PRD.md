# Ruma — PRD versi ringkas

> Status pengembangan 19 Oktober 2026: fondasi Flutter Android dan Firebase Auth lulus uji emulator serta produksi pada HP. APK pratinjau telah dipasang. Bukti dan batas implementasi terkini ada di [FLUTTER-FOUNDATION.md](FLUTTER-FOUNDATION.md) dan [DEVELOPMENT-LOG.md](DEVELOPMENT-LOG.md). Pernyataan “belum dibuat” pada riwayat di bawah menggambarkan tahap perencanaan sebelumnya.

> Keputusan implementasi 18 Oktober 2026: akun menggunakan Firebase Auth, database utama Cloud Firestore, push notification tetap memakai FCM, dan proxy AI memakai Cloudflare Workers Free menuju NaraRouter. Ini menggantikan penundaan cloud data inti dan rencana penyimpanan lokal saja pada catatan lama di bawah. Daftar/masuk/logout harus berfungsi. Rincian serta hal yang belum diuji tercatat di [keputusan arsitektur](ARCHITECTURE.md). Implementasi belum dimulai.

Versi implementasi 1.12 · 18 Oktober 2026 · acuan visual v32-expense-insight

Ruma adalah aplikasi Flutter untuk membantu mahasiswa mengelola waktu dan uang. Keduanya menjadi fungsi inti yang setara, dibantu agent AI pribadi. Beranda merangkum waktu dan keuangan dalam dua kartu berukuran sama. Pengguna dapat memakai percakapan atau formulir manual untuk agenda maupun transaksi, meninjau rincian, lalu menyetujui perubahan.

## Masalah dan pengguna

Pengguna utama adalah mahasiswa rantau yang ngekos. Temuan dari percakapan pengguna: jadwal kuliah sering berubah; jadwal belum biasa dicatat; deadline tugas berada di LMS dan sering diingatkan teman; pengeluaran tidak teratur; sisa uang diperiksa melalui mobile banking atau dompet; menabung masih sulit.

Versi ini mengurangi beban mencatat dan menyesuaikan informasi lewat percakapan, lalu membantu melihat waktu dan pengeluaran secara terpadu. Data tugas dari LMS, perubahan jadwal, uang tunai, dan saldo bank tidak diambil otomatis. Pengguna memasukkan dan memperbaruinya secara manual atau lewat pesan ke AI.

## Batas pengembangan

- Canvas aktif: **71 frame**, setelah penghapusan halaman Ritme Harian.
- Prototype aktif: **71 frame**, dengan 20 titik mulai produk + satu launcher QA di luar layar mobile.
- Pengelompokan canvas: **11 kelompok**.
- PDF terkini v32: **12 halaman**, memuat 71 layar dan tanpa label Figma/Prototype di bawah setiap frame.
- Frame meliputi form, konfirmasi, keadaan kosong/gagal/berhasil, dan contoh alur. Jumlah frame bukan jumlah route Flutter yang wajib dibuat.
- Belum ada implementasi Flutter pada pekerjaan desain ini. Prototype menggunakan data contoh dan simulasi tindakan terakhir.
- Riwayat PRD sebelum penyelarasan teknis tersedia pada [arsip desain](archive/PRD-design-v32-history.md). Dokumen lama bukan kontrak backend aktif.

## Navigasi

**Beranda · Agenda · Asisten · Keuangan · Profil**

Beranda paling kiri, Profil paling kanan, dan Asisten di tengah. Asisten memakai maskot Teman Abstrak pada tombol tengah. Navbar menampilkan ikon tanpa teks dan titik penanda halaman aktif. Tambah manual tersedia pada halaman terkait, tanpa item navigasi tambah tersendiri.

## Fitur aktif

### Beranda

Menampilkan akses “Kelola waktu & uang”, kartu Waktu hari ini dan Uang bulan ini dengan ukuran setara. Waktu merangkum jumlah kegiatan, deadline, dan jadwal berikutnya; uang merangkum saldo tercatat, sisa anggaran, pengeluaran bulan ini, dan kategori terbesar. Ketuk kartu untuk membuka Agenda atau Keuangan. Tombol Tambah agenda dan Catat transaksi tersedia berdampingan. Angka keuangan memakai sumber data yang sama dengan halaman Keuangan.

### Agenda dan kegiatan

Pengguna mencatat kuliah atau aktivitas yang waktunya diketahui, termasuk tanggal, jam mulai/selesai, dan pengulangan mingguan. Pertemuan dapat berubah atau dibatalkan untuk satu kejadian atau kejadian tersebut dan seterusnya.

Kegiatan/tugas memiliki nama, deskripsi, durasi sesi, tanggal/waktu bila sudah dijadwalkan, prioritas, deadline, dan status. Pengguna dapat menyimpan tanpa waktu, mencari saran waktu kosong, menentukan waktu sendiri, mengedit, menghapus, dan menandai selesai. Pencatatan durasi aktual melalui feedback sesi ditunda.

Saran waktu mempertimbangkan agenda yang sudah terisi, durasi, deadline, dan rentang waktu yang diminta pengguna. Jika rentangnya belum jelas, AI menanyakannya sebelum menyusun draf. Waktu tanpa agenda tidak otomatis dianggap sebagai waktu yang bersedia diisi pengguna. Durasi dapat diisi sendiri atau diperkirakan AI. Tidak tersedia pemecahan otomatis menjadi banyak sesi pada tahap ini. Bila tidak muat, pengguna mengganti tanggal, menyesuaikan durasi, atau menyimpan tanpa waktu.

Perubahan kuliah yang berbenturan dengan tugas ditinjau sebelum diterapkan. Saran lama harus diperiksa kembali bila agenda sudah berubah. Ruma tidak memindahkan kegiatan tanpa persetujuan.

Satu halaman Agenda menangani pemilihan hari dan hasil perubahan. Satu detail jadwal dan satu detail tugas menerima data kegiatan terpilih; tidak dibuat halaman terpisah untuk setiap mata kuliah atau hari.

### Agent AI

Agent adalah jalur utama untuk mengurangi pengisian formulir, dengan kemampuan:

1. Membuat kegiatan dari bahasa sehari-hari.
2. Mencari dan membaca kegiatan berdasarkan nama atau waktu.
3. Mengusulkan perubahan kegiatan yang sudah ada.
4. Mengusulkan penghapusan kegiatan dengan target dan cakupan yang jelas.
5. Memperkirakan durasi sesi dan menawarkan waktu yang tersedia.
6. Membuat, membaca, mengubah, dan menghapus catatan transaksi melalui percakapan.
7. Menjelaskan ringkasan keuangan dan laporan berdasarkan transaksi tercatat.

Alur: **pesan → pemahaman/klasifikasi → klarifikasi jika ambigu → validasi → draf/tinjauan → persetujuan → simpan → hasil dan urungkan**. Pembacaan data tidak perlu persetujuan mutasi. Tindakan mengubah data tetap memerlukan konfirmasi.

Nama mirip, misalnya laporan praktikum dan laporan organisasi, memerlukan pemilihan target. Permintaan perubahan waktu tidak membuat kegiatan duplikat. Bila waktu bentrok, AI menawarkan alternatif. Form manual memakai draf yang sama dan tetap tersedia.

Satu layar tinjauan perubahan dapat menangani beberapa kegiatan; satu hasil dan satu hasil urungkan menangani berbagai tindakan agenda. Tampilan berubah mengikuti tindakan yang dipilih.

Personalisasi menggunakan preferensi dan durasi rencana yang dipilih/diubah pengguna dari riwayat yang diizinkan. Pencatatan durasi aktual tetap ditunda. Ini penyesuaian rekomendasi dari konteks, bukan melatih ulang bobot model AI di perangkat. Riwayat dan kontrol personalisasi tetap tersedia.

### Keuangan

Fitur aktif: anggaran bulanan total/per kategori, pemasukan, pengeluaran, edit/hapus transaksi, riwayat dengan pencarian/filter, laporan bulanan sederhana, serta agent AI.

Kategori contoh: Makan, Transport, Kebutuhan kos, dan Lainnya. Transaksi memiliki jenis, nominal rupiah, kategori, tanggal, dan keterangan. Nominal harus lebih besar dari nol.

**Saldo tercatat = pemasukan tercatat − pengeluaran tercatat.**

**Sisa anggaran belanja = batas anggaran periode − pengeluaran tercatat periode tersebut.**

Anggaran bukan saldo rekening. Laporan hanya mencakup transaksi yang sudah dicatat. Tidak ada koneksi bank atau pembacaan uang tunai otomatis.

Laporan menampilkan arus kas serta pengeluaran per kategori dibanding batas anggarannya. AI menjelaskan angka dan dapat membuka riwayat yang mendasarinya. Penjelasan tidak menganggap transaksi yang belum dicatat sebagai data yang diketahui.

Satu halaman detail transaksi menerima item yang dipilih. Filter mengubah tampilan Riwayat pada halaman yang sama. Konfirmasi hapus dipakai bersama untuk jalur manual/AI. Satu hasil transaksi menangani pencatatan pemasukan/pengeluaran, perubahan, dan penghapusan; urungkan memulihkan keadaan sebelumnya.

### Pengingat

Pengingat per kegiatan meliputi aktif/nonaktif, waktu sebelum mulai (atau deadline untuk tugas belum terjadwal), dan pesan. Pengiriman utama memakai FCM dari Worker terjadwal. Notifikasi lokal menampilkan FCM saat aplikasi terbuka dan menangani penundaan lima menit; tidak menjadwalkan salinan pengingat utama yang sama. Jam tenang ditunda. Izin perangkat ditangani terpisah. Tanpa izin, informasi tetap dapat dibaca di aplikasi. Menunda pengingat tidak memindahkan jadwal. Rincian dalam [spesifikasi notifikasi](NOTIFICATIONS.md).

### Profil dan preferensi dasar

Profil berisi nama panggilan, bio, kampus, jurusan, semester, serta avatar inisial dengan pilihan warna. Frame profile preview terpisah ditunda; pengguna mengedit pada form profil. Pemotongan foto dan alur foto khusus ditunda; versi ringkas memakai avatar inisial.

Preferensi aktif meliputi pengingat, bahasa yang ditampilkan pada rancangan, izin personalisasi, panjang sesi nyaman, dan gaya saran. Zona waktu menggunakan konteks perangkat; pengaturan zona waktu khusus tidak ditampilkan.

Privasi menyediakan kontrol penggunaan riwayat dan penghapusan riwayat personalisasi. Bantuan menjelaskan cara saran, persetujuan AI, serta angka keuangan bekerja.

### Akun dan penyimpanan

Daftar, masuk, dan logout harus berfungsi melalui Firebase Auth. Mode tanpa pendaftaran email memakai anonymous session, bukan database lokal terpisah; pertama kali membutuhkan internet. Daftar dari sesi tersebut menautkan akun agar UID/data tetap. Data utama berada di Firestore, dipisahkan per UID. Logout tidak menghapus data cloud dan tidak membuka data akun lama sebagai mode tamu.

Offline tahap awal mendukung baca cache yang sudah tersedia dan penyuntingan draf lokal; commit data membutuhkan koneksi untuk transaksi dan pemeriksaan bentrokan terbaru. Tidak ada keberhasilan simpan palsu atau auto-commit tersembunyi setelah koneksi kembali. Verifikasi email dan pemulihan kata sandi tetap ditunda. Akses provider AI melalui Cloudflare Worker dengan secret server.

## Fitur ditunda atau dikeluarkan dari cakupan aktif

- Pemecahan pekerjaan otomatis menjadi beberapa sesi dan tinjauan multisessi.
- Pengaturan ritme berbeda untuk setiap hari dan peninjauan dampaknya.
- Pengaturan zona waktu kustom.
- Ekspor JSON/CSV dan alur cadangan berkas.
- Tema gelap, pengaturan ukuran teks khusus, dan kontrol animasi khusus dalam aplikasi.
- Alur pemotongan foto profil.
- Penghapusan akun lanjutan.
- Suara/transkripsi, screenshot/OCR, sinkronisasi kalender/LMS eksternal, dan fitur backup/export khusus. Database cloud inti tidak lagi ditunda.
- Penjadwalan ulang otomatis berbasis aturan serta pengaturan pola energi.
- Verifikasi email dan lupa/reset kata sandi.
- Fitur fokus/timer tidak termasuk produk aktif.

Keterbacaan teks, dukungan keyboard, layar kecil, scroll, dan preferensi aksesibilitas perangkat tetap menjadi kewajiban kualitas implementasi, walaupun frame demonstrasinya dihapus dari canvas utama.

## Data inti untuk implementasi

| Data | Isi utama |
|---|---|
| Kegiatan/jadwal | ID, nama, deskripsi, jenis, waktu, durasi, prioritas, deadline, status, pengulangan/pengecualian. |
| Transaksi | ID, jenis, nominal rupiah, kategori, tanggal, keterangan. |
| Anggaran | Periode, batas total, batas per kategori. |
| Preferensi | Pengingat, izin AI, panjang sesi, dan gaya saran. |
| Riwayat aktivitas | Kegiatan asal, durasi rencana yang dipilih/diubah, status, draf, dan hasil tindakan; tanpa durasi aktual. |
| Draf tindakan AI | Target, jenis tindakan, isian usulan, penjelasan, dan status persetujuan. |

## Kriteria penerimaan

1. Pengguna dapat melihat ringkasan agenda dan uang pada Beranda.
2. Pengguna dapat mencatat dan mengubah jadwal kuliah yang tidak selalu tetap.
3. Saran waktu tidak bertabrakan dengan agenda, berada dalam rentang yang diminta pengguna, serta tidak diam-diam mengurangi durasi atau melewati deadline. AI meminta klarifikasi bila rentangnya belum jelas.
4. Agent dapat menjalankan CRUD agenda/transaksi setelah target dan persetujuan jelas; jalur manual tetap tersedia.
5. Pembaruan mempertahankan identitas kegiatan/transaksi yang sama.
6. Perubahan keuangan menghitung ulang ringkasan dan laporan secara konsisten.
7. Form, tinjauan, hasil, dan urungkan menggunakan data tindakan yang sama.
8. Keadaan kosong, AI gagal, penyimpanan gagal, serta nominal/durasi tidak valid memiliki umpan balik dan jalur pemulihan.
9. Draf/isian tidak hilang hanya karena pengguna membuka halaman lain atau menolak izin notifikasi; data tersimpan tetap milik akun yang benar.
10. Kalender, detail, filter, dan hasil tindakan menggunakan layar bersama tanpa kehilangan konteks pilihan pengguna.

Kriteria terperinci, fixture, dan gerbang teknis tersedia pada [rencana penerimaan](ACCEPTANCE.md); seluruh 71 frame dipetakan pada [peta layar Flutter](SCREEN-MAP.md). Hasil pengujian prototype di bawah bukan hasil pengujian Flutter, model, atau Firebase.

## Riwayat desain — catatan historis

Bagian mulai v18 dan seterusnya merekam keadaan pada waktu desain dibuat. Penyebutan data lokal, cloud ditunda, durasi aktual, atau angka frame versi lama tidak menggantikan cakupan implementasi 1.12 di atas dan spesifikasi teknis 18 Oktober 2026.

### Validasi desain v18

Audit menemukan 82 frame desain dan 82 frame prototype, 12 kelompok, tanpa tujuan navigasi hilang. Sumber desain tidak memiliki konten stack terpotong, wrapper keluar section, atau layer terkunci pada frame produk yang diperiksa. Font produk tetap Manrope dan struktur UI tetap native/editable.

Evaluasi awal 17 skenario deklarasi aksi prototype lulus: buat/ubah/hapus agenda, klarifikasi identitas, perpindahan lintas hari, urungkan, pemasukan/pengeluaran, edit/hapus transaksi, filter/reset, dan pemilihan hari pada kalender tunggal. Pemeriksaan ini mengevaluasi struktur dan deklarasi aksi Figma; bukan pengujian aplikasi Flutter atau eksekusi AI sungguhan.

Prototype transaksi/agenda masih menyimulasikan satu tindakan terakhir dari data contoh. Implementasi Flutter perlu menguji persistensi, beberapa tindakan berurutan, validasi masukan nyata, integrasi model AI, dan notifikasi pada perangkat.

Lima pemeriksaan tambahan juga lulus: waktu alternatif manual bertahan di Agenda, detail memakai waktu terpilih, perubahan kuliah dan tugas disimpan bersama, pembatalan kuliah membuka hasil yang benar, serta urungkan memulihkan pertemuan. Total 22 pemeriksaan deklarasi aksi lulus.


## Kelengkapan UI v19

Jumlah tetap 82 frame produk dan 82 frame prototype. Board aset dan komponen pendukung berada terpisah dari layar produk.

- Identitas: ikon aplikasi Ruma, monogram, foreground transparan, ikon notifikasi, serta ilustrasi dompet yang dapat diedit.
- Beranda: deadline terdekat membuka detail tugas yang sesuai; kartu mengikuti visibilitas tugas.
- Keuangan, Riwayat, dan Laporan: pemilih periode bersama. Nilai ringkasan, kategori, progress anggaran, dan ringkasan AI mengikuti periode terpilih.
- Status AI: siap, memproses, perlu klarifikasi, menunggu persetujuan, tersimpan, dan gagal. Hasil baca diberi label ringkasan siap.
- Anggaran: persentase pemakaian, sisa, progress, dan keadaan mendekati/melebihi batas. Batang progress dibatasi maksimal 100%, sedangkan teks tetap menunjukkan kelebihan.
- Form: petunjuk di dekat field utama, kesalahan nominal langsung di bawah isian, dan label menyimpan pada tombol prototype saat ditekan. Feedback ini belum merupakan proses jaringan atau validasi input bebas Flutter.

Prototype periode mencakup September, Oktober, dan November 2026. September menampilkan ringkasan historis dengan anggaran terlampaui; contoh detail transaksi dan CRUD berada pada Oktober; November menampilkan periode kosong. Data Oktober hasil tindakan terakhir tetap tersimpan saat mengganti periode. Memasuki contoh form transaksi kembali ke Oktober, sesuai tanggal contoh yang ditampilkan.

Paket aset tersedia di `output/assets/ruma-assets-v19.zip`: 40 SVG, 18 PNG launcher/notifikasi, font Manrope, lisensi, README, serta manifest. Tidak dibuat PDF baru pada revisi ini.


## Penyederhanaan pengalaman pengguna v20

Cakupan fitur tetap dipertahankan, dengan 82 frame desain dan 82 frame prototype. Delapan layar utama memakai pilihan awal yang lebih sedikit.

- Beranda menampilkan akses Asisten, ringkasan uang, deadline, dan dua agenda hari ini. Pratinjau slot kosong dikeluarkan dari Beranda; pencarian waktu tetap tersedia pada alur kegiatan.
- Form tambah/edit kegiatan menampilkan nama, deadline opsional, dan ringkasan durasi. Deskripsi, durasi, perkiraan AI, serta prioritas dibuka lewat Opsi lainnya.
- Form pemasukan/pengeluaran menampilkan nominal dan kategori. Tanggal memakai hari ini; jenis transaksi, tanggal yang dapat diubah, dan keterangan tetap ada dalam Opsi lainnya.
- Asisten utama menampilkan tiga contoh: tambah tugas, catat pengeluaran, dan lihat agenda. Klarifikasi/perubahan kegiatan tersedia melalui Contoh lainnya. Asisten keuangan menampilkan contoh pencatatan serta ringkasan; contoh edit/hapus masuk Contoh lainnya.
- Keuangan menggabungkan sisa dan progress dalam satu kartu anggaran. Riwayat dan laporan tersedia melalui tombol Riwayat & laporan.

Tombol buka-tutup bekerja di prototype pada layar yang sama. Pengaturan deadline kembali ke form tambah atau edit yang membukanya. Layar awal yang disederhanakan muat pada viewport mobile; rincian yang dibuka dapat digulir. Prototype tetap memakai data contoh, bukan input bebas atau AI sungguhan. Contoh tanggal agenda/keuangan tetap mengikuti skenario demo yang sudah ada; implementasi Flutter memakai tanggal perangkat.

PDF tetap ditunda. Spesifikasi mencatat blok disclosure; renderer lama belum menjadi implementasi Flutter untuk perilaku tersebut.


## Draf gabungan agenda dan uang — v21

Alur unggulan: **satu pesan → AI memisahkan agenda dan transaksi → satu tinjauan → Simpan semua**. Contoh: “Besok revisi laporan satu jam dan baca jurnal 30 menit. Tadi makan 18 ribu dan cetak laporan 15 ribu.” AI menyiapkan dua kegiatan dan dua pengeluaran aktual. Pengguna tidak memilih mode agenda/uang terlebih dahulu.

Tinjauan dikelompokkan menjadi Agenda dan Transaksi. Tiap kartu menampilkan nama, tanggal, serta saran waktu/durasi atau nominal/kategori. **Ubah** membuka satu form sesuai konteks; menerapkan form hanya mengubah draf. **Keluarkan** membuang item dari draf, bukan menghapus data lama. **Pulihkan semua item** mengembalikan kartu yang dikeluarkan sambil mempertahankan rincian yang sudah diedit. **Batalkan** meninggalkan draf. Satu **Simpan semua** menyimpan seluruh item yang masih ada; draf kosong tidak dapat disimpan.

Batas awal internal: maksimal tiga agenda dan tiga transaksi per pesan; prototype memakai dua agenda dan dua transaksi. Tidak perlu pemilih mode atau deretan form sebelum AI menyiapkan draf. Batas ini dapat diubah setelah pengujian.

Aturan implementasi:

- AI memeriksa jadwal terbaru, durasi, deadline, dan rentang waktu permintaan sebelum menawarkan waktu. Jadwal kuliah bisa berubah.
- Pertanyaan hanya untuk informasi penting yang belum jelas: tanggal, nominal, target, atau apakah transaksi sudah terjadi. Nilai hasil perkiraan harus terlihat sebagai saran dan bisa diedit.
- Rencana belanja masa depan tidak masuk pengeluaran aktual. Tawarkan pencatatan setelah transaksi terjadi; jangan membuat nominal palsu.
- Jika satu kegiatan tidak mendapat slot, tampilkan item tersebut sebagai belum terjadwal. Pengguna dapat memilih waktu/durasi lain atau mengeluarkannya. Jangan menyembunyikan item yang gagal dijadwalkan.
- Saat menyimpan, validasi ulang bentrokan serta nilai uang, gunakan satu transaksi penyimpanan lokal, dan cegah duplikasi akibat ketukan ulang. Kegagalan mempertahankan draf; tidak boleh sebagian tersimpan tanpa penjelasan.
- Tahap awal alur gabungan menangani penambahan. Alur ubah/hapus data lama tetap memakai tinjauan yang sudah tersedia.

**Status desain v23:** frame draf, edit dan hasil tetap native editable. Jumlah item, klarifikasi nominal, alternatif hari, pemulihan simpan serta hasil di Agenda/Keuangan tersedia sebagai simulasi nilai contoh. Prototype memakai pesan dan nilai contoh, bukan AI nyata atau ketikan bebas. Satu batch gabungan contoh memperbarui agenda, riwayat, angka Beranda/Keuangan, kategori dan laporan; simpan ulang batch yang sama tidak menggandakan pengeluaran. Simulasi satu batch ini belum menjadi ledger persisten untuk banyak batch atau kombinasi seluruh mutasi lama. Detail transaksi gabungan tersedia baca-saja; edit dilakukan pada draf sebelum persetujuan. Implementasi Flutter wajib memakai penyimpanan dan validasi atomik sungguhan.

Pengujian pengguna berikutnya: apakah empat kartu dari satu pesan mudah dipahami; apakah pengguna membedakan jadwal besok dengan uang yang sudah keluar; apakah edit satu item, keluarkan, dan satu persetujuan terasa lebih mudah daripada form terpisah. Pembeda ini masih hipotesis manfaat yang perlu diuji.


## Perampingan v22 — 72 frame

Canvas aktif dan prototype masing-masing memiliki **72 frame**, **11 kelompok**, dan **20 titik mulai**. Tiga belas frame dikeluarkan: sepuluh digabung ke layar bersama dan tiga fitur ditunda. Sign in, sign up, logout, history, personal preferences, filter riwayat, dan hapus riwayat tetap tersedia.

Yang ditunda hanya **quiet hours**, **feedback sesi**, dan **profile preview** pada revisi ini. Menyimpan profil langsung menerapkan avatar pilihan dan kembali ke Profil. Pengingat dasar dan izin notifikasi tetap ada. Penundaan cloud, suara, OCR, dan penundaan sebelumnya tetap berlaku.

Layar bersama mengikuti konteks masuk; pengguna tidak harus memilih mode lagi. Tambah/edit kegiatan memakai satu frame; tambah/ubah jadwal memakai satu frame; pemasukan/pengeluaran/edit transaksi memakai satu frame. Asisten agenda dan keuangan memakai satu tujuan navigasi dengan contoh yang sesuai konteks. Pilihan jam alternatif berubah di layar yang sama. Tinjauan agenda tunggal, transaksi tunggal, dan gabungan berbagi satu frame; detail kuliah/tugas berbagi satu frame. Hasil perkiraan durasi menyatu dengan draf.

Di Figma, konteks disusun sebagai kelompok native editable dengan binding variabel visible. Hanya satu konteks ditampilkan pada satu waktu. Kelompok konteks bukan phone frame tersembunyi yang dihitung sebagai pengurangan; tiga belas root prototype dan tiga belas wrapper layar lama benar-benar dikeluarkan dari canvas aktif. Implementasi Flutter dapat menggunakan satu form dengan data/konteks sesuai kebutuhan.

Validasi: **36 kasus deklarasi interaksi lulus**, **483 aksi navigasi diperiksa tanpa tujuan hilang**, serta tidak ditemukan wrapper bertumpuk/keluar section, konten sumber yang terpotong, atau ikon telepon yang melebar. Ini pemeriksaan deklarasi dan visual Figma, bukan pengujian aplikasi Flutter. Prototype tetap memakai data contoh, bukan input teks bebas atau AI nyata. Pada v23, batch contoh gabungan sudah terhubung ke Agenda dan Keuangan; batas simulasi dijelaskan pada bagian v23.

PDF tidak diperbarui sesuai permintaan. Versi v18 tetap disimpan.


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


## Navbar dan maskot · v26

Navbar floating putih kini tanpa teks: Beranda, Agenda, Asisten, Keuangan, Profil. Tombol Asisten di tengah memakai maskot Teman Abstrak oranye dalam lingkaran gelap. Titik oranye menunjukkan halaman aktif. Ukuran panel 342 × 64, radius 24, target setiap tab 65,2 × 48, ikon samping 22 × 22, badge tengah 48 × 48. Maskot tersedia sebagai SVG penuh, ikon wajah, dan badge; seluruhnya vector editable di Figma.

Komponen diterapkan pada lima state navbar, 14 navbar sumber dan 14 navbar prototype. Pemeriksaan geometri, label tersembunyi, dan 70 tujuan tab prototype lulus. Jumlah layar produk tetap 72. Saat implementasi Flutter, beri nama aksesibilitas pada kelima tab karena teks tidak tampil; layer label tersembunyi di Figma adalah spesifikasi, bukan implementasi screen reader. PDF tetap ditunda.


## Keseimbangan waktu dan uang · v27

Ruma adalah aplikasi pribadi untuk mengelola waktu dan uang, dibantu agent AI. Kedua bidang menjadi inti yang setara. Beranda memiliki kartu Waktu hari ini dan Uang bulan ini, masing-masing 342 × 184, serta dua tindakan setara: Tambah agenda dan Catat transaksi. Timeline lengkap tetap tersedia di Agenda. Ringkasan uang menampilkan saldo, sisa anggaran, pengeluaran bulan ini, dan kategori pengeluaran terbesar.

Asisten menampilkan empat pintasan dalam grid 2 × 2: Atur agenda, Lihat agenda, Catat transaksi, dan Cek anggaran. Contoh gabungan menghasilkan dua agenda dan dua transaksi melalui draf yang harus ditinjau. Form manual agenda dan transaksi sama-sama tersedia. Welcome dan pengantar kanvas menjelaskan kedua fungsi.

Sebelas tombol/pintasan prototype mempertahankan tindakan serta pengaturan konteks aslinya. Empat angka keuangan Beranda terikat pada variabel yang diperbarui draf gabungan. Pemeriksaan layout baru tidak menemukan overflow. Jumlah layar tetap 72 sumber dan 72 prototype; fitur lama dipertahankan. Nilai dan pesan prototype adalah contoh. Hitung ringkasan serta kategori terbesar dari data aktual saat implementasi Flutter. PDF tetap ditunda.


## PDF untuk LMS · 17 Oktober 2026

PDF desain antarmuka terbaru tersedia pada `output/pdf/ruma-desain-antarmuka-lms.pdf`: 12 halaman, seluruh 71 layar aktif, sampul dan daftar isi, serta akses prototype melalui gambar/sampul. Label Figma dan Prototype di bawah setiap frame dihapus. Ukuran sekitar 4,1 MB. Ini menggantikan status penundaan PDF pada catatan versi sebelumnya. Dokumen v18 tetap disimpan sebagai arsip.


## Revisi v31 - Ritme Harian dihapus

Halaman jam aktif, istirahat, dan jeda otomatis beserta pintasannya di Profil/Pengaturan dihapus dari desain dan prototype. Alur tanpa akun dan persetujuan awal langsung ke Beranda. Pengelolaan jadwal kuliah, pengulangan, pembatalan pertemuan, serta pemilih tanggal/jam dipertahankan. Bagian Jadwal kuliah berisi empat layar. Semua referensi aktif terhadap pengaturan ritme sudah dihapus dan tujuan prototype diperiksa. Total terbaru 71 layar; angka pada catatan versi sebelumnya merupakan kondisi historis. PDF v31 diperbarui menjadi 12 halaman tanpa label Figma/Prototype di bawah setiap frame.
