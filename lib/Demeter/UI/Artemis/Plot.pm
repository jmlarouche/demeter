package  Demeter::UI::Artemis::Plot;

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
use Wx::DND;
use base qw(Wx::Frame);
use Wx::Event qw(EVT_CLOSE EVT_ICONIZE EVT_BUTTON EVT_RADIOBOX EVT_RIGHT_DOWN EVT_MENU EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_TOGGLEBUTTON EVT_LEFT_DOWN);

use Demeter::UI::Artemis::Close;
use Demeter::UI::Artemis::Plot::Limits;
use Demeter::UI::Artemis::Plot::Stack;
use Demeter::UI::Artemis::Plot::Indicators;
use Demeter::UI::Artemis::Plot::VPaths;
use Demeter::UI::Artemis::DND::PlotListDrag;

use Cwd;
use File::Spec;
use List::Util qw(first sum);
use Demeter::Constants qw($EPSILON2);

my $demeter = $Demeter::UI::Artemis::demeter;

sub new {
  my ($class, $parent) = @_;
  my ($w, $h) = $parent->GetSizeWH;
  my ($x, $y) = $parent->GetPositionXY;
  my $pos = $parent->GetScreenPosition;

  ## position of upper left corner
  my $windowsize = 2*wxSYS_FRAMESIZE_Y; #sum(wxSYS_BORDER_Y, wxSYS_BORDER_Y, wxSYS_BORDER_Y, wxSYS_FRAMESIZE_Y);
  #print join(" ", wxSYS_MENU_Y, wxSYS_BORDER_Y, wxSYS_FRAMESIZE_Y, $h, $y), $/;
  my $yy = sum(wxSYS_MENU_Y, wxSYS_BORDER_Y, wxSYS_FRAMESIZE_Y, $h, $y);
  #print $yy, $/;
  #my $yy = sum($pos->y, $h, $windowsize, $parent->GetStatusBar->GetSize->GetHeight);

  my $this = $class->SUPER::new($parent, -1, "Artemis [Plot]",
				[$x+$Demeter::UI::Artemis::demeter->co->default("artemis", "plot_frame_x"),$yy], wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX);
  #$this -> SetBackgroundColour( Wx::Colour->new(0,255,0,0));
  #$this -> SetBackgroundColour( Wx::SystemSettings::GetColour(wxSYS_COLOUR_WINDOW) );
  $this -> SetBackgroundColour( wxNullColour );
  EVT_CLOSE($this, \&on_close);
  EVT_ICONIZE($this, \&on_close);
  $this->{last} = q{};
  $this->{lastplot} = q{};

  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $left  = Wx::BoxSizer->new( wxVERTICAL );
  $vbox -> Add($left,  0, wxGROW|wxALL, 0);




  my $buttonbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left -> Add($buttonbox, 0, wxGROW|wxALL, 5);
  $this->{k_button}   = Wx::Button->new($this, -1, "&k", wxDefaultPosition, [50,-1]);
  $this->{r_button}   = Wx::Button->new($this, -1, "&R", wxDefaultPosition, [50,-1] );
  $this->{'q_button'} = Wx::Button->new($this, -1, "&q", wxDefaultPosition, [50,-1] );
  foreach my $b ('k_button', 'r_button', 'q_button') {
    $buttonbox -> Add($this->{$b}, 1, wxALL, 2);
    $this->{$b} -> SetForegroundColour(Wx::Colour->new("#000000"));
    $this->{$b} -> SetBackgroundColour(Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default("happiness", "average_color")));
    $this->{$b} -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };
  EVT_BUTTON($this, $this->{k_button},   sub{plot(@_, 'k')});
  EVT_BUTTON($this, $this->{r_button},   sub{plot(@_, 'r')});
  EVT_BUTTON($this, $this->{'q_button'}, sub{plot(@_, 'q')});

  $this->mouseover("k_button", "Plot the contents of the plotting list in k-space.");
  $this->mouseover("r_button", "Plot the contents of the plotting list in R-space.");
  $this->mouseover("q_button", "Plot the contents of the plotting list in back-transform k-space.");

  $this->{kweight} = Wx::RadioBox->new($this, -1, "k-weight", wxDefaultPosition, wxDefaultSize,
				       [0, 1, 2, 3, 'kw'],
				       1, wxRA_SPECIFY_ROWS);
  $left -> Add($this->{kweight}, 0, wxLEFT|wxRIGHT|wxGROW, 5);
  $this->{kweight}->SetSelection($demeter->co->default('plot', 'kweight'));
  $this->mouseover("kweight", "Select a value of k-weight to use when plotting data.");
  #$this->{kweight}->Enable(4, 0);
  $demeter->po->kweight($demeter->co->default('plot', 'kweight'));
  EVT_RADIOBOX($this, $this->{kweight},
	       sub{
		 my ($self, $event) = @_;
		 $this->set_kweight('plot');
		 $self->plot($event, $self->{last});
	       });


  my $nb = Wx::Notebook->new( $this, -1, wxDefaultPosition, wxDefaultSize, wxBK_TOP );
  foreach my $utility (qw(limits stack indicators VPaths)) {
    my $count = $nb->GetPageCount;
    $this->{$utility} = ($utility eq 'limits')     ? Demeter::UI::Artemis::Plot::Limits     -> new($nb)
                      : ($utility eq 'stack')      ? Demeter::UI::Artemis::Plot::Stack      -> new($nb)
                      : ($utility eq 'indicators') ? Demeter::UI::Artemis::Plot::Indicators -> new($nb)
                      : ($utility eq 'VPaths')     ? Demeter::UI::Artemis::Plot::VPaths     -> new($nb)
	              :                              q{};
    next if not $this->{$utility};
    $nb->AddPage($this->{$utility}, ($utility eq 'indicators') ? 'indic' : $utility, 0);#, $count);
  };
  $left -> Add($nb, 1, wxGROW|wxALL, 5);
  $this->{notebook} = $nb;


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);

  my $groupbox       = Wx::StaticBox->new($this, -1, 'Plotting list', wxDefaultPosition, wxDefaultSize);
  my $groupboxsizer  = Wx::StaticBoxSizer->new( $groupbox, wxVERTICAL );

  $this->{plotlist} = Wx::CheckListBox->new($this, -1, wxDefaultPosition, [-1,200], [ ], wxLB_MULTIPLE);
  $this->{plotlist}->{datalist} = [];
  #foreach my $i (0 .. $this->{plotlist}->GetCount) {
  #  $this->{plotlist} -> Check($i, 1) if ($i%3);
  #};

  $groupboxsizer -> Add($this->{plotlist},     1, wxGROW|wxALL, 0);
  $hbox          -> Add($groupboxsizer, 1, wxGROW|wxALL, 0);
  EVT_RIGHT_DOWN($this->{plotlist}, sub{OnRightDown(@_)});
  EVT_MENU($this->{plotlist}, -1, sub{ $this->OnPlotMenu(@_)    });
  EVT_LEFT_DOWN($this->{plotlist}, \&OnDrag);
  $this->{plotlist}->SetDropTarget( Demeter::UI::Artemis::Plot::DropTarget->new( $this, $this->{pathlist} ) );


  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $groupboxsizer -> Add($hbox, 0, wxGROW|wxALL, 0);
  $this->{freeze} = Wx::CheckBox->new($this, -1, "&Freeze");
  $hbox -> Add($this->{freeze}, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);
  $this->{clear} = Wx::Button->new($this, wxID_CLEAR, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{clear}, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);
  EVT_BUTTON($this, $this->{clear}, sub{$_[0]->{plotlist}->ClearAll; $_[0]->{freeze}->SetValue(0);});

  $this->mouseover("freeze", "When this button is checked, the plotting list will NOT be refreshed after a fit finishes.");
  $this->mouseover("clear",  "Clear all items from the plotting list.");

  $this->{fileout} = Wx::ToggleButton->new($this, -1, "Save next plot to a file.");
  $vbox -> Add($this->{fileout}, 0, wxLEFT|wxRIGHT|wxBOTTOM|wxGROW, 5);
  $this->mouseover("fileout",  "When this button is pressed, the next plot will be exported as a column data file in which each column is a trace properly stacked and scaled.");
  EVT_TOGGLEBUTTON($this, $this->{fileout}, sub{OnFileoutToggle(@_)});

  $this -> SetSizerAndFit( $vbox );
  #my $hh = Wx::SystemSettings::GetMetric(wxSYS_SCREEN_Y) - $yy - 2*$windowsize - $y;
  #print join(" ", $hh, Wx::SystemSettings::GetMetric(wxSYS_SCREEN_Y), $yy, $windowsize, $y), $/;
  #$this -> SetSize(Wx::Size->new(-1, $hh));
  return $this;
};


