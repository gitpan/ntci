#!#/usr/bin/perl
#
#  TODO:
#  	See sourceforge.net's task list
#
#
#####
#
#  Package  Net::Telnet::Cisco::IOS
#
#  Written by Aaron Conaway
#
#  This package extends the Net::Telnet::Cisco package written by
#  Joshua Keroes.  Go go http://nettelnetcisco.sourceforge.net/ for
#  details on that package.
#
#  The IOS package is for use on Cisco IOS devices.  It will not work on
#  CatOS or any other Cisco OSes.
#
#  I am not a programmer.  I merely developed this package out of
#  necessity to help automate monitoring and configuration of Cisco
#  devices at work.  The code is undoubtedly inefficient and there
#  are probably 84928 better ways to do what I'm trying to do.
#
#  See the SF.net page for NTCI at http://ntci.sourceforge.net for a lot
#  more detail and a mess of documentation.
#
#####
package Net::Telnet::Cisco::IOS;
use Net::Telnet::Cisco;

#  Declare ourselves a child of Net::Telnet::Cisco
@ISA        = qw(Net::Telnet::Cisco);
#  Keep the version number
$VERSION    = "0.3beta";

#  Constructor
sub new  {
	#  Get my own class type
  	my $class = shift;
  	my ($self, $host, %args);
  
	#  Call the super constructor
	$self = $class->SUPER::new(@_) or return;
	
	our ( $platform, $model, $iosver, @config );
  	return $self;
}

sub login  {
	my $self = shift;
	$self->SUPER::login(@_) or return;
	$self->cmd("terminal length 0");
	return;
}

#  Returns the version number
sub getModVer  {
	return $VERSION;
}

#  Returns IOS version of router
sub getIOSVer  {
	my $cmd = "show version";
	my $self = shift;
	#  Try to run the command
        if ( ! (@result = $self->cmd( $cmd ) ) )  {
                #  If it failed, return 0
                return 0;
        }

	foreach $line ( @result )  {
		if ( $line =~ /, Version (.+),/ )  {
			return $1;
		}
	}
	return 0;
}


#  Returns hash of 5-sec, 1-min, and 5-minute CPU averages
sub getCPU  {
        #  cmd is what command we send to the IOS device
        my $cmd = "show process cpu";
	#  Initialize the hash
	my %result = ();
        #  Set the object up
        my $self = shift;
        #  Try to run the command
        if ( ! (@result = $self->cmd( $cmd ) ) )  {
                #  If it failed, return 0
                return 0;
        }
	foreach $line ( @result )  {
		if ( $line =~ /five seconds: (.+)\/.+; one minute: (.+); five minutes: (.+)/ )  {
			$result{ "5sec" } = $1;
			$result{ "1min" } = $2;
			$result{ "5min" } = $3;
			return %result;
		}
	}
	return 0;
}
		
#  Returns all the ints in an array
sub listInts  {
	my $self = shift;
	my @ret;
	my $int;
	my $cmd = "sh ip interface brief";
	
	if ( ! ( @result = $self->cmd( $cmd ) ) )  {
		return 0;
	}

	foreach $line ( @result )  {
		chomp( $line );
		if ( $line =~ /^Interface/i )  { }
		elsif ( $line =~ /^-----/ )  { }
		elsif ( $line =~ /^\s/ )  { }
		elsif ( $line =~ /^\W/ )  { }
		else  {
			$int = substr( $line, 0, 23 );
			if ( length ( $int ) == 0 )  { }
			else  {
				push ( @ret, $int );
			}
		}
	}
	return @ret;
}

sub listVLANs  {
	my $self = shift;
	my @ret;
	my $cmd = "show vlan brief";
	my ( $vlanid, $vlanname );
        #  Try to run the command
        if ( ! ( @result = $self->cmd( $cmd ) ) )  {
                #  If it failed, return 0
                return 0;
        }

	#  Go through each line of the command result
        foreach $line ( @result )  {
                #  If it starts with "Port", do nothing
                if ( $line =~ /^VLAN/i )  { }
                #  If it starts with "----", do nothing
                elsif ( $line =~ /^----/ )  { }
                #  If it starts with whitespace, do nothing
                elsif ( $line =~ /^\s+/ )  { }
                else  {
			#  Get the first two columns
			$vlanid = substr( $line, 0, 4);
			$vlanname = substr ( $line, 5, 30 );
			if ( $vlanid =~ /100[2-5]/ )  { }
			else  {
				chomp( $vlanid );
                        	#  Put the line onto the end of the return array
                        	push ( @ret, $vlanid );
			}
                }
        }
        #  Return the return array
        return @ret;
}	

