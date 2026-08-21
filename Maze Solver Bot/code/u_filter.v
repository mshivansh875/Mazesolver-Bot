/*
Module: ultrasonic_filter (Improved with Outlier Rejection)
Ignores 0 values and extreme spikes caused by motor noise.
*/

module ultrasonic_filter (
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] raw_dist,
    input  wire raw_valid,      
    output reg  [15:0] avg_dist,
    output reg  ready           
);

    reg [3:0] sample_count;
    reg [18:0] sum; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= 0;
            sum <= 0;
            avg_dist <= 0;
            ready <= 0;
        end else begin
            if (raw_valid) begin
                // OUTLIER REJECTION: 
                // Ultrasonic sensors often return 0 or 3000+ when they fail due to noise.
                // We only count samples between 20mm and 2000mm.
                if (raw_dist > 20 && raw_dist < 2000) begin
                    if (sample_count == 7) begin
                        avg_dist <= (sum + raw_dist) >> 3;
                        sum <= 0;
                        sample_count <= 0;
                        ready <= 1;
                    end else begin
                        sum <= sum + raw_dist;
                        sample_count <= sample_count + 1;
                        ready <= 0;
                    end
                end
            end else begin
                ready <= 0;
            end
        end
    end

endmodule