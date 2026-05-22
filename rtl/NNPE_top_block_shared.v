module NNPE_top_block_shared (
    input wire clk,
    input wire reset,
    input wire [7:0] system_in,
    output reg [15:0] system_out
);

    // ============================================================
    // 1. INTERNAL SIGNAL DECLARATIONS
    // ============================================================
    reg [7:0] reg_data_in, reg_weight, reg_gamma, reg_beta;
    reg [3:0] reg_pool_size;
    reg       reg_start;
    reg [2:0] load_ptr;

    reg [5:0] state, next_state;
    reg [2:0] layer_count;
    reg [7:0] feedback_data;
    reg [3:0] conv_counter, relu_counter, pool_counter;


    wire [15:0] mac_out;
    wire [15:0] pool_out;
    wire [15:0] relu_out;
    reg  [7:0]  conv_data_mux;
    reg  [15:0] relu_input_mux;

    // State Encoding
    localparam ST_IDLE       = 6'b000001;
    localparam ST_CONV       = 6'b000010;
    localparam ST_POOLING    = 6'b000100;
    localparam ST_RELU       = 6'b001000;
    localparam ST_NEXT_LAYER = 6'b010000;
    localparam ST_COMPLETE   = 6'b100000;

    wire use_pool = (layer_count == 3'd2 || layer_count == 3'd4 || layer_count == 3'd6);

    // ============================================================
    // 2. SIPO LOGIC
    // ============================================================
    always @(posedge clk) begin
        if (reset) begin
            load_ptr <= 3'b000;
            reg_start <= 1'b0;
            reg_data_in <= 8'h00; reg_weight <= 8'h00;
            reg_gamma <= 8'h00;   reg_beta <= 8'h00;
            reg_pool_size <= 4'h0;
        end else if (!reg_start) begin
            case (load_ptr)
                3'd0: begin reg_data_in <= system_in; load_ptr <= 3'd1; end
                3'd1: begin reg_weight  <= system_in; load_ptr <= 3'd2; end
                3'd2: begin reg_gamma   <= system_in; load_ptr <= 3'd3; end
                3'd3: begin reg_beta    <= system_in; load_ptr <= 3'd4; end
                3'd4: begin
                    reg_pool_size <= system_in[3:0];
                    reg_start     <= system_in[4]; 
                end
                default: load_ptr <= 3'b000;
            endcase
        end
    end

    // ============================================================
    // 3. FINITE STATE MACHINE (FSM)
    // ============================================================
    always @(posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
            layer_count <= 3'b000;
            feedback_data <= 8'h00;
            conv_counter <= 4'h0; relu_counter <= 4'h0; pool_counter <= 4'h0;
        end else begin
            state <= next_state;
            case (state)
                ST_CONV:    conv_counter <= conv_counter + 1'b1;
                ST_POOLING: pool_counter <= pool_counter + 1'b1;
                ST_RELU:    relu_counter <= relu_counter + 1'b1;
                ST_IDLE, ST_NEXT_LAYER: begin
                    conv_counter <= 4'h0; relu_counter <= 4'h0; pool_counter <= 4'h0;
                end
            endcase
            
            if (state == ST_NEXT_LAYER) layer_count <= layer_count + 1'b1;
            if (state == ST_COMPLETE)   layer_count <= 3'b000;

            if (state == ST_RELU && relu_counter == 4'd1) begin
                feedback_data <= (relu_out > 16'd255) ? 8'd255 : relu_out[7:0];
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE:       if (reg_start) next_state = ST_CONV;
            ST_CONV:       if (conv_counter == 4'd4) next_state = (use_pool) ? ST_POOLING : ST_RELU;
            ST_POOLING:    if (pool_counter >= {2'b00, reg_pool_size} - 1'b1) next_state = ST_RELU;
            ST_RELU:       if (relu_counter == 4'd1) next_state = (layer_count == 3'd7) ? ST_COMPLETE : ST_NEXT_LAYER;
            ST_NEXT_LAYER: next_state = ST_CONV;
            ST_COMPLETE:   next_state = ST_IDLE;
            default:       next_state = ST_IDLE;
        endcase
    end

    // ============================================================
    // 4. DATAPATH & SUB-MODULES
    // ============================================================
    
    
    always @(*) begin
        if (conv_counter == 4'h0)
            conv_data_mux = (layer_count == 3'b000) ? reg_data_in : feedback_data;
        else
            conv_data_mux = 8'h00;
    end

    always @(*) relu_input_mux = (use_pool) ? pool_out : mac_out;

    Conv_MAC_Stage conv_unit (
        .clk(clk), .reset(reset), .enable(state == ST_CONV), .finish(conv_counter == 4'd4),
        .data_in(conv_data_mux), .weight(reg_weight), .mac_out(mac_out)
    );

    GAP_Stage pool_unit (
        .clk(clk), .reset(reset), .enable(state == ST_POOLING),
        .finish(pool_counter >= {2'b00, reg_pool_size} - 1'b1),
        .in_data(mac_out), .gap_out(pool_out)
    );

    ReLU_Stage relu_unit (
        .clk(clk), .reset(reset), .enable(state == ST_RELU),
        .in_data(relu_input_mux), .gamma(reg_gamma), .beta(reg_beta),
        .relu_out(relu_out)
    );

    // ============================================================
    // 5. OUTPUT BUFFER
    // ============================================================
    always @(posedge clk) begin
        if (reset)
            system_out <= 16'h0000;
        else if (state == ST_COMPLETE)
            system_out <= relu_out;
    end

endmodule

// ============================================================
// SUB-MODULES
// ============================================================
module Conv_MAC_Stage (
input wire clk, reset, enable, finish,
input wire [7:0] data_in, weight,
output reg [15:0] mac_out
);
reg [15:0] acc;
always @(posedge clk) begin
if (reset || !enable) begin
acc <= 16'h0000;
end else begin
acc <= acc + (data_in * weight);
if (finish) mac_out <= acc + (data_in * weight);
end
end
endmodule


module GAP_Stage (
input wire clk, reset, enable, finish,
input wire [15:0] in_data,
output reg [15:0] gap_out
);
reg [31:0] sum;
always @(posedge clk) begin
if (reset || !enable) begin
sum <= 32'h00000000;
end else begin
if (finish) gap_out <= (sum + {16'h0000, in_data}) >> 1;
else sum <= sum + {16'h0000, in_data};
end
end
endmodule


module ReLU_Stage (
input wire clk, reset, enable,
input wire [15:0] in_data,
input wire [7:0] gamma, beta,
output reg [15:0] relu_out
);
wire [31:0] product = in_data * gamma;
always @(posedge clk) begin
if (reset) begin
relu_out <= 16'h0000;
end else if (enable) begin
// Math: (X * Gamma / 8) + Beta
if (in_data[15] == 1'b0 && in_data > 0)
relu_out <= product[18:3] + {8'h00, beta};
else
relu_out <= {8'h00, beta};
end
end
endmodule