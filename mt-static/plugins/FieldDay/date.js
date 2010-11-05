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

var fd_calendar = new CalendarPopup();
fd_calendar.setReturnFunction("fd_cal_set");
var fd_cal_field = '';

function fd_cal_switch(field_name) {
    var y_sel = getByID(field_name + '_y');
    var y = y_sel.options[y_sel.selectedIndex].value;
    var m_sel = getByID(field_name + '_m');
    var m = m_sel.options[m_sel.selectedIndex].value;
    var d_sel = getByID(field_name + '_d');
    var d = d_sel.options[d_sel.selectedIndex].value;
    if (y && m && d) {
        fd_calendar.currentDate = new Date(y, m - 1, d);
    } else {
        fd_calendar.currentDate = null;
    }
    fd_cal_field = field_name;
}

function fd_cal_set(y, m, d) {
    fd_set_menu(getByID(fd_cal_field + '_y'), y);
    fd_set_menu(getByID(fd_cal_field + '_m'), m);
    fd_set_menu(getByID(fd_cal_field + '_d'), d);
    fd_calendar.currentDate = new Date(y, m - 1, d);
    fd_date_text(fd_cal_field);
}

function fd_set_menu(menu, value) {
    for (var i = 0; i < menu.options.length; i++) {
        if (menu.options[i].value == value) {
            menu.selectedIndex = i;
            break;
        }
    }
}

function fd_date_menu_change(menu) {
    var field_name = menu.id.replace(/_.$/, '');
    fd_cal_switch(field_name);
    fd_date_text(field_name);
}

function fd_date_text(field_name) {
    var date = fd_calendar.currentDate;
    if (date) {
        var text_fld = getByID(field_name + '_text');
        if (text_fld) {
            text_fld.value = (date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear();
        }
    }
}

function fd_date_text_change(fld) {
    var field_name = fld.id.replace(/_text$/, '');
    var elems = fld.value.split(/[-\/]/);
    var m = parseInt(elems[0]);
    var d = parseInt(elems[1]);
    var y = parseInt(elems[2]);
    if (!y) {
        var now = new Date();
        y = now.getFullYear();
    } else {
        if (y < 100) {
            y = y + 2000;
        }
    }
    var date = new Date(y, m, d);
    fd_cal_field = field_name;
    fd_calendar.currentDate = date;
    fd_cal_set(y, m, d);
}
