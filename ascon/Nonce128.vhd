LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY Nonce128 IS
    PORT (
        clk       : IN  STD_LOGIC;
        rst       : IN  STD_LOGIC;
        -- Kontrol
        start     : IN  STD_LOGIC; -- Trigger untuk hitung & kirim nonce
        mode_sel  : IN  STD_LOGIC; -- Pilih Offset A atau B
        
        -- Interface Handshake ke Core (langsung 32-bit)
        bdi_out   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        bdi_valid : OUT STD_LOGIC;
        bdi_ready : IN  STD_LOGIC
    );
END ENTITY;

ARCHITECTURE rtl OF Nonce128 IS
    -- Konstanta
    CONSTANT LOWER_WIDTH : INTEGER := 96;
    CONSTANT UPPER_WIDTH : INTEGER := 32;
    
    -- Offset Constants (128-bit)
    CONSTANT OFFSET_A : unsigned(127 downto 0) := x"0000000000000000000000000000ABCD";
    CONSTANT OFFSET_B : unsigned(127 downto 0) := x"00000000000000000000000000000EF0";

    -- Internal Registers
    SIGNAL lower_cnt   : unsigned(LOWER_WIDTH - 1 downto 0);
    SIGNAL upper_cnt   : unsigned(UPPER_WIDTH - 1 downto 0);
    SIGNAL nonce_reg   : std_logic_vector(127 downto 0); -- Buffer nonce penuh
    
    -- FSM Signals
    TYPE state_t IS (IDLE, SEND_0, SEND_1, SEND_2, SEND_3);
    SIGNAL state : state_t;

BEGIN

    PROCESS (clk)
        VARIABLE v_full_nonce : unsigned(127 downto 0);
        VARIABLE v_offset     : unsigned(127 downto 0);
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                lower_cnt <= (others => '0');
                upper_cnt <= (others => '0');
                state     <= IDLE;
                bdi_valid <= '0';
                bdi_out   <= (others => '0');
            ELSE
                CASE state IS
                    WHEN IDLE =>
                        bdi_valid <= '0';
                        
                        IF start = '1' THEN
                            -- 1. Hitung Nonce Baru
                            IF lower_cnt = (lower_cnt'range => '1') THEN
                                upper_cnt <= upper_cnt + 1;
                            END IF;
                            lower_cnt <= lower_cnt + 1;
                            
                            -- 2. Pilih Offset & Jumlahkan
                            IF mode_sel = '0' THEN v_offset := OFFSET_A;
                            ELSE v_offset := OFFSET_B;
                            END IF;
                            
                            v_full_nonce := (upper_cnt & lower_cnt) + v_offset;
                            nonce_reg    <= std_logic_vector(v_full_nonce);
                            
                            -- 3. Mulai Kirim Paket Pertama (MSB)
                            state <= SEND_0;
                        END IF;

                    WHEN SEND_0 =>
                        bdi_out   <= nonce_reg(127 downto 96);
                        bdi_valid <= '1';
                        IF bdi_ready = '1' THEN
                            state <= SEND_1;
                        END IF;

                    WHEN SEND_1 =>
                        bdi_out   <= nonce_reg(95 downto 64);
                        bdi_valid <= '1';
                        IF bdi_ready = '1' THEN
                            state <= SEND_2;
                        END IF;

                    WHEN SEND_2 =>
                        bdi_out   <= nonce_reg(63 downto 32);
                        bdi_valid <= '1';
                        IF bdi_ready = '1' THEN
                            state <= SEND_3;
                        END IF;

                    WHEN SEND_3 =>
                        bdi_out   <= nonce_reg(31 downto 0);
                        bdi_valid <= '1';
                        IF bdi_ready = '1' THEN
                            state     <= IDLE;
                            bdi_valid <= '0'; -- Selesai
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;
END rtl;
