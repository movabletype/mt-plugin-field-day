
package FieldDay::FieldType::File;
use strict;

use base qw( FieldDay::FieldType );

sub label {
	return 'File';
}

sub tags {
	return {
		'per_type' => {
			'function' => {
				'FileURLPath' => \&hdlr_FileURLPath,
			},
		},
	};
}

sub options {
	return {
		'upload_path' => undef,
		'url_path' => undef,
		'overwrite' => 0,
		'filenames' => 'dirify',
	};
}

sub html_head {
	return <<"HTML";
<script type="text/javascript">
function fdFileFixForm() {
document.getElementById('<mt:var name="object_form_id">').enctype = 'multipart/form-data';
}
TC.attachLoadEvent(fdFileFixForm);
</script>
HTML
}

sub hdlr_FileURLPath {
	my ($ctx, $args) = @_;
	my $options = FieldDay::FieldType::field_options('FileURLPath', $ctx, $args);
	return $options->{'url_path'};
}

sub pre_render {
# before the field is rendered in the CMS
	my $class = shift;
	my ($param) = @_;
	my $app = MT->instance;
	if ($app->param('blog_id')) {
		$param->{'can_upload'} = $app->permissions->can_upload;
	} else {
		# if no blog context (i.e. for a System field), assume they wouldn't be able to access
		# this screen unless they have appropriate permissions
		$param->{'can_upload'} = 1;
	}
	if ($param->{'value'} && $param->{'value'} =~ /\.(jpg|gif|bmp|png|jpeg)$/) {
		$param->{'image'} = 1;
	}
}

sub pre_edit_options {
# before FieldDay displays the config screen
	my $class = shift;
	my ($param) = @_;
	$param->{$param->{'filenames'} . '_selected'} = 1;
}

sub pre_save_value {
# before the CMS saves a value from the editing screen
	my $class = shift;
	my ($app, $field_name, $obj, $options) = @_;
		# if they entered a value in the actual field, use that;
		# if not, use name of uploaded file
	my $upload_field = $field_name . '_upload';
	my $upload_file;
	my $q = $app->{'query'};
	if (!$q->param($upload_field)) {
		return $q->param($field_name);
	}
	if ($q->param($field_name)) {
		$upload_file = $q->param($field_name);
	} else {
		$upload_file = $q->param($upload_field);
			# IE/Win sends full path as filename
		if ($upload_file =~ m#[/\\]#) {
			$upload_file =~ s#.*[/\\]([^/\\]+)$#$1#;
		}
		if ($options->{'filenames'} ne 'keep') {
			$upload_file =~ s/\.(\w+)$//;
			my $ext = $1;
			if (!$ext) {
				(undef, $ext) = split(m#/#, 
					$q->uploadInfo($q->param($upload_field))->{'Content-Type'});
				$ext = 'jpg' if ($ext eq 'jpeg');
				$ext = 'txt' if ($ext eq 'text');
			}
			if ($options->{'filenames'} eq 'dirify') {
				require MT::Util;
				$upload_file = MT::Util::dirify($upload_file);
			} elsif ($options->{'filenames'} eq 'id') {
				$upload_file = $obj->id;
			} elsif ($options->{'filenames'} eq 'basename') {
				$upload_file = $obj->basename;
			}
			$field_name =~ s/-instance-/_/;
			$upload_file .= "_${field_name}.$ext";
		}
	}
	
	return save_upload($q->upload($upload_field),
		$options->{'upload_path'}, $upload_file, $options->{'overwrite'});
}

sub save_upload {
	my ($fh, $path, $file, $overwrite) = @_;

    use File::Spec;
    $path = File::Spec->canonpath($path);
    my $filename = File::Spec->catfile($path, $file);

	my $newfile;
	# generate unique filename (add number if it exists)
	unless ($overwrite) {
		my $i = 0;
		while (-e $filename) {
			$i++;
			$newfile = $file;
			$newfile =~ s/\.(\w+)$/_$i.$1/;
			$filename = File::Spec->catfile($path, $newfile);
		}
	}

    my $fmgr;
    require MT::FileMgr;
    $fmgr = MT::FileMgr->new('Local');
    return undef unless $fmgr;
    unless ( defined $fmgr->put( $fh, $filename, 'upload' ) ) {
        my $plugin_name = MT->component('fieldday')->name;
        MT->log({
            message => MT->translate(
                "[_1]: Writing to '[_2]' failed: [_3]", $plugin_name, $filename, $fmgr->errstr ),
            level => MT::Log::ERROR(),
        });
        return undef;
    }

	return $newfile ? $newfile : $file;
}

1;
