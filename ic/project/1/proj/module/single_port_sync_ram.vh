`ifndef SINGLE_PORT_SYNC_RAM_VH  // 如果没有定义宏 SINGLE_PORT_SYNC_RAM_VH  
`define SINGLE_PORT_SYNC_RAM_VH  // 定义宏 SINGLE_PORT_SYNC_RAM_VH 

//https://www.chipverify.com/verilog/verilog-single-port-ram 
module single_port_sync_ram
  # (parameter ADDR_WIDTH = 5,
     parameter DATA_WIDTH = 24,
     parameter DEPTH = 32
    )

  ( 	input 					clk,
   		input [ADDR_WIDTH-1:0]	addr,
   		inout [DATA_WIDTH-1:0]	data,
   		input 					cs,
   		input 					we,
   		input 					oe
  );

  reg [DATA_WIDTH-1:0] 	tmp_data;
  reg [DATA_WIDTH-1:0] 	mem [DEPTH];

  always @ (posedge clk) begin
    if (cs & we)
      mem[addr] <= data;
  end

  always @ (posedge clk) begin
    if (cs & !we)
    	tmp_data <= mem[addr];
  end

  assign data = cs & oe & !we ? tmp_data : 'hz; //读为1且写为0时data会被赋值为tmp_data（此时可以读RAM的内容）

  // 初始化 RAM 内容  
  initial begin  
    // 初始化地址 0 的数据  
    mem[0] = 24'hABCDEF; // 示例数据  
    // 初始化其他地址为 0  
    for (int i = 1; i < DEPTH; i = i + 1) begin  
      mem[i] = 24'h000000;  
    end  
  end  
  
endmodule

`endif  // 结束条件编译 