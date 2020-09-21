import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:table_calendar/table_calendar.dart';

import '../constants.dart';

class CalendarPage extends StatefulWidget {
  CalendarPage({Key key}) : super(key: key);

  @override
  _CalendarPageState createState() => new _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  var eventsMap = {};

  String eventString = "";

  TextStyle smallText = new TextStyle(fontSize: 11.0);

  CalendarController _calendarController;

  _CalendarPageState();

  @override
  void initState() {
    super.initState();
    _updateEventString();
    _calendarController = CalendarController();
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  _updateEventString() async {
    String events = await rootBundle.loadString("assets/events.json");

    eventsMap = json.decode(events);

    DateTime now = DateTime.now();
    HijriCalendar _today = HijriCalendar.fromDate(now);
    eventString = _today.toFormat("dd MMMM, yyyy");
    var w = eventsMap[getStringFromDate(_today)];
    if (w != null) eventString += "\n\n" + w['content'];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.0),
            child: TableCalendar(
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendStyle: TextStyle(),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekendStyle: TextStyle(color: const Color(0xFF616161)),
              ),
              headerStyle: HeaderStyle(
                  titleTextStyle: TextStyle(fontSize: 14),
                  titleTextBuilder: (date, locale) {
                    String month1;
                    HijriCalendar newDate =
                        HijriCalendar.fromDate(date.add(Duration()));
                    month1 = formatDate(date, [M, ", ", yyyy]) +
                        " / " +
                        newDate.toFormat("MMMM, yyyy");
                    return month1;
                  },
                  formatButtonVisible: false,
                  centerHeaderTitle: true),
              builders: CalendarBuilders(
                dayBuilder: (context, day, events) {
                  HijriCalendar hDate =
                      HijriCalendar.fromDate(day.add(Duration()));

                  String tmpDate = getStringFromDate(hDate);
                  Color dayColor = Colors.transparent;

                  if (eventsMap != null && eventsMap[tmpDate] != null) {
                    dayColor = eventsMap[tmpDate]['color'] == 0
                        ? Colors.green[200]
                        : Colors.red[200];
                  }
                  if (_calendarController.isToday(day) &&
                      dayColor == Colors.transparent)
                    dayColor = Colors.blue[200];
                  return Container(
                      margin: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                          color: dayColor,
                          border: Border.all(
                              color: _calendarController.isSelected(day)
                                  ? Colors.blue
                                  : Colors.grey)),
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              day.day.toString(),
                              style: smallText,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              convertNumberToUrdu(hDate.hDay.toString()),
                              style: smallText,
                            ),
                          ),
                        ],
                      ));
                },
              ),
              calendarController: _calendarController,
              onDaySelected: (date, events) {
                HijriCalendar newDate = new HijriCalendar.fromDate(
                    date.add(Duration(days: hijriDate)));

                String tmpDate = getStringFromDate(newDate);
                eventString = newDate.toFormat("dd MMMM, yyyy");
                if (eventsMap != null && eventsMap[tmpDate] != null) {
                  eventString += "\n\n" + eventsMap[tmpDate]['content'];
                }
                setState(() {});
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              eventString,
              textAlign: TextAlign.center,
            ),
          )
        ],
      ),
    );
  }

  String getStringFromDate(HijriCalendar dateTime) {
    List<String> temp = dateTime.toString().split('/');
    return int.parse(temp[0]).toString() + '-' + int.parse(temp[1]).toString();
  }
}

String convertNumberToUrdu(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  for (int i = 0; i < english.length; i++) {
    input = input.replaceAll(english[i], farsi[i]);
  }
  return input;
}
