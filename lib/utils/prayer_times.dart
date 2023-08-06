/// Created by Anwar Alburai on 1/20/2023
/// Email: anwar.dev.96@gmail.com
// ignore_for_file: non_constant_identifier_names

import 'dart:collection';
import 'dart:math';

class PrayerTime {
  //region Variables
  late int calcMethod; // calculation method
  late int asrJuristic; // Juristic method for Asr
  late int dhuhrMinutes; // minutes after mid-day for Dhuhr
  late int adjustHighLats; // adjusting method for higher latitudes
  late int timeFormat; // time format
  late double lat; // latitude
  late double lng; // longitude
  late double timeZone; // time-zone
  late double JDate; // Julian date

  // Calculation Methods
  late int Jafari; // Ithna Ashari
  late int Karachi; // University of Islamic Sciences, Karachi
  late int ISNA; // Islamic Society of North America (ISNA)
  late int MWL; // Muslim World League (MWL)
  late int Makkah; // Umm al-Qura, Makkah
  late int Egypt; // Egyptian General Authority of Survey
  late int Custom; // Custom Setting
  late int Tehran; // Institute of Geophysics, University of Tehran
  // Juristic Methods
  late int Shafii; // Shafii (standard)
  late int Hanafi; // Hanafi
  // Adjusting Methods for Higher Latitudes
  late int None; // No adjustment
  late int MidNight; // middle of night
  late int OneSeventh; // 1/7th of night
  late int AngleBased; // angle/60th of night
  // Time Formats
  late int Time24; // 24-hour format
  late int Time12; // 12-hour format
  late int Time12NS; // 12-hour format with no suffix
  late int Floating; // floating point number
  // Time Names
  late List<String> timeNames;
  late String InvalidTime; // The string used for invalid times
  //endregion

  //region Technical Setting
  late int numIterations; // number of iterations needed to compute times
  // ------------------- Calc Method Parameters --------------------
  late Map<int, List<double>> methodParams;

  /*
    * this.methodParams[methodNum] = new Array(fa, ms, mv, is, iv);
    * fa : fajr angle
    * ms : maghrib selector (0 = angle; 1 = minutes after sunset)
    * mv : maghrib parameter value (in angle or minutes)
    * is : isha selector (0 = angle; 1 = minutes after maghrib)
    * iv : isha parameter value (in angle or minutes)
    */
  late List<double> prayerTimesCurrent;
  late List<int> offsets;

  PrayerTime() {
    // Initialize vars

    this.setCalcMethod(0);
    this.setAsrJuristic(0);
    this.setDhuhrMinutes(0);
    this.setAdjustHighLats(1);
    this.setTimeFormat(0);

    // Calculation Methods
    this.setJafari(0); // Ithna Ashari
    this.setKarachi(1); // University of Islamic Sciences, Karachi
    this.setISNA(2); // Islamic Society of North America (ISNA)
    this.setMWL(3); // Muslim World League (MWL)
    this.setMakkah(4); // Umm al-Qura, Makkah
    this.setEgypt(5); // Egyptian General Authority of Survey
    this.setTehran(6); // Institute of Geophysics, University of Tehran
    this.setCustom(7); // Custom Setting

    // Juristic Methods
    this.setShafii(0); // Shafii (standard)
    this.setHanafi(1); // Hanafi

    // Adjusting Methods for Higher Latitudes
    this.setNone(0); // No adjustment
    this.setMidNight(1); // middle of night
    this.setOneSeventh(2); // 1/7th of night
    this.setAngleBased(3); // angle/60th of night

    // Time Formats
    this.setTime24(0); // 24-hour format
    this.setTime12(1); // 12-hour format
    this.setTime12NS(2); // 12-hour format with no suffix
    this.setFloating(3); // floating point number

    // Time Names

    timeNames = [
      "Fajr",
      "Sunrise",
      "Dhuhr",
      "Asr",
      "Sunset",
      "Maghrib",
      "Isha"
    ];

    InvalidTime = "-----"; // The string used for invalid times

    //endregion
    //region --------------------- Technical Settings --------------------

    this.setNumIterations(1); // number of iterations needed to compute
    // times

    // ------------------- Calc Method Parameters --------------------

    // Tuning offsets {fajr, sunrise, dhuhr, asr, sunset, maghrib, isha}
    offsets = [0, 0, 0, 0, 0, 0, 0];

    methodParams = HashMap();

    // Jafari
    List<double> Jvalues = [16, 0, 4, 0, 14];
    methodParams.addAll({getJafari(): Jvalues});

    // Karachi
    List<double> Kvalues = [18, 1, 0, 0, 18];
    methodParams.addAll({getKarachi(): Kvalues});

    // ISNA
    List<double> Ivalues = [15, 1, 0, 0, 15];
    methodParams.addAll({getISNA(): Ivalues});

    // MWL
    List<double> MWvalues = [18, 1, 0, 0, 17];
    methodParams.addAll({getMWL(): MWvalues});

    // Makkah
    List<double> MKvalues = [18.5, 1, 0, 1, 90];
    methodParams.addAll({getMakkah(): MKvalues});

    // Egypt
    List<double> Evalues = [19.5, 1, 0, 0, 17.5];
    methodParams.addAll({getEgypt(): Evalues});

    // Tehran
    List<double> Tvalues = [17.7, 0, 4.5, 0, 14];
    methodParams.addAll({getTehran(): Tvalues});

    // Custom
    List<double> Cvalues = [18, 1, 0, 0, 17];
    methodParams.addAll({getCustom(): Cvalues});
  }

