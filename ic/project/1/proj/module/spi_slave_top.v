module spi_slave(  
    input wire sck,       // SPI 时钟输入  
    input wire csn,       // 片选信号输入，低电平有效  
    input wire si,        // 主设备数据输出 (MOSI)  
    output reg so,        // 从设备数据输出 (MISO)  
    input wire rstn       // 复位信号，低电平有效  
);  

    // 内部寄存器  
    reg [31:0] shift_reg;  // 32-bit 移位寄存器  

    // 在SCK上升沿处理 - 数据输出  
    always @(posedge sck or negedge rstn) begin  
        if (!rstn) begin  
            so <= 1'b0;  
        end else if (!csn) begin  
            // SCK上升沿发送数据  
            so <= shift_reg[31];  
        end  
    end  

    // 在SCK下降沿处理 - 数据接收  
    always @(negedge sck or negedge rstn) begin  
        if (!rstn) begin  
            shift_reg <= 32'hDEADBEEF; // 初始数据 11011110101011011011111011101111  
        end else if (!csn) begin  
            // SCK下降沿接收数据  
            shift_reg <= {shift_reg[30:0], si};  
        end  
    end  
endmodule