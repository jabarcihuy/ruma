# Ruma — draf gabungan melalui Asisten

> **Status terbaru 20 Oktober 2026:** saran slot, tool baca, edit/hapus dan urungkan satu catatan per tinjauan sudah aktif. Worker/Rules dipublikasikan dengan izin pengguna; empat panggilan AI nyata lulus, fixture dibersihkan, APK normal terpasang di VM. [Hasil dan batas tahap 1–3](AGENT-STAGES-1-3.md). Catatan kandidat/belum publikasi di bawah adalah riwayat sebelum publikasi ini.

> Pembaruan 20 Oktober 2026: kandidat saran waktu, pembacaan dan edit/hapus/urungkan dibahas dalam [AGENT-STAGES-1-3.md](AGENT-STAGES-1-3.md). Dokumen ini menyimpan hasil tahap create-only yang telah dipublikasikan sebelumnya.

19 Oktober 2026. Cakupan dipilih pengguna: **draf gabungan agenda + uang dahulu**. **Selesai dan aktif:** Flutter, Rules produksi, uji SDK/UI HP, satu panggilan model nyata, cleanup fixture, serta APK normal Asisten. Ini kelulusan tahap create-only, bukan seluruh aplikasi/release final.

## Perilaku aplikasi

- Tab Asisten menerima satu pesan, maksimal 4.000 karakter. Sebelum pengiriman pertama dalam sesi, pengguna menyetujui pemrosesan pesan oleh NaraRouter melalui proxy Ruma.
- Hanya pesan yang diketik dikirim. Token Firebase dikirim ke proxy untuk autentikasi, bukan ke provider. Tidak mengunggah ledger, profil, atau seluruh agenda.
- Respons diperiksa terhadap request ID, tipe yang didukung, bentuk field, kutipan persis pesan asal, tanggal, nominal integer, kategori, dan durasi. Model tidak diberi hak menulis Firestore.
- Satu draf maksimal tiga agenda dan tiga transaksi aktual. Rencana belanja atau status uang belum jelas meminta klarifikasi. Klarifikasi tahap ini memerlukan pengiriman ulang pesan lengkap; proxy belum menjalankan percakapan multilangkah berkonteks.
- Pengguna bisa membuka form bersama untuk mengubah item tanpa langsung menyimpannya, mengeluarkan/memasukkan item, dan memulihkan semua item. Perubahan menaikkan revisi draf dan mengganti identitas persetujuan simpan.
- Tombol **Simpan semua terpilih** menyimpan item pilihan, ringkasan bulan, saldo/revisi, dan receipt operasi dalam satu transaksi Firestore. Membatalkan draf tidak mengubah ledger.
- Angka Beranda dan Keuangan dimuat ulang dari repository setelah penyimpanan berhasil. Tidak ada panggilan model saat tombol Simpan ditekan.
- Bila hasil commit belum pasti karena koneksi, pengeditan draf dikunci dan percobaan ulang memakai ID yang sama. Receipt mencegah penambahan ganda untuk operasi yang sama. Data yang sudah berubah atau waktu berbenturan membatalkan operasi.
- Logout/pergantian UID membuang store lama, menutup HTTP client, dan mengabaikan jawaban terlambat.

## Jam agenda: batas yang ditampilkan secara jelas

Proxy aktif hanya mengembalikan tanggal acuan dan durasi untuk agenda; belum memberikan jam mulai, deadline, jenis kuliah, atau hasil pencarian slot kosong. Item AI awal berupa task **Belum dijadwalkan**. Tanggal acuan terlihat dalam tinjauan, tetapi tanpa jam kegiatan disimpan sebagai task tanpa waktu, mengikuti model agenda yang sudah ada. Pengguna dapat mengatur jam/deadline melalui **Ubah**; aplikasi memeriksa bentrokan sebelum commit. UI tidak mengaku sudah menemukan jam kosong.

## Implementasi

