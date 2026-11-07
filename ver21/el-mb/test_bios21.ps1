$ErrorActionPreference='Stop'
$symbols=New-Object 'System.Collections.Generic.Dictionary[string,int]'
Get-Content (Join-Path $PSScriptRoot 'WifiBios21_MB_EL.sym') | ForEach-Object {if($_ -match '^([^:]+): EQU 0x([0-9A-Fa-f]+)'){$symbols[$matches[1]]=[Convert]::ToInt32($matches[2],16)}}
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
public class BiosCpu {
 public byte[] M=new byte[65536]; public Dictionary<string,int> S; public int Base,StepLimit=3000000; public bool Mb=true,TxBusy; public int Power=0xA4,SpeedCode,StatusOverride=-1; public Queue<byte> Rx=new Queue<byte>(); public List<int> InPorts=new List<int>(); public List<int> OutPorts=new List<int>(),OutValues=new List<int>(); public List<byte> Tx=new List<byte>(); public int AltB,AltC,AltD,AltE,AltH,AltL;
 public int A,B,C,D,E,H,L,F,AltA,AltF,PC,SP=0x6800,IX,Steps,Idle; public bool Failed;
 public string PingReply="\r\n+23\r\nOK\r\n"; public int InputKey=13; public string ScanReply=""; public bool Done; public string Scenario="",Auto="1",Mode="1",Boot="normal";
 public List<string> Commands=new List<string>(); public List<string> Messages=new List<string>();
 Queue<int> Q=new Queue<int>();
 int HL {get{return H*256+L;}set{H=(value>>8)&255;L=value&255;}}
 int DE {get{return D*256+E;}set{D=(value>>8)&255;E=value&255;}}
 int BC {get{return B*256+C;}set{B=(value>>8)&255;C=value&255;}}
 bool Z {get{return (F&64)!=0;}}
 void Flag(int v){F=(F&1)|((v&65535)==0?64:0);}
 int Byte(){return M[PC++];} int Word(){int v=Byte();return v+256*Byte();}
 void Push(int v){M[--SP]=(byte)(v>>8);M[--SP]=(byte)v;}
 int Pop(){int v=M[SP++];return v+256*M[SP++];}
 int Get(int n){switch(n){case 0:return B;case 1:return C;case 2:return D;case 3:return E;case 4:return H;case 5:return L;case 6:return M[HL];default:return A;}}
 void Set(int n,int v){v&=255;switch(n){case 0:B=v;break;case 1:C=v;break;case 2:D=v;break;case 3:E=v;break;case 4:H=v;break;case 5:L=v;break;case 6:M[HL]=(byte)v;break;default:A=v;break;}}
 public string Str(int p){int n=p;while(M[n]!=0 && n-p<512)n++;return Encoding.ASCII.GetString(M,p,n-p);}
 public void Put(int p,string s){byte[] b=Encoding.ASCII.GetBytes(s+"\0");Array.Copy(b,0,M,p,b.Length);}
 public BiosCpu(byte[] bin,Dictionary<string,int> sy,int address){S=sy;Base=address;Array.Copy(bin,0,M,Base,bin.Length);SP=0xF000;} public int Addr(string name){return (Base+((S[name]-S["bios_start"])&65535))&65535;}
 void Enqueue(string s){foreach(byte b in Encoding.ASCII.GetBytes(s))Q.Enqueue(b);}
 int Input(int port){InPorts.Add(port);
  if(port==0x773B)return Mb?0x33:0;
  if(port==0x713B)return Mb?Power:255;
  if(port==0x7D3B)return SpeedCode;
  if(port==0x133B)return StatusOverride>=0?StatusOverride:(Rx.Count>0?1:0)|(TxBusy?2:0)|(Rx.Count>=2048?4:0)|(Rx.Count>=256?8:0);
  if(port==0x143B)return Rx.Count>0?Rx.Dequeue():255;
  return 255;
 }
 void Output(int port,int value){OutPorts.Add(port);OutValues.Add(value);if(port==0x133B)Tx.Add((byte)value);if(port==0x143B)SpeedCode=value;if(port==0x713B)Power=value;if(port==0x7D3B && value==1)Rx.Clear();}
 void InputFlags(int value){int bits=0;for(int i=0;i<8;i++)bits+=(value>>i)&1;F=(F&1)|(value==0?64:0)|((bits&1)==0?4:0);}
 public void Run(string entry){PC=Addr(entry);Push(0x2000);while(!Done && PC!=0x2000){if(++Steps>StepLimit)throw new Exception("Instruction limit at "+PC.ToString("X"));int op=Byte(),v,n;
  if(op>=0x40 && op<=0x7F && op!=0x76){Set((op>>3)&7,Get(op&7));continue;}
  if((op&0xC7)==0x06){Set((op>>3)&7,Byte());continue;}
  if((op&0xC7)==0x04){n=(op>>3)&7;v=(Get(n)+1)&255;Set(n,v);Flag(v);continue;}
  if((op&0xC7)==0x05){n=(op>>3)&7;v=(Get(n)-1)&255;Set(n,v);Flag(v);continue;}
  switch(op){
   case 0x08:v=A;A=AltA;AltA=v;v=F;F=AltF;AltF=v;break;case 0x01:BC=Word();break;case 0x11:DE=Word();break;case 0x21:HL=Word();break;case 0x31:SP=Word();break;
   case 0x09:case 0x19:case 0x29:n=HL+(op==0x09?BC:op==0x19?DE:HL);HL=n&65535;F=(F&64)|(n>65535?1:0);break;case 0x10:v=(sbyte)Byte();B=(B-1)&255;if(B!=0)PC+=v;break;case 0x03:BC=(BC+1)&65535;break;case 0x0B:BC=(BC-1)&65535;break;
   case 0x13:DE=(DE+1)&65535;break;case 0x1B:DE=(DE-1)&65535;break;
   case 0x23:HL=(HL+1)&65535;break;case 0x2B:HL=(HL-1)&65535;break;
   case 0x12:M[DE]=(byte)A;break;case 0x1A:A=M[DE];break;
   case 0x22:n=Word();M[n]=(byte)L;M[n+1]=(byte)H;break;
   case 0x2A:n=Word();HL=M[n]+256*M[n+1];break;
   case 0x32:M[Word()]=(byte)A;break;case 0x3A:A=M[Word()];break;
   case 0xA8:case 0xA9:case 0xAA:case 0xAB:case 0xAC:case 0xAD:case 0xAE:A^=Get(op&7);F=A==0?64:0;break;case 0xAF:A=0;F=64;break;case 0xE6:A&=Byte();F=A==0?64:0;break;
   case 0xB0:case 0xB1:case 0xB2:case 0xB3:case 0xB4:case 0xB5:case 0xB6:case 0xB7:A|=Get(op&7);F=A==0?64:0;break;
   case 0xFE:v=Byte();F=(A==v?64:0)|(A<v?1:0);break;
   case 0xB8:case 0xB9:case 0xBA:case 0xBB:case 0xBC:case 0xBD:case 0xBE:case 0xBF:v=Get(op&7);F=(A==v?64:0)|(A<v?1:0);break;
   case 0xF6:A|=Byte();F=A==0?64:0;break;case 0x37:F|=1;break;
   case 0x18:case 0x20:case 0x28:case 0x30:case 0x38:v=(sbyte)Byte();if(op==0x18||(op==0x20&&!Z)||(op==0x28&&Z)||(op==0x30&&(F&1)==0)||(op==0x38&&(F&1)!=0))PC+=v;break;
   case 0xC3:case 0xC2:case 0xCA:case 0xD2:case 0xDA:v=Word();if(op==0xC3||(op==0xC2&&!Z)||(op==0xCA&&Z)||(op==0xD2&&(F&1)==0)||(op==0xDA&&(F&1)!=0))PC=v;break;
   case 0xCD:case 0xC4:case 0xCC:v=Word();if(op==0xCD||(op==0xC4&&!Z)||(op==0xCC&&Z)){Push(PC);PC=v;}break;
   case 0xD8:if((F&1)!=0)PC=Pop();break;case 0xD0:if((F&1)==0)PC=Pop();break;case 0xC9:PC=Pop();break;case 0xC0:if(!Z)PC=Pop();break;case 0xC8:if(Z)PC=Pop();break;
   case 0xC5:Push(BC);break;case 0xD5:Push(DE);break;case 0xE5:Push(HL);break;case 0xF5:Push(A*256+F);break;
   case 0xC1:BC=Pop();break;case 0xD1:DE=Pop();break;case 0xE1:HL=Pop();break;case 0xF1:v=Pop();A=v>>8;F=v&255;break;
   case 0xEB:v=DE;DE=HL;HL=v;break;
   case 0xED:v=Byte();if(v==0x73){n=Word();M[n]=(byte)SP;M[n+1]=(byte)(SP>>8);}else if(v==0x53){n=Word();M[n]=(byte)E;M[n+1]=(byte)D;}else if(v==0x5B){n=Word();DE=M[n]+256*M[n+1];}else if(v==0xA0){M[DE]=M[HL];DE=(DE+1)&65535;HL=(HL+1)&65535;BC=(BC-1)&65535;}else if(v==0x52){n=HL-DE-(F&1);HL=n&65535;F=(HL==0?64:0)|(n<0?1:0);}else if(v==0xB0){int count=BC==0?65536:BC;for(int i=0;i<count;i++){M[DE]=M[HL];DE=(DE+1)&65535;HL=(HL+1)&65535;}BC=0;}else if(v==0xA1){int value=M[HL];HL=(HL+1)&65535;BC=(BC-1)&65535;F=(F&1)|(A==value?64:0)|(BC!=0?4:0);}else if(v==0xA2){M[HL]=(byte)Input(BC);HL=(HL+1)&65535;B=(B-1)&255;Flag(B);}else if(v==0xA3){B=(B-1)&255;Output(BC,M[HL]);HL=(HL+1)&65535;Flag(B);}else if((v&0xC7)==0x40){int value=Input(BC);Set((v>>3)&7,value);InputFlags(value);}else if((v&0xC7)==0x41)Output(BC,Get((v>>3)&7));else throw new Exception("ED "+v);break;
   case 0xDD:v=Byte();if(v==0x2E){IX=(IX&65280)|Byte();}else if(v==0xE5){Push(IX);}else if(v==0xE1){IX=Pop();}else if(v==0x26){IX=(IX&255)|(Byte()<<8);}else if(v==0x36){n=IX+(sbyte)Byte();M[n]=(byte)Byte();}else if(v==0x34||v==0x35){n=IX+(sbyte)Byte();M[n]=(byte)(M[n]+(v==0x34?1:-1));Flag(M[n]);}else if(v==0xBC){n=IX>>8;F=(A==n?64:0)|(A<n?1:0);}else if((v&0xC7)==0x46)Set((v>>3)&7,M[IX+(sbyte)Byte()]);else if(v==0xCB){n=(sbyte)Byte();v=Byte();int bit=(v>>3)&7,addr=IX+n;if(v>=0xC0)M[addr]|=(byte)(1<<bit);else if(v>=0x80)M[addr]&=(byte)~(1<<bit);else F=(F&1)|((M[addr]&(1<<bit))==0?64:0);}else throw new Exception("DD "+v);break;
   case 0x0F:v=A&1;A=(A>>1)|(v<<7);F=(F&~1)|v;break;case 0x1F:v=A&1;A=(A>>1)|((F&1)<<7);F=(F&~1)|v;break;case 0xE9:PC=HL;break;case 0xE0:if((F&4)==0)PC=Pop();break;case 0xDB:n=Byte();A=Input((A<<8)|n);break;case 0xD3:n=Byte();Output((A<<8)|n,A);break;case 0xD9:v=B;B=AltB;AltB=v;v=C;C=AltC;AltC=v;v=D;D=AltD;AltD=v;v=E;E=AltE;AltE=v;v=H;H=AltH;AltH=v;v=L;L=AltL;AltL=v;break;case 0xCB:v=Byte();n=(v>>3)&7;if(v==0x1A){int old=Get(2);Set(2,(old>>1)|((F&1)<<7));F=(Get(2)==0?64:0)|(old&1);}else if(v>=0xC0)Set(v&7,Get(v&7)|(1<<n));else if(v>=0x80)Set(v&7,Get(v&7)&~(1<<n));else if(v>=0x40&&v<0x80)F=(F&1)|((Get(v&7)&(1<<n))==0?64:0);else throw new Exception("CB "+v);break;case 0xFB:case 0xF3:break;case 0x76:Idle++;break;
   default:throw new Exception("Opcode "+op.ToString("X2")+" at "+(PC-1).ToString("X4"));
  }
 }}
 public void QueueText(string text){Enqueue(text);}
 public void SetHL(int v){HL=v;}
 public bool Zero(){return Z;} public bool Carry(){return (F&1)!=0;} public int EndHL(){return HL;} public int EndDE(){return DE;} public int EndBC(){return BC;} public void SetDE(int v){DE=v;} public void SetBC(int v){BC=v;} public void QueueIdle(int n){while(n-->0)Q.Enqueue(-1);}
}
"@
$bin=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'WifiBios21_MB_EL.cod'))
function Assert($ok,$why){if(-not $ok){throw $why}}
$count=0;$findings=@()
function New-Cpu([bool]$mb=$true,[int]$address=0x4000){$cpu=[BiosCpu]::new($bin,$symbols,$address);$cpu.Mb=$mb;$cpu.IX=0x1234;$cpu.M[0x5CAE]=165;$cpu.M[0x5CAF]=90;$cpu.Run('get_vers_inst');return $cpu}
foreach($address in @(0x4000,0x6000,0xC000,0xFD00)){
 foreach($mb in @($true,$false)){
  $cpu=New-Cpu $mb $address
  Assert ($cpu.EndBC() -eq 0x0201 -and $cpu.A -eq 23 -and $cpu.E -eq $(if($mb){48}else{0})) 'Install return values wrong'
  Assert ($cpu.Str($cpu.EndHL()) -eq 'MBEL-ESP01') 'Relocated BIOS string wrong'
  Assert (($cpu.IX-band 255) -eq 12) 'Wrong service count'
  Assert ($cpu.M[0x5CAE] -eq 165 -and $cpu.M[0x5CAF] -eq 90 -and $cpu.SP -eq 0xF000) 'Relocation damaged work/SP'
  $cpu.Run('get_vers_inst');Assert ($cpu.Str($cpu.EndHL()) -eq 'MBEL-ESP01' -and $cpu.SP -eq 0xF000) 'Repeated install relocates twice'
  $count++
 }
}
$mant=@(24,48,96,192,3125,384,576,1152,2304,4608,576,9216,1152,15,2,2304,3456,4608,576,6912,8064,9216,10368,1152)
$exp=@(2,2,2,2,1,2,2,2,2,2,3,2,3,5,6,3,3,3,4,3,3,3,3,4)
$hw=@(7,6,5,4,3,2,1,0,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23)
foreach($index in 0..23){
 foreach($set in @(0,1)){
  $cpu=New-Cpu;$cpu.OutPorts.Clear();$cpu.A=$index;$cpu.F=$set;$cpu.Run('set_baud')
  Assert (-not $cpu.Carry() -and $cpu.EndBC() -eq $mant[$index] -and $cpu.E -eq $exp[$index]) 'Baud table result wrong'
  Assert ($cpu.OutPorts.Count -eq $set) 'Info query performed an OUT'
  if($set){Assert ($cpu.OutPorts[0] -eq 0x143B -and $cpu.OutValues[-1] -eq $hw[$index]) 'Wrong UART speed OUT'}
  $count++
 }
 $cpu=New-Cpu;$cpu.SpeedCode=$hw[$index];$cpu.Run('get_baud');Assert (-not $cpu.Carry() -and $cpu.A -eq $index -and $cpu.EndBC() -eq $mant[$index] -and $cpu.E -eq $exp[$index]) 'Baud readback wrong';$count++
}
foreach($bad in @(24,255)){
 $cpu=New-Cpu;$cpu.A=$bad;$cpu.F=1;$cpu.Run('set_baud');Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.E -eq 0) 'Unsupported speed accepted';$count++
 $cpu=New-Cpu;$cpu.SpeedCode=$bad;$cpu.Run('get_baud');Assert ($cpu.Carry() -and $cpu.A -eq 255 -and $cpu.EndBC() -eq 0 -and $cpu.E -eq 0) 'Unknown hardware baud accepted';$count++
}
foreach($busy in @($false,$true)){
 $cpu=New-Cpu;$cpu.TxBusy=$busy;$cpu.SetBC(0x2468);$cpu.SetDE(0x1357);$cpu.A=165;$cpu.F=1;$cpu.Run('send_byte')
 Assert ($cpu.Carry() -eq $busy -and $cpu.Tx.Count -eq [int](-not $busy)) 'Transmit byte status wrong';Assert ($cpu.EndBC() -eq 0x2468 -and $cpu.EndDE() -eq 0x1357) 'Byte send damaged preserved BC/DE';if($busy){Assert ($cpu.A -eq 165) 'Busy TX lost retry byte'}else{Assert ($cpu.A -eq 165) 'Successful TX lost input A'};$count++
}
$cpu=New-Cpu;$cpu.TxBusy=$true;$cpu.F=0;$cpu.Run('send_byte');Assert ($cpu.Carry() -and $cpu.Tx.Count -eq 0 -and -not $cpu.Zero()) 'Busy status-only carry wrong';$count++
foreach($value in @(0,65,255)){
 $cpu=New-Cpu;$cpu.Rx.Enqueue([byte]$value);$cpu.F=1;$cpu.SetBC(0x2468);$cpu.SetDE(0x1357);$cpu.Run('rece_byte');Assert (-not $cpu.Zero() -and -not $cpu.Carry() -and $cpu.A -eq $value -and $cpu.Rx.Count -eq 0) 'Byte RX value/flags wrong';Assert ($cpu.EndBC() -eq 0x2468 -and $cpu.EndDE() -eq 0x1357) 'RX byte damaged registers';$count++
}
foreach($length in @(1,255,256,257)){
 $cpu=New-Cpu;for($i=0;$i -lt $length;$i++){$cpu.Rx.Enqueue([byte]($i-band 255))};$cpu.SetHL(0x8000);$cpu.SetBC($length);$cpu.SetDE(5000);$cpu.M[0x8000+$length]=165;$cpu.Run('rece_block')
 Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.EndHL() -eq 0x8000+$length) 'Block RX length/flags wrong'
 for($i=0;$i -lt $length;$i++){Assert ($cpu.M[0x8000+$i] -eq ($i-band 255)) 'Block RX content wrong'};Assert ($cpu.M[0x8000+$length] -eq 165) 'Block RX overflow';$count++
}
$cpu=New-Cpu;$cpu.Rx.Enqueue(42);$cpu.SetHL(0x8000);$cpu.SetBC(0);$cpu.SetDE(4);$cpu.M[0x8000]=165;$cpu.Run('rece_block');Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.EndHL() -eq 0x8000 -and $cpu.M[0x8000] -eq 165 -and $cpu.Rx.Count -eq 1) 'Empty RX block touched memory/FIFO';$count++
$cpu=New-Cpu;$cpu.Put(0x8000,'abc');$cpu.SetHL(0x8000);$cpu.SetBC(3);$cpu.SetDE(0);$cpu.Run('send_block');Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.Tx.Count -eq 3 -and $cpu.Tx[0] -eq 97 -and $cpu.Tx[2] -eq 99) 'Normal block TX failed';$count++
$cpu=New-Cpu;$cpu.SetHL(0x8000);$cpu.SetBC(0);$cpu.SetDE(0);$cpu.Run('send_block');Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.Tx.Count -eq 0 -and $cpu.EndHL() -eq 0x8000) 'Empty TX block transmitted data';$count++
$cpu=New-Cpu $false;$cpu.OutPorts.Clear();$cpu.InPorts.Clear();$cpu.Run('wifi_off');Assert ($cpu.Zero() -and $cpu.OutPorts.Count -eq 0 -and $cpu.InPorts.Count -eq 0) 'EL power off accessed MB ports';$count++
foreach($power in @(0xA4,0xA5)){
 foreach($set in @(0,1)){
  $cpu=New-Cpu;$cpu.Power=$power;$cpu.OutPorts.Clear();$cpu.F=$set;$cpu.Run('wifi_on')
  Assert ($cpu.Power -eq $(if($set){$power-bor 1}else{$power})) 'Power-on changed other bits'
  Assert ($cpu.Zero() -eq (($power-band 1) -eq 0 -and $set -eq 0)) 'Power status Z wrong'
  Assert ($cpu.OutPorts.Contains(0x713B) -eq [bool]$set) 'Status query wrote power register';$count++
 }
}
$cpu=New-Cpu;$cpu.Power=0xA5;$cpu.Run('wifi_off');Assert (-not $cpu.Zero() -and $cpu.Power -eq 0xA4) 'Power-off changed other bits';$count++
$cpu=New-Cpu;$cpu.Rx.Enqueue(42);$cpu.F=0;$cpu.Run('rece_byte');Assert (-not $cpu.Zero() -and $cpu.Rx.Count -eq 1) 'RX status consumed byte';$count++
$cpu=New-Cpu;$cpu.F=1;$cpu.Run('rece_byte');Assert ($cpu.Zero() -and -not $cpu.Carry()) 'Empty RX status wrong';$count++
$cpu=New-Cpu;$cpu.Rx.Enqueue(42);$cpu.Run('clear_rece_buff');Assert ($cpu.Rx.Count -eq 0) 'RX clear failed';$count++
$cpu=New-Cpu;$cpu.SetHL(0x8000);$cpu.SetBC(3);$cpu.SetDE(2);$cpu.M[0x8000]=165;$cpu.Run('rece_block');Assert (-not $cpu.Carry() -and $cpu.EndBC() -eq 3 -and $cpu.M[0x8000] -eq 165) 'Empty block RX timeout failed';$count++
$cpu=New-Cpu;$cpu.TxBusy=$true;$cpu.SetHL(0x8000);$cpu.SetBC(3);$cpu.SetDE(2);$cpu.Run('send_block');Assert (-not $cpu.Carry() -and $cpu.EndBC() -eq 3 -and $cpu.Tx.Count -eq 0) 'Busy block TX timeout failed';$count++
foreach($flags in @(0,1,64,65)){
 $cpu=New-Cpu $false;$cpu.OutPorts.Clear();$cpu.InPorts.Clear();$cpu.F=$flags;$cpu.Run('wifi_on')
 Assert (-not $cpu.Zero() -and $cpu.A -eq 1 -and $cpu.OutPorts.Count -eq 0 -and $cpu.InPorts.Count -eq 0) 'EL power-on/status touched MB ports or reported off';$count++
}
foreach($entry in @('rece_block','send_block')){
 foreach($timeout in @(0,1,65535)){
  foreach($flags in @(0,1)){
   $cpu=New-Cpu;$cpu.SetHL(0x8000);$cpu.SetBC(0);$cpu.SetDE($timeout);$cpu.AltD=0x12;$cpu.AltE=0x34;$cpu.F=$flags;$cpu.M[0x8000]=165;$cpu.Rx.Enqueue(42);$cpu.OutPorts.Clear();$cpu.InPorts.Clear();$cpu.Run($entry)
   Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.EndHL() -eq 0x8000 -and $cpu.EndDE() -eq $timeout -and $cpu.Rx.Count -eq 1 -and $cpu.M[0x8000] -eq 165 -and $cpu.OutPorts.Count -eq 0 -and $cpu.InPorts.Count -eq 0 -and $cpu.AltD -eq 0x12 -and $cpu.AltE -eq 0x34) 'Empty block contract violated';$count++
  }
 }
}
foreach($status in @(1,3,29,31)){
 $cpu=New-Cpu;$cpu.StatusOverride=$status;$cpu.A=165;$cpu.F=0;$cpu.Run('send_byte')
 Assert ($cpu.Carry() -eq (($status-band 2) -ne 0) -and $cpu.Zero() -eq (($status-band 2) -eq 0) -and $cpu.A -eq 165 -and $cpu.Tx.Count -eq 0) 'TX status polluted by RX bits';$count++
}
$cpu=New-Cpu;$cpu.Power=1;$cpu.Run('wifi_off');Assert (-not $cpu.Zero() -and $cpu.Power -eq 0) 'Power-off success flags incorrect for zero control byte';$count++
"PASS: $count scenarios on assembled BIOS 2.1."
$findings