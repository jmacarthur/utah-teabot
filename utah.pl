#!/usr/bin/perl -w

use Data::Dumper;
use DateTime;
use JSON;
# To use this you need: apt-get install libbot-basicbot-perl libpoe-component-sslify-perl libjson-perl libdatetime-perl

package TeaBot;
use base qw(Bot::BasicBot);

my @teas = ();
my @zara_reminders = ();
my $config = {};
my $helptext = 'Try: "utah: Earl grey, 300, 5 minutes"';
my $time_regex = qr/(\d+)\s*(m|min|mins)/;

my $missing_time_err = "Please tell me how many minutes you want to wait (e.g. 5m)";
my $NASTY_FRUIT_TEA = "nasty fruit tea";
my $ZARA_REMIND_PREFIX = "remind zara, ";

my @tea_blacklist = ('AF', 'arctic fire');

sub saveConfig()
{
    $json_text   = JSON::encode_json( $config );
    open(my $fh, '>', "config.json");
    print $fh $json_text;
    close($fh);
}

sub is_approved_tea
{
	my $t = shift;
	return (grep { /$t/i } @tea_blacklist) == 0;
}

sub parse_msg
{
    my $msg = shift;

    my @fields = split(/,/, $msg);
    my $location = "an unknown location";
    my $delay = -1;
    my $tea = "Mystery tea";

    for my $f(@fields) {
	chomp($f);
	if($f =~ qr/$time_regex/i) {
	    $delay = $1;
	}
	elsif($f =~ /now/i) {
	    $delay = 0;
	}
	elsif($f =~ /(300|302|101|jeff|geoff|sean|shaun)/i) {
	    $location = $1;
	}
	else {
	    $tea = $f;
	}
    }

    return ($tea, $location, $delay);
}

sub said
{
    my ($self, $message) = @_;
    print "Message from $message->{'who'}: $message->{'body'}\n";
    if ($message->{'address'}) {
	my $msg = $message->{'body'};
	chomp($msg);
	if (lc($msg) eq "quit") {
	    $self->shutdown( "kbai");
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
	elsif ($msg =~ /,/ and $msg =~ qr/^$ZARA_REMIND_PREFIX/i) {
		# remind zara, make almond tea, 10m
		# parse_fields
		my ($tea, $location, $delay) = parse_msg(substr($msg, length($ZARA_REMIND_PREFIX)));

		if ($delay == -1) {
			return $missing_time_err;
		}

		my $dt = DateTime->now;
		$dt->add(minutes=>$delay);
		chomp($tea);

		if (not is_approved_tea($tea)) {
			$tea = $NASTY_FRUIT_TEA;
		}

		push @zara_reminders, [$dt, $tea, $location, 'Zara'];
		return "OK";
	}
	elsif ($msg =~ /,/) {
	    my $brewer = $message->{'who'};
	    my ($tea, $location, $delay) = parse_msg($msg);

	    if($delay == -1) {
		return $missing_time_err;
	    }

	    print "$tea ready in $delay minutes in $location\n";
	    my $dt = DateTime->now;
	    $dt->add(minutes=>$delay);
	    chomp($tea);

	    if (not is_approved_tea($tea)) {
	    	$tea = $NASTY_FRUIT_TEA;
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
	    while (my ($k,$v)  = each $config->{reportChans}) {
		if($v == 1) {
		    my $tea = ucfirst($t->[1]);
		    $self->say(channel => "#$k", body=>"$tea now ready in $t->[2]. Thanks $t->[3]!");
		}
	    }
	} else {
	    push @newTeas, $t;
	}
    }
    for my $zr (@zara_reminders) {
	my ($dt, $tea, $location, $brewer) = @$zr;

    	my $res = DateTime->compare($dt, DateTime->now());
    	print "ZARA REMINDER: Checking the reminder for $tea: $res\n";
    	if ($res < 1) {
    		while (my ($k, $v) = each %{$config->{reportChans}}) {
    			if ($v == 1) {
    				$self->say(channel => "Zara", body=>"Zara reminder: $tea ($location)");
    			}
    		}
    	} else {
    		push @new_zara_reminders, $zr;
    	}
    }
    @teas = @newTeas;
    @zara_reminders = @new_zara_reminders;
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
while (my ($k,$v)  = each $config->{reportChans}) {
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
