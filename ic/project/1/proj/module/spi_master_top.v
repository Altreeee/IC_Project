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
        if (csn) begin  //csn为1时
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


module spi_master(  
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
    reg [31:0] shift_reg;   // 32位移位寄存器  
    reg [5:0] bit_cnt;      // 位计数器（0~31）  
    reg sck_en;             // SPI时钟使能信号  
    reg time_cnt;           // 运行次数  

    // 状态机定义  
    typedef enum reg [1:0] {  
        IDLE,    // 空闲状态  
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
    
    // 状态机主逻辑  
    always @(posedge clk or negedge rstn) begin  
        if (!rstn) begin  
            csn <= 1'b1; // 片选默认无效  
            shift_reg <= 32'hA5A5A5A5;  
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
                        state <= START;   
                    end else begin  
                        state <= IDLE;  
                    end  
                end  

                START: begin  
                    csn <= 1'b0;    // 拉低片选，开始通信  
                    sck_en <= 1'b1; // 允许SPI时钟工作  
                    state <= TRANSFER;  
                end  

                TRANSFER: begin  
                    if (bit_cnt == 6'd32) begin  
                        state <= IDLE;  
                        csn <= 1'b1;   // 完成传输后关闭片选  
                        sck_en <= 1'b0;  
                        time_cnt <= time_cnt - 1'b1;  
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
        end else if (!csn && sck_en) begin  
            // SCK 上升沿发送数据  
            mo <= shift_reg[31];  
        end  
    end  

    // 在 SCK 下降沿处理：接收数据（读取 MISO）  
    always @(negedge spi_sck or negedge rstn) begin  
        if (!rstn) begin  
            shift_reg <= 32'hA5A5A5A5; // 初始化移位寄存器  
            bit_cnt <= 6'd0;  
        end else if (!csn && sck_en) begin  
            // SCK 下降沿接收数据  
            shift_reg <= {shift_reg[30:0], mi};  
            bit_cnt <= bit_cnt + 1'b1;  
        end  
    end  
endmodule