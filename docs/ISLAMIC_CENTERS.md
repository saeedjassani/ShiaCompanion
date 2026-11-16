# Islamic centers

Most people who install the app go to one local center (a mosque,
imambargah or Islamic center), and nearly every center keeps its programs
(majalis, Dua Kumayl, classes, Eid prayers) on a Google Calendar. This
feature brings that calendar into the app:

- **Home suggests the nearest center.** Someone who follows no center and
  is within 50 km of one in the directory sees "Programs at {center}" on
  Home, with Follow and Not now. Not now hides the card for good.
- **Following a center pulls in its calendar.** Home then shows that
  center's next two programs. The **Center Programs** page lists the next
  60 days, day by day. Each program opens a sheet with the time, the place
  (with Directions), the center's description, any links in it (a live
  stream, a sign-up form) and Share.
- **Any center can be added by its link.** "Add a calendar by link" takes
  a Google Calendar ID, its public or embed link, or any `.ics` / `webcal://`
  address (Outlook, iCloud). A switch, on by default, also files the center
  as a content request (type `center`), so an admin can add it to the
  directory for everyone nearby.

## How it works

| Piece | Where |
| --- | --- |
| iCalendar parser and recurrence expansion | `lib/utils/ics_calendar.dart` |
| Center model, calendar link -> feed URL | `lib/models/islamic_center.dart` |
| Directory, followed centers, cached programs, the suggestion | `lib/services/islamic_center_service.dart` |
| Center Programs page, directory page, event sheet | `lib/pages/centers/` |
| Home card | `lib/pages/home/center_card.dart` |
| Admin directory editor | `lib/pages/admin/center_directory_admin_page.dart` |

- **The directory is one Firestore doc**, `islamic_centers/directory`, with
  a `centers` array of `{id, name, calendar, city, lat, lng, address,
  website}`. One read per install per day at most. Anyone can read it and
  only an admin can write it (`firestore.rules`). Admins edit it in the app:
  *Centers Directory* in the admin menu. Each center there has a **Test
  calendar** button that fetches the feed and reports how many programs it
  found, or why it failed.
- **Calendars are read straight from the device.** There is no server or
  API key. A Google calendar is read from its public iCal feed
  (`calendar.google.com/calendar/ical/<id>/public/basic.ics`), which only
  answers once the calendar is public (Settings -> the calendar -> Access
  permissions -> *Make available to public*, with *See all event
  details*). The web build goes through the same CORS proxy as News.
- **Recurring programs are expanded on the device.** Supported:
  DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL, COUNT, UNTIL, BYDAY (with
  ordinals such as "the last Friday"), BYMONTHDAY, BYMONTH, BYSETPOS,
  EXDATE, RDATE, moved or cancelled single dates (RECURRENCE-ID) and
  cancelled events. Times repeat in the event's own time zone, so a weekly
  8 pm program stays at 8 pm across a clock change. Feeds are parsed off
  the UI isolate, since an old calendar can be several MB.
- **Everything is cached in SharedPreferences**: the followed centers, the
  directory, and each center's next 60 days. The page opens at once and
  works offline. A calendar is fetched again when its copy is over 3 hours
  old, when Home or the page opens, or on Refresh. A failed fetch keeps
  the old programs and says why ("isn't public", "couldn't reach").
- Following is per device: it is not synced to the account.

Analytics: `center_followed` (source: `home_suggestion`, `directory` or
`link`), `center_unfollowed`, `center_suggestion_dismissed`,
`center_event_opened`, `center_event_shared`; screens `Center Programs`
and `Center Directory`.

## Shipping it

The feature is **admin-only** for now. `centerProgramsEnabled` in
`islamic_center_service.dart` returns `isUserAdmin`. While it does, the
menu item, the Home card and the shortcuts all stay hidden from everyone
else. To ship:

1. Deploy `firestore.rules`. It adds `islamic_centers` and the `center`
   request type.
2. Add the first centers in *Centers Directory*, with coordinates, and
   check each with Test calendar.
3. On a phone, check:
   - following a center from Home;
   - a real calendar's recurring programs and their times;
   - Directions and Share;
   - a private calendar's message;
   - adding a center by its link.
4. Make `centerProgramsEnabled` return `true` and move
   `centerProgramsMenuItem` into `homeMenuItems`, after Calendar. Then add
   a What's New note.

## Ideas for later

- **Reminders.** A per-program "Remind me" (an hour before), or a
  notification when a followed center adds a program. Both would build on
  `flutter_local_notifications`, as the zikr reminders do.
- **Add to my calendar**, through an `.ics` file or the device calendar.
- **Sync followed centers** with the signed-in account, as the other
  synced managers do.
- **Center details**: the website, a live-stream link and the next Friday
  prayer, on a small page per center.
- **A link a center can share** (`/center/<id>`) that opens the app on its
  page with Follow, for posters and WhatsApp groups.
- **The Programs page as a tab of Calendar & Prayer Times.**
