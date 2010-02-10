package Plack::Middleware::AutoRefresh;
use strict;
use warnings;
use parent qw( Plack::Middleware );

our $VERSION = '0.03';

use Plack::Util;
use Plack::Util::Accessor qw( dirs filter );

# TODO: should timeout and try again after x seconds
# TODO: configuration!!!
# TODO: clean up the code
# TODO: what about with -restart
# TODO: move to its own distribution

use AnyEvent;
use AnyEvent::Filesys::Notify;
use Data::Dump qw(pp dd);
use JSON::Any;
use File::Slurp;

my $insert = '<script>'
  . read_file("$ENV{HOME}/src/plack-autorefresh/js/plackAutoRefresh.js")

  # . read_file("js/plackAutoRefresh.js")
  . '</script>';

sub prepare_app {
    my $self = shift;

    warn "autorefresh: prepare_app\n";

    my $filter =
      $self->filter
      ? (
        ref $self->filter eq 'CODE'
        ? $self->filter
        : sub { $_[0] !~ $self->filter } )
      : sub { 1 };

    ## TODO: warn the user if none of the dirs exists

    $self->{watcher} = AnyEvent::Filesys::Notify->new(
        dirs => $self->dirs || ['.'],
        cb => sub {
            my @events = grep { $filter->( $_->path ) } @_;
            return unless @events;

            warn "detected change: ", substr( $_->path, -70 ), "\n" for @events;
            $self->file_change_event_handler(@events);
        },
    );

    $self->{condvars} = [];
    $self->{load_time} = time;
}

sub call {
    my ( $self, $env ) = @_;

    warn "autorefresh: call\n";

    # Looking for updates on changed files
    if ( $env->{PATH_INFO} =~ m{^/_plackAutoRefresh(?:/(\d+))?} ) {
        warn "autorefresh: requested ", $env->{PATH_INFO}, "\n";
        warn "autorefresh: time $1\n";
        if ( defined $1 && $1 < $self->{load_time} ) {
            return $self->respond(
                { reload => 1, changed => $self->{load_time} } );
        } else {
            my $cv = AE::cv;
            push @{ $self->{condvars} }, $cv;
            return sub {
                my $respond = shift;
                $cv->cb( sub { $respond->( $_[0]->recv ) } );
            };
        }
    }

    # Wants something from the real app. Give it w/ our script insert.
    my $res = $self->app->($env);
    ## warn "res: ", pp($res), "\n";
    $self->response_cb(
        $res,
        sub {
            my $res = shift;
            my $ct = Plack::Util::header_get( $res->[1], 'Content-Type' );

            if ( $ct =~ m!^(?:text/html|application/xhtml\+xml)! ) {
                return sub {
                    my $chunk = shift;
                    return unless defined $chunk;
                    $chunk =~ s{<head>}{"<head>" . $self->insert}ei;
                    $chunk;
                  }
            }
        } );
}

sub insert {
    my ($self) = @_;

    # TODO: get from config
    my %var = (
        wait => 5 * 1000,
        host => '/_plackAutoRefresh',
        now  => time,
    );

    my $insert_js = $insert;
    $insert_js =~ s/{{([^}]*)}}/@{[ $var{$1} ]}/g;

    return $insert_js;
}

sub file_change_event_handler {
    my $self = shift;

    my $now = time;
    warn "file_change_event_handler: changed: $now\n";
    while ( my $condvar = shift @{ $self->{condvars} } ) {
        $condvar->send( $self->respond( { changed => $now } ) );
    }
}

sub respond {
    my ( $self, $resp ) = @_;

    # TODO: check that resp is a hash ref
    exists $resp->{$_} or $resp->{$_} = 0 for qw(reload changed);

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ JSON::Any->new->encode($resp) ] ];
}

1;