sub getIntState  {
        my ( $self, @args ) = @_;
	my %result;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @output = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @output )  {
                if ( $line =~ /$if is (.+), line protocol is (.+)\n/ )  {
			$result{'port'} = $1;
			$result{'lineprotocol'} = $2;
			return %result;
                }  else  { }
        }

}


sub getIntDesc  {
        my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /Description: (.+)/ )  {
                        return $1;
                }  else  { }
        }
	return 0;
}


sub getEthSpeed  {
        my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /Auto Speed \((.+)\),/ )  {
                        return $1;
                }  elsif ( $line =~ /, (.+)Mb\/s/ )  {
                                return $1;
                }
        }
	return 0;
}


sub getEthDuplex  {
        my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /\s+Auto-duplex \((.{4})\),/ )  {
                        return $1;
                }  elsif ( $line =~ /\s+(.+)-duplex/ )  {
                        if ( $1 eq "Auto" )  { }
                        else  {
                                return $1;
                        }
                }
        }
	return 0;
}

sub getIntBandwidth  {
        my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /\s+BW (.+) Kbit/ )  {
                        return $1;
                }  else  { }
        }

}



sub getIntInputRate  {
	my ( $self, @args ) = @_;
	$if = &harmonizeints( $args[0] );
	$cmd = "sh interface " . $if;
	if ( !( @result = $self->cmd( $cmd ) ) ) { 
		return 0;
	}
	foreach $line ( @result )  {
		if ( $line =~ /5 minute input rate (.+) bits/ )  {
			return $1;
		}  else  { }
	}
	
}

sub getIntInputErrors  {
        my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /(.+) input errors,/ )  {
                        return $1;
                }  else  { }
        }
	return 0;

}


sub getIntOutputRate  {
        my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /5 minute output rate (.+) bits/ )  {
                        return $1;
                }  else  { }
        }

}

sub getIntOutputErrors  {
        my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if;
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /(.+) output errors,/ )  {
                        return $1;
                }  else  { }
        }
	return 0;
}

sub findVLAN  {
	my ( $self, @args ) = @_;
        $if = &harmonizeInts( $args[0] );
        $cmd = "sh interface " . $if . " status";
        if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
		if ( $line =~ /^Port/ )  { }
		elsif ( $line =~ /^-----/ )  { }
		elsif ( $line =~ /^\s+/ )  { }
                else  {
			my $vlan = substr( $line, 40, 8 );
			return $vlan;
		}
        }
        return 0;
}


sub getConfig  {
	my $self = shift;
	my $cmd = "show running-config";
	if ( ! ( @result = $self->cmd( $cmd ) ) )  {
		return 0;
	}
	return @result;
}


sub getModel  {
	my $self = shift;
	my $cmd = "sh ver";
	my $plat;
	if ( !( @result = $self->cmd( $cmd ) ) ) {
                return 0;
        }
        foreach $line ( @result )  {
                if ( $line =~ /^IOS \(tm\) (.+) Software/ )  { 
			return $1;
                }  elsif  ( $line =~ /cisco (.+) processor/ )  {
			return $1;
		}
        }
        return 0;
}

sub getPlatform  {
        my ( $self, @args ) = @_;
	my $platform;
        $model = $args[0];
	
	if ( $model =~ /29.0/ || $model =~ /3750/ )  {
		return "s";
	}  elsif  ( $model =~ /RSP/ )  {
		return "r";
	} 
	return 0;
}