| Bagian | Sumber |
|---|---|
| Validasi proposal dan revisi draf | `lib/data/assistant_draft.dart` |
| HTTPS ke endpoint tetap dan token Firebase | `lib/data/assistant_service.dart` |
| Lifecycle pengiriman, persetujuan, pengeditan dan retry | `lib/data/assistant_store.dart` |
| Server preflight + transaksi atomik/idempotensi | `lib/data/draft_repository.dart` |
| Chat awal, tinjauan bersama dan hasil simpan | `lib/features/assistant/assistant_page.dart` |
| Form manual yang juga bisa mengembalikan edit draf | `agenda_form.dart`, `finance_forms.dart` |
| Kandidat Rules tahap ini | `config/firebase/firestore.agent.rules` |
| Konfigurasi emulator kandidat | `firebase.agent.json` |

Tidak menambah package runtime. HTTP memakai `dart:io`; timestamp WIB, rupiah integer, form, store, dan aset memakai implementasi proyek yang sudah ada. Transaksi buatan AI memiliki `source: ai`; edit manual berikutnya mempertahankan provenance tersebut. Pencatatan manual baru tetap `source: manual`.

Kandidat Rules mempertahankan CRUD manual, memvalidasi daftar target baru (maksimal 3+3, unik, tidak dapat menimpa entitas), mengharuskan receipt/core/bulan terhubung, serta menghitung selisih saldo dan setiap kategori dari transaksi yang benar. Tidak membuka akses lintas UID, counter server, reminder, perangkat, atau chat persisten. Pengguna mengizinkan publikasi dan uji produksi. Rules gabungan Asisten terbit pukul **22.52 WIB**, dan `firebase.json` kini menunjuk `firestore.agent.rules`; versi keuangan sebelumnya tetap tersimpan sebagai snapshot. Komentar kandidat pada file Rules adalah catatan persiapan; bukti publikasi menjadi acuan status aktif.

## Acuan visual dan bukti

Figma: `37:6752` (Asisten), `279:5001` (tinjauan gabungan), serta form bersama yang sudah digunakan aplikasi. Mengadaptasi auto-layout ke widget responsif dan memakai aset lokal, bukan screenshot desain sebagai UI. Indikator review 6×6 diekspor langsung melalui URL aset MCP ke `design/assets/ruma/assistant/review-dot.svg`; maskot dan ikon menggunakan aset proyek yang sama. Status bar sistem memakai Android asli.

- `qa/assistant/render-chat.png` dan `render-review.png`: render widget dengan font Manrope asli; bukan bukti uji cloud/perangkat.
- `qa/assistant/flutter-tests.log`: unit/widget dan pemeriksaan render.
- `qa/assistant/batch-rules.json` dan `.tap`: uji Rules nyata pada emulator.
- `qa/assistant/finance-regression.json`, `agenda-regression.json`: regresi Rules manual pada kandidat yang sama.
- `qa/assistant/backend-regression.tap`: regresi proxy tanpa memanggil provider.
- `qa/assistant/analyze.log`, `build.log`, `apk-inspection.json`: analyzer, build, hash dan pemeriksaan rahasia APK.

## Hasil uji lokal

- 23 unit/widget/render Flutter lulus, termasuk parser menolak kutipan palsu dan tindakan tidak didukung; persetujuan; revisi; retry stabil; hasil terlambat setelah dispose; form edit draf tidak menyimpan; lebar 320 px dan teks 200%.
- 10 uji batch Rules lulus: 3+3 pada satu/tiga bulan, satu domain, atomic rollback, dependensi hilang, aritmetika palsu, batas manifest, UID, ledger yang sudah ada, dan target tambahan.
- 16 regresi Rules keuangan + 12 regresi Rules agenda lulus. Satu percobaan regresi awal memakai asumsi suite lama bahwa pembacaan transaksi belum diizinkan; kondisi pemilihan kandidat tes diperbaiki, tanpa melonggarkan Rules.
- 14 regresi backend lulus. Tidak memanggil model dan tidak mengubah Worker.
- Skrip SDK/UI Android emulator: `integration_test/assistant_flow_test.dart` + `test_driver/assistant_test.dart`, hanya menerima `AUTH_EMULATOR=true`. **Lulus pada HP USB**: enam item atomik, retry, stale revision, overlap, offline, edit manual mempertahankan source AI, edit form draf tanpa simpan, keluarkan item, dan simpan hasil tinjauan. Bukti `qa/assistant/device-results.json` serta tiga screenshot `01-assistant.png`, `02-review.png`, `03-applied.png`. Percobaan awal terganggu layar Dozing/terkunci lalu USB terputus; log dipertahankan sebagai `device-first-interrupted.log`, tidak dihitung lulus. Percobaan setelah pengguna membuka kunci selesai 13 detik; pengaturan keep-awake selama USB sudah dikembalikan ke nilai semula (0).

