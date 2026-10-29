# Rancangan Asisten percakapan dan impor jadwal

Rancangan 26 Oktober 2026. Implementasi lokal dimulai 27 Oktober 2026 pada Flutter, Worker v2, dan Rules. Status pengujian dan batas aktual dicatat terpisah dalam [laporan implementasi](ASSISTANT-CHAT-IMPORT-IMPLEMENTATION.md); rancangan di bawah tetap menjadi acuan, bukan bukti deployment produksi. Keputusan pengguna: Asisten tetap pusat perhatian navbar; pengalaman berbentuk chatbot dengan kemampuan agent; gambar LMS menjadi jadwal **berulang mingguan selama semester**. Sumber tambahan yang diminta: Google Calendar. Rekomendasi untuk MVP adalah impor satu arah Google Calendar → Ruma dengan pembaruan manual dan tinjauan.

## Tujuan dan batas MVP

Mahasiswa dapat berbicara dengan bahasa sehari-hari, melanjutkan jawaban singkat, dan mengirim screenshot jadwal tanpa memahami format draf internal. Percakapan berjalan terus; tindakan yang akan mengubah data muncul sebagai kartu tinjauan di dalam percakapan.

Keberhasilan utama: dari gambar jadwal, pengguna memperoleh seri kuliah dengan mata kuliah, hari, jam, serta periode yang benar setelah satu persetujuan yang jelas. Koreksi seperti “Basis Data pindah Kamis jam 10” memperbarui usulan yang sama. Tidak ada penulisan agenda sebelum persetujuan.

MVP mencakup chat berkonteks, pertanyaan lanjutan, baca agenda/uang melalui tool, koreksi usulan lewat chat, impor screenshot/foto jadwal semester, serta impor Google Calendar satu arah. PDF, sinkronisasi dua arah Google Calendar, pembaruan kalender otomatis di latar, sinkronisasi akun LMS, pengambilan data melalui login LMS, impor otomatis kalender akademik/libur, OCR tulisan tangan yang dijamin akurat, suara, dan eksekusi tugas latar tanpa pengguna ditunda.

Batas yang diusulkan: tiga gambar JPG/PNG per impor, maksimal 3 MB setelah pemrosesan per gambar dan 8 MB total; rancangan awal maksimal 20 pola pertemuan mingguan berbeda per impor. **Hasil implementasi: maksimal 8 perubahan per persetujuan atomik**, berdasarkan pengujian batas ekspresi dan akses Firestore Rules. Pengguna dapat mengeluarkan baris lalu meninjau sisanya pada persetujuan berikutnya. Satu mata kuliah yang bertemu Senin dan Rabu menjadi dua pola. Batas ini adalah rancangan awal yang harus divalidasi dengan sampel nyata dan kuota provider, bukan kemampuan APK saat ini.

## Struktur pengalaman

- Satu halaman Asisten: app bar “Asisten”, percakapan berurutan, kartu tindakan, dan composer di bawah. Riwayat tidak disembunyikan sebagai bagian lipat yang terpisah dari percakapan aktif.
- Composer menerima teks dan lampiran gambar; menu “Impor jadwal” menyediakan Gambar dan Google Calendar. Agenda juga dapat menyediakan pintasan menuju alur impor yang sama. Teks tetap dapat dikirim ketika ada usulan yang belum disetujui. Saat keyboard muncul, composer mengikuti IME dan navbar memberi ruang sesuai pola app saat ini.
- Pesan pengguna memakai permukaan peach yang tenang; jawaban Asisten berupa teks yang mudah dipindai. Kartu jadwal/tindakan memakai putih atau sage. Oranye untuk Kirim dan aksi persetujuan utama. Status perlu rincian/bentrok selalu menyertakan teks/ikon.
- Manrope, margin 24 dp, kartu dan ikon Ruma dipertahankan. Maskot besar di tengah navbar tetap menjadi penekanan fitur MVP.
- Android kompak memakai daftar per hari, bukan tabel tujuh kolom yang diperkecil. Rincian satu jadwal dapat dibuka; screenshot sumber dapat diperbesar untuk memeriksa baris terkait.

## Percakapan yang harus bekerja

