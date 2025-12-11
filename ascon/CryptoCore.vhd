LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_misc.ALL;

-- Pastikan file paket ini ada di folder project Anda
use work.LWC_config_ascon.all;
use work.LWC_config_ccw.all;
use work.design_pkg.all;
USE work.NIST_LWAPI_pkg.ALL;

ENTITY CryptoCore IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        
        -- Key Interface
        key : IN STD_LOGIC_VECTOR (CCSW - 1 DOWNTO 0);
        key_valid : IN STD_LOGIC;
        key_ready : OUT STD_LOGIC;
        
        -- Data Input Interface (BDI)
        bdi : IN STD_LOGIC_VECTOR (CCW - 1 DOWNTO 0);
        bdi_valid : IN STD_LOGIC;
        bdi_ready : OUT STD_LOGIC;
        bdi_pad_loc : IN STD_LOGIC_VECTOR (CCWdiv8 - 1 DOWNTO 0);
        bdi_valid_bytes : IN STD_LOGIC_VECTOR (CCWdiv8 - 1 DOWNTO 0);
        bdi_size : IN STD_LOGIC_VECTOR (3 - 1 DOWNTO 0);
        bdi_eot : IN STD_LOGIC; -- End of Type
        bdi_eoi : IN STD_LOGIC; -- End of Input
        bdi_type : IN STD_LOGIC_VECTOR (4 - 1 DOWNTO 0);
        
        -- Control Signals
        decrypt_in : IN STD_LOGIC; -- 0: Encrypt, 1: Decrypt
        key_update : IN STD_LOGIC;
        
        -- Data Output Interface (BDO)
        bdo : OUT STD_LOGIC_VECTOR (CCW - 1 DOWNTO 0);
        bdo_valid : OUT STD_LOGIC;
        bdo_ready : IN STD_LOGIC;
        bdo_type : OUT STD_LOGIC_VECTOR (4 - 1 DOWNTO 0);
        bdo_valid_bytes : OUT STD_LOGIC_VECTOR (CCWdiv8 - 1 DOWNTO 0);
        end_of_block : OUT STD_LOGIC;
        
        -- Authentication Status
        msg_auth_valid : OUT STD_LOGIC;
        msg_auth_ready : IN STD_LOGIC;
        msg_auth : OUT STD_LOGIC -- 1: Valid, 0: Invalid
    );
END CryptoCore;

ARCHITECTURE behavioral OF CryptoCore IS

    -- Constants for ASCON-128
    CONSTANT TAG_SIZE : INTEGER := 128;
    CONSTANT STATE_SIZE : INTEGER := 320;
    CONSTANT IV_SIZE : INTEGER := 64;
    CONSTANT KEY_SIZE : INTEGER := 128;
    CONSTANT NONCE_SIZE : INTEGER := 128; -- NPUB
    
    -- Word calculations
    CONSTANT KEY_WORDS_C : INTEGER := get_words(KEY_SIZE, CCW);
    CONSTANT NONCE_WORDS_C : INTEGER := get_words(NONCE_SIZE, CCW);
    CONSTANT BLOCK_WORDS_C : INTEGER := get_words(DBLK_SIZE, CCW);
    CONSTANT TAG_WORDS_C : INTEGER := get_words(TAG_SIZE, CCW);
    CONSTANT STATE_WORDS_C : INTEGER := get_words(STATE_SIZE, CCW);
    
    -- State Machine Definition
    SIGNAL n_state_s, state_s : state_t;

    -- Internal Signals
    SIGNAL word_idx_s : INTEGER RANGE 0 TO STATE_WORDS_C - 1;
    SIGNAL word_idx_offset_s : INTEGER RANGE 0 TO STATE_WORDS_C - 1;
    
    SIGNAL key_s : std_logic_vector(CCSW - 1 DOWNTO 0);
    SIGNAL key_ready_s : std_logic;
    SIGNAL bdi_ready_s : std_logic;
    SIGNAL bdi_s : std_logic_vector(CCW - 1 DOWNTO 0);
    SIGNAL bdi_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 DOWNTO 0);
    SIGNAL bdi_pad_loc_s : std_logic_vector(CCWdiv8 - 1 DOWNTO 0);

    SIGNAL bdo_s : std_logic_vector(CCW - 1 DOWNTO 0);
    SIGNAL bdo_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 DOWNTO 0);
    SIGNAL bdo_valid_s : std_logic;
    SIGNAL bdo_type_s : std_logic_vector(3 DOWNTO 0);
    SIGNAL end_of_block_s : std_logic;
    SIGNAL msg_auth_valid_s : std_logic;
    SIGNAL bdoo_s : std_logic_vector(CCW - 1 DOWNTO 0);

    -- Internal Flags
    SIGNAL n_decrypt_s, decrypt_s : std_logic;
    SIGNAL n_msg_auth_s, msg_auth_s : std_logic;
    SIGNAL n_eoi_s, eoi_s : std_logic;
    SIGNAL n_eot_s, eot_s : std_logic;
    SIGNAL n_update_key_s, update_key_s : std_logic;
    SIGNAL bdi_partial_s : std_logic;
    SIGNAL pad_added_s : std_logic;
    SIGNAL bit_pos_s : INTEGER RANGE 0 TO 511;

    -- Ascon Core Signals
    SIGNAL ascon_state_s : std_logic_vector(STATE_SIZE - 1 DOWNTO 0);
    SIGNAL ascon_state_n_s : std_logic_vector(STATE_SIZE - 1 DOWNTO 0);
    SIGNAL ascon_cnt_s : std_logic_vector(7 DOWNTO 0);
    SIGNAL ascon_key_s : std_logic_vector(KEY_SIZE - 1 DOWNTO 0);
    SIGNAL ascon_rcon_s : std_logic_vector(3 DOWNTO 0);
    SIGNAL asconp_out_s : std_logic_vector(STATE_SIZE - 1 DOWNTO 0);

