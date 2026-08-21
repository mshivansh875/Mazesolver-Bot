// MazeSolver Bot: Task 2B - UART Transmitter
/*
Instructions
-------------------
Students are not allowed to make any changes in the Module declaration.

This file is used to generate UART Tx data packet to transmit the messages based on the input data.

Recommended Quartus Version : 20.1
The submitted project file must be 20.1 compatible as the evaluation will be done on Quartus Prime Lite 20.1.

Warning: The error due to compatibility will not be entertained.
-------------------
*/

/*
Module UART Transmitter

Input:  clk_3125 - 3125 KHz clock
        parity_type - even(0)/odd(1) parity type
        tx_start - signal to start the communication.
        data    - 8-bit data line to transmit

Output: tx      - UART Transmission Line
        tx_done - message transmitted flag


        Baudrate : 115200 bps
*/

// module declaration
module uart_tx(
    input clk_3125,
    input parity_type,tx_start,
    input [7:0] data,
    output reg tx, tx_done
);

initial begin
    tx = 1'b1;
    tx_done = 1'b0;
end
//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE//////////////////
reg [4:0] counter = 0;
reg [3:0] i = 8;

parameter IDLE = 3'B000, START_BIT = 3'B001, DATA_BIT = 3'B010,PARITY_BIT = 3'B011, STOP_BIT = 3'B100;
reg [2:0] state = IDLE;
 
 
always @(posedge clk_3125) begin
	case (state)
		IDLE: begin
			counter = 0;
			tx_done = 0;
			if(tx_start) begin
				state = START_BIT;
				tx = 0;
			end
		end
		START_BIT: begin
			counter = counter + 1;
			if(counter >= 26) begin
				state = DATA_BIT;
				tx = data[i-1];
				counter = 0;
			end
		end
		DATA_BIT: begin
			counter = counter + 1;
			if(i == 0) begin
				tx = ^data;
				state = PARITY_BIT;
				i = 8;
				counter = 0;
			end
			else begin
				tx = data[i-1];
			end
			if(counter >= 27 ) begin
				i = i - 1;
				counter = 0;
			end
		end
		PARITY_BIT: begin
			counter = counter + 1;
			if(counter >= 27) begin
				state = STOP_BIT;
				counter = 0;
				tx = 1;
			end
		end
		STOP_BIT: begin
			counter = counter + 1;
			if(counter >= 26) begin
				state = IDLE;
				tx_done = 1;
			end
		end
	endcase
end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE//////////////////

endmodule

