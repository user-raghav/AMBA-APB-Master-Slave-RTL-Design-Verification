`timescale 1ns/1ps

//==============================================================
// TB_TOP.V
// Top-level testbench — instantiates DUT, protocol checker,
// and runs all test scenarios
//==============================================================


module tb_top;

 //=========================================================================
    // Clock and Reset
    // NOTE: PRESETn is driven ONLY here — no other driver
    //=========================================================================
    reg PCLK = 0;
    always #5 PCLK = ~PCLK;  // 100MHz

// Include order matters: tb_tasks first (defines tasks used by test_scenarios)
`include "tb_tasks.v"
`include "test_scenarios.v"


   

    reg PRESETn;
    initial begin
        PRESETn = 0;
        #25 PRESETn = 1;
    end

    //=========================================================================
    // DUT Instantiation (apb_top)
    //=========================================================================
    apb_top u_dut (
        .PCLK      (PCLK),
        .PRESETn   (PRESETn),
        .cmd_addr  (tb_cmd_addr),
        .cmd_wdata (tb_cmd_wdata),
        .cmd_rw    (tb_cmd_rw),
        .cmd_start (tb_cmd_start),
        .cmd_ready (tb_cmd_ready),
        .cmd_done  (tb_cmd_done),
        .cmd_rdata (tb_cmd_rdata),
        .cmd_error (tb_cmd_error)
    );

    //=========================================================================
    // Protocol Checker Instantiation
    // FIXED: Use internal signals instead of hierarchical references
    // Create a wrapper or expose signals from apb_top
    // Alternative: Instantiate checker inside apb_top (cleaner)
    // 
    // For now, using hierarchical access with warning:
    // This works in simulation but is not synthesizable
    //=========================================================================
    // NOTE: Hierarchical references below. For cleaner design, add APB monitor
    // ports to apb_top module.
    apb_protocol_checker u_checker (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PSEL    (u_dut.u_master.PSEL),
        .PENABLE (u_dut.u_master.PENABLE),
        .PWRITE  (u_dut.u_master.PWRITE),
        .PADDR   (u_dut.u_master.PADDR),
        .PWDATA  (u_dut.u_master.PWDATA),
        .PRDATA  (u_dut.u_master.PRDATA),
        .PREADY  (u_dut.u_master.PREADY),
        .PSLVERR (u_dut.u_master.PSLVERR)
    );

    //=========================================================================
    // Waveform Dump
    //=========================================================================
    initial begin
        $dumpfile("apb_top.vcd");
        $dumpvars(0, tb_top);
    end

    task trigger_reset;
    begin
        // NOTE: This task must be called from tb_top where PRESETn is accessible
        // Due to `include, PRESETn is visible here
        PRESETn = 0;
        #15;
        PRESETn = 1;
        reset_scoreboard();
        // Clear command interface to avoid stale values
        tb_cmd_addr  <= 0;
        tb_cmd_wdata <= 0;
        tb_cmd_rw    <= 0;
        tb_cmd_start <= 0;
    end
    endtask

    //=========================================================================
    // Main Test Sequence
    //=========================================================================
    initial begin
        // Initialize command interface
        tb_cmd_addr  = 0;
        tb_cmd_wdata = 0;
        tb_cmd_rw    = 0;
        tb_cmd_start = 0;

        init_scoreboard();

        // Wait for reset
        @(posedge PRESETn);
        @(posedge PCLK);

        $display("\n============================================================");
        $display("           APB SYSTEM VERIFICATION START");
        $display("============================================================");

        // Run all test scenarios
        test1_ram_basic;
        test2_ram_boundary;
        test3_reg_instant;
        test4_rom_readonly;
        test5_invalid_address;
        test6_reset_during_transaction;
        test7_back_to_back;
        test8_random;

        // Print summary
        print_summary;

        #50;
        $finish;
    end

endmodule