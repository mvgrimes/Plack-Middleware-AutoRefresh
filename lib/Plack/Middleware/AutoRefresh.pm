package Plack::Middleware::AutoRefresh;
use strict;
use warnings;
use parent qw( Plack::Middleware );

our $VERSION = '0.01';

use Plack::Util;
# use Plack::Util::Accessor qw( changed );

# TODO: should timeout and try again after x seconds
# TODO: configuration!!!
# TODO: clean up the code
# TODO: what about with -restart
# TODO: move to its own distribution

use AnyEvent;
use AnyEvent::Filesys::Notify;
use Data::Dump qw(pp dd);
use File::Slurp;

my $insert =
    '<script>'
  . read_file("js/plackAutoRefresh.js")
  . '</script>';
my $html_dir = 'html';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    die "can't file dir: $html_dir" unless -d $html_dir;
    $self->{watcher} = AnyEvent::Filesys::Notify->new(
        dirs => [$html_dir],
        cb   => sub {
            my @events = grep { $_->path !~ /\.swp$/ } @_;
            return unless @events;

            print STDERR "detected change: ", pp(@events), "\n";
            $self->file_change_event_handler(@events);
        },
    );

    $self->{condvars} = [];

    return $self;
}

sub call {
    my ( $self, $env ) = @_;

    # Looking for updates on changed files
    if ( $env->{PATH_INFO} =~ m{^/_plackAutoRefresh} ) {
        print STDERR "_plackAutoRefresh\n";
        my $condvar = AnyEvent->condvar;
        push @{ $self->{condvars} }, $condvar;
        return $condvar;
    }

    # Wants something from the real app. Give it w/ our script insert.
    my $res = $self->app->(@_);
    $self->response_cb(
        $res,
        sub {
            my $res     = shift;
            my $content = $res->[2];
            my %headers = @{ $res->[1] };

            if ( $headers{'Content-Type'} eq 'text/html'
                and ref($content) eq 'GLOB' )
            {
                my $content_str = do { local $/; <$content>; };
                my $insert = $self->insert;
                $content_str =~ s{<head>}{<head>$insert};
                $res->[2] = [$content_str];
            }
            return $res;
        } );
}

sub insert {
    my ($self) = @_;

    # TODO: get from config
    my %var = (
        wait => 3 * 1000,
        host => '/_plackAutoRefresh',
        now  => time,
    );

    my $insert_js = $insert;
    $insert_js =~ s/{{([^}]*)}}/@{[ $var{$1} ]}/g;

    return $insert_js;
}

sub file_change_event_handler {
    my $self = shift;

    my $now  = time;
    my $resp = [
        200, [ 'Content-Type' => 'application/json' ],
        [" { \"changed\": \"$now\" } "] ];

    print STDERR 'file_change_event_handler: ', pp($resp), "\n";
    for my $condvar (@{ $self->{condvars} }){
        $condvar->send($resp);
    }
}

1;
