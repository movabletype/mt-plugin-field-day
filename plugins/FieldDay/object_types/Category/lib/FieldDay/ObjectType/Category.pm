
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

1;
