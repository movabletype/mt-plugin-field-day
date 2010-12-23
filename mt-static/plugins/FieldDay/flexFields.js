///////////////////////////////////////////////////////////////////////////
// Copyright (C) 2008-2010 Six Apart Ltd.
// This program is free software: you can redistribute it and/or modify it
// under the terms of version 2 of the GNU General Public License as published
// by the Free Software Foundation, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
// version 2 for more details. You should have received a copy of the GNU
// General Public License version 2 along with this program. If not, see
// <http://www.gnu.org/licenses/>.

var fr_new_row_i = 0;

function swapNode(node1, node2) {
    var nextSibling = node1.nextSibling;
    var parentNode = node1.parentNode;
    parentNode.replaceChild(node1, node2);
    parentNode.insertBefore(node2, nextSibling);
}

Array.prototype.swap = function(a, b) {
    var tmp = this[a];
    this[a] = this[b];
    this[b] = tmp;
}

function ffInitialize() {
    for (var i = 0; i < group_need_initial.length; i++) {
        for (var j = -1; j < (group_initial_instances[group_need_initial[i]] - 1); j++) {
            ffAddInstance(group_need_initial[i], j);
        }
    }
    // set this beacon only after page is loaded, to guard against situation
    // where form might be submitted before all fields are rendered
    for (var i = 0; i < document.forms.length; i++) {
        var fld = document.forms[i].elements['fieldday'];
        if (fld) {
            fld.value = '1';
        }
    }
}
if (typeof(TC) != 'undefined') {
    TC.attachLoadEvent(ffInitialize);
}

function ffRenumberFields(node, old_re, new_str) {
    //recursively
    var i = 0;
    if (node.id) {
        node.id = node.id.replace(old_re, new_str);
    }
    if (node.name) {
        node.name = node.name.replace(old_re, new_str);
    }
    if (document.all) {
        if (node.tagName) {
            if (node.tagName.toLowerCase() == 'input') {
                var newInput = document.createElement('input');
                newInput.id = node.id;
                newInput.name = node.name;
                newInput.type = node.type;
                newInput.value = node.value;
                newInput.mergeAttributes(node);
                node = node.replaceNode(newInput);
            }
        }
    }
    while (node.childNodes[i]) {
        ffRenumberFields(node.childNodes[i], old_re, new_str);
        i++;
    }
}

function ffRenumberInstance(group_id, old_i, new_i) {
    var node = getByID(group_id + '-buttons-instance-' + old_i);
    re = new RegExp("'" + group_id + "', " + old_i, 'g');
    node.innerHTML = node.innerHTML.replace(re, "'" + group_id + "', " + new_i);
    node.id = group_id + '-buttons-instance-' + new_i;
    node = getByID(group_id + '-' + old_i);
    node.id = group_id + '-' + new_i;
    node = getByID(group_id + '-display-instance-' + old_i);
    node.id = group_id + '-display-instance-' + new_i;
    node.innerHTML = new_i + 1;
    node = getByID(group_id + '-fields-instance-' + old_i);
    var re = new RegExp('instance-' + old_i, 'g');
    //can't use innerHTML because it will reset any newly entered values
    ffRenumberFields(node, re, 'instance-' + new_i);
    node.id = group_id + '-fields-instance-' + new_i;
    instance_list[group_id].swap(old_i, new_i);
    var div_array = node.getElementsByTagName('div');
    for (var i in div_array) {
        if (/autocomplete/.test(div_array[i].className)) {
            div_array[i].style.zIndex = 10000 - new_i;
        }
    }
}

function ffAddInstance(group_id) {
    var i = -1;
    if (group_max_instances[group_id] && (instance_list[group_id].length == group_max_instances[group_id])) {
        alert('Only ' + group_max_instances[group_id] + ' instances of that group are allowed.');
        return;
    }
    var parent = getByID(group_id + '-parent');
    var new_i = instance_list[group_id].length;
    var new_name = group_id + '-' + new_i;
    instance_list[group_id][new_i] = new_name;
    var instance = getByID(group_id + '-' + i);
    var new_instance = instance.cloneNode(true);
    new_instance.id = new_name;
    new_instance.style.display = 'block';
    var re = new RegExp('instance-' + i, 'g');
    new_instance.innerHTML = new_instance.innerHTML.replace(re, 'instance-' + new_i);
    new_instance.innerHTML = new_instance.innerHTML.replace(/<span class="?instance-i"? id="?[^"]+"?>[0-9]+<\/span>/i, '<span class="instance-i" id="' + group_id + '-display-instance-' + new_i + '">' + (new_i + 1) + '</span>');
    re = new RegExp("'" + group_id + "', " + i, 'g');
    new_instance.innerHTML = new_instance.innerHTML.replace(re, "'" + group_id + "', " + new_i);
    parent.appendChild(new_instance);
    if (instance.getElementsByTagName('script')[0]) {
        var event_js = instance.getElementsByTagName('script')[0].innerHTML;
        if (event_js) {
            var find_str = 'instance-' + i;
            var re2 = new RegExp(find_str, 'g');
            event_js = event_js.replace(re2, 'instance-' + new_i);
            find_str = find_str.replace(/-/g, '_');
            re2 = new RegExp(find_str, 'g');
            event_js = event_js.replace(re2, 'instance_' + new_i);
            eval(event_js);
        }
    }
    var div_array = new_instance.getElementsByTagName('div');
    for (var i in div_array) {
        if (/autocomplete/.test(div_array[i].className)) {
            div_array[i].style.zIndex = 10000 - new_i;
        }
    }
}

function ffDeleteInstance(group_id, i) {
    if (instance_list[group_id].length == 1) {
        return;
    }
    var parent = getByID(group_id + '-parent');
    var instance = getByID(group_id + '-' + i);
    for (var j = i + 1; j < instance_list[group_id].length; j++) {
        var inst = getByID(group_id + '-' + j);
        ffRenumberInstance(group_id, j, j - 1);
    }
    parent.removeChild(instance);
    instance_list[group_id].splice(i, 1);
}

function ffMoveInstance(dir, group_id, i) {
    var instance = getByID(group_id + '-' + i);
    if (dir == 'up') {
        if (i == 0) {
            return true;
        }
        var other_instance = getByID(group_id + '-' + (i - 1));
        swapNode(instance, other_instance);
        //need to get it out of there temporarily
        ffRenumberInstance(group_id, i - 1, -99);
        ffRenumberInstance(group_id, i, i - 1);
        ffRenumberInstance(group_id, -99, i);
    }
    if (dir == 'down') {
        if (i == (instance_list[group_id].length - 1)) {
            return true;
        }
        var other_instance = getByID(group_id + '-' + (i + 1));
        swapNode(other_instance, instance);
        //need to get it out of there temporarily
        ffRenumberInstance(group_id, i + 1, -99);
        ffRenumberInstance(group_id, i, i + 1);
        ffRenumberInstance(group_id, -99, i);
    }
}
