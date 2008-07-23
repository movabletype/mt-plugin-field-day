
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
<script type="text/javascript">
function ffFormOnSubmit() {
	document.forms['$form_id'].onsubmit = ffSubmit;
}
</script>
$html_head
</mt:setvarblock>
HTML
	$$template =~ s/($old)/$html_head$1/;
	$old = qq{<form .*?name="$form_id".*?"script_url".*?">};
	$$template =~ s#($old)#$1<input type="hidden" name="fieldday" value="1" />#;
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
	for my $field (@fields) {
		my $data = $field->data;
		my $name = $field->name;
		$data->{'type'} ||= 'Text';
		my $class = require_type($app, 'field', $data->{'type'});
		if ($data->{'group'}) {
				# get rid of existing values; trying to keep track of which 
				# submitted instances correspond to which existing ones 
				# would be a huge pain, and this doesn't seem too expensive
			for my $killme (FieldDay::Value->load(app_value_terms($app, $name))) {
				$killme->remove || die $killme->errstr;
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
				my $value_obj = FieldDay::Value->new;
				$value_obj->populate($app, $name, $value, $use_type, $i);
				$value_obj->save || die $value_obj->errstr;
				$class->post_save_value($app, $value_obj, $obj, $field);
			}
		} else {
				# no group, don't need to worry about instances or delete existing
			my $value = $class->pre_save_value($app, $name, $obj, $data->{'options'});
			my $value_obj;
			if ($value_obj = FieldDay::Value->load(app_value_terms($app, $name))) {
				$value_obj->set_value($value);
			} else {
				$value_obj = FieldDay::Value->new;
				$value_obj->populate($app, $name, $value, $use_type);
			}
			$value_obj->save || die $value_obj->errstr;
			$class->post_save_value($app, $value_obj, $obj, $field);
		}
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

1;
