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

    // CRC-8 SAE-J1850 多项式  
    parameter CRC_POLY = 8'h1D; 

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
            data_reg <= 24'hEFEFEF;    
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