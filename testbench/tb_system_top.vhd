LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.LWC_config_ccw.ALL; -- Pastikan paket ini terkompilasi

ENTITY tb_System_Top IS
-- Testbench tidak memiliki port eksternal
END tb_System_Top;

ARCHITECTURE behavior OF tb_System_Top IS 

    -- Deklarasi Unit Under Test (UUT)
    COMPONENT System_Top
    PORT(
         clk           : IN  std_logic;
         rst           : IN  std_logic;
         key_in        : IN  std_logic_vector(127 downto 0);
         key_valid_in  : IN  std_logic;
         ext_data_in   : IN  std_logic_vector(31 downto 0);
         ext_valid_in  : IN  std_logic;
         start_nonce   : IN  std_logic;
         nonce_sel_pin : IN  std_logic;
         bdi_eot       : IN  std_logic;
         bdi_eoi       : IN  std_logic;
         bdi_type      : IN  std_logic_vector(3 downto 0);
         decrypt_in    : IN  std_logic;
         key_update    : IN  std_logic;
         data_out      : OUT  std_logic_vector(31 downto 0);
         valid_out     : OUT  std_logic;
         ready_out     : OUT  std_logic
        );
    END COMPONENT;
    
    -- Definisi Sinyal Internal
    signal clk           : std_logic := '0';
    signal rst           : std_logic := '0';
    
    -- Inputs
    signal key_in        : std_logic_vector(127 downto 0) := (others => '0');
    signal key_valid_in  : std_logic := '0';
    signal ext_data_in   : std_logic_vector(31 downto 0) := (others => '0');
    signal ext_valid_in  : std_logic := '0';
    signal start_nonce   : std_logic := '0';
    signal nonce_sel_pin : std_logic := '0';
    signal bdi_eot       : std_logic := '0';
    signal bdi_eoi       : std_logic := '0';
    signal bdi_type      : std_logic_vector(3 downto 0) := "0000";
    signal decrypt_in    : std_logic := '0';
    signal key_update    : std_logic := '0';

    -- Outputs
    signal data_out      : std_logic_vector(31 downto 0);
    signal valid_out     : std_logic;
    signal ready_out     : std_logic;

    -- Periode Clock (100 MHz)
    constant clk_period : time := 10 ns;
 
BEGIN
 
    -- Instansiasi UUT
    uut: System_Top PORT MAP (
          clk => clk,
          rst => rst,
          key_in => key_in,
          key_valid_in => key_valid_in,
          ext_data_in => ext_data_in,
          ext_valid_in => ext_valid_in,
          start_nonce => start_nonce,
          nonce_sel_pin => nonce_sel_pin,
          bdi_eot => bdi_eot,
          bdi_eoi => bdi_eoi,
          bdi_type => bdi_type,
          decrypt_in => decrypt_in,
          key_update => key_update,
          data_out => data_out,
          valid_out => valid_out,
          ready_out => ready_out
        );

    -- Pembangkitan Clock
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;
 
    -- Proses Stimulus Utama
    stim_proc: process
    begin		
        -- 1. Reset Sistem
        rst <= '1';
        wait for 20 ns;	
        rst <= '0';
        wait for 20 ns;

        -- 2. Memuat Kunci (KEY LOADING)
        key_in <= x"000102030405060708090A0B0C0D0E0F";
        key_valid_in <= '1';
        key_update <= '1';
        wait for clk_period;
        key_valid_in <= '0';
        key_update <= '0';
        
        wait for 50 ns; -- Tunggu proses key selesai

        -- 3. Memulai Nonce Generator (NONCE INJECTION)
        -- Ini akan otomatis menyuntikkan 128-bit Nonce ke Core
        start_nonce <= '1';
        nonce_sel_pin <= '0'; -- Pilih ID A
        wait for clk_period;
        start_nonce <= '0';
        
        -- Tunggu sampai Core selesai menerima Nonce & Inisialisasi
        -- Ascon butuh 12 ronde inisialisasi (~12 clock atau lebih tergantung implementasi)
        wait until ready_out = '1'; 
        wait for clk_period; -- Margin aman

        -- 4. Mengirim Data Eksternal (PLAINTEXT)
        -- Kirim 1 blok data "TEST" (0x54455354)
        ext_data_in <= x"54455354";
        ext_valid_in <= '1';
        bdi_type <= "0100"; -- HDR_PT (Plaintext)
        bdi_eot <= '1';     -- Akhir tipe data
        bdi_eoi <= '1';     -- Akhir input (Pesan selesai)
        
        wait for clk_period;
        ext_valid_in <= '0'; -- Selesai kirim
        bdi_eot <= '0';
        bdi_eoi <= '0';

        -- 5. Observasi Output
        -- Tunggu sampai ciphertext dan tag keluar di 'data_out'
        -- (Proses otomatis berjalan di dalam Core)
        
        wait for 500 ns; -- Beri waktu simulasi berjalan

        assert false report "Simulasi Selesai dengan Sukses" severity failure;
    end process;

END;