| Pengguna | Respons/perilaku yang dirancang |
| --- | --- |
| “Halo” | Jawaban percakapan biasa; tidak diarahkan ke status transaksi. |
| “Besok belajar satu jam” | Menyiapkan agenda atau menanyakan jam yang diperlukan; tidak meminta pengguna menulis ulang seluruh permintaan. |
| “Jam 10 aja” | Melengkapi kegiatan yang sedang dibahas. |
| “Ganti jadi jam 11” | Mengubah revisi usulan aktif; tombol persetujuan lama tidak berlaku lagi. |
| “Tadi makan 18 ribu” | Menyiapkan transaksi aktual untuk ditinjau. |
| “Aku mau beli buku” | Menanyakan maksud yang relevan; rencana tidak dianggap pengeluaran aktual. |
| “Apa agenda saya besok?” | Menjalankan pembacaan terautentikasi dan menampilkan hasil hitungan/data aplikasi. |
| “Pindahkan kelas yang tadi” | Menggunakan referensi percakapan/usulan; jika lebih dari satu kelas, tampilkan pilihan yang relevan. |
| “Terima kasih” ketika ada usulan | Membalas tanpa menghapus usulan atau menganggapnya sebagai persetujuan simpan. |

Jika pesan baru berisi tugas lain sementara satu usulan masih aktif, AI boleh membahasnya dan menanyakan apakah ingin mengganti/menggabungkan usulan. MVP menyimpan satu usulan tindakan aktif; tidak membuang usulan lama diam-diam. Tindakan yang sudah tersimpan dibahas melalui usulan perubahan baru.

## Impor gambar: alur utama

1. **Pilih gambar.** Tombol lampiran membuka pemilih gambar Android; hanya gambar pilihan pengguna yang diakses. Tampilkan thumbnail, jumlah lampiran, hapus/ganti, dan pesan pendamping opsional. MVP tidak menyimpan file gambar di cloud. Izin pemrosesan gambar diminta sebelum pengiriman pertama.
2. **Baca jadwal.** UI menampilkan status “Membaca jadwal…” yang dapat dibatalkan. Gambar dianalisis menjadi kandidat baris, bukan langsung ditulis menjadi agenda. Tidak mengaku sukses jika provider belum menjawab.
3. **Lengkapi bagian penting.** Jika baris buram atau satu gambar berisi beberapa kelas/paralel, tanyakan bagian yang tepat dengan pilihan. Tanyakan awal/akhir semester jika tidak ada. Jawaban tanggal dan jam dapat diberikan melalui chat atau picker. Pertanyaan fokus pada informasi yang belum diketahui; jawaban sebelumnya tetap tersimpan.
4. **Tinjau pertemuan mingguan.** Tampilkan periode, zona waktu, jumlah pola jadwal, baris per hari, serta penanda bagian yang dibetulkan pengguna. Perubahan tanggal/hari/jam dan pengeluaran item dapat dilakukan lewat chat maupun form.
5. **Periksa duplikasi dan bentrokan.** Aplikasi membandingkan kandidat dengan agenda terbaru dan antar kandidat. Baris yang identik sudah ada ditandai; baris yang bentrok memerlukan penyelesaian atau pengeluaran eksplisit dari pilihan. Jadwal resmi LMS tidak dipindahkan otomatis untuk mencari slot kosong.
6. **Setujui dan simpan.** Tombol menyebut dampak, misalnya “Tambahkan 4 jadwal mingguan”. Seluruh item terpilih yang valid disimpan sebagai satu operasi idempoten. Item yang dikeluarkan dan duplikat terlihat dalam ringkasan; tidak ada pemilihan subset tersembunyi.
7. **Hasil terverifikasi.** Setelah receipt terkonfirmasi, tampilkan “4 jadwal mingguan ditambahkan”, periode, item yang dilewati, serta “Lihat Agenda”. Percakapan tetap terbuka. Klaim simpan berasal dari status repository, bukan teks model.

### Data yang diekstrak

