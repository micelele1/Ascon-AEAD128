LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY asconp IS
    PORT (
        state_in  : IN  STD_LOGIC_VECTOR(319 DOWNTO 0); -- 320-bit State (x0..x4)
        rcon      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);   -- Round index 0..15
        state_out : OUT STD_LOGIC_VECTOR(319 DOWNTO 0)
    );
END asconp;

ARCHITECTURE behavioral OF asconp IS

    -- Round Constant Table (LSB holds the 8-bit RC)
    TYPE rcon_table_t IS ARRAY (0 TO 15) OF STD_LOGIC_VECTOR(63 DOWNTO 0);
    CONSTANT RCON_LUT : rcon_table_t := (
        X"00000000000000F0", X"00000000000000E1", X"00000000000000D2", X"00000000000000C3",
        X"00000000000000B4", X"00000000000000A5", X"0000000000000096", X"0000000000000087",
        X"0000000000000078", X"0000000000000069", X"000000000000005A", X"000000000000004B",
        X"000000000000003C", X"000000000000002D", X"000000000000001E", X"000000000000000F"
    );

    -- safe rotate-right on 64-bit vector (indexing robust for n=0)
    FUNCTION rotr64(val : STD_LOGIC_VECTOR(63 DOWNTO 0); n : INTEGER) RETURN STD_LOGIC_VECTOR IS
        VARIABLE r : INTEGER := n MOD 64;
        VARIABLE outv : STD_LOGIC_VECTOR(63 DOWNTO 0);
    BEGIN
        IF r = 0 THEN
            RETURN val;
        ELSE
            -- For vector(63 downto 0), rotate right by r: new = val(r-1 downto 0) & val(63 downto r)
            outv := val(r-1 DOWNTO 0) & val(63 DOWNTO r);
            RETURN outv;
        END IF;
    END FUNCTION;

BEGIN
    ----------------------------------------------------------------
    -- Combinational single ASCON round (exact reference order)
    ----------------------------------------------------------------
    process(state_in, rcon)
        -- use a 0..4 array of 64-bit lanes to mirror spec S[0..4]
        variable S : array(0 to 4) of STD_LOGIC_VECTOR(63 DOWNTO 0);
        variable T : array(0 to 4) of STD_LOGIC_VECTOR(63 DOWNTO 0);
        variable rc64 : STD_LOGIC_VECTOR(63 DOWNTO 0);
        variable i : integer;
    begin
        -- 1) split input into S[0]..S[4] using the same lane ordering:
        --    state_in = S0 || S1 || S2 || S3 || S4  where S0=bits 319..256 etc.
        S(0) := state_in(319 DOWNTO 256);
        S(1) := state_in(255 DOWNTO 192);
        S(2) := state_in(191 DOWNTO 128);
        S(3) := state_in(127 DOWNTO 64);
        S(4) := state_in(63  DOWNTO 0);

        -- 2) Round constant (64-bit with LSB = RC byte)
        rc64 := RCON_LUT(to_integer(unsigned(rcon)));

        ----------------------------------------------------------------
        -- Reference substitution & constant addition order:
        -- (a) S[2] ^= RC
        -- (b) S[0] ^= S[4]
        -- (c) S[4] ^= S[3]
        -- (d) S[2] ^= S[1]
        ----------------------------------------------------------------
        S(2) := S(2) XOR rc64;
        S(0) := S(0) XOR S(4);
        S(4) := S(4) XOR S(3);
        S(2) := S(2) XOR S(1);

        ----------------------------------------------------------------
        -- (e) Non-linear layer using temp T:
        --     T[i] := (~S[i]) & S[(i+1) mod 5]
        --     then S[i] := S[i] XOR T[(i+1) mod 5]  (parallel)
        ----------------------------------------------------------------
        for i in 0 to 4 loop
            T(i) := (NOT S(i)) AND S((i+1) mod 5);
        end loop;
        for i in 0 to 4 loop
            S(i) := S(i) XOR T((i+1) mod 5);
        end loop;

        ----------------------------------------------------------------
        -- (f) The remaining linear transforms, invert, and diffusion:
        --     S[1] ^= S[0]
        --     S[0] ^= S[4]
        --     S[3] ^= S[2]
        --     S[2] := NOT S[2]
        ----------------------------------------------------------------
        S(1) := S(1) XOR S(0);
        S(0) := S(0) XOR S(4);
        S(3) := S(3) XOR S(2);
        S(2) := NOT S(2);

        ----------------------------------------------------------------
        -- (g) Linear diffusion (apply rotates & xors)
        --     final S[i] := S[i] XOR ROTR(S[i], r1) XOR ROTR(S[i], r2)
        ----------------------------------------------------------------
        S(0) := S(0) XOR rotr64(S(0), 19) XOR rotr64(S(0), 28);
        S(1) := S(1) XOR rotr64(S(1), 61) XOR rotr64(S(1), 39);
        S(2) := S(2) XOR rotr64(S(2), 1)  XOR rotr64(S(2), 6);
        S(3) := S(3) XOR rotr64(S(3), 10) XOR rotr64(S(3), 17);
        S(4) := S(4) XOR rotr64(S(4), 7)  XOR rotr64(S(4), 41);

        ----------------------------------------------------------------
        -- (h) Repack state_out as S0 || S1 || S2 || S3 || S4
        ----------------------------------------------------------------
        state_out <= S(0) & S(1) & S(2) & S(3) & S(4);
    end process;

END behavioral;
