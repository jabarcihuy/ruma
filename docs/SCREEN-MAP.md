# Ruma — pemetaan frame ke implementasi Flutter

18 Oktober 2026 · seluruh **71 frame aktif** telah dipetakan. Hasilnya **27 jenis halaman utama/pendukung**; selebihnya sheet, dialog, atau keadaan dalam komponen yang sama. Jumlah ini adalah rencana implementasi, bukan penghapusan frame di Figma. Satu jenis halaman dapat menerima banyak ID/mode tanpa membuat route baru untuk setiap contoh.

> Status implementasi aktual per 19 Oktober ada di [audit Figma terhadap Flutter](FIGMA-IMPLEMENTATION-AUDIT.md). Pemetaan di bawah adalah rancangan target, bukan bukti bahwa semua fitur sudah dibangun.

## Navigasi dan alur pengguna

- MainShell memiliki lima tab: Beranda → Agenda → Asisten → Keuangan → Profil, dengan posisi desain yang sudah dipilih. Navbar tidak diulang sebagai widget berbeda di setiap halaman.
- Alur manual agenda: Agenda/Beranda → form → pilihan waktu → tinjau/simpan → detail/hasil. Kelas memakai form jadwal dan cakupan perubahan.
- Alur uang: Keuangan/Beranda → form transaksi → simpan → hasil/riwayat. Laporan dan batas bulan tetap dapat dibuka langsung tanpa AI.
- Alur unggulan: Asisten → satu pesan agenda+uang → klarifikasi hanya yang perlu → satu draf gabungan → Simpan semua → hasil, Agenda dan Keuangan diperbarui.
- Detail/filter/picker menerima caller, selected ID, mode, dan return value. Tombol kembali tidak memilih ulang transaksi atau menghapus form.
- Keluar dari editor dengan perubahan belum disimpan meminta konfirmasi simpan draf/buang, memakai dialog yang sama; jangan menambah halaman konfirmasi baru.

## Pemetaan lengkap

