`timescale 1ns/1ps

module apb_top (
    //----------------------------------------------------------
    // Clock and Reset
    //----------------------------------------------------------
    input  wire        PCLK,
    input  wire        PRESETn,

    //----------------------------------------------------------
    // Master Command Interface
    // (Testbench drives these to control the Master)
    //----------------------------------------------------------
    input  wire [7:0]  cmd_addr,
    input  wire [7:0]  cmd_wdata,
    input  wire        cmd_rw,       // 1=Write, 0=Read
    input  wire        cmd_start,    // Pulse to start transaction
    output wire        cmd_ready,    // Master can accept command
    output wire        cmd_done,     // Pulse when transaction completes
    output wire [7:0]  cmd_rdata,    // Data returned on read
    output wire        cmd_error     // PSLVERR captured
);

    //=========================================================================
    // Internal Wires Between Master and Interconnect
    //=========================================================================
    wire        m_PSEL;
    wire        m_PENABLE;
    wire        m_PWRITE;
    wire [7:0]  m_PADDR;
    wire [7:0]  m_PWDATA;
    wire [7:0]  m_PRDATA;
    wire        m_PREADY;
    wire        m_PSLVERR;

    //=========================================================================
    // Internal Wires Between Interconnect and Slaves
    //=========================================================================
    // Slave 0 (RAM)
    wire        s0_PSEL;
    wire        s0_PENABLE;
    wire        s0_PWRITE;
    wire [7:0]  s0_PADDR;
    wire [7:0]  s0_PWDATA;
    wire [7:0]  s0_PRDATA;
    wire        s0_PREADY;
    wire        s0_PSLVERR;

    // Slave 1 (Register)
    wire        s1_PSEL;
    wire        s1_PENABLE;
    wire        s1_PWRITE;
    wire [7:0]  s1_PADDR;
    wire [7:0]  s1_PWDATA;
    wire [7:0]  s1_PRDATA;
    wire        s1_PREADY;
    wire        s1_PSLVERR;

    // Slave 2 (ROM)
    wire        s2_PSEL;
    wire        s2_PENABLE;
    wire        s2_PWRITE;
    wire [7:0]  s2_PADDR;
    wire [7:0]  s2_PWDATA;
    wire [7:0]  s2_PRDATA;
    wire        s2_PREADY;
    wire        s2_PSLVERR;

    //=========================================================================
    // INSTANCE 1: APB MASTER
    //=========================================================================
    apb_master #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8)
    ) u_master (
        .PCLK      (PCLK),
        .PRESETn   (PRESETn),
        .cmd_addr  (cmd_addr),
        .cmd_wdata (cmd_wdata),
        .cmd_rw    (cmd_rw),
        .cmd_start (cmd_start),
        .cmd_ready (cmd_ready),
        .cmd_done  (cmd_done),
        .cmd_rdata (cmd_rdata),
        .cmd_error (cmd_error),
        .PSEL      (m_PSEL),
        .PENABLE   (m_PENABLE),
        .PWRITE    (m_PWRITE),
        .PADDR     (m_PADDR),
        .PWDATA    (m_PWDATA),
        .PRDATA    (m_PRDATA),
        .PREADY    (m_PREADY),
        .PSLVERR   (m_PSLVERR)
    );

    //=========================================================================
    // INSTANCE 2: APB INTERCONNECT / DECODER
    //=========================================================================
    apb_interconnect #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8)
    ) u_interconnect (
        // Master Interface
        .m_PSEL    (m_PSEL),
        .m_PENABLE (m_PENABLE),
        .m_PWRITE  (m_PWRITE),
        .m_PADDR   (m_PADDR),
        .m_PWDATA  (m_PWDATA),
        .m_PRDATA  (m_PRDATA),
        .m_PREADY  (m_PREADY),
        .m_PSLVERR (m_PSLVERR),

        // Slave 0 Interface (RAM)
        .s0_PSEL    (s0_PSEL),
        .s0_PENABLE (s0_PENABLE),
        .s0_PWRITE  (s0_PWRITE),
        .s0_PADDR   (s0_PADDR),
        .s0_PWDATA  (s0_PWDATA),
        .s0_PRDATA  (s0_PRDATA),
        .s0_PREADY  (s0_PREADY),
        .s0_PSLVERR (s0_PSLVERR),

        // Slave 1 Interface (Register)
        .s1_PSEL    (s1_PSEL),
        .s1_PENABLE (s1_PENABLE),
        .s1_PWRITE  (s1_PWRITE),
        .s1_PADDR   (s1_PADDR),
        .s1_PWDATA  (s1_PWDATA),
        .s1_PRDATA  (s1_PRDATA),
        .s1_PREADY  (s1_PREADY),
        .s1_PSLVERR (s1_PSLVERR),

        // Slave 2 Interface (ROM)
        .s2_PSEL    (s2_PSEL),
        .s2_PENABLE (s2_PENABLE),
        .s2_PWRITE  (s2_PWRITE),
        .s2_PADDR   (s2_PADDR),
        .s2_PWDATA  (s2_PWDATA),
        .s2_PRDATA  (s2_PRDATA),
        .s2_PREADY  (s2_PREADY),
        .s2_PSLVERR (s2_PSLVERR)
    );

    //=========================================================================
    // INSTANCE 3: SLAVE 0 — RAM (N=4 wait states)
    //=========================================================================
    apb_slave_ram #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8),
        .MEM_DEPTH (8),
        .N         (4)
    ) u_slave0_ram (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PSEL    (s0_PSEL),
        .PENABLE (s0_PENABLE),
        .PWRITE  (s0_PWRITE),
        .PADDR   (s0_PADDR),
        .PWDATA  (s0_PWDATA),
        .PRDATA  (s0_PRDATA),
        .PREADY  (s0_PREADY),
        .PSLVERR (s0_PSLVERR)
    );

    //=========================================================================
    // INSTANCE 4: SLAVE 1 — REGISTER FILE (N=0, instant ready)
    //=========================================================================
    apb_slave_reg #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8),
        .MEM_DEPTH (8)
    ) u_slave1_reg (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PSEL    (s1_PSEL),
        .PENABLE (s1_PENABLE),
        .PWRITE  (s1_PWRITE),
        .PADDR   (s1_PADDR),
        .PWDATA  (s1_PWDATA),
        .PRDATA  (s1_PRDATA),
        .PREADY  (s1_PREADY),
        .PSLVERR (s1_PSLVERR)
    );

    //=========================================================================
    // INSTANCE 5: SLAVE 2 — ROM (N=2, read-only)
    //=========================================================================
    apb_slave_rom #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8),
        .MEM_DEPTH (8),
        .N         (2)
    ) u_slave2_rom (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PSEL    (s2_PSEL),
        .PENABLE (s2_PENABLE),
        .PWRITE  (s2_PWRITE),
        .PADDR   (s2_PADDR),
        .PRDATA  (s2_PRDATA),
        .PREADY  (s2_PREADY),
        .PSLVERR (s2_PSLVERR)
    );

endmodule