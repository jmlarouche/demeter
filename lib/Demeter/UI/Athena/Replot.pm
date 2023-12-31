package Demeter::UI::Athena::Replot;

use strict;
use warnings;
use base qw( Exporter );
our @EXPORT = qw(replot $APP);

our $APP = $::app;

sub replot {
  my ($plot, $space, $how) = @_;
  $::app->plot(q{}, q{}, $space, $how), $/;
};

1;

=head1 NAME

Demeter::UI::Athena::Replot - A replotting abstraction for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module exports a single function which is a generalized replotter
used throughout Athena.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
