module apb_master #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8
)(
    // Clock and Reset
    input  wire                  PCLK,
    input  wire                  PRESETn,

    //----------------------------------------------------------
    // Command Interface
    //----------------------------------------------------------
    input  wire [ADDR_WIDTH-1:0] cmd_addr,
    input  wire [DATA_WIDTH-1:0] cmd_wdata,
    input  wire                  cmd_rw,      // 1=Write, 0=Read
    input  wire                  cmd_start,   // Pulse high to request transfer
    output reg                   cmd_ready,   // HIGH when master can accept command
    output reg                   cmd_done,    // Pulse high when transfer completes
    output reg  [DATA_WIDTH-1:0] cmd_rdata,   // Data returned on read
    output reg                   cmd_error,   // PSLVERR captured at completion

    //----------------------------------------------------------
    // APB Interface
    //----------------------------------------------------------
    output reg                   PSEL,
    output reg                   PENABLE,
    output reg                   PWRITE,
    output reg  [ADDR_WIDTH-1:0] PADDR,
    output reg  [DATA_WIDTH-1:0] PWDATA,
    input  wire [DATA_WIDTH-1:0] PRDATA,
    input  wire                  PREADY,
    input  wire                  PSLVERR
);

    // State Encoding
    localparam IDLE  = 2'b00;
    localparam SETUP = 2'b01;
    localparam ACCESS= 2'b10;
    localparam DONE  = 2'b11;

    reg [1:0] state;

    // Internal registers to hold the current command
    reg [ADDR_WIDTH-1:0] addr_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg                  rw_reg;

    //----------------------------------------------------------
    // Combinational: cmd_ready assertion
    // Master is ready only in IDLE or when completing a transfer
    //----------------------------------------------------------
    always @(*) begin
        cmd_ready = (state == IDLE) || ((state == ACCESS) && PREADY);
    end

    //----------------------------------------------------------
    // Sequential State Machine
    //----------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            // Reset everything
            state     <= IDLE;
            addr_reg  <= {ADDR_WIDTH{1'b0}};
            wdata_reg <= {DATA_WIDTH{1'b0}};
            rw_reg    <= 1'b0;
            cmd_done  <= 1'b0;
            cmd_error <= 1'b0;
            cmd_rdata <= {DATA_WIDTH{1'b0}};
            PSEL      <= 1'b0;
            PENABLE   <= 1'b0;
            PWRITE    <= 1'b0;
            PADDR     <= {ADDR_WIDTH{1'b0}};
            PWDATA    <= {DATA_WIDTH{1'b0}};
        end
        else begin
            // Default: cmd_done is a single-cycle pulse only
            cmd_done <= 1'b0;

            case (state)

                //--------------------------------------------------
                // IDLE: Waiting for a command from testbench
                //--------------------------------------------------
                IDLE: begin
                    PSEL    <= 1'b0;
                    PENABLE <= 1'b0;
                    PWRITE  <= 1'b0;
                    PADDR   <= {ADDR_WIDTH{1'b0}};
                    PWDATA  <= {DATA_WIDTH{1'b0}};

                    if (cmd_start && cmd_ready) begin
                        // Latch the command into internal registers
                        addr_reg  <= cmd_addr;
                        wdata_reg <= cmd_wdata;
                        rw_reg    <= cmd_rw;
                        state     <= SETUP;
                    end
                end

                //--------------------------------------------------
                // SETUP: Assert PSEL, load address/control/data
                //        PENABLE must be LOW in this phase
                //--------------------------------------------------
                SETUP: begin
                    PSEL    <= 1'b1;
                    PENABLE <= 1'b0;
                    PWRITE  <= rw_reg;
                    PADDR   <= addr_reg;
                    PWDATA  <= wdata_reg;

                    // Always move to ACCESS on the next clock edge
                    state <= ACCESS;
                end

                //--------------------------------------------------
                // ACCESS: Assert PENABLE. Wait for slave's PREADY.
                //--------------------------------------------------
                ACCESS: begin
                    PSEL    <= 1'b1;        // [FIXED] Explicitly drive PSEL
                    PENABLE <= 1'b1;

                    if (PREADY) begin
                        //----- Transaction Completes This Cycle -----//

                        // Capture read data if this was a read
                        if (!rw_reg) begin
                            cmd_rdata <= PRDATA;
                        end

                        // Capture error flag from slave
                        cmd_error <= PSLVERR;

                        // Pulse cmd_done to tell testbench "transfer finished"
                        cmd_done <= 1'b1;

                        // Check for back-to-back transfer request
                        if (cmd_start && cmd_ready) begin
                            // Latch new command immediately
                            addr_reg  <= cmd_addr;
                            wdata_reg <= cmd_wdata;
                            rw_reg    <= cmd_rw;
                            state     <= SETUP;   // No idle cycle!
                        end
                        else begin
                            state <= DONE;          // One cycle to clean up
                        end
                    end
                    // else: PREADY=0, stay in ACCESS (wait state)
                end

                //--------------------------------------------------
                // DONE: Deassert bus. Return to IDLE or start next.
                //--------------------------------------------------
                DONE: begin
                    PSEL    <= 1'b0;
                    PENABLE <= 1'b0;
                    PWRITE  <= 1'b0;
                    PADDR   <= {ADDR_WIDTH{1'b0}};    // [FIXED] Clean bus
                    PWDATA  <= {DATA_WIDTH{1'b0}};  // [FIXED] Clean bus

                    if (cmd_start && cmd_ready) begin
                        // New command already waiting, skip IDLE
                        addr_reg  <= cmd_addr;
                        wdata_reg <= cmd_wdata;
                        rw_reg    <= cmd_rw;
                        state     <= SETUP;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule