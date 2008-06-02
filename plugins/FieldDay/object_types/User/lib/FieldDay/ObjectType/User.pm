
package FieldDay::ObjectType::User;
use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
	return qq{<fieldset>
                <h3><__trans phrase="System Permissions">};
}

sub object_form_id {
	return 'profile';
}

sub stashed_id {
	my $class = shift;
	my ($ctx, $args) = @_;
	if ($ctx->stash('author')) {
		return $ctx->stash('author')->id;
	}
	if ($ctx->stash('entry')) {
		return $ctx->stash('entry')->author_id;
	}
}

sub insert_before_html_head {
	return q{<mt:include name="include/header.tmpl">};
}

sub load_terms {
# specify terms to use when a tag loads objects
	my $class = shift;
	my ($ctx, $args) = @_;
	return {
		'type' => MT::Author::AUTHOR(),
	};
}

sub block_loop {
# called when a tag needs to loop through objects of this type
	my $class = shift;
	my ($iter, $ctx, $args, $cond) = @_;
	my $builder = $ctx->stash('builder');
	my $tokens  = $ctx->stash('tokens');
	my $out = '';
	while (my $author = $iter->()) {
        local $ctx->{__stash}{author} = $author;
        local $ctx->{__stash}{author_id} = $author->id;
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
