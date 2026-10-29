# Audit layout dan keseimbangan palet Ruma

26 Oktober 2026. Cakupan: hierarki visual, warna, kepadatan informasi, navigasi, serta layout halaman aktif Android. Audit ini menghasilkan laporan dan bukti; tidak mengubah UI atau APK kandidat.

## Kesimpulan

Palet Ruma sudah selaras: latar putih kehijauan, teks gelap, oranye sebagai aksen, serta sage dan peach sebagai permukaan pendukung. Warna tidak memenuhi layar secara berlebihan. Perbaikan paling berguna adalah membedakan bobot aksi, pilihan, dan informasi, lalu memperjelas nominal transaksi dan kontrol form.

Ditemukan **4 temuan P2 dan 1 temuan P3**. Tidak ditemukan hambatan P0/P1 dalam cakupan yang diperiksa. Dampak berupa kesulitan memindai atau mengenali kontrol merupakan penilaian pengembang; belum dibuktikan melalui peserta uji.

**Kesesuaian platform:** struktur masih terbaca sebagai aplikasi Android: kontrol Material, picker native Flutter/Material, Back, area aman, form bergulir, dan penyesuaian keyboard. Navbar kustom menonjolkan Asisten sebagai fitur utama MVP, sesuai keputusan pemilik produk. Penekanan ini dipertahankan; keterpahaman penanda tab aktif masih menjadi pertanyaan untuk uji pengguna. Tidak ada alasan mengganti seluruh gaya visual dari hasil audit ini.

## Metode dan batas bukti

- Sumber saat ini diperiksa pada theme, komponen bersama, shell, Beranda, Agenda, Asisten, Keuangan, Profil, dan Tabungan.
- **5 tes layout lulus** melalui suite `test/ui_polish_test.dart`: viewport 390×844, 320×640 dengan teks 200%, dan 844×390; pilihan durasi; serta navbar saat keyboard muncul. Halaman juga digulir untuk memeriksa exception layout. Ini pemeriksaan widget, bukan pengukuran kelancaran pada HP.
- Dibuat **25 render widget saat ini** pada 390×844 memakai font Manrope. Pemeriksaan visual difokuskan pada 16 render halaman aktif. Form anggaran legacy ikut ter-render sebagai regresi, tetapi tidak dijadikan rekomendasi produk.
- Enam screenshot Android dari walkthrough **25 Oktober** dipakai sebagai bukti tambahan untuk shell dan keadaan berisi data. Capture Android lama untuk Profil/Keuangan yang masih memiliki subtitle terdahulu tidak dijadikan bukti layout terbaru; kedua halaman memakai render widget baru.
- Render widget halaman utama memakai scaffold fixture bertajuk “Ruma” dan tanpa navbar produksi. Navbar dinilai dari sumber shell serta screenshot Android, bukan dari fixture tersebut.
- Tidak menjalankan Android lagi, mengakses produksi, memanggil model, mengubah Figma, atau membangun APK baru pada audit ini. TalkBack, dark mode, tablet/foldable, dan performa perangkat fisik belum diverifikasi.
- Skor kesehatan seluruh aplikasi tidak diberikan: audit ini berfokus pada layout/palet dan tidak mengukur performa atau seluruh aspek aksesibilitas.

Log dan 25 render mentah: `.local/ui-layout-palette-20261026/`. Bukti terpilih dan hash sumber: [verification.json](qa/layout-palette/verification.json).

## Keseimbangan warna

