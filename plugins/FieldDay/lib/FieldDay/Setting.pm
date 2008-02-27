
package FieldDay::Setting;
use FieldDay::Util qw( mtlog );
use Data::Dumper;

use strict;

use MT::Object;
@FieldDay::Setting::ISA = qw(MT::Object);
__PACKAGE__->install_properties({
	column_defs => {
		'id' => 'integer not null auto_increment',
		'blog_id' => 'integer default 0',
		'type' => 'string(15) not null',
		'name' => 'string(75) not null',
		'object_type' => 'string(15) not null',
		'order' => 'integer',
		'data' => 'blob'
	},
	indexes => {
		'blog_id' => 1,
		'type' => 1,
		'name' => 1,
		'object_type' => 1,
		'order' => 1
	},
	audit => 0,
	datasource => 'fdsetting',
	primary_key => 'id'
});

sub data {
	my $setting = shift;
	require MT::Serialize;
	my $ser = MT::Serialize->new('MT');
	if (my ($data) = @_) {
		$setting->column('data', $ser->serialize(\$data));
	} else {
		return ${$ser->unserialize($setting->column('data'))};
	}
}

sub load_with_default {
# load settings; if none found and a default blog is set, load those
	my $class = shift;
	my ($terms, $args) = @_;
		# not concerned with defaults unless there's a blog_id
	my $orig_blog_id = $terms->{'blog_id'};
	return $class->load($terms, $args) unless $orig_blog_id;
	my @settings;
	if (@settings = $class->load($terms, $args)) {
		return @settings;
	}
	my $orig_type = $terms->{'type'};
		# no settings, but it might be overridden
	$terms->{'type'} = 'override';
	my $setting;
	return () if ($class->load($terms));
		# not overridden, now check for default
	$terms->{'type'} = 'default';
	delete($terms->{'blog_id'});
	$setting = $class->load($terms);
	return () unless $setting;
	$terms->{'blog_id'} = $setting->blog_id;
	$terms->{'type'} = $orig_type;
	@settings = $class->load($terms, $args);
	return @settings;
}

1;
