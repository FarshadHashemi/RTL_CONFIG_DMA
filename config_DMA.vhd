library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity config_DMA is
 Port(
  aclk : in std_logic ;
  aresetn : in std_logic ;
  
  s_axis_config_tvalid : in std_logic ;
  s_axis_config_tready : out std_logic ;
  s_axis_config_tdata : in std_logic_vector(39 downto 0) ;
  
  m_axis_start_tvalid : out std_logic ;
  m_axis_start_tready : in std_logic ;
  
  s2mm_interrupt      : in std_logic ;
  mm2s_interrupt      : in std_logic ;
  
  m_axi_lite_araddr  : out std_logic_vector(9 downto 0) := (others=>'0') ;
  m_axi_lite_arready : in  std_logic ;
  m_axi_lite_arvalid : out std_logic := '0' ;
  m_axi_lite_awaddr  : out std_logic_vector(9 downto 0) ;
  m_axi_lite_awready : in  std_logic ;
  m_axi_lite_awvalid : out std_logic ;
  m_axi_lite_bready  : out std_logic := '1' ;
  m_axi_lite_bresp   : in  std_logic_vector(1 downto 0) ;
  m_axi_lite_bvalid  : in  std_logic ;
  m_axi_lite_rdata   : in  std_logic_vector(31 downto 0) ;
  m_axi_lite_rready  : out std_logic := '1' ;
  m_axi_lite_rresp   : in  std_logic_vector(1 downto 0) ;
  m_axi_lite_rvalid  : in  std_logic ;
  m_axi_lite_wdata   : out std_logic_vector(31 downto 0) ;
  m_axi_lite_wready  : in  std_logic ;
  m_axi_lite_wvalid  : out std_logic 
  
 ) ;
end config_DMA ;

architecture Behavioral of config_DMA is
 
 type t_state is (s_config,
                  s_s2mm_0, s_s2mm_1, s_s2mm_2, s_s2mm_3, s_s2mm_4, s_s2mm_5, s_s2mm_start, s_s2mm_finish, s_s2mm_interrupt0, s_s2mm_interrupt1,
                  s_mm2s_0, s_mm2s_1, s_mm2s_2, s_mm2s_3, s_mm2s_4, s_mm2s_5, s_mm2s_finish, s_mm2s_interrupt0, s_mm2s_interrupt1);
 
 constant s2mm_packet_length : std_logic_vector(31 downto 0) := X"0200_0000" ; -- 32MB
 constant mm2s_packet_length : std_logic_vector(31 downto 0) := X"0000_0400" ; --  1KB
 
 constant S2MM_DMASR         : std_logic_vector( 9 downto 0) := "0000110100" ; -- x"34"
 constant S2MM_DA            : std_logic_vector( 9 downto 0) := "0001001000" ; -- x"48"
 constant S2MM_DMACR         : std_logic_vector( 9 downto 0) := "0000110000" ; -- x"30"
 constant S2MM_LENGTH        : std_logic_vector( 9 downto 0) := "0001011000" ; -- x"58"
 
 constant MM2S_DMASR         : std_logic_vector( 9 downto 0) := "0000000100" ; -- x"04"
 constant MM2S_SA            : std_logic_vector( 9 downto 0) := "0000011000" ; -- x"18"
 constant MM2S_DMACR         : std_logic_vector( 9 downto 0) := "0000000000" ; -- x"00"
 constant MM2S_LENGTH        : std_logic_vector( 9 downto 0) := "0000101000" ; -- x"28"
 
 constant DMA_Run            : std_logic_vector(31 downto 0) := X"0000_1001" ;
 
 constant IOC_Irq            : std_logic_vector(31 downto 0) := X"0000_1000" ; -- x"34"
 signal   length             : std_logic_vector(31 downto 0) := (others=>'0') ;
 
 Signal   dest_addr          : std_logic_vector(31 downto 0) := X"0000_0000" ; 
 Signal   src_addr           : std_logic_vector(31 downto 0) := X"0000_0000" ;
 
 signal   r_state            : t_state                       := s_config ;
 
 signal cnt : integer range 0 to 63 := 0 ;
 
 signal s_axis_config_tvalid1 : std_logic := '1' ;
 
