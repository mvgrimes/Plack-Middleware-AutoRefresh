#!/usr/bin/env perl

use strict;
use warnings;
use lib './lib';
use Plack::Builder;
use File::Slurp;

my $app = sub {
    return [
        404, [ 'Content-Type' => 'text/plain' ],
        ['Not found, try /index.html'] ];
};

builder {
    enable "Plack::Middleware::AutoRefresh",
      dirs   => ['html'],
      # filter => sub { shift =~ /index/ };
      filter => qr/.swp|.bak/;
    enable "Plack::Middleware::Static", path => sub { 1 }, root => 'html';
    $app;
}

