// This is the module that connects moisture sensor and servo motor.
// No specific reason to keep them in one module but the task was done in this manner.

module moisture_sensor(
    input dout, clk50, start_measure,
    output adc_cs_n, din, adc_sck,mm_done,
    output [6:0] is_moisture,
    output [7:0] led_ind,
	 output servo_pwm
);

reg [3:0] counter;

always @(posedge clk50) begin
    counter <= counter + 1;
end

assign adc_sck = counter[3];

adc_controller adc_inst(
    .dout(dout),
    .adc_sck(adc_sck),
    .adc_cs_n(adc_cs_n),
    .din(din),
    .is_moisture(is_moisture),
    .led_ind(led_ind),
	 .mm_done(mm_done)
);
servo_motor s_i(
	 .clk(clk50),
	 .pwm(servo_pwm),
	 .start_measure(start_measure)
);

endmodule