
package FieldDay::FieldType::StarRating;
use strict;

use base qw( FieldDay::FieldType );

use FieldDay::YAML qw( types object_type );
use Data::Dumper;

sub label {
	return 'Star Rating';
}

sub options {
	return {
		'stars' => 5,
		'on_url' => undef,
		'off_url' => undef,
		'half_url' => undef,
		'is_average' => undef,
		'average_object_type' => undef,
		'average_field' => undef,
	};
}

sub tags {
	return {
		'function' => {
			'StarRatingJS' => \&html_head,
		},
	};
}

sub html_head {
	return <<"HTML";
<script type="text/javascript">
var field_stars = new Array();
var star_off_url;
var star_on_url;
function star_over(field, rating) {
	for (var i = 1; i <= rating; i++) {
		var star = document.getElementById(field + '_' + i);
		star.src = star_on_url;
	}
	for (var i = rating + 1; i <= field_stars[field]; i++) {
		var star = document.getElementById(field + '_' + i);
		star.src = star_off_url;	
	}
}
function star_out(field, rating) {
	var val = document.getElementById(field).value;
	if (val) {
		val = parseInt(val);
	} else {
		val = 0;
	}
	for (var i = 1; i <= val; i++) {
		var star = document.getElementById(field + '_' + i);
		star.src = star_on_url;
	}
	for (var i = val + 1; i <= field_stars[field]; i++) {
		var star = document.getElementById(field + '_' + i);
		star.src = star_off_url;
	}
}
function star_click(field, rating) {
	document.getElementById(field).value = rating;
}
</script>
HTML
}

sub pre_edit_options {
	my $class = shift;
	my ($param) = @_;
	my @ot_loop = ();
	my $ots = types('object');
	for my $key (sort keys %$ots) {
		push(@ot_loop, {
			'name' => $key,
			'selected' => ($key eq $param->{'average_object_type'}),
		});
	}
	$param->{'object_type_loop'} = \@ot_loop;
}

sub pre_render {
# before the field is rendered in the CMS
	my $class = shift;
	my ($param) = @_;
	my @star_loop = ();
	for my $i (1 .. $param->{'stars'}) {
		my %url;
		if ($param->{'is_average'}) {
			$url{'img_url'} = star_url($param->{'value'}, $i, $param);
		}
		push(@star_loop, {
			'rating' => $i,
			%url,
		});
	}
	$param->{'star_loop'} = \@star_loop;
}

sub pre_publish {
	my $class = shift;
	my ($ctx, $args, $value, $field) = @_;
	my $name = $field->name . (FieldDay::Template::PubTags::obj_stash_key($ctx, $args) || '');
	my $stars = $field->data->{'options'}->{'stars'};
	my $out = qq{<script type="text/javascript">
field_stars['$name'] = $stars;
</script>
};
	for my $i (1 .. $stars) {
		my $src = ($value >= $i) ? $field->data->{'options'}->{'on_url'} : $field->data->{'options'}->{'off_url'};
		my $attrs = !$args->{'enter'} ? '' : qq{ name="${name}_$i" id="${name}_$i" onmouseover="star_over('$name', $i)" onmouseout="star_out('$name', $i)" onclick="star_click('$name', $i)"};
		$out .= qq{<img src="$src"$attrs />};
		if ($args->{'enter'}) {
			$out .= qq{<input type="hidden" name="$name" id="$name" value="$value" />};
		}
	}
	return $out;
}

sub star_url {
	my ($value, $i, $param) = @_;
	$value ||= 0;
	if ($value >= $i) {
		return $param->{'on_url'};
	} else {
		if (int($value + .5) >= $i) {
			return $param->{'half_url'};
		} else {
			return $param->{'off_url'};
		}
	}
}

sub post_save_value {
	my $class = shift;
	my ($app, $value_obj, $obj, $field) = @_;
	my $options = $field->data->{'options'};
	return 1 unless $options->{'average_object_type'};
	return 1 unless $options->{'average_field'};
	my $avg_ot = FieldDay::YAML->object_type('object', $options->{'average_object_type'});
	my $avg_datasource = $avg_ot->{'datasource'} || $options->{'average_object_type'};
	my $class = ref $obj;
	my $join_col = $avg_datasource . '_id';
	my $avg_obj_id = $obj->$join_col;
	my %blog_id = $value_obj->blog_id ? ('blog_id' => $value_obj->blog_id) : ();
	my $iter = FieldDay::Value->load_iter({
		'object_type' => $value_obj->object_type,
		%blog_id,
		'key' => $value_obj->key,
	},
	{
		'join' => $class->join_on(
		undef,
		{
			'id' => \'= fdvalue_object_id', #'
			$join_col => $avg_obj_id,
		}),
	});
	my $total;
	my $n = 0;
	while (my $val = $iter->()) {
		# we don't want to include zeroes, i.e. non-ratings,
		# which would bring down the average
		next unless $val->value;
		$total += $val->value;
		$n++;
	}
	my $avg = $total / $n;
	my $avg_val = FieldDay::Value->get_by_key({
		'object_type' => $avg_datasource,
		%blog_id,
		'key' => $options->{'average_field'},
		'object_id' => $avg_obj_id,
	});
	$avg_val->value($avg);
	$avg_val->save || die $avg_val->errstr;
}
1;