  //endregion

  //region Trigonometric
  // range reduce angle in degrees.
  double fixangle(double a) {
    a = a - (360 * ((a / 360.0).floorToDouble()));

    a = a < 0 ? (a + 360) : a;
    return a;
  }

  // range reduce hours to 0..23
  double fixhour(double a) {
    a = a - 24.0 * (a / 24.0).floorToDouble();
    a = a < 0 ? (a + 24) : a;
    return a;
  }

  // radian to degree
  double radiansToDegrees(double alpha) {
    return ((alpha * 180.0) / pi);
  }

  // degrees to radian
  double DegreesToRadians(double alpha) {
    return ((alpha * pi) / 180.0);
  }

  // degree sin
  double dsin(double d) {
    return (sin(DegreesToRadians(d)));
  }

  // degree cos
  double dcos(double d) {
    return (cos(DegreesToRadians(d)));
  }

  // degree tan
  double dtan(double d) {
    return (tan(DegreesToRadians(d)));
  }

  // degree arcsin
  double darcsin(double x) {
    double val = asin(x);
    return radiansToDegrees(val);
  }

  // degree arccos
  double darccos(double x) {
    double val = acos(x);
    return radiansToDegrees(val);
  }

  // degree arctan
  double darctan(double x) {
    double val = atan(x);
    return radiansToDegrees(val);
  }

  // degree arctan2
  double darctan2(double y, double x) {
    double val = atan2(y, x);
    return radiansToDegrees(val);
  }

  // degree arccot
  double darccot(double x) {
    double val = atan2(1.0, x);
    return radiansToDegrees(val);
  }

  //endregion

  //region Julian Date
  // calculate julian date from a calendar date
  double julianDate(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    double A = (year / 100.0).floorToDouble();

    double B = 2 - A + (A / 4.0).floorToDouble();

    double JD = (365.25 * (year + 4716)).floorToDouble() +
        (30.6001 * (month + 1)).floorToDouble() +
        day +
        B -
        1524.5;

    return JD;
  }

  // convert a calendar date to julian date (second method)
  double calcJD(int year, int month, int day) {
    double J1970 = 2440588.0;
    DateTime date = new DateTime(year, month - 1, day);

    int ms = date.millisecond; // # of milliseconds since midnight Jan 1,
    // 1970
    double days = (ms / (1000.0 * 60.0 * 60.0 * 24.0)).floorToDouble();
    return J1970 + days - 0.5;
  }

  //endregion

  //region Calculation
  // References:
  // http://www.ummah.net/astronomy/saltime
  // http://aa.usno.navy.mil/faq/docs/SunApprox.html
  // compute declination angle of sun and equation of time
  List<double> sunPosition(double jd) {
    double D = jd - 2451545;
    double g = fixangle(357.529 + 0.98560028 * D);
    double q = fixangle(280.459 + 0.98564736 * D);
    double L = fixangle(q + (1.915 * dsin(g)) + (0.020 * dsin(2 * g)));

    // double R = 1.00014 - 0.01671 * [self dcos:g] - 0.00014 * [self dcos:
    // (2*g)];
    double e = 23.439 - (0.00000036 * D);
    double d = darcsin(dsin(e) * dsin(L));
    double RA = (darctan2((dcos(e) * dsin(L)), (dcos(L)))) / 15.0;
    RA = fixhour(RA);
    double EqT = q / 15.0 - RA;
    return [d, EqT];
  }

  // compute equation of time
  double equationOfTime(double jd) {
    double eq = sunPosition(jd)[1];
    return eq;
  }

