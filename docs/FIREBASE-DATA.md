# Ruma — Firebase, data, dan aturan aplikasi

> **Status terbaru 20 Oktober 2026:** workspace Asisten `users/{uid}/assistant/session` sudah aktif dan teruji produksi. Dokumen ini memakai `{schemaVersion:1, revision, payload, updatedAt}` dengan revision CAS, payload JSON maksimal 160.000 karakter dan timestamp server; hanya pemilik boleh baca/tulis. Workspace memuat input, hingga 10 percakapan sebelumnya dan satu tinjauan, tidak memberi otoritas commit ledger. Model tidak menerima riwayat secara otomatis. Ini pengecualian metadata dari konvensi record bisnis di bawah. [Bukti dan batas pemulihan](ASSISTANT-MEMORY.md). Catatan memori saja pada tahap lama berikut adalah riwayat sebelum implementasi ini.


> Tahap Asisten 19 Oktober 2026 selesai: draf gabungan agenda + transaksi, tinjauan/edit/keluarkan item, dan penyimpanan atomik aktif. Rules terbit 22.52 WIB; uji SDK/UI HP dan satu panggilan AI produksi lulus, fixture dibersihkan, APK normal dipasang. Draf masih dalam memori dan jam agenda disunting manual. Status/batas: [ASSISTANT-IMPLEMENTATION.md](ASSISTANT-IMPLEMENTATION.md).

> Tahap keuangan 19 Oktober 2026: form, repository, anggaran, riwayat, laporan dan Beranda sudah diimplementasikan. Rules gabungan aktif dan uji SDK Android lokal/produksi lulus; fixture dibersihkan dan APK normal dipasang. Status/bukti terbaru: [FINANCE-IMPLEMENTATION.md](FINANCE-IMPLEMENTATION.md).

18 Oktober 2026 · spesifikasi untuk implementasi. Penyiapan Auth dan database awal sudah dilakukan; [SETUP.md](SETUP.md) mencatat keadaan aktual. Bagian agenda sekali jalan, state/core dan receipt manual sudah diimplementasikan dan Rules khususnya aktif; lihat [laporan agenda](AGENDA-IMPLEMENTATION.md). Keuangan manual kini juga aktif dan teruji; lihat [laporan keuangan](FINANCE-IMPLEMENTATION.md). Bagian seri, draf AI dan notifikasi di bawah tetap spesifikasi target, belum seluruhnya diimplementasikan. Cache disk tidak dipakai pada slice agenda; baca daftar selalu dari server. Mengikuti [arsitektur](ARCHITECTURE.md). Nilai batas pada dokumen ini adalah keputusan teknis awal yang dapat disesuaikan berdasarkan pengujian, tanpa menambah fitur produk.

## Akun dan akses awal

Email/password adalah metode daftar dan masuk utama. Email unik mengikuti Firebase Auth; kata sandi tidak disimpan di Firestore, log, ataupun draf. Terapkan kebijakan kata sandi Firebase dan tampilkan ketentuannya. Verifikasi email, reset kata sandi, dan login sosial tetap ditunda. Kegagalan masuk tidak membocorkan rincian akun lain.

Tombol desain **Mulai tanpa akun** dipertahankan sebagai **tanpa pendaftaran email**, menggunakan Firebase Anonymous Auth. Akses pertama tetap membutuhkan internet; ini bukan mode penyimpanan lokal yang terpisah. Tampilkan penjelasan singkat bahwa akun sementara tidak dapat dipulihkan setelah sesi/instalasi hilang. Daftar dari sesi sementara memakai account linking agar UID dan data yang sama dipertahankan. Jika email sudah digunakan, jangan gabungkan data dengan akun tersebut secara otomatis; pertahankan sesi sementara sampai pengguna memilih apakah melanjutkan daftar atau beralih ke akun yang sudah ada.

Masuk ke akun berbeda menutup seluruh langganan data lama dan mengganti konteks UID. Setiap callback/request membawa generation sesi; hasil terlambat dari akun sebelumnya dibuang, tidak dimasukkan ke draf akun baru. Logout membatalkan permintaan berjalan, mengosongkan state tampilan/draf aktif, membatalkan pengingat lokal akun lama, serta melepaskan token perangkat dari akun lama sebelum sign-out jika online. Jika offline, hapus token lokal dan blokir pengiriman akun lama melalui mekanisme registrasi perangkat pada koneksi berikutnya; sisa push yang sudah terkirim tidak dapat ditarik kembali. Jangan menjanjikan logout langsung mencabut token server ketika perangkat offline.

