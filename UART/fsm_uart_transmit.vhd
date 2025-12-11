library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity FSM_uart_transmit is
    port(clk                    :   in  std_logic;
        en_UART_transmit        :   in  std_logic;
        done                    :   in  std_logic;
        done_64                 :   in  std_logic;
        start                   :   out std_logic;
        uart_transmitted_flag   :   out std_logic;
        reset_selector          :   out std_logic
        );
end entity;   

architecture behavior of FSM_uart_transmit is
    type state is (starting, sending_each_byte, increment, check_64, last_byte, finished);
    signal currentstate, nextstate : state := starting;
begin
    clocking : process (clk)
    begin
        if(rising_edge(clk)) then
            currentstate <= nextstate; --pindah state ketika rising_edge clk. Clock yang digunakan adalah clock internal FPGA.
        end if;
    end process;

    stateswitch :   process(currentstate, en_UART_transmit, done, done_64)
    begin
		  --reset_selector <= '0';
		  --start <= '0';
		--  uart_transmitted_flag <= '0';
		  --increment_selector <= '0';
		  
        case currentstate is
            when starting => -- state starting adalah initial state
                reset_selector <= '0';
                uart_transmitted_flag <= '0';
                if (en_UART_transmit = '1') then --bila en_UART_transmit dijadikan '1' (dinyalakan) maka start uart_tx dijadikan '1'.
					     start <= '1';
                    nextstate <= sending_each_byte;
                else
						  start <= '0'; 
                    nextstate <= starting;
                end if;
            when sending_each_byte => --sending each byte adalah state mengirimkan tiap karakter
                uart_transmitted_flag <= '0';
					 reset_selector <= '0';
					 if(done = '1') then --bila done (sudah mengirim karakter) akan mengalami increment.
						start   <= '0';
						nextstate <= increment;
					 else
						start   <= '1';
						nextstate <= sending_each_byte;
					end if;
            when increment => --increment, pindah byte.
                start <= '0';
                reset_selector <= '0'; 
                uart_transmitted_flag <= '0';
                nextstate <= check_64;
            when check_64 => --check apakah sudah dikirimkan 63 karakter
                reset_selector <= '0';
					 start <= '0';    
                if (done_64 = '1') then
                    uart_transmitted_flag <= '0';
                    nextstate <= last_byte;
                else
                    uart_transmitted_flag <= '0';
                    nextstate <= sending_each_byte;
                end if;
            when last_byte => --pengiriman karakter terakhir
                if (done = '1') then --bila sudah dikirim paka reset_selector = '1' dan transmitted flag = '1'.
                    uart_transmitted_flag <= '1';
						  reset_selector <= '1';
						  start <= '0';
                    nextstate <= finished;
                else 
                    uart_transmitted_flag <= '0';
						  reset_selector <= '0';
                    nextstate <= last_byte;
						  start <= '1';
                end if;
            when finished => -- selesai mengirim.
                start <= '0';
                reset_selector <= '1';
                uart_transmitted_flag <= '1';
                nextstate <= starting;
        end case;
    end process;
end architecture;