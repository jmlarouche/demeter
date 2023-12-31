package Demeter::UI::Athena::Plot::PlotK;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN
		 EVT_CHECKBOX EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::Replot;

use Scalar::Util qw(looks_like_number);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxGROW|wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slots = Wx::GridSizer->new( 2, 2, 0, 1 );
  $hbox -> Add($slots, 1, wxGROW|wxALL, 0);

  $this->{chie} = Wx::CheckBox->new($this, -1, $CHI.'(E)', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{chie}, 1, wxGROW|wxALL, 1);
  $this->{mchie} = Wx::CheckBox->new($this, -1, $CHI.'(E)', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mchie}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{chie},
	       sub{my ($this, $event) = @_;
		   if ($this->{chie}->GetValue) {
		     $this->{win}->SetValue(0);
		   };
		   $this->replot(qw(k single));
		 });
  EVT_CHECKBOX($this, $this->{mchie}, sub{$_[0]->replot(qw(k marked))});
  $app->mouseover($this->{chie},  "Plot $CHI(E) when ploting the current group in k-space.");
  $app->mouseover($this->{mchie}, "Plot $CHI(E) when ploting the marked groups in k-space.");

  $this->{win} = Wx::CheckBox->new($this, -1, 'Window', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{win}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{win},
	       sub{my ($this, $event) = @_;
		   if ($this->{win}->GetValue) {
		     $this->{chie}->SetValue(0);
		   };
		   $this->replot(qw(k single));
		 });
  $app->mouseover($this->{win}, "Plot the window function when ploting the current group in k-space.");


  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "single")) )
    foreach (qw(chie win));
  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "marked")) )
    foreach (qw(mchie));


  #$hbox -> Add(0, 1, 1);

  #my $right = Wx::BoxSizer->new( wxVERTICAL );
  #$hbox -> Add($right, 0, wxALL, 4);

  $box -> Add(1, 1, 1);

  my $range = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($range, 0, wxALL|wxGROW, 0);
  #$box -> Add($range, 0, wxBOTTOM, 7);
  my $label = Wx::StaticText->new($this, -1, "kmin", wxDefaultPosition, [35,-1]);
  $this->{kmin} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "kmin"),
				     wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{kmin}, 1, wxRIGHT, 10);
  $label = Wx::StaticText->new($this, -1, "kmax", wxDefaultPosition, [35,-1]);
  $this->{kmax} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "kmax"),
				     wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{kmax}, 1, wxRIGHT, 10);

  foreach my $x (qw(kmin kmax)) {
    $this->{$x} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
    EVT_TEXT_ENTER($this, $this->{$x}, sub{OnTextEnter(@_, $::app, $x)});
  };

  $this->SetSizerAndFit($box);
  return $this;
};


sub OnTextEnter {
  my ($main, $event, $app, $which) = @_;
  my @list = $app->marked_groups;
  my $how = (@list) ? 'marked' : 'single';
  $app->plot(q{}, q{}, 'k', $how);
};

sub label {
  return 'Plot in k-space';
};

sub pull_single_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  $po->chie($this->{chie} -> GetValue);

  my $kmin = $this->{kmin}-> GetValue;
  my $kmax = $this->{kmax}-> GetValue;
  $::app->{main}->status(q{}, 'nobuffer');
  $kmin = 0,  $::app->{main}->status("kmin is not a number", 'error|nobuffer') if not looks_like_number($kmin);
  $kmax = 15, $::app->{main}->status("kmax is not a number", 'error|nobuffer') if not looks_like_number($kmax);
  $po->kmin($kmin);
  $po->kmax($kmax);
};

sub pull_marked_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  $po->chie($this->{mchie}-> GetValue);

  my $kmin = $this->{kmin}-> GetValue;
  my $kmax = $this->{kmax}-> GetValue;
  $::app->{main}->status(q{}, 'nobuffer');
  $kmin = 0,  $::app->{main}->status("kmin is not a number", 'error|nobuffer') if not looks_like_number($kmin);
  $kmax = 15, $::app->{main}->status("kmax is not a number", 'error|nobuffer') if not looks_like_number($kmax);
  $po->kmin($kmin);
  $po->kmax($kmax);
};

1;


=head1 NAME

Demeter::UI::Athena::Plot::PlotK - k-space plotting controls

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module provides controls for plotting in k space in Athena

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
