#!/usr/bin/perl -w

use Data::Dumper;
use DateTime;
use JSON;
# To use this you need: apt-get install libbot-basicbot-perl libpoe-component-sslify-perl

package TeaBot;
use base qw(Bot::BasicBot);

my @teas = ();
my $config = {};
my $helptext = 'Try: "utah: Earl grey, 300, 5 minutes"';
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
	my $msg = lc($message->{'body'});
	chomp($msg);
	if ($msg eq "quit") {
	    $self->shutdown( "kbai");
	}
	elsif ($msg =~ /^report to #(\S+)/) {
	    $config->{reportChans}->{$1} = 1;
	    saveConfig();
	}
	elsif ($msg =~ /^(no|do not) report to #(\S+)/) {
	    $config->{reportChans}->{$2} = 0;
	    saveConfig();
	}
	elsif ($msg =~ /^cancel/) {
	    @teas = ();
	    return "OK, I have cancelled all tea notifications.";
	}
	elsif ($msg =~ /,/) {
	    my @fields = split(/,/, $msg);
	    my $location = "an unknown location";
	    my $delay = 0;
	    my $tea = "Mystery tea";
	    my $brewer = $message->{'who'};
	    for my $f(@fields) {
		chomp($f);
		if($f =~ /(\d+)\s*(m|min|mins)/i) {
		    $delay = $1;
		}
		elsif($f =~ /(300|302)/) {
		    $location = $1;
		}
		else {
		    $tea = $f;
		}
	    }
	    if($delay == 0) {
		return "Please tell me how many minutes you want to wait (e.g. 5m)"
	    }
	    print "$tea ready in $delay minutes in $location\n";
	    my $dt = DateTime->now;
	    $dt->add(minutes=>$delay);
	    push @teas, [$dt ,$tea, $location, $brewer];
	    return "OK";
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
		    $self->say(channel => "#$k", body=>"$t->[1] now ready in $t->[2]. Thanks $t->[3]!");
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
while (my ($k,$v)  = each $config->{reportChans}) {
    if($v == 1) {
	push @chans, "#$k";
    }
}

my $bot = TeaBot->new(
    server => "irc0.codethink.co.uk",
    channels => \@chans,
    nick      => "utah",
    username  => $config->{username},
    password => $config->{password},
    name      => "Utah Teabot",
    ssl       => 1,
    port      => 6697,
    ignore_list => [qw(dipsy dadadodo laotse)],
);
$bot->{IRCNAME} = "utah";
$bot->run();
