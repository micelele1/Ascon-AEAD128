library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use	ieee.numeric_std.all;

--Pengkode:	Rizmi Ahmad Raihan (13223051)
--Dibuat berdasarkan desain yang tertera dalam tautan berikut: https://app.diagrams.net/#G1nsvZxCwPClMlofGU3MhhJaJaecmI7QmL#%7B%22pageId%22%3A%22Gmq5mF0_Os0wrZyW7HvQ%22%7D
entity uart_recieve is
	port(
		clk					:	in 	std_logic;
		serial_in			:	in 	STD_LOGIC;
		en_uart_recieve		:	in	std_logic;
		reg_out				:	out STD_LOGIC_VECTOR (511 downto 0);
		uart_recieved_flag	:	out std_logic
	);
end uart_recieve;

architecture behavioral of uart_recieve is
	component uart_rx is
		port	(
					i_CLOCK			:	in std_logic;
					en_uart_rx		:	in std_logic;
					i_RX			:	in std_logic; --RX line
					o_DATA			:	out std_logic_vector(7 downto 0)	;
					o_sig_CRRP_DATA	:	out std_logic := '0'			;	---Currupted data flag
					o_BUSY			:	out std_logic
				);
	end component;

	component fsm_uart_recieve is
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
	end component;
		
	component shift_register is
		port(clk        :   in  std_logic;
		 	 reset		  :	in  std_logic;
			 enable     :   in  std_logic;
			 data_in    :   in std_logic_vector(7 downto 0);
			 data_out   :   out std_logic_vector(511 downto 0);
			 done_64    :   out std_logic
		);
	end component;
	
	component transmittingtodone is
	port(	clk				:	in 	std_logic;
			transmitting	:	in 	std_logic;
			done			:	out 	std_logic);
	end component;

	
	          --  when start =>
               -- en_rx <= '1';
                --increment_selector <= '0';
                --uart_recieved_flag <= '0';
				 --INI TERAKHIR DIUBAH 12:37, 29/12/2024
                --if(en_uart_recieve = '0') then 
                  --  nextstate <= start;
						  --reset <= '1';
                --else
                  --  nextstate <= prerecieve;
						 -- reset <= '0';
                --end if;

	signal en_rx_sig				:	std_logic := '0';
	signal finishflag_sig			:	std_logic := '0';
	signal recievingflag_sig		:	std_logic := '1';

	signal uart_rx_to_mux			:	std_logic_vector (7 downto 0) := (others => '0');
	signal corruptedflag			:	std_logic := '0';
	signal done_64_sig				:	std_logic := '0';
	signal increment_selector_sig	:	std_logic := '0';
	signal recievingflagone		:	std_logic := '1';
	signal reset_sig				:	std_logic := '0';
	signal done_sig				:	std_logic := '0';
	signal done_sig_one			:	std_logic := '0';
begin
	done_sig <= not recievingflag_sig;
	toonewidthimplemented				:	transmittingtodone port map(clk, done_sig, done_sig_one);
	recievingflagone 					<= not done_sig_one;
	uart_rx_implemented					:	uart_rx 				port map(clk, en_rx_sig, serial_in, uart_rx_to_mux, corruptedflag, recievingflag_sig);
	fsm_uart_recieve_implemented		:	fsm_uart_recieve		port map(clk, finishflag_sig, recievingflagone, en_uart_recieve, done_64_sig, reset_sig, uart_recieved_flag, en_rx_sig);
	shift_register_implemented			:	shift_register			port map(clk, reset_sig, done_sig_one, uart_rx_to_mux, reg_out, done_64_sig);
end behavioral;