| Key frame | Judul desain | Implementasi | Bentuk / perilaku |
|---|---|---|---|
| `welcome` | Ruang untuk waktu dan uangmu. | `WelcomePage` | halaman: Mulai sesi sementara atau buka akun; akses pertama online. |
| `signin` | Selamat datang lagi | `AuthPage` | halaman: Mode masuk/daftar; error pada form yang sama; linking sesi sementara saat daftar. |
| `signup` | Buat akun Ruma | `AuthPage` | halaman: Mode masuk/daftar; error pada form yang sama; linking sesi sementara saat daftar. |
| `consent` | Kamu pegang kendali | `ConsentSheet` | sheet: Izin AI, personalisasi, dan pengingat terpisah; simpan pilihan. |
| `classAdd` | Tambah jadwal | `ClassFormPage` | halaman: Tambah/edit kelas dengan waktu, pengulangan, cakupan, dan pengecualian. |
| `repeat` | Pengulangan jadwal | `RecurrenceSheet` | sheet: Pola mingguan atau sekali saja; kembali ke form asal. |
| `scope` | Terapkan ke mana? | `SeriesScopeSheet` | sheet: Satu pertemuan atau mulai pertemuan ini; tampilkan dampak pengecualian. |
| `cancelMeeting` | Batalkan pertemuan? | `ConfirmationDialog` | dialog: Konfirmasi pembatalan dengan cakupan seri yang jelas. |
| `dashboard` | Waktu & uangmu. | `HomePage` | halaman: Tab Beranda: ringkasan waktu dan uang setara dari data akun aktif. |
| `calendar` | Agendamu minggu ini | `AgendaPage` | halaman: Tab Agenda; kalender/daftar, kosong, dan tugas belum terjadwal adalah keadaan data. |
| `datePicker` | Pilih tanggal | `DatePicker` | dialog: Picker bersama; kembalikan nilai ke field/periode yang membuka. |
| `timePicker` | Pilih waktu | `TimePicker` | dialog: Picker jam-menit; rasio dan padding normal, memakai konteks field asal. |
| `taskAdd` | Kegiatan baru | `TaskFormPage` | halaman: Tambah/edit kegiatan; rincian tambahan tersembunyi sampai dibutuhkan. |
| `deadline` | Batas & prioritas | `DeadlinePrioritySheet` | sheet: Tanggal/jam batas dan prioritas; tidak menyimpan agenda sebelum form utama disetujui. |
| `slots` | Pilih selamu | `SlotSelectionPage` | halaman: Pilihan slot atau tidak ada slot; durasi/rentang dapat diubah, tidak dikurangi diam-diam. |
| `manual` | Atur waktu sendiri | `ManualTimeSheet` | sheet: Masukan waktu sendiri dengan pemeriksaan bentrokan yang sama. |
| `taskDetail` | Laporan praktikum | `AgendaDetailPage` | halaman: ID agenda/seri dan occurrence key menentukan isi; bukan satu detail contoh statis. |
| `saved` | Kegiatan tersimpan | `OperationResult` | keadaan: Hasil receipt operasi: agenda/uang/gabungan/selesai/urungkan; CTA mengikuti hasil sebenarnya. |
| `completed` | Satu kegiatan selesai | `OperationResult` | keadaan: Hasil receipt operasi: agenda/uang/gabungan/selesai/urungkan; CTA mengikuti hasil sebenarnya. |
| `unscheduled` | Belum mendapat waktu | `AgendaPage` | halaman: Tab Agenda; kalender/daftar, kosong, dan tugas belum terjadwal adalah keadaan data. |
| `emptyAgenda` | Harimu masih lapang | `AgendaPage` | halaman: Tab Agenda; kalender/daftar, kosong, dan tugas belum terjadwal adalah keadaan data. |
| `noSlot` | Hari ini sudah penuh | `SlotSelectionPage` | halaman: Pilihan slot atau tidak ada slot; durasi/rentang dapat diubah, tidak dikurangi diam-diam. |
| `saveError` | Belum berhasil tersimpan | `SaveError` | keadaan: Tampilkan di form/tinjauan asal; draf utuh dan retry memakai ID yang sama. |
| `deleteTask` | Hapus kegiatan ini? | `ConfirmationDialog` | dialog: Varian hapus agenda, transaksi, riwayat personalisasi, atau logout; teks dan dampak berbeda. |
| `conflict` | Tinjau bentrokan | `ConflictReviewPage` | halaman: Tinjau perubahan kelas dan agenda terdampak; perubahan baru disimpan setelah persetujuan. |
| `stale` | Pilihan perlu diperbarui | `StaleDraft` | keadaan: Keadaan pada tinjauan/slot; minta data terbaru tanpa membuang isian. |
| `changeConfirm` | Terapkan perubahan? | `ConfirmationDialog` | dialog: Ringkasan dampak perubahan jadwal sebelum commit atomik. |
| `chat` | Mau dibantu apa? | `AssistantPage` | halaman: Tab Asisten; pesan, baca hasil, klarifikasi, loading/error dan konteks uang dalam satu percakapan. |
| `chatDraft` | Tinjau draf dari AI | `DraftReviewPage` | halaman: Satu tinjauan untuk agenda/transaksi/gabungan; edit, keluarkan, batal, atau setujui revisi ini. |
| `aiLoading` | Memperkirakan durasi | `AssistantPage` | halaman: Tab Asisten; pesan, baca hasil, klarifikasi, loading/error dan konteks uang dalam satu percakapan. |
| `aiError` | AI belum bisa membantu | `AssistantPage` | halaman: Tab Asisten; pesan, baca hasil, klarifikasi, loading/error dan konteks uang dalam satu percakapan. |
| `history` | Riwayat & pembelajaran | `ActivityHistoryPage` | halaman: Riwayat tindakan/durasi rencana dan draf; tidak mengarang durasi aktual. |
| `personalPrefs` | Personalisasi milikmu | `PersonalPreferencesPage` | halaman: Izin riwayat, panjang sesi nyaman, dan gaya saran; bukan ritme harian. |
| `agentRead` | Ini kegiatanmu | `AssistantPage` | halaman: Tab Asisten; pesan, baca hasil, klarifikasi, loading/error dan konteks uang dalam satu percakapan. |
| `agentUpdate` | Tinjau perubahan | `DraftReviewPage` | halaman: Satu tinjauan untuk agenda/transaksi/gabungan; edit, keluarkan, batal, atau setujui revisi ini. |
| `agentDelete` | Hapus kegiatan ini? | `ConfirmationDialog` | dialog: Varian hapus agenda, transaksi, riwayat personalisasi, atau logout; teks dan dampak berbeda. |
| `agentClarify` | Laporan yang mana? | `AssistantPage` | halaman: Tab Asisten; pesan, baca hasil, klarifikasi, loading/error dan konteks uang dalam satu percakapan. |
| `agentConflict` | Jamnya sudah terisi | `AssistantPage` | halaman: Tab Asisten; pesan, baca hasil, klarifikasi, loading/error dan konteks uang dalam satu percakapan. |
| `agentApplied` | Hasil tindakan AI | `OperationResult` | keadaan: Hasil receipt operasi: agenda/uang/gabungan/selesai/urungkan; CTA mengikuti hasil sebenarnya. |
| `agentUndo` | Urungkan tindakan AI | `OperationResult` | keadaan: Hasil receipt operasi: agenda/uang/gabungan/selesai/urungkan; CTA mengikuti hasil sebenarnya. |
| `combinedDraft` | Cek sebelum disimpan | `DraftReviewPage` | halaman: Satu tinjauan untuk agenda/transaksi/gabungan; edit, keluarkan, batal, atau setujui revisi ini. |
| `combinedEdit` | Ubah rincian draf | `DraftItemEditor` | sheet: Form sesuai jenis item, hanya mengubah draf; tidak menyentuh ledger. |
| `combinedSaved` | Semua sudah tersimpan | `OperationResult` | keadaan: Hasil receipt operasi: agenda/uang/gabungan/selesai/urungkan; CTA mengikuti hasil sebenarnya. |
| `notifications` | Pengingatmu | `NotificationInboxPage` | halaman: Daftar pengingat aktual dari akun, status dibaca, dan tujuan detail. |
| `reminder` | Atur pengingat | `ReminderSheet` | sheet: Aktif/nonaktif, lead time dan pesan; konteks agenda atau default dasar. |
| `notificationPermission` | Aktifkan pengingat? | `NotificationPermissionPrompt` | dialog: Penjelasan manfaat lalu izin OS, dapat ditolak. |
| `notifDetail` | Sebentar lagi waktumu | `NotificationDetailPage` | halaman: Detail versi agenda terbaru; snooze lokal lima menit atau edit jadwal. |
| `notificationDenied` | Pengingat tetap di sini | `NotificationPermissionState` | keadaan: Banner/empty state inbox/pengaturan; menolak izin tidak menghalangi agenda. |
| `settings` | Pengaturan Ruma | `SettingsPage` | halaman: Pintu masuk preferensi, personalisasi, privasi, bantuan, dan akun. |
| `profile` | Profilmu | `ProfileEditPage` | halaman: Form identitas dan avatar; simpan langsung kembali ke Profil. |
| `appPrefs` | Preferensi aplikasi | `AppPreferencesPage` | halaman: Bahasa Indonesia dan pengingat dasar; opsi yang belum didukung tidak dibuat palsu. |
| `privacy` | Datamu, kendalimu | `PrivacyPage` | halaman: Penjelasan cloud/AI, izin riwayat, dan hapus personalisasi; dapat dibuka sebelum login. |
| `help` | Ada yang ingin kamu pahami? | `HelpPage` | halaman: Penjelasan saran waktu, persetujuan AI, saldo tercatat, dan pengingat. |
| `historyFilter` | Filter riwayat | `FilterSheet` | sheet: Konteks riwayat aktivitas atau transaksi; terapkan/reset kembali ke daftar asal. |
| `deleteHistory` | Hapus riwayat AI? | `ConfirmationDialog` | dialog: Varian hapus agenda, transaksi, riwayat personalisasi, atau logout; teks dan dampak berbeda. |
| `logout` | Keluar dari akun? | `ConfirmationDialog` | dialog: Varian hapus agenda, transaksi, riwayat personalisasi, atau logout; teks dan dampak berbeda. |
| `profileHome` | Ruang untuk dirimu. | `ProfilePage` | halaman: Tab Profil; identitas aktif, edit, pengaturan, bantuan, dan akses akun. |
| `avatarPicker` | Pilih tampilanmu | `AvatarPickerSheet` | sheet: Inisial dan warna tersedia dari aset; hasil kembali ke editor profil. |
| `budgetHome` | Uangmu punya arah. | `FinancePage` | halaman: Tab Keuangan; saldo/batas bulanan/riwayat/laporan dan keadaan belum ada transaksi. |
| `budgetSetup` | Atur batas bulanan. | `BudgetFormPage` | halaman: Batas total dan kategori per bulan; validasi jumlah kategori, simpan satu perubahan. |
| `expenseAdd` | Catat pengeluaran. | `TransactionFormPage` | halaman: Pengeluaran/pemasukan/edit memakai satu form; error nominal inline. |
| `transactionDetail` | Detail transaksi | `TransactionDetailPage` | halaman: Transaksi dari ID terpilih; edit/hapus menuju form/tinjauan bersama. |
| `transactionHistory` | Setiap rupiah tercatat. | `TransactionHistoryPage` | halaman: Riwayat per periode dengan pagination dan filter, tidak membuat halaman per transaksi contoh. |
| `transactionFilter` | Temukan catatanmu. | `FilterSheet` | sheet: Konteks riwayat aktivitas atau transaksi; terapkan/reset kembali ke daftar asal. |
| `budgetReport` | Lihat pola uangmu. | `BudgetReportPage` | halaman: Angka/grafik periode dan kategori dari ledger aktual; buka Asisten dengan konteks periode. |
| `budgetEmpty` | Mulai dari satu catatan. | `FinancePage` | halaman: Tab Keuangan; saldo/batas bulanan/riwayat/laporan dan keadaan belum ada transaksi. |
| `budgetError` | Periksa nominalnya. | `TransactionFormPage` | halaman: Pengeluaran/pemasukan/edit memakai satu form; error nominal inline. |
| `budgetAIedit` | Tinjau perubahan. | `DraftReviewPage` | halaman: Satu tinjauan untuk agenda/transaksi/gabungan; edit, keluarkan, batal, atau setujui revisi ini. |
| `budgetAIdelete` | Hapus catatan ini? | `ConfirmationDialog` | dialog: Varian hapus agenda, transaksi, riwayat personalisasi, atau logout; teks dan dampak berbeda. |
| `budgetAIread` | Ini pola pengeluaranmu. | `AssistantPage` | halaman: Tab Asisten; pesan, baca hasil, klarifikasi, loading/error dan konteks uang dalam satu percakapan. |
| `transactionSaved` | Hasil transaksi | `OperationResult` | keadaan: Hasil receipt operasi: agenda/uang/gabungan/selesai/urungkan; CTA mengikuti hasil sebenarnya. |

