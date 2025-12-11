LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_nonce IS
-- Testbench tidak memiliki port eksternal
END tb_nonce;

ARCHITECTURE behavior OF tb_nonce IS 

    -- Deklarasi Komponen Unit Under Test (UUT)
    COMPONENT Nonce128
    PORT(
         clk       : IN  std_logic;
         rst       : IN  std_logic;
         start     : IN  std_logic;
         mode_sel  : IN  std_logic;
         bdi_out   : OUT  std_logic_vector(31 downto 0);
         bdi_valid : OUT  std_logic;
         bdi_ready : IN  std_logic
        );
    END COMPONENT;
    
    -- Definisi Sinyal Internal untuk Menghubungkan ke UUT
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0';
    signal start     : std_logic := '0';
    signal mode_sel  : std_logic := '0';
    signal bdi_ready : std_logic := '0';

    -- Sinyal Output (untuk diamati)
    signal bdi_out   : std_logic_vector(31 downto 0);
    signal bdi_valid : std_logic;

    -- Definisi Periode Clock
    constant clk_period : time := 10 ns;
 
BEGIN
 
    -- 1. Instansiasi Unit Under Test (UUT)
    uut: Nonce128 PORT MAP (
          clk       => clk,
          rst       => rst,
          start     => start,
          mode_sel  => mode_sel,
          bdi_out   => bdi_out,
          bdi_valid => bdi_valid,
          bdi_ready => bdi_ready
        );

    -- 2. Proses Pembangkitan Clock
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;
 
    -- 3. Proses Stimulus (Skenario Uji)
    stim_proc: process
    begin		
        -- Inisialisasi: Reset sistem
        rst <= '1';
        wait for 20 ns;	
        rst <= '0';
        
        -- Skenario 1: Generate Nonce Pertama (Mode A)
        report "Memulai Transmisi Nonce Pertama (Mode A)...";
        mode_sel <= '0'; -- Pilih Offset A
        start    <= '1'; -- Trigger Start
        wait for clk_period;
        start    <= '0'; -- Matikan Trigger
        
        -- Simulasikan Penerima (Core) yang Siap Menerima Data
        -- Kita set bdi_ready = '1' agar data mengalir lancar tiap clock
        bdi_ready <= '1';
        
        -- Tunggu hingga 4 paket data terkirim (4 clock cycles)
        wait for clk_period * 5; 
        bdi_ready <= '0'; -- Penerima berhenti menerima
        
        wait for 50 ns; -- Jeda waktu antar operasi

        -- Skenario 2: Generate Nonce Kedua (Mode B)
        report "Memulai Transmisi Nonce Kedua (Mode B)...";
        mode_sel <= '1'; -- Pilih Offset B
        start    <= '1';
        wait for clk_period;
        start    <= '0';
        
        -- Simulasikan Penerima dengan 'Backpressure' (Ready kadang 0, kadang 1)
        -- Paket 1
        wait for clk_period; 
        bdi_ready <= '1'; -- Terima Paket 1
        wait for clk_period;
        bdi_ready <= '0'; -- Penerima sibuk (Pause)
        wait for clk_period * 2;
        
        -- Paket 2, 3, 4
        bdi_ready <= '1'; -- Lanjutkan terima sisa paket
        wait for clk_period * 4;
        bdi_ready <= '0';

        report "Simulasi Selesai.";
        wait;
    end process;

END;
