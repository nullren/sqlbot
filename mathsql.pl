#!/usr/bin/env perl

use strict;
use warnings;

use POE qw(Component::IRC);
use DBI;

my $giturl = "http://github.com/nullren/sqlbot";
my $git_dir = "/home/ren/src/sqlbot";

####### #######

my $SERVER = 'irc.foonetic.net';
my $PORT = 6697;
my $USESSL = 1;
my @CHANNELS = qw(#mathematics);

my $NICK = 'mathsql';
my $USERNAME = 'banana';
my $IRCNAME = 'joannac';

####### #######

my $dsn     = "DBI:mysql:database=botshitz";

my $perl_location = `which perl`; chomp $perl_location;
my $script_location = "$0";
sleep 2;

####### #######

my $IRC_ALIAS = 'butt';

my $dbh     = DBI->connect_cached(    $dsn,'derpoid','lolzwut', {'RaiseError' => 1}) or die "failed: $@\n";

my $irc = POE::Component::IRC->spawn(
    nick => $NICK,
    ircname => $IRCNAME,
    username => $USERNAME,
    server => $SERVER,
    port => $PORT,
    usessl => $USESSL,
    alias => $IRC_ALIAS, ) or die "uhhhhhh $!";
    
POE::Session->create( inline_states => {
    _start => sub {
        $_[KERNEL]->post( $IRC_ALIAS => register => 'all' );
        $_[KERNEL]->post( $IRC_ALIAS => connect => {} );
    },
    irc_001 => sub {
        $_[KERNEL]->post( $IRC_ALIAS => mode => $NICK => "+B" );
        $_[KERNEL]->post( $IRC_ALIAS => join => $_ ) for @CHANNELS;
    },
    irc_433 => sub {
        $_[KERNEL]->post( $IRC_ALIAS => nick => $NICK . $$%1000 );
    },
    irc_kick => sub {
        my ($kernel, $heap, $kicker, $where, $kickee, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2, ARG3];
        my $ts      = scalar localtime;
        print " [$ts] $kicker kicked $kickee from $where: $msg\n";
        exit 0 if $kickee eq $NICK;
    },
    irc_public => \&handle_msg,
    irc_msg => \&handle_msg,
    _child => sub {},
    _default => sub {
        0;    # false for signals
    },
},);

POE::Kernel->run;

sub handle_msg {
    my ($kernel, $heap, $who, $where, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    my $nick    = (split /!/, $who)[0];
    my $channel = $where->[0];
    my $ts      = scalar localtime;
    print " [$ts] <$nick:$channel> $msg\n";

    $channel = $nick if $channel eq $NICK;

    # write to db
    $dbh     = DBI->connect_cached(    $dsn,'derpoid','lolzwut', {'RaiseError' => 1}) or die "failed: $@\n";

    if( $msg =~ /^!(.+)$/ ){
        my $query = $1;
        if( $query =~ /^(select|call|show|desc)/i ){
            eval { 
                my $sth = $dbh->prepare("$query");
                $sth->execute; 
                my (@matrix) = ();
                my $c = 0;
                my $COLS = 0;
                while (my @ary = $sth->fetchrow_array()){
                    $COLS = scalar @ary;
                    last if ++$c > ($COLS==1?50:3);
                    push(@matrix, [@ary]);  # [@ary] is a reference
                }
                $sth->finish();

                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "empty set") if $c == 0;

                $" = '\', \'';
                if( $COLS == 1 ){
                    my @shit = ();
                    push @shit, $$_[0] for @matrix;
                    $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => (scalar @shit > 1 ? "('@shit')" : "@shit"));
                } else {
                    foreach my $row (@matrix){
                        $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => (scalar @$row > 1 ? "('@$row')" : "@$row"));
                    }
                }
            } or $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$@");
        } elsif( $query =~ /^help/i ){
            $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "come check me out at $giturl");
        } elsif( $query =~ /^respawn/i ){
            system "cd $git_dir && git pull";
            exec $perl_location, $script_location;
            exit 0;
        } else {
            my $c = 0;
            eval { 
              $c = $dbh->do("$query"); 
              $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$c rows affected");
            } or $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$@");
        }
    } elsif( $msg =~ /^$NICK[:,] (\d+) pushups$/ ){
        my $pushups = $1;
        my $c = 0;
        eval { 
          $c = $dbh->do("INSERT INTO pushup_battle (dude, pushups) VALUES ('$nick', $pushups)"); 
          $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$c set of pushups recorded for $nick");
        } or $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$@");
    }
}

