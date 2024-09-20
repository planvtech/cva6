// (C) 2001-2024 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


module intel_configuration_reset_release_for_debug
#(
   parameter DEVICE_FAMILY_ID = 2
)
(
   output wire conf_reset
);
   if(DEVICE_FAMILY_ID == 2) begin: s10 //stratix 10
      fourteennm_lsm_gpio_out 
      #(
         .bitpos       (19),
         .role         ("postuser"),
         .timingseq    (0)
      ) 
      lsm_gpo_out_user_reset 
      (
         .gpio_o        (conf_reset)
      );
   end
   else if(DEVICE_FAMILY_ID == 3) begin: ag //agilex
        fourteennm_sdm_gpio_out 
        #(
           .bitpos       (14),
           .role         ("USER_RESET")
        ) 
        sdm_gpo_out_user_reset 
        (
           .gpio_o        (conf_reset)
        );
   end
   else begin: universal
      lcell lc
      ( 
         .in(1'b0), 
         .out(conf_reset) 
      )/* synthesis altera_attribute = "-name PRESERVE_FANOUT_FREE_WYSIWYG ON" */;
   end
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "u7/YsPkyP82xbBDtLEznXhS5SZvzKn3nJ64FaEXxxPEjs1Fo1j8wgE/I9TM13dQVg8464Be69dsMv0DAMe5G1VIlCUUNtcrqhwWDc5W6Ndtpzr3rHC5Sad14rDbOEAu95K3wyZTcrJjxSeTiIpoTJ316ii+u+UP3Q9Q9IupM+pgo/Oxs6FGXsUnKNn8iqsbWVqNdMquBd1GvFeNneF2XE9KyYAZdobqoOqpVGjR/B73W9QT+eKw7ttz0htY2gdmi6EYRaMZU628fLpe/KMZmw2HOXG2YOelyFqfnCUi/EuTSkzXMJy9w8ihBKhe5ilpcwIDvZUJe2BUT1LzRtWfVETRmuyt0M3JKbhJWwX/hicIDDCkWoEtGvqI8sFTpGcXPzGQ2xqYWG7IjoVJEavusbuNuvFMOZtGrbJL7/O7VS7dRp0gC1+GF0rpTe2wJDt5G3h/IGuH+I1/WS2h8q/WJHIXC9IAR2yqroV421WbnB4umPFtxfpzIoGopILxH32JD+crd8lHlcv9FtmBsU09ELGCVYMUc3phWpEqpOmxZ7FoSUIFUZ/E/iVkql3YfvTZEzrK7qR6vk/js9/Ae6RTP+bLRXoZW1tjkEpsmiPVPHIReuakYbhjz/+pRK1JNZ8ziI4EOFSFM0nBiLCtZgwElwsB+j/Nm304oKuua1++L2yulX6GFRS8PAllZulj+aWgChvW/15+ZMBX9T1ZlXSWIzmgCJ08poHkKL/3m8EWtvL+WVO+Av9d/x/Dht7XQqrF8kw2n4a2ct0rYe0IoSvbBOLNmyFCWqloWHYYOY+Vr4jAPy3F0EZd9OhHey3M2CkRekk7idFg6AchWMawhij+RaD1xj/tTOnHLenE0y4YQ3mnE4BG+6E3qizmhNK7px+mrZWPIq5PCPyto3ueiCYu9JnZLOWR2TJgQMg7s4WDymyqu2cnRKO2wdH4G9ZAm/4O9cMuP+t1cjMcsgfhRiiavRgHb1U3XnVZcJk+XHb3rvKjbQL151b3PFzfXDqeV7B3m"
`endif