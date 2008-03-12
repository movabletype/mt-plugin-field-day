
package FieldDay::ObjectType::Blog;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<mt:setvarblock name="action_buttons">};
}

sub object_form_id {
	return 'cfg_form';
}

sub insert_before_html_head {
	return q{<mt:include name="include/header.tmpl">};
}

sub stashed_id {
	my $class = shift;
	my ($ctx, $args) = @_;
	return $ctx->stash('blog')->id;
}

sub load_terms {
# specify terms to use when a tag loads objects
	return {};
}

sub block_loop {
# called when a tag needs to loop through objects of this type
	my $class = shift;
	my ($iter, $ctx, $args, $cond) = @_;
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out = '';
	while (my $blog = $iter->()) {
        local $ctx->{__stash}{blog} = $blog;
        local $ctx->{__stash}{blog_id} = $blog->id;
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
