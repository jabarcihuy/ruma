# Ruma — keputusan arsitektur versi awal

> **Aktif 20 Oktober 2026:** workspace Asisten per UID di Firestore menyimpan input, riwayat terbatas dan satu tinjauan draf/undo. Checkpoint sebelum mutasi dan receipt stabil mendukung pemulihan tanpa commit otomatis. 116 tes lokal, restart proses Android dan uji SDK produksi dua akun lulus. Rules aktif, fixture bersih, APK normal terbaru terpasang di VM. Tidak menambah SQLite, Worker atau IAM. [Hasil dan batas](ASSISTANT-MEMORY.md).

> **Status terbaru 20 Oktober 2026:** saran slot, tool baca, edit/hapus dan urungkan satu catatan per tinjauan sudah aktif. Worker/Rules dipublikasikan dengan izin pengguna; empat panggilan AI nyata lulus, fixture dibersihkan, APK normal terpasang di VM. [Hasil dan batas tahap 1–3](AGENT-STAGES-1-3.md). Catatan kandidat/belum publikasi di bawah adalah riwayat sebelum publikasi ini.

> 20 Oktober 2026: implementasi lokal agent tahap 1–3 menambah pencarian slot deterministik, tool baca dengan jawaban dihitung aplikasi, dan satu edit/hapus lama dengan urungkan per tinjauan. Kandidat Worker/Rules belum dipublikasikan; lihat [laporan tahap](AGENT-STAGES-1-3.md).

> Tahap Asisten 19 Oktober 2026 selesai: draf gabungan agenda + transaksi, tinjauan/edit/keluarkan item, dan penyimpanan atomik aktif. Rules terbit 22.52 WIB; uji SDK/UI HP dan satu panggilan AI produksi lulus, fixture dibersihkan, APK normal dipasang. Draf masih dalam memori dan jam agenda disunting manual. Status/batas: [ASSISTANT-IMPLEMENTATION.md](ASSISTANT-IMPLEMENTATION.md).

> Status pengembangan 19 Oktober 2026: fondasi Flutter Android dan Firebase Auth lulus uji emulator serta produksi pada HP. APK pratinjau telah dipasang. Bukti dan batas implementasi terkini ada di [FLUTTER-FOUNDATION.md](FLUTTER-FOUNDATION.md) dan [DEVELOPMENT-LOG.md](DEVELOPMENT-LOG.md). Pernyataan “belum dibuat” pada riwayat di bawah menggambarkan tahap perencanaan sebelumnya.

Tanggal keputusan: **18 Oktober 2026**. Status: **pilihan layanan dan batas fitur dikunci untuk persiapan implementasi**. Penyiapan layanan dan pengujian integrasi lokal telah dimulai atas permintaan pengguna; [SETUP.md](SETUP.md) mencatat keadaan aktual. Potongan proxy sudah dibuat untuk pengujian, belum seluruh backend/aplikasi Flutter.

Dokumen ini menggantikan rencana lama penyimpanan lokal saja dan penundaan cloud untuk data inti. Catatan historis dalam PRD/handoff tetap menjadi riwayat desain, bukan keputusan backend terkini.

## Pilihan yang dikunci

| Bagian | Pilihan |
|---|---|
| Aplikasi | Flutter Android |
| Akun | Firebase Authentication; daftar, masuk, dan logout berfungsi |
| Database utama | Cloud Firestore; data dipisahkan berdasarkan pemilik akun |
| Proxy AI | Cloudflare Workers Free |
| Provider AI | NaraRouter |
| Endpoint upstream | `https://router.bynara.id/v1/chat/completions` |
| Model yang diminta | `glm-5.3-flash`; ketersediaan dan tool calling harus diuji, tanpa mengganti model diam-diam |
| Push notification | Firebase Cloud Messaging (FCM), tetap termasuk cakupan |
| Pengirim otomatis FCM | Ditargetkan berjalan di Worker dengan penjadwal; kelayakan kuota perlu diuji |
| Pengingat perangkat | Notifikasi lokal sebagai pelengkap; tidak menggantikan FCM |
| Firebase Functions/Blaze | Tidak diperlukan dalam rancangan terpilih |

