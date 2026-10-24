# Ruma — kontrak agent dan proxy AI

> **Status terbaru 20 Oktober 2026:** saran slot, tool baca, edit/hapus dan urungkan satu catatan per tinjauan sudah aktif. Worker/Rules dipublikasikan dengan izin pengguna; empat panggilan AI nyata lulus, fixture dibersihkan, APK normal terpasang di VM. [Hasil dan batas tahap 1–3](AGENT-STAGES-1-3.md). Catatan kandidat/belum publikasi di bawah adalah riwayat sebelum publikasi ini.

> 20 Oktober 2026: kandidat tool baca, saran slot serta edit/hapus/urungkan sedang diuji lokal. Belum dipublikasikan. Perilaku dan batas tahap ini: [AGENT-STAGES-1-3.md](AGENT-STAGES-1-3.md). Bagian status create-only berikut menggambarkan versi produksi sebelumnya.

19 Oktober 2026. Proxy create-draft, autentikasi dan kuota sudah aktif. Flutter draf gabungan aktif; Rules produksi terbit 22.52 WIB dan satu panggilan model nyata beserta commit/retry/isolasi UID lulus pada HP. Fixture tahap ini sudah dibersihkan dan APK normal terpasang. [ASSISTANT-IMPLEMENTATION.md](ASSISTANT-IMPLEMENTATION.md) menjadi acuan perilaku yang benar-benar tersedia; bagian di bawah tetap spesifikasi target untuk kemampuan lanjutan.

Implementasi saat ini hanya memakai `prepare_draft` untuk **create_agenda/create_transaction**, satu pesan per panggilan, tanpa pembacaan ledger oleh model. Jam agenda disunting pengguna, bukan diklaim hasil pencarian slot. Approval dan commit dilakukan Flutter. Belum ada tool baca/edit/hapus lama, undo, atau percakapan multilangkah. Draf belum dipersistenkan. CPU tetap ditunda menurut [keputusan pengguna](qa/CPU-FOLLOWUP.md).

## Peran agent

Agent mengurangi pengetikan untuk agenda dan uang: memahami pesan, membaca konteks yang relevan, meminta klarifikasi, menawarkan waktu/durasi, dan menyiapkan draf. Manfaat utamanya adalah satu pesan menghasilkan beberapa agenda dan transaksi yang diperiksa dalam satu tinjauan. Tidak ada klaim melatih ulang model pengguna atau mengambil data LMS/bank secara otomatis.

Alur: **pesan → identifikasi kebutuhan → baca data/tool → klarifikasi bila perlu → draf → pengguna meninjau → validasi terbaru → commit → hasil/urungkan**. Permintaan baca saja langsung menampilkan hasil berdasarkan data yang dibaca, tanpa membuat transaksi palsu atau meminta persetujuan untuk membaca.

## Tool target untuk tahap lanjutan

Tool ini dijalankan oleh Flutter pada repository milik UID aktif. Worker meneruskan percakapan model tetapi tidak menerima SQL, URL, perintah shell, atau fungsi bebas. Definisi tool disediakan backend; klien tidak dapat menggantinya.

| Tool | Masukan inti | Keluaran |
|---|---|---|
| `list_agenda` | rentang UTC, filter jenis/status opsional | ID, nama, waktu, deadline, versi, seri/pertemuan yang relevan |
| `find_free_slots` | durasi, tanggal/rentang, jam yang diizinkan, zona waktu, item draf yang harus dipertimbangkan | maksimal tiga slot, revisi agenda, alasan terukur atau tidak ada slot |
| `list_transactions` | rentang tanggal lokal, jenis/kategori opsional | maksimal 20 item per halaman, cursor, indikator hasil belum lengkap |
| `get_money_summary` | periode dan kategori opsional | pemasukan, pengeluaran, saldo tercatat, batas/sisa anggaran, porsi kategori, cakupan data |
| `prepare_draft` | daftar tindakan terstruktur dan rujukan target | draf tervalidasi, field yang kurang, revisi dasar; tidak melakukan commit |

