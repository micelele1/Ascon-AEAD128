library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

entity fsm_uart_recieve is
    port(
        clk                             :   in  std_logic;
        finishflag                      :   in  std_logic;
        recievingflag                   :   in  std_logic;
        en_uart_recieve                 :   in  std_logic;
        done_64                         :   in  std_logic;
        reset                           :   out std_logic;                      
        uart_recieved_flag              :   out std_logic;
        en_rx                           :   out std_logic
        );
end fsm_uart_recieve;

architecture rtl of FSM_uart_recieve is
    type state                         is (start, prerecieve, recieving, endrecieving, check64, idle, endall);
    signal currentstate, nextstate      :   state := start; 

begin
    clock   :   process(clk)
    begin
        if(rising_edge(clk)) then --ketika rising edge, pindah ke state selanjutnya berdasarkan nextstate
            currentstate <= nextstate;
        end if;
    end process;

    statetree   :   process(currentstate, en_uart_recieve, recievingflag, done_64)
    begin
        case currentstate is
            when start => --state start, uart_rx dinyalakan. menunggu en_uart_recieve bernilai 1 untuk pindah ke state selanjutnya (diterima bit mulai)
                en_rx <= '1';
                uart_recieved_flag <= '0';
                if(en_uart_recieve = '0') then 
                    nextstate <= start;
						  reset <= '1';
                else
                    nextstate <= prerecieve;
						  reset <= '0';
                end if;
            when prerecieve => --prereceive, sebelum menerima. dinyalakan uart_rx. ini guna menghindari menerima di luar waktu yang ditentukan.
                en_rx <= '1';
                reset <= '0';
                uart_recieved_flag <= '0';
                if(recievingflag = '0') then
                    nextstate <= prerecieve;
                else 
                    nextstate <= recieving;
                end if;
            when recieving => --menerima
                reset <= '0';
                en_rx <= '1';
                uart_recieved_flag <= '0';
                if (recievingflag = '1') then
                    nextstate <= recieving;
                else --selesai menerima 1 karakter
                    nextstate <= endrecieving;
                end if;
            when endrecieving =>
                reset <= '0';
                en_rx <= '1';
                uart_recieved_flag <= '0'; 
                nextstate <= check64;  
            when check64 => --cek 64 byte
                reset <= '0';
                en_rx <= '1';
                uart_recieved_flag <= '0';
                if (done_64 = '1') then --bila sudah, akhiri semua
                    nextstate <= endall;
                else
                    if (recievingflag = '0') then --bila belum menerima lagi masuk idle
                        nextstate <= idle;
                    else
                        nextstate <= recieving;
                    end if;
                end if;
            when idle => -- state idle, belum menerima byte baru.
                en_rx <= '1';
                reset <= '0';
                uart_recieved_Flag <= '0';
                if (recievingflag = '0') then
                    nextstate <= idle;
                else
                    nextstate <= recieving;
                end if;
            when endall => --akhiri semua.
                reset <= '0';
                en_rx <= '1';
                uart_recieved_flag <= '1';
                nextstate <= start;
        end case;
    end process;
end architecture;