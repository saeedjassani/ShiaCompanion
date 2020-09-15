import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';
import 'package:hijri/hijri_calendar.dart';

import '../constants.dart';

class CalendarPage extends StatefulWidget {
  CalendarPage({Key key}) : super(key: key);

  @override
  _CalendarPageState createState() => new _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  var eventsMap = {};

  String eventString = "";

  DateTime _currentDate = DateTime.now();

  String month1 = formatDate(DateTime.now(), [M, ", ", yyyy]) +
      " / " +
      HijriCalendar.now().toFormat("MMMM, yyyy");
  TextStyle smallText = new TextStyle(fontSize: 11.0);

  _CalendarPageState();

  // @override
  // void initState() {
  //   super.initState();
  //   print("i am called");
  //   _updateEventString().then(() {
  //     setState(() {});
  //   });
  // }

  _updateEventString() async {
    String events = await rootBundle.loadString("assets/events.json");

    List eventsList = json.decode(events);
    for (var event in eventsList) {
      eventsMap[event['date']] = event;
    }

    DateTime now = DateTime.now();
    HijriCalendar _today = HijriCalendar.fromDate(now);
    eventString = _today.toFormat("dd MMMM, yyyy");
    var w = eventsMap[getStringFromDate(_today)];
    if (w != null) eventString += "\n\n" + w['content'];
  }

  @override
  Widget build(BuildContext context) {
    _updateEventString();
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.0),
            child: CalendarCarousel(
              showOnlyCurrentMonthDate: true,
              todayBorderColor: Colors.blue,
              todayButtonColor: Colors.transparent,
              selectedDayBorderColor: Colors.blue[200],
              selectedDayButtonColor: Colors.blue[200],
              thisMonthDayBorderColor: Colors.grey,
              height: screenHeight * 0.58,
              selectedDateTime: _currentDate,
              daysHaveCircularBorder: false,
              headerText: month1,
              headerTextStyle:
                  TextStyle(fontSize: screenWidth * 0.0375, color: Colors.blue),
              onCalendarChanged: (DateTime dateCal) {
                HijriCalendar newDate =
                    HijriCalendar.fromDate(dateCal.add(Duration()));
                setState(() {
                  month1 = formatDate(dateCal, [M, ", ", yyyy]) +
                      " / " +
                      newDate.toFormat("MMMM, yyyy");
                });
              },
              onDayPressed: (DateTime date, List<String> events) {
                HijriCalendar newDate = new HijriCalendar.fromDate(
                    date.add(Duration(days: hijriDate)));

                String tmpDate = getStringFromDate(newDate);
                eventString = newDate.toFormat("dd MMMM, yyyy");
                if (eventsMap != null && eventsMap[tmpDate] != null) {
                  eventString += "\n\n" + eventsMap[tmpDate]['content'];
                }
                setState(() {
                  _currentDate = date;
                });
              },
              customDayBuilder: (
                bool isSelectable,
                int index,
                bool isSelectedDay,
                bool isToday,
                bool isPrevMonthDay,
                TextStyle textStyle,
                bool isNextMonthDay,
                bool isThisMonthDay,
                DateTime day,
              ) {
                HijriCalendar hDate =
                    HijriCalendar.fromDate(day.add(Duration()));

                String tmpDate = getStringFromDate(hDate);

                Color dayColor = Colors.transparent;

                if (eventsMap != null && eventsMap[tmpDate] != null) {
                  dayColor = eventsMap[tmpDate]['color'] == 2
                      ? Colors.green[200]
                      : Colors.red[200];
                }
                // A RenderFlex overflow error occurs when the page is changed (Day views are shrinked, hence causing the error)
                return Container(
                  color: dayColor,
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
                  ),
                );
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