Data cloud akun terdaftar tidak dihapus oleh logout. Cache SDK harus dibersihkan melalui urutan lifecycle yang didukung sebelum konteks akun lain dibuka; uji pergantian akun saat offline. Label lama **Pertahankan data lokal** di frame logout diganti dalam implementasi menjadi keterangan **Data akun tetap tersimpan. Masuk kembali untuk mengaksesnya.** Perubahan ini belum diterapkan ke Figma/PDF.

## Konvensi penyimpanan

- Seluruh data pribadi berada di `users/{uid}/...`; UID selalu berasal dari sesi, bukan jawaban model. Dokumen induk dan semua subkoleksi memiliki aturan tersendiri.
- ID dibuat sebelum penyimpanan dan dipakai kembali ketika retry. Jangan menggunakan judul sebagai ID.
- Field umum: `schemaVersion: 1`, `version` integer naik, `createdAt`, `updatedAt` timestamp server; data yang dapat dihapus memakai `deletedAt` nullable untuk mendukung urungkan.
- Uang memakai integer rupiah, bukan floating point. Batas awal nominal per transaksi Rp1 sampai Rp1.000.000.000. Nilai agregat tetap boleh negatif untuk saldo/sisa.
- Waktu kejadian memakai UTC Timestamp dan zona waktu IANA. Tanggal transaksi memakai `YYYY-MM-DD` sesuai tanggal lokal yang dipilih; bulan `YYYY-MM`. Tanggal lama tidak bergeser karena pengguna bepergian.
- Field opsional memakai null yang konsisten. Anggaran belum ditentukan berbeda dengan anggaran nol.
- Batas teks awal: judul 120, deskripsi 1.000, bio 160, pesan pengguna 4.000 karakter. Validasi juga dilakukan pada batas layanan.

## Koleksi dan isi dokumen

| Path relatif terhadap `users/{uid}` | Field bisnis utama | Pemilik penulisan |
|---|---|---|
| Dokumen pengguna | `displayName`, `bio`, `campus`, `major`, `semester`, `avatarColor`, `timezone`, `preferences`, `aiConsentVersion`, `aiConsentAt` | Pengguna sendiri |
| `state/core` | `agendaRevision`, `financeRevision`, `balanceRupiah`, `lifetimeIncomeRupiah`, `lifetimeExpenseRupiah`, `lastUndoOperationId` | Transaksi penyimpanan aplikasi |
| `agenda/{id}` | `kind`, `title`, `description`, `startAtUtc`, `endAtUtc`, `durationMinutes`, `deadlineAtUtc`, `priority`, `status`, `timezone`, `recurrence` | Pengguna sendiri |
| `exceptions/{id}` | `seriesId`, `originalLocalDate`, `action`, `replacementStartAtUtc`, `replacementEndAtUtc`, `statusOverride`, `seriesVersion` | Pengguna sendiri |
| `transactions/{id}` | `type`, `amountRupiah`, `categoryId`, `localDate`, `monthKey`, `description`, `source`, `operationId` | Pengguna sendiri |
| `months/{YYYY-MM}` | `incomeRupiah`, `expenseRupiah`, `categoryExpenseRupiah`, `budgetTotalRupiah`, `categoryBudgetRupiah` | Transaksi penyimpanan aplikasi |
| `drafts/{id}` | `revision`, `state`, `items`, `excludedItemIds`, `baseAgendaRevision`, `baseFinanceRevision`, `originMessageId`, `operationId` | Pengguna sendiri |
| `operations/{id}` | `draftId`, `approvedRevision`, `kind`, `targets`, `beforeImages`, `afterVersions`, `result`, `undoState` | Transaksi penyimpanan aplikasi |
| `conversations/{id}/messages/{id}` | `role`, `content`, `draftId`, `operationId`, `toolSummary`, `createdAt` | Pengguna sendiri; bukan otorisasi backend |
| `reminders/{id}` | `agendaId`, `occurrenceKey`, `sourceVersion`, `generation`, `enabled`, `leadMinutes`, `message`, `eventAtUtc`, `dueAtUtc`, `availableAtUtc`, `status`, `dispatch` | Pengguna mengatur tujuan; Worker mengatur hasil kirim |
| `devices/{installationId}` | `fcmToken`, `platform`, `permission`, `tokenUpdatedAt`, `enabled`, `lastSeenAt` | Perangkat milik UID yang sama |
| `notifications/{id}` | `agendaId`, `occurrenceKey`, `sourceVersion`, `title`, `body`, `scheduledAt`, `sentAt`, `readAt`, `status` | Worker menulis isi; pengguna hanya menandai dibaca |

