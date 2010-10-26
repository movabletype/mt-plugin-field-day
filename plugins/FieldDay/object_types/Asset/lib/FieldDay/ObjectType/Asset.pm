package FieldDay::ObjectType::Asset;

use strict;
use Data::Dumper;

use base qw( FieldDay::ObjectType );

sub insert_before {
    return qq{<button};
}

sub object_form_id {
    return 'asset_form';
}

sub stashed_id {
    my $class = shift;
    my ($ctx, $args) = @_;
    my $asset = $ctx->stash('asset');
    return $asset ? $asset->id : undef;
}

sub edit_template_source {
    my $class = shift;
    my ($cb, $app, $template) = @_;
    $$template =~ s/<form method="post"/<form method="post" name="asset_form" id="asset_form"/;
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
        'class' => '*',
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
    my @assets;
    while (my $asset = $iter->()) {
        push(@assets, $asset);
    }
    local $ctx->{__stash}->{assets} = \@assets;
#   return Dumper(\@assets);
    return $ctx->tag('assets', $args, $cond);
}

sub sort_by {
    return 'created_on';
}

sub sort_order {
    return 'descend';
}

1;