Tindakan draf yang ditargetkan pada rancangan lengkap: `create_agenda`, `update_agenda`, `delete_agenda`, `create_transaction`, `update_transaction`, `delete_transaction`. Status selesai agenda termasuk update. Mengubah seri menyertakan `scope` dan occurrence key. Tidak menambahkan tool edit profil, transfer bank, hapus akun, atau otomatisasi bebas.

Tool baca tidak boleh melampaui akun aktif walaupun model menyebut UID/path lain. Batasi rentang dan jumlah hasil; pembacaan sebagian diberi indikator, bukan diklaim lengkap. Angka ringkasan dihitung aplikasi/repository, bukan dihitung ulang dari dugaan model.

## Payload draf

Field wajib: `draftId`, `revision`, `originMessageId`, `baseAgendaRevision`, `baseFinanceRevision`, `items`, `state`. Tiap item mempunyai `itemId`, `action`, `targetId` untuk edit/hapus, `expectedVersion`, `values`, `reason`, `suggestedFields`, dan `included`.

`suggestedFields` membedakan durasi/waktu/kategori yang diperkirakan dari nilai yang disebut pengguna. Pengguna bebas mengubah nilai yang disarankan. Tanggal relatif diselesaikan menggunakan waktu sekarang dan zona pengguna; pesan “besok” dari riwayat lama tidak ditafsirkan ulang terhadap hari baru.

Tahap awal batch gabungan hanya penambahan, maksimal tiga agenda dan tiga transaksi. Jika pesan melebihi batas, tanyakan kelompok mana yang diproses dahulu; jangan diam-diam mengabaikan sisanya. Mutasi item lama memakai tinjauan terpisah. Anggaran dapat diatur lewat form; agent membaca anggaran dan dapat menyarankan batas lewat jawaban, tetapi tool perubahan anggaran belum ditambahkan tanpa kebutuhan UI yang disepakati.

Untuk create, ID target dibuat aplikasi sebelum simpan. Untuk edit/hapus, hanya pakai ID hasil tool yang benar; judul sama memerlukan klarifikasi. Field `approved`, `committed`, atau `ownerUid` dari keluaran model tidak diterima sebagai kewenangan.

## State dan persetujuan

`collecting → needs_clarification / reviewable → saving → applied`. Cabang lain: `cancelled`, `failed`, `stale`; operasi applied dapat menjadi `undone` bila masih sah.

- Tinjauan menampilkan item, tanggal/waktu/durasi atau nominal/kategori, serta bagian yang masih kurang. Menutup tinjauan tidak sama dengan setuju.
- Edit atau keluarkan/pulihkan item menaikkan revisi draf; draf kosong tidak dapat disimpan. Draf belum menyentuh ledger.
- Klik Simpan menyetujui revisi yang tampak, kemudian validasi data terbaru. Jika slot/target berubah, tampilkan perubahan dan minta persetujuan baru. Jangan otomatis mengganti ke slot lain.
- Satu item tidak mendapat slot boleh disimpan sebagai belum terjadwal jika pengguna menyetujui keadaan itu. Nominal yang belum jelas tidak boleh menjadi nol atau angka karangan.
- Kegagalan simpan mempertahankan seluruh draf. Retry memakai ID operasi yang sama dan tidak menggandakan item. Hasil dibaca dari receipt operasi tersimpan.
- Batal tidak melakukan mutasi. Urungkan mengikuti validasi versi dan transaksi atomik dalam spesifikasi data.

## Kontrak endpoint Worker

Satu endpoint AI: **POST `/v1/agent/turn`**. Tidak membuat server CRUD kedua untuk agenda/uang. Data tersebut tetap diakses melalui Firebase SDK dengan Rules.

