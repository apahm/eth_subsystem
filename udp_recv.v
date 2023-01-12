`timescale 1 ns / 1 ps

module udp_recv 
(
    input wire  clk,
    input wire  rst,

	output wire         eth_rxd_tready,
	input wire [31 : 0] eth_rxd_tdata,
	input wire [3 : 0]  eth_rxd_tkeep,
	input wire          eth_rxd_tlast,
	input wire          eth_rxd_tvalid,

	output wire          eth_rxs_tready,
	input wire [31 : 0]  eth_rxs_tdata,
	input wire [3 : 0]   eth_rxs_tkeep,
	input wire           eth_rxs_tlast,
	input wire           eth_rxs_tvalid,

    output wire [31 : 0] m_axis_data_tdata,
    output wire          m_axis_data_tvalid,
    input  wire          m_axis_data_tready,
    output wire          m_axis_data_tlast
);
    
    wire [47:0] local_mac   = 48'h02_00_00_00_00_00;
    wire [31:0] local_ip    = {8'd192, 8'd168, 8'd1,   8'd128};
    wire [31:0] gateway_ip  = {8'd192, 8'd168, 8'd1,   8'd1};
    wire [31:0] subnet_mask = {8'd255, 8'd255, 8'd255, 8'd0};
    
    wire [31 : 0] recv_udp_data_din;
    wire recv_udp_data_we;
             
    reg [31 : 0] recv_ctrl[0 : 5]; 

    reg [7 : 0] recv_dst_mac_addr[0 : 5];
    reg [7 : 0] recv_src_mac_addr[0 : 5];
    reg [15 : 0] recv_ip_pkg_size;
    reg [15 : 0] recv_ip_id;
    reg [7 : 0] recv_ip_protocol;
    reg [7 : 0] recv_ip_hdr_crc;
    reg [7 : 0] recv_dst_ip_addr[0 : 3];
    reg [7 : 0] recv_src_ip_addr[0 : 3];
    reg [15 : 0] recv_udp_data_din_lo;
    reg [15 : 0] recv_udp_src_port;
    reg [15 : 0] recv_udp_dst_port;
    reg [15 : 0] recv_udp_crc;
    reg [15 : 0] recv_udp_size;

	reg [4 : 0] recv_state;

    integer i;

	always @(posedge clk) begin
		if (rst) begin
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
                        end
                    end
                end
                5: begin //Прием IP заголовка 
                    if(eth_rxd_tvalid == 1) begin
                        recv_ip_pkg_size <= {eth_rxd_tdata[7 : 0], eth_rxd_tdata[15 : 8]}; //Сохраняем размер входящего IP пакета
                    
                        recv_ip_id <= {eth_rxd_tdata[23 : 16], eth_rxd_tdata[31 : 24]}; //Сохраняем идентификатор входящего IP пакета
                        
                        //Проверяем MAC адрес получателя (принимаем только "свой" пакет) 
                        if({recv_dst_mac_addr[0], 
                            recv_dst_mac_addr[1], 
                            recv_dst_mac_addr[2], 
                            recv_dst_mac_addr[3], 
                            recv_dst_mac_addr[4], 
                            recv_dst_mac_addr[5]} == local_mac) begin                        
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
                        if({eth_rxd_tdata[15 : 8], eth_rxd_tdata[7 : 0], recv_dst_ip_addr[2], recv_dst_ip_addr[3]} == local_ip) begin
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
                21: begin //Отбрасываем ошибочный пакет, принимаем "хвост" пакета  
                    if(eth_rxd_tvalid == 1 && eth_rxd_tlast == 1) begin
                        recv_state <= 0;        
                    end       
                end   
                22: begin //Прием UDP данных
                    if(eth_rxd_tvalid == 1) begin
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
                    recv_state <= 0;
                end
			endcase
	    end 
	end       
    
    //Буфер данных входящих UDP пакетов
    udp_recv_data_buf 
    udp_recv_data_buf_i 
    (
        .s_aclk(clk),
        .s_aresetn(~rst),
     
        .s_axis_tdata(recv_udp_data_din),
        .s_axis_tvalid(recv_udp_data_we),
        .s_axis_tready(),
             
        .m_axis_tdata(m_axis_data_tdata),
        .m_axis_tvalid(m_axis_data_tvalid),
        .m_axis_tready(m_axis_data_tready)
    );      
    
    assign recv_udp_data_din = {eth_rxd_tdata[15 : 0], recv_udp_data_din_lo};   
    assign recv_udp_data_we = ((recv_state == 22) && (eth_rxd_tvalid == 1)) || (recv_state == 28);
    
    //Интерфейс приема служебной информации
    assign eth_rxs_tready = (recv_state == 0);

    //Интерфейс приема пакетов
    assign eth_rxd_tready = ((recv_state != 0) && (recv_state != 28));
endmodule
