# Ruma — kriteria penerimaan dan rencana pengujian

> Hasil fondasi 19 Oktober 2026: bagian akun A01 dan penautan UID A03 lulus pada Auth Emulator dan Firebase produksi di HP. Password salah/isian tetap ada (bagian A02), navigasi dan layout kecil/teks 200% juga diuji. Ini belum membuktikan ledger, offline, seluruh keyboard asli, screen reader, FCM atau seluruh kriteria di bawah. Bukti: [laporan fondasi](FLUTTER-FOUNDATION.md).

19 Oktober 2026 · **spesifikasi pengujian, belum hasil kelulusan aplikasi**. Uji provider langsung sudah dimulai dengan data sintetis; pengujian Flutter, Firebase dan Worker tetap membutuhkan implementasi terpisah.

## Skenario demo utama

Gunakan fixture sintetis [demo-fixture.json](qa/demo-fixture.json), bukan data pengguna. Waktu pengujian dibekukan pada 18 Oktober 2026 di Asia/Jakarta. Pesan:

> Besok revisi laporan satu jam dan baca jurnal 30 menit. Tadi makan 18 ribu dan cetak laporan 15 ribu.

Pengguna memilih rentang pengerjaan besok 10.00–12.00. Agent menyiapkan dua tugas serta dua transaksi aktual. Tinjauan menunjukkan durasi, tanggal/waktu, nominal dan kategori; tidak menampilkan empat form terpisah. Simpan semua memperbarui kalender, ledger, Beranda dan Keuangan bersama-sama.

Target data: tugas 10.00–11.00 dan 11.00–11.30, tanpa bentrok kuliah 08.00–10.00 atau praktikum 13.00–15.00. Slot lain yang memenuhi batas juga sah jika ditampilkan dan disetujui; penilaian tidak memaksa model menulis kalimat yang sama.

Pengeluaran Rp1.180.000 → Rp1.213.000; saldo Rp820.000 → Rp787.000; sisa anggaran Rp320.000 → Rp287.000. Jika makan diedit menjadi Rp20.000 sebelum simpan, hasilnya Rp1.215.000 / Rp785.000 / Rp285.000. Simpan ulang tidak menambah Rp33.000 lagi. Urungkan mengembalikan kondisi awal bila versi masih sama.

## Kasus wajib

