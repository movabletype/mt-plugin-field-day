
package FieldDay::Template::AppTags;
use strict;
use Data::Dumper;
use FieldDay::YAML qw( field_type );
use FieldDay::Util qw( app_setting_terms load_fields require_type mtlog );

sub hdlr_cmsfields {
	my $class = shift;
	my ($plugin, $ctx, $args, $cond) = @_;
	require FieldDay::FieldType;
	my $render_tmpls = FieldDay::FieldType::type_tmpls($plugin, MT->instance, 'render');
	require MT::Template;
	my ($fields_by_name, $grouped_fields, $group_need_ns, $values, $group_orders, $groups_by_id)
		= load_fields($plugin, $ctx, $args, $cond);
	my $out = '';
	my %instance_list = ();
	my @group_need_initial = ();
	my %group_max_instances = ();
	my %group_initial_instances = ();
	my $static_uri = MT->instance->static_path;
	my $tabindex = 3;
	my $blog_id = MT->instance->param('blog_id');
	my $check_set = $blog_id && MT->component('blogset');
	for my $group_id (sort {
				$group_orders->{$a} <=> $group_orders->{$b}
			} keys %$grouped_fields) {
		my $g_data;
		if ($group_id > 0) {
			$g_data = $groups_by_id->{$group_id}->data;
			if ($check_set && $g_data->{'set'}) {
				require BlogSet::Util;
				if (!BlogSet::Util::blog_in_set($blog_id, $g_data->{'set'})) {
					delete $grouped_fields->{$group_id};
					next;
				}
			}
		}
		my $class = $group_id ? ' class="fd-group-parent">' : '';
		my $group_out = qq{<div id="group-${group_id}-parent"$class};
		my $n = $group_need_ns->{$group_id} || 0;
		if (!$n && $group_id) {
			push(@group_need_initial, $group_id);
			$group_initial_instances{$group_id} = $g_data->{'initial'} || 1;
		}
		if ($g_data->{'instances'} && ($g_data->{'instances'} > 0)) {
			$group_max_instances{$group_id} = $g_data->{'instances'};
		}
		$instance_list{$group_id} = [];
		if ($group_id > 0) {
			$group_out .= qq{<h4 class="fd-group-head">$g_data->{'label'}</h4>};
		}
		for (my $i = -1; $i < $n; $i++) {
				# don't need a prototype if no group
			if (($i == -1) && ($group_id == 0)) {
				$i = 0;
			}
			if ($group_id > 0) {
				my $inst = ' <span class="instance-i" id="group-' . $group_id . '-display-instance-' . $i . '">' . ($i+1) . '</span>';
				my $buttons = ($g_data->{'instances'} && ($g_data->{'instances'} == 1)) ? '' : <<"TMPL";
<span class="fd-group-buttons" id="group-${group_id}-buttons-instance-$i">
<span class="fd-group-button">
<a href="javascript:void(0);" onclick="ffDeleteInstance('group-$group_id', $i);"><img src="${static_uri}plugins/FieldDay/nav-delete.gif" border="0" /></a>
</span>
<span class="fd-group-button">
<a href="javascript:void(0);" onclick="ffMoveInstance('up', 'group-$group_id', $i);"><img src="${static_uri}plugins/FieldDay/nav-arrow-up.gif" border="0" /></a>
</span>
<span class="fd-group-button">
<a href="javascript:void(0);" onclick="ffMoveInstance('down', 'group-$group_id', $i);"><img src="${static_uri}plugins/FieldDay/nav-arrow-down.gif" border="0" /></a>
</span>
<span class="fd-group-button">
<a href="javascript:void(0);" onclick="ffAddInstance('group-$group_id');"><img src="${static_uri}images/status_icons/create.gif" border="0" /></a>
</span>
</span>
TMPL
				my $div;
				my $class = ' class="fd-group"';
				if ($i == -1) {
					$div = qq{<div id="group-${group_id}-$i" style="display:none;"$class>};
				} else {
					$div = qq{<div id="group-${group_id}-$i"$class>};
					push(@{$instance_list{$group_id}}, "group-${group_id}-$i");
				}
				$group_out .= $div;
				if (($group_max_instances{$group_id} || 0) != 1) {
					$group_out .= qq{
<span class="fd-group-inst-buttons"><span class="fd-group-inst">$inst</span>$buttons</span>
};
				}
				$group_out .= qq{
<div id="group-${group_id}-fields-instance-$i">
};
			}
			for my $field (@{$grouped_fields->{$group_id}}) {
				my $data = $field->data;
				$data->{'type'} ||= 'Text';
				my $tmpl_text = $render_tmpls->{$data->{'type'}};
				my $tmpl = MT::Template->new('type' => 'scalarref', 'source' => \$tmpl_text);
				my $field_name = $field->name;
				$field_name .= "-instance-$i" if ($group_id > 0);
				my $js_field_name = $field_name;
				$js_field_name =~ s/-/_/g;
				my $param = {
					'field' => $field_name,
					'js_field' => $js_field_name,
					'label' => $data->{'label'} || $field_name,
					'label_display' => $data->{'options'}->{'label_display'},
					'tabindex' => ++$tabindex,
				};
				my $class = require_type(MT->instance, 'field', $data->{'type'});
				for my $key (keys %{$class->options}) {
					$param->{$key} = $data->{'options'}->{$key};
				}
				if ($i > -1) {
					if (my $value = $values->{$field->name}->[$i]) {
						$param->{'value'} = $value->value;
					}
				}
				$param->{'static_uri'} = $static_uri;
				$param->{'setting_id'} = $field->id;
				$class->pre_render($param, $args);
				$tmpl->param({ %$param, %$args });
				$group_out .= $tmpl->output;
					# the field type may increment this
				$tabindex = $param->{'tabindex'};
			}
			$group_out .= '</div></div>' if $group_id;
		}
		$group_out .= '</div><div style="clear:both;"></div>';
		$out .= $group_out;
	}
	my $js = '';
	my $js_vars = 'var instance_list = new Array();';
	$js_vars .= 'var instance_max = new Array();';
	for my $key (keys %instance_list) {
		$js_vars .= "instance_list['group-$key'] = new Array("
		. join(',', map { "'$_'" } @{$instance_list{$key}} )
		. ');';
		next unless $groups_by_id->{$key};
		my $max = $groups_by_id->{$key}->data->{'instances'};
		#$js_vars .= "instance_max['group-$key'] = $max;";
	}
	$js_vars .= 'var group_need_initial = new Array('
		. join(',', map { "'group-$_'" } @group_need_initial)
		. ');';
	$js_vars .= 'var group_fields = new Array();';
	$js_vars .= 'var group_max_instances = new Array();';
	$js_vars .= 'var group_initial_instances = new Array();';
	for my $group_id (keys %$grouped_fields) {
		$js_vars .= "group_fields['group-$group_id'] = new Array("
		. join(',', map { "'" . $_->name . "'" } @{$grouped_fields->{$group_id}} )
		. ');';
		if ($group_max_instances{$group_id}) {
			$js_vars .= "group_max_instances['group-$group_id'] = $group_max_instances{$group_id};";
		}
		if ($group_initial_instances{$group_id}) {
			$js_vars .= "group_initial_instances['group-$group_id'] = $group_initial_instances{$group_id};";
		}
	}
	$js = <<"TMPL";
<script type="text/javascript">
document.write('<scri' + 'pt type="text/javascript" src="' + StaticURI + 'plugins/FieldDay/flexFields.js"></sc' + 'ript>');
$js_vars
</script>
TMPL
	return <<"TMPL";
<style type="text/css">
.fd-group-head {
border:1px solid #ccc;
padding:5px 0 5px 5px;
margin-bottom:10px;
}
.fd-group-buttons {
padding-right:5px;
}
.fd-group-inst-buttons {
float:left;
width:75px;
padding-bottom:5px;
}
.fd-group-inst {
font-weight:bold;
font-size:12px;
padding-right:5px;
}
.fd-group {
padding-bottom:5px;
margin-bottom:10px;
border-bottom:1px solid #ccc;
}
.fd-group-parent {
padding-bottom:10px;
}
.fd-group-parent .field {
margin-bottom:.75em;
}
</style>
$js
<fieldset>
$out
</fieldset>
TMPL
}

1;
