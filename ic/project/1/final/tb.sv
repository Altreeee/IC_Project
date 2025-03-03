module testbench;  

    // Testbench 信号  
    reg clk_master;              
    reg clk_slave;               
    reg rstn;              
    wire sck;              
    wire csn;               
    wire mosi;             
    wire miso;             

    // Instantiation of Master and Slave 
    spi_master #(.CLK_DIV(4)) master (  
        .clk(clk_master),  
        .rstn(rstn),  
        .sck(sck),  
        .csn(csn),  
        .mo(mosi),  
        .mi(miso)  
    );  

    spi_slave slave (  
        .clk(clk_slave),
        .sck(sck),  
        .csn(csn),  
        .si(mosi),  
        .so(miso),  
        .rstn(rstn)  
    );  

    // Clock Generation 
    initial begin  
        clk_master = 0;  
        forever #5 clk_master = ~clk_master; 
    end  
    initial begin  
        clk_slave = 0;  
        forever #2 clk_slave = ~clk_slave; 
    end  

    // Initialize the RAM data for Master and Slave
    initial begin  
  
        rstn = 0;  
        #20; // Hold reset for 20ns
        rstn = 1;  

        // Initialize the Master's RAM data 
        //master.ram_inst.mem[0] = 24'hABCDEF; // Write data 0xABCDEF to address 0  
        //for (int i = 1; i < 32; i = i + 1) begin  
            //master.ram_inst.mem[i] = 24'h000000; // Other addresses are initialized to 0. 
        //end  

        // Initialize the Slave's RAM data  
        //slave.ram_inst.mem[0] = 24'hFEDCBA; // Write data 0xFEDCBA to address 0 
        //for (int i = 1; i < 32; i = i + 1) begin  
            //slave.ram_inst.mem[i] = 24'h000000; // Other addresses are initialized to 0.
        //end  

        //Waiting for Master and Slave to start communication.  
        #10000;  

          
        $display("Test completed. Check waveforms for verification.");  
        //$stop;  
        $finish;  
    end  

    //----------------------------------  
    // Generate FSDB waveform file  
    //----------------------------------  
    initial begin  
        $fsdbDumpfile("tb.fsdb");	    
        $fsdbDumpvars;  
    end  

endmodule