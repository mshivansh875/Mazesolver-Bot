// This is the top module that controls the communication of sensor data through bluetooth module.

module sensor_communication(
	input clk50, reset,
	inout sensor,
	
	input ir_in,
	
	input dout, mpi,
	input settle_done,
   output adc_cs_n, din, adc_sck,
   output [7:0] led_ind,
	output servo_pwm,
	input rx,
	output tx, match,
	output reg stable_data,
	output[7:0] data_1,
	output [7:0] mpi_required,
	input end_point,
	input [2:0] mpi_id


);

wire [7:0] T_integral;
wire [7:0] RH_integral;
wire [7:0] T_decimal;
wire [7:0] RH_decimal;
wire [7:0] Checksum;
wire data_valid;


wire [6:0] is_moisture;

wire is_object;

reg [7:0] data_to_convert;
assign data_1 = data_to_convert;

wire mm_done;

wire tx_start = tx_start_1;
reg tx_start_1;
wire tx_done;


reg[7:0] stable_is_moisture;
reg[7:0] stable_RH_integral;
reg[7:0] stable_T_integral;

reg [8:0] stability_counter = 0;
reg data_captured = 0;

reg[26:0] counter_1 = 27'd1;
reg start_measure_1 = 0;
assign start_measure = start_measure_1;

localparam MEASURE = 2'B00,DIP = 2'B01, WAIT = 2'B10, WAIT1 = 2'B11;
reg[1:0] state_1 = MEASURE;
reg flag = 1'b0;
reg object;
//---------------------------------------------------------------
//---------------------------------------------------------------
// This section controls when to start measuring and captures stable data values of moisture and dht sensor.
always @(negedge clk50) begin
	object <= is_object;
end
always @(posedge clk50) begin
	case(state_1) 
		MEASURE: begin
			stable_data <= 1'b0;
			data_captured <= 1'b0;
			if(mpi) begin
					state_1 <= WAIT1;
					counter_1 <= 1;
			end
		end
		WAIT1: begin
			if(!counter_1) begin
				state_1 <= DIP;
				counter_1 <= 1;
				start_measure_1 <= 1'b1;
			end
			else counter_1 <= counter_1 + 1;
		end
		DIP: begin										// keep moisture sensor in dip state for around 1.3 seconds.
			if(!counter_1) begin
				state_1 <= WAIT;
				start_measure_1 <= 1'b0;
				stable_is_moisture <= is_moisture;
				stable_RH_integral <= RH_integral;		// capturing fairly stablized data values.
				stable_T_integral	 <= T_integral;
				data_captured <= 1'b1;
				counter_1 <= 1;
				
			end
			counter_1 <= counter_1 + 1;
		end
		WAIT: begin
			if(!counter_1) begin
				state_1 <= MEASURE;
				stable_data <= 1'b1;
			end
			else counter_1 <= counter_1 + 1;
		end
	endcase
end
//------------------------------------------------------------------
//------------------------------------------------------------------

reg[3:0] state = S_IDLE;
reg [7:0] msg_buffer [0:15]; 
reg [3:0] msg_ptr;
reg [3:0] msg_len;
reg end_sent = 0;

localparam S_IDLE = 4'd0, S_LOAD_MPIM = 4'd1, S_LOAD_MM = 4'd2, S_LOAD_TH = 4'd3, S_SEND = 4'd4, S_WAIT = 4'd5,S_STABILITY = 4'd6, S_DIP = 4'd7,S_END = 4'd8;

