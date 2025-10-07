module TxUART (
    input        Clk,
    input        RstB,           // Note: treated as active-HIGH reset in this code
    input        TxFfEmpty,
    input  [7:0] TxFfRdData,
    output       TxFfRdEn,
    output       SerialDataOut
);

// ----------------------------------------
// Output assignment
// ----------------------------------------
assign TxFfRdEn      = rTxFfRdEn[0];
assign SerialDataOut = rSerialData[0];

// ----------------------------------------
// Parameter declaration
// ----------------------------------------
parameter integer cbaudCnt = 108;
parameter integer cdataCnt = 0;

parameter [1:0] stIdle   = 2'b00;
parameter [1:0] stRdReq  = 2'b01;
parameter [1:0] stWtData = 2'b10;
parameter [1:0] stWtEnd  = 2'b11;

// ----------------------------------------
// Signal declaration
// ----------------------------------------
reg  [1:0] rState;
reg  [1:0] rTxFfRdEn;
reg  [9:0] rSerialData;
reg  [9:0] rBaudCnt;
reg        rBaudEnd;
reg  [3:0] rDataCnt;

// ----------------------------------------
// Behavioral Model
// ----------------------------------------

// rBaudCnt
always @(posedge Clk) begin
    if (RstB == 1'b1) begin
        rBaudCnt <= cbaudCnt;
    end else if (rState == stWtEnd) begin
        if (rBaudCnt == 10'd1) begin
            rBaudCnt <= cbaudCnt;
        end else begin 
            brBaudCnt <= rBaudCnt - 10'd1;
        end
    end
end

// rBaudEnd
always @(posedge Clk) begin
    if (RstB == 1'b1) begin
        rBaudEnd <= 1'b0;
    end else begin
        rBaudEnd <= (rBaudCnt == 10'd1);
    end
end

// rDataCnt
always @(posedge Clk) begin
    if (RstB == 1'b1) begin
        rDataCnt <= cdataCnt[3:0];
    end else if (rTxFfRdEn[1] == 1'b1) begin
        rDataCnt <= cdataCnt[3:0];
    end else if (rBaudEnd == 1'b1 && rDataCnt != 4'd9) begin
        rDataCnt <= rDataCnt + 4'd1;
    end
end

// rSerialData
always @(posedge Clk) begin
    if (RstB == 1'b1) begin
        rSerialData <= 10'b1111111111;
    end else if (rTxFfRdEn[1] == 1'b1) begin
        // Load: {stop, data[7:0], start}
        rSerialData[9]   <= 1'b1;
        rSerialData[8:1] <= TxFfRdData[7:0];
        rSerialData[0]   <= 1'b0;
    end else if (rBaudEnd == 1'b1) begin
        // Shift right, keep line high after frame
        rSerialData <= {1'b1, rSerialData[9:1]};
    end
end

// rState
always @(posedge Clk) begin
    if (RstB == 1'b1) begin
        rState <= stIdle;
    end else begin
        case (rState)
            stIdle: begin
                if (TxFfEmpty == 1'b0) rState <= stRdReq;
                else rState <= stIdle;
            end
            stRdReq: begin
                rState <= stWtData;
            end
            stWtData: begin
                if (rTxFfRdEn[1] == 1'b1) begin
                    rState <= stWtEnd;
                end else begin 
                    rState <= stWtData;
                end
            end
            stWtEnd: begin
                if (rDataCnt == 4'd9 && rBaudEnd == 1'b1) begin 
                    rState <= stIdle;
                end
                else begin 
                    rState <= stWtEnd;
                end
            end
            default: begin
                rState <= stIdle;
            end
        endcase
    end
end

// rTxFfRdEn
always @(posedge Clk) begin
    if (RstB == 1'b1) begin
        rTxFfRdEn <= 2'b00;
    end else begin
        rTxFfRdEn[1] <= rTxFfRdEn[0];
        if (rState == stRdReq) begin 
            rTxFfRdEn[0] <= 1'b1;
        end else begin 
            rTxFfRdEn[0] <= 1'b0;
        end
    end
end

endmodule
