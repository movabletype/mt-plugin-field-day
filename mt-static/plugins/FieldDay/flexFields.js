var fr_new_row_i = 0;
Node.prototype.swapNode = function(node) {
	var nextSibling = this.nextSibling;
	var parentNode = this.parentNode;
	parentNode.replaceChild(this, node);
	parentNode.insertBefore(node, nextSibling);  
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
	ffFormOnSubmit();
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
	new_instance.innerHTML = new_instance.innerHTML.replace(/<span class="instance-i" id="[^"]+">[0-9]+<\/span>/, '<span class="instance-i" id="' + group_id + '-display-instance-' + new_i + '">' + (new_i + 1) + '</span>');
	re = new RegExp("'" + group_id + "', " + i, 'g');
	new_instance.innerHTML = new_instance.innerHTML.replace(re, "'" + group_id + "', " + new_i);	
	parent.appendChild(new_instance);
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
		instance.swapNode(other_instance);
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
		other_instance.swapNode(instance);
		//need to get it out of there temporarily
		ffRenumberInstance(group_id, i + 1, -99);
		ffRenumberInstance(group_id, i, i + 1);
		ffRenumberInstance(group_id, -99, i);		
	}
}
