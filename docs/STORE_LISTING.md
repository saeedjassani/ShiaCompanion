# Store listing - 4.0

Listing text for the App Store and Google Play, per language, and the plan for
the screenshots each language shows. Field limits are checked by
`python3 scripts/store_screenshots/check_listing.py` (characters, except the
App Store's keywords, which count UTF-8 bytes).

Translations follow the app's own wording (`lib/l10n/app_<code>.arb`): the
same word for Duas, Ziyarats, Qaza, My Stats and so on as the app's menus.
**Have a native speaker read each language before it goes live** - especially
the religious terms.

## Which languages go where

| Language | App Store | Google Play |
| --- | --- | --- |
| English | en-US (primary) | en-US (primary) |
| Arabic | ar-SA | ar |
| Urdu | ur | ur |
| Persian | **not offered** - Persian-speaking iPhones see the English page | fa-IR |
| Gujarati | gu | gu |

The App Store added Urdu and Gujarati in 2026; it has no Persian. Play has all
four.

## What the screenshots show in each language

Same ten slides, same layouts, same order - each captured with the app in that
language (`openApp`'s `locale`), with the captions translated. What changes is
what the app can actually show in that language:

| Slide | English | Arabic | Urdu | Persian (Play only) | Gujarati |
| --- | --- | --- | --- | --- | --- |
| 01 light & dark | Home | Home in Arabic | Home in Urdu | Home in Persian | Home in Gujarati |
| 02 reader | Kumayl, English | Kumayl, Arabic only (the reader hides translation in Arabic) | Kumayl with Urdu | Kumayl, Arabic only (no Persian dua translations yet) | Kumayl with Gujarati |
| 03 languages | the four languages | same | same | same | same |
| 04 Quran | Ya-Sin, English | Ya-Sin, Arabic only | Ya-Sin, Urdu | Ya-Sin, Persian | Ya-Sin, Gujarati |
| 05 listen | playlists + player | in Arabic | in Urdu | in Persian | in Gujarati |
| 06 My Stats | | in Arabic | in Urdu | in Persian | in Gujarati |
| 07 calendar | | in Arabic | in Urdu | in Persian | in Gujarati |
| 08 tools | | in Arabic | in Urdu | in Persian | in Gujarati |
| 09 duas (App Store) | Kumayl in Urdu | Ziyarat Ashura, Arabic | Ziyarat Ashura with Urdu | Ziyarat Ashura, Arabic (Play has no slot 9) | Ziyarat Ashura, Arabic |
| 10 library (App Store) | | - | - | - | - |

Rules behind the table:

- **Lead with the language itself.** On a localized page slide 03 says
  "now in Urdu", in Urdu - the reason someone opens that page.
- **Never promise a translation the app doesn't have.** Persian and Arabic
  have no dua translations, so their slide 09 shows what they do get. Urdu
  says "famous duas", not "all duas".
- **No Library slide outside English.** Its books are all in English.
- **Slide 09 is Ziyarat Ashura everywhere but English**, so Urdu and
  Gujarati don't show Kumayl twice: with its Urdu translation in Urdu, and as
  Arabic text, under a caption that promises nothing more, elsewhere.

## English

### App Store

**Name** (30)
```
Shia Companion
```

**Subtitle** (30)
```
Prayer times, duas & ziyarats
```

**Promotional text** (170)
```
New in 4.0: a fresh design, the whole app in Urdu, Persian, Arabic and Gujarati, Quran translations, My Stats, and Hijri dates from the moon where you are.
```

**Keywords** (100 bytes)
```
dua,ziyarat,quran,qibla,azan,namaz,hijri,tasbeeh,qaza,kumayl,ashura,mafatih,muharram,ramazan
```

**Description** (4000)
```
Everything a follower of the Ahlul Bayt (a.s.) reaches for each day, in one calm, ad-free app.

PRAYER TIMES AND AZAN
• Accurate prayer times for where you are, worked out on your phone, even offline
• Azan at each prayer time, with your choice of reciter
• Prayer times in flight, for every prayer along your route
• Qibla finder with a live compass

DUAS, ZIYARATS AND THE QURAN
• Hundreds of duas, ziyarats, munajaat and taqibaat, with Arabic, translation and transliteration
• Listen to recitations, play a whole playlist, or download them for offline
• The Quran with translations in English, Urdu, Persian and Gujarati
• Keep a Khatm, add notes to any verse, and pick up where you left off
• Bookmark the line you stopped at; auto-scroll reads with you

NEW IN 4.0
• A fresh design, in light and dark
• The whole app in Urdu, Persian, Arabic and Gujarati
• Famous duas translated into Urdu, and Dua Kumayl into Gujarati - missing one? Request it in the app
• My Stats: your daily streak, zikrs, verses and qaza made up
• Hijri months that start from the crescent as seen where you live

EVERY DAY
• Today's duas and ziyarat, and the hadith of the day
• Hijri calendar with the Islamic events of each month
• Tasbeeh counter, rakaat counter and qaza tracker
• A library of over a thousand books
• Home screen widgets and Apple Watch

Free, with no ads. Spotted a mistake in a text? Select it to report it.
```

**What's New** (4000)
```
Shia Companion 4.0 is our biggest update yet.

• A fresh design throughout, in light and dark
• The app in Urdu, Persian, Arabic and Gujarati
• Quran translations in Urdu, Persian and Gujarati, notes on verses, and Khatm tracking
• Famous duas translated into Urdu; Dua Kumayl in Gujarati
• My Stats: streaks, recitations and qaza progress
• Hijri dates from the moon sighting where you are
• Auto-scroll in the reader, and a first-run setup

Jazakallah to everyone who sent corrections and requests.
```

### Google Play

**Title** (30)
```
Shia Companion: Duas & Quran
```

**Short description** (80)
```
Prayer times, duas, ziyarats & Quran - now in Urdu, Persian, Arabic, Gujarati
```

**Full description** (4000): the App Store description above, with "Home
screen widgets and Apple Watch" changed to "Home screen widgets".

**Release notes** (500)
```
Shia Companion 4.0, our biggest update yet:
• A fresh design, in light and dark
• The app in Urdu, Persian, Arabic and Gujarati
• Quran translations, notes on verses and Khatm tracking
• Famous duas translated into Urdu; Dua Kumayl in Gujarati
• My Stats: streaks, recitations and qaza progress
• Hijri dates from the moon sighting where you are
```

### Screenshot captions

| Slide | Caption | Callouts |
| --- | --- | --- |
| 01 | Prayer times, duas and Quran in one app | - |
| 02 | Read and understand every dua | Arabic + translation / Bookmark a line / Auto-scroll |
| 03 | Now in Urdu, Persian, Arabic and Gujarati | - |
| 04 | The Quran, with your own Khatm | Translated / Notes on any verse / Track every Khatm |
| 05 | Listen to duas, or a whole playlist | - |
| 06 | Keep up your daily recitation | Daily streaks / Zikrs, verses, qaza |
| 07 | Hijri dates from the moon where you are | Islamic events / Prayer times |
| 08 | Qibla, tasbeeh and qaza tracker | - |
| 09 | Famous duas, translated | Kumayl, Nudba, Tawassul / Gujarati too / Missing one? |
| 10 | A library of over a thousand books | 1,162 books / Request a book |

## Arabic - العربية

### App Store

**Name**
```
Shia Companion
```

**Subtitle**
```
أدعية وزيارات ومواقيت الصلاة
```

**Promotional text**
```
الجديد في 4.0: تصميم جديد، والتطبيق كاملاً بالعربية والأردية والفارسية والغوجاراتية، وإحصائياتي، وبداية الأشهر الهجرية من رؤية الهلال في مدينتك.
```

**Keywords**
```
دعاء,زيارة,قرآن,قبلة,أذان,صلاة,تسبيح,قضاء,كميل,عاشوراء
```

**Description**
```
كل ما يحتاجه محبّو أهل البيت (ع) كل يوم، في تطبيق واحد هادئ وبلا إعلانات.

مواقيت الصلاة والأذان
• مواقيت صلاة دقيقة لمكانك، تُحسب على هاتفك حتى دون اتصال
• الأذان في وقت كل صلاة، بصوت القارئ الذي تختاره
• مواقيت الصلاة في الطائرة على طول مسار رحلتك
• تحديد القبلة ببوصلة حيّة

الأدعية والزيارات والقرآن
• مئات الأدعية والزيارات والمناجاة والتعقيبات
• استمع إلى التلاوات، أو شغّل قائمة كاملة، أو نزّلها للاستماع دون اتصال
• القرآن الكريم مع إمكان متابعة الختمة وإضافة ملاحظة على أي آية
• ضع إشارة على السطر الذي توقفت عنده، والتمرير التلقائي يقرأ معك

الجديد في 4.0
• تصميم جديد بالوضعين الفاتح والداكن
• التطبيق كاملاً بالعربية والأردية والفارسية والغوجاراتية
• إحصائياتي: أيام المواظبة، والأذكار، والآيات، والقضاء
• بداية الأشهر الهجرية من رؤية الهلال حيث تعيش

كل يوم
• أدعية اليوم وزيارته، وحديث اليوم
• التقويم الهجري مع مناسبات كل شهر
• عدّاد التسبيح، وعدّاد الركعات، ومتابعة صلوات القضاء
• مكتبة تضم أكثر من ألف كتاب (بالإنجليزية)
• أدوات للشاشة الرئيسية وساعة Apple

مجاني وبلا إعلانات. وجدت خطأ في نص؟ حدّده للإبلاغ عنه.
```

**What's New**
```
Shia Companion 4.0 هو أكبر تحديث حتى الآن:
• تصميم جديد بالكامل، بالوضعين الفاتح والداكن
• التطبيق بالعربية والأردية والفارسية والغوجاراتية
• ملاحظات على الآيات ومتابعة الختمة
• إحصائياتي: أيام المواظبة والتلاوات والقضاء
• بداية الأشهر الهجرية من رؤية الهلال في مدينتك
• التمرير التلقائي في القارئ

جزاكم الله خيراً على كل تصحيح واقتراح.
```

### Google Play

**Title**
```
Shia Companion: أدعية وقرآن
```

**Short description**
```
مواقيت الصلاة والأدعية والزيارات والقرآن، بالعربية والأردية والفارسية
```

**Full description**: the App Store description above, with "أدوات للشاشة
الرئيسية وساعة Apple" changed to "أدوات للشاشة الرئيسية".

**Release notes**: the What's New above.

### Screenshot captions

| Slide | Caption | Callouts |
| --- | --- | --- |
| 01 | مواقيت الصلاة والأدعية والقرآن في تطبيق واحد | - |
| 02 | اقرأ كل دعاء وتدبّره | النص العربي / ضع إشارة على سطر / التمرير التلقائي |
| 03 | الآن بالعربية والأردية والفارسية والغوجاراتية | - |
| 04 | القرآن الكريم، مع ختمتك الخاصة | ملاحظات على أي آية / تابع كل ختمة |
| 05 | استمع إلى الأدعية، أو إلى قائمة كاملة | - |
| 06 | واظب على تلاوتك اليومية | أيام المواظبة / الأذكار والآيات والقضاء |
| 07 | الأشهر الهجرية من رؤية الهلال حيث أنت | المناسبات الإسلامية / مواقيت الصلاة |
| 08 | القبلة والتسبيح ومتابعة القضاء | - |
| 09 | زيارة عاشوراء وأكثر | مئات الأدعية والزيارات |

## Urdu - اردو

### App Store

**Name**
```
Shia Companion
```

**Subtitle**
```
نماز کے اوقات، دعائیں، زیارات
```

**Promotional text**
```
ورژن 4.0 میں نیا: نیا ڈیزائن، پوری ایپ اردو، فارسی، عربی اور گجراتی میں، قرآن کا اردو ترجمہ، مشہور دعاؤں کا اردو ترجمہ، اور میرے اعداد و شمار۔
```

**Keywords**
```
دعا,زیارت,قرآن,قبلہ,اذان,نماز,تسبیح,قضا,کمیل,عاشورہ
```

**Description**
```
محبانِ اہلِ بیت (ع) کی روزمرہ ضرورت کی ہر چیز، ایک پُرسکون اور اشتہارات سے پاک ایپ میں۔

نماز کے اوقات اور اذان
• آپ کے مقام کے مطابق نماز کے درست اوقات، فون پر ہی حساب، انٹرنیٹ کے بغیر بھی
• ہر نماز کے وقت اذان، اپنے پسندیدہ مؤذن کی آواز میں
• پرواز میں نماز: سفر کے راستے پر ہر نماز کا وقت
• زندہ قطب نما کے ساتھ قبلہ

دعائیں، زیارات اور قرآن
• سیکڑوں دعائیں، زیارات، مناجات اور تعقیبات، عربی متن، ترجمہ کے ساتھ
• تلاوت سنیں، پوری پلے لسٹ چلائیں، یا آف لائن کے لیے ڈاؤن لوڈ کریں
• قرآن مجید کا اردو ترجمہ
• ختم کا حساب رکھیں، کسی بھی آیت پر نوٹ لکھیں، اور وہیں سے پڑھیں جہاں چھوڑا تھا
• جس سطر پر رکے اسے بک مارک کریں؛ خودکار اسکرول آپ کے ساتھ پڑھتا ہے

ورژن 4.0 میں نیا
• نیا ڈیزائن، روشن اور تاریک دونوں انداز میں
• پوری ایپ اردو، فارسی، عربی اور گجراتی میں
• مشہور دعاؤں کا اردو ترجمہ: کمیل، ندبہ، توسل، زیارت عاشورہ، حدیث کساء اور مزید - کوئی دعا نہیں ملی؟ ایپ میں ترجمے کی درخواست کریں
• میرے اعداد و شمار: روزانہ کا تسلسل، اذکار، آیات اور ادا شدہ قضا
• ہجری مہینے آپ کے شہر سے چاند دیکھنے کے مطابق

ہر روز
• آج کی دعائیں اور زیارت، اور آج کی حدیث
• ہجری کیلنڈر، ہر مہینے کی مناسبتوں کے ساتھ
• تسبیح، رکعات کا شمار اور قضا نمازوں کا حساب
• ایک ہزار سے زیادہ کتابوں کی لائبریری (انگریزی میں)
• ہوم اسکرین ویجیٹس اور Apple Watch

مفت، بغیر اشتہارات کے۔ کسی متن میں غلطی نظر آئی؟ اسے منتخب کر کے اطلاع دیں۔
```

**What's New**
```
Shia Companion 4.0 ہماری اب تک کی سب سے بڑی اپ ڈیٹ ہے:
• پوری ایپ میں نیا ڈیزائن، روشن اور تاریک انداز میں
• ایپ اردو، فارسی، عربی اور گجراتی میں
• قرآن کا اردو ترجمہ، آیات پر نوٹس اور ختم کا حساب
• مشہور دعاؤں کا اردو ترجمہ
• میرے اعداد و شمار: تسلسل، تلاوت اور قضا
• ہجری تاریخیں آپ کے شہر سے چاند دیکھنے کے مطابق

تصحیح اور تجاویز بھیجنے والے سب کا شکریہ۔ جزاک اللہ۔
```

### Google Play

**Title**
```
Shia Companion: دعا اور قرآن
```

**Short description**
```
نماز کے اوقات، دعائیں، زیارات اور قرآن - اب اردو ترجمے کے ساتھ
```

**Full description**: the App Store description above, with "ہوم اسکرین
ویجیٹس اور Apple Watch" changed to "ہوم اسکرین ویجیٹس".

**Release notes**: the What's New above.

### Screenshot captions

| Slide | Caption | Callouts |
| --- | --- | --- |
| 01 | نماز کے اوقات، دعائیں اور قرآن ایک ایپ میں | - |
| 02 | ہر دعا پڑھیں اور سمجھیں | عربی + اردو ترجمہ / سطر بک مارک کریں / خودکار اسکرول |
| 03 | اب اردو، فارسی، عربی اور گجراتی میں | - |
| 04 | قرآن مجید، آپ کے اپنے ختم کے ساتھ | اردو ترجمہ / کسی بھی آیت پر نوٹ / ہر ختم کا حساب |
| 05 | دعائیں سنیں، یا پوری پلے لسٹ | - |
| 06 | روزانہ کی تلاوت جاری رکھیں | روزانہ کا تسلسل / اذکار، آیات، قضا |
| 07 | ہجری تاریخیں آپ کے شہر کے چاند سے | اسلامی مناسبتیں / نماز کے اوقات |
| 08 | قبلہ، تسبیح اور قضا کا حساب | - |
| 09 | مشہور دعائیں، اردو ترجمے کے ساتھ (Ziyarat Ashura) | دعائے کمیل، ندبہ، توسل / کوئی دعا نہیں ملی؟ |

## Persian - فارسی (Google Play only)

**Title**
```
Shia Companion: دعا و قرآن
```

**Short description**
```
اوقات شرعی، دعاها، زیارت‌ها و قرآن - اکنون به زبان فارسی
```

**Full description**
```
هر آنچه دوستداران اهل بیت (ع) هر روز به آن نیاز دارند، در یک برنامهٔ آرام و بدون تبلیغات.

اوقات شرعی و اذان
• اوقات شرعی دقیق برای مکان شما، محاسبه‌شده روی گوشی، حتی بدون اینترنت
• اذان در وقت هر نماز، با صدای مؤذنی که انتخاب می‌کنید
• نماز در پرواز: وقت هر نماز در طول مسیر سفر
• قبله‌نما با قطب‌نمای زنده

دعاها، زیارت‌ها و قرآن
• صدها دعا، زیارت، مناجات و تعقیبات
• تلاوت‌ها را بشنوید، یک فهرست پخش کامل را پخش کنید، یا برای پخش بدون اینترنت دانلود کنید
• قرآن کریم با ترجمهٔ فارسی آیت‌الله مکارم شیرازی
• ختم قرآن را دنبال کنید، روی هر آیه یادداشت بگذارید، و از همان‌جا که ماندید ادامه دهید
• سطری را که در آن ماندید نشانه‌گذاری کنید؛ پیمایش خودکار همراه شما می‌خواند

تازه‌های نسخهٔ 4.0
• طراحی تازه، در حالت روشن و تیره
• تمام برنامه به فارسی، اردو، عربی و گجراتی
• آمار من: روزهای پیوسته، اذکار، آیات و قضای به‌جاآورده
• آغاز ماه‌های قمری بر اساس رؤیت هلال در شهر شما

هر روز
• دعاها و زیارت امروز، و حدیث روز
• تقویم قمری با مناسبت‌های هر ماه
• تسبیح‌شمار، شمارندهٔ رکعات و حساب نمازهای قضا
• کتابخانه‌ای با بیش از هزار کتاب (به انگلیسی)
• ویجت‌های صفحهٔ اصلی

رایگان و بدون تبلیغات. اشتباهی در متنی دیدید؟ آن را انتخاب کنید و گزارش دهید.
```

**Release notes**
```
Shia Companion 4.0، بزرگ‌ترین به‌روزرسانی تا امروز:
• طراحی تازه، در حالت روشن و تیره
• برنامه به فارسی، اردو، عربی و گجراتی
• ترجمهٔ فارسی قرآن، یادداشت روی آیات و پیگیری ختم
• آمار من: روزهای پیوسته، تلاوت‌ها و قضا
• آغاز ماه‌های قمری بر اساس رؤیت هلال در شهر شما
```

### Screenshot captions

| Slide | Caption | Callouts |
| --- | --- | --- |
| 01 | اوقات شرعی، دعاها و قرآن در یک برنامه | - |
| 02 | هر دعا را بخوانید | متن عربی / نشانه‌گذاری سطر / پیمایش خودکار |
| 03 | اکنون به فارسی، اردو، عربی و گجراتی | - |
| 04 | قرآن کریم، با ختم خودتان | ترجمهٔ فارسی / یادداشت روی هر آیه / پیگیری هر ختم |
| 05 | دعاها را بشنوید، یا یک فهرست کامل | - |
| 06 | تلاوت روزانه را ادامه دهید | روزهای پیوسته / اذکار، آیات، قضا |
| 07 | ماه‌های قمری از رؤیت هلال در شهر شما | مناسبت‌های اسلامی / اوقات شرعی |
| 08 | قبله، تسبیح و حساب قضا | - |
| 09 | زیارت عاشورا و صدها دعای دیگر (not used: Play has 8 slots) | صدها دعا و زیارت |

## Gujarati - ગુજરાતી

### App Store

**Name**
```
Shia Companion
```

**Subtitle**
```
નમાઝના સમય, દુઆઓ, ઝિયારતો
```

**Promotional text**
```
4.0 માં નવું: નવી ડિઝાઇન, આખી એપ ગુજરાતી, ઉર્દૂ, ફારસી અને અરબીમાં, કુરઆનનો ગુજરાતી અનુવાદ, દુઆએ કુમૈલ ગુજરાતીમાં, અને મારા આંકડા.
```

**Keywords**
```
દુઆ,ઝિયારત,કુરઆન,કિબલા,નમાઝ,dua,quran
```

**Description**
```
અહલેબૈત (અ.સ.)ને ચાહનારાઓને રોજ જે જોઈએ તે બધું, એક શાંત અને જાહેરાત વગરની એપમાં.

નમાઝના સમય અને અઝાન
• તમારા સ્થાન માટે નમાઝના સાચા સમય, ફોન પર જ ગણતરી, ઇન્ટરનેટ વગર પણ
• દરેક નમાઝના સમયે અઝાન, તમે પસંદ કરેલા અવાજમાં
• ફ્લાઇટમાં નમાઝ: મુસાફરીના રસ્તે દરેક નમાઝનો સમય
• જીવંત હોકાયંત્ર સાથે કિબલા

દુઆઓ, ઝિયારતો અને કુરઆન
• સેંકડો દુઆઓ, ઝિયારતો, મુનાજાત અને તઅકીબાત
• તિલાવત સાંભળો, આખી પ્લેલિસ્ટ ચલાવો, અથવા ઑફલાઇન માટે ડાઉનલોડ કરો
• કુરઆનનો ગુજરાતી અનુવાદ
• ખત્મનો હિસાબ રાખો, કોઈ પણ આયત પર નોંધ લખો, અને જ્યાં અટક્યા ત્યાંથી આગળ વાંચો
• દુઆએ કુમૈલ ગુજરાતી અનુવાદ સાથે - કોઈ દુઆ ન મળી? એપમાં અનુવાદની વિનંતી કરો

4.0 માં નવું
• નવી ડિઝાઇન, લાઇટ અને ડાર્ક બંનેમાં
• આખી એપ ગુજરાતી, ઉર્દૂ, ફારસી અને અરબીમાં
• મારા આંકડા: રોજનો સિલસિલો, ઝિક્ર, આયતો અને અદા કરેલી કઝા
• હિજરી મહિના તમારા શહેરમાં ચાંદ દેખાવાના આધારે

દરરોજ
• આજની દુઆઓ અને ઝિયારત, અને આજની હદીસ
• હિજરી કેલેન્ડર, દરેક મહિનાના પ્રસંગો સાથે
• તસ્બીહ, રકાતની ગણતરી અને કઝા નમાઝનો હિસાબ
• હજારથી વધુ પુસ્તકોની લાઇબ્રેરી (અંગ્રેજીમાં)
• હોમ સ્ક્રીન વિજેટ્સ અને Apple Watch

મફત, જાહેરાત વગર. કોઈ લખાણમાં ભૂલ દેખાઈ? તેને પસંદ કરીને જણાવો.
```

**What's New**
```
Shia Companion 4.0 અમારું અત્યાર સુધીનું સૌથી મોટું અપડેટ:
• આખી એપમાં નવી ડિઝાઇન, લાઇટ અને ડાર્કમાં
• એપ ગુજરાતી, ઉર્દૂ, ફારસી અને અરબીમાં
• કુરઆનનો ગુજરાતી અનુવાદ, આયતો પર નોંધ અને ખત્મનો હિસાબ
• દુઆએ કુમૈલ ગુજરાતીમાં
• મારા આંકડા: સિલસિલો, તિલાવત અને કઝા
• હિજરી તારીખો તમારા શહેરમાં ચાંદ દેખાવાના આધારે
```

### Google Play

**Title**
```
Shia Companion: દુઆ અને કુરઆન
```

**Short description**
```
નમાઝના સમય, દુઆઓ, ઝિયારતો અને કુરઆન - હવે ગુજરાતીમાં
```

**Full description**: the App Store description above, with "હોમ સ્ક્રીન
વિજેટ્સ અને Apple Watch" changed to "હોમ સ્ક્રીન વિજેટ્સ".

**Release notes**: the What's New above.

### Screenshot captions

| Slide | Caption | Callouts |
| --- | --- | --- |
| 01 | નમાઝના સમય, દુઆઓ અને કુરઆન એક જ એપમાં | - |
| 02 | દરેક દુઆ વાંચો અને સમજો | અરબી + ગુજરાતી અનુવાદ / લાઇન બુકમાર્ક કરો / ઑટો-સ્ક્રોલ |
| 03 | હવે ગુજરાતી, ઉર્દૂ, ફારસી અને અરબીમાં | - |
| 04 | કુરઆન, તમારા પોતાના ખત્મ સાથે | ગુજરાતી અનુવાદ / કોઈ પણ આયત પર નોંધ / દરેક ખત્મનો હિસાબ |
| 05 | દુઆઓ સાંભળો, અથવા આખી પ્લેલિસ્ટ | - |
| 06 | રોજની તિલાવત ચાલુ રાખો | રોજનો સિલસિલો / ઝિક્ર, આયતો, કઝા |
| 07 | હિજરી તારીખો તમારા શહેરના ચાંદથી | ઇસ્લામી પ્રસંગો / નમાઝના સમય |
| 08 | કિબલા, તસ્બીહ અને કઝાનો હિસાબ | - |
| 09 | ઝિયારતે આશૂરા અને સેંકડો દુઆઓ | સેંકડો દુઆઓ અને ઝિયારતો / અનુવાદ નથી મળ્યો? |
