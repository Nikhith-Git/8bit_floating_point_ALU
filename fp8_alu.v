//============================================================
// 8-bit Floating Point ALU with Enhanced Features
// Designer: Nikhith
// Format: IEEE-like [7]=sign, [6:4]=exponent (bias=3), [3:0]=mantissa
// 
// Operations:
//   000 = ADD    | 001 = SUB    | 010 = MUL    | 011 = DIV
//   100 = AND    | 101 = OR     | 110 = XOR    | 111 = NOT
//
// Features:
//   - Proper normalization and rounding
//   - Special value handling (zero, overflow, underflow)
//   - Denormalized number support
//   - Sticky bit for improved rounding accuracy
//   - Exception flags (overflow, underflow, invalid operation)
//============================================================

module fp8_alu (
    input  wire [7:0] a,           // First operand
    input  wire [7:0] b,           // Second operand
    input  wire [2:0] op,          // Operation selector
    output reg  [7:0] result,      // Result
    output reg        overflow,    // Overflow flag
    output reg        underflow,   // Underflow flag
    output reg        zero_flag,   // Result is zero
    output reg        invalid_op   // Invalid operation (e.g., 0/0)
);

    //========================================
    // Field Extraction
    //========================================
    wire sign_a    = a[7];
    wire sign_b    = b[7];
    wire [2:0] exp_a  = a[6:4];
    wire [2:0] exp_b  = b[6:4];
    wire [3:0] frac_a = a[3:0];
    wire [3:0] frac_b = b[3:0];

    // Check for zero operands (exp=0, frac=0)
    wire is_zero_a = (a[6:0] == 7'b0);
    wire is_zero_b = (b[6:0] == 7'b0);

    //========================================
    // Mantissa Construction with Hidden Bit
    //========================================
    // For normalized: 1.fraction (hidden bit = 1)
    // For denormalized: 0.fraction (hidden bit = 0)
    wire [7:0] mant_a = (exp_a == 3'b0) ? {4'b0000, frac_a} : {1'b1, frac_a, 3'b000};
    wire [7:0] mant_b = (exp_b == 3'b0) ? {4'b0000, frac_b} : {1'b1, frac_b, 3'b000};

    //========================================
    // Internal Computation Variables
    //========================================
    integer exp_diff;
    reg [7:0] mant_a_aligned, mant_b_aligned;
    reg [2:0] exp_common;
    reg [2:0] exp_result;
    reg sign_result;
    reg [15:0] mant_product;      // For multiplication
    reg [9:0] mant_sum;           // Extended for add/sub
    reg [3:0] shift_amount;
    reg sticky_bit;               // For rounding
    reg guard_bit, round_bit;

    //========================================
    // Main ALU Operation Logic
    //========================================
    always @(*) begin
        // Default flag values
        overflow   = 1'b0;
        underflow  = 1'b0;
        zero_flag  = 1'b0;
        invalid_op = 1'b0;
        sticky_bit = 1'b0;

        case (op)
            //===========================================
            // ADDITION: a + b
            //===========================================
            3'b000: begin
                // Handle special cases
                if (is_zero_a && is_zero_b) begin
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else if (is_zero_a) begin
                    result = b;
                end else if (is_zero_b) begin
                    result = a;
                end else begin
                    // Align mantissas by equalizing exponents
                    exp_diff = $signed(exp_a) - $signed(exp_b);
                    
                    if (exp_diff > 0) begin
                        mant_a_aligned = mant_a;
                        mant_b_aligned = mant_b >> exp_diff;
                        exp_common = exp_a;
                        // Track bits shifted out for rounding
                        if (exp_diff > 0 && exp_diff < 8)
                            sticky_bit = |(mant_b & ((1 << exp_diff) - 1));
                    end else if (exp_diff < 0) begin
                        mant_a_aligned = mant_a >> (-exp_diff);
                        mant_b_aligned = mant_b;
                        exp_common = exp_b;
                        if (exp_diff < 0 && exp_diff > -8)
                            sticky_bit = |(mant_a & ((1 << (-exp_diff)) - 1));
                    end else begin
                        mant_a_aligned = mant_a;
                        mant_b_aligned = mant_b;
                        exp_common = exp_a;
                    end

                    // Perform signed addition
                    mant_sum = (sign_a ? -$signed({1'b0, mant_a_aligned}) : {1'b0, mant_a_aligned})
                             + (sign_b ? -$signed({1'b0, mant_b_aligned}) : {1'b0, mant_b_aligned});

                    sign_result = mant_sum[9];
                    
                    // Handle negative result
                    if (sign_result)
                        mant_sum = -mant_sum;

                    // Normalize: shift left until MSB is 1
                    exp_result = exp_common;
                    
                    if (mant_sum == 10'b0) begin
                        result = 8'b0;
                        zero_flag = 1'b1;
                    end else if (mant_sum[8]) begin
                        // Overflow: shift right
                        mant_sum = mant_sum >> 1;
                        exp_result = exp_common + 1;
                        if (exp_result > 7) overflow = 1'b1;
                    end else begin
                        // Shift left to normalize
                        while (mant_sum[7] == 0 && exp_result > 0 && mant_sum != 0) begin
                            mant_sum = mant_sum << 1;
                            exp_result = exp_result - 1;
                        end
                        if (exp_result == 0) underflow = 1'b1;
                    end

                    // Round to nearest (using guard/round/sticky bits)
                    if (mant_sum[2] && (mant_sum[3] || sticky_bit || mant_sum[1:0] != 0))
                        mant_sum = mant_sum + 4;

                    result = {sign_result, exp_result[2:0], mant_sum[6:3]};
                end
            end

            //===========================================
            // SUBTRACTION: a - b
            //===========================================
            3'b001: begin
                // Flip sign of b and perform addition
                if (is_zero_a && is_zero_b) begin
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else if (is_zero_a) begin
                    result = {~b[7], b[6:0]};  // -b
                end else if (is_zero_b) begin
                    result = a;
                end else begin
                    exp_diff = $signed(exp_a) - $signed(exp_b);
                    
                    if (exp_diff > 0) begin
                        mant_a_aligned = mant_a;
                        mant_b_aligned = mant_b >> exp_diff;
                        exp_common = exp_a;
                    end else if (exp_diff < 0) begin
                        mant_a_aligned = mant_a >> (-exp_diff);
                        mant_b_aligned = mant_b;
                        exp_common = exp_b;
                    end else begin
                        mant_a_aligned = mant_a;
                        mant_b_aligned = mant_b;
                        exp_common = exp_a;
                    end

                    // Signed subtraction (flip sign of b)
                    mant_sum = (sign_a ? -$signed({1'b0, mant_a_aligned}) : {1'b0, mant_a_aligned})
                             - (sign_b ? -$signed({1'b0, mant_b_aligned}) : {1'b0, mant_b_aligned});

                    sign_result = mant_sum[9];
                    if (sign_result)
                        mant_sum = -mant_sum;

                    exp_result = exp_common;
                    
                    if (mant_sum == 10'b0) begin
                        result = 8'b0;
                        zero_flag = 1'b1;
                    end else if (mant_sum[8]) begin
                        mant_sum = mant_sum >> 1;
                        exp_result = exp_common + 1;
                        if (exp_result > 7) overflow = 1'b1;
                    end else begin
                        while (mant_sum[7] == 0 && exp_result > 0 && mant_sum != 0) begin
                            mant_sum = mant_sum << 1;
                            exp_result = exp_result - 1;
                        end
                        if (exp_result == 0) underflow = 1'b1;
                    end

                    result = {sign_result, exp_result[2:0], mant_sum[6:3]};
                end
            end

            //===========================================
            // MULTIPLICATION: a × b
            //===========================================
            3'b010: begin
                if (is_zero_a || is_zero_b) begin
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else begin
                    sign_result = sign_a ^ sign_b;
                    
                    // Add exponents and subtract bias
                    exp_result = exp_a + exp_b - 3;
                    
                    // Multiply mantissas (5 bits × 5 bits = 10 bits)
                    mant_product = mant_a * mant_b;
                    
                    // Normalize: product is in range [1.0, 4.0)
                    if (mant_product[15:14] != 0) begin
                        mant_product = mant_product >> 8;
                        exp_result = exp_result + 1;
                    end else if (mant_product[13]) begin
                        mant_product = mant_product >> 7;
                    end else begin
                        mant_product = mant_product >> 6;
                        exp_result = exp_result - 1;
                    end

                    // Check for overflow/underflow
                    if (exp_result > 7) begin
                        overflow = 1'b1;
                        result = {sign_result, 3'b111, 4'b1111}; // Max value
                    end else if ($signed(exp_result) < 0) begin
                        underflow = 1'b1;
                        result = {sign_result, 3'b000, 4'b0000}; // Min value
                    end else begin
                        result = {sign_result, exp_result[2:0], mant_product[6:3]};
                    end
                end
            end

            //===========================================
            // DIVISION: a ÷ b
            //===========================================
            3'b011: begin
                if (is_zero_b) begin
                    invalid_op = 1'b1;
                    overflow = 1'b1;
                    result = {sign_a ^ sign_b, 3'b111, 4'b1111}; // Infinity
                end else if (is_zero_a) begin
                    result = 8'b0;
                    zero_flag = 1'b1;
                end else begin
                    sign_result = sign_a ^ sign_b;
                    
                    // Subtract exponents and add bias
                    exp_result = exp_a - exp_b + 3;
                    
                    // Divide mantissas with scaling
                    mant_product = (mant_a << 8) / mant_b;
                    
                    // Normalize result
                    if (mant_product[15]) begin
                        mant_product = mant_product >> 8;
                        exp_result = exp_result + 1;
                    end else if (mant_product[14]) begin
                        mant_product = mant_product >> 7;
                    end else begin
                        mant_product = mant_product >> 6;
                        exp_result = exp_result - 1;
                    end

                    // Check bounds
                    if (exp_result > 7) begin
                        overflow = 1'b1;
                        result = {sign_result, 3'b111, 4'b1111};
                    end else if ($signed(exp_result) < 0) begin
                        underflow = 1'b1;
                        result = {sign_result, 3'b000, 4'b0000};
                    end else begin
                        result = {sign_result, exp_result[2:0], mant_product[6:3]};
                    end
                end
            end

            //===========================================
            // BITWISE LOGICAL OPERATIONS
            //===========================================
            3'b100: result = a & b;     // AND
            3'b101: result = a | b;     // OR
            3'b110: result = a ^ b;     // XOR
            3'b111: result = ~a;        // NOT

            default: begin
                result = 8'b0;
                invalid_op = 1'b1;
            end
        endcase
    end

endmodule
