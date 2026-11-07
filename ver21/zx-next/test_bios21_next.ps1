$ErrorActionPreference='Stop'
$symbols=New-Object 'System.Collections.Generic.Dictionary[string,int]'
Get-Content (Join-Path $PSScriptRoot 'WifiBios21_NX.sym') | ForEach-Object {if($_ -match '^([^:]+): EQU 0x([0-9A-Fa-f]+)'){$symbols[$matches[1]]=[Convert]::ToInt32($matches[2],16)}}
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
public class BiosCpu {
 public byte[] M=new byte[65536]; public Dictionary<string,int> S; public int Base,StepLimit=3000000; public bool Mb=true,TxBusy; public int Timing,NextSelect,Uart=64,Frame=255,Prescaler=65535; public int Power=0xA4,SpeedCode,StatusOverride=-1; public Queue<byte> Rx=new Queue<byte>(); public List<int> InPorts=new List<int>(); public List<int> OutPorts=new List<int>(),OutValues=new List<int>(); public List<byte> Tx=new List<byte>(); public int AltB,AltC,AltD,AltE,AltH,AltL;
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
  if(port==0x253B)return NextSelect==17?Timing:1; if(port==0x153B)return Uart; if(port==0x773B)return Mb?0x33:0;
  if(port==0x713B)return Mb?Power:255;
  if(port==0x7D3B)return SpeedCode;
  if(port==0x133B)return StatusOverride>=0?StatusOverride:(Rx.Count>0?1:0)|(TxBusy?2:0)|(Rx.Count>=2048?4:0)|(Rx.Count>=1536?8:0);
  if(port==0x143B)return Rx.Count>0?Rx.Dequeue():255;
  return 255;
 }
 void Output(int port,int value){OutPorts.Add(port);OutValues.Add(value);if(port==0x133B){if(Uart!=0)throw new Exception("TX went to Pi");Tx.Add((byte)value);} if(port==0x243B)NextSelect=value; if(port==0x153B){Uart=value&64;if((value&16)!=0)Prescaler=(Prescaler&16383)|((value&7)<<14);} if(port==0x163B)Frame=value;if(port==0x143B){if(Uart!=0)throw new Exception("Baud write went to Pi");if((value&128)==0)Prescaler=(Prescaler&~127)|(value&127);else Prescaler=(Prescaler&~16256)|((value&127)<<7);}if(port==0x713B)Power=value;if(port==0x7D3B && value==1)Rx.Clear();}
 void InputFlags(int value){int bits=0;for(int i=0;i<8;i++)bits+=(value>>i)&1;F=(F&1)|(value==0?64:0)|((bits&1)==0?4:0);}
 public void Run(string entry){PC=Addr(entry);Push(0x2000);while(!Done && PC!=0x2000){if(++Steps>StepLimit)throw new Exception("Instruction limit at "+PC.ToString("X"));int op=Byte(),v,n;
  if(op>=0x40 && op<=0x7F && op!=0x76){Set((op>>3)&7,Get(op&7));continue;}
  if((op&0xC7)==0x06){Set((op>>3)&7,Byte());continue;}
  if((op&0xC7)==0x04){n=(op>>3)&7;v=(Get(n)+1)&255;Set(n,v);Flag(v);continue;}
  if((op&0xC7)==0x05){n=(op>>3)&7;v=(Get(n)-1)&255;Set(n,v);Flag(v);continue;}
  switch(op){
   case 0x17:v=A;A=((A<<1)|(F&1))&255;F=(F&~1)|(v>>7);break;case 0x87:v=A*2;A=v&255;F=(A==0?64:0)|(v>255?1:0);break;case 0x08:v=A;A=AltA;AltA=v;v=F;F=AltF;AltF=v;break;case 0x01:BC=Word();break;case 0x11:DE=Word();break;case 0x21:HL=Word();break;case 0x31:SP=Word();break;
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
   case 0xED:v=Byte();if(v==0x91){int r=Byte(),d=Byte();Output(0x243B,r);Output(0x253B,d);}else if(v==0x73){n=Word();M[n]=(byte)SP;M[n+1]=(byte)(SP>>8);}else if(v==0x53){n=Word();M[n]=(byte)E;M[n+1]=(byte)D;}else if(v==0x5B){n=Word();DE=M[n]+256*M[n+1];}else if(v==0xA0){M[DE]=M[HL];DE=(DE+1)&65535;HL=(HL+1)&65535;BC=(BC-1)&65535;}else if(v==0x52){n=HL-DE-(F&1);HL=n&65535;F=(HL==0?64:0)|(n<0?1:0);}else if(v==0xB0){int count=BC==0?65536:BC;for(int i=0;i<count;i++){M[DE]=M[HL];DE=(DE+1)&65535;HL=(HL+1)&65535;}BC=0;}else if(v==0xA1){int value=M[HL];HL=(HL+1)&65535;BC=(BC-1)&65535;F=(F&1)|(A==value?64:0)|(BC!=0?4:0);}else if(v==0xA2){M[HL]=(byte)Input(BC);HL=(HL+1)&65535;B=(B-1)&255;Flag(B);}else if(v==0xA3){B=(B-1)&255;Output(BC,M[HL]);HL=(HL+1)&65535;Flag(B);}else if((v&0xC7)==0x40){int value=Input(BC);Set((v>>3)&7,value);InputFlags(value);}else if((v&0xC7)==0x41)Output(BC,Get((v>>3)&7));else throw new Exception("ED "+v);break;
   case 0xDD:v=Byte();if(v==0x2E){IX=(IX&65280)|Byte();}else if(v==0xE5){Push(IX);}else if(v==0xE1){IX=Pop();}else if(v==0x26){IX=(IX&255)|(Byte()<<8);}else if(v==0x36){n=IX+(sbyte)Byte();M[n]=(byte)Byte();}else if(v==0x34||v==0x35){n=IX+(sbyte)Byte();M[n]=(byte)(M[n]+(v==0x34?1:-1));Flag(M[n]);}else if(v==0xBC){n=IX>>8;F=(A==n?64:0)|(A<n?1:0);}else if((v&0xC7)==0x46)Set((v>>3)&7,M[IX+(sbyte)Byte()]);else if(v==0xCB){n=(sbyte)Byte();v=Byte();int bit=(v>>3)&7,addr=IX+n;if(v>=0xC0)M[addr]|=(byte)(1<<bit);else if(v>=0x80)M[addr]&=(byte)~(1<<bit);else F=(F&1)|((M[addr]&(1<<bit))==0?64:0);}else throw new Exception("DD "+v);break;
   case 0x0F:v=A&1;A=(A>>1)|(v<<7);F=(F&~1)|v;break;case 0x1F:v=A&1;A=(A>>1)|((F&1)<<7);F=(F&~1)|v;break;case 0xE9:PC=HL;break;case 0xE0:if((F&4)==0)PC=Pop();break;case 0xDB:n=Byte();A=Input((A<<8)|n);break;case 0xD3:n=Byte();Output((A<<8)|n,A);break;case 0xD9:v=B;B=AltB;AltB=v;v=C;C=AltC;AltC=v;v=D;D=AltD;AltD=v;v=E;E=AltE;AltE=v;v=H;H=AltH;AltH=v;v=L;L=AltL;AltL=v;break;case 0xCB:v=Byte();n=(v>>3)&7;if(v==0x13){int old=E;E=((E<<1)|(F&1))&255;F=(E==0?64:0)|(old>>7);}else if(v==0x1A){int old=Get(2);Set(2,(old>>1)|((F&1)<<7));F=(Get(2)==0?64:0)|(old&1);}else if(v>=0xC0)Set(v&7,Get(v&7)|(1<<n));else if(v>=0x80)Set(v&7,Get(v&7)&~(1<<n));else if(v>=0x40&&v<0x80)F=(F&1)|((Get(v&7)&(1<<n))==0?64:0);else throw new Exception("CB "+v);break;case 0xFB:case 0xF3:break;case 0x76:Idle++;break;
   default:throw new Exception("Opcode "+op.ToString("X2")+" at "+(PC-1).ToString("X4"));
  }
 }}
 public void QueueText(string text){Enqueue(text);}
 public void SetHL(int v){HL=v;}
 public bool Zero(){return Z;} public bool Carry(){return (F&1)!=0;} public int EndHL(){return HL;} public int EndDE(){return DE;} public int EndBC(){return BC;} public void SetDE(int v){DE=v;} public void SetBC(int v){BC=v;} public void QueueIdle(int n){while(n-->0)Q.Enqueue(-1);}
}
"@
$bin=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'WifiBios21_NX.cod'))
function Assert($ok,$why){if(-not $ok){throw $why}}
$count=0
function New-Cpu([int]$address=0x4000){$cpu=[BiosCpu]::new($bin,$symbols,$address);$cpu.IX=0x1234;$cpu.M[0x5CAE]=165;$cpu.M[0x5CAF]=90;$cpu.Run('get_vers_inst');return $cpu}
foreach($address in @(0x4000,0x6000,0xC000,0xFD00)){
 $cpu=New-Cpu $address
 Assert ($cpu.EndBC() -eq 0x0201 -and $cpu.A -eq 14 -and $cpu.EndDE() -eq 0) 'Install return values'
 Assert ($cpu.Str($cpu.EndHL()) -eq 'ZXNext-ESP01') 'Relocated identifier'
 Assert (($cpu.IX-band 255) -eq 12 -and $cpu.Uart -eq 0 -and $cpu.Frame -eq 24) 'ABI/ESP/8N1 initialization'
 Assert ($cpu.M[0x5CAE] -eq 165 -and $cpu.M[0x5CAF] -eq 90 -and $cpu.SP -eq 0xF000) 'Relocation work/SP'
 $cpu.OutPorts.Clear();$cpu.OutValues.Clear();$cpu.Run('get_vers_inst')
 Assert ($cpu.Str($cpu.EndHL()) -eq 'ZXNext-ESP01' -and $cpu.OutPorts.Count -eq 0) 'Repeated install touched UART'
 $count++
}
$mant=@(24,48,96,192,3125,384,576,1152,2304,4608,576,9216,1152,15,2)
$exp=@(2,2,2,2,1,2,2,2,2,2,3,2,3,5,6)
$clocks=@(28000000,28571429,29464286,30000000,31000000,32000000,33000000,27000000)
foreach($index in 0..14){foreach($timing in 0..7){foreach($set in @(0,1)){
 $cpu=New-Cpu;$cpu.Timing=$timing;$cpu.Prescaler=65535;$cpu.OutPorts.Clear();$cpu.OutValues.Clear();$cpu.A=$index;$cpu.F=$set;$cpu.Run('set_baud')
 Assert (-not $cpu.Carry() -and $cpu.EndBC() -eq $mant[$index] -and $cpu.E -eq $exp[$index] -and $cpu.A -eq $index) "Baud result $index/$timing/$set"
 if($set){
  $baud=$mant[$index]*[Math]::Pow(10,$exp[$index]);$expect=[Math]::Round($clocks[$timing]/$baud,0,[MidpointRounding]::AwayFromZero)
  Assert ($cpu.Prescaler -eq $expect) "Prescaler $index/$timing actual=$($cpu.Prescaler) expected=$expect"
  Assert ($cpu.OutPorts.Count -eq 4 -and $cpu.OutPorts[1] -eq 0x153B -and $cpu.OutValues[1] -eq 16) 'ESP/upper prescaler write'
 }else{Assert ($cpu.Prescaler -eq 65535 -and $cpu.OutPorts.Count -eq 1 -and $cpu.OutPorts[0] -eq 0x243B) 'Info query altered UART'}
 $count++
}}}
foreach($bad in @(15,23,255)){foreach($set in @(0,1)){
 $cpu=New-Cpu;$cpu.OutPorts.Clear();$cpu.OutValues.Clear();$cpu.InPorts.Clear();$cpu.A=$bad;$cpu.F=$set;$cpu.Run('set_baud')
 Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.E -eq 0 -and $cpu.OutPorts.Count -eq 0 -and $cpu.InPorts.Count -eq 0) 'Invalid speed'
 $count++
}}
$cpu=New-Cpu;$cpu.SetBC(123);$cpu.SetDE(456);$cpu.A=2;$cpu.Run('get_baud');Assert ($cpu.Carry() -and $cpu.A -eq 255 -and $cpu.EndBC() -eq 0 -and $cpu.E -eq 0) 'Unsupported get baud';$count++
$cpu=New-Cpu;$cpu.OutPorts.Clear();$cpu.OutValues.Clear();$cpu.InPorts.Clear();$before=$cpu.Steps;$cpu.Run('reset_esp')
Assert ($cpu.OutPorts.Count -eq 4 -and $cpu.OutPorts[0] -eq 0x243B -and $cpu.OutValues[0] -eq 2 -and $cpu.OutPorts[1] -eq 0x253B -and $cpu.OutValues[1] -eq 128 -and $cpu.OutValues[3] -eq 0 -and $cpu.InPorts.Count -eq 0 -and $cpu.Steps-$before -gt 8000) 'Reset register/value/delay';$count++
foreach($busy in @($false,$true)){foreach($set in @(0,1)){
 $cpu=New-Cpu;$cpu.TxBusy=$busy;$cpu.A=165;$cpu.F=$set;$cpu.SetBC(0x2468);$cpu.SetDE(0x1357);$cpu.Run('send_byte')
 Assert ($cpu.Carry() -eq $busy -and $cpu.Tx.Count -eq [int]($set -and -not $busy) -and $cpu.A -eq 165 -and $cpu.EndBC() -eq 0x2468 -and $cpu.EndDE() -eq 0x1357) 'TX byte flags/value/registers';$count++
}}
foreach($value in @(0,65,255)){
 $cpu=New-Cpu;$cpu.Rx.Enqueue([byte]$value);$cpu.F=1;$cpu.SetBC(0x2468);$cpu.SetDE(0x1357);$cpu.Run('rece_byte')
 Assert (-not $cpu.Zero() -and -not $cpu.Carry() -and $cpu.A -eq $value -and $cpu.Rx.Count -eq 0 -and $cpu.EndBC() -eq 0x2468 -and $cpu.EndDE() -eq 0x1357) 'RX byte';$count++
}
foreach($length in @(1,255,256,257,512,1536,1537)){
 $cpu=New-Cpu;for($i=0;$i -lt $length;$i++){$cpu.Rx.Enqueue([byte]($i-band 255))};$cpu.SetHL(0x8000);$cpu.SetBC($length);$cpu.SetDE(10000);$cpu.M[0x8000+$length]=165;$cpu.Run('rece_block')
 Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.EndHL() -eq 0x8000+$length -and $cpu.Rx.Count -eq 0) 'Block RX result'
 for($i=0;$i -lt $length;$i++){Assert ($cpu.M[0x8000+$i] -eq ($i-band 255)) 'Block RX content'};Assert ($cpu.M[0x8000+$length] -eq 165) 'Block RX boundary';$count++
}
foreach($entry in @('rece_block','send_block')){foreach($timeout in @(0,1,65535)){
 $cpu=New-Cpu;$cpu.SetHL(0x8000);$cpu.SetBC(0);$cpu.SetDE($timeout);$cpu.Rx.Enqueue(42);$cpu.M[0x8000]=165;$cpu.OutPorts.Clear();$cpu.OutValues.Clear();$cpu.InPorts.Clear();$cpu.Run($entry)
 Assert ($cpu.Carry() -and $cpu.EndBC() -eq 0 -and $cpu.EndHL() -eq 0x8000 -and $cpu.EndDE() -eq $timeout -and $cpu.Rx.Count -eq 1 -and $cpu.M[0x8000] -eq 165 -and $cpu.OutPorts.Count -eq 0 -and $cpu.InPorts.Count -eq 0) 'Empty block';$count++
}}
$cpu=New-Cpu;$cpu.Put(0x8000,'abc');$cpu.SetHL(0x8000);$cpu.SetBC(3);$cpu.SetDE(0);$cpu.Run('send_block');Assert ($cpu.Carry() -and $cpu.Tx.Count -eq 3 -and $cpu.Tx[0] -eq 97 -and $cpu.Tx[2] -eq 99 -and $cpu.EndBC() -eq 0) 'TX block';$count++
$cpu=New-Cpu;$cpu.TxBusy=$true;$cpu.SetHL(0x8000);$cpu.SetBC(3);$cpu.SetDE(2);$cpu.Run('send_block');Assert (-not $cpu.Carry() -and $cpu.Tx.Count -eq 0 -and $cpu.EndBC() -eq 3) 'TX timeout';$count++
$cpu=New-Cpu;$cpu.SetHL(0x8000);$cpu.SetBC(3);$cpu.SetDE(2);$cpu.Run('rece_block');Assert (-not $cpu.Carry() -and $cpu.EndBC() -eq 3 -and $cpu.EndHL() -eq 0x8000) 'RX timeout';$count++
$cpu=New-Cpu;$cpu.Rx.Enqueue(42);$cpu.F=0;$cpu.Run('rece_byte');Assert (-not $cpu.Zero() -and $cpu.Rx.Count -eq 1) 'RX status consumed byte';$count++
$cpu=New-Cpu;$cpu.F=1;$cpu.Run('rece_byte');Assert ($cpu.Zero() -and -not $cpu.Carry()) 'Empty RX';$count++
$cpu=New-Cpu;1..10|ForEach-Object{$cpu.Rx.Enqueue([byte]$_)};$cpu.Run('clear_rece_buff');Assert ($cpu.Rx.Count -eq 0) 'RX clear';$count++
"PASS: $count scenarios on assembled ZX Next BIOS 2.1 (CPU execution, simulated ports; hardware not tested)."