## Verifikasi produksi — lulus

`integration_test/assistant_cloud_test.dart` mewajibkan `ASSISTANT_LIVE_TESTS=true`, Firebase produksi, akun sintetis, dan satu panggilan model maksimal. Menguji tidak ada catatan sebelum persetujuan, satu agenda + satu transaksi, commit/retry tanpa duplikasi, saldo dan penolakan akun lain/tanpa login. Tidak otomatis mengulang panggilan model.

`backend/tests/assistant-cloud-cleanup.mjs` hanya menerima manifest suite tersebut, project `mobile-app-3479f`, 1–2 UID sintetis yang akun Auth-nya sudah dihapus, serta maksimal 20 dokumen per subkoleksi. Tidak memindai seluruh pengguna dan tidak menghapus counter kuota atau data pengguna lain. Izin diberikan sebelum publikasi dan eksekusi. Suite cloud **lulus dalam 23 detik**, memakai tepat satu panggilan model. Dua akun Auth sintetis dihapus melalui SDK; lima dokumen agenda/transaksi/bulan/core/receipt dibersihkan dan semua subkoleksi fixture diverifikasi kosong. Counter kuota dipertahankan. Bukti: `qa/assistant/cloud-results.json`, `cloud-cleanup.json`, `cloud-test.log`, dan `rules-published.jpg`. Tidak mengubah akun/data lain maupun menyelesaikan fixture Auth historis dari tahap lama.

## Batas tahap ini

Draf dan persetujuan AI disimpan dalam memori per sesi, belum persisten setelah aplikasi ditutup paksa. Idempotensi berlaku pada **draf dan operation ID yang sama**, bukan deduplikasi semantik semua pesan baru setelah restart. Tidak menambahkan klaim pelatihan ulang model per pengguna.

Belum termasuk baca/edit/hapus catatan lama melalui AI, penjadwalan otomatis, percakapan berkonteks, undo, riwayat percakapan persisten, notifikasi, dan pengulangan agenda. Form manual tetap tersedia. Tidak menambahkan SQLite, mengubah IAM/billing, atau mengerjakan optimasi CPU yang ditunda pengguna.

## APK dan status akhir

APK normal profile ARM64 `output/apk/ruma-assistant-preview.apk` (40.8 MB, target `lib/main.dart`) berhasil dipasang dan cold launch. Bukan test harness dan bukan release final. Hash sama dengan kandidat yang sudah dipindai; kecocokan exact API key/private key UTF-8/UTF-16 = 0, tidak ada file privat di APK. Bukti install/launch: `qa/assistant/normal-install.log`; bukti hash: `apk-inspection.json`.

Saat menunggu izin, APK keuangan sebelumnya sempat dipulihkan agar HP tidak ditinggalkan dengan harness. Setelah uji cloud selesai, APK Asisten normal menggantikannya. Fixture emulator dibersihkan, server dihentikan, reverse port uji dilepas, dan pengaturan layar dikembalikan ke 0. Tidak ada model retry otomatis, billing/IAM/Worker baru, atau optimasi CPU pada tahap ini.

## Langkah berikutnya

Tahap yang dipilih sudah selesai. Kemampuan baca/edit/hapus catatan lama melalui AI menjadi potongan berikutnya; pencarian slot waktu, notifikasi dan seri mingguan masih memerlukan implementasi serta uji tersendiri. Jangan menganggap kemampuan tersebut aktif hanya karena tercantum dalam rancangan lengkap.
