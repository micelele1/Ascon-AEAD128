LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_asconp IS
-- Testbench tidak punya port
END tb_asconp;

ARCHITECTURE behavior OF tb_asconp IS 

    -- Komponen yang akan diuji (Unit Under Test - UUT)
    COMPONENT asconp
    PORT(
         state_in  : IN  std_logic_vector(319 downto 0);
         rcon      : IN  std_logic_vector(3 downto 0);
         state_out : OUT  std_logic_vector(319 downto 0)
        );
    END COMPONENT;
    
    -- Sinyal Input
    signal state_in : std_logic_vector(319 downto 0) := (others => '0');
    signal rcon     : std_logic_vector(3 downto 0) := (others => '0');

    -- Sinyal Output
    signal state_out : std_logic_vector(319 downto 0);
 
BEGIN
 
    -- 1. Instansiasi Unit asconp
    uut: asconp PORT MAP (
          state_in => state_in,
          rcon => rcon,
          state_out => state_out
        );

    -- 2. Proses Stimulus (Pemberian Data)
    stim_proc: process
    begin		
        -- tunggu 100 ns untuk reset global (opsional)
        wait for 100 ns;	

        ------------------------------------------------------------
        -- KASUS 1: Input Nol Semua, Ronde 0
        ------------------------------------------------------------
        report "Test 1: Input Zero, Round 0";
        state_in <= (others => '0');
        rcon     <= "0000"; -- Index 0
        wait for 10 ns; 
        
        -- Cek visual di waveform:
        -- Input: 000...000
        -- Output: HARUS BERUBAH (Bukan nol lagi)
        
        ------------------------------------------------------------
        -- KASUS 2: Input Nol Semua, Ronde 1
        ------------------------------------------------------------
        report "Test 2: Input Zero, Round 1";
        rcon     <= "0001"; -- Index 1 (Konstanta beda)
        wait for 10 ns;
        
        -- Output harus berbeda dengan hasil Test 1
        
        ------------------------------------------------------------
        -- KASUS 3: Input Real (IV Standar Ascon)
        ------------------------------------------------------------
        report "Test 3: Standard IV Input";
        -- IV Ascon-128: 80400c0600000000 || 0...0 || 0...0
        -- (Disusun dalam 320 bit)
        state_in <= x"80400c0600000000" & x"0000000000000000" & 
                    x"0000000000000000" & x"0000000000000000" & 
                    x"0000000000000000"; 
        rcon <= "0000";
        wait for 10 ns;

        report "Simulasi Selesai. Cek Waveform.";
        wait;
    end process;

END;
