# Audit sistem, UI dan usability Ruma

25 Oktober 2026. Cakupan: Beranda, agenda manual, transaksi manual, tinjauan Asisten, serta tabungan. Metode: penelusuran kode, pemeriksaan regresi, dan walkthrough Android dengan Firebase lokal. Ini audit oleh pengembang; belum ada peserta mahasiswa atau skor usability dari pengguna.

## Masalah yang direproduksi dan diperbaiki

| Prioritas | Sebelum | Dampak | Sesudah dan bukti |
| --- | --- | --- | --- |
| P1 | Form agenda membuka kalender pada hari ini meskipun pengguna sudah memilih hari lain di Agenda. | Pengguna harus memilih tanggal dua kali; kegiatan bisa tersimpan pada hari yang keliru. | Hari pilihan diteruskan ke form sebagai konteks kalender. Waktu kegiatan tetap dipilih pengguna; tugas tetap bisa disimpan tanpa waktu. Tes memilih minggu berikutnya lalu membuka kalender mereproduksi dan mengonfirmasi perbaikan. |
| P1 | Setelah menyimpan transaksi pada bulan berbeda, FinanceStore memuat ulang bulan yang sebelumnya dipilih. | Transaksi berhasil tersimpan tetapi tidak terlihat pada daftar saat itu; pengguna berpotensi mencatat ulang. | Setelah commit terkonfirmasi, periode mengikuti tanggal transaksi. Feedback menyebut bulan tujuan bila berubah. Jika commit gagal, periode dan isian lama dipertahankan. |
| P2 | Tanggal transaksi tampil sebagai teks; kontrol untuk menggantinya tersembunyi di Opsi lainnya. | Koreksi tanggal sulit ditemukan meskipun tanggal menentukan laporan yang memuat transaksi. | Tanggal menjadi kontrol kalender langsung di form. Catatan opsional tetap dapat dibuka terpisah. |
| P2 | Gagal memuat tabungan di Beranda hanya menunjukkan “Belum termuat”. | Tidak ada tindakan pemulihan langsung pada ringkasan yang gagal. | Tombol “Muat ulang tabungan” muncul saat gagal; saldo yang masih valid tetap dapat dibaca. Tes membuktikan pemulihan tanpa berpindah halaman. |
| P2 | Hari yang dipilih dapat tersembunyi di ujung strip kalender horizontal pada layar sempit. | Penanda pilihan tidak terlihat meskipun isi halaman sudah berganti hari. | Strip otomatis memperlihatkan hari terpilih saat dibuka atau saat pilihan berubah. Hanya strip horizontal yang digulir; posisi halaman tidak dipindahkan. |

Pada refresh setelah commit keuangan yang gagal, snapshot lama sekarang dibuang. Pesan tetap menyatakan bahwa transaksi sudah tersimpan; UI tidak memperlakukan kegagalan membaca ringkasan sebagai kegagalan penulisan.

Pemeriksaan visual juga menemukan bahwa format tanggal yang lebih ringkas pada perubahan awal tidak menampilkan tahun. Format akhir memakai tanggal singkat lokal dengan tahun, seperti `25 Okt 2026 · WIB`; informasi tahun tidak dikorbankan demi keringkasan.

Lokasi perubahan: `lib/features/agenda/agenda_page.dart`, `agenda_form.dart`, `lib/features/finance/finance_forms.dart`, `finance_page.dart`, `lib/data/finance_repository.dart`, dan `lib/features/home/home_page.dart`.

## Dasar penilaian HCI

- **Kesesuaian dengan konteks pengguna:** pilihan hari dan tanggal transaksi mengikuti pekerjaan yang sedang dilakukan.
- **Keterlihatan status dan hasil:** transaksi yang berhasil langsung dapat ditemukan pada periode yang benar; sukses commit dibedakan dari gagal refresh.
- **Recognition:** kontrol tanggal dapat dikenali tanpa mengingat lokasi opsi tersembunyi.
- **Pemulihan kesalahan:** data form bertahan saat gagal simpan, retry memakai identitas operasi yang sama, dan ringkasan gagal menyediakan tindakan pemulihan.
- **Kontrol pengguna:** draf AI belum menjadi data agenda/transaksi sebelum disetujui. Form menjaga isian saat pengguna membatalkan keputusan keluar.

Pola yang dipertahankan: komponen Material, Manrope, SVG dan warna Ruma, navigasi lima tab, form yang dapat digulir, pilihan durasi, serta konfirmasi tindakan yang berisiko kehilangan data. Tidak menambahkan dependensi atau mengubah Rules/Worker produksi.

## Pemeriksaan lima alur