API key provider dan kredensial pengirim FCM hanya berada di secret backend, bukan di APK atau dokumen proyek. Tidak ada secret yang dicatat di sini.

## Pembagian tanggung jawab

Flutter mengakses Auth dan Firestore melalui SDK Firebase. Firestore menjadi sumber utama data pengguna; tidak ditambahkan database SQLite kedua sebagai sumber utama. Rincian cache/offline mengikuti rancangan data dan perlu diuji.

Flutter mengirim token login Firebase ke Worker. Worker memverifikasi identitas, memvalidasi permintaan, membatasi penggunaan, lalu memanggil NaraRouter dengan secret server. Endpoint ini bukan proxy publik yang menerima URL/model bebas dari klien.

Agent membaca konteks pengguna sesuai kebutuhan dan menyiapkan draf tindakan. Flutter memvalidasi waktu, bentrokan, nominal, dan versi data. Penambahan, perubahan, atau penghapusan baru diterapkan setelah pengguna menyetujui draf yang sedang ditampilkan. Penyimpanan kelompok perubahan harus atomik dan aman saat dicoba ulang. Form manual tetap tersedia.

Pengirim FCM berjalan di backend dan menentukan penerima dari data yang berhak diakses. Flutter menangani izin notifikasi, token perangkat, pergantian akun, dan pembukaan halaman tujuan ketika notifikasi diketuk. Menyimpan data di Firestore saja tidak otomatis mengirim push.

## Pengamanan dan keandalan yang termasuk implementasi

- Firestore Security Rules membatasi akses ke data pemilik akun. Token login untuk Worker tetap diverifikasi terpisah.
- Permintaan AI memiliki validasi, batas penggunaan, timeout, serta keadaan gagal/coba lagi.
- Draf yang berubah atau datanya sudah diperbarui tidak boleh disimpan menggunakan persetujuan lama. Percobaan ulang tidak menggandakan agenda/transaksi.
- Notifikasi yang sama tidak dikirim berulang; perubahan jadwal membatalkan atau memperbarui pengingat terkait. Push dan notifikasi lokal memiliki aturan pembagian agar tidak menduplikasi pengingat.
- Riwayat operasi, draf, dan data tersimpan tetap dibatasi per pengguna; logout tidak membuka data akun sebelumnya.
- Beranda, agenda, riwayat keuangan, dan laporan menggunakan data tersimpan yang sama. Nilai contoh desain tidak menjadi data pengguna sungguhan.

Ini kebutuhan teknis dari fitur yang sudah disepakati, bukan tambahan halaman atau fitur produk.

## Batas biaya dan kelayakan

Firebase memakai Spark untuk layanan yang mendukungnya, dalam kuota gratis. FCM tidak dikenakan biaya layanan pengiriman; penggunaan database tetap mengikuti kuota Firestore. Tidak ada billing atau paket berbayar yang diaktifkan oleh keputusan ini.

Workers Free saat keputusan ini dibuat menyediakan 100.000 request/hari per akun dan batas CPU 10 ms per request. Menunggu jaringan tidak dihitung sebagai waktu CPU. Verifikasi token, pemrosesan payload, dan tugas notifikasi tetap harus diukur; kuota request besar tidak menjamin semua beban cocok dengan batas CPU. Jangan menurunkan validasi agar lolos kuota. Jika uji tidak memenuhi batas, laporkan hasil dan tinjau hosting sebelum implementasi dilanjutkan di jalur tersebut.

Hosting proxy gratis tidak mencakup biaya model NaraRouter. Jangan menjanjikan biaya total selalu nol. Penjadwal harus mengambil hanya pengingat yang jatuh tempo, bukan membaca semua data pengguna setiap menit.