| Peran | Token saat ini | Penilaian / arah |
| --- | --- | --- |
| Latar halaman | `background #F6F7F3` | Pertahankan; membuat ruang antarkartu tenang. |
| Permukaan isi | `surface #FFFFFF` | Pertahankan; identitas kartu sudah konsisten. |
| Teks utama | `ink #20241F` | Kontras sangat baik; gunakan juga untuk nominal penting. |
| Teks pendukung | `muted #56614F` | Cukup terbaca pada putih, sage, dan peach. |
| Aksen utama | `accent #CF4924` | Efektif untuk CTA, penanda aktif, dan elemen merek. Perjelas perbedaannya dari kontrol pemilih. |
| Teks aksi | `accentInk #A9361C` | Baik untuk tautan/tombol teks; lebih kuat daripada aksen utama di permukaan terang. |
| Permukaan sage | `sage #E5EDE1` | Ringkasan uang dan kartu informasi sudah nyaman. |
| Permukaan peach | `peach #FFE6D6` | Cocok untuk konteks pendukung dan pilihan aktif bertonal lembut. |
| Kesalahan | `danger #A62D25` | Pertahankan bersama pesan/ikon yang menjelaskan kesalahan. |
| Garis halus | `line #E0E4DC` | Baik untuk dekorasi; terlalu lemah bila menjadi petunjuk utama batas input. |

Penghitungan piksel warna token yang persis sama pada lima capture Android menunjukkan putih+latar sekitar **76–92%**, dengan oranye aksen sekitar **0,20–5,11%** per capture. Pada Beranda, bidang `ink` sekitar **8,42%**, terutama dari kartu Asisten dan maskot navbar; sage dan peach masing-masing sekitar **0,38%**. Ini menjelaskan mengapa bidang gelap Asisten lebih menarik perhatian daripada luas warna oranye.

Angka tersebut hanya proporsi piksel token pada viewport tertentu, bukan ukuran persepsi atau target rasio warna. Anti-alias, bayangan, aset, dan snackbar memiliki warna lain. Pengukuran mendukung arah mempertahankan palet dan merapikan penempatannya; tidak menetapkan rasio warna wajib untuk semua halaman.

### Kontras terukur

Perhitungan memakai luminans relatif sRGB dari token opak di `lib/app/theme.dart`, bukan warna tepi teks hasil anti-alias.

| Pasangan nyata | Rasio | Hasil pada penggunaan yang diperiksa |
| --- | ---: | --- |
| Ink / putih | 15,75:1 | Sangat baik untuk teks. |
| Muted / putih | 6,53:1 | Lulus patokan teks kecil. |
| Muted / sage | 5,45:1 | Lulus patokan teks kecil. |
| Muted / peach | 5,45:1 | Lulus patokan teks kecil. |
| Putih / oranye utama | **4,53:1** | Lulus tipis; jaga warna tombol dan opacity teks. |
| AccentInk / putih | 6,50:1 | Baik untuk teks aksi. |
| Oranye / ink | 3,47:1 | Cukup untuk ikon di kartu Asisten; bukan pasangan yang disarankan untuk teks kecil. |
| Danger / soft | 6,24:1 | Pesan error dapat dibaca. |
| Line / putih | **1,29:1** | Batas input sangat halus. |
| Line / latar | **1,20:1** | Batas input juga lemah terhadap sisi luarnya. |