| Data | Aturan |
| --- | --- |
| Nama mata kuliah | Wajib; jangan mengarang nama yang tidak terbaca. |
| Hari | Wajib untuk setiap pertemuan mingguan. |
| Jam mulai dan selesai | Wajib; hitung durasi dari keduanya dan periksa rentang valid. Nilai ambigu ditanyakan. |
| Ruang, kelas/paralel, dosen | Opsional; pertahankan jika terbaca, tidak menghalangi impor bila kosong. MVP dapat memetakannya ke catatan agenda. |
| Awal dan akhir semester | Wajib dikonfirmasi untuk impor; akhir bersifat inklusif. Jangan mengasumsikan nama semester sebagai rentang tanggal. |
| Zona waktu | Gunakan Asia/Jakarta/WIB sesuai app saat ini dan tampilkan jelas. Bila sumber menyatakan WITA/WIT, minta penyesuaian yang eksplisit; jangan menyalin jamnya sebagai WIB. Konversi multi-zona di luar scope MVP ini. |
| Asal baris | Identitas lampiran dan lokasi baris/crop untuk membantu pengguna memverifikasi sumber. Ini bukan bukti bahwa OCR pasti benar. |

Tidak memakai persentase keyakinan rekaan. Status berbasis masalah yang ditemukan: “Terbaca”, “Perlu konfirmasi jam”, “Nama belum terbaca”, “Sudah ada”, “Bentrok”, “Dikeluarkan”.

### Contoh sintetis untuk rancangan

Periode contoh: 26 Oktober–18 Desember 2026, WIB. Empat pola: Algoritma (Senin 08.00–09.40), Basis Data (Selasa 10.00–11.40), Interaksi Manusia Komputer (Kamis 08.00–09.40), dan Pemrograman Berorientasi Objek (Jumat 13.00–14.40). Data ini untuk simulasi, bukan jadwal pengguna.

Periode itu menghasilkan delapan pertemuan untuk masing-masing pola. UI utama menekankan empat jadwal mingguan; pertemuan muncul mengikuti minggu di Agenda. Pertemuan pertama dihitung sebagai kemunculan hari yang cocok pada/selepas awal periode; tidak semuanya dimulai pada tanggal pertama semester.

## Impor Google Calendar

### Pilihan arah untuk MVP

**Rekomendasi: Google Calendar → Ruma.** Pengguna mengambil salinan jadwal melalui tindakan impor/perbarui. Google tetap menjadi sumber untuk jadwal eksternal; Ruma menampilkannya bersama agenda lokal dan membantu mendeteksi bentrokan. Perubahan lokal tetap milik Ruma. Tidak meminta izin menulis ke Google pada MVP.

| Pilihan | Nilai utama | Konsekuensi |
| --- | --- | --- |
| Impor satu arah, pembaruan manual | Memasukkan jadwal yang sudah tersedia dengan akses baca saja. | Perubahan sumber masuk setelah pengguna menekan Periksa pembaruan dan menyetujui hasilnya. |
| Sinkronisasi dua arah | Edit di Ruma juga dapat mengubah jadwal di Google. | Memerlukan izin tulis, resolusi perubahan bersamaan, penghapusan, undangan/peserta, dan kegagalan sebagian. Ditunda sampai kebutuhan edit Google dari Ruma terbukti. |

Pilihan pertama adalah rekomendasi desain, belum konfigurasi produksi atau integrasi yang sudah berjalan. UI memakai istilah **Impor** dan **Periksa pembaruan** agar tidak menjanjikan sinkronisasi otomatis.

### Alur pengguna

1. Pengguna memilih “Google Calendar” pada menu impor atau meminta “Ambil jadwal kuliah saya dari Google Calendar”.
2. Jika belum ada izin, tampilkan penjelasan singkat akses baca lalu alur otorisasi Google. Pengguna memilih akun; akun Google untuk kalender boleh berbeda dari email masuk Ruma. Otorisasi ini tidak mengganti UID Firebase, menautkan akun Ruma secara otomatis, atau melakukan logout.
3. Tampilkan kalender yang dapat dibaca dan biarkan pengguna memilih satu kalender, misalnya “Kuliah”, lalu periode semester/tanggal. Kalender lain tidak otomatis dibaca isinya. Tampilkan akun sumber dan periode yang dipilih.
4. Ambil data jadwal melalui API, lalu tampilkan pratinjau terurut dan jumlah: baru, sudah ada, berubah, bentrok, dan perlu rincian. Data Calendar sudah terstruktur sehingga ekstraksi dasar tidak memerlukan panggilan model.
5. Gunakan tinjauan serta persetujuan yang sama dengan impor gambar. Label asal “Google Calendar · Kuliah” tetap terlihat. Jenis Kuliah/Agenda mengikuti tujuan impor yang dipilih pengguna dan dapat dikoreksi; tidak semua acara Google dianggap kuliah.
6. Setelah commit terkonfirmasi, jadwal muncul di Agenda. Detail menampilkan sumber, waktu pemeriksaan terakhir, “Periksa pembaruan”, serta “Buka sumber” jika tautan tersedia.

