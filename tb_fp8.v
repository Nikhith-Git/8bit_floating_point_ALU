`timescale 1ns/1ps

//============================================================
// 8-Bit Floating Point ALU Testbench
// Author : Gurram Lakshmi Nikhith
// Dept   : ECE, SRM University-AP
// File   : tb_fp8.v
//
// Description:
// -------------
// This testbench verifies an 8-bit floating-point ALU (FP8 format).
// It includes:
//
// ✔ Fully corrected FP8 encoder (real → fp8)
// ✔ FP8 decoder (fp8 → real)
// ✔ Automated test system (pass/fail counters)
// ✔ Practical arithmetic testcases
// ✔ Edge case tests
// ✔ Mixed signed operations
// ✔ Approximation quality tests
//
// The FP8 format used:
//     [7]    = Sign bit
//     [6:4]  = 3-bit exponent (bias = 3)
//     [3:0]  = 4-bit mantissa
//
// This testbench is production-ready with detailed diagnostics,
// percentage-error checking, and structured test result printing.
//
// NOTE:
// No functional part of the code is modified—only comments added.
//============================================================

module tb_fp8_practical;
    
    // ----------------------------
    // DUT inputs and outputs
    // ----------------------------
    reg  [7:0] a, b;              // FP8 inputs
    reg  [2:0] op;                // Operation select
    wire [7:0] result;            // FP8 result from ALU
    wire overflow, underflow;     // Flag outputs
    wire zero_flag, invalid_op;

    // Instantiate the Device Under Test (ALU)
    fp8_alu uut (
        .a(a), .b(b), .op(op), .result(result),
        .overflow(overflow), .underflow(underflow),
        .zero_flag(zero_flag), .invalid_op(invalid_op)
    );

    // ----------------------------
    // Test counters
    // ----------------------------
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    //============================================================
    // FP8 → REAL conversion
    // Converts encoded FP8 (Sign + Exp + Mantissa) to real number
    //============================================================
    function real fp8_to_real;
        input [7:0] fp;
        reg s;
        reg [2:0] e;
        reg [3:0] f;
        real mantissa;
        begin
            s = fp[7];
            e = fp[6:4];
            f = fp[3:0];

            // Zero handling
            if (fp[6:0] == 7'b0) begin
                fp8_to_real = 0.0;
            end else begin
                // Normalized mantissa = 1.F
                mantissa = 1.0 + (f / 16.0);

                // Apply sign and exponent (bias = 3)
                fp8_to_real = (s ? -1.0 : 1.0) *
                               mantissa *
                               (2.0 ** $signed(e - 3));
            end
        end
    endfunction

    //============================================================
    // REAL → FP8 conversion
    // Corrected version with rounding + normalization
    //============================================================
    function [7:0] real_to_fp8;
        input real value;
        reg s;
        reg [2:0] e_biased;
        integer e;
        real abs_val, normalized;
        integer f;
        begin
            // Zero case
            if (value == 0.0) begin
                real_to_fp8 = 8'b0;
            end else begin
                s = (value < 0.0);
                abs_val = s ? -value : value;

                // ----------------------------
                // Normalize into [1.0, 2.0)
                // ----------------------------
                e = 0;
                normalized = abs_val;

                // Shift right if ≥2.0
                while (normalized >= 2.0 && e < 4) begin
                    normalized = normalized / 2.0;
                    e = e + 1;
                end

                // Shift left if <1.0
                while (normalized < 1.0 && e > -3) begin
                    normalized = normalized * 2.0;
                    e = e - 1;
                end

                // Mantissa = fractional part × 16
                f = $rtoi((normalized - 1.0) * 16.0 + 0.5); // rounded
                if (f > 15) f = 15;

                // Exponent bias = 3
                e_biased = (e + 3);
                if (e_biased > 7) e_biased = 7;
                if (e_biased < 0) e_biased = 0;

                real_to_fp8 = {s, e_biased[2:0], f[3:0]};

                // Debug prints for special values
                if ((value == 2.75) || (value == 1.25)) begin
                    $display("  Encoding %.3f: norm=%.3f e=%0d f=%0d → %b",
                              value, normalized, e, f, real_to_fp8);
                end
            end
        end
    endfunction

    //============================================================
    // Test Task
    // Packs:
    //   - FP8 conversion
    //   - Operation execution
    //   - Real conversion of result
    //   - Error analysis (% diff)
    //   - PASS/FAIL logging
    //============================================================
    task test_real;
        input real in_a, in_b;
        input [2:0] operation;
        input real expected;
        input [31:0] name;
        real val_result, error;
        begin
            a = real_to_fp8(in_a);
            b = real_to_fp8(in_b);
            op = operation;

            #1000; // Allow time for ALU processing

            val_result = fp8_to_real(result);
            test_count = test_count + 1;

            // Compute percentage error
            if (expected != 0.0)
                error = ((val_result - expected) / expected) * 100.0;
            else
                error = (val_result == 0.0) ? 0.0 : 100.0;

            if (error < 0.0) error = -error;

            // Print test info
	    $display("[%s] %.3f %s %.3f = %.3f (exp: %.3f) Error:%.1f%% [%b]", name, in_a, (operation==3'b000)?"+":(operation==3'b001)?"-":(operation==3'b010)?"*":(operation==3'b011)?"/":"?", in_b, val_result, expected, error, result);


            // PASS or FAIL
            if (error < 20.0 || (expected == 0.0 && val_result == 0.0)) begin
                pass_count = pass_count + 1;
                $display("  ✓ PASS");
            end else begin
                fail_count = fail_count + 1;
                $display("  ✗ FAIL (error exceeds 20%%)");
            end
        end
    endtask

    //============================================================
    // MAIN TEST SEQUENCE
    //============================================================
    initial begin
        
        // Initial conversion demonstration
        $display("\n=== TESTING CONVERSION ===");
        a = real_to_fp8(2.75);
        $display("2.75 encoded as: %b", a);
        b = real_to_fp8(1.25);
        $display("1.25 encoded as: %b", b);
        $display("========================\n");

        $display("\n========================================");
        $display("8-bit FP ALU - FIXED Test Suite");
        $display("Testing with corrected FP8 encoding");
        $display("========================================\n");

        // --------------------------
        // ADDITION TESTS
        // --------------------------
        $display("--- ADDITION TESTS ---");
        test_real(2.75, 1.25, 3'b000, 4.0, "ADD ");
        test_real(3.5, 2.5, 3'b000, 6.0, "ADD ");
        test_real(1.125, 0.875, 3'b000, 2.0, "ADD ");
        test_real(7.5, 4.5, 3'b000, 12.0, "ADD ");
        test_real(0.625, 0.375, 3'b000, 1.0, "ADD ");
        test_real(10.0, 5.0, 3'b000, 15.0, "ADD ");
        test_real(0.25, 0.75, 3'b000, 1.0, "ADD ");
        test_real(1.5, 1.5, 3'b000, 3.0, "ADD ");

        // --------------------------
        // SUBTRACTION TESTS
        // --------------------------
        $display("\n--- SUBTRACTION TESTS ---");
        test_real(5.5, 2.5, 3'b001, 3.0, "SUB ");
        test_real(8.75, 3.25, 3'b001, 5.5, "SUB ");
        test_real(3.0, 1.5, 3'b001, 1.5, "SUB ");
        test_real(10.0, 6.0, 3'b001, 4.0, "SUB ");
        test_real(2.25, 1.25, 3'b001, 1.0, "SUB ");
        test_real(7.0, 7.0, 3'b001, 0.0, "SUB ");

        // --------------------------
        // MULTIPLICATION TESTS
        // --------------------------
        $display("\n--- MULTIPLICATION TESTS ---");
        test_real(2.5, 2.0, 3'b010, 5.0, "MUL ");
        test_real(1.5, 3.0, 3'b010, 4.5, "MUL ");
        test_real(0.75, 4.0, 3'b010, 3.0, "MUL ");
        test_real(2.25, 2.0, 3'b010, 4.5, "MUL ");
        test_real(1.25, 4.0, 3'b010, 5.0, "MUL ");
        test_real(3.5, 2.0, 3'b010, 7.0, "MUL ");
        test_real(0.5, 0.5, 3'b010, 0.25, "MUL ");

        // --------------------------
        // DIVISION TESTS
        // --------------------------
        $display("\n--- DIVISION TESTS ---");
        test_real(10.0, 2.5, 3'b011, 4.0, "DIV ");
        test_real(7.5, 1.5, 3'b011, 5.0, "DIV ");
        test_real(9.0, 3.0, 3'b011, 3.0, "DIV ");
        test_real(6.0, 1.5, 3'b011, 4.0, "DIV ");
        test_real(4.5, 1.5, 3'b011, 3.0, "DIV ");
        test_real(8.0, 2.0, 3'b011, 4.0, "DIV ");
        test_real(1.5, 3.0, 3'b011, 0.5, "DIV ");

        // --------------------------
        // EDGE CASES
        // --------------------------
        $display("\n--- EDGE CASES ---");
        test_real(0.125, 0.125, 3'b000, 0.25, "ADD ");
        test_real(15.0, 15.0, 3'b000, 30.0, "ADD ");
        test_real(0.5, 0.25, 3'b010, 0.125, "MUL ");
        test_real(16.0, 16.0, 3'b010, 256.0, "MUL ");

        // --------------------------
        // MIXED SIGN TESTS
        // --------------------------
        $display("\n--- SIGNED OPERATIONS ---");
        test_real(5.0, -2.0, 3'b000, 3.0, "ADD ");
        test_real(-3.0, -2.0, 3'b000, -5.0, "ADD ");
        test_real(4.0, -4.0, 3'b000, 0.0, "ADD ");
        test_real(-6.0, 3.0, 3'b010, -18.0, "MUL ");
        test_real(-2.5, -2.0, 3'b010, 5.0, "MUL ");

        // --------------------------
        // APPROXIMATION TESTS
        // --------------------------
        $display("\n--- APPROXIMATION TESTS ---");
        test_real(3.14159, 2.71828, 3'b000, 5.85987, "ADD ");
        test_real(1.414, 1.732, 3'b000, 3.146, "ADD ");
        test_real(2.5, 1.6, 3'b010, 4.0, "MUL ");

        // --------------------------
        // SUMMARY
        // --------------------------
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Tests:    %0d", test_count);
        $display("Passed:         %0d", pass_count);
        $display("Failed:         %0d", fail_count);
        $display("Pass Rate:      %.1f%%", (pass_count * 100.0) / test_count);

        if (fail_count == 0) begin
            $display("\n🎉 ALL TESTS PASSED! 🎉");
            $display("Your FP8 ALU handles practical values well!");
        end else begin
            $display("\n⚠ %0d tests failed", fail_count);
            $display("Note: FP8 has limited precision - some error is expected");
        end

        $display("========================================\n");

        #10 $finish;
    end

    // Safety timeout to prevent infinite simulation
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