## Konteks yang sudah digabung pada desain

| Konteks | Komponen tujuan | Aturan |
|---|---|---|
| `taskEdit` | `TaskFormPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `classEdit` | `ClassFormPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `incomeAdd` | `TransactionFormPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `transactionEdit` | `TransactionFormPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `budgetChat` | `AssistantPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `slotAlt` | `SlotSelectionPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `agentCreate` | `DraftReviewPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `budgetAIreview` | `DraftReviewPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `detailMetode` | `AgendaDetailPage` | Parameter/mode pada layar bersama, bukan route tambahan. |
| `aiResult` | `OperationResult` | Parameter/mode pada layar bersama, bukan route tambahan. |

## Penyesuaian naskah untuk implementasi

| Frame | Perubahan wajib berdasarkan keputusan terkini |
|---|---|
| welcome/signin/consent | Tanpa akun berarti tanpa daftar email (anonymous session); internet dibutuhkan saat pertama kali. Jelaskan data cloud dan pengiriman konteks ke AI, bukan menjanjikan lokal saja. |
| signup | Kebijakan password aktual sesuai Firebase; jangan menampilkan ketentuan yang berbeda dari backend. |
| logout | Hapus pilihan mempertahankan data lokal akun lama sebagai mode tamu. Data akun tetap cloud; akses kembali melalui masuk, cache/state lama disembunyikan. |
| history | Ubah judul menjadi **Riwayat aktivitas**; durasi yang dipilih/diubah dan status kegiatan menggantikan klaim rencana vs aktual. |
| personalPrefs | **Gunakan riwayat kegiatan** / **Sesuaikan saran dari durasi yang kamu pilih.** Tidak ada training model atau pencatatan sesi aktual. |
| notifications | Hanya menampilkan pengingat yang benar-benar dijadwalkan/dikirim. Contoh “menyiapkan besok” tidak berarti menambahkan push harian otomatis. |
| budgetAIread | Ringkasan dinamis mengikuti periode. Contoh 54% dan Rp320.000 bukan nilai tetap. |
| saveError/stale | Bedakan draf lokal, menunggu koneksi, gagal server, dan sudah tersimpan; jangan memberikan keberhasilan palsu. |

