module t2c_maze_explorer (
    input  wire clk,
    input  wire rst_n,
	 input  wire start_move,
	 output reg  valid_cmd,
    input  wire left, mid, right,
    output reg  [2:0] move,
	 input wire ir,
	 input wire [7:0] mpi_required
);

    // =========================================================
    // Command encoding
    // =========================================================
    localparam STOP       = 3'b000;
    localparam MOVE_FWD   = 3'b001;
    localparam TURN_LEFT  = 3'b010;
    localparam TURN_RIGHT = 3'b011;
    localparam U_TURN     = 3'b100;

    // =========================================================
    // Orientation encoding
    // =========================================================
    localparam NORTH = 2'b00;
    localparam EAST  = 2'b01;
    localparam SOUTH = 2'b10;
    localparam WEST  = 2'b11;

    // =========================================================
    // State encoding
    // =========================================================
    localparam DECIDE_MOVE    = 3'b000;
    localparam MOVE           = 3'b001;  // Fixed: lowercase 'b'
    localparam BACKTRACK_MODE = 3'b010;
    localparam FINAL_EXIT     = 3'b011;
//    localparam RESET_1        = 3'b100;
    localparam RESET_2        = 3'b101;
    localparam IDLE           = 3'b110;

    // =========================================================
    // Registers and internal variables
    // =========================================================
    reg [1:0] orientation = NORTH;
    reg [4:0] deadend_counter;
    reg [4:0] x =  5'b00100;
	reg  [4:0] y = 5'b01000;
    reg [2:0] next_move = STOP;
    reg [2:0] state = IDLE;
    reg exit_found = 0;
    reg explored = 0;
	 reg wrong_turn = 0;
	 reg first_divergence = 0;
	 wire mpi_found;
	 reg mpi_done;
	 reg [3:0] mpi;
    
    wire reached_exit;
    wire divergence;
    
    reg [3:0] root_x, root_y;
    
//    localparam [3:0] START_X = 4, START_Y = 8;
    localparam [3:0] EXIT_X  = 4, EXIT_Y  = 0;
    
    assign reached_exit = (x == EXIT_X && y == EXIT_Y);
    assign divergence = ((!mid)&&(!right) || (!left)&&(!right) || (!mid)&&(!left));
	assign mpi_found =  (left && mid && right && (!ir));
    
    reg [1:0]  stack [0:14];  // Fixed array declaration
    reg [3:0] ptr = 0;

    always @(posedge clk ) begin
        if (!rst_n) begin
            // Reset all registers
            move <= STOP;
            explored <= 1'b0;
            next_move <= STOP;
            state <= IDLE;
            exit_found <= 0;
            orientation <= NORTH;
            deadend_counter <= 5'b00000;
            x <= 5'b00100;
            y <= 5'b01000;
            ptr <= 4'b0000;
        end else begin
           case(state) 
