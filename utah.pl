#!/usr/bin/perl -w

use Data::Dumper;
use DateTime;
use JSON;
# To use this you need: apt-get install libbot-basicbot-perl libpoe-component-sslify-perl libjson-perl libdatetime-perl

package TeaBot;
use base qw(Bot::BasicBot);

my @teas = ();
my $config = {};
my $helptext = 'Try: "utah: Earl grey, downstairs, 5 minutes"';
sub saveConfig()
{
    $json_text   = JSON::encode_json( $config );
    open(my $fh, '>', "config.json");
    print $fh $json_text;
    close($fh);
}

sub said
{
    my ($self, $message) = @_;
    print "Message from $message->{'who'}: $message->{'body'}\n";
    if ($message->{'address'}) {
	my $msg = $message->{'body'};
	chomp($msg);
	if (lc($msg) eq "quit") {
	    $self->shutdown( "Leaving as requested.");
	}
	elsif ($msg =~ /^report to #(\S+)/i) {
	    $config->{reportChans}->{$1} = 1;
	    saveConfig();
	}
	elsif ($msg =~ /^(no|do not) report to #(\S+)/i) {
	    $config->{reportChans}->{$2} = 0;
	    saveConfig();
	}
	elsif ($msg =~ /^cancel/i) {
	    @teas = ();
	    return "OK, I have cancelled all tea notifications.";
	}
	elsif ($msg =~ /^(thanks|thank you|ta)$/i) {
	    return "You're welcome.";
	}
	elsif ($msg =~ /,/) {
	    my @fields = split(/,/, $msg);
	    my $location = "in an unknown location";
	    my $delay = -1;
	    my @tea = ();
	    my $brewer = $message->{'who'};
	    for my $f(@fields) {
                print "Processing field '$f'\n";
		chomp($f);
                $f =~ s/^\s+|\s+$//g; # Trim whitespace
                next if $f eq '';
		if($f =~ /(\d+)\s*(m|min|mins)/i) {
		    $delay = $1;
		}
		elsif($f =~ /now/i) {
		    $delay = 0;
		}
		elsif($f =~ /(upstairs|downstairs)/i) {
                    print "Treating as a location (type 1).\n";
		    $location = $1;
		}
		elsif($f =~ /(3rd|4th)/i) {
                    print "Treating as a location (type 2).\n";
		    $location = "on $1";
		}
		elsif($f =~ /(break room|breakroom)/i) {
                    print "Treating as a location (type 3).\n";
		    $location = "in $1";
		}
		else {
                    print "Treating as tea type.\n";
		    push @tea, $f;
		}
	    }
	    if($delay == -1) {
		return "Please tell me how many minutes you want to wait (e.g. 5m)"
	    }
            if (!@tea) {
                @tea = ('Mystery tea');
            }
	    my $tea = join(", ", @tea);
	    print "$tea ready in $delay minutes $location\n";
	    my $dt = DateTime->now;
	    $dt->add(minutes=>$delay);
	    chomp($tea);
	    if($tea =~ /^AF$/i || $tea =~ /arctic fire/i) {
		$tea = "nasty fruit tea";
	    }
	    push @teas, [$dt ,$tea, $location, $brewer];
	    return "OK";
	}
	elsif ($msg eq 'brewers' or $msg =~ /^who(( i)|')s (making|brewing)( tea)?\??$/i) {
		local $" = ', ';
		my @brewers = sort keys %{{map { $_->[3] => 1 } @teas}};
		return scalar @brewers > 0 ? "@brewers" : 'No tea is brewing at present.';
	}
	else {
	    return "I don't understand. $helptext";
	}
    }
    return undef;
}

sub tick
{
    my ($self) = @_;
    print "tick\n";
    my @newTeas = ();
    for my $t (@teas) {
	my $res = DateTime->compare($t->[0], DateTime->now());
	print "Checking the $t->[1], which is ready at $t->[0]: $res\n";
	if($res < 1) {
	    while (my ($k,$v)  = each %{$config->{reportChans}}) {
		if($v == 1) {
		    my $tea = ucfirst($t->[1]);
		    $self->say(channel => "#$k", body=>"$tea now ready $t->[2]. Thanks $t->[3]!");
		}
	    }
	} else {
	    push @newTeas, $t;
	}
    }
    @teas = @newTeas;
    return 5;
}

# help text for the bot
sub help { $helptext; }

if( -f "config.json") {
    print "Loading config.json\n";
    my $json_text = "";
    open(my $fh, '<', "config.json");
    $json_text = join("", <$fh>);
    close($fh);
    $config = JSON::decode_json($json_text);
}
else {
    $config->{reportChans}->{"bottest"} = 1;
}

my @chans = ();
while (my ($k,$v)  = each %{$config->{reportChans}}) {
    if($v == 1) {
	push @chans, "#$k";
    }
}

my $bot = TeaBot->new(
    server => "irc0.codethink.co.uk",
    channels => \@chans,
    nick      => $config->{nick},
    username  => $config->{username},
    password => $config->{password},
    name      => "Utah Teabot",
    ssl       => 1,
    port      => 6697,
    ignore_list => [qw(marvin medibot)],
);
$bot->{IRCNAME} = "utah";
$bot->run();
