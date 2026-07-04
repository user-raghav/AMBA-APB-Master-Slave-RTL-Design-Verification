module apb_slave_reg #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter MEM_DEPTH  = 8
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
    // Register File
    //=========================================================================
    reg [DATA_WIDTH-1:0] reg_file [0:MEM_DEPTH-1];

    //=========================================================================
    // Address Validation
    //=========================================================================
    //=========================================================================
    // Address Validation
    //=========================================================================
    wire [$clog2(MEM_DEPTH)-1:0] reg_index;
    
    // Use only the lower bits for the index
    assign reg_index = PADDR[$clog2(MEM_DEPTH)-1:0];

    wire addr_valid;
    // FIX: A register is ALWAYS valid if PSEL is high, because the 
    // interconnect already verified the upper bits!
    assign addr_valid = 1'b1;

    //=========================================================================
    // Sequential Logic
    //=========================================================================
    integer i;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            //--------------------------------------------------
            // Reset
            //--------------------------------------------------
            PRDATA  <= {DATA_WIDTH{1'b0}};
            PREADY  <= 1'b0;
            PSLVERR <= 1'b0;
            state   <= IDLE;

            
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                reg_file[i] <= {DATA_WIDTH{1'b0}};
            end
        end
        else begin
            // Default: PREADY low unless we explicitly complete
            PREADY <= 1'b0;

            case (state)

                //--------------------------------------------------
                // IDLE: Waiting for transaction
                //--------------------------------------------------
                IDLE: begin
                    PSLVERR <= 1'b0;  // Clear error for new transaction

                    if (PSEL && !PENABLE) begin
                        // SETUP phase detected
                        state <= SETUP;
                    end
                end

                //--------------------------------------------------
                // SETUP: Address and control valid
                //--------------------------------------------------
                SETUP: begin
                    if (PSEL && PENABLE) begin
                        // Move to ACCESS
                        state <= ACCESS;
                    end
                    else if (!PSEL) begin
                        // Master aborted
                        state <= IDLE;
                    end
                end

                //--------------------------------------------------
                // ACCESS: Complete immediately (N=0, no wait states)
                //--------------------------------------------------
                ACCESS: begin
                    if (!PSEL) begin
                        // Master aborted during access
                        state <= IDLE;
                    end
                    else begin
                        // [FIXED] N=0: Always complete in one cycle
                        PREADY <= 1'b1;

                        if (!addr_valid) begin
                            // Invalid address
                            PSLVERR <= 1'b1;
                        end
                        else if (PWRITE) begin
                            // Write to register
                            reg_file[reg_index] <= PWDATA;
                        end
                        else begin
                            // Read from register
                            PRDATA <= reg_file[reg_index];
                        end

                        // Return to IDLE immediately
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule