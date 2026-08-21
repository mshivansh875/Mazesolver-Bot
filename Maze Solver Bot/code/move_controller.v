

//Motor Controller Debug Version:
//- Fixes instantiation of encoder_counter.
////- Uses explicit reg for counter to help with Signal Tap visibility.
//- Implements the Turn -> Move Forward logic for hardware calibration.
//*/

module move_controller (
    input wire clk,
	 input start_motor,
	 output reg busy , move_complete,
    input [2:0] move_cmd,	 // 50 MHz
    output reg [1:0] l_motor,  
    output reg [1:0] r_motor, 
	 output reg mpi,
	 
    input wire enc_l,
	 input wire enc_r,
	 input wire [15:0] distm,
	 input wire stable_data, wall_l , wall_r, ir_in

);
    
  assign front_wall_detected = (distm < 80 );

    // Speed enable pins (Keep high for max speed during debug)


    // FSM States
    localparam IDLE         = 3'd0;
    localparam EXEC_MOVE    = 3'd1;
    localparam WAIT_ENCODER = 3'd2;
    localparam FINISH       = 3'd3;
    localparam WAIT_EXEC   = 	3'd4;
	 localparam WAIT_FINISH  = 3'd5;
	 localparam CHECK_MPI 	 = 3'd6;
	 localparam WAIT_CAPTURE = 3'd7;

    // Command Constants
    localparam MOVE_FWD   = 3'b001;
    localparam TURN_LEFT  = 3'b010;
    localparam TURN_RIGHT = 3'b011;
    localparam U_TURN     = 3'b100;
    localparam STOP       = 3'b000;

	 
//	 
//    reg [3:0]  state;
//    reg [19:0] servo_cnt;
//    reg [19:0] duty_cycle;
//    reg [31:0] enc_target;
//    reg [31:0] enc_count;
//    reg        last_enc_l;
	 reg turn_complete;

    reg [2:0]  state;
    reg [1:0]  state_2;// for encoder 
    reg [31:0] counter_target;
    reg        counter_clear;  //reset encoder counter 
    
	 
	 reg [30:0] g_counter = 0;  // delay between states 
	 reg start_cnt = 0;
  
    reg        rst_n = 1'b1; // no reset signal rightnow 
    
    // Internal wire for encoder
   

    // --- ENCODER INSTANTIATION ---
   
   reg [1:0] sync;
    reg [3:0] filter;
    reg       clean_state;
    reg       last_state;
	 reg [31:0] count;
	 reg [19:0] counter_1 = 0;
//	 initial mpi_id = 0;
	 always @(posedge clk)begin
		if(start_cnt)begin
			g_counter <= g_counter + 1;
		end
		else begin
			g_counter <= 0;
		end
	 end
	 
	 // encoder logic 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync <= 2'b0;
            filter <= 4'b0;
            clean_state <= 1'b0;
            last_state <= 1'b0;
            count <= 32'd0;
        end else begin
            // 1. Synchronize to prevent metastability
            sync <= {sync[0], enc_l};

            // 2. Short Filter (Debounce)
            if (sync[1] == clean_state) begin
                filter <= 4'b0;
            end else begin
                filter <= filter + 1;
                if (filter == 4'hF) clean_state <= sync[1];
            end

            // 3. Edge Detect and Count
            last_state <= clean_state;
            if (counter_clear) begin
                count <= 32'd0;
            end else if (clean_state && !last_state) begin
                count <= count + 1;
//					 count2 <= count;
            end
        end
    end

    // Main Control FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            l_motor <= 2'b00;
            r_motor <= 2'b00;
            counter_clear <= 1'b1;
            turn_complete <= 1'b0;
        end else begin
            case (state)
                IDLE: begin               //waits for the start signal as well as move cmd from the top module
						  move_complete <= 1'b0;
                    counter_clear <= 1'b1;
                    l_motor <= 2'b00;
                    r_motor <= 2'b00;
                    turn_complete <= 1'b0;
						  if (start_motor) begin     
								start_cnt <= 1;
								state <= CHECK_MPI;
						  end 
                end
					 CHECK_MPI: begin 		// checks if the location is measuring points.
							if(!ir_in && wall_l && wall_r && front_wall_detected) begin
								if(counter_1 > 100000)begin
									mpi <= 1'B1;
									l_motor <= 2'b00;
									r_motor <= 2'b00;
									counter_target <= 32'd0;
									state <= WAIT_CAPTURE;
								end
								else begin
									counter_1 <= counter_1 + 1;
								end
							end
							else begin
								state <= WAIT_EXEC;
							end
					end
					WAIT_CAPTURE: begin	// if location is measuring point comes in this state and stops motor until measurement is done.
						mpi<= 1'b0;
						if(stable_data) begin
							state <= WAIT_EXEC;
						end
					end
					 WAIT_EXEC:begin   // little delay before execution
						if (g_counter >= 'd1000)begin 
							state <= EXEC_MOVE;
							start_cnt <= 0;
						end
					 end

                EXEC_MOVE: begin   // sets encoder count based on the move 
					 
					     busy <= 1;
                   counter_clear <= 1'b1; 
						 counter_clear_r <= 1'b1;
                    case (move_cmd)
                        MOVE_FWD:   begin l_motor <= 2'b01; r_motor <= 2'b01; counter_target <= 32'd603; end
                        TURN_LEFT:  begin l_motor <= 2'b01; r_motor <= 2'b10; counter_target <= 32'd385 + ($signed(drift_offset)<<4); end //dynamic left and right turn 
                        TURN_RIGHT: begin l_motor <= 2'b10; r_motor <= 2'b01; counter_target <= 32'd420 + ($signed(-drift_offset)<<4); end //based on the difference in encoder counts when moving forward 
                        U_TURN:     begin l_motor <= 2'b10; r_motor <= 2'b01; counter_target <= 32'd840; end
                        default:    begin l_motor <= 2'b00; r_motor <= 2'b00; counter_target <= 32'd0;   end
                    endcase
                    state <= WAIT_ENCODER;
                end

                WAIT_ENCODER: begin
                    counter_clear <= 1'b0; // Start counting
						  counter_clear_r <= 1'b0;
                    if (count >= counter_target || (front_wall_detected  && (move_cmd == MOVE_FWD))) begin  // stoping the motors either front wall detected or encoder counts completed 
                        l_motor <= 2'b00; 
                        r_motor <= 2'b00;
								state <= WAIT_FINISH;
								start_cnt <= 1;
                    end
                end
					 
					 WAIT_FINISH:begin   // delay before finsh 
						if (g_counter >= 'd1000)begin 
							start_cnt <= 0;
							state <= FINISH;
						end
					 end

                FINISH: begin   // flags the move_complete signal to the top module 
					 
					     l_motor <= 2'b00; 
                    r_motor <= 2'b00;
						  busy <= 0;
						  move_complete <= 1;
                    turn_complete <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
	 
	 // ---RIGHT_ENCODER INSTANTIATION--
	 	    reg [1:0] sync_r;
    reg [3:0] filter_r;
    reg       clean_state_r;
    reg       last_state_r;
	 reg [31:0] count_r;
	 reg counter_clear_r;
	 

	 // encoder logic 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_r <= 2'b0;
            filter_r <= 4'b0;
            clean_state_r <= 1'b0;
            last_state_r <= 1'b0;
            count_r <= 32'd0;
        end else begin
            // 1. Synchronize to prevent metastability
            sync_r <= {sync_r[0], enc_r};

            // 2. Short Filter (Debounce)
            if (sync_r[1] == clean_state_r) begin
                filter_r <= 4'b0;
            end else begin
                filter_r <= filter_r + 1;
                if (filter_r == 4'hF) clean_state_r <= sync_r[1];
            end

            // 3. Edge Detect and Count
            last_state_r <= clean_state_r;
            if (counter_clear_r) begin
                count_r <= 32'd0;
            end else if (clean_state_r && !last_state_r) begin
                count_r <= count_r + 1;
            end
        end
    end
	 
	 
	 
	 /*
Module: odometry_monitor
Purpose: Tracks wheel travel distance during forward moves to detect orientation drift.
Logic: 
- When 'busy' and 'MOVE_FWD' are active, it accumulates encoder pulses.
- At the end of the move, it calculates the 'drift' (Left Count - Right Count).
- A positive drift means the left wheel moved more (bot veered right).
- A negative drift means the right wheel moved more (bot veered left).
- This 'drift' can be used to subtract/add from the turn counter_targets.
*/


  
    reg signed [15:0]  drift_offset;
    reg [31:0] internal_count_l;
    reg [31:0] internal_count_r;
    
    // State tracking to detect transition to a turn
    reg was_moving_fwd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            drift_offset     <= 0;
            internal_count_l <= 0;
            internal_count_r <= 0;
   
            was_moving_fwd   <= 0;
        end else begin
 
            // 2. Accumulate counts ONLY when moving forward
            if (busy && (move_cmd == MOVE_FWD)) begin
                was_moving_fwd <= 1'b1;
                
                if ((clean_state && !last_state) )
                    internal_count_l <= internal_count_l + 1;
                
                if (clean_state_r && !last_state_r) 
                    internal_count_r <= internal_count_r + 1;
//				drift_offset <= $signed(internal_count_l) - $signed(internal_count_r);
            end 
				 
				 
            
            // 3. Detect transition to a TURN move
            // We calculate drift when the command changes from MOVE_FWD to a TURN
            else if (busy && was_moving_fwd && (move_cmd == TURN_LEFT || move_cmd == TURN_RIGHT)) begin
                
                // Calculate total drift accumulated over the straight path
                drift_offset <= $signed(internal_count_l) - $signed(internal_count_r);
                
                // Reset internal counters for the next journey
                internal_count_l <= 0;
                internal_count_r <= 0;
                was_moving_fwd   <= 0;
            end
            
            // Handle edge case where bot stops without turning
            else if (!busy ) begin
                // Optional: You could choose to keep or clear data here.
                // Keeping was_moving_fwd high allows for cumulative counting 
                // across multiple "Start/Stop" forward increments.
            end
				
				else begin
					drift_offset <= 0;
					internal_count_l <= 0;
               internal_count_r <= 0;
				end
				
        end
    end
endmodule


module move_controller(
	 input wire clk,
	 input start_motor,
	 output reg busy , move_complete,
    input [2:0] move_cmd,	 // 50 MHz
    output reg [1:0] l_motor,  
    output reg [1:0] r_motor, 
	 output reg mpi,
	 
    input wire enc_l,
	 input wire enc_r,
	 input wire [15:0] distm,
	 input wire stable_data, wall_l , wall_r, ir_in
);

endmodule