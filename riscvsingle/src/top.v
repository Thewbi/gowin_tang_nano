module top(

    // input
    input wire sys_clk, 
    input wire sys_rst_n,
    input wire btn1_n,
    input uart_rx,          // UART RX

    // output
    output reg [5:0] led,
    output uart_tx          // UART TX

);

    // Instantiate Debounce Module
    wire sys_rst_n_debounced;
    Debounce_Switch sys_rst_n_debounce_inst
    (
        .i_Clk(sys_clk), 
        .i_Switch(sys_rst_n),
        .o_Switch(sys_rst_n_debounced)
    );

    // Instantiate Debounce Module
    wire btn1_n_debounced;
    Debounce_Switch btn1_n_debounce_inst
    (
        .i_Clk(sys_clk), 
        .i_Switch(btn1_n),
        .o_Switch(btn1_n_debounced)
    );





    



/*
    // When USB top, HDMI bottom, the sys_rst_n button is on the right
    always @(negedge sys_rst_n_debounced)
    begin
        //led[0] <= 1'b1; // used for dmem instance (when USB top, HDMI bottom, then rightmost)
        //led[1] <= 1'b1;
        //led[2] <= 1'b1;
        //led[3] <= 1'b1;
        //led[4] <= 1'b1; // used for riscvsingle instance (when USB top, HDMI bottom, then 2nd from right)
        //led[5] <= 1'b1; // used for blinky (when USB top, HDMI bottom, then 5 is leftmost LED)
    end
*/
    




    wire clock_out;
    reg clock_out_reg;
    assign clock_out = clock_out_reg;

/**/
    //
    // Drive clock_out_reg from [sys_clk] => [clock_divider] => clock_out_reg
    //

    // divide clock
    // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
    
    reg [31:0] counter = 32'd0;
    parameter DIVISOR = 32'd27000000;
    always @(posedge sys_clk)
    begin
        counter <= counter + 32'd1;
        if (counter >= (DIVISOR - 1))
        begin
            counter <= 32'd0;
        end
        clock_out_reg <= (counter < (DIVISOR / 2)) ? 1'b1 : 1'b0;
    end


/*
    //
    // Drive clock_out_reg from [sys_rst_n] => [debouncer] => clock_out_reg
    //
    // When USB top, HDMI bottom, the sys_rst_n button is on the right
    // When USB top, HDMI bottom, the btn1_n button is on the left
    //

    // When USB top, HDMI bottom, the btn1_n button is on the left
    always @(negedge btn1_n_debounced)
    begin
        clock_out_reg = ~clock_out_reg;
    end
*/







    // slow clock
    always @(posedge clock_out)
    begin
        //led[5] = ~led[5];
    end


    // fast clock    
    always @(posedge sys_clk)
    begin
        if (sys_rst_n_debounced == 1'b0)
        begin
            //PC = 32'b0;
            //led[2:0] = 3'b111;

            led[5:0] = 6'b111111;
        end
        else
        begin
            //led[3] = led3_wire; // dmem
            //led[4] = led4_wire; // riscvsingle
            //led[2:0] = ~PC[2:0];

            // just display the current PC
            //led[5:0] = ~PC[5:0];

            led[0] <= ~led3_wire; // dmem
            led[1] <= ~led3_wire; // dmem
            led[2] <= ~led3_wire; // dmem
            led[3] <= ~led3_wire; // dmem
            led[4] <= ~led3_wire; // dmem
            led[5] <= ~led3_wire; // dmem

        end
    end

    wire led3_wire; // dmem
    wire led4_wire; // riscvsingle
    wire [2:0] ALUControl;

    wire [31:0] PC;
    wire [31:0] Instr;
    wire [31:0] ReadData;
    wire [31:0] WriteData;
    wire [31:0] DataAdr;
    wire MemWrite;

    // instantiate processor
    riscvsingle rvsingle(
        clock_out, // slow clock
        sys_rst_n_debounced, 
        PC, 
        Instr, 
        MemWrite, 
        DataAdr, 
        WriteData, 
        ReadData,
        ALUControl,
        led4_wire // led 4
    );

    // instruction memory
    imem imem(sys_rst_n_debounced, PC, Instr);

    // data memory
    dmem dmem(sys_clk, sys_rst_n_debounced, MemWrite, DataAdr, WriteData, ReadData, led3_wire);






    //
    // UART
    //

    //
    // combinational logic for UART
    //

    // Data to send (terminated with cr lf == 16'h0d0a)
    //parameter DATA_NUM = 11 + 2;
    //reg [DATA_NUM * 8 - 1 : 0] send_data = { "Hello World", 16'h0d0a };

    parameter DATA_NUM = 1 + 4 + 2; // 1 byte PC + 4 byte instruction + 2 byte CR LF
    reg [DATA_NUM * 8 - 1 : 0] send_data = { 32'h00000000, 16'h0d0a };

    // slow clock
    always @(posedge clock_out)
    begin

        // output PC
        send_data[55 : 48] = PC;

        // output the instruction from FETCH phase
        send_data[47 : 16] = Instr;

        printf = ~printf;
    end


    reg[7:0]                        tx_str;

    wire[7:0]                       tx_data;
    wire[7:0]                       tx_cnt;

    // DEBUG control the uart tx
    reg printf = 1'b0;

    wire                            tx_data_ready; // output of the tx module. Asserted when transmission has been performed
    wire[7:0]                       rx_data;
    reg                             rx_data_ready = 1'b1; // receiving data is always enabled
    wire                            tx_data_valid;

    uart_controller 
    #(
        .DATA_NUM(DATA_NUM)
    ) uart_controller_inst (

        // input
        .clk                        (sys_clk),
        .rst_n                      (sys_rst_n),
        .tx_str                     (tx_str),
        .printf                     (printf),
        .tx_data_ready              (tx_data_ready),
        .o_tx_data_valid            (tx_data_valid),
        .rx_data                    (rx_data),
        .rx_data_valid              (rx_data_valid),

        // output
        .o_tx_cnt                   (tx_cnt),
        .o_tx_data                  (tx_data)
        
    );

    

    parameter                        CLK_FRE  = 27; // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
    parameter                        UART_FRE = 115200; // baudrate

    always@(*)
        tx_str <= send_data[(DATA_NUM - 1 - tx_cnt) * 8 +: 8];

    uart_rx
    #(
        .CLK_FRE(CLK_FRE),
        .BAUD_RATE(UART_FRE)
    ) uart_rx_inst (
        // input
        .clk                        (sys_clk),
        .rst_n                      (sys_rst_n),	
        .rx_data_ready              (rx_data_ready),
        .rx_pin                     (uart_rx),

        // output
        .rx_data                    (rx_data),
        .rx_data_valid              (rx_data_valid)
    );

    uart_tx
    #(
        .CLK_FRE(CLK_FRE),
        .BAUD_RATE(UART_FRE)
    ) uart_tx_inst (
        // input
        .clk                        (sys_clk),
        .rst_n                      (sys_rst_n),
        .tx_data                    (tx_data),
        .tx_data_valid              (tx_data_valid),

        // output
        .tx_data_ready              (tx_data_ready),
        .tx_pin                     (uart_tx)
    );

endmodule