sub getIntCAM  {
	my ( $self, @args ) = @_;
	$int = harmonizeInts( $args[0] );
	$cmd = "show mac-address-table interface " . $int;
	my @ret;

	@output = $self->cmd( $cmd );
	$model = $self->getModel();
	foreach $line ( @output )  {
		my $mac;
		if ( $line =~ /(\w{4}\.\w{4}\.\w{4})/ )  {
			push ( @ret, $1 );
		}
	}
	return @ret;
}

sub getIntARP  {
        my ( $self, @args ) = @_;
        $int = harmonizeInts( $args[0] );
	$cmd = "show arp";
	my @ret;
	
	@output = $self->cmd( $cmd );
	foreach $line ( @output )  {
		chomp $line;
		if ( $line =~ /^Protocol/i )  { }
		elsif ( $line =~ /$int/ )  {
			$mac = substr ( $line, 38, 14 );
			if ( length ( $int ) == 0 )  { }
			else  {
				push ( @ret, $mac );
			}
		}
	}
	return @ret;
}


sub arpLookup  {
	my ( $self, @args ) = @_;
	$cmd = "show arp";
	
	@output = $self->cmd( $cmd );
	foreach $line ( @output )  {
		chomp $line;
		if ( $line =~ /$args[0]/ )  {
			$ip = substr ( $line, 10, 15 );	
			if ( length( $ip ) == 0 )  { }
			else  {
				return $ip;
			}
		}
	}
	return 0;
}

sub getACLs  {
	$self = shift;
	$cmd = "show access-lists";
	my @ret;
	
	@output = $self->cmd( $cmd );

	foreach $line ( @output )  {
		if ( $line =~ /access list (.+)\n/ )  {
			push ( @ret, $1 );
		}
	}
	return @ret;
}
	
sub getSNMPComm  {
	$self = shift;
	my @ret;
	
	@output = $self->getConfig();

	foreach $line ( @output )  {
		if ( $line =~ /snmp-server community (.+) / )  {
			push ( @ret, $1 );
		}
	}
	return @ret;
} 
			
sub getVTP  {
	$self = shift;
	$cmd = "show vtp status";
	my ( $ver, $mode, $domain );
	my %ret;

	@output = $self->cmd( $cmd );
	
	foreach $line ( @output )  {
		if ( $line =~ /^VTP Version\s+: (.)\n/ )  {
			$ver = $1;
		}
		elsif ( $line =~ /^VTP Operating Mode\s+: (.+)\n/ )  {
			$mode = $1;
		}
		elsif ( $line =~ /^VTP Domain Name\s+: (.+)\n/ )  {
			$domain = $1;
		}
	}
	%ret = (
		version => $ver,
		mode => $mode,
		domain => $domain,
	);
	return %ret;
}

sub getIntACL  {
	my ( $self, @args ) = @_;
        $cmd = "show ip int " . $args[0];
	@outacl =  ("Outgoing access list is ", "Outbound access list is ");
	@inacl = ("Inbound  access list is ", "Inbound access list is ");
	my ( $inacl, $outacl );
        my %ret;

	@output = $self->cmd( $cmd );
	
	foreach $line ( @output )  {
		ACL:
		{
			foreach $acl ( @outacl )  {
				if ( $line =~ /$acl(.+)/ )  {
					$outacl = $1;
					last ACL;
				}	
			}
			foreach $acl ( @inacl )  {
				if ( $line =~ /$acl(.+)/ )  {
					$inacl = $1;
					last ACL;
				}
			}
		}  #  ACL
	}
	
	if ( $inacl eq "not set" )  {
		$inacl = 0;
	}
	if ( $outacl eq "not set" )  {
		$outacl = 0;
	}
	%ret = (
		inbound => $inacl,
		outbound => $outacl,
	);
	return %ret;
}

sub getIPRoute  {
	my ( $self, @args ) = @_;
	my %ret = ( 	protocol => 0,
		 	nexthop => 0);
	my $cmd = "show ip route " . $args[0];
	if ( !( @result = $self->cmd( $cmd ) ) )  {
		return %ret;
	}
	
	foreach $line ( @result )  {

		if ( $line =~ /Known via \"(.+)\"/ )  {
			$ret{ 'protocol' } = $1;
		}
		if ( $line =~ /directly connected, via (.+)\W/ )  {
			$ret{ 'nexthop' } = $1;
		}
		if ( $line =~ /\* (\w{1,3}\.\w{1,3}\.\w{1,3}\.\w{1,3})/ )  {
			$ret{ 'nexthop' } = $1;
		}
		if ( $line =~ /Network not in table/ )  {
			$ret{ 'protocol' } = 0;
			$ret{ 'nexthop' } = 0;
		}
	}
	return %ret;
}

