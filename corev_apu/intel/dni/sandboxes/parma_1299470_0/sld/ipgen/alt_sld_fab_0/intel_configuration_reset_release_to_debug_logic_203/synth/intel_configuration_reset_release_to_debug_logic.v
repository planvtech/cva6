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


module intel_configuration_reset_release_to_debug_logic
(
    input wire conf_reset
);
    altera_debug_config_reset_release_source_endpoint conf_reset_endpoint
    (
        .conf_reset(conf_reset)
    );
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "u7/YsPkyP82xbBDtLEznXhS5SZvzKn3nJ64FaEXxxPEjs1Fo1j8wgE/I9TM13dQVg8464Be69dsMv0DAMe5G1VIlCUUNtcrqhwWDc5W6Ndtpzr3rHC5Sad14rDbOEAu95K3wyZTcrJjxSeTiIpoTJ316ii+u+UP3Q9Q9IupM+pgo/Oxs6FGXsUnKNn8iqsbWVqNdMquBd1GvFeNneF2XE9KyYAZdobqoOqpVGjR/B70T4u5iliEK22AnSAPqHyq8gtK65rPOLfEIs/4t1p8+JWnmhE4Vr82qROAN/YaQHEDRKaaDUbkCSU4V06imJmnUFxdZQgDFysWfv93WoRYdBNEYRHmeSXGGe35GPeAwELtHZla5GAJz9AHdCKcwTj9dKvnyx75O93FObFm+DRadEzKOGMLVGj31BSl2M12lPlpWCSKK+Y4vuIpx89P1wBkX9Qhc+PwQfqakv1Y5tE/iYW78iFXHnNfyYgIBDzg+uZAQM6EEQdy4kRoUDQaTa37EUPwUSVdcdyjrNOK/V1gKKiBu265Z/KIpmfR1gVc8Mea0OpE9IzUX4XQzkw0RLkJF2AM9pqzchXr9z9/cThjq1RnMcZaJDa9R0udkE5QakHb8hLy6754y3PgT1avCm2sq0fQhu5AVn5hUDV9fsNtgnqCzFN7wRHBuWbSnK3QxkLt3W9/bJUEEhP3Ln9cv7Hqx4dm9dxOzO3XU2GVvz2OQaU/7d2eDmDHaY7riTSFNWJdXddO8zeb6xKlob44oo3pbRIectyKEIb0C6q6E3gBew72C+t9wKLfMhkfzw3o1llLZ3gWryF2JzwiMjt50YGc+TrtCITfKakdOx6ufv8KysrgL2sIWrl1l1p+EuohOi8bkxNx13gpVNugbMwAiT96YTA8mw9LMGOMwS/6bJ6y/n1rWqOZcN8Q2q6D0lN1Kt/oASTpmuKSdtAQ27MuAB7d/MImRU5WWZFWaqiA/eMW/ZUACRrwIcRc2pjSurAsQEclYSOq27Y/F9zTYSym8l1A2"
`endif