begin
 
 process(aclk) begin
  if rising_edge(aclk) then
   if aresetn='0' then
    r_state <= s_config ;
    dest_addr <= (others=>'0') ; 
    src_addr <= (others=>'0') ; 
   else
    
    s_axis_config_tvalid1 <= s_axis_config_tvalid ;
    
    case r_state is 
     when s_config=>
      if s_axis_config_tvalid='1' and s_axis_config_tvalid1='0' then
       dest_addr <= (others=>'0') ; 
       src_addr <= (others=>'0') ; 
       length <= s_axis_config_tdata(39 downto 8) ;
       if s_axis_config_tdata(7 downto 0)=X"00" then
        r_state <= s_s2mm_interrupt0 ;
       elsif s_axis_config_tdata(7 downto 0)=X"01" then
        r_state <= s_mm2s_interrupt0 ;
       end if ;
      end if ;
     
     when s_s2mm_interrupt0 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_s2mm_interrupt1 ; 
      end if ;
     
     when s_s2mm_interrupt1 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_s2mm_0 ; 
      end if ;
     
     when s_s2mm_0 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_s2mm_1 ; 
       dest_addr <= std_logic_vector(unsigned(dest_addr) + unsigned(s2mm_packet_length)) ;
      end if ;
      
     when s_s2mm_1 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_s2mm_2 ; 
      end if ;
     
     when s_s2mm_2 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_s2mm_3 ; 
      end if ;
      
     when s_s2mm_3 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_s2mm_4 ; 
      end if ;
     
     when s_s2mm_4 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_s2mm_5 ; 
      end if ;
      
     when s_s2mm_5 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_s2mm_start ; 
      end if ;
     
     when s_s2mm_start =>
      if m_axis_start_tready='1' then
       r_state <= s_s2mm_finish ; 
      end if ;
     
     when s_s2mm_finish =>
      if s2mm_interrupt='1' then
       if dest_addr=length then
        r_state <= s_config ;
       else
        r_state <= s_s2mm_interrupt0 ;
       end if ;
      end if ;
     
     when s_mm2s_interrupt0 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_mm2s_interrupt1 ; 
      end if ;
     
     when s_mm2s_interrupt1 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_mm2s_0 ; 
      end if ;
      
     
     when s_mm2s_0 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_mm2s_1 ; 
       src_addr <= std_logic_vector(unsigned(src_addr) + unsigned(mm2s_packet_length)) ;
      end if ;
      
     when s_mm2s_1 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_mm2s_2 ; 
      end if ;
     
     when s_mm2s_2 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_mm2s_3 ; 
      end if ;
      
     when s_mm2s_3 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_mm2s_4 ; 
      end if ;
     
     when s_mm2s_4 =>
      if (m_axi_lite_wready and m_axi_lite_awready)='1' then
       r_state <= s_mm2s_5 ; 
      end if ;
      
     when s_mm2s_5 =>
      if m_axi_lite_bvalid='1' then
       r_state <= s_mm2s_finish ; 
      end if ;
     
     when s_mm2s_finish =>
      if mm2s_interrupt='1' then
       if src_addr=length then
        r_state <= s_config ;
       else
        r_state <= s_mm2s_interrupt0 ;
       end if ;
      end if ;
     
    end case ;
    
   end if ;
  end if ;
 end process;
 
 s_axis_config_tready <= '1' when r_state=s_config      else '0' ;
 m_axis_start_tvalid  <= '1' when r_state=s_s2mm_start  else '0' ; 
 
 m_axi_lite_awvalid <= '1' when r_state=s_s2mm_interrupt0 else 
                       '1' when r_state=s_s2mm_0 else 
                       '1' when r_state=s_s2mm_2 else 
                       '1' when r_state=s_s2mm_4 else 
                       '1' when r_state=s_mm2s_interrupt0 else 
                       '1' when r_state=s_mm2s_0 else 
                       '1' when r_state=s_mm2s_2 else 
                       '1' when r_state=s_mm2s_4 else 
                       '0' ;
                       
 m_axi_lite_awaddr <= S2MM_DMASR  when r_state=s_s2mm_interrupt0 else 
                      S2MM_DA     when r_state=s_s2mm_0 else 
                      S2MM_DMACR  when r_state=s_s2mm_2 else 
                      S2MM_LENGTH when r_state=s_s2mm_4 else
                      MM2S_DMASR  when r_state=s_mm2s_interrupt0 else  
                      MM2S_SA     when r_state=s_mm2s_0 else 
                      MM2S_DMACR  when r_state=s_mm2s_2 else 
                      MM2S_LENGTH when r_state=s_mm2s_4 else 
                      (others=>'0') ;
                      
 m_axi_lite_wvalid <= '1' when r_state=s_s2mm_interrupt0 else 
                      '1' when r_state=s_s2mm_0 else 
                      '1' when r_state=s_s2mm_2 else 
                      '1' when r_state=s_s2mm_4 else
                      '1' when r_state=s_mm2s_interrupt0 else 
                      '1' when r_state=s_mm2s_0 else 
                      '1' when r_state=s_mm2s_2 else 
                      '1' when r_state=s_mm2s_4 else  
                      '0' ;
                      
 m_axi_lite_wdata <= IOC_Irq            when r_state=s_s2mm_interrupt0 else 
                     dest_addr          when r_state=s_s2mm_0 else 
                     DMA_Run            when r_state=s_s2mm_2 else 
                     s2mm_packet_length when r_state=s_s2mm_4 else 
                     IOC_Irq            when r_state=s_mm2s_interrupt0 else 
                     src_addr           when r_state=s_mm2s_0 else 
                     DMA_Run            when r_state=s_mm2s_2 else 
                     mm2s_packet_length when r_state=s_mm2s_4 else 
                     (others=>'0') ;
 
end Behavioral;