Header: Firebase ID token sebagai Bearer, JSON Content-Type, ID request. Body versi 1 memuat `requestId`, `conversationId`, `turnId`, `timezone`, `clientNow`, `messages`, dan hasil tool yang diperlukan. Identitas pengguna diperoleh dari token, bukan dari body. Batas awal body 64 KiB, satu pesan pengguna 4.000 karakter, dan konteks maksimal 12 pesan terbaru termasuk pasangan tool yang utuh. Jika konteks tidak muat, minta ringkasan/penyempitan; jangan memotong pasangan tool atau klaim melihat riwayat penuh.

Respons versi 1 adalah salah satu dari `tool_requests`, `answer`, `clarification`, `draft_proposal`, atau `error`, dengan request ID dan isi terstruktur. `tool_requests` memuat tool call ID, nama allowlist, dan argumen yang lolos schema. Respons model mentah tidak boleh dianggap perintah simpan.

Proses satu percakapan maksimal empat panggilan model dan enam tool read/prepare; mencapai batas menghasilkan penjelasan dengan data/draf yang sudah ada, bukan loop tanpa batas. Teks atau hasil tool tidak dapat mengganti instruksi sistem. Tool gagal dikembalikan sebagai error data, bukan hasil sukses kosong.

Panggilan upstream selalu menuju `https://router.bynara.id/v1/chat/completions`, dengan model tetap `glm-5.3-flash`, key dari secret, dan format Chat Completions. Klien tidak memilih endpoint upstream. Pemilihan model lain membutuhkan keputusan baru jika model ini tidak tersedia/berfungsi. Streaming ditunda pada implementasi awal; indikator memproses tetap ada. Tentukan batas output setelah uji model agar jawaban tidak terpotong akibat budget reasoning; jangan menjanjikan nilai token yang belum didukung.

Timeout awal 45 detik per upstream dan 90 detik per rangkaian turn, dapat disesuaikan dari hasil uji. Pengguna dapat membatalkan. Pembatalan tampilan tidak menjamin provider membatalkan komputasi atau biaya. Jangan mengulang request model otomatis setelah timeout yang hasilnya tidak diketahui.

Kode error aplikasi: `unauthenticated`, `permission_denied`, `invalid_request`, `rate_limited`, `provider_timeout`, `provider_unavailable`, `invalid_model_output`, `tool_limit`, `stale_data`. HTTP 401 meminta refresh ID token sekali; tetap gagal mengarah ke masuk kembali tanpa menghapus draf. HTTP 429 menampilkan waktu coba lagi. Jangan mencetak API key, token, isi keuangan, atau prompt lengkap di log.

## Identitas, secret, dan pembatasan biaya

Worker memverifikasi signature token Firebase, issuer, audience proyek, expiry, subject, serta waktu yang masuk akal. Cache public key mengikuti cache header dan refresh ketika kid berubah. Token tidak cukup hanya di-decode. Auth anonymous dikenali dari claim resmi, bukan flag body.

Secret yang diperlukan: provider API key; service account untuk akses REST Firestore kuota/pengirim FCM. Project ID, model, dan endpoint bukan secret. Service account tidak diberikan role Owner/Editor. JWT Google untuk OAuth dibuat dengan API crypto runtime; kompatibilitas serta CPU diverifikasi sebelum memilih dependency.

Kuota awal: akun email maksimum 10 panggilan upstream/menit dan 100/hari; akun sementara 5/menit dan 10/hari. Hitung **panggilan model**, bukan pesan UI. Angka ini batas aplikasi yang diusulkan, bukan kuota NaraRouter atau Cloudflare. Sesuaikan terhadap paket provider sebelum uji orang lain. Jangan memperlakukan UID baru sebagai satu manusia; tambahkan batas global harian proyek untuk mencegah banyak akun menghabiskan provider. Batas global belum dapat ditentukan tanpa informasi paket/saldo provider.

