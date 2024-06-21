# PLL Parameters

#USER W A R N I N G !
#USER The PLL parameters are statically defined in this
#USER file at generation time!
#USER To ensure timing constraints and timing reports are correct, when you make 
#USER any changes to the PLL component using the Qsys,
#USER apply those changes to the PLL parameters in this file

set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_corename io_pll_altera_iopll_1931_il4ft3y

set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data [dict create]
set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data [dict create]
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk pattern __inst_name__|tennm_pll|core_refclk
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk node_type pin
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk pin_id ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk pin_node_name ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk port_id ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk port_node_name ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk is_fpga_pin false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk is_main_refclk true
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk exists false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk name "__inst_name___refclk"
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk period 3.333
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_base_clock_data refclk half_period 1.667
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock pattern __inst_name__|tennm_pll~ncntr_reg
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock node_type register
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock pin_id ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock pin_node_name ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock is_valid false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock exists false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock name "__inst_name___n_cnt_clk"
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock src refclk
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock master ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock multiply_by 1
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock divide_by 3
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock phase 0.000
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data n_cnt_clock duty_cycle 50
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock pattern __inst_name__|tennm_pll~mcntr_reg
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock node_type register
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock pin_id ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock pin_node_name ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock is_valid false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock exists false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock name "__inst_name___m_cnt_clk"
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock src refclk
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock master ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock multiply_by 1
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock divide_by 30
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock phase 0.000
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data m_cnt_clock duty_cycle 50
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 pattern __inst_name__|tennm_pll|outclk\[1\]
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 node_type pin
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 pin_id ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 pin_node_name ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 is_valid false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 exists false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 name __inst_name___outclk0
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 src refclk
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 master ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 multiply_by 10
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 divide_by 20
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 phase 0.000
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 duty_cycle 50
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk1 counter_index 1
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 pattern __inst_name__|tennm_pll|outclk\[2\]
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 node_type pin
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 pin_id ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 pin_node_name ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 is_valid false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 exists false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 name __inst_name___outclk1
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 src refclk
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 master ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 multiply_by 10
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 divide_by 8
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 phase 0.000
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 duty_cycle 50
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk2 counter_index 2
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 pattern __inst_name__|tennm_pll|outclk\[3\]
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 node_type pin
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 pin_id ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 pin_node_name ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 is_valid false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 exists false
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 name __inst_name___outclk2
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 src refclk
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 master ""
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 multiply_by 10
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 divide_by 5
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 phase 0.000
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 duty_cycle 50
dict set ::GLOBAL_top_io_pll_altera_iopll_1931_il4ft3y_gen_clock_data outclk3 counter_index 3