Teks saat menyunting: **“Perubahan ini hanya berlaku di Ruma.”** Teks hasil impor: **“Jadwal disalin ke Ruma. Pembaruan Google dapat diperiksa lagi.”** Edit/hapus di Ruma tidak mengubah event Google.

### Pembaruan, konflik, dan duplikasi

- Impor ulang membandingkan identitas sumber dan versi tersimpan, bukan membuat agenda baru berdasarkan judul. Gunakan referensi akun sumber, calendarId, eventId; pada occurrence seri, simpan juga recurringEventId dan originalStartTime. Waktu asli occurrence tetap menjadi referensi ketika pertemuannya dipindah.
- Jika Google berubah dan salinan Ruma belum diedit, tampilkan perubahan sebelum/sesudah untuk disetujui. Jika keduanya berubah, tawarkan **Pertahankan versi Ruma** atau **Gunakan versi Google** per item. Jangan menimpa edit lokal diam-diam.
- Jika pengguna menghapus salinan di Ruma, simpan penanda pengecualian impor agar pembaruan berikutnya tidak langsung membuatnya kembali. “Impor kembali” menjadi tindakan eksplisit.
- Pembatalan/penghapusan sumber ditampilkan sebagai usulan perubahan status/hapus di Ruma dengan konfirmasi. Kalender yang kosong karena hak akses hilang atau pembacaan gagal tidak dianggap sebagai penghapusan seluruh event.
- Jika jadwal yang sama sudah dibuat dari gambar LMS, deteksi kesamaan isi dan minta konfirmasi untuk memakai/menautkan catatan yang ada. Identitas Google saja tidak cukup untuk mendeteksi duplikasi lintas sumber.
- Melepas akses Google menghentikan pembacaan berikutnya. Salinan yang sudah disetujui tetap berada di Ruma; penghapusan salinan merupakan pilihan terpisah.

### Pemetaan data dan batas kompatibilitas

