
package FieldDay::YAML;
use strict;
use Data::Dumper;

use Exporter;
@FieldDay::YAML::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( types object_type field_type load_yamls );

our %yamls = ();

sub types {
	my ($type) = @_;
	return $yamls{$type . '_types'};
}

sub object_type {
	my $class = shift;
	my ($type) = @_;
	return $yamls{'object_types'}->{$type}->[0];
}

sub object_type_by_plural {
	my $class = shift;
	my ($plural) = @_;
	for my $type (keys %{$yamls{'object_types'}}) {
		if (lc($yamls{'object_types'}->{$type}->[0]->{'plural'}) eq lc($plural)) {
			return $yamls{'object_types'}->{$type}->[0];
		}
	}
}

sub object_type_by_class {
	my $class = shift;
	my ($object_class) = @_;
	for my $type (keys %{$yamls{'object_types'}}) {
		if (lc($yamls{'object_types'}->{$type}->[0]->{'object_class'}) eq lc($object_class)) {
			return $yamls{'object_types'}->{$type}->[0];
		}
	}
}

sub field_type {
	my $class = shift;
	my ($type) = @_;
	return $yamls{'field_types'}->{$type}->[0];
}

sub load_yamls {
	my $path = MT->instance->{'cfg'}->pluginpath . '/FieldDay';
	%yamls = ();
	for my $type (qw( object_types field_types )) {
		$yamls{$type} = _load_yamls("$path/$type");
	}
}

sub _load_yamls {
	my ($path) = @_;
	my $yamls = {};
	local *DH;
	if (opendir DH, $path) {
		require File::Spec;
		require YAML::Tiny;
		my @dir = readdir DH;
		for my $dir (@dir) {
			next if ($dir =~ /^\.\.?$/ || $dir =~ /~$/);
			my $dir_path = File::Spec->catdir($path, $dir);
			next if (-f $dir_path); # we only want directories
			my $yaml = File::Spec->catfile($dir_path, 'config.yaml');
			next unless (-f $yaml);
 			my $y = eval { YAML::Tiny->read($yaml) }
				|| die "Error reading $path: " . $YAML::Tiny::errstr;
			$yamls->{$y->[0]->{'object_type'} || $y->[0]->{'field_type'}} = $y;
				# add the object's lib directory to @INC
			my %inc = map { $_ => 1 } @INC;
			my $lib = File::Spec->catdir($dir_path, 'lib');
			push(@INC, $lib) unless $inc{$lib};
		}
	}
	return $yamls;
}

1;
