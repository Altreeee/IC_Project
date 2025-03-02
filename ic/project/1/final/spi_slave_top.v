//https://www.chipverify.com/verilog/verilog-single-port-ram 
module single_port_sync_ram_slave
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
    mem[0] = 24'hFEDCBA; // 示例数据  
    // 初始化其他地址为 0  
    for (int i = 1; i < DEPTH; i = i + 1) begin  
      mem[i] = 24'h000000;  
    end  
  end  
  
endmodule



module spi_slave_top(  
    input wire clk, 
    input wire sck,       // SPI 时钟输入  
    input wire csn,       // 片选信号输入，低电平有效  
    input wire si,        // 主设备数据输出 (MOSI)  
    output reg so,        // 从设备数据输出 (MISO)  
    input wire rstn       // 复位信号，低电平有效  
);  

    // 内部寄存器  
    //reg [31:0] shift_reg;  // 32-bit 移位寄存器  
    reg [23:0] data_reg;    //24位寄存器存储数据位
    reg [7:0] crc_reg;      //8位寄存器存储crc校验码
    reg [5:0] bit_cnt;      // 位计数器（0~31）

    // RAM 控制信号  
    reg [4:0] ram_addr;     // RAM 地址，假设 5 位宽度  
    reg ram_cs;             // RAM 片选信号  
    reg ram_we;             // RAM 写使能信号  
    reg ram_oe;             // RAM 读使能信号  
    wire [23:0] ram_data;   // RAM 数据总线  

    // 实例化 RAM 模块  
    single_port_sync_ram_slave #(  
        .ADDR_WIDTH(5),  
        .DATA_WIDTH(24),  
        .DEPTH(32)  
    ) ram_inst (  
        .clk(clk),  
        .addr(ram_addr),  
        .data(ram_data),  
        .cs(ram_cs),  
        .we(ram_we),  
        .oe(ram_oe)  
    );  

    // RAM 数据总线的驱动逻辑  
    assign ram_data = (ram_cs && ram_we) ? data_reg : 'hz;  //当开启写时ram_data被赋值为data_reg

    // CRC-8 SAE-J1850 多项式  
    parameter CRC_POLY = 8'h1D; 

    reg [7:0] calculated_crc;  
    reg [23:0] temp_data;  
    integer i; 
    // 状态机定义  
    typedef enum reg [2:0] {  
        IDLE,    // 空闲状态 
        WAIT,    // 等待RAM 
        WAIT2,
        START,   // 开始通信  
        TRANSFER // 数据传输  
    } state_t;  
    state_t state; 
    // 状态机主逻辑  
    always @(posedge clk or negedge rstn) begin  
        if (!rstn) begin  
            data_reg <= 24'hA5A5A5; // 初始化数据寄存器 
            crc_reg <= 8'hFF;       // 初始化CRC寄存器  
            bit_cnt <= 6'd0;  
            state <= IDLE;  

        end else begin  
            case (state)  
                IDLE: begin  
                    bit_cnt <= 6'd0;  
                    state <= WAIT;  
                    // 复位 RAM 控制信号  
                    ram_cs <= 1'b0;  
                    ram_we <= 1'b0;  
                    ram_oe <= 1'b0;  
                                
                end  

                WAIT: begin
                    // 从 RAM 中读取数据到 data_reg  上半
                    ram_cs <= 1'b1;  
                    ram_we <= 1'b0;  
                    ram_oe <= 1'b1;  
                    ram_addr <= 5'd0; 
                    state <= WAIT2;
                end
                WAIT2: begin  
                    // 等待一个时钟周期，让 ram_data 稳定  
                    state <= START;  
                end 

                START: begin  
                    if (csn) begin
                        state <= START;
                    end else begin 
                        state <= TRANSFER;  
                        // 从 RAM 中读取数据到 data_reg  下半 
                        data_reg <= ram_data; // 将 RAM 数据加载到 data_reg
                    end
                end  

                TRANSFER: begin  
                    if (bit_cnt == 6'd32) begin  // 完成传输
                        state <= IDLE;  

                        /*检查CRC*/
                        // 重新计算 CRC   
                        calculated_crc = 8'hFF;  // 初始化 CRC  
                        temp_data = data_reg;    // 获取当前数据  
                        for (i = 0; i < 24; i = i + 1) begin  
                            if (calculated_crc[7] ^ temp_data[23]) begin  
                                calculated_crc = (calculated_crc << 1) ^ CRC_POLY;  
                            end else begin  
                                calculated_crc = (calculated_crc << 1);  
                            end  
                            temp_data = temp_data << 1;  // 左移数据  
                        end  

                        // 比较重新计算的 CRC 和接收到的 CRC  
                        if (calculated_crc != crc_reg) begin  
                            $display("CRC Error: Calculated CRC = %h, Received CRC = %h", calculated_crc, crc_reg);  
                        end else begin  
                            $display("CRC Check Passed");  
                        end  

                        // 将 data_reg 写回 RAM  
                        //前面已经有assign ram_data = (ram_cs && ram_we) ? data_reg : 'hz; 所以只需要改读写权限
                        ram_cs <= 1'b1;  
                        ram_we <= 1'b1;  
                        ram_oe <= 1'b0;  
                        ram_addr <= 5'd0; // 写入地址  
                    end  
                end  

                default: state <= IDLE;  
            endcase  
        end  
    end  


    // 在SCK上升沿处理 - 数据输出  
    always @(posedge sck or negedge rstn) begin  
        if (!rstn) begin  
            so <= 1'b0;  
            bit_cnt <= 6'd0;  //初始化 计数器
            crc_reg <= 8'hFF; // 初始化CRC寄存器
        end else if (!csn) begin  
            if (bit_cnt < 24) begin  
                // SCK上升沿发送数据  
                so <= data_reg[23];  
                // 动态更新CRC寄存器  
                if (crc_reg[7] ^ data_reg[23]) begin  
                    crc_reg <= (crc_reg << 1) ^ CRC_POLY;  
                end else begin  
                    crc_reg <= (crc_reg << 1);  
                end  
            end else begin  
                // 发送CRC校验位  
                so <= crc_reg[7];
            end
        end  
    end  

    // 在SCK下降沿处理 - 数据接收  
    always @(negedge sck or negedge rstn) begin  
        if (!rstn) begin  
            data_reg <= 24'hFFFFFF;    
        end else if (!csn) begin  
            // SCK下降沿接收数据  
            if (bit_cnt < 24) begin
                data_reg <= {data_reg[22:0], si};  
            end else begin  
                // 接收CRC校验位  
                crc_reg <= {crc_reg[6:0], si};  
            end 
            bit_cnt <= bit_cnt + 1'b1;  
        end  
    end  
endmodule