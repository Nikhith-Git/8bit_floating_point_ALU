# **8-bit Floating Point ALU (FP8 ALU)**

A compact, feature-rich Arithmetic Logic Unit designed using a custom **8-bit floating-point format**:
`[7] = Sign | [6:4] = Exponent (Bias = 3) | [3:0] = Mantissa`

This repository contains:
✔ FP8 ALU Verilog RTL
✔ Advanced exception handling
✔ Support for ADD, SUB, MUL, DIV, AND, OR, XOR, NOT
✔ Full testbench with real-value conversion & auto-validation

---

## **📌 FP8 Number Format**

```
+-----+-----------+-----------+
| Bit | 7         | 6 5 4     | 3 2 1 0 |
+-----+-----------+-----------+---------+
| Use | Sign (S)  | Exponent  | Mantissa |
+-----+-----------+-----------+---------+

Exponent Bias = 3  
Value = (–1)^S × (1.mantissa) × 2^(Exponent – Bias)
For denormalized numbers (Exponent = 0):
Value = (–1)^S × (0.mantissa) × 2^(1 – Bias)
```

---

# **🚀 Advanced FP8 ALU – Features**

## **1. Enhanced Architecture**

* ✔ **Exception Flags**

  * `overflow`
  * `underflow`
  * `zero_flag`
  * `invalid_op`
* ✔ **Special case detection:** IEEE-style handling of zero
* ✔ **Denormalized number support** (hidden bit = 0)
* ✔ **Cleaner RTL structure**

---

## **2. Improved Normalization Logic**

* Dynamic **left shifting** until MSB becomes `1`
* Exponent grows/shrinks accordingly
* Overflow / Underflow detection after normalization
* **Guard / round / sticky bit** rounding similar to IEEE-754

---

## **3. Operation Enhancements**

### **Addition / Subtraction**

* Proper exponent alignment
* Sticky bit tracking
* Handles opposite-sign subtraction correctly
* Fully normalized output

### **Multiplication**

* Zero detection
* Normalizes based on highest product bit
* Automatic saturation on overflow

### **Division**

* Detects **divide by zero** → raises `invalid_op`
* Returns IEEE-like “infinity” representation
* Correct exponent scaling

### **Logical Operations**

* AND
* OR
* XOR
* NOT

---

# **🧪 Advanced Testbench**

### **✔ Comprehensive Testing**

* Automatic calculation of **expected real output**
* **Relative error computation**
* **PASS / FAIL** marking based on tolerance
* Tracks:

  * Total tests
  * Passed tests
  * Failed tests
  * Average error
  * Maximum error

---

## **✔ Real-Value Conversion Functions**

### **`fp8_to_real()`**

Converts FP8 → actual real number
Handles:

* Zero
* Normal numbers
* Denormalized numbers

### **`real_to_fp8()`**

Converts real number → FP8

* Normalizes into `[1.0, 2.0)` range
* Extracts 4-bit mantissa

---

## **✔ Test Coverage**

### **Edge Cases**

* Zero operands
* Same sign / opposite sign
* Division by zero
* Overflow / underflow conditions

### **Stress Tests**

* 20 random values per operation
* Catches corner cases

### **Logical Tests**

* Performs AND, OR, XOR, NOT
* Exact binary comparison

---

# **📁 File Structure**

```
fp8_alu.v          → Main ALU module
tb_fp8.v           → Advanced testbench
README.md          → Documentation
```

---

# **🛠 Example Commands**

### **Compile**

```sh
iverilog -o fp8 tb_fp8.v fp8_alu.v
```

### **Run**

```sh
vvp fp8
```

### **Open Waveform**

```sh
gtkwave fp8.vcd
```

---

# **📌 Key Differences (Original vs Advanced)**

| Feature          | Original       | Advanced                      |
| ---------------- | -------------- | ----------------------------- |
| Error Handling   | ❌ None         | ✔ 4 exception flags           |
| Denormal Support | ❌ No           | ✔ Full                        |
| Normalization    | Fixed          | Dynamic MSB alignment         |
| Rounding         | Truncate       | Guard / Round / Sticky        |
| Division         | Basic          | Div-by-zero handling          |
| Special Cases    | Minimal        | Zero, Inf, NaN-like           |
| Testbench        | 8 static cases | 50+ auto-validated tests      |
| Logging          | Basic          | Pass/Fail, error stats, flags |

---

# **📜 License**

This project is open-source. Feel free to use it for academic or research purposes.

---

If you want, I can also:
✅ Format it with emojis
✅ Add images / diagrams
✅ Create GitHub badges
✅ Generate a full **Wiki page**
Just tell me!
