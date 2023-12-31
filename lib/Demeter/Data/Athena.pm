package Demeter::Data::Athena;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use autodie qw(open close);

use Moose::Role;

use Carp;
use Compress::Zlib;
use Data::Dumper;

sub write_athena {
  my ($self, $filename, @list) = @_;
  croak("You must supply a filename to the write_athena method") if ( (not defined($filename)) or
								      (ref($filename) =~ m{Data}) );
  my $gzout = gzopen($filename, 'wb9');
  $gzout->gzwrite("# Athena project file -- Demeter version " . $self->version . "\n" .
		  "# This file created at " . $self->now . "\n" .
		  "# Using " . $self->environment . "\n\n");

  ##$gzout->gzwrite('$filename = ' . $filename . ";\n\n");
  $gzout->gzwrite($self->_write_record);
  my $journal = q{};
  foreach my $d (@list) {
    next if ($d eq $self);
    if (ref($d) =~ m{Journal}) {
      $journal ||= $d;
      next;
    };
    $gzout->gzwrite($d->_write_record);
  };
  if ($journal) {
    my @journal = split(/\n/, $journal->text);
    local $Data::Dumper::Indent = 0;
    $gzout->gzwrite(Data::Dumper->Dump([\@journal], [qw/*journal/]));
  };
  $gzout->gzwrite('

1;

# Local Variables:
# truncate-lines: t
# End:
');
  $gzout->gzclose;
  return $self;
};

sub _write_record {
  my ($self) = @_;
  croak("You can only write Data objects to Athena files") if (ref($self) !~ m{Data});
  #print $self->group, " ", $self->name, $/;

  my $compatibility = Demeter->co->get('athena_compatibility');

  local $Data::Dumper::Indent = 0;
  my ($string, $arraystring) = (q{}, q{});

  $self->_update('normalize');
  my @array = ();
  if ($self->datatype =~ m{(?:xmu|xanes)}) {
    #$self -> _update("background");
    @array        = $self -> get_array("energy");
    $arraystring .= Data::Dumper->Dump([\@array], [qw/*x/]) . "\n";
    @array        = $self -> get_array("xmu");
    $arraystring .= Data::Dumper->Dump([\@array], [qw/*y/]) . "\n";
    if (($self->i0_string) and ($self->i0_string ne '1')) {
      @array        = $self -> get_array("i0");
      $arraystring .= Data::Dumper->Dump([\@array], [qw/*i0/]) . "\n";
    };
    if ($self->get("signal_string")) {
      @array        = $self -> get_array("signal");
      $arraystring .= Data::Dumper->Dump([\@array], [qw/*signal/]) . "\n";
    };
    if ($self->get_array("stddev")) {
      @array        = $self -> get_array("stddev");
      $arraystring .= Data::Dumper->Dump([\@array], [qw/*stddev/]) . "\n";
    };
    ## merge array?
  } elsif ($self->datatype eq "chi") {
    $self->read_data if ($self->update_data);
    @array        = $self -> get_array("k");
    $arraystring .= Data::Dumper->Dump([\@array], [qw/*x/]) . "\n";
    @array        = $self -> get_array("chi");
    $arraystring .= Data::Dumper->Dump([\@array], [qw/*y/]) . "\n";
    ## merge array?
  };
  ## xmudat?? xanes?? detector??

  my %hash = $self -> all;

  # -------- clean up non-athena attributes --------------------
  delete $hash{$_} foreach (qw(group plottable data mode cv));
  map {delete $hash{$_} if ($_ =~ m{\Afit}) } keys(%hash);

  $hash{plot_yoffset} = $hash{'y_offset'};
  delete $hash{'y_offset'};
  $hash{plot_scale} = $hash{plot_multiplier};
  delete $hash{plot_multiplier};
  $hash{label} = $hash{name};
  delete $hash{name};

  $hash{is_xmu}    = 1 if ($hash{datatype} =~ m{(?:xmu|xanes)});
  $hash{is_xanes}  = 1 if ($hash{datatype} eq 'xanes');
  $hash{is_chi}    = 1 if ($hash{datatype} eq 'chi');
  $hash{is_xmudat} = 1 if ($hash{datatype} eq 'xmudat');
  delete $hash{datatype};

  $hash{reference} = $hash{reference}->group if ($hash{reference});
  # ------------------------------------------------------------
  # -------- clean up non-pre-0.9.18 attributes ----------------
  if ($compatibility) {
    ## introduced in 0.9.18
    delete $hash{bkg_delta_eshift};
    delete $hash{bkg_nc3};
    delete $hash{bkg_is_pixel};
  };
  # ------------------------------------------------------------

  @array   = %hash;

  $string  = '$old_group = \'' . $self->group . "';\n";
  $string .= Data::Dumper->Dump([\@array], [qw/*args/]) . "\n";
  $string .= $arraystring;
  $string .= "[record]   # create object and set arrays in ifeffit\n\n";
  return $string;
};

1;


=head1 NAME

Demeter::Data::Athena - Write Athena project files

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 DESCRIPTION

This subclass of Demeter::Data contains methods for interacting with
Athena.  See L<Demeter::Data::Prj> for Demeter's method of
reading Athena project file.

=head1 METHODS

=over 4

=item C<write_athena>

Export one or more Data objects to an Athena project file.  The first
argument is the filename for the project file.  This is followed by a
list additional data objects to export.  The caller will be the first
group in the project file, followed by the addition data in the order
supplied.  If the caller is also in the list, it will I<not> be
written twice to the project file.

  $data -> write_athena("athena.prj", @list_of_data);

=head1 DIAGNOSTICS

=over 4

=item C<You must supply a filename to the write_athena method>

The first argument of the C<write_athena> method must be a filename.

=item C<You can only write Data objects to Athena files>

You have tried to write an object that is not a Data object to an
Athena project file.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

The plot features and indicator entries are not yet written to the
project file.

=item *

xmudat and detector array types are not currently written to the
project file.

=item *

The merge array is not currently written by C<write_record>.

=back

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
