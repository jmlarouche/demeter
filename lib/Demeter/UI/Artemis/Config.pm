package  Demeter::UI::Artemis::Config;

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

use strict;
use warnings;

use Wx qw( :everything );
use Wx::Event qw(EVT_CLOSE EVT_BUTTON);
use base qw(Wx::Frame);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Preferences]",
				wxDefaultPosition, [650,500],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  $this -> SetBackgroundColour( wxNullColour );
  EVT_CLOSE($this, \&on_close);

  my $box = Wx::BoxSizer->new( wxVERTICAL );
  my $config = Demeter::UI::Wx::Config->new($this, \&target);
  $config->populate([sort qw(gnuplot indicator marker artemis feff happiness pathfinder fft plot atoms
			     file histogram bft fit interpolation bkg fspath lcf warnings gds
			     operations)]);


  $config->{params}->Expand($config->{params}->GetRootItem);
  $box->Add($config, 1, wxGROW|wxALL, 5);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxGROW|wxALL, 0);

  my $doc = Wx::Button->new($this, wxID_ABOUT, q{});
  $hbox->Add($doc, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $doc, sub{$::app->document('prefs')});
  my $close = Wx::Button->new($this, wxID_CLOSE, q{});
  $hbox->Add($close, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $close, \&on_close);

  $this->SetSizer($box);
  return $this;
};

sub target {
  my ($self, $parent, $param, $value, $save) = @_;

 SWITCH: {
    ($param eq 'plotwith') and do {
      $Demeter::UI::Artemis::demeter->plot_with($value);
      last SWITCH;
    };
    ($param eq 'rmax_out') and do {
      foreach my $k (keys(%Demeter::UI::Artemis::frames)) {
	next unless ($k =~ m{\Adata});
	my $this = $Demeter::UI::Artemis::frames{$k}->{data};
	$this->rmax_out($value);
      };
      last SWITCH;
    };
  };

  ($save)
    ? $Demeter::UI::Artemis::frames{main}->status("Now using $value for $parent-->$param and an ini file was saved")
      : $Demeter::UI::Artemis::frames{main}->status("Now using $value for $parent-->$param");

};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
};

1;


=head1 NAME

Demeter::UI::Artemis::Config - A configuration buffer for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module provides a window for displaying Demeter's standard
Wx-based configuration utility.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Exclude "atoms", "feff", and "pathfinder" groups?

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
