/*
Module HC_SR04 Ultrasonic Sensor

This module will detect objects present in front of the range, and give the distance in mm.

Input:  clk_50M - 50 MHz clock
        reset   - reset input signal (Use negative reset)
        echo_rx - receive echo from the sensor

Output: trig    - trigger sensor for the sensor
        op     -  output signal to indicate object is present.
        distance_out - distance in mm, if object is present.
*/

// module Declaration
module t1b_ultrasonic(
    input clk_50M, reset, echo_rx,
    output reg trig,
    output op,
    output wire [15:0] distance_out
);

initial begin
    trig = 0;
end
//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

reg [19:0] counter = 0;


parameter idle = 2'b00, trigger = 2'b01, distance_measure = 2'b10, calculation = 2'b11;

reg [1:0] state = idle;
reg [15:0] distance_out_1 = 0;
reg op_1 = 0;

assign distance_out = distance_out_1;
assign op = op_1;


always @(posedge clk_50M)
begin

	if(!reset)
	begin
		state <= idle;
		trig <= 1'b0;
		distance_out_1 <= 0;
		op_1 <= 0;
		counter <= 0;
	end
	
	else
	begin
	
	case (state)
		idle:
			begin
								if(counter >= 51)
								begin
									state <= trigger;
									trig <= 1'b1;
								end
								counter <= counter + 1;
			end
		trigger:
			begin
								if(echo_rx || (counter >= 551))
								begin	
									state <= distance_measure;
									trig <= 1'b0;
								end
								counter <= counter +1;
			end
		distance_measure: 
			begin
								if(!echo_rx)
								begin
									state <= calculation;
									distance_out_1 <= ((counter - 846)/294);
									op_1 <= (((counter - 846)/294) < 70);
								end
								counter <= counter + 1;
			end
		calculation:		
			begin
								if(counter == 600553)
								begin
									state <= idle;
									counter <= 0;
								end
								else counter <= counter + 1;
			end
		default: 			state <= idle;
	endcase
	
	end
end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////

endmodule