BEGIN

    -- Little Endian to Big Endian Conversion (Required for NIST API compliance)
	 key_s <= key;        -- KEEP AS-IS (NO REVERSAL)
	 bdi_s <= bdi;        -- KEEP AS-IS (NONCE + MSG RAW INPUT)
    bdi_valid_bytes_s <= reverse_bit(bdi_valid_bytes);
    bdi_pad_loc_s <= reverse_bit(bdi_pad_loc);
    
    key_ready <= key_ready_s;
    bdi_ready <= bdi_ready_s;
    
    bdo <= reverse_byte(bdo_s);
    bdo_valid_bytes <= reverse_bit(bdo_valid_bytes_s);
    bdo_valid <= bdo_valid_s;
    bdo_type <= bdo_type_s;
    end_of_block <= end_of_block_s;
    msg_auth <= msg_auth_s;
    msg_auth_valid <= msg_auth_valid_s;

    -- Utility Signals
    bdi_partial_s <= or_reduce(bdi_pad_loc_s);
    bit_pos_s <= (word_idx_s MOD (DBLK_SIZE/CCW)) * CCW;
    ascon_rcon_s <= ascon_cnt_s(3 DOWNTO 0);

    ---------------------------------------------------------------------------
    -- Ascon Permutation Core Instantiation
    ---------------------------------------------------------------------------
    i_asconp : ENTITY work.asconp
        PORT MAP(
            state_in => ascon_state_s,
            rcon => ascon_rcon_s,
            state_out => asconp_out_s
        );

    -- Helper: Dynamic Slicing for BDO (Output)
    p_dynslice_bdo : process (word_idx_s, ascon_state_s, word_idx_offset_s)
        variable sel : INTEGER RANGE 0 TO STATE_WORDS_C-1;
    begin
        sel := word_idx_s + word_idx_offset_s;
        -- Safety check for simulation to prevent out of bounds
        if sel < STATE_WORDS_C then
            bdoo_s <= ascon_state_s(CCW-1+CCW*sel DOWNTO CCW*sel);
        else
            bdoo_s <= (others => '0');
        end if;
    end process;

    -- Helper: Dynamic Slicing for BDI (Input/Absorb)
    p_dynslice_bdi : process (word_idx_s, ascon_state_s, word_idx_offset_s, state_s, bdi_s, decrypt_s, bdi_valid_bytes_s, bdi_pad_loc_s, bdoo_s, bdi_eot, bdi_partial_s)
        variable pad1 : STD_LOGIC_VECTOR(CCW-1 DOWNTO 0);
        variable pad2 : STD_LOGIC_VECTOR(CCW-1 DOWNTO 0);
    begin
        -- Padding logic: '0' for Encrypt/AD, 'decrypt_s' used for Decrypt msg
        pad1 := pad_bdi(bdi_s, bdi_valid_bytes_s, bdi_pad_loc_s, bdoo_s, '0');
        pad2 := pad_bdi(bdi_s, bdi_valid_bytes_s, bdi_pad_loc_s, bdoo_s, decrypt_s);
    
        case state_s is
            when ABSORB_AD =>
                ascon_state_n_s <= dyn_slice(pad1, bdi_eot, bdi_partial_s, ascon_state_s, word_idx_s, '0');
            when ABSORB_MSG =>
                -- This handles both Encryption (absorb PT) and Decryption (absorb CT -> recover PT logic inside dyn_slice/pad2)
                ascon_state_n_s <= dyn_slice(pad2, bdi_eot, bdi_partial_s, ascon_state_s, word_idx_s, '0');
            when others =>
                ascon_state_n_s <= ascon_state_s;
        end case;
    end process;

    -- Word Offset Logic
    asdf_CASE : process (word_idx_s, state_s)
    begin
        word_idx_offset_s <= 0;
        CASE state_s IS
            WHEN EXTRACT_TAG | VERIFY_TAG =>
                -- Tag is located at the end of the state (usually bytes 16..31 for 128-bit security)
                word_idx_offset_s <= 192/CCW; 
            WHEN others =>
                null;
        end case;
    end process;

    ----------------------------------------------------------------------------
    -- BDO Multiplexer (Output Logic)
    ----------------------------------------------------------------------------
    bdo_mux : PROCESS (state_s, bdi_s, word_idx_s, bdi_ready_s,
        bdi_valid_bytes_s, bdi_valid, bdi_eot, decrypt_s, ascon_state_s,
        bit_pos_s, bdoo_s)
    BEGIN
        -- Default Initialization
        bdo_s <= (OTHERS => '0');
        bdo_valid_bytes_s <= (OTHERS => '0');
        bdo_valid_s <= '0';
        end_of_block_s <= '0';
        bdo_type_s <= (OTHERS => '0');

        CASE state_s IS

            WHEN ABSORB_MSG =>
                -- ENCRYPTION: Output = State XOR Plaintext
                -- DECRYPTION: Output = State XOR Ciphertext (Recovered Plaintext)
                bdo_s <= bdoo_s XOR bdi_s;
                bdo_valid_bytes_s <= bdi_valid_bytes_s;
                bdo_valid_s <= bdi_ready_s;
                end_of_block_s <= bdi_eot;
                
                IF (decrypt_s = '1') THEN
                    bdo_type_s <= HDR_PT; -- Decryption outputs Plaintext
                ELSE
                    bdo_type_s <= HDR_CT; -- Encryption outputs Ciphertext
                END IF;

            WHEN EXTRACT_TAG =>
                -- Final phase of Encryption: Output the Tag
                bdo_s <= bdoo_s;
                bdo_valid_bytes_s <= (OTHERS => '1');
                bdo_valid_s <= '1';
                bdo_type_s <= HDR_TAG;
                
                IF (word_idx_s = TAG_WORDS_C - 1) THEN
                    end_of_block_s <= '1';
                ELSE
                    end_of_block_s <= '0';
                END IF;

            WHEN OTHERS =>
                -- No Data Output in other states
                NULL;

        END CASE;
    END PROCESS bdo_mux;

    ----------------------------------------------------------------------------
    -- Registers (Synchronous Process)
    ----------------------------------------------------------------------------
    p_reg : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF (rst = '1') THEN
                msg_auth_s <= '1';
                eoi_s <= '0';
                eot_s <= '0';
                update_key_s <= '0';
                decrypt_s <= '0';
                state_s <= IDLE;
            ELSE
                msg_auth_s <= n_msg_auth_s;
                eoi_s <= n_eoi_s;
                eot_s <= n_eot_s;
                update_key_s <= n_update_key_s;
                decrypt_s <= n_decrypt_s;
                state_s <= n_state_s;
            END IF;
        END IF;
    END PROCESS p_reg;

    ----------------------------------------------------------------------------
    -- Next State FSM (Control Logic)
    ----------------------------------------------------------------------------
    p_next_state : PROCESS (state_s, key_valid, key_ready_s, key_update, bdi_valid,
        bdi_ready_s, bdi_eot, bdi_eoi, eoi_s, eot_s, bdi_type, bdi_pad_loc_s,
        word_idx_s, decrypt_s, bdo_valid_s, bdo_ready,
        msg_auth_valid_s, msg_auth_ready, bdi_partial_s, ascon_cnt_s, pad_added_s)
    BEGIN
        n_state_s <= state_s;

        CASE state_s IS

            WHEN IDLE =>
                -- Only check for Key or Data (Hash check removed)
                IF (key_valid = '1' OR bdi_valid = '1') THEN
                     n_state_s <= STORE_KEY;
                END IF;

            WHEN STORE_KEY =>
                -- Wait for Key update
                IF (((key_valid = '1' AND key_ready_s = '1') OR key_update = '0') AND word_idx_s >= KEY_WORDS_C - 1) THEN
                    n_state_s <= STORE_NONCE;
                END IF;

            WHEN STORE_NONCE =>
                -- Wait for Nonce (IV)
                IF (bdi_valid = '1' AND bdi_ready_s = '1' AND word_idx_s >= NONCE_WORDS_C - 1) THEN
                    n_state_s <= INIT_STATE_SETUP;
                END IF;

            WHEN INIT_STATE_SETUP =>
                n_state_s <= INIT_PROCESS;

            WHEN INIT_PROCESS =>
                -- Ascon Initial Permutation
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(UROL, ascon_cnt_s'length))) THEN
                    -- Always go to Key Addition (Hash path removed)
                    n_state_s <= INIT_KEY_ADD;
                END IF;

            WHEN INIT_KEY_ADD =>
                IF (eoi_s = '1') THEN
                    n_state_s <= DOM_SEP;
                ELSE
                    n_state_s <= ABSORB_AD;
                END IF;

            WHEN ABSORB_AD =>
                -- Processing Associated Data (Header)
                IF (bdi_valid = '1' AND bdi_type /= HDR_AD) THEN
                    n_state_s <= DOM_SEP;
                ELSIF (bdi_valid = '1' AND bdi_ready_s = '1' AND (bdi_eot = '1' OR word_idx_s >= BLOCK_WORDS_C - 1)) THEN
                    n_state_s <= PROCESS_AD;
                END IF;

            WHEN PROCESS_AD =>
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(UROL, ascon_cnt_s'length))) THEN
                    IF (pad_added_s = '0') THEN
                        IF (eot_s = '1') THEN
                            n_state_s <= PAD_AD;
                        ELSE
                            n_state_s <= ABSORB_AD;
                        END IF;
                    ELSE
                        n_state_s <= DOM_SEP;
                    END IF;
                END IF;

            WHEN PAD_AD =>
                n_state_s <= PROCESS_AD;

            WHEN DOM_SEP =>
                IF (eoi_s = '1') THEN
                    n_state_s <= PAD_MSG;
                ELSE
                    n_state_s <= ABSORB_MSG;
                END IF;

            WHEN ABSORB_MSG =>
                -- Core Processing Loop (Encrypt or Decrypt)
                IF (bdi_ready_s = '1') THEN
                    IF (eoi_s = '1') THEN
                        n_state_s <= FINAL_KEY_ADD_1;
                    ELSE
                        IF (bdi_eot = '1') THEN
                            IF (word_idx_s < BLOCK_WORDS_C - 1 OR bdi_partial_s = '1') THEN
                                n_state_s <= FINAL_KEY_ADD_1;
                            ELSE
                                n_state_s <= PROCESS_MSG;
                            END IF;
                        ELSIF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
                            n_state_s <= PROCESS_MSG;
                        END IF;
                    END IF;
                END IF;

            WHEN PROCESS_MSG =>
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(UROL,ascon_cnt_s'length))) THEN
                    IF (eoi_s = '1') THEN
                        n_state_s <= PAD_MSG;
                    ELSE
                        n_state_s <= ABSORB_MSG;
                    END IF;
                END IF;

            WHEN PAD_MSG =>
                n_state_s <= FINAL_KEY_ADD_1;

            WHEN FINAL_KEY_ADD_1 =>
                n_state_s <= FINAL_PROCESS;

            WHEN FINAL_PROCESS =>
                IF (ascon_cnt_s = std_logic_vector(to_unsigned(UROL,ascon_cnt_s'length))) THEN
                    n_state_s <= FINAL_KEY_ADD_2;
                END IF;

            WHEN FINAL_KEY_ADD_2 =>
                -- BRANCHING POINT: Encrypt -> Extract Tag | Decrypt -> Verify Tag
                IF (decrypt_s = '1') THEN
                    n_state_s <= VERIFY_TAG; -- Decryption Path
                ELSE
                    n_state_s <= EXTRACT_TAG; -- Encryption Path
                END IF;

            WHEN EXTRACT_TAG =>
                -- For Encryption: Send Tag to Output
                IF (bdo_valid_s = '1' AND bdo_ready = '1' AND word_idx_s >= TAG_WORDS_C - 1) THEN
                    n_state_s <= IDLE;
                END IF;

            WHEN VERIFY_TAG =>
                -- For Decryption: Receive Tag from Input and Verify
                IF (bdi_valid = '1' AND bdi_ready_s = '1' AND word_idx_s >= TAG_WORDS_C - 1) THEN
                    n_state_s <= WAIT_ACK;
                END IF;

            WHEN WAIT_ACK =>
                IF (msg_auth_valid_s = '1' AND msg_auth_ready = '1') THEN
                    n_state_s <= IDLE;
                END IF;

            WHEN OTHERS =>
                n_state_s <= IDLE;
        END CASE;
    END PROCESS p_next_state;

    ----------------------------------------------------------------------------
    -- Decoder Process (Input Parsing)
    ----------------------------------------------------------------------------
    p_decoder : PROCESS (state_s, key_valid, key_update, update_key_s, eot_s,
        bdi_s, bdi_valid, bdi_ready_s, bdi_eoi, bdi_eot,
        bdi_size, bdi_type, eoi_s, decrypt_in, decrypt_s,
        bdo_ready, word_idx_s, msg_auth_s, bdoo_s)
    BEGIN
        -- Default Latch Prevention
        key_ready_s <= '0';
        bdi_ready_s <= '0';
        msg_auth_valid_s <= '0';
        n_msg_auth_s <= msg_auth_s;
        n_eoi_s <= eoi_s;
        n_eot_s <= eot_s;
        n_update_key_s <= update_key_s;
        n_decrypt_s <= decrypt_s;

        CASE state_s IS

            WHEN IDLE =>
                n_msg_auth_s <= '1';
                n_eoi_s <= '0';
                n_eot_s <= '0';
                n_update_key_s <= '0';
                n_decrypt_s <= '0';
                
                IF (key_valid = '1' AND key_update = '1') THEN
                    n_update_key_s <= '1';
                END IF;

            WHEN STORE_KEY =>
                IF (update_key_s = '1') THEN
                    key_ready_s <= '1';
                END IF;

            WHEN STORE_NONCE =>
                bdi_ready_s <= '1';
                n_eoi_s <= bdi_eoi;
                -- CAPTURE MODE: Encrypt (0) or Decrypt (1)
                n_decrypt_s <= decrypt_in;

            WHEN ABSORB_AD =>
                IF (bdi_valid = '1' AND bdi_type = HDR_AD) THEN
                    bdi_ready_s <= '1';
                    n_eoi_s <= bdi_eoi;
                    n_eot_s <= bdi_eot;
                END IF;

            WHEN ABSORB_MSG =>
                IF (bdi_valid = '1' AND (bdi_type = HDR_PT OR bdi_type = HDR_CT)) THEN
                    bdi_ready_s <= bdo_ready;
                    IF (bdi_ready_s = '1') THEN
                        n_eoi_s <= bdi_eoi;
                        n_eot_s <= bdi_eot;
                    END IF;
                END IF;

            WHEN VERIFY_TAG =>
                bdi_ready_s <= '1';
                IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_TAG) THEN
                    -- CRITICAL: Check input tag against calculated tag (bdoo_s)
                    IF (bdi_s /= bdoo_s) THEN
                        n_msg_auth_s <= '0'; -- Auth Fail
                    END IF;
                END IF;

            WHEN WAIT_ACK =>
                msg_auth_valid_s <= '1';

            WHEN OTHERS =>
                NULL;
        END CASE;
    END PROCESS p_decoder;

    ----------------------------------------------------------------------------
    -- Word Counters
    ----------------------------------------------------------------------------
    p_counters : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF (rst = '1') THEN
                word_idx_s <= 0;
            ELSE
                CASE state_s IS
                    WHEN IDLE => word_idx_s <= 0;
                    
                    WHEN STORE_KEY =>
                        IF (key_update = '1') THEN
                            IF (key_valid = '1' AND key_ready_s = '1') THEN
                                IF (word_idx_s >= KEY_WORDS_C - 1) THEN word_idx_s <= 0;
                                ELSE word_idx_s <= word_idx_s + 1; END IF;
                            END IF;
                        ELSE
                            IF (word_idx_s >= KEY_WORDS_C - 1) THEN word_idx_s <= 0;
                            ELSE word_idx_s <= word_idx_s + 1; END IF;
                        END IF;

                    WHEN STORE_NONCE =>
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            IF (word_idx_s >= NONCE_WORDS_C - 1) THEN word_idx_s <= 0;
                            ELSE word_idx_s <= word_idx_s + 1; END IF;
                        END IF;

                    WHEN ABSORB_AD | ABSORB_MSG =>
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            IF (word_idx_s >= BLOCK_WORDS_C - 1 OR (bdi_eot = '1' AND bdi_partial_s = '1')) THEN
                                word_idx_s <= 0;
                            ELSE
                                word_idx_s <= word_idx_s + 1;
                            END IF;
                        END IF;

                    WHEN PAD_AD | DOM_SEP | PAD_MSG | FINAL_PROCESS | FINAL_KEY_ADD_2 =>
                        word_idx_s <= 0;

                    WHEN EXTRACT_TAG =>
                        IF (bdo_valid_s = '1' AND bdo_ready = '1') THEN
                            IF (word_idx_s >= TAG_WORDS_C - 1) THEN word_idx_s <= 0;
                            ELSE word_idx_s <= word_idx_s + 1; END IF;
                        END IF;

                    WHEN VERIFY_TAG =>
                        IF (bdi_valid = '1' AND bdi_ready_s = '1' AND bdi_type = HDR_TAG) THEN
                            IF (n_state_s = WAIT_ACK) THEN word_idx_s <= 0;
                            ELSE word_idx_s <= word_idx_s + 1; END IF;
                        END IF;

                    WHEN OTHERS => NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS p_counters;

    ----------------------------------------------------------------------------
    -- ASCON Data Path FSM (State Updates) - FIXED RESET
    ----------------------------------------------------------------------------
    p_ascon_fsm : PROCESS (clk)
        -- local variables used for slicing
        variable hi_idx : integer;
        variable lo_idx : integer;
    BEGIN
        IF rising_edge(clk) THEN
            IF (rst = '1') THEN
                -- [FIX] Reset semua register data path ke 0 agar tidak 'U'/'X'
                ascon_state_s <= (OTHERS => '0');
                ascon_key_s   <= (OTHERS => '0');
                ascon_cnt_s   <= (OTHERS => '0');
                pad_added_s   <= '0';
            ELSE
                CASE state_s IS
						  WHEN STORE_KEY =>
								IF (key_update = '1' AND key_valid = '1' AND key_ready_s = '1') THEN
									 case word_idx_s is
											when 0 => ascon_key_s(127 downto 96) <= key_s;
											when 1 => ascon_key_s(95  downto 64) <= key_s;
											when 2 => ascon_key_s(63  downto 32) <= key_s;
											when 3 => ascon_key_s(31  downto 0)  <= key_s;
											when others => null;
									 end case;
								END IF;


                    WHEN STORE_NONCE =>
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            ascon_state_s(IV_SIZE + KEY_SIZE + CCW*word_idx_s + CCW - 1 DOWNTO IV_SIZE + KEY_SIZE + CCW*word_idx_s) <= bdi_s;
                        END IF;

                    WHEN INIT_STATE_SETUP =>
                        -- Setup IV || Key || Nonce
                        ascon_state_s(IV_SIZE - 1 DOWNTO 0) <= IV_AEAD;
                        ascon_state_s(IV_SIZE + KEY_SIZE - 1 DOWNTO IV_SIZE) <= ascon_key_s;
                        ascon_cnt_s <= ROUNDS_A;
                        pad_added_s <= '0';

                    WHEN INIT_PROCESS | PROCESS_AD | PROCESS_MSG | FINAL_PROCESS =>
                        ascon_state_s <= asconp_out_s;
                        -- Kurangi round counter
                        ascon_cnt_s <= std_logic_vector(unsigned(ascon_cnt_s) - to_unsigned(UROL, ascon_cnt_s'length));

                    WHEN ABSORB_AD =>
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            ascon_state_s <= ascon_state_n_s;
                            IF (bdi_eot = '1') THEN
                                ascon_cnt_s <= ROUNDS_B;
                                IF (bdi_partial_s = '1' OR word_idx_s < BLOCK_WORDS_C - 1) THEN
                                    pad_added_s <= '1';
                                END IF;
                            ELSIF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
                                ascon_cnt_s <= ROUNDS_B;
                            END IF;
                        END IF;

                    WHEN INIT_KEY_ADD =>
                         ascon_cnt_s <= ROUNDS_B;
                         ascon_state_s(STATE_SIZE - 1 DOWNTO STATE_SIZE - KEY_SIZE) <= ascon_state_s(STATE_SIZE - 1 DOWNTO STATE_SIZE - KEY_SIZE) XOR ascon_key_s(KEY_SIZE - 1 DOWNTO 0);

                    WHEN PAD_AD =>
                        ascon_state_s(319 DOWNTO 312) <= ascon_state_s(319 DOWNTO 312) XOR X"80";
                        pad_added_s <= '1';
                        ascon_cnt_s <= ROUNDS_B;

                    WHEN DOM_SEP =>
                        ascon_state_s(STATE_SIZE - 8) <= ascon_state_s(STATE_SIZE - 8) XOR '1';
                        pad_added_s <= '0';

                    WHEN ABSORB_MSG =>
                        IF (bdi_valid = '1' AND bdi_ready_s = '1') THEN
                            ascon_state_s <= ascon_state_n_s;
                            IF (bdi_eot = '1') THEN
                                ascon_cnt_s <= ROUNDS_B;
                                IF (bdi_partial_s = '1' OR word_idx_s < BLOCK_WORDS_C - 1) THEN
                                    pad_added_s <= '1';
                                END IF;
                            ELSIF (word_idx_s >= BLOCK_WORDS_C - 1) THEN
                                ascon_cnt_s <= ROUNDS_B;
                            END IF;
                        END IF;

                    WHEN PAD_MSG =>
                        ascon_state_s(319 DOWNTO 312) <= ascon_state_s(319 DOWNTO 312) XOR X"80";
                        pad_added_s <= '1';

                    WHEN FINAL_KEY_ADD_1 =>
                        ascon_state_s(KEY_SIZE + DBLK_SIZE - 1 DOWNTO DBLK_SIZE) <= ascon_state_s(KEY_SIZE + DBLK_SIZE - 1 DOWNTO DBLK_SIZE) XOR ascon_key_s;
                        ascon_cnt_s <= ROUNDS_A;

                    WHEN FINAL_KEY_ADD_2 =>
                        ascon_state_s(STATE_SIZE - 1 DOWNTO STATE_SIZE - KEY_SIZE) <= ascon_state_s(STATE_SIZE - 1 DOWNTO STATE_SIZE - KEY_SIZE) XOR ascon_key_s(KEY_SIZE - 1 DOWNTO 0);

                    WHEN OTHERS =>
                        NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS p_ascon_fsm;
END behavioral;
