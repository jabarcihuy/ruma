# Ruma — konfigurasi proyek aktual

> **Status terbaru 20 Oktober 2026:** saran slot, tool baca, edit/hapus dan urungkan satu catatan per tinjauan sudah aktif. Worker/Rules dipublikasikan dengan izin pengguna; empat panggilan AI nyata lulus, fixture dibersihkan, APK normal terpasang di VM. [Hasil dan batas tahap 1–3](AGENT-STAGES-1-3.md). Catatan kandidat/belum publikasi di bawah adalah riwayat sebelum publikasi ini.

> Tahap Asisten 19 Oktober 2026 selesai: draf gabungan agenda + transaksi, tinjauan/edit/keluarkan item, dan penyimpanan atomik aktif. Rules terbit 22.52 WIB; uji SDK/UI HP dan satu panggilan AI produksi lulus, fixture dibersihkan, APK normal dipasang. Draf masih dalam memori dan jam agenda disunting manual. Status/batas: [ASSISTANT-IMPLEMENTATION.md](ASSISTANT-IMPLEMENTATION.md).

> Tahap keuangan 19 Oktober 2026: form, repository, anggaran, riwayat, laporan dan Beranda sudah diimplementasikan. Rules gabungan aktif dan uji SDK Android lokal/produksi lulus; fixture dibersihkan dan APK normal dipasang. Status/bukti terbaru: [FINANCE-IMPLEMENTATION.md](FINANCE-IMPLEMENTATION.md).

> Pembaruan 19 Oktober 2026, tahap agenda: CRUD manual sekali jalan dan Rules per UID sudah aktif; suite Android emulator dan produksi lulus, fixture produksi dibersihkan. Lihat [AGENDA-IMPLEMENTATION.md](AGENDA-IMPLEMENTATION.md) untuk bukti, batas dan APK terbaru. Berikutnya keuangan manual; seri mingguan, agent dalam aplikasi dan notifikasi belum selesai.

> Status pengembangan 19 Oktober 2026: fondasi Flutter Android dan Firebase Auth lulus uji emulator serta produksi pada HP. APK pratinjau telah dipasang. Bukti dan batas implementasi terkini ada di [FLUTTER-FOUNDATION.md](FLUTTER-FOUNDATION.md) dan [DEVELOPMENT-LOG.md](DEVELOPMENT-LOG.md). Pernyataan “belum dibuat” pada riwayat di bawah menggambarkan tahap perencanaan sebelumnya.

19 Oktober 2026 · tahap penyiapan layanan, alat, dan uji provider, sebelum implementasi aplikasi. [Konfigurasi publik](../config/public-config.json) tidak memuat secret atau kredensial server.

**Status terbaru:** proxy cloud sudah terdeploy, service account/Secret aktif, token Firebase asli dan dua skenario AI berfungsi. Batas global 10 panggilan model/hari UTC diuji melalui penolakan kuota HTTP 429. Sesudah optimasi, CPU sampel pertama build produksi 13 ms dan berikutnya 4 ms; nominal Free 10 ms sehingga pemeriksaan nominal CPU belum lulus. Atas keputusan pengguna 19 Oktober 2026, optimasi CPU ditunda dan tidak menghalangi tahap Flutter; buka kembali hanya jika pengujian aplikasi menemukan error yang terkonfirmasi terkait CPU. [Catatan tindak lanjut](qa/CPU-FOLLOWUP.md). [Hasil cloud lengkap](qa/CLOUD-INTEGRATION.md) menggantikan status “belum deploy/menunggu izin” pada riwayat penyiapan di bawah. Fondasi Flutter/Auth sudah diuji pada HP; FCM ke HP, ledger dan Rules seluruh fitur belum diimplementasikan.

## Identitas

- Nama aplikasi dan nama tampilan Firebase: **Ruma**.
- Firebase Project ID tetap **mobile-app-3479f**, project number **18934621879**. Mengubah nama tampilan tidak mengubah Project ID.
- Pengguna memilih mengkhususkan project ini untuk Ruma karena aplikasi lama tidak lagi dipakai. Registrasi tiga aplikasi lama dipertahankan; tidak dihapus.
- Android application ID Ruma: **id.ruma.app**, dipilih untuk registrasi baru. Implementasi Flutter nanti harus memakai ID yang sama, bukan package aplikasi lama.
- Paket Firebase: **Spark**. Tidak mengaktifkan billing atau Firebase Functions.
- Worker: **ruma-api**, paket **Free**, sudah aktif di `ruma-api.abduljabarbrngkl.workers.dev`; POST `/v1/agent/turn` wajib token Firebase.

## Hasil pemeriksaan lokal

Pemeriksaan `flutter doctor -v` telah dijalankan menggunakan environment khusus proses, SDK `/home/ael/Android/Sdk`, dan JDK `/usr/lib/jvm/java-17-openjdk`. Flutter 3.47.7 / Dart 3.13.5 dan SDK Android 36.1.0 ditemukan. Pada pemeriksaan awal beberapa lisensi Android belum diterima; setelah pengguna menerimanya, pemeriksaan ulang memastikan **All Android licenses accepted** dan Android toolchain berstatus lulus. Bukti terkini: [android-license-recheck.json](qa/android-license-recheck.json). Chrome yang tidak ditemukan tidak menghalangi target APK Android. Status connected device tidak membuktikan HP Android siap karena dapat merujuk target desktop; HP uji masih perlu ditentukan.