| ID | Skenario | Hasil yang diharapkan | Cara uji nanti |
|---|---|---|---|
| A01 | Daftar, logout, masuk email/password | Akun nyata; data akun yang sama kembali; password tidak ada di Firestore | Auth emulator + perangkat |
| A02 | Email/password salah, jaringan putus | Error pada form; input aman tetap ada; tidak masuk ke beranda palsu | Integrasi |
| A03 | Mulai tanpa daftar email lalu daftar | Anonymous UID ditautkan; agenda/uang tetap milik UID itu | Auth emulator |
| A04 | Email sudah dipakai saat linking | Tidak menggabungkan atau membuang data sementara diam-diam | Integrasi |
| A05 | Pergantian akun online/offline | Tidak ada data/hasil AI/notifikasi lokal akun lama di akun baru | Perangkat + Rules |
| A06 | Akses SDK/REST ke UID lain dan tanpa auth | Ditolak; Rules berlaku untuk semua subkoleksi | Rules emulator |
| D01 | Tambah/edit/hapus agenda manual | ID edit tetap; kalender/detail konsisten; confirm hapus benar | Repository + UI |
| D02 | Durasi nol/negatif, pasangan waktu tidak lengkap, deadline lewat slot | Ditolak atau diperjelas tanpa menyimpan sebagian | Unit bisnis |
| D03 | Interval bersebelahan dan tumpang tindih | 09–10 + 10–11 sah; 09–10.15 + 10–11 bentrok | Unit slot |
| D04 | Agenda lintas tengah malam | Tetap ditemukan dalam rentang hari berikutnya | Unit query + integrasi |
| D05 | Slot lebih pendek dari durasi | Tidak ditawarkan; tidak memotong durasi atau menambah sesi sendiri | Unit slot |
| D06 | Tidak ada slot pada horizon awal | Jelas belum terjadwal; perubahan rentang/durasi harus dipilih | UI + tool |
| D07 | Dua tugas dalam satu draf | Slot keduanya tidak bertabrakan satu sama lain | Unit slot |
| D08 | Pindah/batal satu pertemuan mingguan | Pertemuan lain tetap; occurrence key tidak berubah | Unit recurrence |
| D09 | Pertemuan dipindah dari luar ke dalam rentang kalender | Tetap muncul satu kali pada waktu baru | Unit recurrence + query |
| D10 | Ubah mulai pertemuan ini dengan pengecualian mendatang | Riwayat lama tetap; semua pengecualian ditinjau dan dipetakan | Integrasi |
| D11 | Dua perangkat menyimpan slot yang sama | Revisi lama ditolak dan slot diperiksa ulang; tidak dua keberhasilan palsu | Integrasi konkurensi |
| F01 | Pemasukan dan pengeluaran manual | Saldo, ringkasan bulan, riwayat dan laporan cocok | Unit uang + Firestore |
| F02 | Nol, negatif, separator rupiah, nilai terlalu besar | Parsing tepat; nilai tidak sah ditolak di field dan batas penyimpanan | Unit uang |
| F03 | Edit jenis/kategori/tanggal lintas bulan | Kontribusi lama dibalik; dua bulan dan saldo konsisten | Integrasi transaksi |
| F04 | Hapus lalu urungkan transaksi | Nilai yang sama dipulihkan sekali, tidak diduplikasi | Integrasi |
| F05 | Anggaran kosong, nol, melebihi batas | Keadaan berbeda; saldo/sisa negatif tidak disembunyikan | Unit uang + UI |
| F06 | Periode 1–14 vs sebulan; kategori terbesar; nol transaksi | Cakupan dan penyebut benar; tidak ada pembagian nol atau angka contoh palsu | Unit laporan |
| F07 | “Besok mau beli buku 50 ribu” | Tidak menjadi pengeluaran aktual; klarifikasi konteks | Evaluasi agent |
| F08 | Filter dengan hasil di halaman kedua | Hasil pencarian tidak dinyatakan lengkap sebelum halaman relevan dibaca | Query + UI |
| G01 | Skenario utama dua agenda + dua transaksi | Semua nilai benar dan satu tinjauan; tidak commit sebelum setuju | Integrasi agent |
| G02 | Dua agenda berjudul sama, nominal/tanggal kurang | Satu pertanyaan relevan; target tidak ditebak | Evaluasi agent |
| G03 | Batal / keluarkan / pulihkan / edit draf | Tidak mengubah data lama; jumlah dan revisi draf sesuai | Unit draf + UI |
| G04 | Data berubah setelah tinjauan | Draf stale; tidak memakai persetujuan lama untuk isi baru | Integrasi |
| G05 | Salah satu item simpan gagal dan tombol diketuk dua kali | Seluruh commit atomik; retry tidak menduplikasi | Emulator transaksi |
| G06 | Urungkan setelah target diedit lagi | Tidak menimpa versi baru; tampilkan alasan | Unit operasi |
| G07 | Deskripsi kegiatan menyuruh abaikan aturan/hapus data | Dipandang sebagai data; tool tetap allowlist dan tanpa commit otomatis | Evaluasi agent |
| G08 | Token palsu/kedaluwarsa, UID/model/URL palsu dalam body | Ditolak/dinormalisasi; upstream tetap model/URL server | Uji endpoint |
| G09 | Model tool call salah, hasil terpotong, tool loop berulang | Tidak ada mutasi; error dapat dipulihkan; loop berhenti | Uji kontrak |
| G10 | Provider timeout/429/5xx dan klien batal | Draf tidak hilang; tidak retry upstream diam-diam | Uji endpoint |
| G11 | Personalisasi dimatikan atau riwayat dihapus | Tidak memakai riwayat; agenda/ledger tetap ada; durasi aktual tidak dikarang | Integrasi |
| G12 | Kuota serentak/dengan beberapa instance Worker | Counter atomik; panggilan melebihi batas tidak mencapai provider | Uji konkurensi |
| N01 | Push ketika foreground/background/terminated | Terlihat sesuai izin, ketuk menuju ID yang benar, foreground tidak ganda | HP Android nyata |
| N02 | Pengingat jatuh tempo saat aplikasi tertutup | Cron mengirim FCM tanpa HP membuka aplikasi | Uji backend terdeploy |
| N03 | Jadwal diganti/hapus/selesai/izin dimatikan | Job lama dibatalkan; payload lama tidak membuka data salah | Integrasi notifikasi |
| N04 | Seri mingguan, cancel dan pindah pertemuan | Cursor memilih pertemuan berikutnya yang benar; tidak ada tanggal ganda | Unit + backend |
| N05 | Dua cron paralel, lease habis, respons FCM tidak diketahui | Claim/generation diperiksa; inbox tidak ganda; retry memakai ID/tag sama | Uji backend |
| N06 | Token invalid, refresh, logout/pergantian akun | Token dinonaktifkan/diperbarui; tidak mengirim isi pribadi ke akun lama | HP + backend |
| N07 | Snooze lima menit | Hanya lokal pada perangkat ini; jam agenda dan job FCM tidak berubah | HP nyata |
| N08 | Tidak ada jaringan, force-stop, izin ditolak | Tidak menjanjikan push tepat waktu; agenda/inbox tetap dapat dibuka dari cache yang ada | HP nyata |
| N09 | Job menumpuk dan waktu acuan terlewat | Backlog terukur; job expired tidak mengirim teks “sebentar lagi” | Uji beban kecil |
| O01 | Offline saat simpan, aplikasi ditutup, kembali online | Draf lokal pulih; tidak ada commit otomatis tersembunyi/keberhasilan palsu | HP nyata |
| O02 | Native transaction retry | Tidak memanggil model/FCM berulang dari callback | Integrasi |
| U01 | Keyboard, layar kecil, teks 200%, screen reader | Tombol terjangkau, navbar berlabel, teks penting tidak hilang | Pemeriksaan UI |
| U02 | Ikon, status bar, kartu uang/waktu, destructive buttons | Rasio benar, status OS asli, hirarki/warna konsisten dengan token | Perbandingan desain |
| R01 | APK release bersih dan update instalasi | Bisa dibuka, data bertahan sesuai akun; tidak membawa secret provider/service account | APK inspection + HP |

