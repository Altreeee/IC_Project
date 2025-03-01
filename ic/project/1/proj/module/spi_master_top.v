module spi_master(
    //clk & Reset 0: Valid 
    input wire clk,
    input wire rstn,

    output reg sck, //Clock to slave
    output reg csn, //Chip select 0: Valid 
    output reg mo, //Data output    
    
    input wire mi //Data input 
);

    // 参数定义  
    parameter CLK_DIV = 4;  // 时钟分频比，SPI 时钟 = 输入时钟 / (2 * CLK_DIV)  

    // 内部寄存器  
    reg [31:0] shift_reg;   // 32-bit 移位寄存器  
    reg [4:0] bit_cnt;      // 位计数器（0~31）  
    reg [15:0] clk_div_cnt; // 时钟分频计数器  
    reg sck_en;             // SPI 时钟使能信号  
    reg sck_d;              // 延迟一个时钟周期的 sck 信号，用于检测下降沿  

    // 状态机定义  
    typedef enum reg [1:0] {  
        IDLE,   // 空闲状态  
        START,  // 开始通信  
        TRANSFER // 数据传输  
    } state_t;  
    state_t state;  


    // 主逻辑  
    always @(posedge clk or negedge rstn) begin  
        if (!rstn) begin  
            sck <= 1'b0;  
            csn <= 1'b1;  // 片选信号默认拉高（无效）  
            mo <= 1'b0;  
            shift_reg <= 32'hA5A5A5A5; // 初始化为非零值  10100101101001011010010110100101
            bit_cnt <= 5'd0;  
            clk_div_cnt <= 16'd0;  
            sck_en <= 1'b0;  
            state <= IDLE;  
             
        end else begin  
            // 延迟一个时钟周期的 sck 信号  
            //sck_d <= sck;   /////////////////////////////////////////////////////////////////原来没有注释
            case (state)  
                // 空闲状态  
                IDLE: begin  
                    csn <= 1'b1;  // 片选信号无效  
                    sck <= 1'b0;  // SPI 时钟默认低电平  
                    bit_cnt <= 5'd0;  
                    clk_div_cnt <= 16'd0;  
                    sck_en <= 1'b0;  
                    if (/* 启动条件，例如外部触发信号 */ 1'b1) begin  
                        state <= START;  
                    end  
                end  

                // 开始通信  
                START: begin  
                    csn <= 1'b0;  // 拉低片选信号，开始通信  
                    sck_en <= 1'b1; // 使能 SPI 时钟  
                    state <= TRANSFER;  
                end  

                // 数据传输  
                
                TRANSFER: begin  
                    // 时钟分频逻辑  
                    if (clk_div_cnt == CLK_DIV - 1) begin  
                        clk_div_cnt <= 16'd0;  
                        sck_d <= sck;
                        sck <= ~sck; // 翻转 SPI 时钟  
                        
                        // 基于翻转前的SCK和sck_d判断当前处于什么边沿  
                        // 正在生成上升沿：当前sck为0，即将变为1  
                        if (sck == 1'b0) begin  
                            // 在SCK即将上升前设置输出位  
                            mo <= shift_reg[31];  
                        end  
                        // 正在生成下降沿：当前sck为1，即将变为0  
                        else begin  
                            // 下降沿操作  
                            shift_reg <= {shift_reg[30:0], mi}; // 接收数据并移位  
                            bit_cnt <= bit_cnt + 1'b1;  
                            if (bit_cnt == 5'd31) begin  
                                state <= IDLE;  
                                csn <= 1'b1;  
                                sck_en <= 1'b0;  
                            end  
                        end  
                        
                    end else begin  
                        clk_div_cnt <= clk_div_cnt + 1'b1;  
                    end  
                end
                
                

                default: state <= IDLE;  
            endcase  
        end  
    end  

endmodule  



