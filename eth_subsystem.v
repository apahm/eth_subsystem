
`timescale 1 ns / 1 ps

	module eth_hw_core_v1_0 #(

		parameter integer C_eth_txd_TDATA_WIDTH	= 32,

		parameter integer C_eth_txc_TDATA_WIDTH	= 32,

		parameter integer C_eth_rxd_TDATA_WIDTH	= 32,

		parameter integer C_eth_rxs_TDATA_WIDTH	= 32,
		
        parameter integer C_data_TDATA_WIDTH    = 32
	)
	(
		output wire  eth_txd_tvalid,
		output wire [C_eth_txd_TDATA_WIDTH-1 : 0] eth_txd_tdata,
		output wire [(C_eth_txd_TDATA_WIDTH/8)-1 : 0] eth_txd_tkeep,
		output wire  eth_txd_tlast,
		input wire  eth_txd_tready,

		output wire  eth_txc_tvalid,
		output wire [C_eth_txc_TDATA_WIDTH-1 : 0] eth_txc_tdata,
		output wire [(C_eth_txc_TDATA_WIDTH/8)-1 : 0] eth_txc_tkeep,
		output wire  eth_txc_tlast,
		input wire  eth_txc_tready,

		output wire  eth_rxd_tready,
		input wire [C_eth_rxd_TDATA_WIDTH-1 : 0] eth_rxd_tdata,
		input wire [(C_eth_rxd_TDATA_WIDTH/8)-1 : 0] eth_rxd_tkeep,
		input wire  eth_rxd_tlast,
		input wire  eth_rxd_tvalid,

		output wire  eth_rxs_tready,
		input wire [C_eth_rxs_TDATA_WIDTH-1 : 0] eth_rxs_tdata,
		input wire [(C_eth_rxs_TDATA_WIDTH/8)-1 : 0] eth_rxs_tkeep,
		input wire  eth_rxs_tlast,
		input wire  eth_rxs_tvalid,
		
		input wire data_aclk,
        output wire data_tready,
        input wire [C_data_TDATA_WIDTH-1 : 0] data_tdata,
        input wire [(C_data_TDATA_WIDTH/8)-1 : 0] data_tkeep,
        input wire data_tlast,
        input wire data_tvalid
	);
    
    //MAC адрес блока
    wire [7 : 0] self_mac_addr[0 : 5];

    //IP адрес блока
    (* mark_debug *) wire [7 : 0] self_ip_addr[0 : 3];  
    
    //Счетчик для циклов
    integer i;
    
    //Буфер служебной информации связанной с входящими UDP пакетами
    wire [127 : 0] recv_udp_ctrl_din;
    wire recv_udp_ctrl_we;
    wire recv_udp_ctrl_full;
             
    wire recv_udp_ctrl_re;
    wire [127 : 0] recv_udp_ctrl_dout;
    wire recv_udp_ctrl_empty;
    
    //Буфер данных входящих UDP пакетов     
    wire [31 : 0] recv_udp_data_din;
    wire recv_udp_data_we;
    wire recv_udp_data_full;
             
    wire recv_udp_data_re;
    wire [31 : 0] recv_udp_data_dout;
    wire recv_udp_data_empty;      
    
    //Буфер служебной информации связанной с исходящими UDP пакетами      
    wire [127 : 0] send_udp_ctrl_din;
    wire send_udp_ctrl_we;
    wire send_udp_ctrl_full;
             
    wire send_udp_ctrl_re;
    wire [127 : 0] send_udp_ctrl_dout;
    wire send_udp_ctrl_empty;  
    
    //Буфер данных исходящих UDP пакетов     
    wire [31 : 0] send_udp_data_din;
    wire send_udp_data_we;
    wire send_udp_data_full;
                  
    wire send_udp_data_re;
    wire [31 : 0] send_udp_data_dout;
    wire send_udp_data_empty;
    
    //Сигналы чтения из буфера запросов на передачу ARP ответов
    wire [79 : 0] fifo_arp_answer_dout;
    wire fifo_arp_answer_re;
    wire fifo_arp_answer_empty;
    
    //Сигналы записи в буфер запросов на передачу ARP ответов
    wire [79 : 0] fifo_arp_answer_din;
    wire fifo_arp_answer_we;
    wire fifo_arp_answer_full;
    
    //Служебная информация связанная с входящим пакетом
    reg [31 : 0] recv_ctrl[0 : 5]; 

    //MAC адрес получателя входящего пакета  
    reg [7 : 0] recv_dst_mac_addr[0 : 5];

    //MAC адрес отправителя входящего пакета 
    reg [7 : 0] recv_src_mac_addr[0 : 5];
    
    //Размер входящего IP пакета
    reg [15 : 0] recv_ip_pkg_size;

    //Идентификатор входящего IP пакета
    reg [15 : 0] recv_ip_id;
    
    //Тип пакета вложенного в IP
    reg [7 : 0] recv_ip_protocol;
    
    //Контрольная сумма заголовка IP пакета
    reg [7 : 0] recv_ip_hdr_crc;
    
    //IP адрес получателя входящего пакета
    (* mark_debug *) reg [7 : 0] recv_dst_ip_addr[0 : 3];
        
    //IP адрес отправителя входящего пакета 
    reg [7 : 0] recv_src_ip_addr[0 : 3];
    
    //Младшее слово UDP данных
    reg [15 : 0] recv_udp_data_din_lo;
    
    //Порт отправителя UDP пакета
    reg [15 : 0] recv_udp_src_port;
    
    //Порт получателя UDP пакета
    reg [15 : 0] recv_udp_dst_port;

    //Контрольная сумма UDP пакета
    reg [15 : 0] recv_udp_crc;
    
    //Размер UDP пакета
    reg [15 : 0] recv_udp_size;
    
    //Заголовок отправляемого UDP пакета
    reg [15 : 0] send_udp_hdr[0 : 3]; 
                                        
    //Размер отправляемых UDP данных
    reg [15 : 0] send_udp_data_size;
                                     
    //Размер отправляемого UDP пакета
    reg [15 : 0] send_udp_pkg_size;
    
    //Состояние автомата управляющего обработкой входящих пакетов
	(* mark_debug *) reg [4 : 0] recv_state;

    //Служебная информация связанная с исходящим пакетом
    reg [31 : 0] send_ctrl[0 : 5];
    
    //Счетчик управляющий передачей служебной информации
    reg [2 : 0] send_ctrl_counter;
    
    //ETH заголовок передаваемого пакета
    reg [15 : 0] send_eth_hdr[0 : 6];
    
    //Отправляемый ARP пакет
    reg [15 : 0] send_arp_data[0 : 13];
    
    //Счетчик управляющий отправкой пакета
    reg [5 : 0] send_arp_pkg_size;
    
    //Состояние конечного автомата управляющего отправкой пакетов
    (* mark_debug *) reg [4 : 0] send_state;
    
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
    reg [2 : 0] ip_crc_calc_counter;
    
	always @(posedge ctrl_aclk) begin
		if (ctrl_aresetn == 1'b0) begin
			//Сброс автомата управляющего обработкой входящих пакетов
			recv_state <= 0;
	    end else begin    
			//Автомат управляющий обработкой входящих пакетов
			case(recv_state)
				0: begin //Получение служебной информации связанной с входящим пакетом
					if(eth_rxs_tvalid == 1) begin
						for(i = 0; i < 5; i = i + 1) begin
                            recv_ctrl[i] <= recv_ctrl[i + 1];
						end
						  
						recv_ctrl[5] <= eth_rxs_tdata;    
						
						if(eth_rxs_tlast == 1) begin
                            recv_state <= 1;
                        end
					end
				end
				1: begin //Прием ETH заголовка
                    if(eth_rxd_tvalid == 1) begin
                        recv_dst_mac_addr[5] <= eth_rxd_tdata[7 : 0]; //Сохраняем часть MAC адреса получателя пакета 
                        recv_dst_mac_addr[4] <= eth_rxd_tdata[15 : 8];
                        recv_dst_mac_addr[3] <= eth_rxd_tdata[23 : 16];
                        recv_dst_mac_addr[2] <= eth_rxd_tdata[31 : 24];
                        
                        recv_state <= 2;
                    end
                end	
				2: begin //Прием ETH заголовка
                    if(eth_rxd_tvalid == 1) begin
                        recv_dst_mac_addr[1] <= eth_rxd_tdata[7 : 0]; //Сохраняем часть MAC адреса получателя пакета
                        recv_dst_mac_addr[0] <= eth_rxd_tdata[15 : 8];
                        
                        recv_src_mac_addr[5] <= eth_rxd_tdata[23 : 16]; //Сохраняем часть MAC адреса отправителя пакета
                        recv_src_mac_addr[4] <= eth_rxd_tdata[31 : 24];
                        
                        recv_state <= 3;
                    end
                end
                3: begin //Прием ETH заголовка
                    if(eth_rxd_tvalid == 1) begin
                        recv_src_mac_addr[3] <= eth_rxd_tdata[7 : 0]; //Сохраняем часть MAC адреса отправителя пакета
                        recv_src_mac_addr[2] <= eth_rxd_tdata[15 : 8];                
                        recv_src_mac_addr[1] <= eth_rxd_tdata[23 : 16];
                        recv_src_mac_addr[0] <= eth_rxd_tdata[31 : 24];
                                 
                        recv_state <= 4;
                    end
                end
                4: begin //Завершаем прием ETH заголовка
                    if(eth_rxd_tvalid == 1) begin
                        //Проверяем поле EtherType
                        if({eth_rxd_tdata[7 : 0], eth_rxd_tdata[15 : 8]} == 16'h0800) begin //IP пакет 
                            if(eth_rxd_tdata[23 : 20] == 4'h4 && eth_rxd_tdata[19 : 16] == 4'h5) begin //Проверяем версию IP протокола и размер IP заголовка
                                recv_state <= 5;
                            end else begin
                                //Формат IP заголовка не поддерживается, отбрасываем пакет
                                recv_state <= 21;
                            end
                        end else if({eth_rxd_tdata[7 : 0], eth_rxd_tdata[15 : 8]} == 16'h0806) begin //ARP пакет
                            if({eth_rxd_tdata[23 : 16], eth_rxd_tdata[31 : 24]} == 16'h0001) begin //Проверяем поле HTYPE, которое должно быть равно 0x0001 (Ethernet)
                                recv_state <= 12;
                            end else begin
                                //Поступивший ARP запрос не поддерживается
                                recv_state <= 21;
                            end
                        end else begin //Не поддерживаемый ядром паке
                            recv_state <= 21;
                        end
                    end
                end
                5: begin //Прием IP заголовка 
                    if(eth_rxd_tvalid == 1) begin
                        recv_ip_pkg_size <= {eth_rxd_tdata[7 : 0], eth_rxd_tdata[15 : 8]}; //Сохраняем размер входящего IP пакета
                    
                        recv_ip_id <= {eth_rxd_tdata[23 : 16], eth_rxd_tdata[31 : 24]}; //Сохраняем идентификатор входящего IP пакета
                        
                        //Проверяем MAC адрес получателя (принимаем только "свой" пакет) 
                        if({recv_dst_mac_addr[0], recv_dst_mac_addr[1], recv_dst_mac_addr[2], recv_dst_mac_addr[3], recv_dst_mac_addr[4], recv_dst_mac_addr[5]} == {self_mac_addr[0], self_mac_addr[1], self_mac_addr[2], self_mac_addr[3], self_mac_addr[4], self_mac_addr[5]}) begin                        
                            recv_state <= 6;
                        end else begin
                            recv_state <= 21;
                        end
                    end
                end
                6: begin //Прием IP заголовка
                    if(eth_rxd_tvalid == 1) begin
                        //Сохраняем тип пакета вложенного в IP 
                        recv_ip_protocol <= eth_rxd_tdata[31 : 24]; 
                        
                        recv_state <= 7;
                    end
                end    					
                7: begin //Прием IP заголовка
                    if(eth_rxd_tvalid == 1) begin
                        //Сохраняем контрольную сумму заголовка IP пакета
                        recv_ip_hdr_crc <= {eth_rxd_tdata[7 : 0], eth_rxd_tdata[15 : 8]};  
                        
                        //Сохраняем часть IP адреса отправителя пакета
                        recv_src_ip_addr[3] <= eth_rxd_tdata[23 : 16];
                        recv_src_ip_addr[2] <= eth_rxd_tdata[31 : 24]; 
                                               
                        recv_state <= 8;
                    end
                end
                8: begin //Прием IP заголовка
                    if(eth_rxd_tvalid == 1) begin
                        //Сохраняем часть IP адреса отправителя пакета
                        recv_src_ip_addr[1] <= eth_rxd_tdata[7 : 0];
                        recv_src_ip_addr[0] <= eth_rxd_tdata[15 : 8]; 
                        
                        //Сохраняем часть IP адреса получателя пакета
                        recv_dst_ip_addr[3] <= eth_rxd_tdata[23 : 16];
                        recv_dst_ip_addr[2] <= eth_rxd_tdata[31 : 24];
                                               
                        recv_state <= 9;
                    end
                end                
                9: begin //Завершаем прием IP заголовка
                    if(eth_rxd_tvalid == 1) begin
                        //Сохраняем часть IP адреса получателя пакета
                        recv_dst_ip_addr[1] <= eth_rxd_tdata[7 : 0];
                        recv_dst_ip_addr[0] <= eth_rxd_tdata[15 : 8]; 
                        
                        //Проверяем IP адрес назначения
                        if({eth_rxd_tdata[15 : 8], eth_rxd_tdata[7 : 0], recv_dst_ip_addr[2], recv_dst_ip_addr[3]} == {self_ip_addr[0], self_ip_addr[1], self_ip_addr[2], self_ip_addr[3]}) begin
                            //Проверяем тип пакета вложенного в IP 
                            if(recv_ip_protocol == 8'h11) begin //UDP пакет
                                //Сохраняем порт отправителя UDP пакета
                                recv_udp_src_port <= {eth_rxd_tdata[23 : 16], eth_rxd_tdata[31 : 24]};
                                
                                recv_state <= 19;                                               
                            end else begin //Не поддерживаемый ядром пакет
                                recv_state <= 21;                       
                            end
                        end else begin
                            //Отбрасываем пакет, так как указан не верный IP адрес назначения
                            recv_state <= 21;
                        end                
                    end
                end
                19: begin //Прием UDP заголовка
                    if(eth_rxd_tvalid == 1) begin
                        //Сохраняем порт получателя UDP пакета
                        recv_udp_dst_port <= {eth_rxd_tdata[7 : 0], eth_rxd_tdata[15 : 8]};
                       
                        //Сохраняем размер UDP пакета
                        recv_udp_size <= {eth_rxd_tdata[23 : 16], eth_rxd_tdata[31 : 24]} - 8;
                        
                        recv_state <= 20;                                     
                    end
                end
                20: begin //Прием UDP заголовка 
                    if(eth_rxd_tvalid == 1) begin
                        //Сохраняем контрольную сумму UDP пакета
                        recv_udp_crc <= {eth_rxd_tdata[7 : 0], eth_rxd_tdata[15 : 8]};
                        
                        //Первое слово данных UDP пакета
                        recv_udp_data_din_lo <= eth_rxd_tdata[31 : 16];
                        
                        //Не проверяя порт назначения UDP пакета переходим к приему UDP данных
                        recv_state <= 22;                                     
                    end
                end   
                22: begin //Прием UDP данных
                    if(eth_rxd_tvalid == 1 && recv_udp_data_full == 0) begin
                        //Буферизируем старшие два байта 
                        recv_udp_data_din_lo <= eth_rxd_tdata[31 : 16]; 
                                                        
                        if(eth_rxd_tlast == 1) begin
                            if(eth_rxd_tkeep == 3 || eth_rxd_tkeep == 1) begin
                                recv_state <= 29;
                            end else begin
                                recv_state <= 28;
                            end            
                        end
                    end    
                end
                28: begin //Запись последнего слова UDP данных        
                    if(recv_udp_data_full == 0) begin
                        recv_state <= 29;
                    end
                end
                29: begin //Запись служебной информации связанной с входящим UDP пакетом
                    if(recv_udp_ctrl_full == 0) begin
                        recv_state <= 0;
                    end                
                end
                21: begin //Отбрасываем ошибочный пакет, принимаем "хвост" пакета  
                    if(eth_rxd_tvalid == 1 && eth_rxd_tlast == 1) begin
                        recv_state <= 0;        
                    end       
                end
			endcase
	    end 
	end       
    
    //Буфер служебной информации связанной с входящими UDP пакетами
    fifo128x128x16 udp_recv_ctrl_buf_i 
    (
        .rst(~ctrl_aresetn),
     
        .wr_clk(ctrl_aclk),      
        .din(recv_udp_ctrl_din),
        .wr_en(recv_udp_ctrl_we),
        .full(recv_udp_ctrl_full),
             
        .rd_clk(ctrl_aclk),     
        .rd_en(recv_udp_ctrl_re),
        .dout(recv_udp_ctrl_dout),
        .empty(recv_udp_ctrl_empty)
    );  
    
    assign recv_udp_ctrl_din = {recv_udp_size,
                                recv_udp_dst_port,
                                recv_udp_src_port,
                                recv_src_ip_addr[2],
                                recv_src_ip_addr[3],
                                recv_src_ip_addr[0],
                                recv_src_ip_addr[1],
                                recv_src_mac_addr[4], 
                                recv_src_mac_addr[5], 
                                recv_src_mac_addr[2], 
                                recv_src_mac_addr[3], 
                                recv_src_mac_addr[0], 
                                recv_src_mac_addr[1]}; 
    
    assign recv_udp_ctrl_we = (recv_state == 29); 
    
    //Буфер данных входящих UDP пакетов
    fifo32x32x2048 udp_recv_data_buf_i 
    (
        .rst(~ctrl_aresetn),
     
        .wr_clk(ctrl_aclk),      
        .din(recv_udp_data_din),
        .wr_en(recv_udp_data_we),
        .full(recv_udp_data_full),
             
        .rd_clk(ctrl_aclk),     
        .rd_en(recv_udp_data_re),
        .dout(recv_udp_data_dout),
        .empty(recv_udp_data_empty)
    );      
    
    assign recv_udp_data_din = {eth_rxd_tdata[15 : 0], recv_udp_data_din_lo};   
    assign recv_udp_data_we = ((recv_state == 22) && (eth_rxd_tvalid == 1)) || (recv_state == 28);
    
    //Буфер служебной информации связанной с исходящими UDP пакетами
    fifo128x128x16 udp_send_ctrl_buf_i 
    (
        .rst(~ctrl_aresetn),
     
        .wr_clk(ctrl_aclk),      
        .din(send_udp_ctrl_din),
        .wr_en(send_udp_ctrl_we),
        .full(send_udp_ctrl_full),
             
        .rd_clk(ctrl_aclk),     
        .rd_en(send_udp_ctrl_re),
        .dout(send_udp_ctrl_dout),
        .empty(send_udp_ctrl_empty)
    );  
    
    //Сигналы чтения из буфера служебной информации связанной с исходящими UDP пакетами
    assign send_udp_ctrl_re = (send_state == 10);
    
    //Буфер данных исходящих UDP пакетов
    fifo32x32x2048 udp_send_data_buf_i 
    (
        .rst(~ctrl_aresetn),
     
        .wr_clk(ctrl_aclk),      
        .din(send_udp_data_din),
        .wr_en(send_udp_data_we),
        .full(send_udp_data_full),
             
        .rd_clk(ctrl_aclk),     
        .rd_en(send_udp_data_re),
        .dout(send_udp_data_dout),
        .empty(send_udp_data_empty)
    );   
    
    //Сигналы чтения из буфера данных исходящих UDP пакетов 
    assign send_udp_data_re = (send_state == 13) && (send_udp_data_size != 0) && (eth_txd_tready == 1);
    
    //Интерфейс приема служебной информации
    assign eth_rxs_tready = (recv_state == 0);

    //Интерфейс приема пакетов
    assign eth_rxd_tready = ((recv_state != 0) && (recv_state != 23) && (recv_state != 24) && (recv_state != 25) && (recv_state != 26) && (recv_state != 27) && (recv_state != 28) && (recv_state != 29)) ||  
                            ((recv_state == 24) && (fifo_ping_data_full == 0));
                             
    always @(posedge ctrl_aclk) begin
        if (ctrl_aresetn == 1'b0) begin
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
                    if(fifo_arp_answer_empty == 0 || fifo_ping_answer_empty == 0 || send_udp_ctrl_empty == 0) begin
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
                            
                            if(fifo_arp_answer_empty == 0) begin //Запрос на передачу ARP ответа
                                send_state <= 2;
                            end else if(fifo_ping_answer_empty == 0) begin //Запрос на передачу PING пакета
                                send_state <= 4;    
                            end else if(send_udp_ctrl_empty == 0) begin //Запрос на передачу UDP пакета
                                send_state <= 10;    
                            end
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
        .clk(ctrl_aclk),
        .rst(~ctrl_aresetn),
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
     
    
    assign icmp_crc_calc_din = icmp_crc_calc_din_mux;   
    assign icmp_crc_calc_en = (send_state == 7);
    assign icmp_crc_calc_sop = (icmp_crc_calc_counter == 2);
    assign icmp_crc_calc_eop = (icmp_crc_calc_counter == 0); 
    
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
        else if((send_state == 9 &&send_ping_pkg_size == 1) || (send_state == 13 || send_udp_pkg_size == 1)) 
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