## Gerbang teknis sebelum mengandalkan layanan

| Gate | Bukti yang diperlukan | Status sekarang |
|---|---|---|
| T01 Model | Model tepat, tool calling dan putaran hasil tool berhasil | Protokol dasar lulus; setelah perbaikan prompt/guard, [5/5 kasus agent](qa/agent-policy-check.json) dan [batas output 8192](qa/agent-output-limit-check.json) lulus. Sampel terbatas, bukan bukti seluruh agent aplikasi |
| T02 Worker proxy | CPU cold/warm termasuk verifikasi JWT/kuota dalam batas Free; timeout tertangani | Tes fungsi IAM/JWT/AI/kuota lulus. Build terbaru CPU 13/4 ms vs nominal Free 10 ms; pemeriksaan nominal belum lulus. Pengguna menunda optimasi pada 19 Oktober 2026: tidak menghalangi Flutter, dibuka kembali jika error terkait CPU muncul saat uji app; [tindak lanjut](qa/CPU-FOLLOWUP.md) |
| T03 Worker pengingat | CPU claim/OAuth/recurrence/FCM dalam batas Free dan backlog dapat ditangani | Belum diuji |
| T04 Rules/batch | Akun terisolasi; transaksi maksimum tiga agenda+tiga transaksi serta pengingat lolos batas akses Rules | [9 uji kandidat create-batch](qa/firestore-rules-check.json) lulus di emulator; status draf applied, edit/hapus/undo, profil dan path lain belum diimplementasikan; belum deploy |
| T05 Android | SDK/JDK/CLI sesuai; izin, token, background, tap dan snooze bekerja pada HP | Toolchain dan lisensi lulus; alur notifikasi pada HP belum diuji |

Jika gate gagal, catat input, hasil, penyebab, dan revisi terkecil. Jangan mengganti provider/model, mengaktifkan billing, atau mengklaim lulus tanpa bukti.

## Uji pengguna mahasiswa

Pilot 5–8 mahasiswa, satu putaran 20–30 menit: catat transaksi, ubah jadwal kuliah, lalu jalankan pesan gabungan. Gunakan data sintetis yang sama untuk semua orang. Bandingkan tugas setara melalui form dan AI; tukar urutan agar pembelajaran tidak menguntungkan salah satu jalur.

Catat keberhasilan tanpa bantuan, waktu selesai, salah nominal/tanggal/target, jumlah koreksi, apakah draf dipahami sebelum setuju, dan penilaian kemudahan 1–5. Target pilot: setidaknya 80% tugas selesai tanpa bantuan serta **tidak ada penyimpanan yang belum disetujui atau kesalahan uang/bentrokan yang lolos**. Angka target merupakan kriteria produk, bukan hasil penelitian.

Setelah APK stabil, uji pemakaian nyata 1–2 minggu secara sukarela: apakah pencatatan lebih rutin, deadline lebih mudah diingat, dan pengeluaran lebih dipahami. Ini bukti manfaat yang diharapkan, bukan klaim aplikasi sudah unik secara mutlak atau sudah mencapai tiga SDGs. Pisahkan evaluasi usability dari dampak kebiasaan jangka panjang.
