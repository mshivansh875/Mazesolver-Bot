module uart_rx(
    input clk_3125,
    input rx,
    output reg [7:0] rx_msg,
    output reg rx_complete,
	 output reg match,
	 output wire [7:0] mpi_required
    );

initial begin
    rx_msg = 8'b0;
    rx_complete = 1'b0;
	 j = 0;
	 match = 0;
end
//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE//////////////////
reg [7:0] counter = 0;
reg [2:0] i = 0;
reg [7:0] rx_msg_1 = 0;

localparam IDLE = 2'B00, START_BIT = 2'B01, DATA_BIT = 2'B10, END_BIT = 2'B11;
reg [1:0] state = IDLE;
reg clock_cycle_no = 0;
(* noprune *) reg [7:0] recieved_msg[0:8];
(* noprune *) reg [3:0] j;

always @(posedge clk_3125) begin
	case(state)
	IDLE: begin
		rx_complete <= 0;
		counter <= 0;
		i <= 0;
		if(!rx) begin
			state <= START_BIT;
			rx_msg_1 <= 0;
		end
	end
	START_BIT: begin
		counter <= counter + 1;
		if(counter == 25) begin
			state <= DATA_BIT;
			counter <= 0;
		end
	end
	DATA_BIT: begin
		counter <= counter + 1;
		if(counter == 13) begin
			rx_msg_1[i] <= rx;
		end
		if(counter == 26) begin
			counter <= 0;
			if(i == 7) begin
				state <= END_BIT;
			end else begin
					i <= i + 1;
			end
		end
	end
	END_BIT: begin
		counter <= counter + 1;
		if(counter == 27)begin
			state <= IDLE;
			rx_msg <= rx_msg_1;
			rx_complete <= 1;
		end
	end
	endcase
end
assign mpi_required = recieved_msg[6]; // to get no. of mpi points to be measured.

// recieving start message in a buffer.
always @(posedge clk_3125) begin
	if(j==9) begin
	end
	else if(rx_complete) begin
		recieved_msg[j] <= rx_msg;
		j <= j + 1;
	end
end

reg[7:0] start_msg [0:8];
always @(posedge clk_3125) begin
	start_msg[0] <= "S";
	start_msg[1] <= "T";
	start_msg[2] <= "A";
	start_msg[3] <= "R";
	start_msg[4] <= "T";
	start_msg[5] <= "-";
	start_msg[6] <= "3";
	start_msg[7] <= "-";
	start_msg[8] <= "#";
end
integer k;
// comparing only "START-" for detecting start message assuming that no. of mpi points can be anything not specifically 3.
always @(*) begin
    match = 1;
    for (k = 0; k < 6; k = k + 1) begin
        if (recieved_msg[k] != start_msg[k]) match = 0; // sending match signal to start the bot.
    end
end

/* Add your logic here */

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE//////////////////

endmodule