Counter kuota disimpan server-only di Firestore dan diperbarui atomik sebelum request upstream; bukan variabel memory Worker yang hilang saat instance berganti. Kunci kuota meliputi hari UTC dan bucket menit. Counter global per menit/hari menambah biaya operasi database yang harus masuk perhitungan, tetapi tidak perlu database layanan lain. Tidak menyimpan prompt dalam counter. Request yang sudah diteruskan dapat memakai kuota meskipun klien timeout; UI menjelaskannya saat coba lagi.

App Check untuk distribusi APK di luar Play Store dicatat sebagai penguatan yang perlu diuji terhadap signing/Play Integrity, bukan dianggap otomatis aktif atau syarat memakai token debug dalam APK release. Auth terverifikasi, validasi input, dan rate limit tetap wajib meskipun App Check belum diterapkan.

## Personalisasi dan penggunaan data

Persetujuan pemakaian AI menjelaskan bahwa pesan dan konteks terpilih dikirim ke NaraRouter/model. Izin personalisasi terpisah mengatur apakah durasi yang dipilih/diubah pengguna dari riwayat boleh membantu saran. Mematikannya tidak menghilangkan agent dasar.

Gunakan panjang sesi nyaman dan median maksimal 20 durasi rencana dari kegiatan sejenis yang diizinkan sebagai konteks saran, dengan label perkiraan. Tidak ada durasi aktual, skor produktivitas palsu, atau klaim model melatih dirinya. Jika datanya sedikit, jelaskan menggunakan preferensi/durasi yang disebut pengguna. Riwayat kosong tidak menampilkan contoh 12 sesi/42 menit sebagai fakta.

Jangan mengirim semua profil, seluruh ledger, token perangkat, ID token, atau kredensial Firebase ke provider. Untuk ringkasan uang kirim agregat periode; rincian transaksi hanya yang relevan dengan permintaan. Deskripsi kegiatan/transaksi adalah data tidak tepercaya, bukan instruksi tool baru.

## Gerbang kompatibilitas sebelum integrasi

**Hasil terkini setelah perbaikan:** [5/5 kasus](qa/agent-policy-check.json) lulus dengan instruksi baru dan pemeriksaan hasil yang dipakai bersama oleh uji dan potongan Worker. Dua pengulangan rencana besok dan satu rencana tanpa tanggal meminta klarifikasi; kejadian aktual serta dua agenda+dua transaksi tetap menjadi draf. Field proposal `transactionStatus` dan `sourceQuote` membantu menolak status rencana/tanggal masa depan. Pendeteksian kata rencana bersifat konservatif, bukan pemahaman bahasa yang terjamin. Semua draf tetap perlu ditinjau pengguna. Teks “Draf siap ditinjau. Data belum disimpan.” berasal dari kode; model tidak memiliki tool commit.

Uji terpisah [max_tokens 8192](qa/agent-output-limit-check.json) lulus pada skenario gabungan (HTTP 200, finish_reason tool_calls, 1184 completion tokens). Potongan Worker kini memakai batas tersebut dan menolak keluaran terpotong. Pengaturan reasoning/streaming belum diisolasi. Bukti kegagalan awal di bawah tetap dipertahankan sebagai riwayat, bukan status terbaru.

Potongan `backend/` baru menerima satu pesan untuk membuat draf, belum seluruh protokol multi-pesan/tool baca/slot/edit/hapus yang dirancang di atas. Uji emulator kuota membatasi tiga dari delapan permintaan serentak. Uji cloud berikutnya membuktikan OAuth/IAM nyata, token Firebase asli, respons AI dan kuota; cap global kini 10/hari UTC. CPU sampel awal setelah optimasi 11 ms dan berikutnya 4 ms, sehingga T02 belum lulus nominal Free 10 ms. Semua fetch memakai `redirect:manual` dan menolak non-2xx karena Workers tidak mendukung `error`. Lihat [panduan backend](../backend/README.md) serta laporan cloud untuk membedakan bukti lokal dan remote.

