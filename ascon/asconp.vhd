LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY asconp IS
    PORT (
        state_in  : IN  STD_LOGIC_VECTOR(319 DOWNTO 0);
        rcon      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
        state_out : OUT STD_LOGIC_VECTOR(319 DOWNTO 0)
    );
END asconp;

ARCHITECTURE behavioral OF asconp IS

    -- Definisi Tipe Array 5x64-bit untuk State Ascon
    TYPE state_array_t IS ARRAY (0 TO 4) OF STD_LOGIC_VECTOR(63 DOWNTO 0);

    -- Tabel Konstanta Ronde
    TYPE rcon_table_t IS ARRAY (0 TO 15) OF STD_LOGIC_VECTOR(63 DOWNTO 0);
    CONSTANT RCON_LUT : rcon_table_t := (
        X"00000000000000F0", X"00000000000000E1", X"00000000000000D2", X"00000000000000C3",
        X"00000000000000B4", X"00000000000000A5", X"0000000000000096", X"0000000000000087",
        X"0000000000000078", X"0000000000000069", X"000000000000005A", X"000000000000004B",
        X"000000000000003C", X"000000000000002D", X"000000000000001E", X"000000000000000F"
    );

    -- Fungsi Rotate Right 64-bit
    FUNCTION rotr64(val : STD_LOGIC_VECTOR(63 DOWNTO 0); n : INTEGER) RETURN STD_LOGIC_VECTOR IS
        VARIABLE r : INTEGER := n MOD 64;
        VARIABLE outv : STD_LOGIC_VECTOR(63 DOWNTO 0);
    BEGIN
        IF r = 0 THEN
            RETURN val;
        ELSE
            outv := val(r-1 DOWNTO 0) & val(63 DOWNTO r);
            RETURN outv;
        END IF;
    END FUNCTION;

BEGIN
    process(state_in, rcon)
        -- Gunakan tipe yang sudah didefinisikan di atas
        variable S : state_array_t; 
        variable T : state_array_t;
        variable rc64 : STD_LOGIC_VECTOR(63 DOWNTO 0);
        variable i : integer;
    begin
        -- 1) Split input
        S(0) := state_in(319 DOWNTO 256);
        S(1) := state_in(255 DOWNTO 192);
        S(2) := state_in(191 DOWNTO 128);
        S(3) := state_in(127 DOWNTO 64);
        S(4) := state_in(63  DOWNTO 0);

        -- 2) Round constant
        rc64 := RCON_LUT(to_integer(unsigned(rcon)));

        -- (a-d) Substitution & Constant Addition
        S(2) := S(2) XOR rc64;
        S(0) := S(0) XOR S(4);
        S(4) := S(4) XOR S(3);
        S(2) := S(2) XOR S(1);

        -- (e) Non-linear layer (S-Box)
        for i in 0 to 4 loop
            T(i) := (NOT S(i)) AND S((i+1) mod 5);
        end loop;
        for i in 0 to 4 loop
            S(i) := S(i) XOR T((i+1) mod 5);
        end loop;

        -- (f) Linear mixing
        S(1) := S(1) XOR S(0);
        S(0) := S(0) XOR S(4);
        S(3) := S(3) XOR S(2);
        S(2) := NOT S(2);

        -- (g) Linear diffusion
        S(0) := S(0) XOR rotr64(S(0), 19) XOR rotr64(S(0), 28);
        S(1) := S(1) XOR rotr64(S(1), 61) XOR rotr64(S(1), 39);
        S(2) := S(2) XOR rotr64(S(2), 1)  XOR rotr64(S(2), 6);
        S(3) := S(3) XOR rotr64(S(3), 10) XOR rotr64(S(3), 17);
        S(4) := S(4) XOR rotr64(S(4), 7)  XOR rotr64(S(4), 41);

        -- (h) Repack output
        state_out <= S(0) & S(1) & S(2) & S(3) & S(4);
    end process;

END behavioral;