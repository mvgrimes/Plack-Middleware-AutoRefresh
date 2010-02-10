package Plack::Middleware::AutoRefresh;
use strict;
use warnings;
use parent qw( Plack::Middleware );

our $VERSION = '0.04';

use Plack::Util;
use Plack::Util::Accessor qw( dirs filter wait );

use AnyEvent;
use AnyEvent::Filesys::Notify;
use JSON::Any;
use File::Slurp;
use File::ShareDir qw(dist_file);
use File::Basename;
use Carp;

use constant {
    URL    => '/_plackAutoRefresh',
    JS     => 'js/plackAutoRefresh.min.js',
    JS_DEV => 'js/plackAutoRefresh.js',
};

sub prepare_app {
    my $self = shift;

    # Setup config params: filter, wait, dirs

    $self->{filter} ||= sub { $_[0] !~ qr/\.(swp|bak)$/ };
    $self->{filter} = sub { $_[0] !~ $self->filter }
      if ref( $self->filter ) eq 'Regexp';
    croak "AutoRefresh: filter must be a regex or code ref"
      unless ref( $self->filter ) eq 'CODE';

    $self->{wait} ||= 5;

    $self->{dirs} ||= ['.'];
    -d $_ or carp "AutoRefresh: can't find directory $_" for @{ $self->dirs };

    # Create the filesystem watcher
    $self->{watcher} = AnyEvent::Filesys::Notify->new(
        dirs     => $self->dirs,
        interval => 0.5,
        cb       => sub {
            my @events = grep { $self->filter->( $_->path ) } @_;
            return unless @events;

            warn "detected change: ", substr( $_->path, -70 ), "\n" for @events;
            $self->_change_handler(@events);
        },
    );

    # Setup an array to hold the condition vars, record the load time as
    # the last change to deal with restarts, and get the raw js script
    $self->{condvars}    = [];
    $self->{last_change} = time;
    $self->{_script}     = $self->_get_script;

}

sub call {
    my ( $self, $env ) = @_;

    # Client is looking for changed files
    if ( $env->{PATH_INFO} =~ m{^/_plackAutoRefresh(?:/(\d+))?} ) {

        # If a change has already happened return immediately,
        # otherwise make the browser block while we wait for change events
        if ( defined $1 && $1 < $self->{last_change} ) {
            return $self->_respond( { changed => $self->{last_change} } );
        } else {
            my $cv = AE::cv;
            push @{ $self->{condvars} }, $cv;
            return sub {
                my $respond = shift;
                $cv->cb( sub { $respond->( $_[0]->recv ) } );
            };
        }
    }

    # Client wants something from the real app.
    # Insert our script if it is an html file
    my $res = $self->app->($env);
    $self->response_cb(
        $res,
        sub {
            my $res = shift;
            my $ct = Plack::Util::header_get( $res->[1], 'Content-Type' );

            if ( $ct =~ m!^(?:text/html|application/xhtml\+xml)! ) {
                return sub {
                    my $chunk = shift;
                    return unless defined $chunk;
                    $chunk =~ s{<head>}{'<head>' . $self->_insert}ei;
                    $chunk;
                  }
            }
        } );
}

# Return the js script updating the time and adding config params
sub _insert {
    my ($self) = @_;

    my %var = (
        wait => $self->wait * 1000,
        url  => URL,
        now  => time,
    );

    ( my $script = $self->{_script} ) =~ s/{{([^}]*)}}/$var{$1}/eg;
    return $script;
}

# AFN saw a change, respond to each blocked client
sub _change_handler {
    my $self = shift;

    my $now = $self->{last_change} = time;
    while ( my $condvar = shift @{ $self->{condvars} } ) {
        $condvar->send( $self->_respond( { changed => $now } ) );
    }
}

# Generate the plack response and encode any arguments as json
sub _respond {
    my ( $self, $resp ) = @_;
    ## TODO: check that resp is a hash ref

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ JSON::Any->new->encode($resp) ] ];
}

# Return the js script from ShareDir unless we are developing/testing PMA.
# This is a bit hack-ish
sub _get_script {
    my $self = shift;

    my $dev_js_file =
      File::Spec->catfile( dirname( $INC{'Plack/Middleware/AutoRefresh.pm'} ),
        qw( .. .. .. share ), JS_DEV );

    my $is_dev_mode = -e $dev_js_file;

    my $script =
        $is_dev_mode
      ? $dev_js_file
      : dist_file( 'Plack-Middleware-AutoRefresh', JS );

    return '<script>' . read_file($script) . '</script>';
}

1;
