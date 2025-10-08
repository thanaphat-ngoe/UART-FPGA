`timescale 1ns/1ps

module tb_TxUART;
	reg Clk = 1'b0;
	reg RstB;            
	reg TxFfEmpty;
	reg [7:0] TxFfRdData;
	wire TxFfRdEn;
	wire SerialDataOut;

  	// ---- Clock (20ns period = 50 MHz)
  	always #10 Clk = ~Clk;

  	// ---- Instantiate DUT
  	TxUART dut (
    	.Clk(Clk),
    	.RstB(RstB),
    	.TxFfEmpty(TxFfEmpty),
    	.TxFfRdData(TxFfRdData),
    	.TxFfRdEn(TxFfRdEn),
    	.SerialDataOut(SerialDataOut)
  	);

  	// -------- Helper tasks --------
  	task automatic feed_byte_when_requested(input [7:0] byteval);
    	begin
			@(posedge Clk);
			wait (TxFfRdEn === 1'b1);
			TxFfRdData <= byteval;
			@(posedge Clk);
			@(posedge Clk);
    	end
  	endtask

  	task automatic case1_stream_three_bytes;
    	begin
      		$display("[%0t] CASE1: Empty=0 long; bytes A5,00,FF back-to-back", $time);
      		TxFfEmpty   <= 1'b0;
			feed_byte_when_requested(8'hA5);
			feed_byte_when_requested(8'h00);
			feed_byte_when_requested(8'hFF);
			TxFfEmpty   <= 1'b1;
			repeat (5000) @(posedge Clk);
    	end
  	endtask

  	task automatic case2_pulse_empty_per_byte;
    	integer NUM_IDLE_CLKS;
    	begin
			NUM_IDLE_CLKS = 4000;
			$display("[%0t] CASE2: Pulse Empty 2-3 clocks per byte; bytes A5,00,FF", $time);
			TxFfRdData <= 8'hA5;
			pulse_empty_for_n_clks(3);
			wait_idle_for(NUM_IDLE_CLKS);
			TxFfRdData <= 8'h00;
			pulse_empty_for_n_clks(3);
			wait_idle_for(NUM_IDLE_CLKS);
			TxFfRdData <= 8'hFF;
			pulse_empty_for_n_clks(3);
			wait_idle_for(NUM_IDLE_CLKS);
			$display("[%0t] CASE2 done", $time);
			repeat (2000) @(posedge Clk);
    	end
  	endtask

  	task automatic pulse_empty_for_n_clks(input integer nclks);
    	integer i;
    		begin
      			TxFfEmpty <= 1'b0;
      			for (i = 0; i < nclks; i = i + 1) @(posedge Clk);
      			TxFfEmpty <= 1'b1;
    		end
  	endtask

  	task automatic wait_idle_for(input integer num_clks);
    	integer k;
    	begin
			wait (SerialDataOut === 1'b1);
			for (k = 0; k < num_clks; k = k + 1) begin
				@(posedge Clk);
				if (SerialDataOut !== 1'b1) begin
				k = -1;
				wait (SerialDataOut === 1'b1);
				end
			end
		end
  	endtask

  	// ---- Reset and Main Simulation ----
  	initial begin
		RstB = 1'b0;
		TxFfEmpty = 1'b1;    
		TxFfRdData = 8'h00;
		@(posedge Clk);
		RstB = 1'b1;
		repeat (5) @(posedge Clk);
		RstB = 1'b0;
		$display("[%0t] Released reset", $time);
		repeat (10) @(posedge Clk);
		case1_stream_three_bytes();
		repeat (2000) @(posedge Clk);
		case2_pulse_empty_per_byte();
		$display("[%0t] All tests finished.", $time);
		$finish;
	end

	always @(posedge Clk) begin
		if (TxFfRdEn)
		$display("[%0t] TxFfRdEn=1, TxFfRdData=%02h (Empty=%b)", $time, TxFfRdData, TxFfEmpty);
	end

	// ---- VCD dump
  	initial begin
    	$dumpfile("txuart_tb.vcd");
    	$dumpvars(0, tb_TxUART);
  	end

endmodule