  // compute declination angle of sun
  double sunDeclination(double jd) {
    double d = sunPosition(jd)[0];
    return d;
  }

  // compute mid-day (Dhuhr, Zawal) time
  double computeMidDay(double t) {
    double T = equationOfTime(this.getJDate() + t);
    double Z = fixhour(12 - T);
    return Z;
  }

  // compute time for a given angle G
  double computeTime(double G, double t) {
    double D = sunDeclination(this.getJDate() + t);
    double Z = computeMidDay(t);
    double Beg = -dsin(G) - dsin(D) * dsin(this.getLat());
    double Mid = dcos(D) * dcos(this.getLat());
    double V = darccos(Beg / Mid) / 15.0;

    return Z + (G > 90 ? -V : V);
  }

  // compute the time of Asr
  // Shafii: step=1, Hanafi: step=2
  double computeAsr(double step, double t) {
    double D = sunDeclination(this.getJDate() + t);
    double G = -darccot(step + dtan((this.getLat() - D).abs()));
    return computeTime(G, t);
  }

  //endregion

  //region Misc
  // compute the difference between two times
  double timeDiff(double time1, double time2) {
    return fixhour(time2 - time1);
  }

  //endregion

  //region Interface Functions
  // return prayer times for a given date
  List<String> getDatePrayerTimes(int year, int month, int day, double latitude,
      double longitude, double tZone) {
    this.setLat(latitude);
    this.setLng(longitude);
    this.setTimeZone(tZone);
    this.setJDate(julianDate(year, month, day));
    double lonDiff = longitude / (15.0 * 24.0);
    this.setJDate(this.getJDate() - lonDiff);
    return computeDayTimes();
  }

  // return prayer times for a given date
  List<String> getPrayerTimes(
      DateTime date, double latitude, double longitude, double tZone) {
    int year = date.year;
    int month = date.month;
    int day = date.day;

    return getDatePrayerTimes(year, month, day, latitude, longitude, tZone);
  }

  // set custom values for calculation parameters
  setCustomParams(List<double> params) {
    for (int i = 0; i < 5; i++) {
      if (params[i] == -1) {
        params[i] = mParams[i];
        methodParams.addAll({this.getCustom(): params});
      } else {
        mParams[i] = params[i];
      }
    }
    this.setCalcMethod(this.getCustom());
  }

  //endregion

  //region Parse Time
  // convert double hours to 24h format
  String floatToTime24(double time) {
    String result;

    if (time.isNaN) {
      return InvalidTime;
    }

    time = fixhour(time + 0.5 / 60.0); // add 0.5 minutes to round
    int hours = time.floor();
    double minutes = ((time - hours) * 60).floorToDouble();

    if ((hours >= 0 && hours <= 9) && (minutes >= 0 && minutes <= 9)) {
      result = "0$hours:0${minutes.round()}";
    } else if ((hours >= 0 && hours <= 9)) {
      result = "0$hours:${minutes.round()}";
    } else if ((minutes >= 0 && minutes <= 9)) {
      result = "$hours:0${minutes.round()}";
    } else {
      result = "$hours:${minutes.round()}";
    }
    return result;
  }

  // convert double hours to 12h format
  String floatToTime12(double time, bool noSuffix) {
    if (time.isNaN) {
      return InvalidTime;
    }

    time = fixhour(time + 0.5 / 60); // add 0.5 minutes to round
    int hours = time.floor();
    double minutes = ((time - hours) * 60).floorToDouble();
    String suffix, result;
    if (hours >= 12) {
      suffix = "pm";
    } else {
      suffix = "am";
    }
    hours = ((((hours + 12) - 1) % (12)) + 1);
//        /* hours = (hours + 12) - 1;
//        int hrs = (int) hours % 12;
//        hrs += 1;*/
    if (noSuffix == false) {
      if ((hours >= 0 && hours <= 9) && (minutes >= 0 && minutes <= 9)) {
        result = "0$hours:0${minutes.round()} $suffix";
      } else if ((hours >= 0 && hours <= 9)) {
        result = "0$hours:${minutes.round()} $suffix";
      } else if ((minutes >= 0 && minutes <= 9)) {
        result = "$hours:0${minutes.round()} $suffix";
      } else {
        result = "$hours:${minutes.round()} $suffix";
      }
    } else {
      if ((hours >= 0 && hours <= 9) && (minutes >= 0 && minutes <= 9)) {
        result = "0$hours:0${minutes.round()}";
      } else if ((hours >= 0 && hours <= 9)) {
        result = "0$hours:${minutes.round()}";
      } else if ((minutes >= 0 && minutes <= 9)) {
        result = "$hours:0${minutes.round()}";
      } else {
        result = "$hours:${minutes.round()}";
      }
    }
    return result;
  }

