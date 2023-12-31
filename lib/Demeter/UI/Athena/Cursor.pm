package Demeter::UI::Athena::Cursor;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);
use Time::HiRes qw(usleep);

use Wx qw( :everything );
use Wx::DND;
use base qw( Exporter );
our @EXPORT = qw(cursor);


# my %map = (
# 	   bkg_e0    => 'E0',
# 	   bkg_rbkg  => 'Rbkg',
# 	   bkg_pre1  => 'lower bound of pre-edge range',
# 	   bkg_pre2  => 'upper bound of pre-edge range',
# 	   bkg_nor1  => 'lower bound of normalization range',
# 	   bkg_nor2  => 'upper bound of normalization range',
# 	   bkg_spl1  => 'lower bound of spline range',
# 	   bkg_spl2  => 'upper bound of spline range',
# 	   bkg_spl1e => 'lower bound of spline range',
# 	   bkg_spl2e => 'upper bound of spline range',
# 	   fft_kmin  => 'lower bound of forward Fourier transform range',
# 	   fft_kmax  => 'upper bound of forward Fourier transform range',
# 	   bft_rmin  => 'lower bound of backward Fourier transform range',
# 	   bft_rmax  => 'upper bound of backward Fourier transform range',
# 	  );

sub cursor {
  my ($app, $frame) = @_;
  my ($x, $y) = (-100000, -100000);
  my $parent = $frame || $app->{main};
  my ($was, $is) = (q{ }, q{});

  my $return = Demeter::Return->new();
  my $busy;
  if (Demeter->mo->template_plot eq 'pgplot') {
    $app->{main}->status("Click on a point to pluck its value...", "wait");
    Demeter->dispose("cursor(crosshair=true)");
    ($x, $y) = (Demeter->fetch_scalar("cursor_x"), Demeter->fetch_scalar("cursor_y"));

  } elsif (Demeter->mo->template_plot eq 'gnuplot') {

    # my $recent;
    # if (wxTheClipboard->Open) {
    #   $recent = Wx::TextDataObject->new;
    #   wxTheClipboard->GetData( $recent );
    #   wxTheClipboard->Close;
    # };
    # $was = $recent->GetText;

    # my $yesno = Wx::MessageDialog
    #   -> new($parent,
    # 	     "1. Double click in the Gnuplot window to pluck a point.\n2. Then click ok to accept the value.",
    # 	     "Pluck a point",
    # 	     wxOK|wxICON_EXCLAMATION|wxSTAY_ON_TOP)
    # 	-> ShowModal;

    # my $tdo;
    # if (wxTheClipboard->Open) {
    #   $tdo = Wx::TextDataObject->new;
    #   wxTheClipboard->GetData( $tdo );
    #   wxTheClipboard->Close;
    # };
    # $is = $tdo->GetText;
    # ($x, $y) = split(/,\s+/, $is);

    my $sleep = 200000;
    my $wait  = Demeter->co->default('gnuplot', 'pluck_timeout') * 1e6 / 200000;
    if (wxTheClipboard->Open) {
      $app->{main}->status("Double click on a point to pluck its value (there WILL be a short pause after clicking) ...", "wait");
      $busy = Wx::BusyCursor->new();
      my $tdo = Wx::TextDataObject->new;
      $tdo->SetText(q{});
      wxTheClipboard->GetData( $tdo );
      wxTheClipboard->Close;
      my $top_of_clipboard = $tdo->GetText;
      my $new = $top_of_clipboard;
      my $count = 0;
      while ($new eq $top_of_clipboard) {
	usleep($sleep);       # 1/5 second
	++$count;
	if ($count > 50) {    # 10 seconds have passed
	  $return->status(0);
	  $return->message("Pluck timed out!");
	  return ($return, -100000, -100000);
	};
	wxTheClipboard->Open;
	if (not wxTheClipboard->IsOpened) {
	  next;
	};
	next if not wxTheClipboard->IsSupported(wxDF_TEXT);
	wxTheClipboard->GetData( $tdo );
	wxTheClipboard->Close;
	$new = $tdo->GetText;
	$::app->{main}->Update;
      };
      ($x, $y) = split(/,\s+/, $new);
    };


  } else {
    $app->{main}->status("Unknown or unpluckable plotting backend.  Pluck canceled.");
    $return->status(0);
    return ($return, $x, -100000);
  };

  undef $busy;
  if ((Demeter->mo->template_plot eq 'gnuplot') and ($was eq $is)) {
    $return->status(0);
    $return->message("Plucking failed. Did you double click on the plot?");
    return ($return, -100000, -100000);
  };
  if ((not looks_like_number($x)) and (not looks_like_number($y))) {
    $return->status(0);
    $return->message("Plucking failed. Neither coordinate appears to be a number.");
    return ($return, -100000, -100000);
  };
  if (not looks_like_number($y)) {
    $return->status(0);
    $return->message("Plucking failed. The y coordinate appears not to be a number.");
    return ($return, $x, -100000);
  };
  if (not looks_like_number($x)) {
    $return->status(0);
    $return->message("Plucking failed. The x coordinate appears not to be a number.");
    return ($return, -100000, $y);
  };
  return ($return, $x, $y);
};

1;

=head1 NAME

Demeter::UI::Athena::Cursor - interact with a plotting cursor

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module provides a way of interacting with the plot cursor for
Demeter's plotting backends

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
