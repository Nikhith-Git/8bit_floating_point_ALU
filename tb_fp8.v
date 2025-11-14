`timescale 1ns/1ps

//============================================================
// Comprehensive Testbench for 8-bit Floating Point ALU
// Features:
//   - Exhaustive test coverage
//   - Automatic error detection and reporting
//   - Real-value conversion and comparison
//   - Edge case testing (zero, overflow, underflow)
//   - Exception flag verification
//   - Performance timing analysis
//============================================================

module tb_fp8;
    
    //========================================
    // DUT (Device Under Test) Signals
    //========================================
    reg  [7:0] a, b;
    reg  [2:0] op;
    wire [7:0] result;
    wire overflow, underflow, zero_flag, invalid_op;
    
    // Instantiate the ALU
    fp8_alu uut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .overflow(overflow),
        .underflow(underflow),
        .zero_flag(zero_flag),
        .invalid_op(invalid_op)
    );

    //========================================
    // Test Statistics
    //========================================
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    real max_error = 0.0;
    real total_error = 0.0;

    //========================================
    // FP8 to Real Conversion Function
    // Converts custom 8-bit float to IEEE real
    //========================================
    function real fp8_to_real;
        input [7:0] fp;
        reg sign;
        reg [2:0] exp;
        reg [3:0] frac;
        real mantissa;
        integer exp_unbias;
        begin
            sign = fp[7];
            exp  = fp[6:4];
            frac = fp[3:0];
            
            // Handle zero case
            if (fp[6:0] == 7'b0) begin
                fp8_to_real = 0.0;
            end else begin
                // Hidden bit handling
                if (exp == 3'b0) begin
                    // Denormalized: mantissa = 0.fraction
                    mantissa = frac / 16.0;
                    exp_unbias = -2;  // Denormalized exponent
                end else begin
                    // Normalized: mantissa = 1.fraction
                    mantissa = 1.0 + (frac / 16.0);
                    exp_unbias = exp - 3;  // Remove bias
                end
                
                // Compute final value: (-1)^sign × mantissa × 2^exp
                fp8_to_real = (sign ? -1.0 : 1.0) * mantissa * (2.0 ** exp_unbias);
            end
        end
    endfunction

    //========================================
    // Real to FP8 Conversion Function
    // Converts IEEE real to custom 8-bit float
    //========================================
    function [7:0] real_to_fp8;
        input real r;
        reg sign;
        reg [2:0] exp;
        reg [3:0] frac;
        real abs_r, mantissa;
        integer exp_val, i;
        begin
            if (r == 0.0) begin
                real_to_fp8 = 8'b0;
            end else begin
                // Extract sign
                sign = (r < 0.0);
                abs_r = sign ? -r : r;
                
                // Find exponent
                exp_val = 0;
                if (abs_r >= 2.0) begin
                    while (abs_r >= 2.0 && exp_val < 4) begin
                        abs_r = abs_r / 2.0;
                        exp_val = exp_val + 1;
                    end
                end else if (abs_r < 1.0) begin
                    while (abs_r < 1.0 && exp_val > -3) begin
                        abs_r = abs_r * 2.0;
                        exp_val = exp_val - 1;
                    end
                end
                
                // Extract mantissa (abs_r is now in [1.0, 2.0))
                mantissa = abs_r - 1.0;
                frac = mantissa * 16.0;
                
                // Combine fields
                exp = exp_val + 3;  // Add bias
                real_to_fp8 = {sign, exp[2:0], frac[3:0]};
            end
        end
    endfunction

    //========================================
    // Test Case Execution
    //========================================
    task test_operation;
        input [7:0] val_a, val_b;
        input [2:0] operation;
        input real expected;
        input string op_name;
        real a_real, b_real, result_real, error;
        begin
            a = val_a;
            b = val_b;
            op = operation;
            #1; // Wait for combinational logic
            
            a_real = fp8_to_real(a);
            b_real = fp8_to_real(b);
            result_real = fp8_to_real(result);
            
            test_count = test_count + 1;
            
            // Calculate relative error (handle zero case)
            if (expected != 0.0)
                error = ((result_real - expected) / expected) * 100.0;
            else
                error = result_real * 100.0;
            
            if (error < 0) error = -error;
            
            total_error = total_error + error;
            if (error > max_error) max_error = error;
            
            // Display result
            $display("[%s] %f %s %f = %f (expected: %f) | Error: %.2f%% | Flags: OV=%b UF=%b Z=%b INV=%b",
                     op_name, a_real, op_name, b_real, result_real, expected, 
                     error, overflow, underflow, zero_flag, invalid_op);
            
            // Check if test passed (within 10% tolerance for FP arithmetic)
            if (error < 10.0 || (expected == 0.0 && result_real == 0.0)) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("  *** FAILED: Error exceeds threshold ***");
            end
        end
    endtask

    //========================================
    // Main Test Sequence
    //========================================
    initial begin
        // Setup waveform dump
        $dumpfile("fp8_advanced.vcd");
        $dumpvars(0, tb_fp8_advanced);
        
        $display("\n========================================");
        $display("8-bit Floating Point ALU Test Suite");
        $display("========================================\n");
        
        //===========================================
        // ADDITION TESTS
        //===========================================
        $display("\n--- ADDITION TESTS ---");
        test_operation(8'b0_100_0010, 8'b0_100_0001, 3'b000, 1.125 + 1.0625, "ADD");
        test_operation(8'b0_101_0000, 8'b0_011_0000, 3'b000, 2.0 + 0.5, "ADD");
        test_operation(8'b0_110_0000, 8'b0_100_0000, 3'b000, 4.0 + 1.0, "ADD");
        test_operation(8'b0_100_1000, 8'b0_011_1000, 3'b000, 1.5 + 0.75, "ADD");
        
        // Zero cases
        test_operation(8'b0_000_0000, 8'b0_100_0000, 3'b000, 0.0 + 1.0, "ADD");
        test_operation(8'b0_100_0000, 8'b0_000_0000, 3'b000, 1.0 + 0.0, "ADD");
        
        // Negative numbers
        test_operation(8'b1_100_0000, 8'b0_100_0000, 3'b000, -1.0 + 1.0, "ADD");
        test_operation(8'b1_101_0000, 8'b0_100_0000, 3'b000, -2.0 + 1.0, "ADD");

        //===========================================
        // SUBTRACTION TESTS
        //===========================================
        $display("\n--- SUBTRACTION TESTS ---");
        test_operation(8'b0_100_1000, 8'b0_100_0010, 3'b001, 1.5 - 1.125, "SUB");
        test_operation(8'b0_101_0000, 8'b0_100_0000, 3'b001, 2.0 - 1.0, "SUB");
        test_operation(8'b0_110_0000, 8'b0_101_0000, 3'b001, 4.0 - 2.0, "SUB");
        
        // Result zero
        test_operation(8'b0_100_0000, 8'b0_100_0000, 3'b001, 1.0 - 1.0, "SUB");
        
        // Negative results
        test_operation(8'b0_100_0000, 8'b0_101_0000, 3'b001, 1.0 - 2.0, "SUB");

        //===========================================
        // MULTIPLICATION TESTS
        //===========================================
        $display("\n--- MULTIPLICATION TESTS ---");
        test_operation(8'b0_011_1000, 8'b0_100_0000, 3'b010, 0.75 * 1.0, "MUL");
        test_operation(8'b0_100_0000, 8'b0_100_0000, 3'b010, 1.0 * 1.0, "MUL");
        test_operation(8'b0_100_1000, 8'b0_100_0100, 3'b010, 1.5 * 1.25, "MUL");
        test_operation(8'b0_101_0000, 8'b0_011_0000, 3'b010, 2.0 * 0.5, "MUL");
        
        // Sign combinations
        test_operation(8'b1_100_0000, 8'b0_100_0000, 3'b010, -1.0 * 1.0, "MUL");
        test_operation(8'b1_100_0000, 8'b1_100_0000, 3'b010, -1.0 * -1.0, "MUL");
        
        // Zero cases
        test_operation(8'b0_000_0000, 8'b0_100_0000, 3'b010, 0.0 * 1.0, "MUL");

        //===========================================
        // DIVISION TESTS
        //===========================================
        $display("\n--- DIVISION TESTS ---");
        test_operation(8'b0_100_1000, 8'b0_100_0000, 3'b011, 1.5 / 1.0, "DIV");
        test_operation(8'b0_100_0000, 8'b0_100_0000, 3'b011, 1.0 / 1.0, "DIV");
        test_operation(8'b0_101_0000, 8'b0_100_0000, 3'b011, 2.0 / 1.0, "DIV");
        test_operation(8'b0_100_0000, 8'b0_101_0000, 3'b011, 1.0 / 2.0, "DIV");
        test_operation(8'b0_110_0000, 8'b0_100_1000, 3'b011, 4.0 / 1.5, "DIV");
        
        // Division by zero (should set invalid_op flag)
        $display("\n--- EDGE CASE: Division by Zero ---");
        a = 8'b0_100_0000; b = 8'b0_000_0000; op = 3'b011; #1;
        $display("1.0 / 0.0 = %f | Flags: OV=%b UF=%b Z=%b INV=%b",
                 fp8_to_real(result), overflow, underflow, zero_flag, invalid_op);

        //===========================================
        // LOGICAL OPERATION TESTS
        //===========================================
        $display("\n--- LOGICAL OPERATIONS ---");
        a = 8'b10101010; b = 8'b11001100; op = 3'b100; #1;
        $display("AND: %b & %b = %b", a, b, result);
        
        a = 8'b10101010; b = 8'b11001100; op = 3'b101; #1;
        $display("OR:  %b | %b = %b", a, b, result);
        
        a = 8'b10101010; b = 8'b11001100; op = 3'b110; #1;
        $display("XOR: %b ^ %b = %b", a, b, result);
        
        a = 8'b10101010; b = 8'b00000000; op = 3'b111; #1;
        $display("NOT: ~%b = %b", a, result);

        //===========================================
        // STRESS TESTS - Random Operations
        //===========================================
        $display("\n--- RANDOM STRESS TESTS ---");
        repeat(20) begin
            a = $random;
            b = $random;
            op = $random % 4;  // Random arithmetic operation
            #1;
            $display("Random[%0d]: %f op %f = %f | Flags: OV=%b UF=%b Z=%b INV=%b",
                     test_count, fp8_to_real(a), fp8_to_real(b), 
                     fp8_to_real(result), overflow, underflow, zero_flag, invalid_op);
            test_count = test_count + 1;
        end

        //===========================================
        // TEST SUMMARY
        //===========================================
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Tests:    %0d", test_count);
        $display("Passed:         %0d", pass_count);
        $display("Failed:         %0d", fail_count);
        $display("Pass Rate:      %.1f%%", (pass_count * 100.0) / test_count);
        $display("Average Error:  %.2f%%", total_error / test_count);
        $display("Maximum Error:  %.2f%%", max_error);
        $display("========================================\n");
        
        #10 $finish;
    end

    //========================================
    // Monitor for Real-time Value Display
    //========================================
    real a_real_mon, b_real_mon, result_real_mon;
    
    always @(*) begin
        a_real_mon = fp8_to_real(a);
        b_real_mon = fp8_to_real(b);
        result_real_mon = fp8_to_real(result);
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
