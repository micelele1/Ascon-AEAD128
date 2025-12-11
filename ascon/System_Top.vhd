LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.LWC_config_ccw.ALL;

ENTITY System_Top IS
    PORT (
        clk           : IN  STD_LOGIC;
        rst           : IN  STD_LOGIC;
        key_in        : IN  STD_LOGIC_VECTOR(CCSW-1 DOWNTO 0);
        key_valid_in  : IN  STD_LOGIC;
        ext_data_in   : IN  STD_LOGIC_VECTOR(CCW-1 DOWNTO 0);
        ext_valid_in  : IN  STD_LOGIC;
        start_nonce   : IN  STD_LOGIC;
        nonce_sel_pin : IN  STD_LOGIC;
        
        bdi_eot       : IN  STD_LOGIC;
        bdi_eoi       : IN  STD_LOGIC;
        bdi_type      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
        decrypt_in    : IN  STD_LOGIC;
        key_update    : IN  STD_LOGIC;
        
        data_out      : OUT STD_LOGIC_VECTOR(CCW-1 DOWNTO 0);
        valid_out     : OUT STD_LOGIC;
        ready_out     : OUT STD_LOGIC
    );
END System_Top;

ARCHITECTURE Structural OF System_Top IS

    -- Internal Signals
    SIGNAL w_nonce_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL w_nonce_valid : STD_LOGIC;
    
    -- Core Signals
    SIGNAL w_core_ready  : STD_LOGIC;
    SIGNAL w_core_valid  : STD_LOGIC;
    SIGNAL w_core_data   : STD_LOGIC_VECTOR(CCW-1 DOWNTO 0);
    
    -- Mux Signals
    SIGNAL w_bdi_mux     : STD_LOGIC_VECTOR(CCW-1 DOWNTO 0);
    SIGNAL w_valid_mux   : STD_LOGIC;
    SIGNAL w_type_mux    : STD_LOGIC_VECTOR(3 DOWNTO 0);

    -- SIGNAL SANITIZER FUNCTION
    -- Converts any input to a definite '0' or '1'.
    -- 'U', 'X', 'Z' are treated as '0'.
    function safe_logic(input : std_logic) return boolean is
    begin
        if (to_x01(input) = '1') then
            return true;
        else
            return false;
        end if;
    end function;

BEGIN

    -- 1. NONCE GENERATOR
    U_NonceGen: ENTITY work.Nonce128
    PORT MAP (
        clk       => clk,
        rst       => rst,
        start     => start_nonce,
        mode_sel  => nonce_sel_pin,
        bdi_out   => w_nonce_data,
        bdi_valid => w_nonce_valid,
        bdi_ready => w_core_ready
    );

    -- 2. SAFE MULTIPLEXER PROCESS
    -- Uses a process for clearer control over priority and 'U' signal handling
    process(w_nonce_valid, w_nonce_data, ext_data_in, ext_valid_in, bdi_type)
    begin
        -- Check if Nonce Valid is strictly '1'
        if safe_logic(w_nonce_valid) then
            -- Internal Mode (Nonce)
            w_bdi_mux   <= w_nonce_data;
            w_valid_mux <= '1';
            w_type_mux  <= "0010"; -- Header Type: Nonce (NPUB)
        else
            -- External Mode (User Input)
            w_bdi_mux   <= ext_data_in;
            w_valid_mux <= ext_valid_in;
            w_type_mux  <= bdi_type;
        end if;
    end process;

    -- 3. CRYPTO CORE
    U_Core: ENTITY work.CryptoCore
    PORT MAP (
        clk             => clk,
        rst             => rst,
        key             => key_in,
        key_valid       => key_valid_in,
        key_ready       => OPEN,
        
        bdi             => w_bdi_mux,
        bdi_valid       => w_valid_mux,
        bdi_ready       => w_core_ready,
        
        bdi_pad_loc     => (OTHERS => '0'),
        bdi_valid_bytes => (OTHERS => '1'),
        bdi_size        => "100", 
        bdi_eot         => bdi_eot,
        bdi_eoi         => bdi_eoi,
        bdi_type        => w_type_mux, -- Use the Muxed Type
        
        decrypt_in      => decrypt_in,
        key_update      => key_update,
        
        bdo             => w_core_data,
        bdo_valid       => w_core_valid,
        bdo_ready       => '1', 
        
        bdo_type        => OPEN,
        bdo_valid_bytes => OPEN,
        end_of_block    => OPEN,
        msg_auth_valid  => OPEN,
        msg_auth_ready  => '1',
        msg_auth        => OPEN
    );

    -- 4. OUTPUT DRIVER (Safe Logic for Ready Out)
    -- Prevents Ready from being 'U' during reset or when w_nonce_valid is 'U'
    ready_out <= '0' when safe_logic(rst) else          -- Reset: Ready 0
                 '0' when safe_logic(w_nonce_valid) else -- Nonce Busy: Ready 0
                 w_core_ready;                           -- Normal: Follow Core

    -- Output Data & Valid
    data_out  <= (OTHERS => '0') when safe_logic(rst) else w_core_data;
    valid_out <= '0'             when safe_logic(rst) else w_core_valid;

END Structural;