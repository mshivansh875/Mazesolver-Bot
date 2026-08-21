
/*
Module: centre_aligner
Monitors left and right ultrasonic distances during MOVE_FWD.
Outputs a speed adjustment (offset) to keep the bot centered.
*/

module centre_aligner (
    input  wire clk,
    input  wire [15:0] dist_l,
    input  wire [15:0] dist_r,
    input  wire [2:0]  move_cmd,
    input  wire        busy,
	 input wire         valid_udata,
	 input wire wall_r, wall_l, wall_m,
    output reg  [15:0]  speed_offset_l, // Amount to slow down left motor
    output reg  [15:0]  speed_offset_r  // Amount to slow down right motor
);

    localparam MOVE_FWD = 3'b001;
	 
	 always @(posedge clk) begin
	 
	  //aligns if the left wall is available 
		if(busy && wall_l && !wall_m && (move_cmd == MOVE_FWD)) begin
		   //piecewise function
			if(dist_l < 50) begin     //for repelling if too close to the wall
			  
				speed_offset_r <= 16'd0;
				speed_offset_l <= 16'd13;
			end
			else if(dist_l < 58) begin
				speed_offset_r <= 16'd0;
				speed_offset_l <= 16'd9;
			end
			else if(dist_l < 70) begin
				speed_offset_r <= 16'd0;
				speed_offset_l <= 16'd6;
			end
			else if(dist_l > 152) begin  //attracting if too far from centre 
				speed_offset_r <= 16'd13;
				speed_offset_l <= 16'd0;
			end
			else if(dist_l > 125) begin
				speed_offset_r <= 16'd9;
				speed_offset_l <= 16'd0;
			end
			else if(dist_l > 95) begin
				speed_offset_r <= 16'd6;
				speed_offset_l <= 16'd0;
			end
			else begin
				speed_offset_r <= 16'd0;
				speed_offset_l <= 16'd0;
			end
		end
		//if no left wall than align with the help of right wall
		//same piecewise approch 
		else if(busy && !wall_l && !wall_m && wall_r && (move_cmd == MOVE_FWD)) begin
			if(dist_r < 40) begin
				speed_offset_r <= 16'd13;
				speed_offset_l <= 16'd0;
			end
			else if(dist_r < 51) begin
				speed_offset_r <= 16'd9;
				speed_offset_l <= 16'd0;
			end
			else if(dist_r < 78) begin
				speed_offset_r <= 16'd6;
				speed_offset_l <= 16'd0;
			end
			else if(dist_r > 145) begin
				speed_offset_r <= 16'd0;
				speed_offset_l <= 16'd13;
			end
			else if(dist_r > 125) begin
				speed_offset_r <= 16'd0;
				speed_offset_l <= 16'd9;
			end
			else if(dist_r > 100) begin
				speed_offset_r <= 16'd0;
				speed_offset_l <= 16'd6;
			end
			else begin
				speed_offset_r <= 0;
				speed_offset_l <= 0;
			end
		end
		else begin
			speed_offset_r <= 16'd0;
			speed_offset_l <= 16'd0;
		end
	 end

endmodule