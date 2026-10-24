# Ruma — push notification dan pengingat

> 20 Oktober 2026: pengingat dasar, Rules, indeks dan cron produksi sudah aktif. FCM foreground, background/tap dan proses berhenti/cold tap terbukti di AVD; lihat [NOTIFICATION-IMPLEMENTATION.md](NOTIFICATION-IMPLEMENTATION.md) untuk status aktual, bukti dan batas implementasi. Bagian di bawah adalah rancangan lengkap termasuk kemampuan lanjutan.

18 Oktober 2026 · rancangan; belum ada token perangkat, Worker pengirim FCM, cron, atau pengiriman FCM yang dibuat. Proxy AI terpisah sudah terdeploy; hasilnya ada di qa/CLOUD-INTEGRATION.md. Push notification adalah fitur aktif, bukan digantikan notifikasi lokal.

## Perilaku versi awal

**FCM menjadi jalur utama pengingat terjadwal dari server.** Notifikasi lokal dipakai untuk menampilkan pesan FCM ketika aplikasi terbuka dan untuk **Ingatkan 5 menit lagi** di perangkat yang memilihnya. Tidak menjadwalkan salinan lokal otomatis untuk peristiwa utama yang sama; ini mencegah dua jalur berbeda membunyikan pengingat yang sama.

Default awal pengingat adalah nonaktif sampai pengguna mengizinkan dan memilihnya; form menyarankan 10 menit sebelum waktu acuan dan pengguna dapat mengubahnya. Acuan: waktu mulai bila agenda terjadwal, atau deadline bila tugas belum terjadwal. Tugas tanpa keduanya tidak mempunyai waktu pengingat dan meminta pengguna mengisi waktu terlebih dahulu. Satu agenda tidak otomatis mengirim pengingat mulai sekaligus deadline. Pilihan ini mengurangi gangguan tanpa mengurangi kemampuan FCM.

Jam tenang, pengingat saldo/anggaran otomatis, pengingat mencatat uang harian, broadcast promosi, dan AI yang berjalan sendiri di latar belakang tidak ditambahkan. Batas anggaran tetap terlihat di aplikasi. Push awal berfokus pada agenda/deadline yang sudah ada pada rancangan.

Menunda pengingat memakai notifikasi lokal lima menit setelah tindakan, tidak menggeser agenda, tidak mengaktifkan ulang job FCM yang sudah selesai, dan tidak membuat agenda baru. Perubahan/penghapusan agenda membatalkan snooze yang masih terkait. Setelah perangkat restart, rekonsiliasi pengingat lokal hanya yang masih valid.

## Identitas peristiwa

Kunci pengingat stabil mengacu pada agenda atau seri. Field `generation` meningkat setiap kali jadwal/aturan pengingat diubah. `occurrenceKey` untuk kelas memakai ID seri dan tanggal asal, sehingga pemindahan tanggal tidak membuat dua pertemuan.

`notificationId` adalah hash stabil dari UID, agenda/seri, occurrence key, dan generation. Gunakan ID itu pada inbox, data payload, serta Android notification tag. Retry tidak membuat baris inbox baru. Android dapat mengganti kartu dengan tag yang sama; ini tidak menjamin banner/suara tidak pernah berulang bila jaringan gagal pada saat yang tidak diketahui.

Job antrean berada di `users/{uid}/reminders/{reminderId}` dengan field tujuan dari spesifikasi data, ditambah `availableAtUtc`. Awalnya availableAt = dueAt. Saat leased, availableAt = leaseUntil; saat retry, availableAt = waktu retry. Status aktif `queued` atau `leased`; terminal `sent`, `cancelled`, `expired`, atau `failed`. Worker sendiri menulis field dispatch: lease ID, leaseUntil, attempts, lastError, lastSentOccurrenceKey, dan hasil per perangkat. Klien tidak dapat memalsukan hasil kirim.

