# Ascon-AEAD128

Sistem yang dirancang ini untuk tugas besar mata kuliah sistem digital EL2102.
Sistem yang dikembangkan untuk proyek ini adalah bot yang diimplementasikan pada platform Discord, khususnya komunikasi melalui chat. Bot ini berfungsi untuk menerima pesan dari pengguna yang berisi perintah spesifik (enkripsi atau dekripsi). Setelah menerima perintah, sistem akan secara otomatis melakukan proses penambahan lapisan enkripsi atau penghilangan lapisan dekripsi pada pesan, sesuai dengan instruksi yang diberikan oleh pengguna.

Untuk menjalankan sistem ini, diperlukan:

Koneksi internet
Bot Discord (berbasis Python)
Cyclone IV FPGA yang telah diimplementasikan dengan algoritma ASCON-AEAD128 (untuk proses enkripsi/dekripsi serta penyimpanan key)
Satu perangkat user
Satu perangkat host yang terhubung serial dengan FPGA
Terminal serial RealTerm
Koneksi UART antara PC host dan FPGA
USER melalui aplikasi Discord akan mengirimkan perintah “/encrypt” atau “/decrypt” dan kemudian diikuti dengan isi teks yang ingin dienkripsi/dekripsi. Bot Discord yang di-hosting dari PC host akan menerima perintah ini kemudian akan mengambil isi pesan dari perintah tersebut. Isi pesan diekspor dalam bentuk file .txt atau .json kemudian disimpan pada PC host. File yang diekspor kemudian akan dikirimkan ke FPGA yang tersambung serial dengan PC host melalui terminal RealTerm. FPGA kemudian membaca file yang diinput dan melakukan proses enkripsi atau deskripsi, sesuai dengan ASCON-AEAD128 yang telah disusun. output dari FPGA, yaitu pesan yang telah dienkripsikan atau dideskripsikan serta nonce(jika proses yang dilakukan adalah proses enkripsi), akan dikirimkan kepada RealTerm. Pesan yang diterima oleh RealTerm kemudian akan diekspor dalam bentuk file .txt atau .json dan dikirimkan kembali kepada bot discord. Bot Discord akan menampilkan output yang diharapkan kepada pengguna.
