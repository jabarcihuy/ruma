# Bahasa domain Ruma

Ruma membantu mahasiswa mengelola waktu dan uang pribadi. Istilah berikut dipakai konsisten dalam rancangan dan implementasi.

## Bahasa

**Agenda**: Semua kegiatan bertanggal atau tugas yang dikelola pengguna, termasuk yang belum memperoleh waktu. _Hindari_: memakai agenda hanya untuk jadwal kuliah.

**Jadwal kuliah**: Agenda yang waktu mulai dan selesainya diketahui, dan dapat memiliki pengulangan mingguan.

**Tugas**: Agenda dengan kebutuhan durasi dan deadline opsional; waktu pengerjaannya dapat belum ditentukan.

**Seri jadwal**: Pola beberapa pertemuan berulang. Mengubah satu pertemuan tidak otomatis mengubah seluruh seri.

**Pertemuan**: Satu kejadian dari seri jadwal pada tanggal tertentu, dengan identitas yang tetap meskipun waktunya dipindahkan.

**Waktu tersedia**: Rentang yang tidak berbenturan dengan agenda di dalam waktu yang pengguna bersedia gunakan. Kalender kosong saja belum menyatakan kesediaan pengguna.

**Bentrokan**: Dua agenda aktif mempunyai irisan waktu; kegiatan yang berakhir tepat ketika kegiatan berikutnya mulai tidak beririsan.

**Transaksi**: Catatan pemasukan atau pengeluaran yang benar-benar sudah terjadi. _Hindari_: menyebut rencana belanja sebagai pengeluaran aktual.

**Saldo tercatat**: Akumulasi seluruh pemasukan tercatat dikurangi seluruh pengeluaran tercatat. Angka ini tidak menyatakan saldo bank atau isi dompet yang belum dicatat.

**Anggaran bulanan**: Batas pengeluaran yang ditentukan pengguna untuk satu bulan, dengan batas kategori opsional. Anggaran tidak menambah saldo.

**Sisa anggaran**: Batas anggaran periode dikurangi pengeluaran tercatat periode itu. Nilainya dapat negatif jika batas terlampaui.

**Draf tindakan**: Usulan perubahan agenda atau transaksi yang dapat ditinjau dan diedit sebelum disetujui. Draf belum mengubah data tersimpan.

**Draf gabungan**: Satu draf berisi beberapa penambahan agenda dan transaksi dari satu percakapan.

**Keluarkan item**: Tidak menyertakan item draf ketika menyimpan; tidak menghapus data lama.

**Persetujuan**: Pilihan pengguna menerapkan isi draf yang sedang ditampilkan. Mengubah draf setelah persetujuan memerlukan persetujuan baru.

**Urungkan**: Mengembalikan satu perubahan yang sudah diterapkan ke keadaan sebelumnya, selama data terkait belum berubah lagi.

**Riwayat tindakan**: Catatan perubahan tersimpan yang diperlukan untuk menampilkan hasil dan melakukan urungkan.

**Personalisasi**: Penyesuaian saran dari preferensi dan riwayat yang diizinkan pengguna. _Hindari_: menyebutnya pelatihan ulang model AI.

**Akun**: Identitas pengguna yang menjadi pemilik agenda, keuangan, preferensi, dan riwayat pribadinya. Data milik akun yang berbeda tidak digabung tanpa persetujuan pengguna.
