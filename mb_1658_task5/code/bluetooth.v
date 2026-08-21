module bluetooth(
	input clk50,
	input rx,
	input tx_start,
	output tx,
	output tx_done,
	input[7:0] data,
	output match,
	output [7:0] mpi_required
);
wire [7:0] rx_msg;
wire rx_complete;
wire clk_3125;


reg clk3125_reg = 0;
reg[2:0] counter = 0;

assign clk_3125 = clk3125_reg;

always @(posedge clk50) begin				// divides 50MHz clock to 3125 KHz clock for uart tx and rx.
	if(!counter) clk3125_reg  <= ~clk3125_reg;
	counter <= counter + 1;
end

uart_tx t1(
	.clk_3125(clk_3125),
	.tx_start(tx_start),
	.data(data),
	.tx(tx),
	.tx_done(tx_done)
);

uart_rx r1(
	.clk_3125(clk_3125),
	.rx(rx),
	.rx_msg(rx_msg),
	.rx_complete(rx_complete),
	.match(match),
	.mpi_required(mpi_required)
);
endmodule