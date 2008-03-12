
package FieldDay::Template::PubTags;
use strict;
use Data::Dumper;
use FieldDay::YAML qw( field_type object_type );
use FieldDay::Util qw( load_fields require_type mtlog );

sub obj_stash_key {
	my ($ctx, $args) = @_;
	my $class = require_type(MT->instance, 'object', $args->{'object_type'});
	my $id = $class->stashed_id($ctx, $args);
	return ("fd:$args->{'object_type'}:$id", $id);
}

sub get_fd_data {
	my ($plugin, $ctx, $args, $cond) = @_;
	my ($key, $object_id) = obj_stash_key($ctx, $args);
	return $ctx->stash($key) if $ctx->stash($key);
	my $ot = FieldDay::YAML->object_type($args->{'object_type'});
	my %blog_id = $ot->{'has_blog_id'} ? ('blog_id' => $ctx->stash('blog_id')) : ();
	my %setting_terms = (
		%blog_id,
		'object_type' => $args->{'object_type'},
	);
	my %value_terms = ( %setting_terms, 'object_id' => $object_id );
	$ctx->stash('fd:setting_terms', \%setting_terms);
	$ctx->stash('fd:value_terms', \%value_terms);
	my ($fields_by_name, $grouped_fields, $group_need_ns, $values, $group_orders, $groups_by_id)
		= load_fields($plugin, $ctx, $args, $cond);
	my $fd_data = {
		'fields_by_name' => $fields_by_name,
		'grouped_fields' => $grouped_fields,
		'group_need_ns' => $group_need_ns,
		'values' => $values,
		'group_orders' => $group_orders,
		'groups_by_id' => $groups_by_id,
	};
	$ctx->stash($key, $fd_data);
	return $fd_data;
}

sub hdlr_FieldGroup {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args, $cond);
	my %instances = $args->{'instances'} ? (map { $_ => 1 } split(/,/, $args->{'instances'})) : ();
	my $stash_key = obj_stash_key($ctx, $args);
	my $group_id = $ctx->stash($stash_key . ':group_id');
	my $group = $args->{'group'};
	return '' unless ($group_id || $group);
	if ($group) {
		my %groups_by_name = map { $_->name => $_ } values %{$fd_data->{'groups_by_id'}};
		$group_id = $groups_by_name{$group}->id;
		local $ctx->{'__stash'}{"$stash_key:group_id"} = $group_id;
	}
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out;
	for (my $i = 0; $i < $fd_data->{'group_need_ns'}->{$group_id}; $i++) {
		next if (%instances && !$instances{$i+1});
		local $ctx->{'__stash'}{"$stash_key:instance"} = $i;
		my $text = $builder->build( $ctx, $tokens )
			or return $ctx->error( $builder->errstr );
		$out .= $text;
	}
	return $out;
}

sub hdlr_Field {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args, $cond);
	my %instances = $args->{'instances'} ? (map { $_ => 1 } split(/,/, $args->{'instances'})) : ();
	my $stash_key = obj_stash_key($ctx, $args);
	my $field = $ctx->stash($stash_key . ':field') || $args->{'field'};
	return '' unless ($field);
	local $ctx->{'__stash'}{"$stash_key:field"} = $field;
	my $group_id = $fd_data->{'fields_by_name'}->{$field}->data->{'group'} || 0;
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out;
	for (my $i = 0; $i < $fd_data->{'group_need_ns'}->{$group_id}; $i++) {
		next if (%instances && !$instances{$i+1});
		local $ctx->{'__stash'}{"$stash_key:instance"} = $i;
		my $text = $builder->build( $ctx, $tokens )
			or return $ctx->error( $builder->errstr );
		$out .= $text;
	}
	return $out;
}

sub get_group_id {
	my ($fd_data, $ctx, $args) = @_;
	my $stash_key = obj_stash_key($ctx, $args);
	my $group_id = $ctx->stash($stash_key . ':group_id');
	my $group = $args->{'group'};
	return 0 unless ($group_id || $group);
	if ($group) {
		my %groups_by_name = map { $_->name => $_ } values %{$fd_data->{'groups_by_id'}};
		$group_id = $groups_by_name{$group}->id;
	}
	return $group_id;
}

sub hdlr_IfFieldGroup {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args, $cond);
	my %instances = $args->{'instances'} ? (map { $_ => 1 } split(/,/, $args->{'instances'})) : ();
	my $group_id = get_group_id($fd_data, $ctx, $args);
		# return true if any instance of any field in this group has a value
	for (my $i = 0; $i < $fd_data->{'group_need_ns'}->{$group_id}; $i++) {
		next if (%instances && !$instances{$i+1});
		for my $field (@{$fd_data->{'grouped_fields'}->{$group_id}}) {
			my $values = $fd_data->{'values'}->{$field->name};
			next unless ($values && @$values);
			return 1 if $values->[$i]->value;
		}
	}
	return 0;
}