#  setVLAN
#  disableInt
#  setDesc
#  setSpeed
#  setDuplex
#  addSNMPComm
#  setACL
#  

sub harmonizeInts  {
	my $input = shift;
	my @FastEthernet = qw(FastEthernet FastEth Fast FE Fa F);
	my @GigEthernet = qw(GigabitEthernet GigEthernet GigEth GE Gi G);
	my @Ethernet = qw(Ethernet Eth E);
	my @Serial = qw(Serial Se S);
	my @PortChannel = qw(PortChannel Port-Channel Po);
	my @POS = qw(POS P);
	my @VLAN = qw(VLAN VL V);
	IFS:
	{
		#  Go through the array @FastEthernet
        	foreach $fe ( @FastEthernet )
        	{
               		#  If the user's input matches
                	if ( $input =~ /^$fe\d/i )
	        	{
              			#  Take the number part out
                		$input =~ /^$fe(.+)\b/i;
        	        	#  Reset $val to the long name + number
	                	$input = "FastEthernet" . $1;
                        	#  Leave the block because we found it
                		last IFS;
        		}
		}
		#  Go through the array @GigEthernet
                foreach $ge ( @GigEthernet )
                {
                        #  If the user's input matches
                        if ( $input =~ /^$ge\d/i )
                        {
                                #  Take the number part out
                                $input =~ /^$ge(.+)\b/i;
                                #  Reset $val to the long name + number
                                $input = "GigabitEthernet" . $1;
                                #  Leave the block because we found it
                                last IFS;
                        }
                }
		#  Go through the array @Ethernet
                foreach $e ( @Ethernet )
                {
                        #  If the user's input matches
                        if ( $input =~ /^$e\d/i )
                        {
                                #  Take the number part out
                                $input =~ /^$e(.+)\b/i;
                                #  Reset $val to the long name + number
                                $input = "Ethernet" . $1;
                                #  Leave the block because we found it
                                last IFS;
                        }
                }
		#  Go through the array @Serial
                foreach $s ( @Serial )
                {
                        #  If the user's input matches
                        if ( $input =~ /^$s\d/i )
                        {
                                #  Take the number part out
                                $input =~ /^$s(.+)\b/i;
                                #  Reset $val to the long name + number
                                $input = "Serial" . $1;
                                #  Leave the block because we found it
                                last IFS;
                        }
                }
		#  Go through the array @PortChannel
                foreach $po ( @PortChannel )
                {
                        #  If the user's input matches
                        if ( $input =~ /^$po\d/i )
                        {
                                #  Take the number part out
                                $input =~ /^$po(.+)\b/i;
                                #  Reset $val to the long name + number
                                $input = "Port-channel" . $1;
                                #  Leave the block because we found it
                                last IFS;
                        }
                }
		#  Go through the array @POS
                foreach $pos ( @POS )
                {
                        #  If the user's input matches
                        if ( $input =~ /^$pos\d/i )
                        {
                                #  Take the number part out
                                $input =~ /^$pos(.+)\b/i;
                                #  Reset $val to the long name + number
                                $input = "POS" . $1;
                                #  Leave the block because we found it
                                last IFS;
                        }
                }
		#  Go through the array @VLAN
		foreach $vlan ( @VLAN )
                {
                        #  If the user's input matches
                        if ( $input =~ /^$vlan\d/i )
                        {
                                #  Take the number part out
                                $input =~ /^$vlan(.+)\b/i;
                                #  Reset $val to the long name + number
                                $input = "VLAN" . $1;
                                #  Leave the block because we found it
                                last IFS;
                        }
                }
		#  Since we didn't find it, set $input to 0
		return 0;
	}  #  IFS
	return $input;
}

1;