## Status persiapan teknis

Rancangan tertulis berikut sudah diselesaikan pada 18 Oktober 2026:

- [Firebase dan data](FIREBASE-DATA.md): koleksi, field, query/indeks awal, kebijakan Rules, akun sementara, offline, atomik dan urungkan.
- [Agent dan proxy](AGENT-PROXY.md): tool, kontrak endpoint, draf, persetujuan, secret dan batas penggunaan.
- [Notifikasi](NOTIFICATIONS.md): FCM utama, antrean/lease, seri berulang, retry, token dan pelengkap lokal.
- [Pemetaan layar](SCREEN-MAP.md): 71 frame dan 10 konteks menjadi 27 jenis halaman serta komponen/keadaan bersama.
- [Penerimaan](ACCEPTANCE.md): skenario sintetis dan kriteria pengujian; bukan laporan aplikasi sudah lulus.
- [Urutan build](BUILD-PLAN.md): struktur Flutter, kandidat package, konfigurasi yang belum tersedia, dan rencana enam minggu.

19 Oktober 2026: service account/Secret dan proxy cloud sudah diterapkan setelah persetujuan. JWT Firebase asli, dua skenario AI dan penolakan kuota cloud berhasil; [hasil CPU](qa/CLOUD-INTEGRATION.md) masih 13 ms pada sampel awal vs nominal Free 10 ms. Gate CPU belum lulus. Kandidat Rules hanya lulus emulator dan belum dideploy; Fondasi Flutter/Auth sudah diuji pada HP; ledger, FCM dan cron belum diimplementasikan. Tidak mengaktifkan billing. Keberhasilan potongan cloud bukan kelulusan seluruh arsitektur.

Tidak perlu menambah fitur produk atau memperbanyak frame. Rancangan tersedia untuk ditinjau; kelayakan integrasi belum boleh dianggap sudah terbukti hanya berdasarkan dokumen.

## Referensi resmi

- [Firebase Pricing](https://firebase.google.com/pricing)
- [Cloudflare Workers Pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Workers Secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Workers Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/)
- [Firebase token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [FCM server environment](https://firebase.google.com/docs/cloud-messaging/server-environment)
- [NaraRouter API](https://router.bynara.id/id/docs)

## Kandidat tahap akhir 1–3 — 21 Oktober 2026

Profil/preferensi memakai store Firestore per UID dan revision CAS. Seri mingguan disimpan sebagai satu dokumen dengan pengecualian/perubahan fase berbatas; ekspansi tanggal dan konflik tetap di repository. Worker kandidat memakai occurrenceDate/cursor pengingat; tidak melakukan panggilan AI lewat cron. Snooze adalah antrean notifikasi lokal kecil dengan validasi server, bukan database agenda/keuangan atau jaminan offline. Belum dipublikasikan; status serta batasan lengkap di FINAL-STAGES-1-3.md.

Status publikasi kandidat di atas: Rules final-stages dan Worker 774700f2 aktif, profil/isolasi dan penerimaan FCM terverifikasi; APK normal terbaru terpasang di VM. Verifikasi AI produksi masih gagal HTTP 502, bukan exceededCpu. Detail serta batas bukti di FINAL-STAGES-1-3.md. Tidak mengklaim seluruh uji cloud lulus.

Pembaruan diagnosis AI 21 Oktober 2026: Worker 359dcc2b memakai klarifikasi incomplete_draft untuk output model yang tidak valid atau kehilangan kalimat bermakna dalam proposal. Nol item dikirim pada klarifikasi. Flutter mengenali reason allowlist baru; semua validasi/approval/metering tetap. Guard cakupan bukan bukti pemahaman NLP lengkap. Replay Worker dan SDK produksi lulus, kualitas draf gabungan model live sesudah fix belum terverifikasi; lihat FINAL-STAGES-1-3.md.
