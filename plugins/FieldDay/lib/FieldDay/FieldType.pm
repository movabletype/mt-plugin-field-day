
package FieldDay::FieldType;
use strict;
use FieldDay::YAML qw( types );
use FieldDay::Util qw( require_type mtlog );
use Data::Dumper;

sub label {
	return 'Unknown';
}

sub options {
	return {};
}

sub html_head {
# code to go into html_head of template
	return '';
}

sub pre_edit_options {
# before FieldDay displays the config screen
}

sub pre_save_options {
# before FieldDay saves a field's settings
}

sub pre_edit_default {
# before FieldDay displays the Default Values config screen
}

sub pre_save_default {
# before FieldDay saves the default value
}

sub pre_render {
# before the field is rendered in the CMS
	my $class = shift;
	my ($param) = @_;
}

sub pre_publish {
# before the field value is output on a template
	my $class = shift;
	my ($value) = @_;
	return $value;
}

sub pre_save_value {
# before the CMS saves a value from the editing screen
	my $class = shift;
	my ($app, $field_name) = @_;
	return $app->param($field_name);
}

sub pre_display_value {
# before a template tag displays the field value
}

sub options_tmpl_type {
# the field type that contains the options template, used for subclasses
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
}

sub type_tmpls {
	my ($plugin, $app, $tmpl_type) = @_;
	my $field_types = types('field');
	my %options = ();
	my $ft_path = $app->{'cfg'}->pluginpath . '/FieldDay/field_types';
	for my $key (keys %$field_types) {
		require_type($app, 'field', $key);
		my $yaml = $field_types->{$key}->[0];
		next if ($yaml->{'abstract'});
		my $meth = $tmpl_type . '_tmpl_type';
		my $tmpl_dir = $yaml->{'class'}->$meth || $key;
		my $tmpl_path = "$ft_path/$tmpl_dir/tmpl";
		my $tmpl = $plugin->load_tmpl("$tmpl_path/$tmpl_type.tmpl");
		$options{$yaml->{'field_type'}} = $tmpl->text;
	}
	return \%options;
}

sub tags {
# any type-specific publishing tags
}


1;
