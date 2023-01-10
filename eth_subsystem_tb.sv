module eth_sub_tb();

bit clk_r;
bit rst_r;

bit [31:0]	eth_rxd_tdata_r;
bit [3:0] 	eth_rxd_tkeep_r;
bit  		eth_rxd_tlast_r;
bit  		eth_rxd_tvalid_r;

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

eth_hw_core_v1_0 
eth_hw_core_v1_0_inst
(
	.eth_txd_tvalid(),
	.eth_txd_tdata(),
	.eth_txd_tkeep(),
	.eth_txd_tlast(),
	.eth_txd_tready(),

	.eth_txc_tvalid(),
	.eth_txc_tdata(),
	.eth_txc_tkeep(),
	.eth_txc_tlast(),
	.eth_txc_tready(),
	
	.eth_rxd_tready(),
	.eth_rxd_tdata(),
	.eth_rxd_tkeep(),
	.eth_rxd_tlast(),
	.eth_rxd_tvalid(),
	
	.eth_rxs_tready(),
	.eth_rxs_tdata(),
	.eth_rxs_tkeep(),
	.eth_rxs_tlast(),
	.eth_rxs_tvalid(),
		
	.data_aclk(),
    .data_tready(),
    .data_tdata(),
    .data_tkeep(),
    .data_tlast(),
    .data_tvalid()
);


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

	// Инициализация заголовков пакетов для тестирования
	udp_packet lfm_pkg;
	lfm_pkg.eth_dest_mac_r = {8'h02, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
	lfm_pkg.eth_src_mac_r = {8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
	lfm_pkg.eth_type_r = 16'h0800;
	lfm_pkg.ip_version_r = 4'h4;
	lfm_pkg.ip_ihl_r = 4'h5;
	lfm_pkg.ip_dscp_r = {}; 
	lfm_pkg.ip_ecn_r = {}; 
	lfm_pkg.ip_length_r = {}; 
	lfm_pkg.ip_identification_r = {}; 
	lfm_pkg.ip_flags_r = {}; 
	lfm_pkg.ip_fragment_offset_r = {}; 
	lfm_pkg.ip_ttl_r = {}; 
	lfm_pkg.ip_protocol_r = {}; 
	lfm_pkg.ip_header_checksum_r = {}; 
	lfm_pkg.ip_source_ip_r = {}; 
	lfm_pkg.ip_dest_ip_r = {}; 
	lfm_pkg.udp_source_port_r = {}; 
	lfm_pkg.udp_dest_port_r = {};
	lfm_pkg.udp_length_r = {}; 
	lfm_pkg.udp_checksum_r = {}; 
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
	eth_rxd_tdata_r = [0];
	eth_rxd_tvalid_r = 1;
	@(posedge clk_r);
	for (integer i = 1; i < 1024; i = i + 1) begin
		@(posedge clk_r);
		eth_rxd_tdata_r = [i];
	end
	#9.9;
	eth_rxd_tvalid_r = 0;
end

endmodule