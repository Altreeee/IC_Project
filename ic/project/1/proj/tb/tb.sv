module spi_testbench;  

    // Testbench 信号  
    reg clk;               // 全局时钟  
    reg rstn;              // 全局复位信号  
    wire sck;              // SPI 时钟  
    wire csn;              // SPI 片选信号  
    wire mosi;             // SPI 主设备数据输出 (MOSI)  
    wire miso;             // SPI 从设备数据输出 (MISO)  

    // Master 和 Slave 的实例化  
    spi_master #(.CLK_DIV(4)) master (  
        .clk(clk),  
        .rstn(rstn),  
        .sck(sck),  
        .csn(csn),  
        .mo(mosi),  
        .mi(miso)  
    );  

    spi_slave slave (  
        .clk(clk),
        .sck(sck),  
        .csn(csn),  
        .si(mosi),  
        .so(miso),  
        .rstn(rstn)  
    );  

    // 时钟生成  
    initial begin  
        clk = 0;  
        forever #5 clk = ~clk; // 100MHz 时钟，周期为 10ns  
    end  

    // 初始化 Master 和 Slave 的 RAM 数据  
    initial begin  
        // 初始化复位信号  
        rstn = 0;  
        #20; // 保持复位 20ns  
        rstn = 1;  

        // 初始化 Master 的 RAM 数据  
        //master.ram_inst.mem[0] = 24'hABCDEF; // 地址 0 写入数据 0xABCDEF  
        //for (int i = 1; i < 32; i = i + 1) begin  
            //master.ram_inst.mem[i] = 24'h000000; // 其他地址初始化为 0  
        //end  

        // 初始化 Slave 的 RAM 数据  
        //slave.ram_inst.mem[0] = 24'hFEDCBA; // 地址 0 写入数据 0xFEDCBA  
        //for (int i = 1; i < 32; i = i + 1) begin  
            //slave.ram_inst.mem[i] = 24'h000000; // 其他地址初始化为 0  
        //end  

        // 等待 Master 和 Slave 开始通信  
        #10000;  

        // 检查通信结果  
        $display("Test completed. Check waveforms for verification.");  
        //$stop;  
        $finish;  
    end  

    //----------------------------------  
    // 生成 FSDB 波形文件  
    //----------------------------------  
    initial begin  
        $fsdbDumpfile("tb.fsdb");	    
        $fsdbDumpvars;  
    end  

endmodule