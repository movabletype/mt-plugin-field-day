package FieldDay::FieldType::LinkedObject::LinkedUser;

use strict;

use base qw( FieldDay::FieldType::LinkedObject );


sub tags {
    return {
        'per_type' => {
            'block' => {
                'LinkedUsers' => sub { __PACKAGE__->hdlr_LinkedObjects('user', @_) },
                'IfLinkedUsers?' => sub { __PACKAGE__->hdlr_LinkedObjects('user', @_) },
                'LinkingUsers' => sub { __PACKAGE__->hdlr_LinkingObjects('user', @_) },
                'IfLinkingUsers?' => sub { __PACKAGE__->hdlr_LinkingObjects('user', @_) },
            },
        },
    };
}

sub options {
    my $class = shift;
    return {
        'active' => 1,
        %{$class->SUPER::options()},
        'allow_create' => 0, # override default
    };
}

sub label {
    return 'Linked User';
}

sub object_type {
    return 'user';
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
    return 'LinkedObject';
}

sub load_objects {
    my $class = shift;
    my ($param, @terms) = @_;
    require MT::Author;
    if (ref($terms[0])) {
        push(@terms, '-and', { 'type' => MT::Author::AUTHOR() });
        if ($param->{'active'}) {
            push(@terms, '-and', { 'status' => 1 });
        }
        return MT::Author->load(\@terms);
    } else {
        my %terms = @terms;
        return MT::Author->load(\%terms);
    }
}

sub has_blog_id {
    0;
}

sub object_label {
    my $class = shift;
    my ($obj) = @_;
    return $obj->nickname || $obj->name;
}

sub core_fields {
    my $class = shift;
    # don't need type and label because create is not currently allowed
    return { map { $_ => 1 } qw( name nickname email ) };
}

sub pre_render {
    my $class = shift;
    $class->SUPER::pre_render(@_);
    my ($param) = @_;
    $param->{'linked_object_type'} = 'author';
}

sub do_query {
    my $class = shift;
    my ($setting, $q) = @_;
    my @terms = (
        [
            {
                name => { like => '%' . $q->param('query') . '%' },
            },
            '-or',
            {
                nickname => { like => '%' . $q->param('query') . '%' },
            },
        ]
    );
    my $data = $setting->data;
    my $options = $setting->data->{'options'};
    $options->{'type'} = $data->{'type'};
    my @authors = $class->load_objects($options, @terms);
    return join("\n", map { $class->map_obj($_, $options) } @authors);
}

sub map_obj {
    my $class = shift;
    my ($author, $options) = @_;
    my @values = ($author->name, $author->id, undef);
    push(@values, $class->autocomplete_values($author, $options));
    return join("\t", @values);
}

1;
