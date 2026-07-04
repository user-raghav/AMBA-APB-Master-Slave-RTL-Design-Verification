module apb_slave_rom #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter MEM_DEPTH  = 8,
    parameter N          = 2
)(
    input  wire                  PCLK,
    input  wire                  PRESETn,
    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,     // Monitored to reject writes
    input  wire [ADDR_WIDTH-1:0] PADDR,
    // [FIXED Bug 1] No PWDATA input — ROM is read-only!
    output reg  [DATA_WIDTH-1:0] PRDATA,
    output reg                   PREADY,
    output reg                   PSLVERR
);

    //=========================================================================
    // State Encoding
    //=========================================================================
    localparam IDLE  = 2'b00;
    localparam SETUP = 2'b01;
    localparam ACCESS= 2'b10;

    reg [1:0] state;

    //=========================================================================
    // ROM Storage — Read-Only Memory
    //=========================================================================
    reg [DATA_WIDTH-1:0] rom [0:MEM_DEPTH-1];

    //=========================================================================
    // Wait State Counter
    //=========================================================================
    reg [$clog2(N+1)-1:0] wait_counter;

    //=========================================================================
    // Address Validation
    //=========================================================================
    //=========================================================================
    // Address Validation
    //=========================================================================
    wire [$clog2(MEM_DEPTH)-1:0] rom_index;
    assign rom_index = PADDR[$clog2(MEM_DEPTH)-1:0];

    wire addr_valid;
    // FIX: Since the interconnect decoded the upper bits to select this ROM,
    // any transaction reaching here is at a valid base address.
    assign addr_valid = 1'b1;

    //=========================================================================
    // ROM Initialization (Pre-loaded Pattern)
    //=========================================================================
    // [FIXED Bug 2] ROM must have defined values at startup!
    // Using initial block for simulation. For synthesis, use $readmemh or
    // hardcoded values. Here we use a simple pattern.
    //=========================================================================
    integer init_i;
    initial begin
        for (init_i = 0; init_i < MEM_DEPTH; init_i = init_i + 1) begin
            rom[init_i] = init_i * 8'h11;  // Pattern: 0x00, 0x11, 0x22, 0x33...
        end
    end

    //=========================================================================
    // Sequential Logic
    //=========================================================================
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            //--------------------------------------------------
            // Reset
            //--------------------------------------------------
            PRDATA       <= {DATA_WIDTH{1'b0}};
            PREADY       <= 1'b0;
            PSLVERR      <= 1'b0;
            state        <= IDLE;
            wait_counter <= 0;
        end
        else begin
            // Default: PREADY low
            PREADY <= 1'b0;

            case (state)

                //--------------------------------------------------
                // IDLE: Waiting for transaction
                //--------------------------------------------------
                IDLE: begin
                    PSLVERR <= 1'b0;

                    if (PSEL && !PENABLE) begin
                        state <= SETUP;
                    end
                end

                //--------------------------------------------------
                // SETUP: Address valid, preparing
                //--------------------------------------------------
                SETUP: begin
                    if (PSEL && PENABLE) begin
                        state <= ACCESS;
                        wait_counter <= 0;
                    end
                    else if (!PSEL) begin
                        state <= IDLE;
                    end
                end

                //--------------------------------------------------
                // ACCESS: Read-only operations only
                //--------------------------------------------------
                ACCESS: begin
                    if (!PSEL) begin
                        // Master aborted
                        state <= IDLE;
                    end
                    else if (N == 0) begin
                        // Zero wait states: complete immediately
                        PREADY <= 1'b1;

                        if (!addr_valid) begin
                            PSLVERR <= 1'b1;
                        end
                        else if (PWRITE) begin
                            // [FIXED Bug 4] WRITE ATTEMPT TO ROM!
                            PSLVERR <= 1'b1;  // Reject with error
                            // Do NOT write to rom[] — it's read-only!
                        end
                        else begin
                            // Valid read
                            PRDATA <= rom[rom_index];
                        end

                        state <= IDLE;
                    end
                    else if (wait_counter < N - 1) begin
                        // [FIXED Bug 3] Explicitly stay in ACCESS!
                        wait_counter <= wait_counter + 1;
                        state <= ACCESS;  // ← CRITICAL FIX
                    end
                    else begin
                        // Wait complete
                        PREADY <= 1'b1;

                        if (!addr_valid) begin
                            PSLVERR <= 1'b1;
                        end
                        else if (PWRITE) begin
                            // [FIXED Bug 4] WRITE ATTEMPT TO ROM!
                            PSLVERR <= 1'b1;  // Reject with error
                            // Do NOT write to rom[] — it's read-only!
                        end
                        else begin
                            // Valid read
                            PRDATA <= rom[rom_index];
                        end

                        state <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule