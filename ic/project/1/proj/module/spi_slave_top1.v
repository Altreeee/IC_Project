`include "single_port_sync_ram.vh"  


module spi_slave(  
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
    single_port_sync_ram #(  
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

    // 状态机定义  
    typedef enum reg [1:0] {  
        IDLE,    // 空闲状态 
        WAIT,    // 等待RAM 
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
 

                    state <= START;   
                    // 从 RAM 中读取数据到 data_reg  上半
                    ram_cs <= 1'b1;  
                    ram_we <= 1'b0;  
                    ram_oe <= 1'b1;  
                    ram_addr <= 5'd0; 

                    state <= IDLE;  
                     
                end  

                WAIT: begin
                    // 从 RAM 中读取数据到 data_reg  下半 
                    data_reg <= ram_data; // 将 RAM 数据加载到 data_reg
                    state <= START;
                end

                START: begin  
                    state <= TRANSFER;  
                end  

                TRANSFER: begin  
                    if (bit_cnt == 6'd32) begin  // 完成传输
                        state <= IDLE;  




                        /*检查CRC*/

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
                crc_reg <= {crc_reg[6:0], so};  
            end 
            bit_cnt <= bit_cnt + 1'b1;  
        end  
    end  
endmodule