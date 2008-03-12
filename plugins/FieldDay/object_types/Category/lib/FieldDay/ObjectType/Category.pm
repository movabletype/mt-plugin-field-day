
package FieldDay::ObjectType::Category;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<fieldset>
        <h3><__trans phrase="Inbound TrackBacks"></h3>};
}

sub object_form_id {
	return 'category_form';
}

sub stashed_id {
	my $class = shift;
	my ($ctx, $args) = @_;
	my $e;
	my $cat = ($ctx->stash('category') || $ctx->stash('archive_category'))
		|| (($e = $ctx->stash('entry')) && $e->category);
	return $cat ? $cat->id : 0;
}

sub edit_template_source {
	my $class = shift;
	my ($cb, $app, $template) = @_;
	$$template =~ s/<form method="post"/<form method="post" name="category_form" id="category_form"/;
	$class->SUPER::edit_template_source(@_);
}

sub insert_before_html_head {
	return q{<mt:include name="include/header.tmpl">};
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
    local $ctx->{inside_mt_categories} = 1;
	while (my $cat = $iter->()) {
        local $ctx->{__stash}{category} = $cat;
        local $ctx->{__stash}{entries};
        local $ctx->{__stash}{category_count};
        local $ctx->{__stash}{blog_id} = $cat->blog_id;
        local $ctx->{__stash}{blog} = MT::Blog->load($cat->blog_id);
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
