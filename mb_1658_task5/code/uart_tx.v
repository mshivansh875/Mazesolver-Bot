module uart_tx(
    input clk_3125,
    input tx_start,
    input [7:0] data,
    output reg tx, tx_done
);

initial begin
    tx <= 1'b1;
    tx_done <= 1'b0;
end
//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE//////////////////

reg [4:0] counter = 0;
reg [2:0] i = 7;

localparam IDLE = 3'B000, START_BIT = 3'B001, DATA_BIT = 3'B010, STOP_BIT = 3'b011, DUMMY = 3'B101;
reg [2:0] state = IDLE;

reg [7:0] data1;
 
always @(posedge clk_3125) begin
	case (state)
		IDLE: begin
			counter <= 0;
			tx_done <= 0;
			tx <= 1'b1;
			if(tx_start) begin
				state <= START_BIT;
				tx <= 0;
			end
		end

		START_BIT: begin
			counter <= counter + 1;
			if(counter == 26) begin
				state <= DATA_BIT;
				counter <= 0;
				i <= 0;
				tx <= data[0];
			end
		end

		DATA_BIT: begin
			counter <= counter + 1;
			tx <= data[i];

			if(counter == 26) begin
				counter <= 0;
				if(i == 7) begin
					state <= STOP_BIT;
					i <= 7;
				end else begin
					i <= i + 1;
				end
			end
		end

		STOP_BIT: begin
			counter <= counter + 1;
			tx <= 1'b1;
			if(counter == 26) begin
				state <= DUMMY;
				tx_done <= 1;
				counter <= 0;
			end
		end

		DUMMY: begin
			counter <= counter + 1;
			if(counter > 10) begin
				state <= IDLE;
			end
		end
	endcase
end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE//////////////////

endmodule
