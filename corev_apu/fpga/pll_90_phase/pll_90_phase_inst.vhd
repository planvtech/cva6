	component pll_90_phase is
		port (
			refclk     : in  std_logic := 'X'; -- clk
			locked     : out std_logic;        -- export
			rst        : in  std_logic := 'X'; -- reset
			permit_cal : in  std_logic := 'X'; -- export
			outclk_0   : out std_logic         -- clk
		);
	end component pll_90_phase;

	u0 : component pll_90_phase
		port map (
			refclk     => CONNECTED_TO_refclk,     --     refclk.clk
			locked     => CONNECTED_TO_locked,     --     locked.export
			rst        => CONNECTED_TO_rst,        --      reset.reset
			permit_cal => CONNECTED_TO_permit_cal, -- permit_cal.export
			outclk_0   => CONNECTED_TO_outclk_0    --    outclk0.clk
		);

