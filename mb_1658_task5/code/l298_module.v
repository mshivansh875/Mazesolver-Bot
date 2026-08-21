/*
Module: l298_driver
Updated to include speed_offset inputs for dynamic alignment.
Base duty cycle is 83.3% (500/600).
Offsets reduce the duty cycle of the specific motor to steer.
*/

module l298_module (
    input wire clk,          // 50 MHz 
	 input wire wall_l, wall_r, wall_m,
    output wire ena,
    output wire enb,
	 input [15:0] speed_offset_l,
	 input [15:0] speed_offset_r
);
wire [16:0] l_threshold;
wire [16:0] r_threshold;
 
    reg [16:0] pwm_cnt;
    always @(posedge clk) begin  // counter to scale down the frequency given to l298
        if (pwm_cnt >= 600) pwm_cnt <= 0;
        else pwm_cnt <= pwm_cnt + 1;
    end

    //changing duty for aligning the bot in centre 
	 assign	l_threshold = 17'd550 - {1'd0, speed_offset_l * 12}; 
	 assign	r_threshold = 17'd550 - {1'd0, speed_offset_r * 12};
    //pwm genration
	 assign ena = (pwm_cnt < l_threshold);
    assign enb = (pwm_cnt < r_threshold);

endmodule