Hasil tersanitasi disimpan di [environment-check.json](qa/environment-check.json). Tidak ada perubahan PATH/JAVA_HOME/SDK global. Firebase CLI 15.34.0 dan Wrangler 4.151.1 kemudian disiapkan pada cache lokal `.tools/` dan diverifikasi. Keduanya dijalankan dengan Node 24.19.0 bawaan runtime untuk menghindari ketidakcocokan dependency Firebase dengan Node sistem 26. FlutterFire CLI ditunda sampai ada aplikasi Flutter yang akan dikonfigurasi.

Lokasi executable aktual tersimpan di `.local/tooling.json`, diabaikan Git. Alias Firebase default ada di `.firebaserc` dan menunjuk mobile-app-3479f. CLI Firebase/Wrangler belum login; sesi browser bukan sesi CLI. Deployment Worker dilakukan lewat dashboard, tanpa token CLI baru.

## Layanan yang sudah terverifikasi

| Bagian | Keadaan aktual |
|---|---|
| Firebase | Project mobile-app-3479f, nama tampilan Ruma, Spark |
| Android | Ruma Android terdaftar, package id.ruma.app, App ID 1:18934621879:android:8f7ae40b378ec1dce08f32 |
| Auth | Email/Password dan Anonymous aktif; email-link tidak diaktifkan, auto-cleanup akun sementara tidak diaktifkan |
| Firestore | Standard, database (default), Jakarta asia-southeast2; ledger pengguna kosong, counter server usage telah ditulis saat uji |
| Rules aktif | Gabungan agenda + transaksi/anggaran/core/receipt per UID; 28 skenario Rules lokal dan SDK Android produksi lulus. Fitur lainnya tetap ditolak |
| FCM | HTTP v1 Enabled; API legacy tetap Disabled; pengiriman perangkat belum diuji |
| Cloudflare | ruma-api terdeploy; kedua Secret terenkripsi, global model limit 10/hari UTC; CPU dicatat sebagai tindak lanjut ditunda, bukan penghalang Flutter |

Bukti: [registrasi Android](qa/firebase-ruma-android.png), [provider Auth](qa/firebase-auth-enabled.png), [Firestore](qa/firestore-created-jakarta.png), [Rules produksi](qa/firestore-production-rules.png), [FCM v1](qa/firebase-fcm-v1-enabled.png), dan [Workers Free](qa/cloudflare-workers-free.png).

## Langkah yang memerlukan tindakan pemilik akun