`usage/{uid_period}` berada di tingkat proyek dan **hanya dapat diakses Worker** untuk batas pemakaian AI/push. Tidak ada koleksi API key atau kata sandi di database klien. Tidak menggunakan Cloud Storage untuk avatar; inisial dan warna mengikuti aset yang sudah tersedia.

`preferences` mencakup `personalizationEnabled`, `comfortableDurationMinutes`, `suggestionStyle`, `remindersEnabled`, dan `language: id`. Tidak memuat jam aktif, jam istirahat, pola energi, atau durasi aktual. Waktu yang boleh dipakai untuk pencarian slot diminta pada konteks kegiatan, bukan menghidupkan kembali Ritme Harian.

## Aturan agenda dan saran waktu

`kind` adalah `class` atau `task`; `status` adalah `planned`, `completed`, atau `cancelled`. Tugas belum terjadwal memiliki start/end null, tetap dapat memiliki deadline. Waktu mulai dan selesai harus sama-sama ada atau sama-sama null. Durasi awal 5–720 menit dan dapat diubah pengguna. Kegiatan lintas tengah malam memakai timestamp tanggal yang benar.

Interval memakai batas `[mulai, selesai)`: selesai 10.00 dan mulai 10.00 tidak bentrok. Pertemuan dibatalkan, tugas selesai, atau data terhapus tidak menghalangi pencarian waktu mendatang. Penjadwalan ulang tidak dilakukan tanpa permintaan dan persetujuan.

Pencarian slot dijalankan deterministik di Flutter, bukan dipercayakan pada hitungan model. Masukan wajib: durasi, tanggal/rentang, zona waktu, serta rentang jam yang pengguna bersedia gunakan. AI bertanya singkat jika informasi penting belum jelas. Periksa kelas berulang, pengecualian, agenda tunggal, dan item lain dalam draf yang sama. Tawarkan paling banyak tiga pilihan; jangan memendekkan durasi, melewati deadline, menambahkan jeda otomatis, atau memecah tugas menjadi banyak sesi. Prioritas membantu urutan usulan, bukan alasan melewati batas keras.

Horizon awal pencarian maksimal 14 hari atau sampai deadline yang lebih dekat. Jika tidak mendapat slot, tampilkan belum terjadwal dan tawarkan perubahan rentang/durasi dengan persetujuan. Jangan menganggap pencarian 14 hari membuktikan seluruh kalender penuh.

### Kelas berulang

`recurrence` selalu berupa map dengan `type: none` untuk sekali saja atau `type: weekly` untuk mingguan, agar query tidak bergantung pada field yang hilang. Mingguan memuat hari ISO 1–7, tanggal mulai/akhir opsional, jam lokal mulai, durasi, dan zona waktu IANA. Seri tanpa tanggal akhir tetap berupa pola, tidak dibuat menjadi ribuan dokumen. Rentang kalender diekspansi saat dibaca. Zona waktu seri lama tetap melekat pada seri; pergantian zona perangkat hanya mengubah tampilan, bukan diam-diam menggeser waktu aslinya.

Identitas pertemuan adalah `seriesId + originalLocalDate`, tetap sama saat waktunya dipindahkan. Pengecualian `move` mengganti waktu pada tanggal asal; `cancel` meniadakan pertemuan itu. Penyelesaian pertemuan memakai `statusOverride`, bukan menyelesaikan seluruh seri. Query juga harus memasukkan pertemuan yang dipindah masuk rentang dari tanggal asal di luar rentang.

