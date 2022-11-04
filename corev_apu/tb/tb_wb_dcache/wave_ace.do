add wave -group TB -position insertpoint sim:/tb_ace/*
add wave -group scheduler -position insertpoint sim:/tb_ace/i_request_scheduler/*
add wave -group checker -position insertpoint sim:/tb_ace/i_checker/*
add wave -group snoop_cache_ctrl -position insertpoint sim:/tb_ace/i_dut/i_snoop_cache_ctrl/*
add wave -group miss_handler -position insertpoint sim:/tb_ace/i_dut/i_miss_handler/*
add wave -position insertpoint sim:/tb_ace/i_checker/cache_status
add wave -position insertpoint sim:/tb_ace/i_dut/valid_dirty_sram/gen_cut[0]/gen_mem/i_tc_sram_wrapper/i_tc_sram/sram