Perubahan agenda memperbarui konfigurasi job dalam transaksi data yang sama; sumber yang dihapus/diselesaikan atau pengingat dinonaktifkan membatalkan job. Jika pengguna mengubah pengingat, generation baru membatalkan lease lama. Tidak ada ketergantungan pada panggilan HTTP tambahan dari HP sesudah commit agar job bisa ditemukan.

## Penjadwal Cloudflare

Gunakan satu Cron Trigger setiap menit. Target awal setiap tick mengambil maksimal lima job yang enabled, status queued/leased, dan `availableAtUtc <= waktu server`, diurutkan availableAt; query collection-group dengan indeks, bukan scan semua akun. Angka ini membatasi beban awal, bukan jaminan throughput produksi. Pantau backlog dan keterlambatan.

Urutan tiap job:

1. Claim dengan transaksi REST Firestore dan lease 60 detik; simpan generation/sourceVersion yang dibaca. Request paralel tidak boleh memegang lease aktif yang sama.
2. Baca agenda terbaru, pengecualian, preferensi pengingat, dan perangkat aktif milik UID. Periksa waktu acuan, completion/cancel/delete, generation, serta apakah job masih relevan. Jika sudah lewat waktu kegiatan/deadline, tandai expired; jangan mengirim “sebentar lagi” setelah lewat.
3. Periksa batas pengiriman per UID dan global. Batas awal 10 per UID/menit; batas proyek mengikuti hasil uji/pilot. Jangan menerima token tujuan bebas dari klien atau mengambil UID dari teks AI.
4. Kirim memakai FCM HTTP v1 dan OAuth service account di secret. Catat hasil per perangkat; token invalid/unregistered dinonaktifkan. Lease/source version diperiksa kembali sebelum kirim. Masih ada celah kecil apabila perubahan terjadi sesudah pemeriksaan terakhir dan sebelum FCM menerima pesan; mitigasi payload generik dan validasi lagi ketika dibuka, bukan klaim pengiriman dapat ditarik kembali.
5. Simpan satu inbox notification dan hasil dispatch. Penulisan akhir memeriksa generation/lease lagi; hasil pengiriman lama tidak boleh menimpa job generasi baru yang dibuat saat request FCM masih berjalan. Untuk sekali saja, terminal sent; untuk seri, hitung pertemuan valid berikutnya dan jadwalkan cursor berikutnya. Tidak memanggil AI pada cron.

Untuk seri tanpa akhir, job menyimpan cursor pertemuan berikutnya, bukan semua pertemuan bertahun-tahun. Perhitungan mempertimbangkan hari mingguan, zona waktu, tanggal akhir, cancel/move exceptions, dan pertemuan dipindah masuk rentang. Pemindahan satu pertemuan tidak melompati pertemuan reguler yang lebih dekat. Pencarian dibatasi per halaman; bila terlalu banyak pengecualian, simpan cursor kemajuan untuk tick berikutnya, jangan mengirim kandidat yang belum diverifikasi. CPU seri kompleks termasuk gerbang kelayakan paket gratis.

Jika FCM mengembalikan kegagalan sementara, retry bertahap 1, 2, lalu 5 menit, maksimal lima percobaan dan hanya sebelum waktu acuan. Respect Retry-After jika lebih lama. Jangan mengulang token yang sudah sukses ketika perangkat lain gagal. Respons jaringan tidak diketahui dapat menyebabkan pengiriman ulang; gunakan ID/tag yang sama. Exactly-once delivery tidak dijanjikan. Lease kedaluwarsa bisa diproses ulang setelah verifikasi sumber/generation.

Status terminal berlaku untuk peristiwa saat ini. Pada seri yang masih aktif, hasil sent/expired/failed atau tidak ada perangkat aktif tetap harus memajukan cursor ke pertemuan berikutnya; tidak mematikan pengingat seri selamanya. Riwayat hasil peristiwa berada di inbox/dispatch history ringkas. Jika pola seri berakhir atau pengingat dimatikan, barulah cursor berhenti.