Figma, PNG, dan PDF belum diubah pada tahap rancangan teknis. Penyesuaian di atas menjadi checklist naskah saat implementasi atau revisi desain berikutnya.

## Komponen dan kualitas visual

Gunakan token `design/tokens.json`, Manrope lokal, ikon SVG dan maskot dari `design/assets/ruma`. Warna dasar aplikasi #F6F7F3 berbeda dari permukaan kartu #FFFFFF. Rasio ikon 1:1 dengan BoxFit.contain, status bar memakai OS asli, bukan gambar status bar mockup.

Komponen bersama: navbar, app bar, field, tombol utama/sekunder/destruktif, kartu agenda/uang, badge, pesan AI, kartu draf, loading/empty/error, dan sheet filter/picker. Tombol Batal memakai latar netral yang jelas; Hapus memakai warna destruktif. Tidak menggambar screenshot satu frame sebagai UI aplikasi.

Navbar icon-only memiliki nama Semantics/tooltip dan status terpilih. Target sentuh minimal 48 dp. Konten, keyboard dan safe-area tidak tertutup navbar; chat composer mengikuti keyboard. Detail panjang dapat scroll, footer tindakan tetap dapat dijangkau. Teks keterangan ditargetkan dua baris pada skala normal; ukuran aksesibilitas tidak dipotong paksa untuk mempertahankan dua baris.

Animasi cukup perpindahan tab, expand Opsi lainnya, loading dan munculnya hasil/draf (sekitar 150–250 ms), mengikuti preferensi pengurangan animasi OS. Tidak menambahkan animasi panjang sebelum tindakan utama.

## Batas

Tidak ada perubahan jumlah frame atau aset baru yang diperlukan oleh pemetaan ini. Verifikasi tampilan tetap perlu dilakukan pada Flutter nyata untuk layar kecil, keyboard, nilai uang panjang, teks Indonesia, screen reader, serta skala teks besar.
