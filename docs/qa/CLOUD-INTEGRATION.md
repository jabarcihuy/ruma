# Ruma — hasil integrasi cloud

19 Oktober 2026 · setup proxy sederhana, bukan kelulusan seluruh aplikasi.

**Keputusan 19 Oktober 2026:** optimasi CPU ditunda atas permintaan pengguna. Lanjut fondasi Flutter; buka kembali hanya jika uji aplikasi menunjukkan error terkait CPU. [Pemicu dan bukti](CPU-FOLLOWUP.md). Angka pengukuran dan status nominal di bawah dipertahankan.

## Status terbaru

Worker aktif: `https://ruma-api.abduljabarbrngkl.workers.dev`, endpoint **POST `/v1/agent/turn`**. Versi `c6bedf81-7f1a-4d01-b4e2-aee42d574c09` tetap memakai NaraRouter `glm-5.3-flash`. Provider dan hosting tidak diganti. Firebase Spark dan Workers Free tetap dipakai; billing/cron tidak diaktifkan.

| Pemeriksaan | Hasil |
|---|---|
| Token tidak ada/palsu | HTTP 401 |
| Token Firebase asli + dua agenda dan dua pengeluaran | HTTP 200; empat item draf, nominal dan durasi benar |
| Rencana membeli buku besok | HTTP 200; klarifikasi, tidak tersimpan menjadi transaksi |
| UID uji dengan kuota harian penuh | HTTP 429; counter global tetap 6 sebelum/sesudah, provider diblokir |
| Pengujian regresi source | 14 lulus, 0 gagal |
| Konkurensi kuota di emulator | 8 permintaan, tepat 3 diterima dengan batas 3 |
| Runtime workerd dengan JWT Google asli | Autentikasi lolos; body kosong ditolak 400 |
| Akun dan counter fixture | Dihapus setelah pengujian |

Bukti: [cloud](cloud-proxy-check.json), [kuota](cloud-quota-check.json), [regresi](backend-cloud-regression.tap), [konkurensi](quota-concurrency-check.json), [runtime lokal](workerd-real-jwt-diagnostic.json).

## Optimasi yang dipertahankan

- Kunci verifikasi RS256 diambil dari endpoint JWK Google untuk identitas securetoken yang sama. Kunci publik dibandingkan dengan endpoint sertifikat Firebase; nilai modulus/exponent cocok. Signature, issuer, audience, waktu, subject dan pergantian kid tetap diperiksa.
- Kuota memakai dua request Firestore: batchGet dan commit atomik dengan prasyarat updateTime untuk dokumen yang ada atau exists:false untuk dokumen baru. Perubahan bersamaan membatalkan seluruh commit dan dibaca ulang maksimal tiga kali. Batas tidak direset dan model tidak diulang otomatis.
- Build produksi memakai minify:true dan keep_names:false: sekitar 68,50 KiB menjadi 37,87 KiB. Source tetap terbaca di backend/src.

[Dokumentasi kunci JWK Google](https://docs.cloud.google.com/iam/docs/service-account-creds), [commit atomik](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/commit), [prasyarat versi](https://firebase.google.com/docs/firestore/reference/rest/v1/Precondition), [konfigurasi build](https://developers.cloudflare.com/workers/wrangler/configuration/).

## CPU: uji fungsi lulus, batas nominal belum lulus

| Versi percobaan | Autentikasi pertama sesudah deploy | Request berikutnya |
|---|---:|---:|
| Awal | 13 ms | 5 ms |
| Optimasi tanggal sebelumnya | 11 ms | 4 ms |
| JWK | 15 ms | 5 ms |
| Commit kuota bersyarat | 16 ms | 4 ms |
| Build produksi terbaru | **13 ms** | **4 ms** |

Angka ini berasal dari cpuTimeMs log invokasi, bukan waktu tunggu model. Wall time dua request terbaru sekitar 15,4 detik dan 2,9 detik. Semua request fungsional di atas berhasil, tetapi [batas nominal Workers Free](https://developers.cloudflare.com/workers/platform/limits/) adalah 10 ms. Cloudflare mendokumentasikan kelonggaran untuk lonjakan sesekali; itu tidak membuktikan kelayakan beban terburuk. **Gate T02 nominal tetap belum lulus.** Tidak ada bukti profiler yang mengisolasi satu sumber CPU; jangan mengklaim perubahan JWK pasti menurunkan CPU. Refresh OAuth/kid, isolate baru berulang dan payload maksimum juga belum diuji menyeluruh.

Sesuai permintaan pengguna agar setup tetap sederhana, tidak menambah layanan, framework, atau percobaan model lanjutan. Proxy bisa dipakai untuk integrasi terbatas; sebelum distribusi luas perlu keputusan kelayakan hosting jika CPU tetap melampaui nominal.

Periksa ulang bukti dengan `node backend/tests/cpu-gate.mjs`; saat ini keluar gagal untuk 13/4 ms. [Data CPU](cloud-cpu-check.json) dan [screenshot terbaru](cloud-cpu-latest.png) tidak memuat token/IP/lokasi privat.

## Akses dan batas cakupan

Service account ruma-ai-proxy@mobile-app-3479f.iam.gserviceaccount.com memakai roles/datastore.user, sesuai persetujuan pengguna. Peran ini memungkinkan baca/tulis Firestore di project; kode proxy hanya mengakses usage. API key dan kredensial Google tersimpan sebagai Secret terenkripsi Cloudflare. Private key lokal berizin 0600 dalam direktori 0700 yang diabaikan Git. Sertifikat publik terdaftar sampai 17 Januari 2027 Jakarta; rotasi sebelum kedaluwarsa. Tidak memberi Owner/Editor/izin FCM.

Batas global tetap **10 panggilan model/hari UTC**. Sepanjang seluruh riwayat ada 10 panggilan model sukses melalui cloud (4 pada rangkaian sebelumnya, 6 pada rangkaian ini), ditambah 13 pemeriksaan langsung terdahulu termasuk kegagalan awal: total 23. Rangkaian hari UTC terbaru memakai 6 reservasi. Request gagal autentikasi tidak mencapai model. Satu deployment sementara salah mentransfer karakter template melalui editor; ditolak 401, diperbaiki sebelum uji sukses dan tidak meneruskan request ke model. Gangguan jaringan uji dicatat dan tidak disamakan dengan kegagalan CPU.

Potongan ini menangani satu pesan untuk create-draft; tidak mempunyai tool commit. Tidak menulis agenda/keuangan. Hanya counter usage dan fixture sementara yang ditulis. Rules produksi tetap deny-all. Histori/read-tools/update/delete/undo/profil, Rules seluruh fitur, FCM/cron/perangkat dan Flutter belum lengkap.

Kegagalan runtime terdahulu disebabkan redirect:error yang ditolak Workers; seluruh fetch menggunakan manual dan menolak non-2xx. Tidak ada logging token/prompt atau debug sementara dalam source.