//-----------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------
// This section stores the data to be sent in a buffer and controls the flow of the data to be sent.
always @(posedge clk50) begin
	case(state)
                S_IDLE: begin
                    if(mpi) begin
                        state <= S_LOAD_MPIM;
                    end
						  else if(end_point && !end_sent) state <= S_END; // logic for sending end message.
                end

                S_LOAD_MPIM: begin // "MPIM-X-#"
                    msg_buffer[0] <= "M"; msg_buffer[1] <= "P"; msg_buffer[2] <= "I"; msg_buffer[3] <= "M";
                    msg_buffer[4] <= "-"; msg_buffer[5] <= (8'd48 + mpi_id); 
                    msg_buffer[6] <= "-"; msg_buffer[7] <= "#";
                    msg_len <= 8; msg_ptr <= 0;
                    state <= S_SEND;
                end

                S_LOAD_MM: begin // "MM-X-M-#"
                    msg_buffer[0] <= "M"; msg_buffer[1] <= "M"; msg_buffer[2] <= "-";
                    msg_buffer[3] <= (8'd48 + mpi_id); msg_buffer[4] <= "-";
                    msg_buffer[5] <= (stable_is_moisture) ? "M" : "D";
                    msg_buffer[6] <= "-"; msg_buffer[7] <= "#";
                    msg_len <= 8; msg_ptr <= 0;
                    state <= S_SEND;
                end

                S_LOAD_TH: begin // "TH-X-25-60-#"
                    msg_buffer[0] <= "T"; msg_buffer[1] <= "H"; msg_buffer[2] <= "-";
                    msg_buffer[3] <= (8'd48 + mpi_id); msg_buffer[4] <= "-";
                    msg_buffer[5] <= (8'd48 + (stable_T_integral / 10)); 
                    msg_buffer[6] <= (8'd48 + (stable_T_integral % 10));
                    msg_buffer[7] <= "-";
                    msg_buffer[8] <= (8'd48 + (stable_RH_integral / 10));  
                    msg_buffer[9] <= (8'd48 + (stable_RH_integral % 10));
                    msg_buffer[10] <= "-"; msg_buffer[11] <= "#";msg_buffer[12] <= "\n";
                    msg_len <= 13; msg_ptr <= 0;
                    state <= S_SEND;
                end
					 
					 S_END: begin		// END-#
						  msg_buffer[0] <= "E"; msg_buffer[1] <= "N"; msg_buffer[2] <= "D";
						  msg_buffer[3] <= "-"; msg_buffer[4] <= "#";
						  msg_len <= 5; msg_ptr <= 0;
						  state <= S_SEND; end_sent <= 1;
					 end

                S_SEND: begin
                    if(msg_ptr < msg_len) begin
                        data_to_convert <= msg_buffer[msg_ptr];
                        tx_start_1 <= 1;
                        state <= S_WAIT;
                    end else begin
                        // Chain sequences
                        if(msg_buffer[1] == "P") state <= S_DIP; // Was MPIM
                        else if(msg_buffer[1] == "M") state <= S_LOAD_TH; // Was MM
                        else state <= S_IDLE; // Finished TH
                    end
                end

                S_WAIT: begin
                    if(tx_done) begin
                        msg_ptr <= msg_ptr + 1;
                        state <= S_STABILITY;
								tx_start_1 <= 0;
                    end
                end
					 S_STABILITY: begin
							if(stability_counter == 8'd500) begin
								state <= S_SEND;
								stability_counter <= 0;
							end
							else stability_counter <= stability_counter + 1;
					 end
					 S_DIP: begin
							if(data_captured) begin
								state <= S_LOAD_MM;
							end
					 end
            endcase
end
//---------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------



t2a_dht i1(
	.clk50(clk50),
	.reset(reset),
	.sensor(sensor),
	.T_integral(T_integral),
	.RH_integral(RH_integral),
	.T_decimal(T_decimal),
	.RH_decimal(RH_decimal),
	.Checksum(Checksum),
	.data_valid(data_valid)
);

moisture_sensor i2(
	.clk50(clk50),
	.start_measure(start_measure),
	.dout(dout),
	.is_moisture(is_moisture),
	.adc_cs_n(adc_cs_n),
	.din(din),
	.adc_sck(adc_sck),
	.led_ind(led_ind),
	.servo_pwm(servo_pwm),
	.mm_done(mm_done)
);

bluetooth i3(
	.clk50(clk50),
	.rx(rx),
	.tx(tx),
	.data(data_1),
	.tx_start(tx_start),
	.tx_done(tx_done),
	.match(match),
	.mpi_required(mpi_required)
);

ir_sensor i(
	.ir_in(ir_in),
	.is_object(is_object)
);


endmodule