**Pertemuan ini saja** menulis pengecualian. **Mulai pertemuan ini dan seterusnya** membatasi seri lama sebelum tanggal asal pertemuan dan membuat seri lanjutan dengan `parentSeriesId`. Tinjau pengecualian mendatang: pertahankan dengan pemetaan ke seri baru, ubah, atau hapus setelah persetujuan; jangan menghilangkannya diam-diam. Riwayat yang lampau tidak diubah. Jika ada banyak pengecualian, jangan membagi penyimpanan menjadi bagian-bagian yang diklaim atomik; minta peninjauan cakupan terlebih dahulu.

## Uang dan laporan

`type` adalah `income` atau `expense`; nominal disimpan positif. Kategori pengeluaran: `food`, `transport`, `housing`, `other`; kategori pemasukan: `allowance`, `work`, `other_income`. Kategori kuliah/cetak pada desain masuk `other` dengan keterangan. Rencana pengeluaran masa depan tidak dicatat sebagai transaksi aktual.

Tanggal transaksi tidak boleh melewati hari ini pada zona waktu pengguna. AI harus bertanya bila belum jelas apakah uang sudah masuk/keluar. Nilai saldo rekening dan uang tunai tidak diambil dari bank; UI menyebut **saldo tercatat**. Tidak ada pemindahan antar rekening, utang, atau koneksi bank pada versi ini.

Transaksi merupakan sumber kebenaran. `state/core` dan `months` adalah ringkasan turunan yang diperbarui bersama transaksi, bukan saldo yang dapat diedit sendiri di UI. Edit tanggal/jenis/kategori membalik kontribusi lama lalu menambahkan yang baru pada bulan terkait; hapus dan urungkan melakukan kebalikannya.

Rumus: saldo = pemasukan seumur pencatatan − pengeluaran seumur pencatatan; pengeluaran periode = jumlah expense aktif dalam periode; sisa anggaran = batas bulan − pengeluaran bulan. Porsi kategori dibagi total pengeluaran periode, bukan pemasukan. Jika total nol, tampilkan belum ada data; progress visual maksimal 100% tetapi kelebihan tetap ditulis sebagai angka. Batas kategori opsional; jumlah yang diisi tidak melebihi total anggaran. Sisa pembagian menjadi bagian yang belum dialokasikan, bukan kategori baru.

Laporan bulanan membaca `months` dan transaksi bulan itu untuk rincian; ringkasan 1–14 suatu bulan dihitung dari transaksi tanggal tersebut. Jangan menampilkan ringkasan sebulan sebagai hasil 14 hari. Query transaksi dipaginasi; pencarian keterangan bekerja pada periode terpilih, dengan seluruh halaman relevan dibaca sebelum menyatakan hasil lengkap. Tidak menambah layanan full-text search.

## Simpan, bentrokan serentak, dan urungkan

Satu jalur penyimpanan dipakai form manual dan AI. Draf gabungan tahap awal: maksimal tiga agenda dan tiga transaksi, hanya penambahan. Ubah/hapus item lama tetap memakai tinjauan tindakan tersendiri.

Setiap perintah mempunyai ID operasi stabil. Sebelum simpan, baca data terkini dan `state/core`. Hitung perubahan serta konflik, lalu jalankan Firestore transaction yang membaca ID operasi, core, dokumen target, ringkasan bulan terkait, dan data pengecualian yang diperlukan **sebelum** menulis. Setiap perubahan agenda menaikkan `agendaRevision`. Hasil query bentrokan diambil di luar callback transaksi dengan revisi core sebelum/sesudah query yang sama; di dalam transaksi revisi harus masih sama. Jika revisi berubah, hentikan percobaan dan ulangi query/peninjauan di luar callback. Jangan menjalankan query atau panggilan AI di callback transaksi.

Dengan protokol ini dua perangkat yang sama-sama melihat slot kosong tidak boleh menyimpan hasil berdasarkan revisi lama. Semua jalur perubahan agenda harus memperbarui core, termasuk kelas dan pengecualian. Perubahan waktu yang berbeda dari draf yang disetujui meminta persetujuan baru.

