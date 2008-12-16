
package FieldDay::ObjectType::Template;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<mt:if name="archive_types">};
}

sub object_form_id {
	return 'template-listing-form';
}

sub stashed_id {
	my $class = shift;
	my ($ctx, $args) = @_;
	return $ctx->stash('template') ? $ctx->stash('template')->id : 0;
}

sub load_terms {
# specify terms to use when a tag loads objects
	my $class = shift;
	my ($ctx, $args) = @_;
	return {
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
	while (my $tmpl = $iter->()) {
        local $ctx->{__stash}{template} = $tmpl;
        local $ctx->{__stash}{blog_id} = $tmpl->blog_id;
        local $ctx->{__stash}{blog} = MT::Blog->load($tmpl->blog_id);
		my $text = $builder->build($ctx, $tokens, $cond);
		return $ctx->error( $builder->errstr ) unless defined $text;
		$out .= $text;
	}
	return $out;
}

sub sort_by {
	return 'name';
}

sub sort_order {
	return 'ascend';
}


1;
