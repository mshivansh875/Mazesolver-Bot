module t2a_dht(
    input clk50,
    input reset,
    inout sensor,
    output reg [7:0] T_integral,
    output reg [7:0] RH_integral,
    output reg [7:0] T_decimal,
    output reg [7:0] RH_decimal,
    output reg [7:0] Checksum,
    output reg data_valid
);

    initial begin
        T_integral = 0;
        RH_integral = 0;
        T_decimal = 0;
        RH_decimal = 0;
        Checksum = 0;
        data_valid = 0;
    end
//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

parameter IDLE = 2'B00,
			 START = 2'B01,
			 ACK   = 2'B10,
			 ACQUARE = 2'B11;
			 
			 
//wire reset = 1;
reg direction = 1'b1;
reg [1:0] state = IDLE;
reg [20:0] counter = 0;
reg [6:0] counter1 = 40;

reg [39:0] data = 0;

reg sensor_op;
// direction: 1 ==> controller drives; 0 ==> sensor drives
assign sensor = (direction)?sensor_op : 1'bz ; // controlling the direction of bidirectional sensor pin.

always @(posedge clk50) begin
	if(!reset)begin
		state <= IDLE;
		{T_integral, RH_integral, T_decimal, RH_decimal, Checksum, data_valid} <= 41'b0;
		counter <= 0;
		counter1 <= 40;
	end
	else begin
		case (state)
		IDLE: begin
			counter <= counter + 1;
			direction <= 1'b0;
			if(data_valid) begin // assigning only valid data points to the variables.
				{RH_integral, RH_decimal, T_integral, T_decimal, Checksum} <= data;
			end
			if(counter > 2700) begin
				state <= START;
				direction <= 1'b1;
			end
		end
		START: begin
			counter <= counter + 1;
			
			if(counter < 900000)begin			// driving low for around 18 ms 
				sensor_op <= 1'b0;
			end
			else if(counter < 900050) sensor_op <= 1'b1;
			else if(counter > 901000 && sensor == 1'b0) begin
				counter <= 0;
				state <= ACK;
			end
			else if(counter > 906000) begin	// If no acknowledge comes within fairly large time then again sends request.
				state <= IDLE;
				counter <= 0;
				data_valid <= 1'b0;
			end
			else begin
				direction <= 1'b0;
			end
		end
		ACK: begin
			counter <= counter + 1;
			if(counter > 6000 && sensor == 0)begin
				state <= ACQUARE;
				counter <= 0;
			end
		end
		ACQUARE: begin
			counter <= counter + 1;
			
			// for 0 and 1 bit detection accepting large range of values to overcome sensor non idealities.
			
			if(counter > 3500 && counter < 4200 && sensor == 0 ) begin
				data[counter1-1] <= 0;
				counter <= 0;
				counter1 <= counter1 - 1;
			end
			else if(counter > 5600 && counter < 6400 && sensor == 0 ) begin
				data[counter1-1] <= 1;
				counter <= 0;
				counter1 <= counter1 - 1;
			end
			else if(counter > 6400) begin	// if some time sensor stucks in b/w while sending data then controller again sends request.
				state <= IDLE;
				counter <= 0;
				counter1 <= 40;
				data_valid <= 1'b0;
			end
			if(counter1 == 1) begin
				state <= IDLE;
				data_valid <= (data[7:0] == data[15:8] + data[23:16] + data[31:24] + data[39:32]);
				counter1 <= 40;
			end
		end
		default: begin
			state <= 2'bx;
			{RH_integral, RH_decimal, T_integral, T_decimal, Checksum} <= 40'bx;
		end
		endcase
	end
end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////
  
endmodule