| Alur | Pemeriksaan |
| --- | --- |
| Beranda | Ringkasan agenda dan uang; saldo tercatat, tabungan, serta uang tersedia mengikuti data yang konsisten. State gagal tidak diganti dengan angka nol palsu. |
| Agenda | Pilih hari, tambah jadwal, edit catatan yang sama. Kegiatan yang dipilih dari Beranda membuka detail berdasarkan ID. |
| Keuangan | Pemasukan/pengeluaran, validasi rupiah, hasil simpan pada periode yang benar, keadaan offline, isian yang dipertahankan, dan retry tanpa duplikasi. |
| Asisten | Proposal sintetis, tinjauan/edit/keluarkan item, penyimpanan hanya setelah persetujuan, serta pemulihan workspace. Normalisasi respons model diperiksa pada suite backend terpisah. |
| Tabungan | Buat tujuan, setor, tarik, pembatalan keluar dari form, serta rekonsiliasi uang tersedia. Setor/tarik tidak menjadi pemasukan/pengeluaran. |

Anggaran merupakan data legacy dan tidak ditampilkan pada dashboard aktif. Fokus istilah uang pada audit ini adalah **saldo tercatat**, **tabungan**, dan **uang tersedia**; tidak mengembalikan menu anggaran.

## Bukti dan batas

- Empat pemeriksaan baru gagal terhadap implementasi lama, lalu lulus sesudah perbaikan. Satu pemeriksaan tambahan memastikan kegagalan penulisan lintas bulan tidak mengganti periode atau snapshot sebelumnya.
- Total 84 tes Flutter lulus. Cakupan mencakup layar 320 px, teks 200%, lanskap, keyboard, pembatalan, validasi, keadaan gagal, dan isolasi hasil asynchronous antar akun. Dua pemeriksaan visual tambahan mereproduksi hari terpilih yang tidak terlihat dan hilangnya tahun pada format antara; keduanya lulus setelah koreksi.
- Analyzer bersih. Suite backend 35 tes dan Rules 64 tes sudah lulus pada tahap pemulihan lingkungan; kode backend/Rules tidak berubah pada audit ini dan hasil tersebut tidak diklaim sebagai rerun baru.
- Walkthrough native akhir lulus delapan skenario pada AVD Android API 37, layar 720×1600/density 320, dengan Firebase lokal `demo-ruma`. Sembilan screenshot tersimpan. Daftar skenario dan metadata artefak ada di [verification.json](qa/usability/verification.json).

Log lokal: `.local/usability-audit-20261025/`. `before-tests-confirmed.log` mencatat empat kegagalan regresi; `focused-tests.log` mencatat 26 tes terfokus lulus; `visual-regressions-before.log` menyimpan dua kegagalan pemeriksaan visual; `flutter-tests-final.log` mencatat 84 tes lulus. File mentah disimpan lokal, tidak ikut Git. Runner menerima `RUMA_QA_DIR` dan `RUMA_RESULT_NAME` agar bukti baru tidak menimpa arsip QA lama.

## Hasil Android dan APK kandidat

`integration_test/usability_flow_test.dart` menguji tambah/edit agenda pada hari pilihan, transaksi dari tampilan bulan lama yang mengikuti tanggal sebenarnya, gagal simpan offline dan retry satu kali, setor/tarik tanpa mengubah ledger, perlindungan isian saat kembali, penolakan draf kosong, rekonstruksi store dengan draf yang belum diterapkan, edit/persetujuan draf, serta angka Beranda setelah semua perubahan.

Hasil angka sintetis pada walkthrough: pemasukan Rp1.000.000; dua pengeluaran Rp18.000 + Rp22.000; saldo tercatat Rp960.000; setoran Rp200.000 dan penarikan Rp50.000 menghasilkan tabungan Rp150.000 serta uang tersedia Rp810.000. Setor/tarik tidak menambah transaksi pemasukan/pengeluaran. Proposal Asisten hanya menambah agenda setelah ditinjau. Angka protokol mahasiswa berbeda karena tugas Asisten di protokol juga menambahkan transaksi.

Pemulihan draf pada uji baru ini memakai penghancuran dan pembuatan ulang widget/store dalam proses Android yang sama. Ini tidak diklaim sebagai pengujian force-stop atau cold restart proses OS. Tidak ada request ke model produksi; proposal Asisten memakai fixture sintetis dengan tinjauan dan commit Firestore yang nyata.

