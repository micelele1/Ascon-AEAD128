library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_transmit is
    port(
        clk                     :   in  std_logic;
        en_uart_transmit        :   in  std_logic;
        paralel_in              :   in  std_logic_vector(511 downto 0);
        serial_out              :   out std_logic;
        uart_transmitted_flag   :   out std_logic   
    );
end entity;
architecture behavior of UART_transmit is
    component uart_tx is
        port	(
                    i_CLOCK	:	in std_logic							;
                    i_START	:	in std_logic							;		----Signal from TOP to begin transmission
                    o_BUSY	:	out std_logic	:= '1'						;		----Signal to TOP to wait until transmission has finished
                    i_DATA	:	in std_logic_vector(7 downto 0)			;		----Data vector from TOP
                    o_TX_LINE:	out std_logic	:='1'							----Uart output to TOP

                );
    end component;

    component mux_UART_transmit is 
        port(
            clk                  :   in  std_logic;   
            data_in              :   in  std_logic_vector (511 downto 0);
            increment_selector   :   in  std_logic;
            reset_selector       :   in  std_logic;
            data_out             :   out std_logic_vector (7 downto 0);
            done_64              :   out std_logic
        );
    end component;
--    mux_UART_transmit_implemented   :   mux_UART_transmit port map(clk, paralel_in, increment_selector_sig, reset_selector, muxtouarttx, done_64_sig);
    component FSM_uart_transmit is
        port(clk                    :   in  std_logic;
            en_UART_transmit        :   in  std_logic;
            done                    :   in  std_logic;
            done_64                 :   in  std_logic;
            start                   :   out std_logic;
            uart_transmitted_flag   :   out std_logic;
            reset_selector          :   out std_logic
            );
    end component;   -- FSM_uart_transmit_inst          : FSM_uart_transmit port map(clk, en_uart_transmit, reset, done_sig, done_64_sig, start_sig, uart_transmitted_flag, increment_selector_sig, reset_selector);

	 component transmittingtodone is
		port(clk	:	in STD_LOGIC;
		transmitting	:	in 	std_logic;
				done			:	out 	std_logic);
	 end component;

    signal start_sig                 :   std_logic := '0';
    signal done_sig                  :   std_logic := '0';
    signal done_64_sig              :   std_logic := '0';
    signal increment_selector_sig   :   std_logic := '0';
    signal muxtouarttx              :   std_logic_vector(7 downto 0) := (others => '0');
    signal transmittingsig          :   std_logic  := '1';
    signal reset_selector           :   std_logic := '0';
	 signal transmittingused			:	std_logic := '0';
           -- when starting =>
               -- reset_selector <= '0';
             --   start <= '0';
                --uart_transmitted_flag <= '0';
                --increment_selector <= '0';
                --if (en_UART_transmit = '1') then
                 --   nextstate <= sending_each_byte;
                --else
                  --  nextstate <= starting;
               -- end if;

begin
    uart_tx_implemented :   uart_tx port map(clk, start_sig, transmittingsig, muxtouarttx, serial_out);
	 done_sig <= not transmittingsig;
    --transmittingdoneimplemented	:	transmittingtodone port map (clk, transmittingsig, done_Sig);
    mux_UART_transmit_implemented   :   mux_UART_transmit port map(clk, paralel_in, done_sig, reset_selector, muxtouarttx, done_64_sig);
    FSM_uart_transmit_inst          :   FSM_uart_transmit port map(clk, en_uart_transmit, done_sig, done_64_sig, start_sig, uart_transmitted_flag, reset_selector);
end architecture;
--UART TRANSMIT MULTIPLEXER 
--FSM_UART_TRANSMIT v
