#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The GNU
 General Public License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use strict;
use warnings;
use Cwd;
use File::Spec;
use Module::Build;
use DemeterBuilder; # subclass of Module::Build defining some Demeter specific installation instructions

my $build = DemeterBuilder
  -> new(
	 module_name        => 'Demeter',
	 create_readme      => 0,
	 ##create_makefile_pl => 'traditional',
	 license            => 'gpl',
	 dist_author        => 'Bruce Ravel <bravel AT bnl DOT gov>',
	 auto_configure_requires => 1,
	 needs_compiler     => 1,
	 requires           => {
				'Moose'			    => '2.04',
				'MooseX::Aliases'           => '0.10',
				#'MooseX::StrictConstructor' => '0.19',
				'MooseX::Singleton'	    => '0.29',
				'MooseX::Types'		    => '0.31',
				'MooseX::Types::LaxNum'     => '0',

				'Archive::Zip'		    => '0',

				'Capture::Tiny'	            => '0.07',
				'Chemistry::Elements'	    => '0',
				'Config::INI'	            => '0',
				'DateTime'                  => '0',
				'Digest::SHA'		    => '0',
				'Encoding::FixLatin'        => '0',
				'File::Copy::Recursive'     => '0',
				'File::CountLines'          => '0',
				'File::Touch'	            => '0',
				'Graph'                     => '0',
				'Heap'			    => '0',
                                'HTML::Entities'            => '0', # what is this used for?
				'List::MoreUtils'	    => '0',
				'Math::Combinatorics'	    => '0',
				'Math::Derivative'	    => '0',
				'Math::Round'		    => '0',
				'Math::Spline'		    => '0',
				'Pod::POM'                  => '0',
				'Const::Fast'		    => '0.01',
				'Regexp::Common'	    => '0',
				'Regexp::Assemble'	    => '0',
                                'Spreadsheet::WriteExcel'   => '0',
                                'Statistics::Descriptive'   => '0',
				'String::Random'            => '0',
				'Text::Template'	    => '0',
				'Tree::Simple'		    => '0',
				'Want'			    => '0',
				'YAML::Tiny'		    => '0',

				'PDL'                       => '2.4.9',
				#'PDL::Slatec'               => '0',
				'PDL::Stats'                => '0.5.5',

				'XMLRPC::Lite'              => '0',

				(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ?
				('Win32::Shortcut' => '0',) : (),
				## deprecated....
				#'Compress::Raw::Zlib'	   => '0',
				#'Compress::Raw'	   => '0',
				#'Math::Cephes'		   => '0',
				#'MooseX::AttributeHelpers'  => '0.23', now using Moose::Meta::Attribute::Native like a good boy
			       },
	 build_requires     => {
				## these are used to build the documents
				'Template'                => '2.22',
				'PPI'                     => '0',
				'PPI::HTML'               => '0', # perl syntax highlighting for HTML
				'Syntax::Highlight::Perl' => '0', # perl syntax highlighting for latex
				'Image::Size'             => '0',
				'File::Copy::Recursive'   => '0',
				## project docs
				'Pod::ProjectDocs'        => '0',
				## these are used to build the Ifeffit wrapper
                                'ExtUtils::CBuilder'      => '0',
			       },
	 PL_files           => {
				'lib/Xray/Crystal/share/space_groups.db.PL' => 'lib/Xray/Crystal/share/space_groups.db',

                                ## from Xray::Absorption
				'lib/Xray/data/chantler2st.PL'  => 'lib/Xray/Absorption/chantler.db',
				'lib/Xray/data/dat2st.PL'       => 'lib/Xray/Absorption/mcmaster.db',
				'lib/Xray/data/henke2st.PL'     => 'lib/Xray/Absorption/henke.db',
				'lib/Xray/data/shalt2st.PL'     => 'lib/Xray/Absorption/shaltout.db',
				'lib/Xray/data/cl2st.PL'        => 'lib/Xray/Absorption/cl.db',
				'lib/Xray/data/elam2st.PL'      => 'lib/Xray/Absorption/elam.db',
				'lib/Xray/data/hubbell_g2st.PL' => 'lib/Xray/Absorption/hubbell_g.db',

                                ## from Xray::Scattering
				'lib/Xray/data/cromann.PL'  => 'lib/Xray/Scattering/cromann.db',
				'lib/Xray/data/waaskirf.PL' => 'lib/Xray/Scattering/waaskirf.db',
			       },
	 recommends         => {
				## these add functionality when using demeter at the command line
				(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? 
				('Win32::Console::ANSI' => '0',) :
				('Term::Twiddle'      => '0',
				 'Term::Sk'           => '0.07',
				),
				#'Getopt::Long'       => '2.38', #  this is core

				## this is required for the gnuplot plotting backend
				#(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? () :
				'Graphics::GnuplotIF' => '0',

				## GUI for Athena, Artemis, and Hephaestus
				'Wx'                  => '0.86',

				## required by the data watcher
				'File::Monitor::Lite' => '0',

				## these are used for direct access to the pgplot terminal
				#'ExtUtils::F77'       => '0',
				#'PGPLOT'              => '0',
			       },
	 sign               => 1,
	 add_to_cleanup     => [
				'src/*.o',
				'src/*.so',
				'src/*.dylib',
				'src/*.dll',
				'lib/Xray/Absorption/*.db',
				'lib/Xray/Scattering/*.db',
				'lib/Xray/Crystal/share/*.db',
				'lib/Demeter/doc/dpg/bin/build',
				'lib/Demeter/doc/dpg/etc/ttree.cfg',
				'lib/Demeter/doc/dpg/html',
				'lib/Demeter/doc/dpg/templates/lib/config/map',
				'lib/Demeter/doc/dpg/templates/lib/config/version',
				't/feff',
			       ],
	);

## include all required non-perl files in the installation
$build->add_build_element('db');
$build->add_build_element('cif');
$build->add_build_element('dem');
$build->add_build_element('demeter_conf');
$build->add_build_element('fit_serialization');
$build->add_build_element('htm');
$build->add_build_element('html');
$build->add_build_element('css');
$build->add_build_element('ini');
$build->add_build_element('png');
$build->add_build_element('ico');
$build->add_build_element('jpg');
$build->add_build_element('prj');
$build->add_build_element('stan');
$build->add_build_element('tmpl');
$build->add_build_element('xpm');
## make sure pgplot will work seamlessly on windows
$build->add_build_element('dat');
$build->add_build_element('txt');

$build->create_build_script;


=head1 NAME

Build.PL - Demeter build script

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This is Demeter's build script using L<Module::Build>

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel/

=cut
