library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity trigger_controller is
generic( 
		data_width : natural := 12;
		addr_width : natural := 11);
port(
		clk:			in std_logic; 								-- clock input, active by rising edge
		resetn: 		in std_logic;								-- synchronous reset input, active low
		sample_ready:	in std_logic;								-- input sample in data1 is ready to be read
		data1: 			in std_logic_vector(data_width-1 downto 0);	-- data input, first converter
		trigger_up:		in std_logic;								-- move trigger up
		trigger_down:	in std_logic;								-- move trigger downt
		trigger_n_p:	in std_logic;								-- switch if trigger is sensitive to positive or negative slope
		v_sync:			in std_logic;								-- required to control ADC_enable
		ADC_enable:		out std_logic;								-- enable signal for ADC
		we:				out std_logic;								-- write enable for memory
		trigger_level:	out std_logic_vector(8 downto 0);			-- output value of trigger level
		addr_in:		out std_logic_vector(addr_width-1 downto 0);-- output 
		data_in:		out std_logic_vector(data_width-1 downto 0)	-- output 
);
end trigger_controller;

architecture arq of trigger_controller is

signal trig_status:	std_logic;										-- Trigger status. 1 => positive, 0 => negative
signal trig_level: std_logic_vector(8 downto 0) := "100000000";
signal trig_hold: std_logic;
signal count_hold: std_logic;
signal vsync_hold: std_logic;
signal we_signal: std_logic;
signal count_en:	std_logic;
signal count:		std_logic_vector(10 downto 0);
signal old_data1:	std_logic_vector(data_width-1 downto 0);
signal trig_up_r1: std_logic;
signal trig_up_r2: std_logic;
signal trig_down_r1: std_logic;
signal trig_down_r2: std_logic;
signal trig_n_p_r1: std_logic;
signal trig_n_p_r2: std_logic;

begin

process(clk)
	begin
		if (clk'event and clk='1') then
			if (resetn='0') then
				trig_level <= "100000000";
				trig_status <= '1';
				count_en <= '0';
				count_hold <= '0';
				vsync_hold <= '0';
				count <= "00000000000";
				old_data1 <= "000000000000";
				ADC_enable <= '0';
				we_signal <= '0';
				addr_in <= "00000000000";
				data_in <= "000000000000";
				trig_hold <= '0';
				trig_up_r1 <= '0';
				trig_up_r2 <= '0';
				trig_down_r1 <= '0';
				trig_down_r2 <= '0';
				trig_n_p_r1 <= '0';
				trig_n_p_r2 <= '0';
			else
				if (sample_ready = '1') then
					old_data1 <= data1;
					
					if (trig_level = data1(data_width-1 downto data_width-9)) then
						if (trig_status='1' and data1>old_data1) then
							count_en <= '1';
							count_hold <= '1';
						elsif (trig_status='0' and data1<old_data1) then
							count_en <= '1';
							count_hold <= '1';
						end if;
					end if;
					
					if (count_en='1') then
						count <= count+1;
						we_signal <= '1';
						addr_in <= count;
						data_in <= data1;
					end if;
					if (count="10100000000") then
						count_en <= '0';
					end if;
					
				end if;
				
				if (trig_hold='0' and trig_up_r2='1') then
					trig_level <= trig_level + 16;
					trig_hold <= '1';
				end if;
				if (trig_hold='0' and trig_down_r2='1') then
					trig_level <= trig_level - 16;
					trig_hold <= '1';
				end if;
				if (trig_hold='0' and trig_n_p_r2='1') then
					if (trig_status='1') then
						trig_status <= '0';
					else
						trig_status <= '1';
					end if;
					trig_hold <= '1';
				end if;
				
				if (trig_up_r2='0' and trig_down_r2='0' and trig_n_p_r2='0') then
					trig_hold <= '0';
				end if;
								
				if (count_hold='1' and count_en='0') then
					ADC_enable <= '0';
					count_hold <= '0';
				elsif (vsync_hold='1' and v_sync='0') then
					ADC_enable <= '1';	
					vsync_hold <= '0';				
				end if;
				
				if (we_signal='1') then
					we_signal <= '0';
				end if;
				
				-- Synchronization registers
				
				trig_up_r1 <= trigger_up;
				trig_up_r2 <= trig_up_r1;
				trig_down_r1 <= trigger_down;
				trig_down_r2 <= trig_down_r1;
				trig_n_p_r1 <= trigger_n_p;
				trig_n_p_r2 <= trig_n_p_r1;
				
			end if;
		end if;
	end process;
	
trigger_level <= trig_level;
we <= we_signal;
	
end arq;