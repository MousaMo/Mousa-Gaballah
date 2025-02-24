// -----------------------------------
// Bit Delay Module (Stores the Previous DPSK Bit)
// -----------------------------------
module bit_delay (
    input wire clk,
    input wire rst,
    input wire dpsk_bit_in,  // Current extracted DPSK bit
    output reg dpsk_bit_out  // Delayed (previous) DPSK bit
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            dpsk_bit_out <= 1'b1;  // Initialize to `1` to ensure correct demodulation
        else
            dpsk_bit_out <= dpsk_bit_in; // Store the current DPSK bit for next cycle
    end
endmodule


// -----------------------------------
// DPSK Bit Extraction Module (Converts Signal to Digital Bit)
// -----------------------------------
module dpsk_bit_extractor (
    input signed [15:0] dpsk_signal, // Received DPSK modulated signal
    output wire dpsk_bit             // Extracted DPSK bit
);
    assign dpsk_bit = (dpsk_signal >= 0) ? 1'b1 : 1'b0;
endmodule


// -----------------------------------
// XNOR Logic Module (Recovers Original Data)
// -----------------------------------
module xnor_logic (
    input wire current_dpsk_bit,   // Current extracted DPSK bit
    input wire previous_dpsk_bit,  // Previous DPSK bit (delayed)
    output wire recovered_data     // Recovered original data
);
    assign recovered_data = ~(current_dpsk_bit ^ previous_dpsk_bit); // XNOR operation
endmodule


// -----------------------------------
// DPSK Demodulator Module (Top Module for DPSK Demodulation)
// -----------------------------------
module dpsk_demodulator (
    input wire clk,
    input wire rst,
    input signed [15:0] dpsk_signal, // Received DPSK modulated signal
    output wire recovered_data       // Output recovered data
);
    wire dpsk_bit, delayed_dpsk_bit;
    // Store previous DPSK bit for comparison
    bit_delay delay_unit (
        .clk(clk),
        .rst(rst),
        .dpsk_bit_in(dpsk_bit),
        .dpsk_bit_out(delayed_dpsk_bit)
    );
     // Extract DPSK digital bit from the modulated signal
    dpsk_bit_extractor extractor (
        .dpsk_signal(dpsk_signal),
        .dpsk_bit(dpsk_bit)
    );

    // Recover original data using XNOR
    xnor_logic xnor_mod (
        .current_dpsk_bit(dpsk_bit),
        .previous_dpsk_bit(delayed_dpsk_bit),
        .recovered_data(recovered_data)
    );

endmodule


// -----------------------------------
// DPSK Demodulation Testbench
// -----------------------------------

module dpsk_demodulator_tb;

    reg clk, rst;
    reg signed [15:0] dpsk_signal;
    wire recovered_data;

    // Instantiate the DPSK Demodulator
    dpsk_demodulator uut (
        .clk(clk),
        .rst(rst),
        .dpsk_signal(dpsk_signal),
        .recovered_data(recovered_data)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50MHz clock (20ns period)
    end

    // Apply Test Data
    initial begin
        rst = 1;
        dpsk_signal = 16'sd1000; // Initial signal
        #20 rst = 0; // Release reset

        // Simulated DPSK signal transitions
        @(negedge clk); dpsk_signal = 16'sd1000;  // No phase change (1)
        @(negedge clk); dpsk_signal = -16'sd1000; // Phase shift (0)
        @(negedge clk); dpsk_signal = 16'sd1000;  // Phase shift (1)
        @(negedge clk); dpsk_signal = 16'sd1000;  // No phase change (1)
        @(negedge clk); dpsk_signal = -16'sd1000; // Phase shift (0)
        @(negedge clk); dpsk_signal = -16'sd1000; // No phase change (0)
        @(negedge clk); dpsk_signal = 16'sd1000;  // Phase shift (1)
        @(negedge clk); dpsk_signal = 16'sd1000;  // No phase change (1)

        #500;
        $stop;
    end

    // Monitor Output Signals
    initial begin
        $monitor("Time = %0t | dpsk_signal = %d | recovered_data = %b",
                 $time, dpsk_signal, recovered_data);
    end
endmodule