Patokan teks kecil adalah 4,5:1; teks besar dan petunjuk visual nonteks yang diperlukan umumnya 3:1. Batas semua kartu/tombol tidak otomatis wajib 3:1 bila teks atau ikonnya sudah cukup mengidentifikasi kontrol. Karena itu garis halus dicatat sebagai masalah keterlihatan input, bukan klaim seluruh UI gagal WCAG. Rujukan: [W3C — Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [W3C — Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

## Temuan berdasarkan prioritas

### 1. [P2] Garis input terlalu samar untuk menjadi petunjuk bentuk kontrol

**Lokasi:** `lib/app/theme.dart:33` dan `:130`; tampak pada form agenda, keuangan, profil, dan tabungan. Kategori: warna, keterlihatan.

Border `line` memiliki kontras 1,29:1 terhadap putih dan 1,20:1 terhadap latar. Fill putih terhadap latar hanya 1,08:1. Contoh [form setoran](qa/layout-palette/savings-deposit-widget.png) memperlihatkan input yang sangat menyatu dengan halaman. Label dan isi tetap terbaca, sehingga ini bukan hambatan mengisi form yang sudah terkonfirmasi.

**Dampak:** bentuk area ketuk/tulis lebih sulit dikenali dalam kondisi kontras layar rendah. Border fokus sudah lebih kuat, tetapi baru muncul setelah kontrol ditemukan.

**Rekomendasi:** pisahkan token `outline` fungsional dari `line` dekoratif. Gunakan outline lebih gelap pada input aktif yang belum fokus, dengan sasaran 3:1 terhadap kedua permukaan di sisinya. Pertahankan warna lembut kartu; tidak perlu menggelapkan semua pemisah atau membuat semua kartu berbingkai.

**Workflow:** `$impeccable colorize`.

### 2. [P2] Nominal transaksi mendapat bobot sama dengan tanggal

**Lokasi:** `lib/features/finance/finance_page.dart:580`; gaya subtitle `lib/app/theme.dart:105`. Kategori: hierarki, tipografi.

Kategori menjadi judul 15 dp, sedangkan tanggal dan nominal digabung dalam satu subtitle 12 dp berwarna muted. [Riwayat saat ini](qa/layout-palette/history-widget.png) menunjukkan angka uang lebih lemah daripada kategori. Bandingkan detail Tabungan yang sudah memakai nominal tebal.

**Dampak:** memindai besar pemasukan/pengeluaran membutuhkan pembacaan lebih teliti. Kontras teksnya lulus; masalahnya adalah urutan perhatian.

**Rekomendasi:** pisahkan nominal dari tanggal; gunakan ink dan bobot semibold/bold untuk nominal, dengan tanggal tetap sekunder. Pertahankan tanda `+`/`−` dan label jenis agar makna tidak bergantung pada warna. Tata letak nominal harus membungkus aman pada angka besar/teks 200%.

**Workflow:** `$impeccable typeset`.

### 3. [P2] Kontrol filter mengambil banyak ruang awal Riwayat

**Lokasi:** `lib/features/finance/finance_page.dart:498` sampai blok kategori `:557`. Kategori: kepadatan, layout kompak.

Pencarian, jenis, dan kategori selalu tampil dalam tiga baris kontrol penuh setelah judul dan pemilih bulan. Pada render 390×844, kartu pertama mulai sekitar y=400. Pada capture Android 360 dp lebar, kartu pertama mulai sekitar y=424 dp. Pengguna tetap dapat menggulir dan tidak ditemukan overflow.

**Dampak:** jumlah transaksi yang terlihat pada pembukaan halaman berkurang, bahkan ketika tidak memakai filter.

**Rekomendasi:** pertahankan pencarian yang langsung terlihat. Gabungkan jenis/kategori dalam panel Filter yang dapat dibuka, tampilkan ringkasan filter aktif dan aksi reset. Simpan pilihan saat panel ditutup. Jaga target sentuh 48 dp; jangan menghemat ruang dengan mengecilkan kontrol. Rujukan: [Android — controls and touch targets](https://developer.android.com/guide/topics/ui/accessibility/apps).

**Workflow:** `$impeccable layout`.

### 4. [P2] Pemilih Setoran/Penarikan memakai gaya yang sama dengan CTA Simpan

**Lokasi:** `lib/features/savings/savings_form.dart:209` dan `:382`. Kategori: semantik warna, konsistensi kontrol.

Pilihan Setoran/Penarikan memakai dua `RumaButton`; pilihan aktif memakai filled oranye yang sama dengan “Simpan catatan”. [Render form](qa/layout-palette/savings-deposit-widget.png) memperlihatkan dua pusat perhatian oranye pada satu alur. RumaButton juga tidak menyatakan `selected`/`checked`; ia mengumumkan peran tombol biasa. Judul form berubah mengikuti pilihan, tetapi state pada kontrol pemilih belum eksplisit.

**Dampak:** perubahan jenis transaksi dan tindakan menyimpan memiliki bahasa visual yang sama. Pengguna pembaca layar tidak mendapat state pilihan langsung dari masing-masing tombol.

**Rekomendasi:** gunakan pemilih tersegmen Material dengan state terpilih yang jelas dan semantics terpilih. Tonal peach + accentInk dapat membedakannya dari CTA filled oranye. “Simpan catatan” tetap menjadi aksi utama; perilaku setoran/penarikan tidak berubah.

**Workflow:** `$impeccable harden`.

### 5. [P3] Aksi ubah nama terlalu menonjol di Profil

**Lokasi:** `lib/features/profile/profile_page.dart:173`. Kategori: bobot aksi.

[Profil saat ini](qa/layout-palette/profile-widget.png) memberi “Ubah nama panggilan” tombol oranye selebar kartu, sementara preferensi, notifikasi, dan privasi menjadi baris netral.

**Dampak:** aksi personalisasi yang jarang dilakukan menjadi pusat perhatian tetap. Ini peluang penyempurnaan; tidak ada kegagalan tugas yang direproduksi.

**Rekomendasi:** gunakan tombol teks/tonal atau ikon edit berlabel yang dekat dengan nama. Pada akun sementara, tindakan mempertahankan akses melalui email dapat tetap mendapat prioritas lebih tinggi. Pertahankan target sentuh dan label yang jelas.

**Workflow:** `$impeccable quieter`.

## Keputusan desain MVP: Asisten sebagai pusat perhatian

Klarifikasi pemilik produk pada 26 Oktober: AI agent memang sengaja dibuat lebih menonjol sebagai fitur MVP. Maskot besar dan lingkaran gelap navbar dipertahankan; dominasi visualnya dikeluarkan dari daftar masalah. Bukti tampilannya tetap tersedia pada [Beranda Android](qa/layout-palette/home-android.png).

Apakah pengguna dapat mengenali tab aktif saat Asisten tetap dominan merupakan hipotesis uji pengguna, bukan defect yang telah dibuktikan. Audit ini tidak merekomendasikan mengecilkan maskot atau mengubah navbar berdasarkan hipotesis tersebut.

## Pola yang perlu dipertahankan

- Margin halaman 24 dp dan jarak isi 12–16 dp menciptakan ritme yang cukup konsisten. Radius 16 untuk kontrol, 20–24 untuk kartu juga masih membentuk keluarga visual yang selaras.
- Layout pasangan aksi bertumpuk pada ruang sempit/teks besar. Nilai uang besar mengikuti isi dan halaman dapat digulir.
- Keuangan sudah memiliki hierarki yang baik antara saldo sage, arus masuk/keluar, aksi, dan menu lanjutan: [render Keuangan](qa/layout-palette/finance-widget.png).
- Ringkasan Beranda memakai komponen waktu/uang yang sama. Tabungan memakai teks angka/persentase selain progress bar.
- Oranye tidak dipakai sebagai satu-satunya penjelas transaksi: tanda nominal, label, judul dan status teks tetap tersedia.
- Warna kritis sudah terpusat pada `RumaColors`. Material `ColorScheme.fromSeed` masih menghasilkan beberapa peran turunan seperti outline/chip/snackbar; bila menata token, petakan hanya peran yang dibutuhkan agar tidak muncul warna tambahan yang tidak disengaja.

Mode gelap belum memiliki skema tersendiri (`darkTheme` tidak tersedia). Ini dicatat sebagai batas kemampuan saat ini; tidak dijadikan alasan mengganti palet terang atau klaim bahwa tangkapan layar mode gelap telah diuji.

## Urutan tindak lanjut

1. `$impeccable colorize`: outline input fungsional; pertahankan kontras CTA dan warna merek.
2. `$impeccable typeset`: hierarki nominal/tanggal pada transaksi.
3. `$impeccable layout`: filter riwayat.
4. `$impeccable harden`: state pemilih Setoran/Penarikan, termasuk semantics.
5. `$impeccable quieter`: turunkan bobot edit nama bila diperlukan.
6. `$impeccable polish`: konfirmasi satu putaran pada Android kompak, teks besar, dan keyboard setelah perubahan.

Perubahan dapat dikerjakan satu per satu atau dalam satu paket sesuai prioritas. Ulangi `$impeccable audit` pada area yang berubah untuk memastikan temuan tertutup. APK kandidat 0.1.1+2 tetap merupakan build dari audit sebelumnya; laporan ini tidak mengklaim kelima rekomendasi telah diimplementasikan.
