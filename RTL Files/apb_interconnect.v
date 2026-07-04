module apb_interconnect #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8
)(
    //----------------------------------------------------------
    // Master Interface
    //----------------------------------------------------------
    input  wire                  m_PSEL,
    input  wire                  m_PENABLE,
    input  wire                  m_PWRITE,
    input  wire [ADDR_WIDTH-1:0] m_PADDR,
    input  wire [DATA_WIDTH-1:0] m_PWDATA,
    output reg  [DATA_WIDTH-1:0] m_PRDATA,
    output reg                   m_PREADY,
    output reg                   m_PSLVERR,

    //----------------------------------------------------------
    // Slave 0 Interface (RAM - 0x00 to 0x0F)
    //----------------------------------------------------------
    output wire                  s0_PSEL,
    output wire                  s0_PENABLE,
    output wire                  s0_PWRITE,
    output wire [ADDR_WIDTH-1:0] s0_PADDR,
    output wire [DATA_WIDTH-1:0] s0_PWDATA,
    input  wire [DATA_WIDTH-1:0] s0_PRDATA,
    input  wire                  s0_PREADY,
    input  wire                  s0_PSLVERR,

    //----------------------------------------------------------
    // Slave 1 Interface (Register File - 0x10 to 0x1F)
    //----------------------------------------------------------
    output wire                  s1_PSEL,
    output wire                  s1_PENABLE,
    output wire                  s1_PWRITE,
    output wire [ADDR_WIDTH-1:0] s1_PADDR,
    output wire [DATA_WIDTH-1:0] s1_PWDATA,
    input  wire [DATA_WIDTH-1:0] s1_PRDATA,
    input  wire                  s1_PREADY,
    input  wire                  s1_PSLVERR,

    //----------------------------------------------------------
    // Slave 2 Interface (ROM - 0x20 to 0x2F)
    //----------------------------------------------------------
    output wire                  s2_PSEL,
    output wire                  s2_PENABLE,
    output wire                  s2_PWRITE,
    output wire [ADDR_WIDTH-1:0] s2_PADDR,
    output wire [DATA_WIDTH-1:0] s2_PWDATA,
    input  wire [DATA_WIDTH-1:0] s2_PRDATA,
    input  wire                  s2_PREADY,
    input  wire                  s2_PSLVERR
);

    //=========================================================================
    // SECTION 1: BROADCAST
    //=========================================================================
    // Fan out Master's control/data signals to ALL slaves.
    // Only the selected slave (via PSEL) will act on them.
    //=========================================================================

    assign s0_PENABLE = m_PENABLE;
    assign s0_PWRITE  = m_PWRITE;
    assign s0_PADDR   = m_PADDR;
    assign s0_PWDATA  = m_PWDATA;

    assign s1_PENABLE = m_PENABLE;
    assign s1_PWRITE  = m_PWRITE;
    assign s1_PADDR   = m_PADDR;
    assign s1_PWDATA  = m_PWDATA;

    assign s2_PENABLE = m_PENABLE;
    assign s2_PWRITE  = m_PWRITE;
    assign s2_PADDR   = m_PADDR;
    assign s2_PWDATA  = m_PWDATA;

    //=========================================================================
    // SECTION 2: ADDRESS DECODER
    //=========================================================================
    // Uses upper nibble of PADDR. m_PSEL acts as enable.
    // If m_PSEL=0, all slave PSELs are 0 (no slave selected).
    //=========================================================================

    // [FIXED] Use ADDR_WIDTH-1 instead of hardcoded 7
    assign s0_PSEL = m_PSEL && (m_PADDR[ADDR_WIDTH-1:4] == 4'h0);
    assign s1_PSEL = m_PSEL && (m_PADDR[ADDR_WIDTH-1:4] == 4'h1);
    assign s2_PSEL = m_PSEL && (m_PADDR[ADDR_WIDTH-1:4] == 4'h2);

    //=========================================================================
    // SECTION 3: RESPONSE MULTIPLEXER (MUX)
    //=========================================================================
    // Forwards the selected slave's response to the Master.
    //
    // [FIXED] Added explicit !m_PSEL check at the top. When the bus is idle,
    // drive PREADY=0 and PSLVERR=0. Only use the error terminator when
    // m_PSEL=1 AND no slave matches (unmapped address).
    //=========================================================================

    always @(*) begin
        if (!m_PSEL) begin
            // Bus is idle: no transaction active
            m_PRDATA  = {DATA_WIDTH{1'b0}};
            m_PREADY  = 1'b0;
            m_PSLVERR = 1'b0;
        end
        else if (s0_PSEL) begin
            // Slave 0 (RAM) is selected
            m_PRDATA  = s0_PRDATA;
            m_PREADY  = s0_PREADY;
            m_PSLVERR = s0_PSLVERR;
        end
        else if (s1_PSEL) begin
            // Slave 1 (Register File) is selected
            m_PRDATA  = s1_PRDATA;
            m_PREADY  = s1_PREADY;
            m_PSLVERR = s1_PSLVERR;
        end
        else if (s2_PSEL) begin
            // Slave 2 (ROM) is selected
            m_PRDATA  = s2_PRDATA;
            m_PREADY  = s2_PREADY;
            m_PSLVERR = s2_PSLVERR;
        end
        else begin
            // [FIXED] ERROR TERMINATOR: m_PSEL=1 but address unmapped.
            // Do NOT leave Master hanging in ACCESS state.
            m_PRDATA  = {DATA_WIDTH{1'b0}};
            m_PREADY  = 1'b1;   // Force immediate completion
            m_PSLVERR = 1'b1;   // Assert error flag
        end
    end

endmodule