//https://www.chipverify.com/verilog/verilog-single-port-ram   
module single_port_sync_ram_slave  
  # (parameter ADDR_WIDTH = 5,  
     parameter DATA_WIDTH = 24,  
     parameter DEPTH = 32  
    )  

  ( 	input 					clk,  
   		input [ADDR_WIDTH-1:0]	addr,  
   		inout [DATA_WIDTH-1:0]	data,  
   		input 					cs,  
   		input 					we,  
   		input 					oe  
  );  

  reg [DATA_WIDTH-1:0] 	tmp_data;  
  reg [DATA_WIDTH-1:0] 	mem [DEPTH];  

  always @ (posedge clk) begin  
    if (cs & we)  
      mem[addr] <= data;  
  end  

  always @ (posedge clk) begin  
    if (cs & !we)  
    	tmp_data <= mem[addr];  
  end  

  assign data = cs & oe & !we ? tmp_data : 'hz; // When read is 1 and write is 0, data is assigned to tmp_data (RAM content can be read at this time)  

  // Initialize RAM content  
  initial begin  
    // Initialize data at address 0  
    mem[0] = 24'hFEDCBA; // Example data  
    // Initialize other addresses to 0  
    for (int i = 1; i < DEPTH; i = i + 1) begin  
      mem[i] = 24'h000000;  
    end  
  end  
  
endmodule  



module spi_slave_top(  
    input wire clk,   
    input wire sck,         
    input wire csn,         
    input wire si,        // MOSI  
    output reg so,        // MISO  
    input wire rstn        
);  

    // Internal Register   
    reg [23:0] data_reg;    // 24-bit register to store data  
    reg [7:0] crc_reg;      // 8-bit register to store CRC checksum  
    reg [5:0] bit_cnt;      // Bit counter (0~31)  

    // RAM control signals  
    reg [4:0] ram_addr;     // RAM address, assumed to be 5 bits wide  
    reg ram_cs;             // RAM chip select signal  
    reg ram_we;             // RAM write enable signal  
    reg ram_oe;             // RAM read enable signal  
    wire [23:0] ram_data;   // RAM data bus  

    // Instantiate RAM module  
    single_port_sync_ram_slave #(  
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

    // Driving logic for RAM data bus  
    assign ram_data = (ram_cs && ram_we) ? data_reg : 'hz;  // When write is enabled, ram_data is assigned to data_reg  

    // CRC-8 SAE-J1850 polynomial  
    parameter CRC_POLY = 8'h1D;   

    reg [7:0] calculated_crc;  
    reg [23:0] temp_data;  
    integer i;   
    // State machine definition  
    typedef enum reg [2:0] {  
        IDLE,    // Idle state   
        WAIT,    // Wait for RAM   
        WAIT2,  
        START,   // Start communication  
        TRANSFER // Data transfer  
    } state_t;  
    state_t state;   
    // Main logic for state machine  
    always @(posedge clk or negedge rstn) begin  
        if (!rstn) begin  
            data_reg <= 24'hA5A5A5; // Initialize data register   
            crc_reg <= 8'hFF;       // Initialize CRC register  
            bit_cnt <= 6'd0;  
            state <= IDLE;  

        end else begin  
            case (state)  
                IDLE: begin  
                    bit_cnt <= 6'd0;  
                    state <= WAIT;  
                    // Reset RAM control signals  
                    ram_cs <= 1'b0;  
                    ram_we <= 1'b0;  
                    ram_oe <= 1'b0;  
                                
                end  

                WAIT: begin  
                    // Read data from RAM into data_reg (upper half)  
                    ram_cs <= 1'b1;  
                    ram_we <= 1'b0;  
                    ram_oe <= 1'b1;  
                    ram_addr <= 5'd0;   
                    state <= WAIT2;  
                end  
                WAIT2: begin  
                    // Wait one clock cycle for ram_data to stabilize  
                    state <= START;  
                end   

                START: begin  
                    if (csn) begin  
                        state <= START;  
                    end else begin   
                        state <= TRANSFER;  
                        // Read data from RAM into data_reg (lower half)  
                        data_reg <= ram_data; // Load RAM data into data_reg  
                    end  
                end  

                TRANSFER: begin  
                    if (bit_cnt == 6'd32) begin  // Transfer complete  
                        state <= IDLE;  

                        /* Check CRC */  
                        // Recalculate CRC   
                        calculated_crc = 8'hFF;  // Initialize CRC  
                        temp_data = data_reg;    // Get current data  
                        for (i = 0; i < 24; i = i + 1) begin  
                            if (calculated_crc[7] ^ temp_data[23]) begin  
                                calculated_crc = (calculated_crc << 1) ^ CRC_POLY;  
                            end else begin  
                                calculated_crc = (calculated_crc << 1);  
                            end  
                            temp_data = temp_data << 1;  // Left shift data  
                        end  

                        // Compare recalculated CRC with received CRC  
                        if (calculated_crc != crc_reg) begin  
                            $display("CRC Error: Calculated CRC = %h, Received CRC = %h", calculated_crc, crc_reg);  
                        end else begin  
                            $display("CRC Check Passed");  
                        end  

                        // Write data_reg back to RAM  
                        // The assign statement already exists: ram_data = (ram_cs && ram_we) ? data_reg : 'hz; so only read/write permissions need to be changed  
                        ram_cs <= 1'b1;  
                        ram_we <= 1'b1;  
                        ram_oe <= 1'b0;  
                        ram_addr <= 5'd0; // Write address  
                    end  
                end  

                default: state <= IDLE;  
            endcase  
        end  
    end  


    // Handle data output on SCK rising edge  
    always @(posedge sck or negedge rstn) begin  
        if (!rstn) begin  
            so <= 1'b0;  
            bit_cnt <= 6'd0;  // Initialize counter  
            crc_reg <= 8'hFF; // Initialize CRC register  
        end else if (!csn) begin  
            if (bit_cnt < 24) begin  
                // Send data on SCK rising edge  
                so <= data_reg[23];  
                // Dynamically update CRC register  
                if (crc_reg[7] ^ data_reg[23]) begin  
                    crc_reg <= (crc_reg << 1) ^ CRC_POLY;  
                end else begin  
                    crc_reg <= (crc_reg << 1);  
                end  
            end else begin  
                // Send CRC checksum  
                so <= crc_reg[7];  
            end  
        end  
    end  

    // Handle data reception on SCK falling edge  
    always @(negedge sck or negedge rstn) begin  
        if (!rstn) begin  
            data_reg <= 24'hFFFFFF;    
        end else if (!csn) begin  
            // Receive data on SCK falling edge  
            if (bit_cnt < 24) begin  
                data_reg <= {data_reg[22:0], si};  
            end else begin  
                // Receive CRC checksum  
                crc_reg <= {crc_reg[6:0], si};  
            end   
            bit_cnt <= bit_cnt + 1'b1;  
        end  
    end  
endmodule