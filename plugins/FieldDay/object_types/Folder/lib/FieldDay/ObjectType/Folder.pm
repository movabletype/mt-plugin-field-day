package FieldDay::ObjectType::Folder;

use strict;

use Data::Dumper;

use base qw( FieldDay::ObjectType::Category );

sub insert_before {
    return qq{<mt:setvarblock name="action_buttons">};
}

sub object_form_id {
    return 'folder_form';
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
    $$template =~ s/<form method="post"/<form method="post" name="folder_form" id="folder_form"/;
    $class->SUPER::edit_template_source(@_);
}

sub insert_before_html_head {
    return q{<mt:include name="include/header.tmpl">};
}

1;
