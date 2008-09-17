
package FieldDay::Template::PubTags;
use strict;
use Data::Dumper;
use FieldDay::YAML qw( field_type object_type );
use FieldDay::Util qw( load_fields require_type mtlog obj_stash_key );

sub get_fd_data {
	my ($plugin, $ctx, $args, $cond) = @_;
	my ($key, $object_id) = obj_stash_key($ctx, $args);
	return $ctx->stash($key) if $ctx->stash($key);
	my $ot = FieldDay::YAML->object_type($args->{'object_type'});
	my %blog_id = ($ot->{'has_blog_id'} && ($args->{'blog_id'} || $ctx->stash('blog')))
		? ('blog_id' => ($args->{'blog_id'} || $ctx->stash('blog')->id)) : ();
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
	my @indices = (0 .. $fd_data->{'group_need_ns'}->{$group_id} - 1);
	if ($args->{'sort_by'}) {
		# we don't need to actually sort the values, just rejigger the indices.
		if ($args->{'numeric'}) {
			if ($args->{'sort_order'} eq 'descend') {
				@indices = sort {
					$fd_data->{'values'}->{$args->{'sort_by'}}->[$b]->value
					<=> $fd_data->{'values'}->{$args->{'sort_by'}}->[$a]->value
				} @indices;
			} else {
				@indices = sort {
					$fd_data->{'values'}->{$args->{'sort_by'}}->[$a]->value
					<=> $fd_data->{'values'}->{$args->{'sort_by'}}->[$b]->value
				} @indices;
			}		
		} else {
			if ($args->{'sort_order'} eq 'descend') {
				@indices = sort {
					lc($fd_data->{'values'}->{$args->{'sort_by'}}->[$b]->value) 
					cmp lc($fd_data->{'values'}->{$args->{'sort_by'}}->[$a]->value)
				} @indices;
			} else {
				@indices = sort {
					lc($fd_data->{'values'}->{$args->{'sort_by'}}->[$a]->value) 
					cmp lc($fd_data->{'values'}->{$args->{'sort_by'}}->[$b]->value)
				} @indices;
			}
		}
	}
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out;
	for my $i (@indices) {
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
	if (!$fd_data->{'fields_by_name'}->{$field}) {
		return $ctx->error("Field $field not defined");
	}
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
			next unless ($values && @$values && $values->[$i]);
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
	if ($args->{'instance'}) {
		$instances{$args->{'instance'} - 1} = 1;
	} elsif (defined $ctx->stash("$stash_key:instance")) {
		$instances{$ctx->stash("$stash_key:instance")} = 1;
	} else {
		%instances = $args->{'instances'} ? (map { $_ => 1 } split(/,/, $args->{'instances'})) : ();
	}
	my $field = $ctx->stash($stash_key . ':field') || $args->{'field'};
	return 0 unless ($field);
	if (!$fd_data->{'fields_by_name'}->{$field}) {
		return $ctx->error("Field $field not defined");
	}
	my $group_id = $fd_data->{'fields_by_name'}->{$field}->data->{'group'} || 0;
		# return true if any instance of this field has a value
	my $values = $fd_data->{'values'}->{$field};
	return 0 unless ($values && @$values);
	for my $i (%instances ? (keys %instances) : (0 .. $fd_data->{'group_need_ns'}->{$group_id})) {
		next unless $values->[$i];
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
	} elsif (defined $ctx->stash("$stash_key:instance")) {
		$instance = $ctx->stash("$stash_key:instance");
	}
	my $values = $fd_data->{'values'}->{$field};
	if (!$fd_data->{'fields_by_name'}->{$field}) {
		return $ctx->error("Field $field not defined");
	}
	my $field_class = require_type(MT->instance, 'field', $fd_data->{'fields_by_name'}->{$field}->data->{'type'} || 'Text');
	if (!($values && @$values && $values->[$instance])) {
		if ($args->{'enter'}) {
			return $field_class->pre_publish($ctx, $args, undef, $fd_data->{'fields_by_name'}->{$field});
		} else {
			return '';
		}
	}
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
	my $ot = lc($ctx->stash('tag'));
	$ot =~ s/fieldi$//;
	if ($args->{'id'}) {
		my $object_id = $ctx->tag($ot . 'id');
		require FieldDay::Value;
		my $value = FieldDay::Value->load(
			{
				object_id => $args->{'id'},
				object_type => $ot,
				key => $args->{'field'},
				value => $object_id,
			}
		);
		return $value ? $value->instance : 0;
	}
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

sub hdlr_ByValue {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	my $tag = $ctx->stash('tag');
	$tag =~ /^(.+)ByValue/i;
	my $ot = FieldDay::YAML->object_type_by_plural($1);
	my $object_type = $ot->{'object_type'};
	my $ot_class = require_type(MT->instance, 'object', $object_type);
	require FieldDay::Value;
	my $terms = $ot_class->load_terms($ctx, $args);
	$terms->{'blog_id'} = $args->{'blog_id'} if $args->{'blog_id'};
	my $load_args = {};
	my $id_col = ($ot->{'object_datasource'} || $ot->{'object_mt_type'} || $object_type) . '_id';
	my @keys = grep { /^(eq|ne)/ } keys %$args;
	my %use_args;
	for my $key (@keys, qw( gt lt ge le like not_like )) {
		next unless ($args->{$key});
		$args->{$key} =~ s/Date([^>]*)>/Date$1 format="%Y%m%d%H%M%S">/ig;
		my $tmpl = MT::Template->new('type' => 'scalarref', 'source' => \$args->{$key});
		$tmpl->context($ctx);
		$use_args{$key} = $tmpl->output;
	}
	my $load_args = {};
	my @terms;
	my %join_args;
	my @eq;
	my @ne;
	if ($use_args{le} && $use_args{ge}) {
		push(@terms, '-and', { value => { between => [ $use_args{ge}, $use_args{le} ] } });
		delete $use_args{le};
		delete $use_args{ge};
	} elsif ($use_args{lt} && $use_args{gt}) {
		push(@terms, '-and', { value => [ $use_args{gt}, $use_args{lt} ] });
		$join_args{'range'} = { value => 1 };
		delete $use_args{lt};
		delete $use_args{gt};
	}
	my %ops = (
		'ge' => '>=',
		'gt' => '>',
		'le' => '<=',
		'lt' => '<',
	);
	for my $key (keys %use_args) {
		if ($key =~ /^eq/) {
			push(@eq, $use_args{$key});
		} elsif ($key =~ /^ne/) {
			push(@ne, $use_args{$key});
		} elsif ($key =~ /^(ge|gt|le|lt|like|not_like)$/) {
			my $op = $ops{$key} || $key;
			push(@terms, '-and', { value => { $op => $use_args{$key} } });
		}
	}
	if (@eq) {
		push(@terms, '-and', { value => [ @eq ] });
	}
	if (@ne) {
		push(@terms, '-and', { value => { not => [ @ne ] } });
	}
	require FieldDay::Value;
	$load_args->{'join'} = FieldDay::Value->join_on(
		undef,
		[{
			object_id        => \"= $id_col", #"
			key => $args->{'field'},
		},
		@terms
		],
		\%join_args
	);
	my $iter = $ot->{'object_class'}->load_iter($terms, $load_args);
	return $ot_class->block_loop($iter, $ctx, $args, $cond);
}

1;
