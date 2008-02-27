var fd_calendar = new CalendarPopup();
fd_calendar.setReturnFunction("fd_cal_set");
var fd_cal_field = '';
function fd_cal_switch(field_name) {
	var y_sel = getByID(field_name + '_y');
	var y = y_sel.options[y_sel.selectedIndex].value;
	var m_sel = getByID(field_name + '_m');
	var m = m_sel.options[m_sel.selectedIndex].value - 1;
	var d_sel = getByID(field_name + '_d');
	var d = d_sel.options[d_sel.selectedIndex].value;
	if (y && m && d) {
		fd_calendar.currentDate = new Date(y, m, d);
	} else {
		fd_calendar.currentDate = new Date();		
	}
	fd_cal_field = field_name;
}
function fd_cal_set(y, m, d) {
	fd_set_menu(getByID(fd_cal_field + '_y'), y);
	fd_set_menu(getByID(fd_cal_field + '_m'), m);
	fd_set_menu(getByID(fd_cal_field + '_d'), d);
}
function fd_set_menu(menu, value) {
	for (var i = 0; i < menu.options.length; i++) {
		if (menu.options[i].value == value) {
			menu.selectedIndex = i;
			break;
		}
	}
}
