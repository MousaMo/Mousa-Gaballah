// -----------------------------------
//   (Stores the Previous Bit)
// -----------------------------------
module bit_delay (
    input wire clk,
    input wire rst,
    input wire serial_data_in,  // Current input serial bit
    output reg serial_data_out  // Delayed (previous) serial bit
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            serial_data_out <= 1'b1;  // Initialize to `1` to avoid phase errors
        else
            serial_data_out <= serial_data_in; // Store the current bit for the next cycle
    end
endmodule

// -----------------------------------
// XNOR Logic Module (Computes DPSK Bit)
// -----------------------------------
module xnor_logic (
    input wire serial_data,   // Current serial data bit
    input wire delayed_data,  // Previous serial data bit (delayed)
    output wire dpsk_bit      // DPSK bit output
);
    assign dpsk_bit = ~(serial_data ^ delayed_data);  // XNOR operation
endmodule

// -----------------------------------
// Balanced Modulator (Phase Shift Modulation)
// -----------------------------------
module balanced_modulator (
    input wire clk,
    input wire rst,
    input wire dpsk_bit,           // DPSK bit after XNOR encoding
    input signed [15:0] carrier,   // Carrier signal
    output signed [15:0] dpsk_signal // DPSK modulated signal
);

    reg signed [15:0] dpsk_signal_previous; // Store the previous DPSK signal

    always @(posedge clk or posedge rst) begin
        if (rst)
            dpsk_signal_previous <= carrier; // Initialize to the carrier signal
        else
            dpsk_signal_previous <= dpsk_signal; // Store the previous modulated signal
    end

    // If dpsk_bit = 1, keep the same signal; if dpsk_bit = 0, invert the previous signal
    assign dpsk_signal = (dpsk_bit) ? dpsk_signal_previous : -dpsk_signal_previous;

endmodule
// -----------------------------------
// DPSK Modulator (Top Module)
// -----------------------------------
module dpsk_modulator (
    input wire clk,
    input wire rst,
    input wire serial_data,         // Input serial data
    input signed [15:0] carrier,    // Carrier signal
    output signed [15:0] dpsk_out   // DPSK modulated output signal
);
    wire delayed_bit, dpsk_bit;

    // Bit Delay Unit (Stores previous serial data bit)
    bit_delay delay_unit (
        .clk(clk),
        .rst(rst),
        .serial_data_in(serial_data),  
        .serial_data_out(delayed_bit)  
    );

    // XNOR Logic to compute DPSK bit
    xnor_logic xnor_mod (
        .serial_data(serial_data),
        .delayed_data(delayed_bit),
        .dpsk_bit(dpsk_bit)
    );

    // Balanced Modulator to generate DPSK output
    balanced_modulator modulator (
        .clk(clk),
        .rst(rst),
        .carrier(carrier),
        .dpsk_bit(dpsk_bit),
        .dpsk_signal(dpsk_out)
    );
endmodule

// -----------------------------------
// DPSK Modulator Testbench
// -----------------------------------
module dpsk_tb;

    reg clk, rst;
    reg serial_data;
    reg signed [15:0] carrier;
    wire signed [15:0] dpsk_out;

    // Instantiate the DPSK modulator
    dpsk_modulator uut (
        .clk(clk),
        .rst(rst),
        .serial_data(serial_data),
        .carrier(carrier),
        .dpsk_out(dpsk_out)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; 
    end

    // Apply Input Test Data
    initial begin
        rst = 1;
        serial_data = 0;
        carrier = 16'sd1000; 
        
        #20 rst = 0; // Release reset
        #20; 

        // Test sequence of serial_data inputs
        @(posedge clk); serial_data = 1; // Phase shift
        @(posedge clk); serial_data = 0; // Phase shift
        @(posedge clk); serial_data = 1; // Phase shift
        @(posedge clk); serial_data = 1; // No phase shift
        @(posedge clk); serial_data = 0; // Phase shift
        @(posedge clk); serial_data = 0; // No phase shift
        @(posedge clk); serial_data = 1; // Phase shift
        @(posedge clk); serial_data = 1; // No phase shift

        #500;
        $stop;
    end

    // Monitor Output Signals
    initial begin
        $monitor("Time = %0t | serial_data = %b | delayed_bit = %b | dpsk_bit = %b | dpsk_out = %d",
                 $time, serial_data, uut.delay_unit.serial_data_out, uut.xnor_mod.dpsk_bit, dpsk_out);
    end
endmodule


        