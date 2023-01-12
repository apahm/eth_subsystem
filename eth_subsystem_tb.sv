module eth_sub_tb();

bit clk_r;
bit rst_r;

bit [31:0]	eth_rxd_tdata_r;
bit [3:0] 	eth_rxd_tkeep_r;
bit  		eth_rxd_tlast_r;
bit  		eth_rxd_tvalid_r;
bit 		eth_rxd_tlast_r;

wire  	eth_rxd_tready;
wire 	eth_rxs_tready;

bit [31:0]	eth_rxs_tdata_r;
bit [3:0] 	eth_rxs_tkeep_r;
bit  		eth_rxs_tlast_r;
bit  		eth_rxs_tvalid_r;

bit [31:0] eth_pkg_reg [63:0];

typedef struct {
	bit [47:0] eth_dest_mac_r;
	bit [47:0] eth_src_mac_r;
	bit [15:0] eth_type_r;
	bit [3:0]  ip_version_r;
	bit [3:0]  ip_ihl_r;
	bit [5:0]  ip_dscp_r;
	bit [1:0]  ip_ecn_r;
	bit [15:0] ip_length_r;
	bit [15:0] ip_identification_r;
	bit [2:0]  ip_flags_r;
	bit [12:0] ip_fragment_offset_r;
	bit [7:0]  ip_ttl_r;
	bit [7:0]  ip_protocol_r;
	bit [15:0] ip_header_checksum_r;
	bit [31:0] ip_source_ip_r;
	bit [31:0] ip_dest_ip_r;
	bit [15:0] udp_source_port_r;
	bit [15:0] udp_dest_port_r;
	bit [15:0] udp_length_r;
	bit [7:0]  udp_payload [1023:0];
	bit [15:0] udp_checksum_r;
} udp_packet;

wire [31:0] recv_udp_tdata;
wire        recv_udp_tvalid;
wire        recv_udp_tready;
wire        recv_udp_tlast;

wire [31:0] transmit_udp_tdata;
wire        transmit_udp_tvalid;
wire        transmit_udp_tready;
wire        transmit_udp_tlast;
                     
udp_recv
udp_recv_inst
(
    .clk(clk),
    .rst(rst),

    .eth_rxd_tready(m_axis_rxd_tdata),
    .eth_rxd_tdata(m_axis_rxd_tkeep),
    .eth_rxd_tkeep(m_axis_rxd_tlast),
    .eth_rxd_tlast(m_axis_rxd_tready),
    .eth_rxd_tvalid(m_axis_rxd_tvalid),

    .eth_rxs_tready(m_axis_rxs_tdata),
    .eth_rxs_tdata(m_axis_rxs_tkeep),
    .eth_rxs_tkeep(m_axis_rxs_tlast),
    .eth_rxs_tlast(m_axis_rxs_tready),
    .eth_rxs_tvalid(m_axis_rxs_tvalid),

    .m_axis_data_tdata(recv_udp_tdata),
    .m_axis_data_tvalid(recv_udp_tvalid),
    .m_axis_data_tready(recv_udp_tready),
    .m_axis_data_tlast(recv_udp_tlast)  
);

udp_transmit
udp_transmit_inst
(
    .clk(clk),
    .rst(rst),

    .eth_txd_tvalid(s_axis_txd_tdata),
    .eth_txd_tdata(s_axis_txd_tkeep),
    .eth_txd_tkeep(s_axis_txd_tlast),
    .eth_txd_tlast(s_axis_txd_tready),
    .eth_txd_tready(s_axis_txd_tvalid),

    .eth_txc_tvalid(s_axis_txc_tdata),
    .eth_txc_tdata(s_axis_txc_tkeep),
    .eth_txc_tkeep(s_axis_txc_tlast),
    .eth_txc_tlast(s_axis_txc_tready),
    .eth_txc_tready(s_axis_txc_tvalid),

    .s_axis_data_tdata(transmit_udp_tdata),
    .s_axis_data_tvalid(transmit_udp_tvalid),
    .s_axis_data_tready(transmit_udp_tready),
    .s_axis_data_tlast(transmit_udp_tlast)
);

udp_complete_fifo
udp_complete_fifo_inst
(
    .s_aclk(clk),
    .s_aresetn(~rst),
     
    .s_axis_tdata(recv_udp_tdata),
    .s_axis_tvalid(recv_udp_tvalid),
    .s_axis_tready(recv_udp_tready),
    .s_axis_tlast(recv_udp_tlast),

    .m_axis_tdata(transmit_udp_tdata),
    .m_axis_tvalid(transmit_udp_tvalid),
    .m_axis_tready(transmit_udp_tready),
    .m_axis_tlast(transmit_udp_tlast)
);

