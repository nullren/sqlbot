#!/usr/bin/env perl

use strict;
use warnings;
use Switch;

use POE qw(Component::IRC);
use DBI;

my $giturl = "http://github.com/nullren/sqlbot";

####### #######
####### #######

my $SERVER = 'irc.foonetic.net';
my @CHANNELS = qw(#mathematics #spam);

my $NICK = 'mathsql';
my $USERNAME = 'banana';
my $IRCNAME = 'ask me for help';

my $log_dsn = "DBI:mysql:database=woodstove";
my $dsn     = "DBI:mysql:database=botshitz";

my $perl_location = `which perl`; chomp $perl_location;
my $script_location = "$0";
sleep 2;

####### #######

my $IRC_ALIAS = 'butt';

#sleep 3; #time to respawn

my $log_dbh = DBI->connect($log_dsn,'logger','donger', {'RaiseError' => 1}) or die "failed: $@\n";
my $dbh     = DBI->connect(    $dsn,'derpoid','lolzwut', {'RaiseError' => 1}) or die "failed: $@\n";

my $log_chat = $log_dbh->prepare('INSERT INTO logs (target, nick, text) VALUES (?, ?, ?)') or die "could not make prepare statement: " . $log_dbh->errstr;

my $irc = POE::Component::IRC->spawn(
    nick => $NICK,
    ircname => $IRCNAME,
    username => $USERNAME,
    server => $SERVER,
    alias => $IRC_ALIAS, ) or die "uhhhhhh $!";
    
POE::Session->create( inline_states => {
    _start => sub {
        $_[KERNEL]->post( $IRC_ALIAS => register => 'all' );
        $_[KERNEL]->post( $IRC_ALIAS => connect => {} );
    },
    irc_001 => sub {
        foreach my $chan (@CHANNELS){
            $_[KERNEL]->post( $IRC_ALIAS => join => $chan );
        }
    },
    irc_433 => sub {
        $_[KERNEL]->post( $IRC_ALIAS => nick => $NICK . $$%1000 );
    },
    irc_kick => sub {
        exit 0;
    },
    irc_public => sub {
        my ($kernel, $heap, $who, $where, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
        my $nick    = (split /!/, $who)[0];
        my $channel = $where->[0];
        my $ts      = scalar localtime;
        print " [$ts] <$nick:$channel> $msg\n";
        # write to db
        $log_chat->execute($channel, $nick, $msg) or die "could not execute statement: " . $log_chat->errstr;

        if( $msg =~ /^!(.+)$/ ){
            my $query = $1;
            if( $query =~ /^(select|call|show)/i ){
                eval { 
                    my $sth = $dbh->prepare("$query");
                    $sth->execute; 
                    my (@matrix) = ();
                    my $c = 0;
                    my $COLS = 0;
                    while (my @ary = $sth->fetchrow_array()){
                        last if $c++ > 10;
                        push(@matrix, [@ary]);  # [@ary] is a reference
                        $COLS = scalar @ary;
                    }
                    $sth->finish();

                    $" = '\', \'';
                    if( $COLS == 1 ){
                        my @shit = ();
                        foreach my $row (@matrix){
                            push @shit, $$row[0]; 
                        }
                        $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "('@shit')");
                    } else {
                        foreach my $row (@matrix){
                            $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => (scalar @$row > 1 ? "('@$row')" : "@$row"));
                        }
                    }
                } or $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$@");
            } elsif( $query =~ /^help/i ){
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "come check me out at $giturl");
            #} elsif( $query =~ /^(insert|update)/i ){
            } elsif( $query =~ /^quit/i ){
                exit 0;
            } elsif( $query =~ /^respawn/i ){
                exec $perl_location, $script_location;
                exit 0;
            } else {
                my $c = 0;
                eval { $c = $dbh->do("$1"); } or $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$@");
                $_[KERNEL]->post( $IRC_ALIAS => privmsg => $channel => "$c rows affected");
            }
        }
    },
    _child => sub {},
    _default => sub {
        #printf "%s: session %s caught an unhandled %s event.\n",
        #    scalar localtime(), $_[SESSION]->ID, $_[ARG0];
#        print "$_[ARG0]: ",
#            join(" ", map({"ARRAY" eq ref $_ ? "" : "$_"} @{$_[ARG1]})),
#            "\n";
        0;    # false for signals
    },
},);

POE::Kernel->run;