  // convert double hours to 12h format with no suffix
  String floatToTime12NS(double time) {
    return floatToTime12(time, true);
  }

  //endregion

  //region Compute Prayer Times
  // compute prayer times at given julian date
  List<double> computeTimes(List<double> times) {
    List<double> t = dayPortion(times);

    List<double> x = mParams;
    double Fajr = this.computeTime(180.0 - x[0], t[0]);

    double Sunrise = this.computeTime(180 - 0.833, t[1]);

    double Dhuhr = this.computeMidDay(t[2]);
    double Asr = this.computeAsr(1.0 + this.getAsrJuristic(), t[3]);
    double Sunset = this.computeTime(0.833, t[4]);

    double Maghrib = this.computeTime(mParams[2], t[5]);
    double Isha = this.computeTime(mParams[4], t[6]);

    List<double> CTimes = [Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha];

    return CTimes;
  }

  // compute prayer times at given julian date
  List<String> computeDayTimes() {
    List<double> times = [5, 6, 12, 13, 18, 18, 18]; // default times

    for (int i = 1; i <= this.getNumIterations(); i++) {
      times = computeTimes(times);
    }

    times = adjustTimes(times);
    times = tuneTimes(times);

    return adjustTimesFormat(times);
  }

  // adjust times in a prayer time array
  List<double> adjustTimes(List<double> times) {
    for (int i = 0; i < times.length; i++) {
      times[i] += this.getTimeZone() - this.getLng() / 15;
    }

    times[2] += this.getDhuhrMinutes() / 60; // Dhuhr
    if (mParams[1] == 1) // Maghrib
    {
      times[5] = times[4] + mParams[2] / 60;
    }
    if (mParams[3] == 1) // Isha
    {
      times[6] = times[5] + mParams[4] / 60;
    }

    if (this.getAdjustHighLats() != this.getNone()) {
      times = adjustHighLatTimes(times);
    }

    return times;
  }

  // convert times array to given time format
  List<String> adjustTimesFormat(List<double> times) {
    List<String> result = List.of([]);

    if (this.getTimeFormat() == this.getFloating()) {
      for (var time in times) {
        result.add(time.toString());
      }
      return result;
    }

    for (int i = 0; i < 7; i++) {
      if (this.getTimeFormat() == this.getTime12()) {
        result.add(floatToTime12(times[i], false));
      } else if (this.getTimeFormat() == this.getTime12NS()) {
        result.add(floatToTime12(times[i], true));
      } else {
        result.add(floatToTime24(times[i]));
      }
    }
    return result;
  }

  // adjust Fajr, Isha and Maghrib for locations in higher latitudes
  List<double> adjustHighLatTimes(List<double> times) {
    double nightTime = timeDiff(times[4], times[1]); // sunset to sunrise

    // Adjust Fajr
    double FajrDiff = nightPortion(mParams[0]) * nightTime;

    if (times[0].isNaN || timeDiff(times[0], times[1]) > FajrDiff) {
      times[0] = times[1] - FajrDiff;
    }

    // Adjust Isha
    double IshaAngle = (mParams[3] == 0) ? mParams[4] : 18;
    double IshaDiff = this.nightPortion(IshaAngle) * nightTime;
    if (times[6].isNaN || this.timeDiff(times[4], times[6]) > IshaDiff) {
      times[6] = times[4] + IshaDiff;
    }

    // Adjust Maghrib
    double MaghribAngle = (mParams[1] == 0) ? mParams[2] : 4;
    double MaghribDiff = nightPortion(MaghribAngle) * nightTime;
    if (times[5].isNaN || this.timeDiff(times[4], times[5]) > MaghribDiff) {
      times[5] = times[4] + MaghribDiff;
    }

    return times;
  }

  // the night portion used for adjusting times in higher latitudes
  double nightPortion(double angle) {
    double calc = 0;

    if (adjustHighLats == AngleBased)
      calc = (angle) / 60.0;
    else if (adjustHighLats == MidNight)
      calc = 0.5;
    else if (adjustHighLats == OneSeventh) calc = 0.14286;

    return calc;
  }

  // convert hours to day portions
  List<double> dayPortion(List<double> times) {
    for (int i = 0; i < 7; i++) {
      times[i] /= 24;
    }
    return times;
  }

