
package FieldDay::ObjectType::Entry;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<mt:setvarblock name="show_metadata">};
}

sub object_form_id {
	return 'entry_form';
}

sub stashed_id {
	my $class = shift;
	my ($ctx, $args) = @_;
	return $ctx->stash('entry')->id;
}

sub load_terms {
# specify terms to use when a tag loads objects
	my $class = shift;
	my ($ctx, $args) = @_;
	return {
		'status' => MT::Entry::RELEASE(),
		$ctx->stash('blog') ? ('blog_id' => $ctx->stash('blog')->id) : (),
	};
}

sub block_loop {
# called when a tag needs to loop through objects of this type
	my $class = shift;
	my ($iter, $ctx, $args, $cond) = @_;
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out = '';
	while (my $e = $iter->()) {
		local $ctx->{__stash}{blog} = $e->blog;
		local $ctx->{__stash}{blog_id} = $e->blog_id;
		local $ctx->{__stash}{entry} = $e;
		local $ctx->{current_timestamp} = $e->authored_on;
		local $ctx->{modification_timestamp} = $e->modified_on;
		my $text = $builder->build($ctx, $tokens, $cond);
		return $ctx->error( $builder->errstr ) unless defined $text;
		$out .= $text;
	}
	return $out;
}

sub sort_by {
	return 'created_on';
}

sub sort_order {
	return 'descend';
}


1;