sub OnDrag {
  my ($list, $event) = @_;
  my $which = $list->HitTest($event->GetPosition);
  my $source = Wx::DropSource->new( $list );
  my $dragdata = Demeter::UI::Artemis::DND::PlotListDrag->new(\$which);
  $source->SetData( $dragdata );
  $source->DoDragDrop(1);
  $event->Skip(1);
};


sub OnFileoutToggle {
  my ($self, $event) = @_;

  if ($self->{fileout}->GetValue) {
    $Demeter::UI::Artemis::frames{main}->status("The next plot will be written to a column data file.");
  } else {
    $Demeter::UI::Artemis::frames{main}->status("The next plot will be plotted normally.");
  };
};

sub mouseover {
  my ($self, $widget, $text) = @_;
  my $sb = $Demeter::UI::Artemis::frames{main}->{statusbar};
  EVT_ENTER_WINDOW($self->{$widget}, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($self->{$widget}, sub{$sb->PopStatusText if ($sb->GetStatusText eq $text); $_[1]->Skip});
};


sub set_kweight {
  my ($self) = @_;
  my $kw = $self->{kweight}->GetStringSelection;
  if ($kw eq 'kw') {

    my @kweights = ();
    foreach my $i (0 .. $self->{plotlist}->GetCount-1) {
      next if (not $self->{plotlist}->IsChecked($i));
      my $obj = $self->{plotlist}->GetIndexedData($i);
      push @kweights, $obj->data->fit_karb_value;
    };
    ## check to see if plotted items all have the same arbitrary k-weight
    my $nuniq = grep {abs($_-$kweights[0]) > $EPSILON2} @kweights;
    $demeter->po->kweight($kweights[0]);
    $demeter->po->kweight(-1) if $nuniq; # variable k-weighting if not all the same
  } else {
    $demeter->po->kweight($kw);
  };
};

sub fetch_parameters {
  my ($self, $how) = @_;

  $self->set_kweight($how);
  foreach my $p (qw(kmin kmax rmin rmax qmin qmax)) {
    $demeter->po->$p($self->{limits}->{$p}->GetValue || 0);
  };

  #   $demeter->po->plot_fit($self->{limits}->{fit}       ->GetValue);
  #   $demeter->po->plot_bkg($self->{limits}->{background}->GetValue);
  #   $demeter->po->plot_win($self->{limits}->{window}    ->GetValue);
  #   $demeter->po->plot_res($self->{limits}->{residual}  ->GetValue);
  #   $demeter->po->plot_run($self->{limits}->{running}   ->GetValue);

  $demeter->po->stackdo   ($self->{stack}->{dostack}  ->GetValue);
  $demeter->po->stackstart($self->{stack}->{start}    ->GetValue || 0);
  $demeter->po->stackinc  ($self->{stack}->{increment}->GetValue || 0);
  $demeter->po->stackdata ($self->{stack}->{offset}   ->GetValue || 0);
  my $val = ($self->{stack}->{invert}->GetStringSelection eq 'Never')  ? 0
          : ($self->{stack}->{invert}->GetStringSelection =~ m{Only})  ? 2
          :                                                              1;
  $demeter->po->invert_paths($val);
};

sub populate {
  my ($self) = @_;
  foreach my $p (qw(kmin kmax rmin rmax qmin qmax)) {
    $self->{limits}->{$p}->SetValue($demeter->po->$p);
  };
  $self->{kweight}->SetSelection($demeter->po->kweight);
  my $val = ($demeter->po->r_pl eq 'm') ? 0
          : ($demeter->po->r_pl eq 'r') ? 1
	  :                               2;
  $self->{limits}->{rpart}      -> SetSelection($val);
  $val    = ($demeter->po->q_pl eq 'm') ? 0
          : ($demeter->po->q_pl eq 'r') ? 1
	  :                               2;
  $self->{limits}->{qpart}      -> SetSelection($val);
  $self->{limits}->{fit}        -> SetValue($demeter->po->plot_fit);
  $self->{limits}->{background} -> SetValue($demeter->po->plot_bkg);
  $self->{limits}->{window}     -> SetValue($demeter->po->plot_win);
  $self->{limits}->{residual}   -> SetValue($demeter->po->plot_res);
  $self->{limits}->{running}    -> SetValue($demeter->po->plot_run);

  $self->{stack} ->{dostack}    -> SetValue($demeter->po->stackdo);
  $self->{stack} ->{start}      -> SetValue($demeter->po->stackstart);
  $self->{stack} ->{increment}  -> SetValue($demeter->po->stackinc);
  $self->{stack} ->{offset}     -> SetValue($demeter->po->stackdata);
  $self->{stack} ->{invert}     -> SetSelection($demeter->po->invert_paths);
};

sub plot {
  my ($self, $event, $space) = @_;
  return if ($space !~ m{[krq]}i);
  my $busy = Wx::BusyCursor->new();
  my $saveplot = $demeter->co->default(qw(plot plotwith));
  if ($self->{fileout}->GetValue) {
    ## writing plot to a single file has been selected...
    my $fd = Wx::FileDialog->new( $self, "Save plot to a file", cwd, "plot.dat",
				  "Data (*.dat)|*.dat|All files (*)|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $::app->{main}->status("Saving plot to a file has been canceled.");
      $self->{fileout}->SetValue(0);
      return;
    };
    ## set up for SingleFile backend
    my $file = $fd->GetPath;
    $self->{fileout}->SetValue(0), return
      if $self->overwrite_prompt($file, $::app->{main}); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
    $demeter->plot_with('singlefile');
    $demeter->po->file($file);
  };
  my ($abort, $rdata, $rpaths) = Demeter::UI::Artemis::uptodate(\%Demeter::UI::Artemis::frames);
  $Demeter::UI::Artemis::frames{GDS}->reset_all if (not $Demeter::UI::Artemis::frames{GDS}->{uptodate});
  $self->fetch_parameters('plot');
  my @list = ();
  foreach my $i (0 .. $self->{plotlist}->GetCount-1) {
    next if (not $self->{plotlist}->IsChecked($i));
    push @list, $self->{plotlist}->GetIndexedData($i);
  };
  if ($#list == -1) {
    $Demeter::UI::Artemis::frames{main}->status("The plotting list is empty.");
    undef $busy;
    return;
  };

  $list[0]->data->standard if $self->{fileout}->GetValue;
  $demeter->po->space($space);
  $demeter->po->start_plot;

  my $invert_r = (    (lc($space) eq 'r')
		  and ($self->{stack}->{invert}->GetStringSelection !~ m{Never})
		  and ($self->{limits}->{rpart}->GetStringSelection eq 'Magnitude') );
  my $invert_q = (    (lc($space) eq 'q')
		  and ($self->{stack}->{invert}->GetStringSelection !~ m{(?:Never|Only)})
		  and ($self->{limits}->{qpart}->GetStringSelection eq 'Magnitude') );

  my $mds_offset = $self->{stack}->{offset}->GetValue;
  my $offset = 0;
  foreach my $i (0 .. $self->{plotlist}->GetCount-1) {
    next if (not $self->{plotlist}->IsChecked($i));
    my $obj = $self->{plotlist}->GetIndexedData($i);
    ##print $obj, "  ", $obj->name, "  ", $obj->group, $/;
    if (ref($obj) !~ m{Data}) {
      $obj->update_path(1);
      next;
    };
    $obj->y_offset($offset);
    $offset -= $mds_offset;
  };

  ## stack overrides invert
  if ($self->{stack}->{dostack}->GetValue) {
    my $jump = $self->{stack}->{start}->GetValue;
    foreach my $i (0 .. $self->{plotlist}->GetCount-1) {
      next if (not $self->{plotlist}->IsChecked($i));
      my $obj = $self->{plotlist}->GetIndexedData($i);
      my $save = $obj->data->y_offset;
      $obj -> data -> y_offset($jump);
      if ($self->{plotlist}->GetIndexedData($i) =~ m{\AFit}) {
	$self->plot_fit($space, $i);
      } else {
	$obj->plot($space);
      }
      $obj -> data -> y_offset($save);
      $jump -= $self->{stack}->{increment}->GetValue;
    };
  } elsif ($invert_r or $invert_q) {
    foreach my $i (0 .. $self->{plotlist}->GetCount-1) {
      next if (not $self->{plotlist}->IsChecked($i));
      my $obj = $self->{plotlist}->GetIndexedData($i);
      if ($self->{plotlist}->GetIndexedData($i) =~ m{\AFit}) {
	$self->plot_fit($space, $i);
      } elsif (ref($obj) =~ m{Data}) {  # Data and fits plotted normally
	$obj->plot($space);
      } elsif (ref($obj) =~ m{VPath}) { # VPath plotted normally
	$obj->plot($space);
      } else {			        # invert Path
	my $save = $obj->data->plot_multiplier;
	$obj->data->plot_multiplier(-1*$save);
	$obj->plot($space);
	$obj->data->plot_multiplier($save);
      };
    };
  } else {			# plot normally
    foreach my $i (0 .. $self->{plotlist}->GetCount-1) {
      next if (not $self->{plotlist}->IsChecked($i));
      my $obj = $self->{plotlist}->GetIndexedData($i);
      if ($self->{plotlist}->GetIndexedData($i) =~ m{\AFit}) {
	$self->plot_fit($space, $i);
      } else {
	$obj->plot($space);
      };
    };
  };

  my $ds = first {ref($_) =~ m{Data}} @list;
  $self->{indicators}->plot($ds) if ($space ne 'rk');


  $Demeter::UI::Artemis::frames{main}->status("Plotted in $space");
  ## restore plotting backend if this was a plot to a file
  if ($self->{fileout}->GetValue) {
    $demeter->po->finish;
    $Demeter::UI::Artemis::frames{main}->status("Saved plot to file \"" . $demeter->po->file . "\".");
    $demeter->plot_with($saveplot);
    $self->{fileout}->SetValue(0);
  };
  $self->{last} = $space;
  $self->{lastplot} = $space;
  $::app->heap_check;
  undef $busy;
};

sub plot_fit {
  my ($self, $space, $count) = @_;
  print $self, $/;
  return;
  my $tempname = $self->{plotlist}->GetString($count);
  $tempname = (split(/ from /, $tempname))[1];
  my $data = $self->{plotlist}->GetIndexedData($count);
  $data->plotkey($tempname);
  $data->co->set(plot_part=>'fit');
  $data->part_plot('fit', $space);
  $data->co->set(plot_part=>q{});
  $data->plotkey(q{});
  $data->po->increment;
  $::app->heap_check;
};


sub image {
  my ($self, $format) = @_;

  my $on_screen = lc($self->{last});
  if ($on_screen eq 'rk') {
    $::app->{main}->status("Cannot save an Rk plot to an image file.", 'alert');
    return;
  };

  my $busy = Wx::BusyCursor->new();
  my $name =   $::app->{main}->{projectname};
  $name =~ s{\s+}{_}g;

  my $suffix = $format;
  $format = 'pngcairo' if $format eq 'png';
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save image file", cwd, join('.', $name, $suffix),
				"$suffix (*.$suffix)|*.$suffix|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, # wxFD_OVERWRITE_PROMPT|
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving image canceled.");
    return;
  };
  my $file = $fd->GetPath;
  return if $::app->{main}->overwrite_prompt($file); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  Demeter->po->image($file, $format);

  if ($self->{lastplot} =~ m{\A[krq]\z}i) {
    $self->plot(q{}, $self->{last});
  } else {
    my ($how, $which) = split(/\|/,$self->{lastplot});
    $::app->{$which}->plot(q{}, $how);
  };

  $::app->{main}->status("Saved $suffix image to \"$file\".");
  undef $busy;
};


