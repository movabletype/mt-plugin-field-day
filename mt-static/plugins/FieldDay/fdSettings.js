function findPos(obj) {
    var curleft = curtop = 0;
    if (obj.offsetParent) {
        curleft = obj.offsetLeft;
        curtop = obj.offsetTop;
        while (obj = obj.offsetParent) {
            curleft += obj.offsetLeft;
            curtop += obj.offsetTop;
        }
    }
    return [curleft,curtop];
}

function saveSettings(f, type) {
    f.elements["__mode"].value = 'fd_save_' + type;
    f.fd_setting_list.value = fd_setting_list.join(',');
    f.fd_deleted_settings.value = fd_deleted_settings.join(',');
    f.submit();
}

function editOptions(field) {
    var options_div = getByID(field + '_options_div');
    var pos = findPos(getByID(field + '_name'));
    options_div.style.left = pos[0] + 'px';
    options_div.style.top = pos[1] + 'px';
    if (showing_options) {
        showing_options.style.display = 'none';
    }
    options_div.style.display = 'block';
    showing_options = options_div;
}

function hideOptions() {
    if (typeof(showing_options) == 'undefined') return 0;
    if (showing_options) {
        showing_options.style.display = 'none';
    }
    showing_options = false;
}

function moveRow(dir, row_name) {
    frMoveRow('fdsetting-listing-table', dir, row_name, fd_setting_list);
}

function deleteRow(row_name) {
    frDeleteRow('fdsetting-listing-table', row_name, fd_setting_list, fd_deleted_settings);
}

function typeChange(sel, field) {
    var type = sel.options[sel.selectedIndex].value;
    changeType(sel, field, type);
    changeType(getByID('prototype___type'), 'prototype__', type);
    getByID('prototype___type').selectedIndex = sel.selectedIndex;
    editOptions(field);
}

function changeType(sel, field, type) {
    var options_div = getByID(field + '_options_div_inner');
    var options = fd_options[type];
    var re = new RegExp('__FIELDNAME__', 'g');
    options = options.replace(re, field);
    options_div.innerHTML = options;
}

function nameChange(fld, field_key) {
    if (fld.value) {
        var revert = 0;
        if (fld.value.match(/^[\w_]+$/)) {
            var found = 0;
            for (var i in fd_setting_names) {
                if (i == field_key) {
                    continue;
                }
                if (fd_setting_names[i] == fld.value) {
                    found = 1;
                    break;
                }
            }
            if (found) {
                alert('Duplicate fieldname.');
                revert = 1;
            }
        } else {
            alert('Field name can only contain letters, numbers, and underscores.');
            revert = 1;
        }
        if (revert) {
            fld.value = fd_setting_names[field_key] ? fd_setting_names[field_key] : '';
        } else {
            fd_setting_names[field_key] = fld.value;
        }
    }
}

function unlockRow(field) {
    getByID(field + '_delete').style.display = 'inline';
    getByID(field + '_unlock').style.display = 'none';
    getByID('delete_warning').style.display = 'block';
}
