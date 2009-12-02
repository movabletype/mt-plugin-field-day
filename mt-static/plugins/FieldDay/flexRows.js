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
function frAddRow(table_id, hidden_div_key, item_list, new_item_list) {
	fr_new_row_i++;
	var row_name = 'new_row_' + fr_new_row_i;
	var table = getByID(table_id);
	var new_row = getByID('prototype___row').cloneNode(true);
	table.tBodies[0].appendChild(new_row);
	new_row.id = row_name;
	new_row.name = row_name;
	if ( navigator.appName == "Microsoft Internet Explorer" ) {
		new_row.style.display = 'block';
	} else {
		new_row.style.display = 'table-row';
	}
	var old_name = 'prototype__';
	var re = new RegExp(old_name, 'g');
	for (var i = 0; i < new_row.cells.length; i++) {
		new_row.cells[i].innerHTML = new_row.cells[i].innerHTML.replace(re, row_name);
	}
	var class_name;
	if (table.tBodies[0].rows.length > 1) {
		class_name = table.tBodies[0].rows[table.tBodies[0].rows.length-1].className;
	} else {
		class_name = 'even';
	}
	new_row.className = (class_name == 'odd') ? 'even' : 'odd';
	if (hidden_div_key) {
		var old_div = getByID(old_name + '_' + hidden_div_key + '_div');
		var new_div = old_div.cloneNode(true);
		new_div.innerHTML = new_div.innerHTML.replace(re, row_name);
		re = new RegExp('__FIELDNAME__', 'g');
		new_div.innerHTML = new_div.innerHTML.replace(re, row_name);
		new_div.id = row_name + '_' + hidden_div_key + '_div';
		getByID('fr_all_hidden_divs').appendChild(new_div);
	}
	var order = getByID(row_name + '_order');
	item_list[item_list.length] = row_name;
	order.value = item_list.length - 1;
	return { old_name : old_name, new_name : row_name };
}
function frMoveRow(table_id, dir, row_name, item_list) {
	hideOptions();
	var table = getByID(table_id);
	var order_field = getByID(row_name + '_order');
	var order = parseInt(order_field.value);
	var i = order;
	var swap_row;
	var swap_i;
	if (dir == 'up') {
		if (i == 1) {
			return true;
		}
		swap_i = i - 1;
		swap_row = table.tBodies[0].rows[swap_i];
		swapNode(table.tBodies[0].rows[i], swap_row);
	}
	if (dir == 'down') {
		if (i == item_list.length - 1) {
			return true;
		}
		swap_i = i + 1;
		swap_row = table.tBodies[0].rows[swap_i];
		swapNode(swap_row, table.tBodies[0].rows[i]);
	}
	var swap_order_field = getByID(item_list[swap_i] + '_order');
	item_list.swap(i, swap_i);
	order_field.value = swap_i;
	swap_order_field.value = i;
	frReFlipFlop(table);
}
function frDeleteRow(table_id, row_name, item_list, deleted_item_list) {
	var table = getByID(table_id);
	var order_field = getByID(row_name + '_order');
	var order = parseInt(order_field.value);
	var i = order;// - 1; // array index
	table.tBodies[0].removeChild(table.tBodies[0].rows[i]);
	item_list.splice(i, 1);
	for (var j = i; j < item_list.length; j++) {
		order_field = getByID(item_list[j] + '_order');
		order_field.value = parseInt(order_field.value) - 1;
	}
	deleted_item_list[deleted_item_list.length] = row_name;
	frReFlipFlop(table);
}
function frReFlipFlop(table) {
	for (var i = 1; i < table.tBodies[0].rows.length; i++) {
		table.tBodies[0].rows[i].className = (i % 2) ? 'odd' : 'even';
	}
}