use Const::Fast;
const my $PLOT_REMOVE => Wx::NewId();
const my $PLOT_ON     => Wx::NewId();
const my $PLOT_OFF    => Wx::NewId();
const my $PLOT_TOGGLE => Wx::NewId();

sub OnRightDown {
  my ($self, $event) = @_;
  my @sel  = $self->GetSelections;
  if ($#sel == -1) {
    $self->SetSelection($self->HitTest($event->GetPosition));
    @sel  = $self->GetSelections;
  };
  my $name = ($#sel == 0) ? sprintf("\"%s\"", $self->GetString($sel[0])) : 'selected items';
  my $menu = Wx::Menu->new(q{});
  $menu->Append($PLOT_REMOVE, "Remove $name from plotting list");
  if ($#sel) {
    $menu->AppendSeparator;
    $menu->Append($PLOT_ON,     "Mark $name for plotting");
    $menu->Append($PLOT_OFF,    "Unmark $name for plotting");
    $menu->Append($PLOT_TOGGLE, "Toggle $name for plotting");
  };
  $self->PopupMenu($menu, $event->GetPosition);
};

sub OnPlotMenu {
  my ($self, $list, $event) = @_;
  if ($event->GetId == $PLOT_REMOVE) {
    my @sel = $list->GetSelections;
    while (@sel) {
      $list->DeleteData($sel[-1]);
      @sel = $list->GetSelections;
    };
  } elsif ($event->GetId == $PLOT_ON) {
    foreach my $i ($list->GetSelections) {
      $list->Check($i, 1);
    };
  } elsif ($event->GetId == $PLOT_OFF) {
    foreach my $i ($list->GetSelections) {
      $list->Check($i, 0);
    };
  } elsif ($event->GetId == $PLOT_TOGGLE) {
    foreach my $i ($list->GetSelections) {
      $list->Check($i, not $list->IsChecked($i));
    };
  };
};


package Demeter::UI::Artemis::Plot::DropTarget;

use Wx qw( :everything);
use base qw(Wx::DropTarget);
use Demeter::UI::Artemis::DND::PathDrag;

use Scalar::Util qw(looks_like_number);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new;

  my $data = Demeter::UI::Artemis::DND::PlotListDrag->new();
  $this->SetDataObject( $data );
  $this->{DATA} = $data;
  return $this;
};

