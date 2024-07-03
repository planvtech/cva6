module cva6_intel (
		input  wire        emif_fm_0_local_reset_req_local_reset_req,                   //           emif_fm_0_local_reset_req.local_reset_req
		output wire        emif_fm_0_local_reset_status_local_reset_done,               //        emif_fm_0_local_reset_status.local_reset_done
		input  wire        emif_fm_0_pll_ref_clk_clk,                                   //               emif_fm_0_pll_ref_clk.clk
		output wire        emif_fm_0_pll_locked_pll_locked,                             //                emif_fm_0_pll_locked.pll_locked
		input  wire        emif_fm_0_oct_oct_rzqin,                                     //                       emif_fm_0_oct.oct_rzqin
		output wire [0:0]  emif_fm_0_mem_mem_ck,                                        //                       emif_fm_0_mem.mem_ck
		output wire [0:0]  emif_fm_0_mem_mem_ck_n,                                      //                                    .mem_ck_n
		output wire [16:0] emif_fm_0_mem_mem_a,                                         //                                    .mem_a
		output wire [0:0]  emif_fm_0_mem_mem_act_n,                                     //                                    .mem_act_n
		output wire [1:0]  emif_fm_0_mem_mem_ba,                                        //                                    .mem_ba
		output wire [1:0]  emif_fm_0_mem_mem_bg,                                        //                                    .mem_bg
		output wire [0:0]  emif_fm_0_mem_mem_cke,                                       //                                    .mem_cke
		output wire [0:0]  emif_fm_0_mem_mem_cs_n,                                      //                                    .mem_cs_n
		output wire [0:0]  emif_fm_0_mem_mem_odt,                                       //                                    .mem_odt
		output wire [0:0]  emif_fm_0_mem_mem_reset_n,                                   //                                    .mem_reset_n
		output wire [0:0]  emif_fm_0_mem_mem_par,                                       //                                    .mem_par
		input  wire [0:0]  emif_fm_0_mem_mem_alert_n,                                   //                                    .mem_alert_n
		inout  wire [8:0]  emif_fm_0_mem_mem_dqs,                                       //                                    .mem_dqs
		inout  wire [8:0]  emif_fm_0_mem_mem_dqs_n,                                     //                                    .mem_dqs_n
		inout  wire [71:0] emif_fm_0_mem_mem_dq,                                        //                                    .mem_dq
		inout  wire [8:0]  emif_fm_0_mem_mem_dbi_n,                                     //                                    .mem_dbi_n
		output wire        emif_fm_0_status_local_cal_success,                          //                    emif_fm_0_status.local_cal_success
		output wire        emif_fm_0_status_local_cal_fail,                             //                                    .local_cal_fail
		output wire        emif_fm_0_emif_usr_reset_n_reset_n,                          //          emif_fm_0_emif_usr_reset_n.reset_n
		output wire        emif_fm_0_emif_usr_clk_clk,                                  //              emif_fm_0_emif_usr_clk.clk
		output wire        emif_fm_0_ctrl_ecc_user_interrupt_0_ctrl_ecc_user_interrupt, // emif_fm_0_ctrl_ecc_user_interrupt_0.ctrl_ecc_user_interrupt
		input  wire        iopll_0_refclk_clk,                                          //                      iopll_0_refclk.clk
		input  wire        reset_controller_0_reset_in0_reset                           //        reset_controller_0_reset_in0.reset
	);
endmodule

