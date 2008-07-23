
package FieldDay::FieldType::LinkedObject;
use strict;
use Data::Dumper;
use FieldDay::YAML qw( field_type object_type );
use FieldDay::Util qw( app_setting_terms load_fields require_type mtlog );

use base qw( FieldDay::FieldType );

sub pre_edit_options {
# before FieldDay displays the config screen
	my $class = shift;
	my ($param) = @_;
	if ($class->has_blog_id) {
		my @blog_loop = ();
		require MT::Blog;
		for my $blog (MT::Blog->load) {
			push (@blog_loop, {
				'value' => $blog->id,
				'label' => $blog->name,
				'selected' => ($param->{'linked_blog_id'} && ($param->{'linked_blog_id'} == $blog->id)) ? 1 : 0,
			});
		}
		$param->{'linked_blog_loop'} = \@blog_loop;
	}
}

sub pre_render {
	my $class = shift;
	my ($param) = @_;
	my @object_loop = ();
	my %blog_ids = ();
	if ($param->{'autocomplete'}) {
		if ($param->{'value'}) {
			push(@object_loop, {
				'value' => $param->{'value'},
				'selected' => 1,
				'label' => $class->object_label($class->load_objects({}, id => $param->{'value'})),
			});
		}
	} else {
		for my $obj ($class->load_objects($param)) {
			my $value = $class->object_value($obj);
			my $label = $class->object_label($obj);
			my $blog_label;
			if ($class->has_blog_id) {
				my $blog = MT::Blog->load($obj->blog_id);
				next unless $blog;
				$blog_label = ' (' . MT::Util::remove_html($blog->name) . ')';
				$blog_ids{$obj->blog_id} = 1;
			}
			push(@object_loop, {
				'value' => $value,
				'selected' => ($param->{'value'} && 
					($param->{'value'} eq $value)) ? 1 : 0,
				'label' => $label,
				'blog_label' => $blog_label,
			});
		}
		if (scalar keys %blog_ids > 1) {
			for my $row (@object_loop) {
				$row->{'label'} = $row->{'label'} . $row->{'blog_label'};
			}
		}
	}
	if ($param->{'allow_create'} && $param->{'create_fields'}) {
		my @field_list;
		require FieldDay::Setting;
		my $static_uri = MT->instance->static_path;
		my $render_tmpls = FieldDay::FieldType::type_tmpls(MT->instance, MT->instance, 'render');
		for my $name (split(/,/, $param->{'create_fields'})) {
			my $core_fields = $class->core_fields;
			my $data;
			if ($core_fields->{$name}) {
				$data = $core_fields->{$name};
			} else {
				my $field = FieldDay::Setting->load({
					'type' => 'field',
					$param->{'linked_blog_id'} ? ('blog_id' => $param->{'linked_blog_id'}) : (),
					'object_type' => $class->object_type,
					'name' => $name,
				});
				next unless $field;
				$data = $field->data;
			}
			$data->{'type'} ||= 'Text';
			my $tmpl_text = $render_tmpls->{$data->{'type'}};
			my $tmpl = MT::Template->new('type' => 'scalarref', 'source' => \$tmpl_text);
			my $field_name = $param->{'field'} . '-' . $name;
			push(@field_list, $field_name);
			my $f_param = {
				'field' => $field_name,
				'label' => $data->{'label'} || $name,
				'label_above' => $data->{'options'}->{'label_above'} ? 1 : 0,
			};
			my $f_class = require_type(MT->instance, 'field', $data->{'type'});
			for my $key (keys %{$f_class->options}) {
				$f_param->{$key} = $data->{'options'}->{$key};
			}
			$f_param->{'static_uri'} = $static_uri;
			$f_class->pre_render($f_param);
			$tmpl->param($f_param);
			$param->{'create_form'} .= $tmpl->output;
		}
		$param->{'field_list'} = join(',', map { "'" . $_ . "'" } @field_list);
	}
	$param->{'object_loop'} = \@object_loop;
}

