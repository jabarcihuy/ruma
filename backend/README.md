# Ruma — backend agent dan pengingat

Release 27 Oktober 2026 mempertahankan v1 dan menambahkan `/v2/agent/turn`, `/v2/agent/schedule` (multipart gambar), serta `/v2/agent/schedule/correct`. Seluruh endpoint memakai autentikasi dan kuota yang sama; model tidak mendapat akses tulis database. Worker produksi `ruma-api` aktif pada versi `da716d11`; tiga probe model live dengan data sintetis lulus dan lima request tanpa autentikasi/credential palsu ditolak. `npm test` mencakup 43 tes offline. Hasil publish dan batas verifikasi: [laporan implementasi](../docs/ASSISTANT-CHAT-IMPORT-IMPLEMENTATION.md).

> Pengingat produksi: Rules, indeks, NOTIFICATIONS_ENABLED=true dan cron setiap menit sudah aktif. Versi Worker aktif c3759e9e-c2d6-4004-a2be-e6009ad04fe5; kode pengingat37c46502. FCM foreground serta background/tap terbukti di AVD. [Status dan batas terbaru](../docs/NOTIFICATION-IMPLEMENTATION.md).

> Riwayat agent sebelum publikasi pengingat, 20 Oktober 2026: allowlist `prepare_draft`, `read_records`, `prepare_change`, `ask_clarification` aktif pada Worker `f0bc9c39`. Empat panggilan model produksi beserta edit/hapus/undo SDK Android lulus. Rules pemulihan persis sudah dipublikasikan. [Bukti dan batas](../docs/AGENT-STAGES-1-3.md). Bagian status lama di bawah merupakan riwayat persiapan awal.

Worker agent dan pengingat terhubung ke aplikasi Flutter. Cakupan aktual serta pengujian terbaru dicatat pada laporan implementasi. Paket dikunci di package-lock.json dan menggunakan Node 24.19.0.

## Yang tersedia

- Instruksi model, schema draf create, kutipan sumber dan pemeriksaan status transaksi. Tidak ada tool commit. Teks konfirmasi draf berasal dari kode.
- Worker POST `/v1/agent/turn`: signature Firebase RS256, audience/issuer/expiry/auth_time, schema request, batas body, endpoint/model tetap, timeout dan pembatasan output 8.192 token.
- Counter UID/global menit/hari memakai transaksi REST Firestore. Service account memakai Datastore User. Batas global **10/hari UTC** sudah diterapkan sesuai persetujuan; konfigurasi hilang/nol tetap ditolak.
- Kandidat Rules untuk create-batch, isolasi akun, akses server-only dan perlindungan pengingat/inbox. **Belum dideploy.**

Potongan ini hanya menerima satu pesan user untuk membuat draf. Histori, hasil tool baca, pencarian slot, edit/hapus/urungkan, profil dan seluruh izin data aplikasi akan dilengkapi pada tahap implementasi. Jangan memakai kandidat Rules ini untuk mengklaim seluruh fitur sudah bekerja: path yang belum mempunyai validator tetap ditolak. Draf UI belum ditandai applied dalam batch uji ini.

## Menjalankan ulang

Jalankan `npm ci --ignore-scripts` di backend jika dependency belum tersedia, lalu `npm test` untuk pemeriksaan agent, auth dan proxy tanpa provider.

Untuk emulator, dari root proyek jalankan Firebase CLI `emulators:start --only firestore --project demo-ruma --config firebase.json` dengan Java 21+ pada PATH. SDK Android tetap memakai JDK 17; environment emulator tidak mengubahnya secara global. Kemudian di backend:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8086 npm run test:rules
```

Hanya endpoint loopback dan project `demo-ruma` yang diterima pengujian. Data sintetis emulator direset. Uji quota memakai OAuth tiruan dan key RSA sementara; bukan service account Firebase nyata. Rerun test Rules dahulu, baru quota, tanpa berjalan paralel pada database emulator yang sama.

`npm run test:ai` menjalankan **lima request model berkuota** dengan secret dari `.local/ai.env`. `npm run test:ai -- --bounded` menjalankan satu kasus gabungan dengan max_tokens 8192. Tidak ada retry model otomatis. Tidak perlu menjalankannya untuk pemeriksaan offline.

Wrangler CLI yang sudah tersedia pada cache proyek dapat menjalankan `deploy --config backend/wrangler.jsonc --dry-run` untuk bundling, atau `dev --local --config backend/wrangler.jsonc --port 8796` untuk runtime lokal. Bukan deployment cloud atau pengukuran CPU paket Free.

## Hasil uji cloud

Persetujuan sudah diberikan dan identitas `ruma-ai-proxy@mobile-app-3479f.iam.gserviceaccount.com` sudah aktif. Role `roles/datastore.user` memungkinkan baca/tulis Firestore melalui server, melewati Rules klien; kode proxy hanya memakai `usage`. Ini bukan pembatasan IAM per dokumen. Pembaruan 20 Oktober: custom role rumaFcmSender dengan permission cloudmessaging.messages.create diberikan pada akun proxy. Scheduled handler memakai antrean reminders, sumber agenda dan perangkat, menulis hasil dispatch/inbox serta counter push. Role Datastore User tetap melewati Rules klien; pembatasan dokumen dilakukan oleh kode server.

Kredensial server dan provider telah dipasang sebagai Worker Secret terenkripsi. Deployment memakai dashboard; tidak membuat token CLI baru. HTTP 401 untuk token palsu, HTTP 200 untuk dua skenario agent dan HTTP 429 untuk kuota penuh berhasil diuji. `tests/cloud-live.mjs` adalah uji opt-in dengan dua panggilan model maksimal dan akun anonymous sementara; `tests/cloud-quota-live.mjs` menyiapkan counter UID sintetis yang penuh dan membersihkannya sesudah uji. Jangan menjalankannya sebagai tes offline.

Root cause awal: Workers menolak `redirect:error`; semua fetch Worker kini memakai `manual` dan menolak non-2xx. `tests/workerd-jwt-live.mjs` mereproduksi validasi token Google asli dalam workerd lokal tanpa panggilan model. Sesudah build produksi minified, CPU sampel pertama build produksi 13 ms dan berikutnya 4 ms; nominal Free 10 ms, sehingga gate CPU belum lulus. Lihat [hasil lengkap](../docs/qa/CLOUD-INTEGRATION.md). Pengiriman FCM, seluruh agent multi-turn dan Rules lengkap tetap belum diimplementasikan.

Uji kuota memakai `batchGet` lalu satu `commit` atomik bersyarat (`updateTime`/`exists:false`), bukan begin/rollback. Konflik dibaca ulang maksimal tiga kali; pemanggilan model tidak diulang. `minify:true` dan `keep_names:false` menghasilkan bundle 37,87 KiB. Verifikasi sampel CPU: `node tests/cpu-gate.mjs` (saat ini sengaja gagal: 13/4 ms vs 10 ms); ini terpisah dari tes fungsional.
