module spi_clk_gen(  
    input wire clk,     // 系统主时钟  
    input wire csn,    // 复位信号（低有效）  -___-___
    output reg sck      // 生成的SPI时钟  
);  
    // 分频系数参数，SPI时钟 = clk / (2 * CLK_DIV)  
    parameter CLK_DIV = 4;  

    // 分频计数器，根据CLK_DIV自动切换sck电平  
    reg [15:0] clk_div_cnt = 16'd0;  

    always @(posedge clk or posedge csn) begin  
        if (csn) begin  
            clk_div_cnt <= 16'd0;  
            sck <= 1'b0;  
        end else begin  
            if (clk_div_cnt == (CLK_DIV - 1)) begin  
                clk_div_cnt <= 16'd0;  
                sck <= ~sck;  // 达到分频计数上限后翻转时钟输出  
            end else begin  
                clk_div_cnt <= clk_div_cnt + 16'd1;  
            end  
        end  
    end  
endmodule

//https://www.chipverify.com/verilog/verilog-single-port-ram 
module single_port_sync_ram_master
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


module spi_master_top(  
    input wire clk,  
    input wire rstn,  
    output wire sck,     //Clock to slave
    output reg csn,      // 片选信号，0有效  
    output reg mo,       // MOSI  
    input wire mi        // MISO  
);  

    // 参数定义  
    parameter CLK_DIV = 4;  // SPI时钟分频比  

    // 内部寄存器  
    //reg [31:0] shift_reg;   // 32位移位寄存器  
    reg [23:0] data_reg;    //24位寄存器存储数据位
    reg [7:0] crc_reg;      //8位寄存器存储crc校验码
    reg [5:0] bit_cnt;      // 位计数器（0~31）  
    reg sck_en;             // SPI时钟使能信号  
    reg time_cnt;           // 运行次数  

    // RAM 控制信号  
    reg [4:0] ram_addr;     // RAM 地址，假设 5 位宽度  
    reg ram_cs;             // RAM 片选信号  
    reg ram_we;             // RAM 写使能信号  
    reg ram_oe;             // RAM 读使能信号  
    wire [23:0] ram_data;   // RAM 数据总线  

    // 状态机定义  
    typedef enum reg [2:0] {  
        IDLE,    // 空闲状态 
        WAIT,    // 等待RAM 
        WAIT2,
        START,   // 开始通信  
        TRANSFER // 数据传输  
    } state_t;  
    state_t state;  

    // 生成SPI时钟信号的连线  
    wire spi_sck;  
    
    // 实例化独立的SPI时钟生成模块  
    spi_clk_gen #(  
        .CLK_DIV(CLK_DIV)  
    ) spi_clk_inst (  
        .clk(clk),  
        .csn(csn),  
        .sck(spi_sck)  
    );  
    
    // 将 spi_clk_gen 生成的 spi_sck 信号连接到模块的 sck 输出  
    assign sck = spi_sck; 
    
    // CRC-8 SAE-J1850 多项式  
    parameter CRC_POLY = 8'h1D; 

    // 实例化 RAM 模块  
    single_port_sync_ram_master #(  
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
    
    reg [7:0] calculated_crc;  
    reg [23:0] temp_data;  
    integer i; 
    // 状态机主逻辑  
    always @(posedge clk or negedge rstn) begin  
        if (!rstn) begin  
            csn <= 1'b1; // 片选默认无效  
            data_reg <= 24'hA5A5A5; // 初始化数据寄存器 
            crc_reg <= 8'hFF;       // 初始化CRC寄存器  
            bit_cnt <= 6'd0;  
            sck_en <= 1'b0;  
            state <= IDLE;  
            time_cnt <= 1'b1;  

        end else begin  
            case (state)  
                IDLE: begin  
                    csn <= 1'b1;    // 片选无效  
                    bit_cnt <= 6'd0;  
                    sck_en <= 1'b0;  
                    if (time_cnt > 1'b0) begin  
                        state <= WAIT;   

                    end else begin  
                        state <= IDLE;  
                    end  
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
                    csn <= 1'b0;    // 拉低片选，开始通信  
                    sck_en <= 1'b1; // 允许SPI时钟工作  
                    state <= TRANSFER;  
                    // 从 RAM 中读取数据到 data_reg  下半 
                    data_reg <= ram_data; // 将 RAM 数据加载到 data_reg
                end  

                TRANSFER: begin  
                    if (bit_cnt == 6'd32) begin  // 完成传输
                        state <= IDLE;  
                        csn <= 1'b1;   // 完成传输后关闭片选  
                        sck_en <= 1'b0;  // 关闭spi时钟
                        time_cnt <= time_cnt - 1'b1;  

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

    // 在 SCK 上升沿处理：发送数据（设置 MOSI）  
    always @(posedge spi_sck or negedge rstn) begin  
        if (!rstn) begin  
            mo <= 1'b0;  
            crc_reg <= 8'hFF; // 初始化CRC寄存器
        end else if (!csn && sck_en) begin  
            if (bit_cnt < 24) begin  
                // SCK 上升沿发送数据  
                mo <= data_reg[23];  
                // 动态更新CRC寄存器  
                if (crc_reg[7] ^ data_reg[23]) begin  //异或
                    crc_reg <= (crc_reg << 1) ^ CRC_POLY;  
                end else begin  
                    crc_reg <= (crc_reg << 1);  
                end  
            end else begin  
                // 发送CRC校验位  
                mo <= crc_reg[7];  
            end  
        end  
    end  

    // 在 SCK 下降沿处理：接收数据（读取 MISO）  
    always @(negedge spi_sck or negedge rstn) begin  
        if (!rstn) begin  
            data_reg <= 24'hFFFFFF; // 初始化数据寄存器    
            bit_cnt <= 6'd0;  
        end else if (!csn && sck_en) begin  
            // SCK 下降沿接收数据  
            if (bit_cnt < 24) begin
                data_reg  <= {data_reg [22:0], mi};  
            end else begin  
                // 接收CRC校验位  
                crc_reg <= {crc_reg[6:0], mi};  
            end 
            bit_cnt <= bit_cnt + 1'b1;  
        end  
    end  
endmodule