sub render_tmpl_type {
# the field type that contains the render template, used for subclasses
	return 'LinkedObject';
}

sub html_head_type {
	return 'LinkedObject';
}

sub html_head {
	return <<"HTML";
<link type="text/css" rel="stylesheet" href="http://yui.yahooapis.com/2.5.2/build/autocomplete/assets/skins/sam/autocomplete.css">
<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/yahoo-dom-event/yahoo-dom-event.js"></script> 
<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/connection/connection-min.js"></script> 
<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/autocomplete/autocomplete-min.js"></script>
<script type="text/javascript">
function linkedObjectSelect(field, data) {
	var f = getByID(field);
	f.options.length = 1;
	f.options[0] = new Option(data[0], data[1]);
	var tx = getByID(field + '-text');
	tx.value = '';
}
function linkedObjectToggleCreate(field, on) {
	var fieldsDiv = getByID(field + '-create-fields');
	var linkDiv = getByID(field + '-create-link');
	if (on) {
		linkDiv.style.display = 'none';
		fieldsDiv.style.display = 'block';
	} else {
		linkDiv.style.display = 'block';
		fieldsDiv.style.display = 'none';
	}
}
function linkedObjectSubmit(field, setting_id, blog_id, ac) {
	var param = '__mode=fd_save_linked_obj';
	param += '&blog_id=' + blog_id;
	param += '&setting_id=' + setting_id;
	for (var i = 0; i < linkedObjectFormFields[field].length; i++) {
		var fld = getByID(linkedObjectFormFields[field][i]);
		param += '&' + linkedObjectFormFields[field][i].replace(new RegExp(field + '-'), '') + '=' + fld.value;
	}
    var params = {
    	uri: '<mt:var name="script_url">',
    	method: 'POST',
    	arguments: param,
    	load: function(c) {
    		linkedObjectReturn(c, field, ac);
    	}
    };
    TC.Client.call(params);
}
function linkedObjectReturn(c, field, ac) {
	var resp;
    try {
        resp = eval('(' + c.responseText + ')');
    } catch(e) {
		alert("Error: invalid response");
        return;
    }
    if (resp.error) {
    	alert(resp.error);
    	return;
    }
	var result = resp.result;
    if (result.code == 'added') {
    	linkedObjectToggleCreate(field, false);
    	if (ac) {
    		linkedObjectSelect(field, new Array(result.label, result.id));
    	}
    } else if (result.code == 'found') {
    	linkedObjectToggleCreate(field, false);
    	if (ac) {
    		linkedObjectSelect(field, new Array(result.label, result.id));
    	}
    	alert(result.msg);
    }
}
var linkedObjectFormFields = new Array();
var myServer = "<mt:var name="script_path">plugins/FieldDay/mt-linkedobj-flat.cgi"; 
var mySchema = ["\\n", "\\t"]; 
YAHOO.widget.AutoComplete.prototype.formatResult = function(aResultItem, sQuery) {
	var re = new RegExp('(' + sQuery + ')', 'ig');
	var matches = aResultItem[0].match(re);
	return aResultItem[0].replace(re, function(str) { return '<span class="linked-object-highlight">' + str + '</span>'; });
};
</script>
<style type="text/css">
.yui-skin-sam .yui-ac-content li.yui-ac-highlight {
background-color:#cddee7;
color:#33789c;
}
.yui-skin-sam .yui-ac-input {
position:relative;
width:50%;
}
.linked-object-highlight {
font-weight:bold;
color:#33789c;
}
.linked-object-create-link {
padding:5px 0 0 0;
}
.linked-object-create-fields {
display:none;
border:1px solid #999;
margin:10px 0 0 0;
padding:10px;
}
</style>
HTML
}

