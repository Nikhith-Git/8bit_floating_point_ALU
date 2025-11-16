//=============================================================================
// 8-bit Floating Point ALU (Arithmetic Logic Unit)
//
// G.Nikhith (AP23110020120)
//
// Description:
// This module implements an ALU for a custom 8-bit floating-point format.
// It supports addition, subtraction, multiplication, division,
// and bitwise logical operations.
//
// FP8 Format (Normalized, Bias=3):
// [7]   : Sign bit (0=positive, 1=negative)
// [6:4] : 3-bit Exponent (bias of 3)
// [3:0] : 4-bit Mantissa (Fraction)
//
// Value Calculation:
// Value = (-1)^sign * (1.fraction) * 2^(exponent - 3)
//
// Example:
// 0_100_1000 = (-1)^0 * (1.1000_bin) * 2^(4-3)
//            = 1 * (1 + 8/16) * 2^1
//            = 1 * (1.5) * 2
//            = 3.0
//
//=============================================================================

module fp8_alu (
    // Inputs
    input  wire [7:0] a,          // 8-bit FP input 'a'
    input  wire [7:0] b,          // 8-bit FP input 'b'
    input  wire [2:0] op,         // 3-bit operation code
                                 // 000: ADD
                                 // 001: SUB
                                 // 010: MUL
                                 // 011: DIV
                                 // 100: AND
                                 // 101: OR
                                 // 110: XOR
                                 // 111: NOT (of 'a')
    
    // Outputs
    output reg  [7:0] result,     // 8-bit FP result
    
    // Status Flags
    output reg        overflow,   // Result is too large to represent
    output reg        underflow,  // Result is too small to represent
    output reg        zero_flag,  // Result is zero
    output reg        invalid_op  // Operation is invalid (e.g., div by zero)
);

    //================================================
    // Step 1: Unpack Inputs
    //================================================
    // Deconstruct 'a' into its components
    wire sign_a = a[7];
    wire [2:0] exp_a = a[6:4];
    wire [3:0] frac_a = a[3:0];

    // Deconstruct 'b' into its components
    wire sign_b = b[7];
    wire [2:0] exp_b = b[6:4];
    wire [3:0] frac_b = b[3:0];

    // Check for zero inputs. A number is zero if all bits
    // (except the sign) are zero.
    wire zero_a = (a[6:0] == 7'b0);
    wire zero_b = (b[6:0] == 7'b0);

    // Reconstruct the full mantissa by adding the implicit '1'
    // (e.g., frac=1000 -> mant=1_1000)
    wire [4:0] mant_a = {1'b1, frac_a};
    wire [4:0] mant_b = {1'b1, frac_b};


    //================================================
    // Step 2: Internal Registers for Calculation
    //================================================
    // Registers for add/sub operations
    reg [5:0] aligned_a, aligned_b; // 6 bits for 5-bit mantissa + 1 guard bit
    reg [6:0] sum;                 // 7 bits to hold sum of 6-bit aligned mantissas
    reg a_is_larger;               // Flag for subtraction

    // Register for mul/div operations
    reg [9:0] product;             // 10 bits for 5-bit * 5-bit multiplication

    // Registers for final result assembly
    reg [2:0] result_exp;
    reg result_sign;

    // Use 'integer' for intermediate exponent math to avoid
    // 3-bit signed arithmetic issues.
    integer exp_delta;
    integer temp_exp;


    //================================================
    // Step 3: Combinational Logic (ALU Core)
    //================================================
    // This 'always' block recalculates whenever any input changes.
    always @(*) begin
        
        // Default all flags to 'false' at the start of any calculation
        overflow = 1'b0;
        underflow = 1'b0;
        zero_flag = 1'b0;
        invalid_op = 1'b0;
        result = 8'b0; // Default result to 0

        // Main operation selection
        case (op)
            
            //===========================================
            // OPERATION: ADDITION (op = 3'b000)
            //===========================================
            3'b000: begin
                // --- Handle special cases (zero) ---
                if (zero_a && zero_b) begin
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else if (zero_a) begin
                    result = b; // a + b = 0 + b = b
                end else if (zero_b) begin
                    result = a; // a + b = a + 0 = a
                
                // --- Standard case (non-zero) ---
                end else begin
                    // Determine which number is larger (for subtraction)
                    if (exp_a > exp_b) begin
                        a_is_larger = 1'b1;
                    end else if (exp_a < exp_b) begin
                        a_is_larger = 1'b0;
                    end else begin
                        a_is_larger = (mant_a >= mant_b);
                    end
                    
                    // --- Mantissa Alignment ---
                    // Calculate exponent difference
                    // (FIXED: Simple integer subtraction, no $signed!)
                    exp_delta = exp_a - exp_b;
                    
                    if (exp_delta > 0) begin // a's exponent is larger
                        aligned_a = {1'b0, mant_a}; // Add guard bit
                        // Shift b's mantissa right to match a's exponent
                        aligned_b = (exp_delta >= 5) ? 6'b0 : ({1'b0, mant_b} >> exp_delta);
                        result_exp = exp_a;
                    end else if (exp_delta < 0) begin // b's exponent is larger
                        // Shift a's mantissa right to match b's exponent
                        aligned_a = ((-exp_delta) >= 5) ? 6'b0 : ({1'b0, mant_a} >> (-exp_delta));
                        aligned_b = {1'b0, mant_b}; // Add guard bit
                        result_exp = exp_b;
                    end else begin // Exponents are equal
                        aligned_a = {1'b0, mant_a};
                        aligned_b = {1'b0, mant_b};
                        result_exp = exp_a;
                    end

                    // --- Actual Addition/Subtraction ---
                    if (sign_a == sign_b) begin
                        // Same sign: Effective ADDITION
                        sum = aligned_a + aligned_b;
                        result_sign = sign_a;
                    end else begin
                        // Different signs: Effective SUBTRACTION
                        if (a_is_larger) begin
                            sum = aligned_a - aligned_b;
                            result_sign = sign_a;
                        end else begin
                            sum = aligned_b - aligned_a;
                            result_sign = sign_b;
                        end
                    end

                    // --- Normalization & Packing ---
                    if (sum == 7'b0) begin
                        // Result is zero (e.g., 5 + (-5))
                        result = 8'b0;
                        zero_flag = 1'b1;
                    end else begin
                        temp_exp = result_exp;
                        
                        // Check for mantissa overflow (e.g., 1.5 + 1.5 = 3.0)
                        // sum[5] is the bit position *above* the implicit '1'
                        if (sum[5]) begin
                            sum = sum >> 1;        // Shift right
                            temp_exp = temp_exp + 1; // Increment exponent
                        end
                        
                        // Check for mantissa underflow (e.g., 1.1 - 1.0 = 0.1)
                        // sum[4] is the implicit '1' bit position
                        while (!sum[4] && temp_exp > 0) begin
                            sum = sum << 1;        // Shift left
                            temp_exp = temp_exp - 1; // Decrement exponent
                        end
                        
                        // --- Final Exponent Check & Result Assembly ---
                        if (temp_exp > 7) begin
                            // Exponent Overflow
                            overflow = 1'b1;
                            // Return "infinity"
                            result = {result_sign, 3'b111, 4'b1111};
                        end else if (temp_exp <= 0 && !sum[4]) begin
                            // Exponent Underflow (result too small)
                            underflow = 1'b1;
                            // Return zero
                            result = {result_sign, 3'b000, 4'b0000};
                        end else begin
                            // Valid result
                            result = {result_sign, temp_exp[2:0], sum[3:0]};
                        end
                    end
                end
            end

            //===========================================
            // OPERATION: SUBTRACTION (op = 3'b001)
            //===========================================
            3'b001: begin
                // --- Handle special cases (zero) ---
                if (zero_a && zero_b) begin
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else if (zero_a) begin
                    // 0 - b = -b
                    result = {~b[7], b[6:0]}; // Flip b's sign
                end else if (zero_b) begin
                    // a - 0 = a
                    result = a;
                
                // --- Standard case (non-zero) ---
                end else begin
                    // Magnitude comparison (same as ADD)
                    if (exp_a > exp_b) begin
                        a_is_larger = 1'b1;
                    end else if (exp_a < exp_b) begin
                        a_is_larger = 1'b0;
                    end else begin
                        a_is_larger = (mant_a >= mant_b);
                    end
                    
                    // --- Mantissa Alignment (same as ADD) ---
                    exp_delta = exp_a - exp_b;
                    
                    if (exp_delta > 0) begin
                        aligned_a = {1'b0, mant_a};
                        aligned_b = (exp_delta >= 5) ? 6'b0 : ({1'b0, mant_b} >> exp_delta);
                        result_exp = exp_a;
                    end else if (exp_delta < 0) begin
                        aligned_a = ((-exp_delta) >= 5) ? 6'b0 : ({1'b0, mant_a} >> (-exp_delta));
                        aligned_b = {1'b0, mant_b};
                        result_exp = exp_b;
                    end else begin
                        aligned_a = {1'b0, mant_a};
                        aligned_b = {1'b0, mant_b};
                        result_exp = exp_a;
                    end

                    // --- Actual Addition/Subtraction (logic is flipped vs. ADD) ---
                    if (sign_a != sign_b) begin
                        // Different signs: Effective ADDITION (e.g., a - (-b) = a + b)
                        sum = aligned_a + aligned_b;
                        result_sign = sign_a;
                    end else begin
                        // Same signs: Effective SUBTRACTION (e.g., a - b)
                        if (a_is_larger) begin
                            sum = aligned_a - aligned_b;
                            result_sign = sign_a;
                        end else begin
                            sum = aligned_b - aligned_a;
                            result_sign = ~sign_a; // Result sign flips
                        end
                    end

                    // --- Normalization & Packing (same as ADD) ---
                    if (sum == 7'b0) begin
                        result = 8'b0;
                        zero_flag = 1'b1;
                    end else begin
                        temp_exp = result_exp;
                        
                        if (sum[5]) begin
                            sum = sum >> 1;
                            temp_exp = temp_exp + 1;
                        end
                        
                        while (!sum[4] && temp_exp > 0) begin
                            sum = sum << 1;
                            temp_exp = temp_exp - 1;
                        end
                        
                        if (temp_exp > 7) begin
                            overflow = 1'b1;
                            result = {result_sign, 3'b111, 4'b1111};
                        end else if (temp_exp <= 0 && !sum[4]) begin
                            underflow = 1'b1;
                            result = {result_sign, 3'b000, 4'b0000};
                        end else begin
                            result = {result_sign, temp_exp[2:0], sum[3:0]};
                        end
                    end
                end
            end

            //===========================================
            // OPERATION: MULTIPLICATION (op = 3'b010)
            //===========================================
            3'b010: begin
                // --- Handle special cases (zero) ---
                if (zero_a || zero_b) begin
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else begin
                    // --- Calculate Result Components ---
                    // Sign is XOR of input signs
                    result_sign = sign_a ^ sign_b;
                    
                    // Exponents are added, and one bias is removed
                    // (exp_a - 3) + (exp_b - 3) = (exp_a + exp_b - 3) - 3
                    temp_exp = exp_a + exp_b - 3; 
                    
                    // Multiply the 5-bit mantissas (1.xxxx * 1.xxxx)
                    // Result is 10 bits.
                    product = mant_a * mant_b;
                    
                    // --- Normalization ---
                    // The 5-bit * 5-bit product (1.xxxx * 1.xxxx) will be
                    // between 1.0 (10000 * 10000 = 01_0000_0000)
                    // and < 4.0 (11111 * 11111 = 11_1100_0001)
                    
                    if (product[9]) begin
                        // Result is in range [2.0, 4.0), e.g., 1x.xxxxxxxx
                        // Shift mantissa right by 1 bit
                        product = product >> 5; 
                        temp_exp = temp_exp + 1; // Increment exponent
                    end else if (product[8]) begin
                        // Result is in range [1.0, 2.0), e.g., 01.xxxxxxxx
                        // Shift mantissa right to align
                        product = product >> 4; 
                    end else begin
                        // This case should not be hit with normalized inputs,
                        // but handles potential < 1.0 results.
                        product = product >> 3;
                        temp_exp = temp_exp - 1;
                    end

                    // --- Final Exponent Check & Result Assembly ---
                    if (temp_exp > 7) begin
                        overflow = 1'b1;
                        result = {result_sign, 3'b111, 4'b1111};
                    end else if (temp_exp < 0) begin
                        underflow = 1'b1;
                        result = {result_sign, 3'b000, 4'b0000};
                    end else begin
                        // Pack the result
                        result = {result_sign, temp_exp[2:0], product[3:0]};
                    end
                end
            end

            //===========================================
            // OPERATION: DIVISION (op = 3'b011)
            //===========================================
            3'b011: begin
                // --- Handle special cases ---
                if (zero_b) begin
                    // Divide by zero
                    invalid_op = 1'b1;
                    overflow = 1'b1; // Division by zero returns "infinity"
                    result = {sign_a ^ sign_b, 3'b111, 4'b1111};
                end else if (zero_a) begin
                    // 0 / b = 0
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else begin
                    // --- Calculate Result Components ---
                    result_sign = sign_a ^ sign_b;
                    
                    // Exponents are subtracted, and one bias is added
                    // (exp_a - 3) - (exp_b - 3) = (exp_a - exp_b) + 3 - 3
                    temp_exp = exp_a - exp_b + 3;
                    
                    // Perform division: (1.xxxx) / (1.yyyy)
                    // Shift 'a' left by 4 bits to get 4 bits of fractional
                    // precision in the integer quotient.
                    product = (mant_a << 4) / mant_b;
                    
                    // --- Normalization ---
                    // The result (a/b) can be in range (0.5, 2.0)
                    // We need to find the leading '1' and shift.
                    if (product[5]) begin
                        // Result >= 2.0 (e.g., 1.111 / 1.000)
                        product = product >> 1;
                        // No temp_exp change, but this case is rare
                    end else if (product[4]) begin
                        // Result is in range [1.0, 2.0)
                        // Already normalized (1.xxxx)
                    end else if (product[3]) begin
                        // Result in range [0.5, 1.0)
                        product = product << 1;
                        temp_exp = temp_exp - 1;
                    end else if (product[2]) begin
                        product = product << 2;
                        temp_exp = temp_exp - 2;
                    end else if (product[1]) begin
                        product = product << 3;
                        temp_exp = temp_exp - 3;
                    end else begin
                        product = product << 4;
                        temp_exp = temp_exp - 4;
                    end

                    // --- Final Exponent Check & Result Assembly ---
                    if (temp_exp > 7) begin
                        overflow = 1'b1;
                        result = {result_sign, 3'b111, 4'b1111};
                    end else if (temp_exp < 0) begin
                        underflow = 1'b1;
                        result = {result_sign, 3'b000, 4'b0000};
                    end else begin
                        // Pack the result
                        result = {result_sign, temp_exp[2:0], product[3:0]};
                    end
                end
            end

            //===========================================
            // LOGICAL (BITWISE) OPERATIONS
            // These operate on the raw 8-bit patterns,
            // not the FP-decoded values.
            //===========================================
            3'b100: result = a & b; // Bitwise AND
            3'b101: result = a | b; // Bitwise OR
            3'b110: result = a ^ b; // Bitwise XOR
            3'b111: result = ~a;    // Bitwise NOT (only on 'a')

            //===========================================
            // DEFAULT (Invalid OP Code)
            //===========================================
            default: begin
                result = 8'b0;
                invalid_op = 1'b1;
            end
            
        endcase
    end // end always @(*)

endmodule
