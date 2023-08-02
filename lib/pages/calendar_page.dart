import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/widgets/prayer_times_card.dart';
import 'package:table_calendar/table_calendar.dart';

import '../constants.dart';

class CalendarPage extends StatefulWidget {
  final bool shouldScroll;
  CalendarPage(this.shouldScroll);

  @override
  _CalendarPageState createState() => new _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  var eventsMap = {};

  String eventString = "";

  TextStyle smallText = new TextStyle(fontSize: 11.0);

  late ScrollController scrollController;

  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();
    _updateEventString();
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _updateEventString() async {
    String events = await rootBundle.loadString("assets/events.json");

    eventsMap = json.decode(events);

    selectedDay = DateTime.now().add(Duration(days: hijriDate));
    HijriCalendar _today = HijriCalendar.fromDate(selectedDay!);
    eventString = _today.toFormat("dd MMMM, yyyy");
    var w = eventsMap[getStringFromDate(_today)];
    if (w != null) eventString += "\n\n" + w['content'];
    if (this.mounted) setState(() {});
  }

  _scrollToEnd() async {
    scrollController.animateTo(scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 500), curve: Curves.ease);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shouldScroll)
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        children: <Widget>[
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2000, 1, 11),
              lastDay: DateTime.utc(2050, 12, 31),
              focusedDay: selectedDay ?? DateTime.now(),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekendStyle: TextStyle(color: const Color(0xFF616161)),
              ),
              headerStyle: HeaderStyle(
                  titleTextStyle: TextStyle(fontSize: 14),
                  titleTextFormatter: (date, locale) {
                    String month1;
                    HijriCalendar newDate = HijriCalendar.fromDate(
                        date.add(Duration(days: hijriDate)));
                    month1 = formatDate(date, [M, ", ", yyyy]) +
                        " / " +
                        newDate.toFormat("MMMM, yyyy");
                    return month1;
                  },
                  formatButtonVisible: false,
                  titleCentered: true),
              calendarBuilders: CalendarBuilders(
                prioritizedBuilder:
                    (BuildContext context, DateTime day, events) {
                  HijriCalendar hDate = HijriCalendar.fromDate(
                      day.add(Duration(days: hijriDate)));

                  String tmpDate = getStringFromDate(hDate);
                  Color? dayColor = Colors.transparent;

                  if (eventsMap[tmpDate] != null) {
                    dayColor = eventsMap[tmpDate]['color'] == 0
                        ? Colors.green[200]
                        : Colors.red[200];
                  }
                  if (this.isToday(day) && dayColor == Colors.transparent) {
                    dayColor = Colors.blue[200];
                  }
                  return Container(
                      margin: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                          color: dayColor,
                          border: Border.all(
                              width: selectedDay == day ? 2.0 : 1.0,
                              color: selectedDay == day
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
              onDaySelected: (DateTime date, DateTime _) {
                HijriCalendar newDate =
                    HijriCalendar.fromDate(date.add(Duration(days: hijriDate)));

                String tmpDate = getStringFromDate(newDate);
                eventString = newDate.toFormat("dd MMMM, yyyy");
                if (eventsMap[tmpDate] != null) {
                  eventString += "\n\n" + eventsMap[tmpDate]['content'];
                }
                selectedDay = date;
                setState(() {});
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              eventString,
              key: ValueKey("cal-key"),
              textAlign: TextAlign.center,
            ),
          ),
          selectedDay != null
              ? PrayerTimesCard(
                  date: selectedDay!,
                )
              : Container(),
        ],
      ),
    );
  }

  String getStringFromDate(HijriCalendar dateTime) {
    List<String> temp = dateTime.toString().split('/');
    return int.parse(temp[0]).toString() + '-' + int.parse(temp[1]).toString();
  }

  bool isToday(DateTime dateTime) {
    DateTime now = DateTime.now();

    // Compare day, month, and year components to check if it's today
    return dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year;
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
