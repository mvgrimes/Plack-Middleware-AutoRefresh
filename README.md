# NAME

Plack::Middleware::AutoRefresh - Reload pages in browsers when files are modified

# VERSION

version 0.09

# STATUS

<div>
    <a href="https://travis-ci.org/mvgrimes/Plack-Middleware-AutoRefresh"><img src="https://travis-ci.org/mvgrimes/Plack-Middleware-AutoRefresh.svg?branch=master" alt="Build Status"></a>
    <a href="https://metacpan.org/pod/Plack::Middleware::AutoRefresh"><img alt="CPAN version" src="https://badge.fury.io/pl/Plack-Middleware-AutoRefresh.svg" /></a>
</div>

# SYNOPSIS

    # in app.psgi
    use Plack::Builder;

    builder {
        enable 'Plack::Middleware::AutoRefresh',
               dirs => [ qw/html/ ], filter => qr/\.(swp|bak)/;
        $app;
    }

# DESCRIPTION

Plack::Middleware::AutoRefresh is a middleware component that will
reload you web pages in your browser when changes are detected in the
source files. It should work with any modern browser that supports
JavaScript and multiple browsers simultaneously.

At this time, this middleware will only work with backend servers that
set psgi.nonblocking to true. Servers that are known to work include
[Plack::Server::AnyEvent](https://metacpan.org/pod/Plack::Server::AnyEvent) and [Plack::Server::Coro](https://metacpan.org/pod/Plack::Server::Coro).  You can force
a server with the `-s` or `--server` flag to `plackup`.

# CONFIGURATION

    dirs => [ '.' ]                     # default
    dirs => [ qw/root share html/ ]

Specifies the directories to watch for changes. Will watch all files 
and subdirectories of the specified directories for file modifications,
new files, deleted files, new directories and deleted directories.

    filter => qr/\.(swp|bak)$/           # default
    filter => qr/\.(svn|git)$/
    filter => sub { shift =~ /\.html$/ }

Will apply the specified filter to the changed path name. This can be
a regular expression or a code ref. Any paths that match the regular
expression will be ignored. A code ref will be passed the path as the
only argument. Any false return values will be filtered out.

    wait => 5                           # default 

Wait indicated the maximum number of seconds that the client should
block for while waiting for notifications of changes. Setting this to
a lower value will _not_ improve response times. 

# ACKNOWLEDGMENTS

This component was inspired by NodeJuice ([http://nodeJuice.com/](http://nodeJuice.com/)).
NodeJuice provides very similar browser refresh functionality by
running a standalone proxy between your client and the web
application. It is a bit more robust than
Plack::Middleware::AutoRefresh as it can handle critical errors in
your app (ie, compile errors).  Plack::Middleware::AutoRefresh is
simpler to setup and is limited to [Plack](https://metacpan.org/pod/Plack) based applications. Some
of the original JavaScript was taken from nodeJuice project as well,
although it was mostly rewritten prior to release. Thank you to
Stephen Blum the author of nodeJuice.

A huge thank you to the man behind [Plack](https://metacpan.org/pod/Plack), Tatsuhiko Miyagawa, who
help me brainstorm the implementation, explained the inners of the
Plack servers, and re-wrote my broken code. 

# IMPLEMENTATION

Plack::Middleware::AutoRefresh accomplishes the browser refresh by
inserting a bit (1.2K to be precise) of JavaScript into the (x)html
pages your Plack application on the fly. The JavaScript tries to have
minimal impact: only one anonymous function and one global flag
(window\['-plackAutoRefresh-'\]) are added. The JavaScript will open an
Ajax connection back to your Plack server which will block waiting to
be notified of changes. When a change notification arrives, the
JavaScript will trigger a page reload.

# SEE ALSO

NodeJuice at [http://www.nodejuice.com/](http://www.nodejuice.com/).

Modules used to implement this module [AnyEvent::Filesys::Notify](https://metacpan.org/pod/AnyEvent::Filesys::Notify). 

And of course, [Plack](https://metacpan.org/pod/Plack).

# AUTHOR

Mark Grimes, <mgrimes@cpan.org>

# SOURCE

Source repository is at [https://github.com/mvgrimes/Plack-Middleware-AutoRefresh](https://github.com/mvgrimes/Plack-Middleware-AutoRefresh).

# BUGS

Please report any bugs or feature requests on the bugtracker website [http://github.com/mvgrimes/Plack-Middleware-AutoRefresh/issues](http://github.com/mvgrimes/Plack-Middleware-AutoRefresh/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Mark Grimes, <mgrimes@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