Simpan entitas, ringkasan, operasi, status draf, serta konfigurasi pengingat yang terpengaruh secara atomik. Jika ID operasi sudah ada, kembalikan hasilnya; jangan menulis entitas baru. Tidak ada pengiriman FCM/AI/notifikasi lokal di dalam callback transaksi yang dapat diulang SDK. Efek notifikasi dikerjakan setelah commit oleh antrean pengingat.

Urungkan awal hanya untuk operasi data terakhir yang masih memenuhi versi sesudah perubahan. Jika target sudah diubah lagi, jangan menimpa perubahan baru; tampilkan alasan dan arahkan ke edit manual. Urungkan satu batch memulihkan seluruh item dan ringkasan secara atomik. Op terakhir baru menggantikan before-images yang tidak lagi bisa diurungkan; riwayat ringkas tetap ada. Menghapus riwayat personalisasi tidak menghapus transaksi, agenda, atau catatan integritas operasi.

Firestore transaction membutuhkan jaringan. Mode offline awal: baca cache yang sudah ada, edit draf lokal, dan buka halaman; **commit agenda/keuangan menunggu koneksi dan validasi ulang**. Jangan tampilkan “tersimpan” saat baru berada di cache. Draf/form disimpan sebagai berkas JSON milik UID di penyimpanan privat aplikasi agar tidak hilang saat proses berhenti; ini bukan database utama kedua. Tidak ada antrean commit otomatis tersembunyi ketika koneksi kembali. Ini menyederhanakan konflik data; tidak menjanjikan CRUD penuh offline.

## Security Rules yang harus ditulis dan diuji nanti

- Default deny; autentikasi saja tidak cukup: `request.auth.uid` harus sama dengan UID path. Akun anonymous tetap mempunyai UID.
- Owner boleh membaca data sendiri dan menulis field yang diizinkan. Daftar field, tipe, enum, panjang, nominal, timestamp, dan kenaikan versi dibatasi. Semua path lain ditolak.
- Operasi data harus memperbarui core/revisi dan ringkasan terkait menggunakan pemeriksaan `getAfter` yang terukur. Transaksi keuangan tidak boleh mengubah `owner`, `createdAt`, atau melewati tipe/nominal yang sah. Rumus ringkasan juga diuji oleh kode transaksi; Rules tidak menjalankan penjumlahan seluruh ledger.
- Draf dan pesan percakapan bukan bukti persetujuan yang dipercaya backend. Aplikasi memerlukan interaksi persetujuan nyata untuk alur produk; pemilik data tetap dapat mengakses data miliknya lewat klien yang sah. Jangan mengklaim Rules dapat membuktikan pengguna benar-benar menekan tombol.
- Owner tidak dapat membaca/menulis data UID lain, kuota server, hasil pengiriman server, atau kredensial. Token perangkat tidak pernah dikirim ke model.
- Pengingat: owner boleh membuat tujuan pengingat valid berstatus queued, mengubah tujuan dengan `generation + 1`, atau membatalkan miliknya; hanya Worker boleh menulis lease, attempts, sentAt, dan hasil FCM. Validasi agenda sumber/versinya menggunakan `getAfter` dan larang target perangkat di luar akun sendiri. Tidak ada endpoint mengirim push bebas ke token yang dikirim klien.
- Server REST memakai service account terpisah; akses server tidak dilindungi Rules klien sehingga Worker harus memeriksa kepemilikan serta menggunakan IAM sekecil yang diperlukan. Jangan menambahkan role Owner/Editor proyek.
- Hitung akses Rules: maksimal 10 pembacaan dokumen per operasi dan 20 untuk transaksi/batch menurut batas Firebase. Cache akses tidak dijadikan asumsi. Ukur batch maksimum tiga agenda+tiga transaksi beserta pengingat, core, dan ringkasan di emulator; sederhanakan checks bersama jika diperlukan, jangan melepas isolasi akun.

