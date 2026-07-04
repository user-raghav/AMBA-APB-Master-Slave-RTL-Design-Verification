

//==============================================================
// TEST_SCENARIOS.V
// Individual test tasks — each test is a separate task
// Include this file after tb_tasks.v
//==============================================================

//==============================================================
// TEST 1: Basic RAM Write/Read
//==============================================================
task test1_ram_basic;
    reg [7:0] rdata;
    reg       err;
    begin
        $display("\n--- TEST 1: Slave 0 (RAM) Basic Write/Read ---");

        apb_write(8'h02, 8'hAA, err);
        expected_ram[2] = 8'hAA;
        check_result(!err, "Write RAM[0x02]=0xAA");

        apb_read(8'h02, rdata, err);
        check_result((rdata == 8'hAA) && !err, "Read RAM[0x02]=0xAA");
    end
endtask

//==============================================================
// TEST 2: RAM Boundary Addresses
//==============================================================
task test2_ram_boundary;
    reg [7:0] rdata;
    reg       err;
    begin
        $display("\n--- TEST 2: Slave 0 (RAM) Boundary Addresses ---");

        apb_write(8'h00, 8'h10, err);
        expected_ram[0] = 8'h10;
        check_result(!err, "Write RAM[0x00]=0x10");

        apb_write(8'h07, 8'hFF, err);
        expected_ram[7] = 8'hFF;
        check_result(!err, "Write RAM[0x07]=0xFF (boundary)");

        apb_read(8'h00, rdata, err);
        check_result((rdata == 8'h10) && !err, "Read RAM[0x00]=0x10");

        apb_read(8'h07, rdata, err);
        check_result((rdata == 8'hFF) && !err, "Read RAM[0x07]=0xFF");
    end
endtask

//==============================================================
// TEST 3: Register File Instant Access
//==============================================================
task test3_reg_instant;
    reg [7:0] rdata;
    reg       err;
    begin
        $display("\n--- TEST 3: Slave 1 (Register) Instant Access ---");

        apb_write(8'h12, 8'h55, err);
        expected_reg[2] = 8'h55;
        check_result(!err, "Write REG[0x12]=0x55");

        apb_read(8'h12, rdata, err);
        check_result((rdata == 8'h55) && !err, "Read REG[0x12]=0x55");

        // Back-to-back writes
        apb_write(8'h10, 8'h01, err);
        expected_reg[0] = 8'h01;
        check_result(!err, "Write REG[0x10]=0x01");

        apb_write(8'h11, 8'h02, err);
        expected_reg[1] = 8'h02;
        check_result(!err, "Write REG[0x11]=0x02");

        apb_write(8'h13, 8'h03, err);
        expected_reg[3] = 8'h03;
        check_result(!err, "Write REG[0x13]=0x03");
    end
endtask

//==============================================================
// TEST 4: ROM Read-Only Operations
//==============================================================
task test4_rom_readonly;
    reg [7:0] rdata;
    reg       err;
    begin
        $display("\n--- TEST 4: Slave 2 (ROM) Read-Only ---");

        apb_read(8'h20, rdata, err);
        check_result((rdata == 8'h00) && !err, "Read ROM[0x20]=0x00");

        apb_read(8'h21, rdata, err);
        check_result((rdata == 8'h11) && !err, "Read ROM[0x21]=0x11");

        apb_read(8'h22, rdata, err);
        check_result((rdata == 8'h22) && !err, "Read ROM[0x22]=0x22");

        apb_read(8'h27, rdata, err);
        check_result((rdata == 8'h77) && !err, "Read ROM[0x27]=0x77 (boundary)");

        // Write attempt — MUST FAIL
        apb_write(8'h22, 8'hFF, err);
        check_result(err, "Write to ROM rejected with PSLVERR");

        // Verify ROM not corrupted
        apb_read(8'h22, rdata, err);
        check_result((rdata == 8'h22) && !err, "ROM[0x22] still 0x22 (not corrupted)");
    end
endtask

//==============================================================
// TEST 5: Invalid Address Errors
//==============================================================
task test5_invalid_address;
    reg [7:0] rdata;
    reg       err;
    begin
        $display("\n--- TEST 5: Invalid Address Handling ---");

        // Unmapped address (0x30+)
        apb_write(8'h35, 8'h00, err);
        check_result(err, "Invalid addr 0x35 rejected (Interconnect)");

        apb_read(8'h3F, rdata, err);
        check_result(err, "Invalid addr 0x3F read rejected");

        // RAM out-of-range (0x08 in Slave 0 range but mem only 8 deep)
        apb_write(8'h08, 8'h00, err);
        check_result(err, "RAM addr 0x08 (out of mem range) rejected");
    end
endtask

//==============================================================
// TEST 6: Reset During Transaction
// FIXED: Uses trigger_reset task, waits for transaction start
//==============================================================
task test6_reset_during_transaction;
    reg [7:0] rdata;
    reg       err;
    begin
        $display("\n--- TEST 6: Reset During Transaction ---");

        // Start a write but don't wait for completion
        wait(tb_cmd_ready);
        @(posedge PCLK);
        tb_cmd_addr  <= 8'h05;
        tb_cmd_wdata <= 8'hBE;
        tb_cmd_rw    <= 1'b1;
        tb_cmd_start <= 1;
        @(posedge PCLK);
        tb_cmd_start <= 0;

        // Wait one cycle to ensure we're in ACCESS phase
        @(posedge PCLK);

        // Trigger reset (uses task from tb_top.v)
        trigger_reset();

        // Verify RAM was zeroed by reset
        apb_read(8'h05, rdata, err);
        check_result((rdata == 8'h00) && !err, "RAM[0x05]=0x00 after reset");
    end
endtask

//==============================================================
// TEST 7: Cross-Slave Back-to-Back
//==============================================================
task test7_back_to_back;
    reg [7:0] rdata;
    reg       err;
    begin
        $display("\n--- TEST 7: Cross-Slave Back-to-Back ---");

        apb_write(8'h03, 8'hCC, err);
        expected_ram[3] = 8'hCC;
        check_result(!err, "Back-to-back: Write RAM[0x03]=0xCC");

        apb_write(8'h14, 8'hDD, err);
        expected_reg[4] = 8'hDD;
        check_result(!err, "Back-to-back: Write REG[0x14]=0xDD");

        apb_read(8'h03, rdata, err);
        check_result((rdata == 8'hCC) && !err, "Verify RAM[0x03]=0xCC");

        apb_read(8'h14, rdata, err);
        check_result((rdata == 8'hDD) && !err, "Verify REG[0x14]=0xDD");
    end
endtask

//==============================================================
// TEST 8: Random Stimulus
// FIXED: Added explicit error checking for invalid addresses
//==============================================================
task test8_random;
    reg [7:0] rdata;
    reg       err;
    reg [7:0] rand_addr;
    reg [7:0] rand_data;
    reg       rand_rw;
    integer   i;
    begin
        $display("\n--- TEST 8: Random Transactions (20 cycles) ---");

        for (i = 0; i < 20; i = i + 1) begin
            rand_addr = {$random} % 48;  // 0 to 47
            rand_data = {$random} % 256;
            rand_rw   = {$random} % 2;

            apb_transaction(rand_addr, rand_data, rand_rw, rdata, err);

            // Scoreboard check based on address region
            if (rand_addr < 8'h10) begin
                // Slave 0: RAM
                if (!err && rand_rw) expected_ram[rand_addr[2:0]] = rand_data;
                if (!err && !rand_rw) begin
                    check_result(rdata == expected_ram[rand_addr[2:0]],
                        $sformatf("Random RAM[%h]=%h", rand_addr, rdata));
                end
                if (err && !rand_rw) begin
                    // Read error — check if address is truly invalid
                    check_result(rand_addr >= 8'h08,
                        $sformatf("Random RAM[%h] read error expected", rand_addr));
                end
            end
            else if (rand_addr < 8'h20) begin
                // Slave 1: Register
                if (!err && rand_rw) expected_reg[rand_addr[2:0]] = rand_data;
                if (!err && !rand_rw) begin
                    check_result(rdata == expected_reg[rand_addr[2:0]],
                        $sformatf("Random REG[%h]=%h", rand_addr, rdata));
                end
            end
            else if (rand_addr < 8'h30) begin
                // Slave 2: ROM
                if (!err && !rand_rw) begin
                    check_result(rdata == expected_rom[rand_addr[2:0]],
                        $sformatf("Random ROM[%h]=%h", rand_addr, rdata));
                end
                if (!err && rand_rw) begin
                    // Write to ROM should always error!
                    check_result(1'b0,  // Force fail
                        $sformatf("Random ROM[%h] write should fail!", rand_addr));
                end
            end
            else begin
                // Invalid address region
                check_result(err,
                    $sformatf("Invalid addr %h rejected", rand_addr));
            end
        end
    end
endtask