sub hdlr_IfField {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args, $cond);
	my $stash_key = obj_stash_key($ctx, $args);
	my %instances;
		# if there's a stashed instance, we only want to check that one
	if ($ctx->stash("$stash_key:instance")) {
		$instances{$ctx->stash("$stash_key:instance")} = 1;
	} else {
		%instances = $args->{'instances'} ? (map { $_ => 1 } split(/,/, $args->{'instances'})) : ();
	}
	my $field = $ctx->stash($stash_key . ':field') || $args->{'field'};
	return 0 unless ($field);
	my $group_id = $fd_data->{'fields_by_name'}->{$field}->data->{'group'} || 0;
		# return true if any instance of this field has a value
	for (my $i = 0; $i < $fd_data->{'group_need_ns'}->{$group_id}; $i++) {
		next if (%instances && !$instances{$i+1});
		my $values = $fd_data->{'values'}->{$field};
		next unless ($values && @$values);
		return 1 if $values->[$i]->value;
	}
	return 0;
}

sub hdlr_FieldValue {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args, $cond);
	my $stash_key = obj_stash_key($ctx, $args);
	my $field = $args->{'field'} || $ctx->stash("$stash_key:field");
	return '' unless $field;
	my $instance = 0;
	if ($args->{'instance'}) {
		$instance = $args->{'instance'} - 1;
	} elsif ($ctx->stash("$stash_key:instance")) {
		$instance = $ctx->stash("$stash_key:instance");
	}
	my $values = $fd_data->{'values'}->{$field};
	return '' unless ($values && @$values);
	my $field_class = require_type(MT->instance, 'field', $fd_data->{'fields_by_name'}->{$field}->data->{'type'});
	return $field_class->pre_publish($ctx, $args, $values->[$instance]->value, $fd_data->{'fields_by_name'}->{$field});
}

sub hdlr_FieldLabel {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args, $cond);
	my $stash_key = obj_stash_key($ctx, $args);
	my $field = $args->{'field'} || $ctx->stash("$stash_key:field");
	return '' unless $field;
	my $field_obj = $fd_data->{'fields_by_name'}->{$field};
	return '' unless $field_obj;
	return $field_obj->data->{'label'};
}

sub hdlr_FieldI {
	my $class = shift;
	my ($plugin, $ctx, $args) = @_;
	my $stash_key = obj_stash_key($ctx, $args);
	return $ctx->stash("$stash_key:instance") + 1;
}

sub hdlr_FieldGroupI {
	return hdlr_FieldI(@_);
}

sub hdlr_FieldCount {
	my $class = shift;
	my ($plugin, $ctx, $args) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args);
	return $ctx->error('No field passed') unless $args->{'field'};
	my $values = $fd_data->{'values'}->{$args->{'field'}};
	return $values ? @$values : 0;
}

sub hdlr_FieldGroupCount {
	my $class = shift;
	my ($plugin, $ctx, $args) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args);
	my $group_id = get_group_id($fd_data, $ctx, $args);
	return $ctx->error('Group not found') unless $group_id;
	my $n = $fd_data->{'group_need_ns'}->{$group_id};
	return 0 || $n;
}

sub hdlr_FieldGroupLabel {
	my $class = shift;
	my ($plugin, $ctx, $args) = @_;
	my $fd_data = get_fd_data($plugin, $ctx, $args);
	my $group_id = get_group_id($fd_data, $ctx, $args);
	return $ctx->error('Group not found') unless $group_id;
	my $group = $fd_data->{'groups_by_id'}->{$group_id};
	return $group->data->{'label'};
}

sub hdlr_ListByValue {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $tag = $ctx->stash('tag');
	$tag =~ /^(.+)ListByValue/i;
	my $object_type = lc($1);
	my $ot_class = require_type(MT->instance, 'object', $object_type);
	my $ot = FieldDay::YAML->object_type($args->{'object_type'});
	require FieldDay::Value;
	my $terms = $ot_class->load_terms($ctx, $args);
	my $load_args = {};
	my $key = $args->{'field'};
	my $value = $args->{'value'};
	my $id_col = ($ot->{'object_datasource'} || $ot->{'object_mt_type'} || $object_type) . '_id';
	$load_args->{join} = FieldDay::Value->join_on(
		undef,
		{
			object_id        => \"= $id_col", #"
			key => $key,
			value => $value,
		}
	);
	my $iter = $ot->{'object_class'}->load_iter($terms, $load_args);
	return $ot_class->block_loop($iter, $ctx, $args, $cond);
}

1;
