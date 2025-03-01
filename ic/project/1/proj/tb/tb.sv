module spi_testbench;  

    // Testbench 信号  
    reg clk;               // 全局时钟  
    reg rstn;              // 全局复位信号  
    wire sck;              // SPI 时钟  
    wire csn;              // SPI 片选信号  
    wire mo;               // SPI 主设备数据输出 (MOSI)  
    wire mi;               // SPI 从设备数据输出 (MISO)  

    // Master 和 Slave 的实例化  
    spi_master #(.CLK_DIV(4)) master (  
        .clk(clk),  
        .rstn(rstn),  
        .sck(sck),  
        .csn(csn),  
        .mo(mo),  
        .mi(mi)  
    );  

    spi_slave slave (  
        .sck(sck),  
        .csn(csn),  
        .si(mo),  
        .so(mi),  
        .rstn(rstn)  
    );  

    // 时钟生成  
    initial begin  
        clk = 0;  
        forever #5 clk = ~clk; // 100MHz 时钟，周期为 10ns  
    end  

    // 测试逻辑  
    initial begin  
        // 初始化  
        rstn = 0;  
        #20; // 保持复位 20ns  
        rstn = 1;  

        // 等待 Master 和 Slave 开始通信  
        #10000;  

        // 检查通信结果  
        $display("Test completed. Check waveforms for verification.");  
        //$stop;  
        $finish;
    end  

//----------------------------------
//gen fsdb
//----------------------------------

initial	begin
	    $fsdbDumpfile("tb.fsdb");	    
        $fsdbDumpvars;
end

endmodule
