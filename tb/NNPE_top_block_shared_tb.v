`timescale 1ns / 1ps

module NNPE_top_block_shared_tb();

    reg clk;
    reg reset;
    reg [7:0] system_in;
    wire [15:0] system_out;

    // Instantiate UUT
    NNPE_top_block_shared uut (
        .clk(clk), 
        .reset(reset), 
        .system_in(system_in), 
        .system_out(system_out)
    );

    // Clock Generation: 100MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("Starting Directed Simulation with Static Delays...");
        
        // --- TEST CASE 1: Original Sample ---
        reset = 1; system_in = 0; #20; reset = 0; #10;
        system_in = 8'd10;  #10; 
        system_in = 8'd45;  #10; 
        system_in = 8'd120; #10; 
        system_in = 8'd5;   #10; 
        system_in = 8'h12;  #10; 
        system_in = 0;
        
        #1000; // Static delay to allow FSM to finish 8 layers
        $display("TC1 - Final Output: %d | Expected: 14463", system_out);
        #100;

        // --- TEST CASE 2: Low Gain Growth ---
        reset = 1; #20; reset = 0; #10;
        system_in = 8'd50;  #10;
        system_in = 8'd2;   #10;
        system_in = 8'd4;   #10;
        system_in = 8'd1;   #10;
        system_in = 8'h12;  #10;
        system_in = 0;
        
        #1000; // Static delay
        $display("TC2 - Final Output: %d | Expected: 3191", system_out);
        #100;

        // --- TEST CASE 3: High Gain / Truncation ---
        reset = 1; #20; reset = 0; #10;
        system_in = 8'd100; #10;
        system_in = 8'd10;  #10;
        system_in = 8'd200; #10;
        system_in = 8'd20;  #10;
        system_in = 8'h12;  #10;
        system_in = 0;
        
        #1000; // Static delay
        $display("TC3 - Final Output: %d | Expected: 25200", system_out);
        #100;

        // --- TEST CASE 4: Zero-Feedback Case ---
        reset = 1; #20; reset = 0; #10;
        system_in = 8'd64;  #10;
        system_in = 8'd4;   #10;
        system_in = 8'd8;   #10;
        system_in = 8'd0;   #10;
        system_in = 8'h12;  #10;
        system_in = 0;
        
        #1000; // Static delay
        $display("TC4 - Final Output: %d | Expected: 8168", system_out);
        #100;

        // --- TEST CASE 5: High Bias / Low Multiplier ---
        reset = 1; #20; reset = 0; #10;
        system_in = 8'd5;   #10;
        system_in = 8'd2;   #10;
        system_in = 8'd10;  #10;
        system_in = 8'd100; #10;
        system_in = 8'h12;  #10;
        system_in = 0;
        
        #1000; // Static delay
        $display("TC5 - Final Output: %d | Expected: 193", system_out);

        #100;
        $display("All test cases completed.");
        $finish;
    end

endmodule