- Pratinjau mengambil semua halaman hasil pada rentang yang dipilih. Google menyediakan ekspansi recurring events menjadi occurrence melalui `singleEvents`; importer harus memperhitungkan pertemuan yang dipindah/dibatalkan. Jangan berhenti pada halaman pertama atau menyamakan jumlah baris pratinjau dengan jumlah seri. [Events.list](https://developers.google.com/workspace/calendar/api/v3/reference/events/list), [Recurring events](https://developers.google.com/workspace/calendar/api/guides/recurringevents).
- Seri mingguan yang dapat diwakili secara tepat dipetakan ke recurrence Ruma, termasuk pengecualian yang relevan dalam periode. Jangan memaksa pola harian, bulanan, dua mingguan, atau perubahan DST menjadi mingguan biasa. Untuk pola yang belum dapat dipetakan, tampilkan pilihan mengimpor occurrence bertanggal dalam periode terpilih; jika melebihi kapasitas commit yang teruji, pengguna memilih subset/periode secara eksplisit. Tidak ada pemotongan tersembunyi.
- Event berjam memakai instant dan offset/zona sumber lalu ditampilkan dalam WIB; label harus menunjukkan hasil konversi yang benar. Seri yang bergeser dalam WIB akibat DST memakai occurrence bertanggal jika pola mingguan Ruma tidak dapat merepresentasikannya.
- Event sepanjang hari tidak diberi jam karangan. Tampilkan sebagai perlu keputusan: pilih jam untuk membuat agenda berwaktu atau keluarkan dari impor. Rentang akhir event Google bersifat eksklusif; jangan menambah satu hari pada acara sepanjang hari. Ini memerlukan pemetaan tersendiri karena app belum memiliki event all-day. [Calendars and events](https://developers.google.com/workspace/calendar/api/concepts/events-calendars), [Event resource](https://developers.google.com/workspace/calendar/api/v3/reference/events).
- Daftar undangan/peserta, email, lampiran, dan rincian pertemuan daring tidak diperlukan untuk impor jadwal dasar. Ambil field minimum. Kalender tanpa hak membaca rincian tidak diisi dengan judul hasil tebakan.

### Otentikasi, data, dan gerbang implementasi

Minta akses ketika pengguna memilih impor, terpisah dari proses masuk Ruma. Gunakan otorisasi Google untuk pengguna; service account backend Ruma tidak mewakili izin kalender pribadi. Pedoman Android memisahkan autentikasi dan otorisasi: [Authorize access to Google user data](https://developer.android.com/identity/authorization).

Scope rancangan minimum: `calendar.calendarlist.readonly` untuk pemilihan kalender dan `calendar.events.readonly` untuk pembacaan event. Tidak meminta scope penulisan `calendar.events` atau akses penuh `calendar`. Kemampuan scope dan kebutuhan proses verifikasi aplikasi publik perlu diperiksa saat konfigurasi OAuth: [Calendar API scopes](https://developers.google.com/workspace/calendar/api/auth), [CalendarList.list](https://developers.google.com/workspace/calendar/api/v3/reference/calendarList/list).

Token otorisasi bukan bagian dari pesan, draf, log, model context, atau dokumen Firestore biasa. MVP tidak memerlukan job latar/server yang menyimpan refresh token: pembacaan dilakukan saat pengguna menjalankan impor/periksa pembaruan melalui otorisasi Android yang sesuai. Menolak atau mencabut izin tetap menyisakan chat, impor gambar, dan agenda manual yang dapat dipakai.

AI membantu memilih tindakan dan mengoreksi usulan setelah impor. Seluruh isi kalender tidak otomatis dikirim ke provider AI. Gunakan tinjauan deterministik dari API; jika pengguna meminta AI membahas data tertentu, kirim hanya konteks item yang diperlukan sesuai persetujuan pemrosesan yang telah dijelaskan.

Implementasi memerlukan adapter Calendar, provenance/versi sumber, UI otorisasi/pemilih kalender, serta repository impor yang sudah dirancang. Adapter Google Calendar dan otorisasi Android telah ditambahkan dalam implementasi lokal; otorisasi akun Google nyata masih memerlukan verifikasi konfigurasi OAuth. Prototype pendamping saat ini hanya mendemonstrasikan chat dan gambar LMS; OAuth serta Calendar belum disimulasikan di sana.

## Koreksi dan perubahan seri

- Sebelum simpan: “Basis Data pindah Kamis jam 10” mengubah baris kandidat, menjalankan ulang pemeriksaan bentrokan, dan menaikkan revisi usulan. Tidak perlu meninggalkan chat atau menulis ulang seluruh jadwal.
- Setelah simpan: referensi kelas diselesaikan terhadap data milik akun aktif. Tanyakan cakupan bila ambigu: **Pertemuan ini**, **Mulai minggu ini/yang dipilih**, atau **Seluruh seri**. Ringkasan memperlihatkan tanggal konkret yang terdampak.
- Nama kelas yang mirip menghasilkan pilihan kandidat; pengguna memilih baris. ID dokumen tidak perlu diketik, dan model tidak boleh memilih UID/path database.
- Jika ada dua pertemuan mata kuliah yang sama, ubah hanya pertemuan yang dimaksud; tanyakan hari/paralel jika belum jelas.
- Perubahan pada jadwal tersimpan tetap memakai tinjauan sebelum/sesudah serta pemeriksaan versi. Dukungan cakupan seri harus dihubungkan ke operasi recurrence yang sudah ada; tool AI saat ini belum mendukung seluruh cakupan ini.

## Keadaan penting dan pemulihan

| Keadaan | UI / tindakan |
| --- | --- |
| Gambar belum dikirim | Thumbnail dapat dibuka, diganti, atau dihapus; tidak ada request provider. |
| Gambar buram/tidak lengkap | Tunjukkan bagian yang perlu diperjelas; pertahankan baris lain. Tawarkan unggah ulang/crop atau isi lewat chat. |
| Gambar bukan jadwal | Jelaskan bahwa jadwal belum ditemukan; percakapan tetap bisa dilanjutkan. |
| Periode belum lengkap | Tanyakan tanggal yang kurang; jangan menyimpan seri tanpa akhir secara diam-diam. |
| Jadwal identik sudah ada | Tandai “Sudah ada”, default tidak dibuat ulang; pengguna melihat jumlah baru dan yang dilewati. |
| Kandidat mirip tetapi berbeda | Tampilkan perbedaan dan pilihan; jangan menyatukan atau menimpa otomatis. |
| Bentrok | Tampilkan jadwal dan tanggal konflik yang konkret. Pengguna membetulkan data, mengeluarkan baris, atau menyiapkan perubahan agenda lama dengan persetujuan tersendiri. |
| Batas gambar/baris | Jelaskan jumlah yang terbaca dan batas yang berlaku; pertahankan hasil sebagai tinjauan dan minta pemilihan/pemisahan yang jelas. |
| Provider gagal/kuota habis | Pesan dan hasil lokal dipertahankan; retry dilakukan pengguna. Input manual tetap tersedia. |
| Offline | Percakapan/draf yang sudah termuat tetap dapat dibaca/disunting; pengiriman dan commit menunggu koneksi serta tindakan pengguna. Tidak ada auto-commit. |
| Menutup app saat gambar belum diproses | Simpan referensi lokal privat sementara; jika file tidak tersedia lagi, minta lampirkan ulang. Teks hasil ekstraksi yang sudah tersimpan tidak hilang bersama file. |
| Gagal baca status commit | Tampilkan “Memeriksa hasil penyimpanan”. Periksa receipt dengan operationId yang sama; jangan membuat usulan baru untuk retry operasi itu. Chat nonmutasi tetap tersedia. |
| Agenda berubah sebelum simpan | Muat ulang dan periksa bentrokan/versi. Tampilkan dampak baru dan minta persetujuan untuk revisi terbaru. |
| Sesi/akun berubah | Hentikan pengiriman/hasil lama, bersihkan file sementara serta state lintas akun. Usulan tidak dibawa ke akun lain. |

Pada semua keadaan, keyboard, error, atau thumbnail tidak boleh menutupi composer maupun tindakan pemulihan. Target sentuh minimal 48 dp, teks dapat diperbesar, dan penanda status menyertakan label untuk TalkBack.

## Rancangan teknis

### Percakapan dan status tindakan

Pisahkan pesan percakapan dari state usulan tindakan. Respons terstruktur memiliki empat jenis konseptual: jawaban biasa, pertanyaan klarifikasi, permintaan baca, dan usulan tindakan. Ini pengganti kontrak respons saat ini yang terlalu memaksa setiap jawaban menuju draf/tool.

Usulan memiliki ID, revisi, provenance, item terpilih, dan status: diusulkan, perlu rincian, siap, sedang disimpan, hasil belum pasti, tersimpan, dibatalkan, atau digantikan revisi baru. Hanya usulan siap dengan revisi yang sama yang dapat disetujui. Tombol pada pesan historis tidak dapat menyetujui revisi lama.

Untuk MVP, kirim konteks thread aktif yang dibatasi: usulan aktif dan maksimal delapan giliran dialog terakhir, dengan anggaran awal 12.000 karakter teks. Ketika batas tercapai, pertahankan state usulan dan klarifikasi terbuka; buang giliran lama secara deterministik. Ini batas rancangan yang perlu diuji, bukan batas permanen produk.

Percakapan model dan blok hasil baca aplikasi harus dibedakan. Jangan otomatis mengirim seluruh ledger atau blok hasil hitungan ke provider ketika membangun konteks. Tindak lanjut pada daftar catatan memakai referensi item terpilih dan data minimum yang disetujui pengguna. Semua resolusi target, hak akses, perhitungan uang, dan pemeriksaan versi tetap dilakukan aplikasi/repository. Persetujuan AI perlu diperbarui karena kontrak saat ini menjelaskan pengiriman satu pesan saja.

### Pembacaan gambar

- Jalur gambar menghasilkan kandidat jadwal terstruktur plus referensi sumber. Hasil OCR/vision diperlakukan sebagai input tidak tepercaya dan tidak dapat memanggil commit.
- App memvalidasi jenis file melalui decoding, ukuran/dimensi, orientasi, dan keterbacaan pratinjau. Pengguna dapat memotong bagian identitas yang tidak diperlukan; metadata lokasi dibuang sebelum pengiriman. Hindari kompresi yang membuat jam/huruf tidak terbaca.
- Gambar dikirim melalui endpoint terautentikasi sebagai lampiran biner dengan batas request tersendiri. Jangan memasukkan base64 ke payload percakapan Firestore atau memperbesar endpoint teks tanpa batas.
- Usulan arsitektur: satu pemrosesan vision saat gambar dikirim, kemudian chat teks memakai hasil ekstraksi dan koreksi; tidak mengirim ulang gambar pada setiap jawaban singkat. Pemeriksaan ulang gambar hanya melalui tindakan eksplisit pengguna.
- Gambar tidak disimpan sebagai objek cloud pada MVP; file sementara privat dihapus setelah selesai/dibatalkan atau maksimal 24 jam. Provider tetap menerima isi gambar yang dikirim. Kebijakan retensi provider harus diverifikasi dan dijelaskan sebelum peluncuran; tidak menjanjikan penghapusan di provider tanpa bukti.
- Model backend saat ini bernama `glm-5.3-flash` pada source. **Kemampuan gambar pada route NaraRouter tersebut belum diverifikasi.** Gerbang pertama implementasi adalah membuktikan dukungan vision dan keluaran terstruktur dengan fixture sintetis. Bila perlu model terpisah untuk vision, putuskan berdasarkan bukti, biaya, dan batas provider; jangan menganggap model teks saat ini pasti mendukung gambar.

### Penyimpanan seri dan konsistensi

Simpan satu seri `kind: class` per pola pertemuan memakai recurrence mingguan yang sudah ada; jangan membuat ratusan dokumen kegiatan satu kali. Nama ruang/dosen dapat masuk description pada MVP. Tanggal origin adalah pertemuan pertama yang sesuai hari; untilLocalDate adalah akhir semester.

Pemeriksaan bentrokan perlu mencakup seluruh periode terpilih, antar kandidat dan terhadap seri/pengecualian yang sudah ada. Fungsi ekspansi saat ini membatasi satu rentang sampai 90 hari; pemeriksa semester harus memakai potongan rentang yang valid dan menangani batas antar potongan, bukan memanggilnya untuk semester panjang sekaligus atau diam-diam memeriksa minggu pertama saja.

Commit impor memerlukan jalur batch khusus, receipt, dan Rules yang mengikat seluruh item terpilih. Batas draf gabungan lama tiga agenda tidak cocok untuk jadwal satu semester. Jangan memecah menjadi batch tiga item yang menulis sebagian tanpa status dan persetujuan yang jelas. Bila batch atomik yang dirancang belum lulus Rules/batas pembacaan, fitur belum dianggap siap.

Dedup memakai identitas isi (mata kuliah/paralel, hari, jam, periode) dan catatan yang sudah tersimpan; hash gambar hanya membantu mengenali lampiran yang sama. Retry usulan yang sama memakai ID operasi yang sama; impor ulang dalam sesi baru tetap harus mendeteksi isi yang sudah ada. Uji kedua kasus tersebut secara terpisah.

### Gap konkret pada kode saat ini

| Area | Saat ini | Perubahan yang diperlukan |
| --- | --- | --- |
| `lib/data/assistant_service.dart` | Satu pesan teks; satu request/conversation/turn ID; respons allowlist tanpa chat biasa. | ID percakapan stabil, konteks terbatas, jawaban biasa, dan jalur lampiran. |
| `backend/src/worker.mjs` | Validator menerima tepat satu pesan; body dibatasi 64 KiB. | Kontrak chat berkonteks yang tervalidasi serta endpoint gambar dengan batas terpisah. |
| `backend/src/agent.mjs` | SourceQuote harus ada di pesan terbaru; setiap kalimat perlu terwakili; jawaban tanpa tool menjadi klarifikasi transaksi. | Tool routing yang mendukung chat dan klarifikasi spesifik; provenance dari giliran/sumber yang benar, termasuk gambar. Jangan sekadar menghapus validasi kutipan. |
| `backend/src/record-tools.mjs` | Target perubahan memakai nama persis dari pengguna. | Resolusi referensi usulan/item pilihan; target ambigu ditawarkan sebagai pilihan. |
| `lib/data/assistant_store.dart` | Usulan belum diterapkan memblokir send. | Pisahkan lifecycle chat dan usulan; revisi draf tidak mengunci percakapan biasa. |
| `lib/data/assistant_snapshot.dart` | Workspace schema 1, sepuluh pasangan message/reply; pemulihan agenda tidak membawa recurrence. | Migrasi berversi untuk thread, klarifikasi, provenance, revisi usulan, serta recurrence; baca state lama tanpa menimpa data gagal decode. |
| `lib/data/draft_repository.dart` | Commit agenda AI secara eksplisit menulis recurrence `none`. | Repository impor seri; payload/receipt/Rules yang mempertahankan pola mingguan. |
| `lib/data/recurrence.dart` | Pola mingguan, perubahan/pengecualian dan ekspansi tersedia. | Pakai ulang; verifikasi rentang semester dan operasi cakupan melalui AI. |

Konfigurasi repo saat ini menetapkan kuota global AI 10/hari. Alur banyak klarifikasi dan pengujian gambar akan memakai kuota lebih cepat; hitung request teks dan gambar serta biaya nyata sebelum pilot. Rancangan ini tidak mengubah kuota, model produksi, atau billing.

## Tahapan implementasi dan bukti kelulusan

1. **Percakapan inti.** Tambahkan jawaban biasa, satu pertanyaan lanjutan yang spesifik, konteks thread, serta koreksi usulan lewat chat. Buktikan sapaan tidak menjadi transaksi, “jam 10 aja” mempertahankan kegiatan, dan tidak ada commit sebelum persetujuan.
2. **Pembuktian gambar.** Fixture sintetis dengan tabel, grid, foto miring, crop, teks buram, dan dua paralel. Verifikasi provider/format, waktu respons, ukuran, biaya, serta minimisasi data. Hasil belum menulis agenda.
3. **Tinjauan dan impor seri.** Lengkapi periode semester, validasi, duplikat, konflik lintas minggu, serta commit atomik/idempoten dengan Rules lokal. Uji jadwal lebih dari tiga dan periode lebih dari 90 hari.
4. **Sambungkan UI Android.** Picker, preview, chat, kartu usulan, bentuk ringkas per hari, pembesaran sumber, serta pemulihan. Uji HP kompak, teks 200%, keyboard, dan TalkBack.
5. **Pilot pengguna.** Tiga sampai lima mahasiswa mengirim jadwal milik sendiri dengan persetujuan pemrosesan. Amati penyelesaian impor, koreksi lewat chat, dan pemahaman bahwa jadwal belum tersimpan sebelum persetujuan. Keberhasilan tidak dinilai dari model saja.

Jalur Google Calendar menggunakan fondasi tinjauan/impor seri yang sama: setelah fondasi tersebut siap, uji otorisasi baca, pemilih kalender/periode, adapter API, provenance, dan pemeriksaan pembaruan manual. Calendar tidak bergantung pada keberhasilan pembuktian model vision.

Kasus wajib tambahan: jadwal lintas akhir bulan; jam 07.00 tidak tertukar dengan 17.00; pertemuan hari Senin tidak dibuat pada hari awal periode yang berbeda; dua hari untuk mata kuliah sama; gambar dengan instruksi palsu tidak menjadi instruksi sistem; retry sesudah putus koneksi; impor ulang gambar berbeda berisi jadwal sama; pergantian akun ketika vision berjalan; serta state lama yang masih dapat dibaca setelah upgrade.

Kasus Calendar: pembatalan izin; akun Calendar berbeda dari akun Ruma tanpa perubahan UID; beberapa kalender dan pagination; satu occurrence dipindah/dibatalkan; all-day dengan akhir eksklusif; perbedaan zona/DST; impor ulang tanpa duplikasi; edit lokal bersamaan dengan edit Google; salinan dihapus lokal lalu periksa pembaruan; kehilangan izin tidak menghapus data; serta kesamaan jadwal antara gambar dan Calendar.

## Keputusan yang tetap terbuka

- Provider/model vision yang terverifikasi dan biaya/batas riilnya.
- Dukungan gambar lebih dari batas awal dan PDF setelah bukti penggunaan.
- Kebijakan kalender akademik/libur dan zona waktu selain WIB.
- Anggaran kuota untuk pilot; perubahan nilai produksi memerlukan tindakan tersendiri.
- Kapasitas atomik importer untuk occurrence Calendar yang tidak cocok dengan pola mingguan Ruma, serta kesiapan OAuth untuk distribusi publik. Sinkronisasi dua arah tetap di luar rekomendasi MVP ini.

Prototype pendamping memakai data sintetis dan respons yang diskenariokan untuk memperlihatkan interaksi. Prototype tidak membaca gambar sungguhan, menjalankan model, atau menyimpan data ke Ruma. Ia bukan bukti bahwa fitur sudah tersedia pada APK.
