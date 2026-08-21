module t1b_ultrasonic(
    input clk_50M, reset, echo_rx,
    input start,
    output reg trig,
    output reg [15:0] distance_out_1,
    output reg measure_valid,
	 output wire  op, inf_dist
);
   
	 assign op =   (distance_out_1 < 200);  // 1. Synchronize echo_rx to 50MHz clock to prevent metastability
	 assign inf_dist = distance_out_1 > 400; // for detecting exit.
    reg echo_sync_0, echo_sync_1;
    always @(posedge clk_50M) begin
        echo_sync_0 <= echo_rx;
        echo_sync_1 <= echo_sync_0;
    end

    reg [23:0] counter; // Increased size for timeout (24-bit)
    reg [2:0] state;

    parameter IDLE = 3'd0, TRIGGER = 3'd1, WAIT_FOR_ECHO = 3'd2, MEASURE = 3'd3, COOLDOWN = 3'd4;
    parameter TIMEOUT_LIMIT = 24'd1_000_000; // 20ms Timeout at 50MHz

    always @(posedge clk_50M) begin
        if (!reset || !start) begin
            state <= IDLE;
            trig <= 0;
            measure_valid <= 0;
            counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    trig <= 0;
                    counter <= 0;
                    state <= TRIGGER;
                end

                TRIGGER: begin
                    trig <= 1;
                    if (counter >= 500) begin // 10us pulse
                        trig <= 0;
                        counter <= 0;
                        state <= WAIT_FOR_ECHO;
                    end else counter <= counter + 1;
                end

                WAIT_FOR_ECHO: begin
					     measure_valid <= 0;
                    if (echo_sync_1) begin
                        counter <= 0;
                        state <= MEASURE;
                    end else if (counter >= TIMEOUT_LIMIT) begin
                        state <= IDLE; // TIMEOUT: Reset to try again
                    end else counter <= counter + 1;
                end

                MEASURE: begin
                    if (!echo_sync_1) begin
                        distance_out_1 <= (counter / 294);
                        measure_valid <= 1;
                        counter <= 0;
                        state <= COOLDOWN;
                    end else if (counter >= TIMEOUT_LIMIT) begin
                        state <= IDLE; // TIMEOUT
                    end else counter <= counter + 1;
                end

                COOLDOWN: begin
					     measure_valid <= 0;
                    // 60ms delay between pings to avoid "ghost echos"
                    if (counter >= 24'd600_000) begin
						      
                        state <= IDLE;
                    end else counter <= counter + 1;
                end
            endcase
        end
    end
endmodule