//                RESET_1:begin 
//						move <= STOP;
//						valid_cmd <= 0;
//						explored <= 1'b0;
//						next_move <= STOP;
//						state <= IDLE;
//						exit_found <= 0;
//						orientation <= NORTH;
//						deadend_counter <= 5'b00000;
//						x <= 5'b00100;
//						y <= 5'b01000;
//						ptr <= 4'b0000;
//					 end
//					 
//                RESET_2: begin
//					 state <= IDLE;
//					 end
					 
					 IDLE:begin 
					 if (exit_found) begin
						explored = ((x == root_x) && y == (root_y)) || mpi_done;
					 end
					 if (divergence  && !first_divergence )begin 
							root_x = x;
							root_y = y;
							first_divergence = 1'b1;
					 end 
						valid_cmd <= 0;
						if(start_move) begin 
							state <= DECIDE_MOVE;
						end
					 end
					 
                
                MOVE: begin 
					     if (mpi == mpi_required) begin 
								mpi_done = 1;
							end 
					     valid_cmd <= 1;
                    move <= next_move;
                    state <= IDLE;
                    
                    if (reached_exit) exit_found <= 1'b1;
                    
                    if ((!explored) && exit_found && (!wrong_turn)) begin 
                        if(divergence) begin 
                            case(orientation)
                                    NORTH: stack[ptr] <= SOUTH;
                                    EAST:  stack[ptr] <= WEST;
                                    SOUTH: stack[ptr] <= NORTH;
                                    WEST:  stack[ptr] <= EAST;
                                endcase // Store current orientation
                            ptr <= ptr + 1'b1; 
                        end 
                    end
						  
						  if (exit_found && wrong_turn && divergence) wrong_turn <= 1'b0;
                    
                    // Update position and orientation
                    case (next_move)
                        MOVE_FWD: begin
                            orientation <= orientation;
                            case (orientation)
                                NORTH: y <= y - 1;
                                EAST:  x <= x + 1;
                                SOUTH: y <= y + 1;
                                WEST:  x <= x - 1;
                            endcase
                        end
                        TURN_LEFT: begin
                            orientation <= (orientation == 2'b00) ? 2'b11 : orientation - 1;
                            case (orientation)
                                NORTH: x <= x - 1;
                                WEST:  y <= y + 1;
                                SOUTH: x <= x + 1;
                                EAST:  y <= y - 1;
                            endcase
                        end
                        TURN_RIGHT: begin
                            orientation <= (orientation == 2'b11) ? 2'b00 : orientation + 1;
                            case (orientation)
                                NORTH: x <= x + 1;
                                EAST:  y <= y + 1;
                                SOUTH: x <= x - 1;
                                WEST:  y <= y - 1;
                            endcase
                        end
                        U_TURN: begin
								  
                            deadend_counter <= deadend_counter + 1;
                            orientation <= orientation + 2'b10;
                            case (orientation)
                                NORTH: y <= y + 1;
                                SOUTH: y <= y - 1;
                                EAST:  x <= x - 1;
                                WEST:  x <= x + 1;
                            endcase
                        end
                    endcase
                end
                
                DECIDE_MOVE : begin 
					 
					     if (mpi_found) begin 
							mpi = mpi + 1;
						  end 
							
                    move <= STOP;
                    
                    // Check if all dead ends explored
//                    if(deadend_counter >= 5'b01001) explored <= 1'b1;
                    
                   if ((!reached_exit) | explored ) 
						 begin
						 if((!explored)) begin
                        state <= MOVE; 
                        if (!left) begin
                            next_move <= TURN_LEFT;
                        end else if (!mid) begin
                            next_move <= MOVE_FWD;
                        end else if (!right) begin
                            next_move <= TURN_RIGHT;
                        end else begin
								     wrong_turn <= 1'b1;

                            next_move <= U_TURN;
                        end
                    end else if(divergence && exit_found) begin
                        ptr <= ptr - 1'b1;
                        // Fixed: single case statement for orientation
                        case(orientation)
                            NORTH: begin 
                                case(stack[ptr-1])
                                    NORTH: next_move <= MOVE_FWD;
                                    EAST:  next_move <= TURN_RIGHT;
                                    SOUTH: next_move <= U_TURN;
                                    WEST:  next_move <= TURN_LEFT;
                                endcase
                            end
                            SOUTH: begin 
                                case(stack[ptr-1])
                                    NORTH: next_move <= U_TURN;
                                    EAST:  next_move <= TURN_LEFT;
                                    SOUTH: next_move <= MOVE_FWD;
                                    WEST:  next_move <= TURN_RIGHT;
                                endcase
                            end
                            EAST: begin 
                                case(stack[ptr-1])
                                    NORTH: next_move <= TURN_LEFT;
                                    EAST:  next_move <= MOVE_FWD;
                                    SOUTH: next_move <= TURN_RIGHT;
                                    WEST:  next_move <= U_TURN;
                                endcase
                            end
                            WEST: begin 
                                case(stack[ptr-1])
                                    NORTH: next_move <= TURN_RIGHT;
                                    EAST:  next_move <= U_TURN;
                                    SOUTH: next_move <= TURN_LEFT;
                                    WEST:  next_move <= MOVE_FWD;
                                endcase
                            end
                        endcase
                        state <= MOVE;
                    end
						  else begin 
                        if (!left) begin
                            next_move <= TURN_LEFT;
                        end else if (!mid) begin
                            next_move <= MOVE_FWD;
                        end else if (!right) begin
                            next_move <= TURN_RIGHT;
                        end else begin
                            next_move <= U_TURN;
                        end
                        state <= MOVE;
                    end 
						  end else begin state <= MOVE;
						         case(orientation)
								NORTH: begin if (!left) begin
                            next_move <= TURN_LEFT;
                       
                        end else if (!right) begin
                            next_move <= TURN_RIGHT;
                        end else begin
                            next_move <= U_TURN;
                        end end
								EAST: begin  if (!mid) begin
                            next_move <= MOVE_FWD;
                        end else if (!right) begin
                            next_move <= TURN_RIGHT;
                        end else begin
                            next_move <= U_TURN;
                        end end
								WEST: begin if (!left) begin
                            next_move <= TURN_LEFT;
                        end else if (!mid) begin
                            next_move <= MOVE_FWD;
                    
                        end else begin
                            next_move <= U_TURN;
                        end end
								
								
								
								
								endcase 
								
								
						
				
				             end 
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule