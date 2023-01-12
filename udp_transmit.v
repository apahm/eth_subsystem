`timescale 1 ns / 1 ps

module udp_transmit 
(
    input wire  clk,
    input wire  rst,

	output wire  eth_txd_tvalid,
	output wire [DATA_WIDTH-1 : 0] eth_txd_tdata,
	output wire [(DATA_WIDTH/8)-1 : 0] eth_txd_tkeep,
	output wire  eth_txd_tlast,
	input wire  eth_txd_tready,

	output wire                    eth_txc_tvalid,
	output wire [DATA_WIDTH-1 : 0] eth_txc_tdata,
	output wire [(DATA_WIDTH/8)-1 : 0] eth_txc_tkeep,
	output wire  eth_txc_tlast,
	input wire  eth_txc_tready,

    input wire [DATA_WIDTH-1 : 0]   s_axis_data_tdata,
    input wire                      s_axis_data_tvalid,
    output wire                     s_axis_data_tready,
    input wire                      s_axis_data_tlast

);
    
    wire [7 : 0] self_mac_addr[0 : 5];

    wire [7 : 0] self_ip_addr[0 : 3];

    assign self_mac_addr[0] = 8'h00;
    assign self_mac_addr[1] = 8'h00;
    assign self_mac_addr[2] = 8'h00;
    assign self_mac_addr[3] = 8'h00;
    assign self_mac_addr[4] = 8'h00;
    assign self_mac_addr[5] = 8'h02;

    assign self_ip_addr[0] = 8'd128;
    assign self_ip_addr[1] = 8'd1;
    assign self_ip_addr[2] = 8'd168;
    assign self_ip_addr[3] = 8'd192;

    //Счетчик для циклов
    integer i;

    //Буфер служебной информации связанной с исходящими UDP пакетами      
    wire [127 : 0] send_udp_ctrl_din;
    wire send_udp_ctrl_we;
    wire send_udp_ctrl_full;
             
    //Буфер данных исходящих UDP пакетов     
    wire [31 : 0] send_udp_data_din;
    wire send_udp_data_we;
                  
    wire send_udp_data_re;
    wire [31 : 0] send_udp_data_dout;
    wire send_udp_data_empty;
    
    //Заголовок отправляемого UDP пакета
    reg [15 : 0] send_udp_hdr[0 : 3]; 
                                        
    //Размер отправляемых UDP данных
    reg [15 : 0] send_udp_data_size;
                                     
    //Размер отправляемого UDP пакета
    reg [15 : 0] send_udp_pkg_size;
    
    //Служебная информация связанная с исходящим пакетом
    reg [31 : 0] send_ctrl[0 : 5];
    
    //Счетчик управляющий передачей служебной информации
    reg [2 : 0] send_ctrl_counter;
    
    //ETH заголовок передаваемого пакета
    reg [15 : 0] send_eth_hdr[0 : 6];
    
    //Состояние конечного автомата управляющего отправкой пакетов
    reg [4 : 0] send_state;
    
    //Сигналы для доступа к блоку расчета контрольной суммы заголовка IP пакета   
    wire [31 : 0] ip_crc_calc_din;
    wire ip_crc_calc_en;
    wire ip_crc_calc_sop;
    wire ip_crc_calc_eop;
    wire [15 : 0] ip_crc_calc_result;
    wire ip_crc_calc_rdy;
    
    //IP заголовок передаваемого пакета
    reg [15 : 0] send_ip_hdr[0 : 9];
    
    //Счетчик управляющей загрузкой IP заголовка в блок расчета контрольной суммы
    creg [2 : 0] ip_crc_calc_counter;
    
    //Буфер данных исходящих UDP пакетов
    udp_send_data_buf 
    udp_send_data_buf_i 
    (
        .rst(rst),
     
        .wr_clk(clk),      
        .din(s_axis_data_tdata),
        .wr_en(s_axis_data_tvalid),
        .full(),
             
        .rd_clk(clk),     
        .rd_en(send_udp_data_re),
        .dout(send_udp_data_dout),
        .empty(send_udp_data_empty)
    );   
    
    //Сигналы чтения из буфера данных исходящих UDP пакетов 
    assign send_udp_data_re = (send_state == 13) && (eth_txd_tready == 1);
    
    wire [127:0] send_udp_ctrl_dout;

    assign send_udp_ctrl_dout[47 : 0]  = 48'h01_00_00_00_00_00;
    assign send_udp_ctrl_dout[79 : 48] = {8'd192, 8'd168, 8'd1,   8'd100};
    assign send_udp_ctrl_dout[95 : 80] = 16'd30000;
    assign send_udp_ctrl_dout[111 : 96] = 16'd31000;
    assign send_udp_ctrl_dout[127 : 112] = 16'd1024;

    always @(posedge clk) begin
        if (rst) begin
            //Сброс автомата управляющего отправкой пакетов
            send_state <= 0;
                
            //Инициализация служебной информации связанной с передаваемыми пакетами
            send_ctrl[0] <= 32'hA0000000;
            send_ctrl[1] <= 32'h00000000;
            send_ctrl[2] <= 32'h00000000;
            send_ctrl[3] <= 32'h00000000;
            send_ctrl[4] <= 32'h00000000;
            send_ctrl[5] <= 32'h00000000;
                
            //Сброс счетчика управляющего передачей служебной информации
            send_ctrl_counter <= 0; 
        end else begin    
            //Автомат управляющий отправкой пакетов
            case(send_state)  
                0: begin //Ожидание запросов на отправку пакетов
                    if(fifo_arp_answer_empty == 0 || fifo_ping_answer_empty == 0 || send_udp_data_empty == 0) begin
                        send_state <= 1; 
                    end
                end                
                1: begin //Передача служебной информации связанной с передаваемым пакетом
                    if(eth_txc_tready == 1) begin
                        send_ctrl[5] <= send_ctrl[0];
                        
                        for(i = 0; i < 5; i = i + 1) begin
                            send_ctrl[i] <= send_ctrl[i + 1];
                        end
                        
                        if(send_ctrl_counter != 5) begin
                            send_ctrl_counter <= send_ctrl_counter + 1;
                        end else begin
                            send_ctrl_counter <= 0;
                            send_state <= 10;    
                        end
                    end
                end    
                10: begin //Формирование UDP ответа
                    //Eth заголовок
                                                    
                    //DST MAC
                    {send_eth_hdr[0], send_eth_hdr[1], send_eth_hdr[2]} <= send_udp_ctrl_dout[47 : 0];
                    //SRC MAC
                    {send_eth_hdr[3], send_eth_hdr[4], send_eth_hdr[5]} <= {self_mac_addr[4], self_mac_addr[5], self_mac_addr[2], self_mac_addr[3], self_mac_addr[0], self_mac_addr[1]};
                    //Protokol type - IP
                    send_eth_hdr[6] <= 16'h0008;
                                    
                    //IP заголовок PING oтвета
                                    
                    //HDR LEN = 0x05, IP VER = 0x04, TYPE OF SERVICE = 0x00 
                    send_ip_hdr[0] <= 16'h0045;
                    //Заполняем поле размер пакета
                    {send_ip_hdr[1][7 : 0], send_ip_hdr[1][15 : 8]} <= send_udp_ctrl_dout[127 : 112] + 28;
                    //Идентификатор пакета (используется при сегментации) = 0x0000
                    send_ip_hdr[2] <= 16'h0000;
                    //Смещение фрагмента и флаги (используется при сегментации) = 0x0000
                    send_ip_hdr[3] <= 16'h0000;
                    //Вышестоящий протокол UDP (0x11), TTL = 0x80
                    send_ip_hdr[4] <= 16'h1180;
                    //Контрольная сумма IP заголовка
                    send_ip_hdr[5] <= 16'h0000;
                    //IP адрес отправителя
                    {send_ip_hdr[6], send_ip_hdr[7]} <= {self_ip_addr[2], self_ip_addr[3], self_ip_addr[0], self_ip_addr[1]};
                    //IP адрес получателя
                    {send_ip_hdr[8], send_ip_hdr[9]} <= send_udp_ctrl_dout[79 : 48];
                                    
                    //UDP заголовок передаваемого пакета
                    
                    //Порт отправителя пакета
                    send_udp_hdr[0] <= {send_udp_ctrl_dout[103 : 96], send_udp_ctrl_dout[111 : 104]};                
                                    
                    //Порт получателя пакета
                    send_udp_hdr[1] <= {send_udp_ctrl_dout[87 : 80], send_udp_ctrl_dout[95 : 88]};                 
                                  
                    //Размер UDP пакета
                    {send_udp_hdr[2][7 : 0], send_udp_hdr[2][15 : 8]} <= send_udp_ctrl_dout[127 : 112] + 8;
                                  
                    //Контрольная сумма UDP пакета (игнорируется)
                    send_udp_hdr[3] <= 16'h0000; 
                                    
                    //Размер отправляемых UDP данных
                    send_udp_data_size <= send_udp_ctrl_dout[127 : 112];
                                 
                    //Размер отправляемого UDP пакета
                    send_udp_pkg_size <= send_udp_ctrl_dout[127 : 112] + 42;
                                                         
                    ip_crc_calc_counter <= 4;                        
                                                            
                    send_state <= 11;
                end
                11: begin //Расчет контрольной суммы IP заголовка
                    if(ip_crc_calc_counter == 0) begin
                        send_state <= 12;
                    end else begin
                        ip_crc_calc_counter <= ip_crc_calc_counter - 1;
                    end
                            
                    for(i = 0; i < 4; i = i + 1) begin
                        send_ip_hdr[i * 2] <= send_ip_hdr[(i + 1) * 2];
                        send_ip_hdr[i * 2 + 1] <= send_ip_hdr[(i + 1) * 2 + 1];                     
                    end        
                            
                    send_ip_hdr[8] <= send_ip_hdr[0];
                    send_ip_hdr[9] <= send_ip_hdr[1];                   
                end
                12: begin //Запись контрольной суммы в IP заголовок
                    if(ip_crc_calc_rdy == 1) begin
                        //Контрольная сумма IP заголовка
                        send_ip_hdr[5] <= ip_crc_calc_result;
                        
                        send_state <= 13;
                    end
                end
                13: begin
                    if(eth_txd_tready == 1) begin
                        //Сдвиг передаваемых данных
                        for(i = 0; i < 2; i = i + 1) begin
                            send_eth_hdr[i * 2] <= send_eth_hdr[(i + 1) * 2];
                            send_eth_hdr[i * 2 + 1] <= send_eth_hdr[(i + 1) * 2 + 1];
                        end
                                        
                        send_eth_hdr[4] <= send_eth_hdr[6];
                        send_eth_hdr[5] <= send_ip_hdr[0];
                                        
                        send_eth_hdr[6] <= send_ip_hdr[1];
                        send_ip_hdr[0] <= send_ip_hdr[2];
                                        
                        for(i = 0; i < 3; i = i + 1) begin
                            send_ip_hdr[i * 2 + 2] <= send_ip_hdr[(i + 1) * 2 + 2];
                            send_ip_hdr[i * 2 + 1] <= send_ip_hdr[(i + 1) * 2 + 1];
                        end
                                        
                        send_ip_hdr[7] <= send_ip_hdr[9];
                        send_ip_hdr[8] <= send_udp_hdr[0];
                                        
                        send_ip_hdr[9] <= send_udp_hdr[1];
                        send_udp_hdr[0] <= send_udp_hdr[2];
                                        
                        send_udp_hdr[1] <= send_udp_hdr[3];
                        send_udp_hdr[2] <= send_udp_data_dout[15 : 0];
                                        
                        send_udp_hdr[3] <= send_udp_data_dout[31 : 16];
                                        
                        //Условие чтения передаваемых UDP данных из буфера
                        if(send_udp_data_size > 4) begin
                            send_udp_data_size <= send_udp_data_size - 4;
                        end else begin
                            send_udp_data_size <= 0;
                        end
                                        
                        //Условие завершения передачи пакета
                        if(send_udp_pkg_size > 4) begin
                            send_udp_pkg_size <= send_udp_pkg_size - 4;
                        end else begin
                            send_udp_pkg_size <= 0;
                                          
                            send_state <= 0;
                        end 
                    end
                end
            endcase
        end
    end
   
    //Расчет CRC IP заголовкка
    crc_calc ip_crc_calc_i 
    (
        .clk(clk),
        .rst(rst),
        .din(ip_crc_calc_din),
        .din_en(ip_crc_calc_en),
        .sop(ip_crc_calc_sop),
        .eop(ip_crc_calc_eop),
        .inv_crc(1),
        .crc_dout(ip_crc_calc_result),
        .crc_rdy(ip_crc_calc_rdy)
    );    
        
    assign ip_crc_calc_din = {send_ip_hdr[1], send_ip_hdr[0]};
    assign ip_crc_calc_en =  (send_state == 5) || (send_state == 11);
    assign ip_crc_calc_sop = (ip_crc_calc_counter == 4);            
    assign ip_crc_calc_eop = (ip_crc_calc_counter == 0);       
     
    assign s_axis_data_tready = 1'b1;

    //Интерфейс передачи служебной информации
    assign eth_txc_tkeep = 4'hF;
    assign eth_txc_tvalid = (send_state == 1); 
    assign eth_txc_tlast = (send_state == 1) && (send_ctrl_counter == 5);
    
    assign eth_txc_tdata = send_ctrl[0];
    
    //Интерфейс передачи пакета
    reg [3 : 0] eth_txd_tkeep_mux;
    
    always @(*) begin
        if((send_state == 3) && (send_arp_pkg_size == 2)) 
            eth_txd_tkeep_mux <= 4'h3;
        else if((send_state == 9 && send_ping_pkg_size == 3) || (send_state == 13 || send_udp_pkg_size == 3)) 
            eth_txd_tkeep_mux <= 4'h7;
        else if((send_state == 9 && send_ping_pkg_size == 2) || (send_state == 13 || send_udp_pkg_size == 2)) 
            eth_txd_tkeep_mux <= 4'h3;
        else if((send_state == 9 && send_ping_pkg_size == 1) || (send_state == 13 || send_udp_pkg_size == 1)) 
            eth_txd_tkeep_mux <= 4'h1;            
        else
            eth_txd_tkeep_mux <= 4'hF;    
    end
    
    assign eth_txd_tkeep = eth_txd_tkeep_mux;
    
    assign eth_txd_tvalid = (send_state == 3) || (send_state == 9) || (send_state == 13);
    assign eth_txd_tlast =  ((send_state == 3) && (send_arp_pkg_size <= 4)) || 
                            ((send_state == 9) && (send_ping_pkg_size <= 4)) || 
                            ((send_state == 13) && (send_udp_pkg_size <= 4));
    
    assign eth_txd_tdata = {send_eth_hdr[1], send_eth_hdr[0]}; 
endmodule