Secret tersedia pada berkas lokal privat dan tidak dicetak. [Hasil uji provider](qa/nararouter-check.json) membuktikan model tepat tersedia, pesan biasa berhasil, tool `get_money_summary` dipanggil dengan argumen benar, hasil tool dibaca menjadi sisa anggaran Rp320.000, dan satu pesan dipecah menjadi dua agenda serta dua pengeluaran sesuai fixture. Lima dari enam pemeriksaan dasar lulus; ini belum membuktikan keandalan agent aplikasi.

Kasus “Besok mau beli buku 50 ribu” belum lulus: model memanggil tool alih-alih meminta klarifikasi terlebih dahulu. Tidak ada penyimpanan database dalam pengujian. Jangan meloloskan draf transaksi masa depan hanya karena format JSON valid; pisahkan rencana dari transaksi aktual, minta klarifikasi atas status transaksi, lalu tetap wajibkan tinjauan pengguna sebelum simpan. Kasus ini harus diuji ulang saat kontrak dan validasi agent diimplementasikan.

Satu [uji diagnostik ulang](qa/nararouter-future-diagnostic.json) dengan input dan prompt yang sama menghasilkan klarifikasi tanpa tool call, tetapi pembuka “saya catat dulu sebagai rencana” menyiratkan penyimpanan yang tidak terjadi. Hasil ini menunjukkan perilaku belum konsisten; jangan menimpa hasil gagal pertama dengan klaim lulus. Argumen tool pada kegagalan pertama tidak terekam sehingga tidak dapat disimpulkan bahwa model saat itu membuat pengeluaran. Saat tidak ada penyimpanan, jawaban harus mengatakan “Ini masih rencana. Mau dijadikan agenda?” tanpa klaim sudah mencatat.

Payload minimal `model` + `messages` (+ `tools` saat diperlukan) berhasil tanpa `tool_choice` paksa. Percobaan sebelumnya yang menyertakan `stream:false`, `reasoning_effort:none`, dan `max_tokens` bersama-sama ditolak HTTP 400; parameter penyebab belum diisolasi. Bukti: [percobaan awal](qa/nararouter-initial-check.json), [probe minimal](qa/nararouter-minimal-probe.json). Jangan menganggap pembatasan output atau pengaturan reasoning sudah kompatibel. Penghapusan parameter merupakan diagnosis, bukan profil produksi yang sudah dibatasi biaya.

Latensi contoh yang berhasil sekitar 6–30 detik per request; ekstraksi gabungan memakai 4.932 completion tokens menurut provider. Angka ini hanya sampel, bukan SLA. Uji batas output, timeout, biaya, dan CPU Worker masih diperlukan sebelum distribusi.

1. Model tepat tersedia dan request pesan biasa berhasil.
2. Model menghasilkan tool call dengan nama/argumen yang sesuai; parsing gagal ditangani tanpa mutasi.
3. Hasil tool dengan call ID/role yang benar dapat dilanjutkan menjadi jawaban/draf.
4. Dua agenda dan dua transaksi bisa dikenali; pekerjaan masa depan tidak menjadi pengeluaran aktual.
5. Worker dengan verifikasi token dan quota check tetap dalam batas CPU gratis, termasuk cold start/kid baru dan payload maksimum.
6. Timeout, limit provider, output terpotong, dan error format mengembalikan kegagalan yang bisa dipulihkan.

Jika tool calling model tidak kompatibel, jangan menyebut chatbot biasa sebagai agent yang sudah selesai. Pertahankan pengerjaan manual yang independen dan laporkan hasil; perubahan model/protokol diputuskan berdasarkan bukti.

## Referensi

- [NaraRouter API](https://router.bynara.id/id/docs)
- [Verifikasi ID token Firebase](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/), [Secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Firestore REST authentication](https://firebase.google.com/docs/firestore/use-rest-api)
