library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity control_vga is
generic (
		data_width : natural := 12;
		addr_width : natural := 11);
port(
		clk:	 		in std_logic; 									-- clock input, active by rising edge
		reset: 	 		in std_logic; 									-- synchronous reset input, active high
		trigger_level:	in std_logic_vector(8 downto 0);				-- output value of trigger level
		data_out:		in std_logic_vector(data_width-1 downto 0);
		addr_out:		out std_logic_vector(addr_width-1 downto 0);	-- output 
		vsync: 			out std_logic;									-- horizontal synchronization signal for teh display
		hsync: 			out std_logic;									-- vertical synchronization signal for the display
		red:			out std_logic_vector(3 downto 0);
		green: 			out std_logic_vector(3 downto 0);
		blue: 			out std_logic_vector(3 downto 0)	
		
		
);
end control_vga;
architecture comportament of control_vga is
		signal count_hori:	 	std_logic_vector(10 downto 0);
		signal count_ver: 		std_logic_vector(10 downto 0);
		signal RGB:				std_logic_vector(11 downto 0);
		
		signal state_hori: 		std_logic_vector (1 downto 0);
		signal state_ver: 		std_logic_vector (1 downto 0);
		
		constant retrase_ini_h: integer:=0;					-- first pixel of retrase zone	[0-111] length 112								
		constant retarse_fin_h: integer:=110;				-- last pixel number of retrase zone
		constant backpor_ini_h: integer:=111;				-- first pixel of porch zone    [112-359] length 248
		constant backpor_fin_h: integer:=358;				-- last pixel number of back porch zone									
		constant active_lines_ini_h: integer:=359;			-- first pixek number of active lines [360-1639] length 1280		
		constant active_lines_fin_h: integer:=1638;			-- last pixel number of actibe lines zone 
		constant frontpor_ini_h: integer:=1639; 			-- first pixel number of the front porch zone [1640-1687] length 48
		constant frontpor_fin_h: integer:=1687; 			-- last pixel number of front porch zone
			
		constant retrase_ini_v: integer:=0;					-- first pixel of retrase zone	[0-2] length 3								
		constant retrase_fin_v: integer:=2;					-- last pixel number of retrase zone
		constant backpor_ini_v: integer:=3;					-- first pixel of porch zone    [3-40] length 38
		constant backpor_fin_v: integer:=40;				-- last pixel number of back porch zone									
		constant active_lines_ini_v: integer:=41;			-- first pixek number of active lines [41-1064] length 1024		
		constant active_lines_fin_v: integer:=1064;			-- last pixel number of actibe lines zone 
		constant frontpor_ini_v: integer:=1065; 			-- first pixel number of the front porch zone [1065] length 1
		constant frontpor_fin_v: integer:=1065; 			-- last pixel number of front porch zone	
		
		
		

begin

process(clk)
	begin
		if (clk'event and clk= '1') then
			if (reset = '1') then
			count_hori <= (others => '0');
			count_ver <= (others => '0');
			--Vertical counter
			elsif (count_hori=frontpor_fin_h) then
				count_ver<=count_ver+1;
				count_hori <= (others => '0');
			elsif (count_ver=frontpor_fin_v)then
				count_ver <= (others => '0');
			--Horizontal counter
			else 
				count_hori<= count_hori + 1;
			end if;
			-- Counter state definition
			if (count_hori < backpor_ini_h or count_hori = frontpor_fin_h) then 
				state_hori<="00";
			elsif (count_hori >= backpor_ini_h and count_hori < active_lines_ini_h) then
				state_hori<="01";
			elsif(count_hori >= active_lines_ini_h and  count_hori < frontpor_ini_h) then
				state_hori<="10"; 
			else
				state_hori<="11";
			end if;
		end if;
	end process;

	
process(clk)
	begin
		if (clk'event and clk= '1') then
			-- Counter state definition
			if (count_ver < backpor_ini_v or count_ver = frontpor_fin_v) then 
				state_ver<="00";
			elsif (count_ver >= backpor_ini_v and count_ver < active_lines_ini_v) then
				state_ver<="01";
			elsif(count_ver >= active_lines_ini_v and  count_ver < frontpor_ini_v) then
				state_ver<="10"; 
			else
				state_ver<="11";
			end if;
		end if;
	end process;

-- Memory fetch
process(clk)
	begin
		if (clk'event and clk='1') then
			if (count_hori >= active_lines_ini_h - 3) then
				addr_out <= count_hori - 3;
			end if;
		end if;
	end process;

	
--Output generation
process	(clk)
	begin
		if (clk'event and clk= '1') then
			--Non active zone definition
			if (state_ver="00" or state_ver="01" or state_ver="11" or state_hori="00" or state_hori="01" or state_hori="11") then 
				red<="0000";
				blue<="0000";
				green<="0000";
			-- Oscilloscope zone
			elsif (count_ver >= active_lines_ini_v and count_ver <= active_lines_ini_v + 512 ) then
				if (data_out(data_width-1 downto data_width - 9) = count_ver) then
					red<="1111";
					blue<="0000";
					green<="1111";
				end if;
			-- Temperature zone
			--elsif (count_ver >= active_lines_ini_v + 543 and count_ver <= active_lines_ini_v + 573) then
				
			else
				red<="0000";
				blue<="0000";
				green<="0000";
			end if;
				
				
			
			-- --
			-- -- DELETE
			-- --
			-- --Mode='0'--> horizontal pattern definition
			-- elsif (mode='0') then
				-- red<=RGB (11 downto 8);
				-- green<=RGB (7 downto 4);
				-- blue<=RGB (3 downto 0);
			-- --Mode='1'--> vertical pattern definition	
			-- elsif(mode='1') then
				-- if(state_hori="10" and state_ver="10") then --active zones in woth zones
					-- if(count_ver>=active_lines_ini_v and count_ver<=(active_lines_ini_v+(active_lines_fin_v/3)-1)) then
						-- red<="1111";
						-- green<="0000";
						-- blue<="0000";
					-- elsif (count_ver>=active_lines_ini_v+(active_lines_fin_v/3) and count_ver<=(active_lines_ini_v+(2*active_lines_fin_v/3)-1)) then
						-- red<="0000";
						-- green<="1111";
						-- blue<="0000";
					-- elsif(count_ver>=active_lines_ini_v+(2*active_lines_fin_v/3) and count_ver<=active_lines_fin_v) then
						-- red<="0000";
						-- green<="0000";
						-- blue<="1111";
					-- end if;
			-- --
			-- -- DELETE
			-- --
		end if;
	end process;

vsync<='0' when state_ver="00" else '1';
hsync<='0' when state_hori="00" else '1';
RGB<='0'& count_hori;
	
end comportament;