1. Login [Cloudflare](https://dash.cloudflare.com/) telah diselesaikan pengguna. Password, OTP, dan penerimaan syarat akun tidak dibagikan lewat chat.
2. **Selesai:** pengguna telah menerima lisensi Android, dan `flutter doctor -v` mengonfirmasi Android toolchain siap. Perintah berikut dipertahankan sebagai referensi penyiapan ulang, bukan pekerjaan yang masih tertunda:

```bash
JAVA_HOME=/usr/lib/jvm/java-17-openjdk \
ANDROID_HOME=/home/ael/Android/Sdk \
ANDROID_SDK_ROOT=/home/ael/Android/Sdk \
/opt/flutter/bin/flutter doctor --android-licenses
```

3. **Selesai:** pengguna telah mengisi secret AI di `.local/ai.env`, diabaikan Git; direktori privat berizin 0700 dan file 0600. Key dimuat tanpa dicetak dan berhasil dipakai untuk uji provider. Key lama dari teks chat tidak disalin ke file. Contoh berikut hanya untuk pengisian ulang jika diperlukan:

```bash
umask 077
read -rsp 'API key NaraRouter baru: ' ruma_ai_key
printf '\n'
printf 'NARAROUTER_API_KEY=%s\n' "$ruma_ai_key" > .local/ai.env
unset ruma_ai_key
```

Pengisian key AI dilakukan pengguna, lalu Secret diunggah ke Worker setelah persetujuan. Service account khusus proxy dibuat dengan Datastore User; hanya kunci publik didaftarkan di Google. Private key tetap pada penyimpanan privat lokal/Worker Secret. Akun proxy tidak mempunyai role pengiriman FCM.

4. **Selesai:** file `config/firebase/google-services.json` sudah ditemukan dan diverifikasi terhadap project mobile-app-3479f, package id.ruma.app, serta App ID Ruma. File juga berisi konfigurasi Android aplikasi lama; entri Ruma tersedia dan cocok. Konfigurasi klien Firebase berbeda dari secret provider/service account.

Sebelumnya pengambilan SDK melalui CLI ditolak karena CLI belum login. File kini sudah tersedia melalui penyimpanan pengguna dan telah diperiksa; login CLI bukan lagi penghalang untuk mendapatkan file konfigurasi SDK ini.

## Status dan batas

### Riwayat uji lokal sebelum deployment cloud

Kegagalan awal di bagian bawah sudah ditindaklanjuti. Instruksi dan schema proposal diperjelas dengan status transaksi/kutipan sumber; hasil model divalidasi sebelum menjadi draf. Lima dari lima kasus sintetis pada [uji terbaru](qa/agent-policy-check.json) lulus, termasuk dua pengulangan kasus awal, rencana yang belum dibayar, pesan gabungan dan pembelian aktual. Ini sampel terbatas, bukan jaminan semua ungkapan bahasa dipahami. Tidak ada tool commit. Teks konfirmasi draf berasal dari kode.

`max_tokens:8192` diuji terpisah dan [berhasil](qa/agent-output-limit-check.json). Potongan proxy memakai batas ini; penyebab tepat kombinasi parameter lama tetap belum diisolasi. Rangkaian sejak pemeriksaan awal mengirim total 13 request model, termasuk request gagal dan diagnostik. Enam request baru pada tahap lanjutan semuanya sintetis, tanpa perubahan database produksi.

Potongan `backend/` telah dibuat, belum keseluruhan backend aplikasi. **20 pemeriksaan Node + Rules dan satu pemeriksaan kuota terpisah lulus**: signature/claim token sintetis, validasi request, error provider, isolasi akun, rollback atomik, idempotensi, tanggal transaksi masa depan, perlindungan pengingat/inbox dan batch maksimum tiga agenda+tiga transaksi+tiga pengingat. Delapan reservasi kuota serentak hanya memberi tiga keberhasilan saat batas uji tiga; counter tetap tiga. OAuth counter memakai mock, bukan kredensial Google nyata. Bukti: [ringkasan](qa/backend-readiness.json), [TAP](qa/backend-checks.tap), [Rules](qa/firestore-rules-check.json), [kuota](qa/quota-concurrency-check.json).

Firestore emulator memakai project demo-ruma pada loopback 8086 dan Java 27 khusus proses; toolchain Android tetap JDK 17. Tidak mengubah environment global. Kandidat Rules belum memuat seluruh field/alur aplikasi dan belum dideploy: database Firebase aktif tetap deny-all. Draf applied, profil, seri, edit/hapus/undo dan beberapa path lain masih perlu implementasi.

Bundling Wrangler dry-run berhasil; Worker berjalan di workerd lokal dan [menolak request tanpa/palsu token](qa/workerd-local-check.json). Saat uji lokal ini, hasil belum mencakup cloud; pengujian cloud sesudahnya dicatat pada laporan terbaru di atas. Pengujian notifikasi HP disiapkan di [checklist](qa/ANDROID-NOTIFICATIONS.md); seluruh kasus perangkat tetap belum diuji.

Sesudah uji lokal, pengguna menyetujui formulir akses server tersebut. Identitas, role, key, Secret, deployment dan batas 10/hari UTC kini sudah diterapkan. Tidak menggunakan key service account aplikasi lama. Riwayat formulir dan hasil uji lokal dipertahankan sebagai bukti tahapan, bukan keadaan aktif saat ini.

### Riwayat pemeriksaan awal

Model tepat `glm-5.3-flash` sudah diuji langsung dengan data sintetis. Katalog, pesan biasa, argumen tool, pembacaan hasil tool dan draf dua agenda + dua pengeluaran berhasil. Lima dari enam pemeriksaan dasar lulus. Kasus rencana belanja pertama menghasilkan tool call; uji ulang menghasilkan klarifikasi tetapi kata pembukanya menyiratkan data sudah dicatat. Perilaku belum cukup konsisten untuk dianggap siap produksi. Bukti dan tinjauan: [hasil utama](qa/nararouter-check.json), [diagnostik](qa/nararouter-future-diagnostic.json).

Payload minimal berhasil; kombinasi parameter tambahan pada [percobaan awal](qa/nararouter-initial-check.json) ditolak HTTP 400. Parameter penyebab belum diisolasi dan batas output produksi belum teruji. Tujuh request model dikirim di seluruh rangkaian termasuk satu request gagal dan satu pengulangan diagnostik; baseline yang digunakan ulang tidak dihitung dua kali. Tidak ada data pengguna nyata atau perubahan database dalam pengujian.

Project, aplikasi Android, provider Auth, Firestore dan status FCM sudah diverifikasi di Console. Cloudflare juga sudah terhubung. Status file SDK, secret, CLI dan hasil gate harus diperiksa terpisah; nilai null pada konfigurasi berarti belum tersedia, bukan sudah siap.

Kode uji provider awal tersedia di `scripts/check_ai_provider.py`; jalankan tanpa flag untuk memeriksa validator offline. Flag `--live` menggunakan kuota provider; jangan mengulang tanpa kebutuhan. Uji terkini dan potongan proxy ada di backend. Belum membuat aplikasi Flutter, men-deploy Worker atau Rules produksi, mengirim push, atau membangun APK. Status gate terbaru ada pada [rencana penerimaan](ACCEPTANCE.md).