  // Tune timings for adjustments
  // Set time offsets
  tune(List<int> offsetTimes) {
    for (int i = 0; i < offsetTimes.length; i++) {
      // offsetTimes length
      // should be 7 in order
      // of Fajr, Sunrise,
      // Dhuhr, Asr, Sunset,
      // Maghrib, Isha
      this.offsets[i] = offsetTimes[i];
    }
  }

  List<double> tuneTimes(List<double> times) {
    for (int i = 0; i < times.length; i++) {
      times[i] = times[i] + this.offsets[i] / 60.0;
    }

    return times;
  }

  //endregion

  //region Get & Set
  int getCalcMethod() {
    return calcMethod;
  }

  List<double> get mParams => methodParams[this.getCalcMethod()]!;

  void setCalcMethod(int calcMethod) {
    this.calcMethod = calcMethod;
  }

  int getAsrJuristic() {
    return asrJuristic;
  }

  void setAsrJuristic(int asrJuristic) {
    this.asrJuristic = asrJuristic;
  }

  int getDhuhrMinutes() {
    return dhuhrMinutes;
  }

  void setDhuhrMinutes(int dhuhrMinutes) {
    this.dhuhrMinutes = dhuhrMinutes;
  }

  int getAdjustHighLats() {
    return adjustHighLats;
  }

  void setAdjustHighLats(int adjustHighLats) {
    this.adjustHighLats = adjustHighLats;
  }

  int getTimeFormat() {
    return timeFormat;
  }

  void setTimeFormat(int timeFormat) {
    this.timeFormat = timeFormat;
  }

  double getLat() {
    return lat;
  }

  void setLat(double lat) {
    this.lat = lat;
  }

  double getLng() {
    return lng;
  }

  void setLng(double lng) {
    this.lng = lng;
  }

  double getTimeZone() {
    return timeZone;
  }

  void setTimeZone(double timeZone) {
    this.timeZone = timeZone;
  }

  double getJDate() {
    return JDate;
  }

  void setJDate(double jDate) {
    JDate = jDate;
  }

  int getJafari() {
    return Jafari;
  }

  void setJafari(int jafari) {
    Jafari = jafari;
  }

  int getKarachi() {
    return Karachi;
  }

  void setKarachi(int karachi) {
    Karachi = karachi;
  }

  int getISNA() {
    return ISNA;
  }

  void setISNA(int iSNA) {
    ISNA = iSNA;
  }

  int getMWL() {
    return MWL;
  }

  void setMWL(int mWL) {
    MWL = mWL;
  }

  int getMakkah() {
    return Makkah;
  }

  void setMakkah(int makkah) {
    Makkah = makkah;
  }

  int getEgypt() {
    return Egypt;
  }

  void setEgypt(int egypt) {
    Egypt = egypt;
  }

  int getCustom() {
    return Custom;
  }

  void setCustom(int custom) {
    Custom = custom;
  }

  int getTehran() {
    return Tehran;
  }

  void setTehran(int tehran) {
    Tehran = tehran;
  }

  int getShafii() {
    return Shafii;
  }

  void setShafii(int shafii) {
    Shafii = shafii;
  }

  int getHanafi() {
    return Hanafi;
  }

  void setHanafi(int hanafi) {
    Hanafi = hanafi;
  }

  int getNone() {
    return None;
  }

  void setNone(int none) {
    None = none;
  }

  int getMidNight() {
    return MidNight;
  }

  void setMidNight(int midNight) {
    MidNight = midNight;
  }

  int getOneSeventh() {
    return OneSeventh;
  }

  void setOneSeventh(int oneSeventh) {
    OneSeventh = oneSeventh;
  }

  int getAngleBased() {
    return AngleBased;
  }

  void setAngleBased(int angleBased) {
    AngleBased = angleBased;
  }

  int getTime24() {
    return Time24;
  }

  void setTime24(int time24) {
    Time24 = time24;
  }

  int getTime12() {
    return Time12;
  }

  void setTime12(int time12) {
    Time12 = time12;
  }

  int getTime12NS() {
    return Time12NS;
  }

  void setTime12NS(int time12ns) {
    Time12NS = time12ns;
  }

  int getFloating() {
    return Floating;
  }

  void setFloating(int floating) {
    Floating = floating;
  }

  int getNumIterations() {
    return numIterations;
  }

  void setNumIterations(int numIterations) {
    this.numIterations = numIterations;
  }

  List<String> getTimeNames() {
    return timeNames;
  }

//endregion
}
