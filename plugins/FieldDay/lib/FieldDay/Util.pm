
package FieldDay::Util;
use strict;
use Data::Dumper;

use Exporter;
@FieldDay::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( app_setting_terms app_value_terms 
				 require_type mtlog load_fields );

use FieldDay::YAML qw( object_type field_type );

sub app_setting_terms {
	my ($app, $setting_type, $name) = @_;
	my $use_type = $app->param('setting_object_mt_type')
		|| $app->param('setting_object_type')
		|| $app->param('_type');
	$use_type ||= 'system';
	return {
		'type' => $setting_type,
		($app->param('blog_id') && ($app->param('_type') ne 'blog')) ? ('blog_id' => $app->param('blog_id')) : (),
		'object_type' => $use_type,
		$name ? ('name' => $name) : ()
	};
}

sub app_value_terms {
	my ($app, $key) = @_;
	return {
		($app->param('blog_id') && ($app->param('_type') ne 'blog')) ? ('blog_id' => $app->param('blog_id')) : (),
		 'object_type' => $app->param('_type') || 'system',
		$app->param('id') ? ('object_id' => $app->param('id')) : (),
		'key' => $key,
	};
}

sub require_type {
	my ($app, $which, $key) = @_;
	my $meth = $which . '_type';
	my $yaml = FieldDay::YAML->$meth($key);
	eval("require $yaml->{'class'};");
	die $@ if $@;
	return $yaml->{'class'};
}

sub mtlog {
	my ($val) = @_;
	if (ref $val) {
		$val = Dumper($val);
	}
	MT->instance->log($val);
}

sub load_fields {
	my ($plugin, $ctx, $args, $cond) = @_;
	require FieldDay::Setting;
	require FieldDay::Value;
	my $sort = { 'sort' => 'order' };
	my $terms;
	$terms = $ctx->stash('fd:setting_terms')
		? { %{$ctx->stash('fd:setting_terms')}, 'type' => 'field' }
		: app_setting_terms(MT->instance, 'field'); 
	my @fields = FieldDay::Setting->load_with_default($terms, $sort);
	my $values = {};
		# don't try to load values for a new object (no ID)
	if ($ctx->stash('fd:value_terms') || MT->instance->param('id')) {
		for my $field (@fields) {
			$terms = $ctx->stash('fd:value_terms')
				? { %{$ctx->stash('fd:value_terms')}, 'key' => $field->name }
				: app_value_terms(MT->instance, $field->name); 
			for my $value (FieldDay::Value->load($terms)) {
				$values->{$field->name} ||= [];
				my $i = ($value->instance && ($value->instance > 0)) ? ($value->instance - 1) : 0;
				$values->{$field->name}->[$i] = $value;
			}
		}
	}
	my $grouped_fields = {};
	my $group_need_ns = {};
	my %groups_in_use = ();
	for my $field (@fields) {
		my $data = $field->data;
		my $group_id = $data->{'group'} || 0;
		$groups_in_use{$group_id}++ if $group_id;
		$grouped_fields->{$group_id} ||= [];
		push(@{$grouped_fields->{$group_id}}, $field);
			# this group needs as many instances as the field with the
			# most value instances
		next unless ($values->{$field->name});
		if (scalar(@{$values->{$field->name}}) > ($group_need_ns->{$group_id} || 0)) {
			$group_need_ns->{$group_id} = scalar(@{$values->{$field->name}});
		}
	}
	$terms = $ctx->stash('fd:setting_terms')
		? { %{$ctx->stash('fd:setting_terms')}, 'type' => 'group' }
		: app_setting_terms(MT->instance, 'group'); 
	my $groups = [];
	@$groups = FieldDay::Setting->load_with_default($terms, $sort);
	@$groups = map { $groups_in_use{$_->id} ? $_ : () } @$groups;
	my $max_order = 0;
	my $group_orders = { map {
		$max_order = $_->order if ($_->order > $max_order); 
		$_->id => $_->order
	} @$groups };
		# put ungrouped fields at the end
	$group_orders->{0} = $max_order + 1;
	my $groups_by_id = { map {
		$_->id => $_
	} @$groups };
	my $fields_by_name = { map {
		$_->name => $_
	} @fields };
	return ($fields_by_name, $grouped_fields, $group_need_ns, $values, $group_orders, $groups_by_id);
}

1;
