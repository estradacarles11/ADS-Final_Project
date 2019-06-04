library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ADC_control_vm is
generic (n:  integer:=12);
port(
		clk:			in std_logic; 								-- clock input, active by rising edge
		resetn: 		in std_logic;								-- synchronous reset input, active low
		enable:			in std_logic;								-- enable input for the whole ADC
		sdata1: 		in std_logic;								-- serial data input, first converter
		sdata2: 		in std_logic; 								-- serial data input, second converter
		ncs:			out std_logic;								-- output chip select, active low
		sclk:			out std_logic;								-- output clock for the converters, clk/6
		sample_ready:	out std_logic;								-- output flag for the trigger control
		data_out_adc:		out std_logic_vector(n-1 downto 0)			-- output data_out_adc
		
		
);
end ADC_control_vm;
architecture arq of ADC_control_vm is

signal ncs_signal:	std_logic;									-- Output chip select signal internal signal
signal sample_ready_signal:	std_logic;
signal reg_enable:	std_logic;									-- Signal to enable and disable the registers and pass the value of the input data to the data_out_adc 
signal count:		std_logic_vector(2 downto 0);				-- counter signal to generate sclk
signal sclk_count:	std_logic_vector(3 downto 0);				-- counter of sclk periods
signal data_reg1:	std_logic_vector(n-1 downto 0);				-- led registers for first converter
signal data_reg2:	std_logic_vector(n-1 downto 0);				-- led registers for second converter


begin

process(clk)
	begin
		if (clk'event and clk= '1') then						-- Reseting of the system. All the signals must follow the general reset and all the registers should be reseted
			if (resetn = '0' or enable = '0') then								-- Note in this part, the enable for the registers is set to 1
				count <= "000";
				ncs_signal <= '1';
				sclk_count <= x"0";
				data_reg1 <= "000000000000";
				data_reg2 <= "000000000000";
				data_out_adc <= "000000000000";
				sclk <= '0';
				reg_enable <= '1';

			else
				count <= count + "001";
				
				if (count = "010") then						-- count = 2
					sclk <= '1';
				elsif (count = "101") then					-- count = 5
					sclk <= '0';
					count <= "000";
					if ncs_signal = '0' then				-- check that output chip select is set to 0--> active low, note this clocks is 6times lower than
															-- slck and will need to be activated 15 times before needing to show the data in the data_out_adc
															
						if (sclk_count = x"F") then			-- if 15 periods of slck have been passed (which means the 16 bit data has been 
															-- acquired from the ADC, 4 first bits that are 0 and the 12 bits that are converted ones) and 
															-- consequently the data is ready to be shown in the data_out_adc
															
							sclk_count <= x"0";				-- the counter has achieved its maximum value and is set to 0
							ncs_signal <= '1';				-- ncs signal is set to 1 (not active) so that it remains in this state one more clock of sclk.
						else
							sclk_count <= sclk_count + 1;	-- if the counter hasn't arrived to its maximum value its has to follow counting
						end if;
					else
						ncs_signal <= '0';
					end if;			
				end if;
				
				for i in 0 to n-1 loop						-- in this step the data acquired from the sdata1 is 
															-- transferred to the registers (note only the needed bits are transferred--> [0-11]
					if (sclk_count = i+4) then				-- note the first 4 bits (the ones that have always value 0 are not taken into account)
						data_reg1(n-1-i) <= sdata1;
						data_reg2(n-1-i) <= sdata2;
					end if;
				end loop;
				
				if (sclk_count = x"0") then
					reg_enable <= '0';
				elsif (sclk_count = x"F" and count = "101") then -- if arrived to 15 periods and counted to 5 enable the registers to transfer data to the data_out_adc
					reg_enable <= '1';
				end if;

				if (reg_enable  = '1') then					-- transfer the data from the registers to the data_out_adc
					data_out_adc <= data_reg1;
					reg_enable <= '0';
					sample_ready_signal <= '1';
				end if;
				
				if (sample_ready_signal = '1') then
					sample_ready_signal <= '0';
				end if;
				
			end if;
		end if;
end process;

ncs <= ncs_signal;											-- Generation of the output signal
sample_ready <= sample_ready_signal;

end arq;