Kandidat Rules create-batch tersedia pada `config/firebase/firestore.rules` dan [sembilan pemeriksaan emulator](qa/firestore-rules-check.json) lulus. Cakupan: agenda sekali saja zona Jakarta, transaksi, core/ringkasan, receipt penambahan, pengingat baru dan readAt inbox. Field `operationId` dipakai pada agenda dan ringkasan bulan untuk memeriksa satu commit yang sama. Potongan ini belum mengimplementasikan profil, seri/pengecualian, applied pada draf, edit/hapus/undo, perangkat dan pesan; path tersebut masih ditolak. Kandidat ini bukan Rules produksi seluruh aplikasi. Kandidat batch lama tidak dipakai sebagai deployment aktif. Status sekarang: Rules gabungan agenda + keuangan manual diterbitkan dan diuji; path fitur yang belum didukung tetap ditolak. Lihat FINANCE-IMPLEMENTATION.md untuk sumber Rules aktif, bukti dan batas.

## Query dan indeks awal

| Query | Kandidat indeks komposit |
|---|---|
| Agenda tunggal dalam rentang | `deletedAt`, `recurrence.type`, `startAtUtc` |
| Tugas belum terjadwal/deadline | `deletedAt`, `status`, `startAtUtc`, `deadlineAtUtc` |
| Seri mingguan aktif | `deletedAt`, `kind`, `recurrence.type` |
| Pengecualian tanggal asal | `seriesId`, `originalLocalDate` |
| Pengecualian dipindah masuk rentang | `action`, `replacementStartAtUtc` |
| Riwayat transaksi | `deletedAt`, `monthKey`, `localDate` descending, document ID |
| Riwayat dengan jenis/kategori | tambah `type` dan/atau `categoryId` pada query periode yang benar-benar digunakan |
| Operasi/percakapan | `createdAt` descending, document ID; gunakan pagination |
| Antrean pengingat dan lease kedaluwarsa (Worker) | collection-group reminders: `enabled`, `status`, `availableAtUtc`; status queued/leased dan availableAt sampai waktu server |

Nama indeks bersifat rancangan query, belum merupakan JSON indeks yang dapat di-deploy. Semua agenda yang mungkin bertumpang tindih harus diambil, termasuk mulai sebelum rentang tetapi berakhir di dalamnya. Untuk tahap awal durasi maksimal 12 jam memberi batas lookback 12 jam bagi query startAt; bukan hanya query mulai setelah jam tampilan. Seri dan pengecualian dibaca terpisah. Bandingkan hasil dengan data lintas hari saat uji.

Langganan realtime hanya untuk halaman aktif dan ringkasan inti. Riwayat dibaca per 30 item, bukan seluruh database saat membuka Beranda. Hindari polling semua pengguna/semua transaksi. Lokasi Firestore dipilih dekat pengguna Indonesia setelah memeriksa opsi region, kuota, dan lokasi Worker; pilihan lokasi database tidak diambil tanpa mencatatnya.

## Referensi teknis

- [Password auth](https://firebase.google.com/docs/auth/flutter/password-auth), [Anonymous/account linking](https://firebase.google.com/docs/auth/flutter/anonymous-auth)
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [Offline cache](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Rules conditions and limits](https://firebase.google.com/docs/firestore/security/rules-conditions), [Indexes](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Write-time aggregation](https://firebase.google.com/docs/firestore/solutions/aggregation), [REST authentication](https://firebase.google.com/docs/firestore/use-rest-api)

## Kandidat 21 Oktober 2026 — belum dipublikasikan

`firestore.final-stages.rules` menambah `users/{uid}/settings/personal` (schemaVersion/revision/updatedAt, bio/study/avatar, personalize/duration/from/to) dengan owner-only read/write dan revision CAS. Agenda mendukung recurrence weekly berbatas dan pengingat optional occurrenceDate; operasi dan receipt tetap koleksi yang sama. Rincian representasi JSON, batas validasi dan verifikasi terdapat di FINAL-STAGES-1-3.md. `firebase.json` masih menunjuk Rules assistant-memory yang aktif; bagian kandidat ini belum mengubah kontrak produksi.

Status terbaru 21 Oktober 2026: Rules final-stages sudah aktif atas persetujuan pengguna; firebase.json diselaraskan. Settings/profil dan isolasi akun lulus produksi, fixture dibersihkan. Verifikasi AI masih HTTP 502, tidak ada perubahan izin/IAM tambahan. Lihat hasil aktual FINAL-STAGES-1-3.md.
