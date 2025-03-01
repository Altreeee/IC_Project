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
    //reg sck_d; // 添加延迟寄存器用于检测边沿 

    // 检测时钟边沿的寄存器  
    /*always @(posedge sck or negedge rstn) begin  
        if (!rstn)  
            sck_d <= 1'b0;  
        else  
            sck_d <= 1'b1; // 在上升沿设置为1  
    end*/

    // 主逻辑 
    always @(posedge sck or negedge sck or negedge rstn) begin  
        if (!rstn) begin  
            shift_reg <= 32'hDEADBEEF; // 初始化为非零值  11011110101011011011111011101111
            bit_cnt <= 5'd0;  
            so <= 1'b0;  
        end else if (!csn) begin  
            if (sck == 1'b1) begin  
                // sck上升沿发送数据  
                so <= shift_reg[31];  
                //shift_reg <= {shift_reg[30:0], 1'b0}; // 左移，为下一位做准备    
            end else if (sck == 1'b0) begin  
                // sck下降沿接收数据  
                //shift_reg[0] <= si; // 接收数据到最低位  
                shift_reg <= {shift_reg[30:0], si};
                if (bit_cnt < 31) begin  
                    bit_cnt <= bit_cnt + 1'b1;  
                end else begin  
                    bit_cnt <= 5'd0; // 复位计数器，准备下一次传输  
                end  
            end
        end else begin  
            // 在片选信号无效时，重置计数器  
            bit_cnt <= 5'd0;  
        end  
    end  

endmodule  