`timescale 1ns/1ps

//==============================================================
// APB_PROTOCOL_CHECKER.V
// Monitors APB bus and flags protocol violations
// Pure Verilog (no SVA)
//==============================================================

module apb_protocol_checker (
    input wire        PCLK,
    input wire        PRESETn,
    
    // APB Bus signals
    input wire        PSEL,
    input wire        PENABLE,
    input wire        PWRITE,
    input wire [7:0]  PADDR,
    input wire [7:0]  PWDATA,
    input wire [7:0]  PRDATA,
    input wire        PREADY,
    input wire        PSLVERR
);

    //=========================================================================
    // Previous cycle samples
    //=========================================================================
    reg        prev_PSEL;
    reg        prev_PENABLE;
    reg [7:0]  prev_PADDR;
    reg        prev_PWRITE;
    reg [7:0]  prev_PWDATA;
    reg [7:0]  prev_PRDATA;  // Moved here from bottom

    //=========================================================================
    // Error flags
    //=========================================================================
    reg        error_PENABLE_without_PSEL;
    reg        error_addr_change_during_access;
    reg        error_pwrite_change_during_access;
    reg        error_pslverr_without_pready;
    reg        error_prdata_change_during_access;  // Renamed for clarity

    //=========================================================================
    // Update previous cycle samples
    //=========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            prev_PSEL    <= 0;
            prev_PENABLE <= 0;
            prev_PADDR   <= 0;
            prev_PWRITE  <= 0;
            prev_PWDATA  <= 0;
            prev_PRDATA  <= 0;
        end else begin
            prev_PSEL    <= PSEL;
            prev_PENABLE <= PENABLE;
            prev_PADDR   <= PADDR;
            prev_PWRITE  <= PWRITE;
            prev_PWDATA  <= PWDATA;
            prev_PRDATA  <= PRDATA;
        end
    end

    //=========================================================================
    // CHECK 1: PENABLE can only go high if PSEL was high last cycle
    //=========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            error_PENABLE_without_PSEL <= 0;
        end else begin
            // Use !== to catch X propagation; ignore X at startup
            if (PENABLE === 1'b1 && prev_PSEL !== 1'b1) begin
                error_PENABLE_without_PSEL <= 1;
                $display("[PROTOCOL ERROR] PENABLE=1 without PSEL=1 in previous cycle at time %0t", $time);
            end else begin
                error_PENABLE_without_PSEL <= 0;
            end
        end
    end

    //=========================================================================
    // CHECK 2: PADDR must remain stable during ACCESS phase (PENABLE=1, PREADY=0)
    //=========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            error_addr_change_during_access <= 0;
        end else begin
            // Only check during true ACCESS wait states
            if (PSEL === 1'b1 && PENABLE === 1'b1 && PREADY === 1'b0 && (PADDR !== prev_PADDR)) begin
                error_addr_change_during_access <= 1;
                $display("[PROTOCOL ERROR] PADDR changed during ACCESS wait at time %0t", $time);
            end else begin
                error_addr_change_during_access <= 0;
            end
        end
    end

    //=========================================================================
    // CHECK 3: PWRITE must remain stable during ACCESS phase
    //=========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            error_pwrite_change_during_access <= 0;
        end else begin
            if (PSEL === 1'b1 && PENABLE === 1'b1 && PREADY === 1'b0 && (PWRITE !== prev_PWRITE)) begin
                error_pwrite_change_during_access <= 1;
                $display("[PROTOCOL ERROR] PWRITE changed during ACCESS wait at time %0t", $time);
            end else begin
                error_pwrite_change_during_access <= 0;
            end
        end
    end

    //=========================================================================
    // CHECK 4: PSLVERR is only valid when PREADY is high
    //=========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            error_pslverr_without_pready <= 0;
        end else begin
            if (PSLVERR === 1'b1 && PREADY !== 1'b1) begin
                error_pslverr_without_pready <= 1;
                $display("[PROTOCOL ERROR] PSLVERR=1 without PREADY=1 at time %0t", $time);
            end else begin
                error_pslverr_without_pready <= 0;
            end
        end
    end

    //=========================================================================
    // CHECK 5: PRDATA should only change when PREADY is high (during read)
    // FIXED: Only check during true ACCESS phase, not during SETUP
    //=========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            error_prdata_change_during_access <= 0;
        end else begin
            // Only flag if: PSEL=1, PENABLE=1 (true ACCESS), PREADY=0 (wait state), 
            // PWRITE=0 (read), and PRDATA changed
            if (PSEL === 1'b1 && PENABLE === 1'b1 && PREADY === 1'b0 && 
                PWRITE === 1'b0 && (PRDATA !== prev_PRDATA)) begin
                error_prdata_change_during_access <= 1;
                $display("[PROTOCOL ERROR] PRDATA changed during ACCESS wait at time %0t", $time);
            end else begin
                error_prdata_change_during_access <= 0;
            end
        end
    end

endmodule