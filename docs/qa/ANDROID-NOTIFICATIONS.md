# Uji notifikasi Ruma pada HP

19 Oktober 2026 · **belum dijalankan**. Daftar ini dipakai setelah APK uji, autentikasi, registrasi perangkat, Worker pengirim, dan cron tersedia. FCM yang aktif di Console belum membuktikan notifikasi diterima HP.

## Catatan perangkat

Isi saat uji: model HP, versi Android, versi APK/commit, UID sintetis, izin notifikasi, keadaan jaringan, battery optimization, zona waktu, waktu jadwal/terima/ketuk dan notification ID. Jangan menaruh token FCM, ID token atau service account di laporan publik. Token perangkat hanya disimpan melalui mekanisme privat aplikasi/backend.

Pakai akun dan agenda sintetis. Verifikasi package `id.ruma.app` terhubung ke `mobile-app-3479f`. Izin diberikan melalui HP; bukan dimanipulasi di backend. Tidak perlu data bank atau transaksi nyata.

| Urutan | Keadaan yang diuji | Bukti kelulusan |
|---|---|---|
| 1 | Izin ditolak lalu diaktifkan dari pengaturan | Simpan agenda tetap berhasil; tidak meminta izin berulang; token/status diperbarui saat izin berubah |
| 2 | Aplikasi foreground | Satu notifikasi lokal dari pesan FCM; tidak ada kartu ganda; ID/tag sesuai sumber |
| 3 | Aplikasi background dan ditutup biasa | FCM notification+data tampil; ketukan membuka agenda yang benar melalui onMessageOpenedApp/getInitialMessage |
| 4 | Agenda 10 menit mendatang dengan pengingat 5 menit sebelumnya | Cron mengambil job jatuh tempo tanpa membuka aplikasi; catat keterlambatan aktual, bukan menjanjikan alarm presisi |
| 5 | Jadwal diubah, diselesaikan atau dihapus sebelum jatuh tempo | Job/generation lama tidak menjadi pengiriman valid; ketukan pesan yang sudah terkirim membuka keadaan terbaru |
| 6 | Ingatkan 5 menit lagi | Satu snooze lokal, tanpa mengubah waktu agenda dan tanpa mengirim FCM utama lagi |
| 7 | Logout dan ganti akun pada HP yang sama | Detail akun lama tidak terbuka; token dilepas/didaftarkan ulang; tangani logout offline sesuai rancangan |
| 8 | Token refresh/invalid, koneksi terputus dan perangkat restart | Token diperbarui atau dinonaktifkan; kegagalan dicatat; snooze direkonsiliasi tanpa duplikasi |
| 9 | Force-stop dan battery optimization | Batas Android/FCM dicatat; force-stop dibedakan dari menutup biasa, tidak diklaim pasti terkirim |
| 10 | Dua cron bersamaan dan dua perangkat satu akun | Lease/sourceVersion diperiksa; inbox memakai ID stabil; hasil per perangkat tidak mengulang perangkat yang sudah berhasil |

Untuk setiap baris simpan status lulus/gagal, waktu, screenshot HP tanpa kredensial, notification ID, serta alasan kegagalan. Selama belum ada perangkat dan backend terdeploy, status seluruh baris tetap **belum diuji**. Uji ini tidak membutuhkan panggilan model AI.