Payload minimal: judul **Pengingat Ruma**, isi generik **Ada agenda yang perlu kamu cek**, notification ID, agenda ID, occurrence key, source version, generation, dan UID konteks. Hindari angka uang, token, nama kelas sensitif, atau isi percakapan di layar kunci. Pesan pengingat buatan pengguna disimpan untuk detail di aplikasi; bukan dikirim sebagai teks sensitif layar kunci. Saat diketuk, aplikasi mengambil detail dari akun yang sedang masuk; berbeda UID mengarah ke masuk tanpa membuka data lama.

Saat aplikasi background/terminated, gunakan notification+data payload agar Android menampilkan notifikasi. Saat foreground, handler menampilkan tepat satu kartu lokal dengan ID yang sama. Handler background tidak mencoba membuka UI. Pemetaan getInitialMessage/onMessageOpenedApp harus menuju detail agenda yang benar. Catatan notif yang sumbernya berubah ditampilkan sebagai **Jadwal sudah diperbarui** dan membuka keadaan terbaru.

TTL dibatasi sampai waktu acuan, collapse/tag memakai identitas peristiwa. Ini pengingat best effort: FCM, koneksi, izin, battery optimization, cron, force-stop, atau antrean dapat menunda/mencegah kedatangan. Bukan alarm presisi atau sistem darurat. Beranda/Agenda/inbox tetap sumber yang dapat dibuka pengguna.

## Perangkat dan izin

- Minta izin setelah menjelaskan manfaat atau saat pengguna mengaktifkan pengingat, bukan berkali-kali setiap membuka aplikasi.
- Simpan/update token pada login, onTokenRefresh, dan pembukaan sesi. installation ID acak milik instalasi, tidak memanfaatkan identitas hardware.
- Kirim ke perangkat enabled milik UID yang sama; perangkat tanpa izin tidak dipaksa menerima tampilan. Uji dua perangkat sebagai satu akun dan pergantian akun pada satu HP.
- Logout online melepaskan pendaftaran server, menghapus token lokal, dan membatalkan notifikasi lokal milik akun lama. Logout offline tetap melindungi pembukaan detail dan membersihkan lokal; pengiriman yang sudah berada dalam antrean server belum tentu langsung berhenti.
- Token tidak masuk prompt/model/log publik. Service account bukan Firebase client config dan tidak pernah berada di APK.
- Menolak izin tidak menggagalkan simpan agenda. Tampilkan keadaan izin ditolak yang sudah ada dan akses ke pengaturan OS.

## Kuota yang harus dibuktikan

Cron per menit berarti sekitar 1.440 query/hari, bahkan jika kosong. Di atas itu ada pembacaan sumber, token, claim, hasil, refresh seri, serta penggunaan Rules/aplikasi. Perkirakan semuanya terhadap kuota Firestore, bukan hanya jumlah push. Jangan melakukan polling per pengguna setiap menit.

Worker Free membatasi CPU request dan cron. Benchmark verifikasi JWT/OAuth, parsing, REST transactions, pencarian recurrence, dan pengiriman beberapa job dengan cold key. Waktu tunggu jaringan berbeda dari CPU, tetapi crypto/JSON tetap menggunakan CPU. Jika lima job tidak muat, uji satu job/lebih ringan; jika tetap tidak layak, laporkan kebutuhan perubahan hosting. Jangan mengklaim push otomatis gratis telah terbukti sebelum pengujian.

Kriteria penerimaan dan skenario retry terdapat di [ACCEPTANCE.md](ACCEPTANCE.md). FCM/cron tetap bagian implementasi, tidak ada layanan yang diaktifkan melalui dokumen ini.

## Referensi

- [FCM server environment](https://firebase.google.com/docs/cloud-messaging/server-environment)
- [FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api)
- [Menerima pesan Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [Token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens)
- [Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/), [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Notifikasi lokal Flutter](https://pub.dev/packages/flutter_local_notifications)
