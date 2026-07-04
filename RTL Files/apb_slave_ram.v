module apb_slave_ram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter MEM_DEPTH  = 8,
    parameter N          = 4
)(
    input  wire                  PCLK,
    input  wire                  PRESETn,
    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire [DATA_WIDTH-1:0] PWDATA,
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
    // Memory and Counter
    //=========================================================================
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    reg [$clog2(N+1)-1:0] wait_counter;

    //=========================================================================
    // Address Validation
    //=========================================================================
    wire [$clog2(MEM_DEPTH)-1:0] mem_index;
    assign mem_index = PADDR[$clog2(MEM_DEPTH)-1:0];

    wire addr_valid;
    assign addr_valid = (PADDR < MEM_DEPTH);

    //=========================================================================
    // Sequential Logic
    //=========================================================================
    integer i;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA   <= {DATA_WIDTH{1'b0}};
            PREADY   <= 1'b0;
            PSLVERR  <= 1'b0;
            state    <= IDLE;
            wait_counter <= 0;

            
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                mem[i] <= {DATA_WIDTH{1'b0}};
            end
        end
        else begin
            // Default: PREADY is low unless we explicitly set it
            PREADY <= 1'b0;

            case (state)

                //--------------------------------------------------
                // IDLE: Waiting for transaction to start
                //--------------------------------------------------
                IDLE: begin
                    PSLVERR <= 1'b0;  // Clear error when idle

                    if (PSEL && !PENABLE) begin
                        // SETUP phase detected: PSEL=1, PENABLE=0
                        state <= SETUP;
                    end
                end

                //--------------------------------------------------
                // SETUP: Address and control are valid
                //        Prepare for access, but don't act yet
                //--------------------------------------------------
                SETUP: begin
                    if (PSEL && PENABLE) begin
                        // Move to ACCESS phase
                        state <= ACCESS;
                        wait_counter <= 0;
                    end
                    else if (!PSEL) begin
                        // Master aborted before enable
                        state <= IDLE;
                    end
                    // else: stay in SETUP (PSEL=1, PENABLE=0 still)
                end

                //--------------------------------------------------
                // ACCESS: Perform the operation
                //--------------------------------------------------
                ACCESS: begin
                    if (!PSEL) begin
                        // Master aborted during access/wait
                        state <= IDLE;
                    end
                    else if (N == 0) begin
                        // Zero wait states: complete immediately
                        PREADY <= 1'b1;

                        if (!addr_valid) begin
                            PSLVERR <= 1'b1;
                        end
                        else if (PWRITE) begin
                            mem[mem_index] <= PWDATA;
                        end
                        else begin
                            PRDATA <= mem[mem_index];
                        end

                        state <= IDLE;
                    end
                    else if (wait_counter < N - 1) begin
                        // Still in wait state
                        wait_counter <= wait_counter + 1;
                        state <= ACCESS;  // Stay in ACCESS
                    end
                    else begin
                        // Wait complete: perform operation
                        PREADY <= 1'b1;

                        if (!addr_valid) begin
                            PSLVERR <= 1'b1;
                        end
                        else if (PWRITE) begin
                            mem[mem_index] <= PWDATA;
                        end
                        else begin
                            PRDATA <= mem[mem_index];
                        end

                        state <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule