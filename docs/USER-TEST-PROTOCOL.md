# Protokol uji mahasiswa Ruma

Status 25 Oktober 2026: protokol siap; **belum dijalankan dengan peserta**. Gunakan APK kandidat dari laporan audit. Pengujian pengembang dan tes otomatis tidak dihitung sebagai hasil peserta.

## Persiapan

Lakukan pilot dengan 3–5 mahasiswa sasaran, satu orang per sesi sekitar 20–30 menit. Gunakan akun uji terpisah yang belum mempunyai transaksi, serta nominal sintetis di bawah. Catat ID peserta anonim seperti M01; jangan mencatat password. Minta izin sebelum merekam layar/suara. Peserta boleh berhenti atau melewati tugas.

Pembuka moderator: “Kami menguji aplikasinya. Kerjakan dengan cara yang menurutmu paling masuk akal dan ceritakan apa yang kamu pikirkan. Kalau membingungkan, sampaikan; saya tidak akan langsung menunjukkan tombolnya.”

Jangan menjelaskan lokasi menu atau langkah sebelum peserta mencoba. Bantuan tetap boleh diberikan saat peserta benar-benar buntu; catat bagian yang dibantu. Catat waktu tunggu AI/jaringan terpisah dari waktu mencari dan mengisi kontrol.

## Tugas

| Tugas yang dibacakan | Yang diamati | Keberhasilan yang diperiksa moderator |
| --- | --- | --- |
| “Cari tempat untuk mengatur kegiatanmu. Catat kuliah pada Selasa minggu depan pukul 09.00 selama satu jam, lalu ubah namanya.” | Penemuan Agenda, pemilihan tanggal, durasi dan edit. | Satu jadwal pada tanggal yang diminta; edit mempertahankan catatan yang sama. |
| “Catat uang saku Rp1.000.000 dan pengeluaran makan hari ini Rp18.000.” | Pemasukan versus pengeluaran, nominal dan kategori. | Saldo tercatat Rp982.000 dan pengeluaran Rp18.000; peserta menemukan hasilnya. |
| “Lihat bulan sebelumnya. Sambil di sana, catat ongkos hari ini Rp22.000.” | Tanggal transaksi, perubahan periode dan feedback simpan. | Transaksi berada pada bulan berjalan; total pengeluaran Rp40.000 dan saldo Rp960.000. |
| “Minta Asisten membantu mencatat: besok belajar 30 menit dan tadi makan Rp18.000. Periksa usulannya; sebelum menyimpan, tutup lalu buka lagi aplikasi. Ubah pengeluaran di draf menjadi Rp20.000, lalu simpan pilihanmu.” | Izin AI, draf versus data tersimpan, pemulihan, edit dan persetujuan. | Sebelum disetujui tidak ada transaksi/agenda baru. Setelah disetujui, nominal mengikuti hasil edit dan hanya tercatat sekali. Jika semua item disimpan, pengeluaran menjadi Rp60.000 dan saldo Rp940.000. |
| “Buat tujuan laptop Rp2.000.000. Sisihkan Rp200.000, lalu kembalikan Rp50.000 dari tabungan. Jelaskan angka uang yang ditampilkan.” | Penemuan Tabungan, setor/tarik dan pemahaman alokasi. | Tabungan Rp150.000, uang tersedia Rp790.000, saldo tercatat Rp940.000 dan pengeluaran tetap Rp60.000. Angka ini berlaku bila tugas sebelumnya selesai sesuai skenario. |
| “Matikan koneksi. Coba catat pengeluaran Rp25.000. Setelah terlihat hasilnya, sambungkan kembali dan selesaikan pencatatan.” | Kejelasan gagal/menunggu, isian yang bertahan dan retry. | Tidak ada sukses palsu atau auto-commit tersembunyi; sesudah retry hanya ada satu transaksi tambahan Rp25.000. |

Tugas Asisten cukup satu pesan model per peserta. Jika kuota atau layanan tidak tersedia, catat hambatan tersebut dan lanjutkan alur manual; jangan meminta peserta mengirim berulang kali untuk mengejar keberhasilan. Kemampuan AI tabungan bukan bagian tugas ini.

Jika tugas terlewat/gagal, jangan memakai angka akhir tabel untuk menilai tugas berikutnya. Rekonsiliasi terhadap data yang benar-benar tersimpan dan catat perbedaannya.

## Pertanyaan pemahaman dan penutup

Setelah tugas, tanyakan tanpa mengajari jawabannya:

- “Apa perbedaan saldo tercatat, tabungan dan uang tersedia?”
- “Saat menekan Setor, apakah uang benar-benar berpindah rekening?”
- “Pada saat apa pesan ke Asisten menjadi data yang tersimpan?”
- “Apa yang akan kamu lakukan jika layar menunjukkan belum termuat atau gagal simpan?”
- “Bagian mana yang paling membingungkan, dan apa yang kamu harapkan terjadi?”

Setelah setiap tugas, minta nilai kemudahan 1–7 dengan jangkar 1 = sangat sulit dan 7 = sangat mudah. Ini penilaian per tugas; jangan mengubahnya menjadi skor SUS atau klaim validasi produk.

## Lembar pencatatan

Duplikasi tabel berikut untuk setiap peserta. Biarkan kosong sampai ada pengamatan nyata.

| Tugas | Berhasil tanpa bantuan / dibantu / gagal | Waktu aktif | Waktu tunggu | Salah langkah / bantuan | Kemudahan 1–7 | Kutipan / hambatan |
| --- | --- | --- | --- | --- | --- | --- |
| Agenda | | | | | | |
| Transaksi | | | | | | |
| Lintas bulan | | | | | | |
| Draf Asisten | | | | | | |
| Tabungan | | | | | | |
| Offline/retry | | | | | | |

Prioritaskan kehilangan/duplikasi data, persetujuan yang tidak dipahami, salah tanggal/periode, lalu hambatan menemukan kontrol. Rangkum jumlah keberhasilan dan bantuan terhadap jumlah peserta yang benar-benar mencoba setiap tugas; sertakan kegagalan dan layanan yang tidak tersedia.

Setelah sesi, hapus hanya data akun uji yang dibuat untuk sesi tersebut sesuai kesepakatan peserta. Jangan menghapus atau mengganti akun pribadi peserta.
