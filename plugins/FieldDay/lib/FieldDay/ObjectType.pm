
package FieldDay::ObjectType;
use strict;
use FieldDay::Util qw( app_setting_terms app_value_terms require_type mtlog use_type );
use Data::Dumper;

sub edit_template_param {
    my $class = shift;
    my ($cb, $app, $param, $template) = @_;
    $param->{'object_form_id'} = $class->object_form_id;
}

sub edit_template_source {
    my $class = shift;
    my ($cb, $app, $template) = @_;
    if (my $old = quotemeta($class->insert_before)) {
        $$template =~ s/($old)/<mt:fd_cmsfields>$1/;
    }
    my $old = quotemeta($class->insert_before_html_head);
    require FieldDay::Setting;
    my @fields = FieldDay::Setting->load_with_default(app_setting_terms(MT->instance, 'field'));
    my %type_classes = ();
    for my $field (@fields) {
        my $data = $field->data;
        my $class;
        $data->{'type'} ||= 'Text';
        unless ($class = $type_classes{$data->{'type'}}) {
            $class = require_type(MT->instance, 'field', $data->{'type'});
            $type_classes{$class->html_head_type || $data->{'type'}} = $class;
        }
    }
    my $html_head = '';
    for my $class (values %type_classes) {
        $html_head .= $class->html_head;
    }
    my $form_id = $class->object_form_id;
    $html_head = <<"HTML";
<mt:setvarblock name="html_head" append="1">
$html_head
</mt:setvarblock>
HTML
    $$template =~ s/($old)/$html_head$1/;
    $old = qq{</form>};
    $$template =~ s#($old)#<input type="hidden" name="fieldday" value="" /></form>#g;
}

sub insert_before_html_head {
    return q{<mt:setvarblock name="html_body" append="1">};
}

sub insert_before {
    return 0;
}

sub insert_after {
    return 0;
}

sub callbacks {
    return 0;
}

sub cms_post_save {
    my $class = shift;
    my ($cb, $app, $obj) = @_;
        # if this beacon is not present, FieldDay was not loaded when the
        # editing template was loaded; we don't want to blow away any
        # existing data
    return 1 unless ($app->param('fieldday'));
    require FieldDay::Setting;
        # the process of saving data needs to be driven by the field settings
        # so we don't end up saving any fields that aren't actually defined
        # (i.e. if settings were changed between form display and save)
    my @fields = FieldDay::Setting->load_with_default(app_setting_terms(MT->instance, 'field'));
    return 1 unless @fields; # ´ optionally (plugin setting) delete any existing values
    my @param = $app->param;
    require FieldDay::Value;
    my %group_instances = map {
        my $data = $_->data; $_->id => $data->{'instances'}
    } FieldDay::Setting->load_with_default(app_setting_terms($app, 'group'));
        # set this in case it's a newly saved object
    $app->param('id', $obj->id);
    my $use_type = $app->param('setting_object_type') || use_type($app->param('_type'));
    my %existing;
    for my $field (@fields) {
        my $data = $field->data;
        next if ($data->{'options'}->{'read_only'});
        my $name = $field->name;
        $data->{'type'} ||= 'Text';
        my $class = require_type($app, 'field', $data->{'type'});
        if ($data->{'group'}) {
            for my $val (FieldDay::Value->load(app_value_terms($app, $name))) {
                $existing{$val->key . '=::=' . $val->value . '=::=' . $val->instance} = $val;
            }
            for my $i_name (grep { /^$name/ } @param) {
                if ($i_name !~ /^$name-instance-(\d+)$/) {
                    next;
                }
                my $i = $1 + 1;
                    # more instances submitted than allowed by settings
                next if ($group_instances{$data->{'group'}}
                    && ($i > $group_instances{$data->{'group'}}));
                my $value = $class->pre_save_value($app, $i_name, $obj, $data->{'options'});
                next unless $value;
                my $val;
                my $existing_key = $name . '=::=' . $value . '=::=' . $i;
                if ($existing{$existing_key}) {
                    $val = $existing{$existing_key};
                    delete $existing{$existing_key};
                } else {
                    $val = FieldDay::Value->new;
                    $val->populate($app, $name, $value, $use_type, $i);
                }
                $val->save || die $val->errstr;
                $class->post_save_value($app, $val, $obj, $field);
            }
        } else {
                # no group, don't need to worry about instances or delete existing
            my $value = $class->pre_save_value($app, $name, $obj, $data->{'options'});
            my $val;
                # shouldn't be more than one value with this key, but just in case
            my @vals = FieldDay::Value->load(app_value_terms($app, $name));
            if (scalar @vals > 1) {
                for my $i (1 .. $#vals) {
                    $vals[$i]->remove;
                }
            }
            $val = @vals ? $vals[0] : undef;
            if ($val) {
                $val->set_value($value);
            } else {
                $val = FieldDay::Value->new;
                $val->populate($app, $name, $value, $use_type);
            }
            $val->save || die $val->errstr;
            $class->post_save_value($app, $val, $obj, $field);
        }
    }
    # anything left in %existing was not re-saved, so remove it
    for my $key (keys %existing) {
        $existing{$key}->remove;
    }
    return 1;
}

sub post_remove {
    my ($cb, $app, $obj) = @_;
    require FieldDay::YAML;
    my $ot = FieldDay::YAML->object_type_by_class(ref $obj);
    require FieldDay::Value;
    my $terms = {
        object_type => $ot->{'object_type'},
        object_id => $obj->id,
    };
    for my $value (FieldDay::Value->load($terms)) {
        $value->remove;
    }
}

sub stashed_id {
# called when publishing to get the ID of a given object type out of the stash
    my ($ctx, $args) = @_;
}

sub load_terms {
# specify terms to use when a tag loads objects
    my $class = shift;
    my ($ctx, $args) = @_;
    return {};
}

sub block_loop {
# called when a tag needs to loop through objects of this type
    my $class = shift;
    my ($iter, $ctx, $args, $cond) = @_;
    return '';
}

sub sort_objects {
    my $class = shift;
    my ($object_class, $objects, $ctx, $args) = @_;
    my $col = $args->{'sort_by'};
    if ($col && !$object_class->has_column($col) && !$object_class->is_meta_column($col)) {
        my $so = $args->{'sort_order'};
        local $args->{field} = $col;
        local $ctx->{__stash};
        my %vals;
        for my $obj (@$objects) {
            my %terms = (
                object_id => $obj->id,
                object_type => $args->{'object_type'},
                key => $col,
            );
            my $value = MT->model('fdvalue')->load(\%terms);
            $vals{$obj->id} = $value->value if $value;
        }
        if ($args->{'numeric'}) {
            if ($so eq 'descend') {
                @$objects = sort { $vals{$b->id} <=> $vals{$a->id} } @$objects;
            } else {
                @$objects = sort { $vals{$a->id} <=> $vals{$b->id} } @$objects;
            }
        } else {
            if ($so eq 'descend') {
                @$objects = sort { $vals{$b->id} cmp $vals{$a->id} } @$objects;
            } else {
                @$objects = sort { $vals{$a->id} cmp $vals{$b->id} } @$objects;
            }
        }
        delete $args->{'sort_by'};
        delete $args->{'sort_order'};
    }
    $objects;
}

1;
