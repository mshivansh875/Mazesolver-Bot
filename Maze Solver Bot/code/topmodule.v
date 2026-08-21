/*
Top Module for Maze Solving Robot
Integrated Components:
1. Ultrasonic Sensors (Left, Mid, Right)
2. Maze Explorer (Logic/Brain)
3. Centre Aligner (Path Correction)
4. Move Controller (Actuator/FSM)
5. UART Manager (Comm & Remote Start)
6. DHT11 Sensor (Integrated t2a_dht)
7. L298 Driver (Motor Power)
*/


module topmodule (
    input  wire clk_50M,
    input  wire echo_l, echo_m, echo_r,
	 
	 inout sensor,
	 input ir_in, dout, rx,
	 output wire adc_cs_n, din, adc_sck, servo_pwm, tx,
	 output wire [7:0] data, led_ind,
	 
    output wire trig_l, trig_m, trig_r,
    input  wire enc_l,enc_r,
    output wire [3:0] l298_pins, 
    output wire ena, enb,
    output wire valid_wall_data // Now represents filtered stability
);
    reg ir_1 ,ir_2;
    always @(posedge clk_50M)begin
	    ir_1 <= ir_in;
		 ir_2 <= ir_1;
	 end
	 wire wall_l, wall_m, wall_r, end_l, end_m, end_r;
	 reg exit = 0;
    wire reset_n = 1'b1;
	 reg [2:0] mpi_id ;
	 
	 initial mpi_id = 0;
	 
	 wire[8:0] step_counter;
	 
	 wire front_wall_detected;
	 
    wire v_l, v_m, v_r;
    
    // Filtered Signals
    wire [15:0] dist_l, dist_m, dist_r;
	 reg [16:0] df_l , df_r , df_m;
    
    wire [2:0] move_cmd;
    wire valid_cmd;
    wire move_complete;
    wire busy;
    wire [15:0] off_l, off_r;
	 wire stop_motor;
	 
	 wire start;
	 
	 wire mpi;
	 
	 wire [7:0] mpi_required;
	 
	 wire stable_data;
	 

	 

    // Filtered Logic: Only "Ready" when all 3 sensors have averaged 8 samples
    assign valid_wall_data = v_l && v_m && v_r;
    
   

    // State Machine
    localparam IDLE           = 4'd0;
    localparam START_SENSING  = 4'd1; 
    localparam WAIT_STABLE    = 4'd2; 
    localparam WAIT_BRAIN     = 4'd3; 
    localparam MOTOR_START    = 4'd4;
    localparam MOTOR_BUSY     = 4'd5;
    localparam SETTLE         = 4'd6; // New: Wait for sensors to stabilize after move
    localparam FINISH         = 4'd7;
	 localparam BRAIN_DATA     = 4'd8;
	 localparam BRAIN_START    = 4'd9;
	 localparam HANDSHAKE_DONE = 4'd10;
	 
	 
	 //moves encoding 
	 
	 localparam STOP       = 3'b000;
    localparam MOVE_FWD   = 3'b001;
    localparam TURN_LEFT  = 3'b010;
    localparam TURN_RIGHT = 3'b011;
    localparam U_TURN     = 3'b100;



    reg [3:0] state = IDLE;
    reg [2:0] cmd_reg;
    reg start_usonic;
    reg get_a_move;
    reg start_motor;
    reg left_reg, mid_reg, right_reg;
    reg [29:0] settle_timer,settle_limit; // Timer for 50ms delay
	 reg [29:0] usonic_cnt; 
	 
 //   Main fsm for the bot
 //--------------------------------------------------------------------------------------
	 reg settle_done = 1'b0;
    always @(posedge clk_50M) begin
		  if(!start) begin
				state        <= IDLE;
            start_usonic <= 1'b0;
            get_a_move   <= 1'b0;
            start_motor  <= 1'b0;
            settle_timer <= 24'd0;
		  end
        else if (!reset_n) begin
            state        <= IDLE;
            start_usonic <= 1'b0;
            get_a_move   <= 1'b0;
            start_motor  <= 1'b0;
            settle_timer <= 24'd0;
        end
		  else if (exit) begin // stops the motor if motor exits.
            state        <= IDLE;
            start_usonic <= 1'b1;
            get_a_move   <= 1'b0;
            start_motor  <= 1'b0;
            settle_timer <= 24'd0;
        end
		  else begin
            case (state)
                IDLE: begin                    //start the three ultrasonic together for valid data synchronization
						
                    start_motor <= 1'b0;
                    start_usonic <= 1'b1; // Trigger continuous sensing
                    state <= WAIT_STABLE;
						  usonic_cnt <= 0;
						  settle_done <= 0;
			  
                end

                WAIT_STABLE: begin      // sampling time for ultrasonic 
					 
					       if (usonic_cnt >= 30'd30_000_000 )begin  // halting the bot so that the ultrasonic data do not get noise from the bot and motor vibration
								get_a_move <= 1'b1;
								exit <= end_l && end_m && end_r;
								state <= HANDSHAKE_DONE;
							 end 
							 else usonic_cnt <= usonic_cnt + 1;
						
				
                end
					 HANDSHAKE_DONE: begin   // pulling get_a_move down so that mazesolver only gives one command per request 
						get_a_move <= 1'b0;
						state <= WAIT_BRAIN;
						end
					 

                WAIT_BRAIN: begin      // waiting for the output of mazsolver 

                    if (valid_cmd) begin  //approx delay 5 cycles 
						      if (move_cmd == U_TURN) mpi_id = mpi_id+1;
                        cmd_reg    <= move_cmd;
                        get_a_move <= 1'b0;
                        state      <= MOTOR_START;
                    end
                end
					 

                MOTOR_START: begin           //starting the motor based on the cmd by mazesolver
					     if(cmd_reg != STOP)begin
                    start_motor <= 1'b1;
                    state       <= MOTOR_BUSY;end
                end

                MOTOR_BUSY: begin     // waiting for the motor to complete the given move 
                    if (move_complete) begin
								start_motor  <= 1'b0;
						      if ((cmd_reg == TURN_LEFT) || (cmd_reg == TURN_RIGHT) || (cmd_reg == U_TURN))begin //extra fwd in case of turns
									cmd_reg <= MOVE_FWD;
									state <= MOTOR_START;
								end else begin
									settle_timer <= 24'd0;
									state        <= SETTLE;
		
									settle_limit <= 30'd20_000_000;  // some delay to avoid high frequency switching to the l298 driver 
								end	
                     end
                end

                SETTLE: begin
                   //additional delay 
                    // This gives the bot time to stop shaking and sensors to update
                    if (settle_timer >= settle_limit) begin
                        start_usonic <= 1'b0; // Pulse usonic off to reset filters for new position
								settle_done <= 1'b1;
                        state        <= FINISH;
                    end else begin
                        settle_timer <= settle_timer + 1'b1;
                    end
                end

                FINISH: begin  //one move finish 
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
//--------------------------------------------------------------------------------------------------------------

    // --- Sensor Instantiations (Connecting to Raw wires) ---
    t1b_ultrasonic s_l (.clk_50M(clk_50M), .reset(reset_n), .echo_rx(echo_l),.op(wall_l), .trig(trig_l), .distance_out_1(dist_l), .measure_valid(v_l), .start(start_usonic), .inf_dist(end_l));
    t1b_ultrasonic s_m (.clk_50M(clk_50M), .reset(reset_n), .echo_rx(echo_m),.op(wall_m), .trig(trig_m), .distance_out_1(dist_m), .measure_valid(v_m), .start(start_usonic), .inf_dist(end_m));
    t1b_ultrasonic s_r (.clk_50M(clk_50M), .reset(reset_n), .echo_rx(echo_r),.op(wall_r), .trig(trig_r), .distance_out_1(dist_r), .measure_valid(v_r), .start(start_usonic), .inf_dist(end_r));

    // --- Brain, Align, Driver ---
    t2c_maze_explorer brain (
        .clk(clk_50M), .rst_n(reset_n), .start_move(get_a_move), .valid_cmd(valid_cmd),
        .left(wall_l), .mid(wall_m), .right(wall_r), .move(move_cmd), .mpi_required(mpi_required) , .ir(ir_2)
    );
    // executes the requested move 
    move_controller actuator(
        .clk(clk_50M), .move_cmd(cmd_reg), .start_motor(start_motor), .move_complete(move_complete), .busy(busy),
        .l_motor(l298_pins[1:0]), .r_motor(l298_pins[3:2]), .enc_l(enc_l) , .distm(dist_m) , .enc_r(enc_r),
		  .stable_data(stable_data) , .mpi(mpi), .wall_l(wall_l), .wall_r(wall_r), .ir_in(ir_2)
    );
    //  adjust the pwm to the driver based on the offset calculated through center aligner 
    l298_module l298_inst (
        .clk(clk_50M), .wall_r(wall_r), .wall_l(wall_l),.wall_m(wall_m), .ena(ena), .enb(enb), .speed_offset_l(off_l), .speed_offset_r(off_r)
    );
    //calcultaes the offset for each tire based on the distance from either left or front wall
    centre_aligner aligner (
        .clk(clk_50M), .dist_l(dist_l), .dist_r(dist_r), .move_cmd(cmd_reg), .busy(busy), .speed_offset_l(off_l), .speed_offset_r(off_r), .wall_l(wall_l), .wall_m(wall_m), .wall_r(wall_r)
    );
	 // module that handle all sensor, bluetooth module and servo motor;
	 sensor_communication sc(
		.clk50(clk_50M),
		.reset(reset_n),
		.sensor(sensor),
		.settle_done(settle_done),
		.ir_in(ir_2),
		.dout(dout),
		.adc_cs_n(adc_cs_n),
		.din(din),
		.adc_sck(adc_sck),
		.led_ind(led_ind),
		.servo_pwm(servo_pwm),
		.rx(rx),
		.tx(tx),
		.stable_data(stable_data),
		.data_1(data),
		.match(start),
		.mpi(mpi),
		.mpi_required(mpi_required),
		.mpi_id(mpi_id),
		.end_point(exit)
	 );

endmodule