udp_packet lfm_pkg;

initial begin
	rst_r = 1'b0;
	eth_rxd_tdata_r = 32'b0;
	eth_rxd_tkeep_r = 4'b0;
	eth_rxd_tlast_r = 1'b0;
	eth_rxd_tvalid_r = 1'b0;

	eth_rxs_tdata_r = 32'b0;
	eth_rxs_tkeep_r = 4'b0;
	eth_rxs_tlast_r = 1'b0;
	eth_rxs_tvalid_r = 1'b0;

	lfm_pkg.eth_dest_mac_r = {8'h02, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
	lfm_pkg.eth_src_mac_r = {8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
	lfm_pkg.eth_type_r = 16'h0800;
	lfm_pkg.ip_version_r = 4'h4;
	lfm_pkg.ip_ihl_r = 4'h5;
	lfm_pkg.ip_dscp_r = 5'b0; 
	lfm_pkg.ip_ecn_r = 2'b0; 
	lfm_pkg.ip_length_r = 16'h0; 
	lfm_pkg.ip_identification_r = 16'h0; 
	lfm_pkg.ip_flags_r = 3'b0; 
	lfm_pkg.ip_fragment_offset_r = 13'h0; 
	lfm_pkg.ip_ttl_r = 8'h80; 
	lfm_pkg.ip_protocol_r = 8'h11; 
	lfm_pkg.ip_header_checksum_r = 16'h0000; 
	lfm_pkg.ip_source_ip_r = 32'h0; 
	lfm_pkg.ip_dest_ip_r = 32'h0; 
	lfm_pkg.udp_source_port_r = 16'h0; 
	lfm_pkg.udp_dest_port_r = 16'h0;
	lfm_pkg.udp_length_r = 16'h0; 
	lfm_pkg.udp_checksum_r = 16'h0; 
	for (int i = 0; i < count; i = i + 1) begin
		lfm_pkg.udp_payload[i] = i;
	end

	eth_pkg_reg[0] = lfm_pkg.eth_dest_mac_r[31:0];
	eth_pkg_reg[1] = {lfm_pkg.eth_dest_mac_r[47:32], lfm_pkg.eth_src_mac_r[47:32]};
	eth_pkg_reg[2] = lfm_pkg.eth_src_mac_r[31:0];
	eth_pkg_reg[3] = {	lfm_pkg.eth_type_r, 
						lfm_pkg.ip_version_r, 
						lfm_pkg.ip_ihl_r, 
						lfm_pkg.ip_dscp_r,
						lfm_pkg.ip_ecn_r};
	eth_pkg_reg[4] = {lfm_pkg.ip_length_r, lfm_pkg.ip_identification_r};
	eth_pkg_reg[5] = {lfm_pkg.ip_flags_r, lfm_pkg.ip_fragment_offset_r, lfm_pkg.ip_ttl_r, lfm_pkg.ip_protocol_r};
	eth_pkg_reg[6] = {lfm_pkg.ip_header_checksum_r, lfm_pkg.ip_source_ip_r};
	eth_pkg_reg[7] = {lfm_pkg.ip_dest_ip_r, lfm_pkg.udp_source_port_r};
	eth_pkg_reg[8] = {lfm_pkg.udp_dest_port_r, lfm_pkg.udp_length_r};
	eth_pkg_reg[9] = {lfm_pkg.udp_checksum_r, lfm_pkg.udp_payload[0], lfm_pkg.udp_payload[1]};

	for (int i = 0; i < count; i++) begin
		eth_pkg_reg[i + 10] = {	lfm_pkg.udp_payload[3*i + 3], 
								lfm_pkg.udp_payload[3*i + 4], 
								lfm_pkg.udp_payload[3*i + 5], 
								lfm_pkg.udp_payload[3*i + 6]};
	end

	wait(eth_rxd_tready);
	wait(eth_rxs_tready);

	@(posedge aclk_reg);
	#9.9;
	eth_rxd_tdata_r = lfm_pkg.udp_payload[0];
	eth_rxd_tvalid_r = 1;
	@(posedge clk_r);
	for (integer i = 1; i < 1024; i = i + 1) begin
		@(posedge clk_r);
		eth_rxd_tdata_r = lfm_pkg.udp_payload[i];
	end
	#9.9;
	eth_rxd_tvalid_r = 0;
end

endmodule