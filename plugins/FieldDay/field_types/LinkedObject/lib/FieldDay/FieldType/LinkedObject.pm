
package FieldDay::FieldType::LinkedObject;
use strict;
use Data::Dumper;
use FieldDay::YAML qw( field_type object_type );
use FieldDay::Util qw( app_setting_terms load_fields require_type mtlog );

use base qw( FieldDay::FieldType );

sub pre_edit_options {
# before FieldDay displays the config screen
	my $class = shift;
	my ($param) = @_;
	if ($class->has_blog_id) {
		my @blog_loop = ();
		require MT::Blog;
		for my $blog (MT::Blog->load) {
			push (@blog_loop, {
				'value' => $blog->id,
				'label' => $blog->name,
				'selected' => ($param->{'linked_blog_id'} && ($param->{'linked_blog_id'} == $blog->id)) ? 1 : 0,
			});
		}
		$param->{'linked_blog_loop'} = \@blog_loop;
	}
}

sub pre_render {
	my $class = shift;
	my ($param) = @_;
	my @object_loop = ();
	for my $obj ($class->load_objects($param)) {
		my $value = $class->object_value($obj);
		my $label = $class->object_label($obj);
		push(@object_loop, {
			'value' => $value,
			'selected' => ($param->{'value'} && 
				($param->{'value'} eq $value)) ? 1 : 0,
			'label' => $label
		});
	}
	$param->{'object_loop'} = \@object_loop;
}

sub hdlr_LinkedObjects {
	my $class = shift;
	my $linked_type = shift;
	my ($ctx, $args, $cond) = @_;
	$ctx->stash('tag') =~ /^(.+?)(If)?Linked/i;
	my $linking_type = lc($1);
	return $ctx->error('No field passed') unless $args->{'field'};
	my $ot_class = require_type(MT->instance, 'object', $linked_type);
	my $ot = FieldDay::YAML->object_type($linked_type);
	my $linking_ot_class = require_type(MT->instance, 'object', $linking_type);
	my $linking_ot = FieldDay::YAML->object_type($linking_type);
	my $object_id = $linking_ot_class->stashed_id($ctx, $args);
	my $linked_type = $class->object_type;
	require FieldDay::Value;
	my $load_args = {};
	my $terms = $ot_class->load_terms($ctx, $args);
	delete $terms->{'blog_id'};
	my $id_col = ($ot->{'object_mt_type'} || $ot->{'object_type'}) . '_id';
	$load_args->{join} = FieldDay::Value->join_on(
		undef,
		{
			'value'        => \"= $id_col", #"
			'key' => $args->{'field'},
			'object_type' => $linking_ot->{'object_mt_type'} || $linking_ot->{'object_type'},
			'object_id' => $object_id,
		}
	);
	$load_args->{'sort'} = $args->{'sort_by'} || $ot_class->sort_by;
	$load_args->{'direction'} = $args->{'sort_order'} || $ot_class->sort_order;
	if ($ctx->stash('tag') =~ /IfLinked/) {
		return $ot->{'object_class'}->count($terms, $load_args) ? 1 : 0;
	}
	my $iter = $ot->{'object_class'}->load_iter($terms, $load_args);
	return $ot_class->block_loop($iter, $ctx, $args, $cond);
}

sub hdlr_LinkingObjects {
	my $class = shift;
	my $linking_type = shift;
	my ($ctx, $args, $cond) = @_;
	$ctx->stash('tag') =~ /^(.+?)(If)?Linking/i;
	my $linked_type = lc($1);
	return $ctx->error('No field passed') unless $args->{'field'};
	my $ot_class = require_type(MT->instance, 'object', $linked_type);
	my $ot = FieldDay::YAML->object_type($linked_type);
	my $linking_ot = FieldDay::YAML->object_type($linking_type);
	my $linking_ot_class = require_type(MT->instance, 'object', $linking_type);
	my $linked_object_id = $ot_class->stashed_id($ctx, $args);
	require FieldDay::Value;
	my $load_args = {};
	my $terms = $linking_ot_class->load_terms($ctx, $args);
	if (!$args->{'blog_id'}) {
		delete $terms->{'blog_id'};
	} else {
		$terms->{'blog_id'} = $args->{'blog_id'};
	}
	my $id_col = $linking_type . '_id';
	$load_args->{join} = FieldDay::Value->join_on(
		undef,
		{
			'object_id' => \"= $id_col", #"
			'value'        => $linked_object_id,
			'key' => $args->{'field'},
			'object_type' => $linking_ot->{'object_mt_type'} || $linking_ot->{'object_type'},
		}
	);
	#die Dumper($terms, $load_args);
	$load_args->{'sort'} = $args->{'sort_by'} || $linking_ot_class->sort_by;
	$load_args->{'direction'} = $args->{'sort_order'} || $linking_ot_class->sort_order;
	if ($ctx->stash('tag') =~ /IfLinking/) {
		return $linking_ot->{'object_class'}->count($terms, $load_args) ? 1 : 0;
	}
	my $iter = $linking_ot->{'object_class'}->load_iter($terms, $load_args);
	return $linking_ot_class->block_loop($iter, $ctx, $args, $cond);
}

sub hdlr_IfLinkingObjects {
	my $class = shift;
	my $linking_type = shift;
	my ($ctx, $args, $cond) = @_;
	die Dumper(\@_);
}

sub has_blog_id {
	return 1;
}

sub object_value {
	my $class = shift;
	my ($obj) = @_;
	return $obj->id;
}

1;
