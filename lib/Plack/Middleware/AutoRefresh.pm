package Plack::Middleware::AutoRefresh;
use strict;
use warnings;
use parent qw( Plack::Middleware );

our $VERSION = '0.01';

use Plack::Util;
use Plack::Util::Accessor qw( dir );

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

sub prepare_app {
    my $self = shift;

    warn "autorefresh: new\n";

    $self->{watcher} = AnyEvent::Filesys::Notify->new(
        dirs => [$self->dir],
        cb   => sub {
            my @events = grep { $_->path !~ /\.swp$/ } @_;
            return unless @events;

            print STDERR "detected change: ", pp(@events), "\n";
            $self->file_change_event_handler(@events);
        },
    );

    $self->{condvars} = [];
}

sub call {
    my ( $self, $env ) = @_;

    warn "autorefresh: call\n";

    # Looking for updates on changed files
    if ( $env->{PATH_INFO} =~ m{^/_plackAutoRefresh} ) {
        print STDERR "_plackAutoRefresh\n";
        my $cv = AE::cv;
        push @{$self->{condvars}}, $cv;
        return sub {
            my $respond = shift;
            $cv->cb(sub { $respond->($_[0]->recv) });
        };
    }

    # Wants something from the real app. Give it w/ our script insert.
    my $res = $self->app->($env);
    # warn "res: ", pp($res), "\n";

    $self->response_cb(
        $res,
        sub {
            my $res = shift;
            my $ct = Plack::Util::header_get($res->[1], 'Content-Type');

            if ($ct =~ m!^(?:text/html|application/xhtml\+xml)!) {
                return sub {
                    my $chunk = shift;
                    return unless defined $chunk;
                    $chunk =~ s{<head>}{"<head>" . $self->insert}ei;
                    $chunk;
                }
            }
        }
    );
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