Percobaan pertama berhenti karena runner langsung mengetuk menu yang tertutup snackbar sukses. Runner sekarang menunggu durasi pesan sementara tersebut; pemeriksaan hit-test tetap fatal. Satu konfirmasi berikutnya terputus oleh pembaruan otomatis Google Play Services: log ActivityManager secara eksplisit mencatat Ruma dihentikan akibat `killDueToPackageUpdate`. Konfirmasi dengan APK yang sama kemudian lulus setelah Play Store dinonaktifkan sementara pada AVD khusus uji. Play Store diaktifkan kembali setelah pengujian. Log kedua kejadian dipertahankan di folder bukti lokal; tidak dihitung sebagai kelulusan.

Cleanup akhir terverifikasi: akun Auth fixture terhapus dan tidak ada akun tersisa pada emulator; 21 dokumen fixture pada delapan koleksi dibersihkan dan semuanya diverifikasi kosong. AVD, Firebase Emulator dan daemon Gradle dihentikan. Rules/Worker produksi tidak dipublikasikan atau diubah.

APK lokal: [ruma-0.1.1-usability-candidate.apk](../output/apk/ruma-0.1.1-usability-candidate.apk), versi **0.1.1+2**, package `id.ruma.app`, 62.342.342 byte (62,3 MB), ABI ARM32/ARM64/x86_64, minSdk 24, targetSdk 36. SHA-256: `35f7c33d78630b65ee602851bf607b6b6b57c6c8439d738ef3302d456bed5a7d`.

Tanda tangan v2 valid; sertifikat SHA-256 `3f4af245b0c9f64f415442a32d4c5341386337ad5015803355dba1a809879ae8` cocok dengan release sebelumnya. Manifest tidak menandai APK sebagai debuggable. APK ini build produksi untuk uji mahasiswa, bukan APK harness emulator. Walkthrough di atas memakai harness debug x86_64; APK bertanda tangan ini belum menjalani walkthrough pada HP fisik dan belum dipublikasikan ke Google Play. Jika masih memakai APK debug, ikuti [petunjuk pemasangan release](ANDROID-RELEASE.md) sebelum menggantinya.

Bukti visual terpilih berikut berasal dari dua putaran Android dengan data sintetis. Gambar “sebelum” adalah putaran fungsional awal audit, sebelum koreksi visual terakhir, bukan seluruh kondisi repo sebelum empat perbaikan pertama.

| Area | Sebelum koreksi visual terakhir | Hasil akhir |
| --- | --- | --- |
| Hari terpilih | [Minggu tersembunyi di ujung strip](qa/usability/agenda-before-visual-fix.png) | [Minggu dan penandanya terlihat](qa/usability/agenda-after.png) |
| Tanggal transaksi | [Format tanpa tahun](qa/usability/transaction-before-visual-fix.png) | [Kontrol langsung dengan tahun](qa/usability/transaction-after.png) |

Untuk mengulang, gunakan [lingkungan lokal](LOCAL-TEST-SETUP.md). Build harness sebelum menjalankan AVD bila memori terbatas, lalu jalankan driver setelah Auth/Firestore Emulator dan AVD siap:

```bash
source .local/android.env
flutter build apk --debug --target-platform android-x64 \
  --target integration_test/usability_flow_test.dart \
  --dart-define=AUTH_EMULATOR=true \
  --dart-define=AUTH_EMULATOR_HOST=10.0.2.2 \
  --dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2
RUMA_QA_DIR=.local/usability-audit-20261025/android \
RUMA_RESULT_NAME=usability-results flutter drive -d emulator-5554 --no-pub \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/usability_flow_test.dart \
  --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

## Hal yang masih perlu divalidasi

1. Pengguna baru menemukan lima tujuan navbar yang memakai ikon dan tooltip tanpa label visual. Semantics label sudah ada, tetapi keterpahaman pertama kali memerlukan pengamatan pengguna.
2. Pengguna memahami saldo tercatat sebagai jumlah dari catatan, bukan saldo bank otomatis. Setoran tabungan hanya mengalokasikan uang dan tidak memindahkannya ke bank.
3. Judul “Uang bulan ini” tidak membuat saldo sepanjang waktu dan pengeluaran bulanan dianggap sebagai periode yang sama. Ini hipotesis pemahaman, belum bukti kesalahan pengguna.
4. Pemulihan kata sandi masih ditunda dalam cakupan produk lama. Sebelum distribusi luas, tentukan alur pemulihan akun dan uji pada HP fisik.
5. TalkBack, performa, notifikasi dan pembatasan baterai pada perangkat fisik belum diverifikasi pada tahap ini. Tidak memberi skor performa atau skor HCI kuantitatif dari emulator yang mengalami tekanan memori.

Protokol uji mahasiswa: [USER-TEST-PROTOCOL.md](USER-TEST-PROTOCOL.md). Perbaikan berikutnya mengikuti hambatan yang diamati pada tugas tersebut; bukan penambahan fitur baru.
