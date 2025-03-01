module spi_slave(  
    input wire sck,       // SPI 时钟输入  
    input wire csn,       // 片选信号输入，低电平有效  
    input wire si,        // 主设备数据输出 (MOSI)  
    output reg so,        // 从设备数据输出 (MISO)  
    input wire rstn       // 复位信号，低电平有效  
);  

    // 内部寄存器  
    reg [31:0] shift_reg;   // 32-bit 移位寄存器  
    reg [4:0] bit_cnt;      // 位计数器（0~31）  

    // 初始化  
    always @(negedge rstn or posedge sck) begin  
        if (!rstn) begin  
            shift_reg <= 32'hDEADBEEF; // 初始化为非零值  
            bit_cnt <= 5'd0;  
            so <= 1'b0;  
        end else if (!csn) begin  
            // 在片选信号有效时（低电平）  
            /*if (sck) begin  
                // 在时钟上升沿接收数据  
                save_besent <= shift_reg[31];
                shift_reg <= {shift_reg[30:0], si}; // 接收主设备发送的数据  
                bit_cnt <= bit_cnt + 1'b1;  
            end else begin  
                // 在时钟下降沿发送数据  
                so <= save_besent; // 发送最高位  
            end  */
            if (sck) begin  
                // 在时钟上升沿发送数据  
                so <= shift_reg[31]; // 发送最高位  
            end else begin  
                // 在时钟下降沿接收数据  
                shift_reg <= {shift_reg[30:0], si}; // 接收主设备发送的数据  
                bit_cnt <= bit_cnt + 1'b1;  
            end
        end else begin  
            // 在片选信号无效时，重置计数器  
            bit_cnt <= 5'd0;  
        end  
    end  

endmodule  