sub OnData {
  my ($this, $x, $y, $def) = @_;

  my $list = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  return 0 if not $list->GetCount;
  $this->GetData;		# this line is what transfers the data from the Source to the Target

  my $from = ${ $this->{DATA}->{Data} };
  my $from_object  = $list->GetIndexedData($from);
  my $from_label   = $list->GetString($from);
  my $from_checked = $list->IsChecked($from);
  my $point = Wx::Point->new($x, $y);
  my $to = $list->HitTest($point);

  return 0 if ($to == $from);	# either of these two would leave the list in the same state
  return 0 if ($to == $from+1);

  my $message;
  $list -> DeleteData($from);
  if ($to == -1) {
    $list -> AddData($from_label, $from_object);
    $list -> Check($list->GetCount-1, $from_checked);
    $message = sprintf("Moved '%s' to the last position.", $from_label);
  } else {
    $message = sprintf("Moved '%s' from position %d to position %d.", $from_label, $from+1, $to+1);
    --$to if ($from < $to);
    $list -> InsertData($from_label, $to, $from_object);
    #$list -> SetClientData($to, $from_object);
    $list -> Check($to, $from_checked);
  };
  $Demeter::UI::Artemis::frames{main}->status($message);

  return $def;
};

1;



=head1 NAME

Demeter::UI::Artemis::Plot - Plot interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module provides a window for interacting with Demeter's plotting
capabilities.

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
