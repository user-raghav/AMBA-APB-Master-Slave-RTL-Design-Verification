

//==============================================================
// TB_TASKS.V
// Reusable APB transaction tasks and scoreboard
// NOTE: This file is designed to be `included inside a module
//       where PCLK and PRESETn are already declared.
//==============================================================

// Global command interface signals (driven by tasks, connected to DUT)
reg [7:0] tb_cmd_addr;
reg [7:0] tb_cmd_wdata;
reg tb_cmd_rw;
reg tb_cmd_start;
wire tb_cmd_ready;
wire tb_cmd_done;
wire [7:0] tb_cmd_rdata;
wire tb_cmd_error;

// Scoreboard: Expected memory models
reg [7:0] expected_ram [0:7];
reg [7:0] expected_reg [0:7];
reg [7:0] expected_rom [0:7];  // Read-only, never changes after init

// Test statistics
integer pass_count = 0;
integer fail_count = 0;
integer test_num   = 0;

//==============================================================
// TASK: Initialize scoreboard and ROM pattern
//==============================================================
task init_scoreboard;
    integer i;
    begin
        for (i = 0; i < 8; i = i + 1) begin
            expected_ram[i] = 0;
            expected_reg[i] = 0;
            expected_rom[i] = i * 8'h11;  // Pre-loaded ROM pattern: 0x00, 0x11, 0x22...
        end
    end
endtask

//==============================================================
// TASK: Reset scoreboard (after DUT reset)
// NOTE: ROM is NOT reset — it's read-only
//==============================================================
task reset_scoreboard;
    integer i;
    begin
        for (i = 0; i < 8; i = i + 1) begin
            expected_ram[i] = 0;
            expected_reg[i] = 0;
            // expected_rom[i] is NOT reset — read-only!
        end
    end
endtask

//==============================================================
// TASK: Single APB transaction (Write or Read)
//==============================================================
task apb_transaction;
    input  [7:0] addr;
    input  [7:0] wdata;
    input        rw;        // 1=Write, 0=Read
    output [7:0] rdata;
    output       error;
    begin
        // Wait until Master is ready
        wait(tb_cmd_ready);

        @(posedge PCLK);
        tb_cmd_addr  <= addr;
        tb_cmd_wdata <= wdata;
        tb_cmd_rw    <= rw;
        tb_cmd_start <= 1;

        @(posedge PCLK);
        tb_cmd_start <= 0;

        // Wait for transaction complete
        wait(tb_cmd_done);

        // Capture results
        rdata = tb_cmd_rdata;
        error = tb_cmd_error;

        @(posedge PCLK);
    end
endtask 

//==============================================================
// TASK: APB Write (convenience wrapper)
//==============================================================
task apb_write;
    input  [7:0] addr;
    input  [7:0] data;
    output       error;
    reg [7:0] dummy_rdata;
    begin
        apb_transaction(addr, data, 1'b1, dummy_rdata, error);
    end
endtask

//==============================================================
// TASK: APB Read (convenience wrapper)
//==============================================================
task apb_read;
    input  [7:0] addr;
    output [7:0] data;
    output       error;
    begin
        apb_transaction(addr, 8'h00, 1'b0, data, error);
    end
endtask


//==============================================================
// TASK: Check result and log pass/fail
//==============================================================
task check_result;
    input        condition;
    input string msg; // <--- Change [255:0] to string here!
    begin
        test_num = test_num + 1;
        if (condition) begin
            pass_count = pass_count + 1;
            $display("[PASS] Test %0d: %0s", test_num, msg);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] Test %0d: %0s", test_num, msg);
        end
    end
endtask

//==============================================================
// TASK: Trigger DUT reset (for tests that need mid-transaction reset)
// Call this instead of driving PRESETn directly to avoid multi-driver
//==============================================================
// task trigger_reset;
//     begin
//         // NOTE: This task must be called from tb_top where PRESETn is accessible
//         // Due to `include, PRESETn is visible here
//         PRESETn = 0;
//         #15;
//         PRESETn = 1;
//         reset_scoreboard();
//         // Clear command interface to avoid stale values
//         tb_cmd_addr  <= 0;
//         tb_cmd_wdata <= 0;
//         tb_cmd_rw    <= 0;
//         tb_cmd_start <= 0;
//     end
// endtask

//==============================================================
// TASK: Print final test summary
//==============================================================
task print_summary;
    begin
        $display("\n============================================================");
        $display("           APB SYSTEM VERIFICATION COMPLETE");
        $display("============================================================");
        $display("Total Tests:  %0d", test_num);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        if (test_num > 0)
            $display("Success Rate: %0d%%", (pass_count * 100) / test_num);
        $display("============================================================");
        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", fail_count);
        $display("============================================================\n");
    end
endtask