sub hdlr_LinkedObjects {
	my $class = shift;
	my $linked_type = shift;
	my ($ctx, $args, $cond) = @_;
	$ctx->stash('tag') =~ /^(.+?)(If)?Linked/i;
	my $linking_type = lc($1);
	return $ctx->error('No field passed') unless $args->{'field'};
	my $ot_class = require_type(MT->instance, 'object', $linked_type);
	my $ot = FieldDay::YAML->object_type($linked_type);
	my $linking_ot_class = require_type(MT->instance, 'object', $linking_type);
	my $linking_ot = FieldDay::YAML->object_type($linking_type);
	my $object_id = $linking_ot_class->stashed_id($ctx, $args);
	require FieldDay::Value;
	my $load_args = {};
	my $terms = $ot_class->load_terms($ctx, $args);
	delete $terms->{'blog_id'};
	my $id_col = id_col($ot);
	$load_args->{join} = FieldDay::Value->join_on(
		undef,
		{
			'value'        => \"= $id_col", #"
			'key' => $args->{'field'},
			'object_type' => $linking_ot->{'object_mt_type'} || $linking_ot->{'object_type'},
			'object_id' => $object_id,
		}
	);
	eval("require $ot->{'object_class'};");
	if ($ctx->stash('tag') =~ /IfLinked/) {
		return $ot->{'object_class'}->count($terms, $load_args) ? 1 : 0;
	}
	$load_args->{'sort'} = $args->{'sort_by'} || $ot_class->sort_by;
	$load_args->{'direction'} = $args->{'sort_order'} || $ot_class->sort_order;
	my $iter = $ot->{'object_class'}->load_iter($terms, $load_args);
	return $ot_class->block_loop($iter, $ctx, $args, $cond);
}

sub hdlr_LinkingObjects {
	my $class = shift;
	my $linking_type = shift;
	my ($ctx, $args, $cond) = @_;
	$ctx->stash('tag') =~ /^(.+?)(If)?Linking/i;
	my $linked_type = lc($1);
	return $ctx->error('No field passed') unless $args->{'field'};
	my $ot_class = require_type(MT->instance, 'object', $linked_type);
	my $ot = FieldDay::YAML->object_type($linked_type);
	my $linking_ot = FieldDay::YAML->object_type($linking_type);
	my $linking_ot_class = require_type(MT->instance, 'object', $linking_type);
	my $linked_object_id = $ot_class->stashed_id($ctx, $args);
	require FieldDay::Value;
	my $load_args = {};
	my $terms = $linking_ot_class->load_terms($ctx, $args);
	local $ctx->{__stash}{blog_id};
	if (!$args->{'blog_id'}) {
		delete $terms->{'blog_id'};
	} else {
		$terms->{'blog_id'} = $args->{'blog_id'};
		$ctx->{__stash}{blog_id} = $args->{'blog_id'};
	}
	my $id_col = id_col($linking_ot);
	$load_args->{join} = FieldDay::Value->join_on(
		undef,
		{
			'object_id' => \"= $id_col", #"
			'value'        => $linked_object_id,
			'key' => $args->{'field'},
			'object_type' => $linking_ot->{'object_mt_type'} || $linking_ot->{'object_type'},
		}
	);
	eval("require $ot->{'object_class'};");
	die $@ if $@;
	if ($ctx->stash('tag') =~ /IfLinking/) {
		return $linking_ot->{'object_class'}->count($terms, $load_args) ? 1 : 0;
	}
	$load_args->{'sort'} = $args->{'sort_by'} || $linking_ot_class->sort_by;
	$load_args->{'direction'} = $args->{'sort_order'} || $linking_ot_class->sort_order;
	my $iter = $linking_ot->{'object_class'}->load_iter($terms, $load_args);
	return $linking_ot_class->block_loop($iter, $ctx, $args, $cond);
}

sub id_col {
	my ($ot) = @_;
	return ($ot->{'object_datasource'} || $ot->{'object_mt_type'} || $ot->{'object_type'}) . '_id'
}

sub has_blog_id {
	return 1;
}

sub object_value {
	my $class = shift;
	my ($obj) = @_;
	return $obj ? $obj->id : undef;
}

sub save_object {
	my $class = shift;
	my ($setting, $app) = @_;
	return $app->json_error("Type $class not supported");
}

sub core_fields {
	return {};
}

1;
