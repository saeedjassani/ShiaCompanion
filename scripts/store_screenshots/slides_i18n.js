'use strict';
// The localized slide sets: same layouts and order as English (build.js),
// captions from docs/STORE_LISTING.md, captured with the app in that language
// (capture.js with STORE_LANG). There is no Library slide: its books are in
// English. Persian has no App Store page, so it only fills Play.
//
// Slide 09 shows what the language really has: Ziyarat Ashura with Urdu
// translation, and in Arabic, Persian and Gujarati - which have no translation
// of it - the Arabic text, under a caption that promises no more than that.

const RTL = new Set(['ar', 'ur', 'fa']);

// Slide 03's side devices show their outer halves, so a right-to-left Home
// goes on the right, where its text starts.
const LANGUAGE_PEEK = {
  ar: ['home-gu', 'home-l', 'home-ur'],
  ur: ['home-gu', 'home-l', 'home-ar'],
  fa: ['home-gu', 'home-l', 'home-ar'],
  gu: ['home-en', 'home-l', 'home-ur'],
};

const TEXT = {
  ar: {
    badge: 'جديد في 4.0',
    tagline: 'الأدعية والزيارات والقرآن ومواقيت الصلاة، الآن بالعربية',
    c: [
      ['مواقيت الصلاة والأدعية\nوالقرآن في تطبيق واحد'],
      ['اقرأ كل دعاء\nوتدبّره', [['النص العربي', 'سطراً بسطر'], ['ضع إشارة على سطر', 'وتابع من حيث توقفت'],
                                  ['التمرير التلقائي', 'قراءة دون لمس']]],
      ['الآن بالعربية والأردية\nوالفارسية والغوجاراتية'],
      ['القرآن الكريم،\nمع ختمتك الخاصة', [['ملاحظات على أي آية', null], ['تابع كل ختمة', 'وتابع من حيث توقفت']]],
      ['استمع إلى الأدعية،\nأو إلى قائمة كاملة'],
      ['واظب على\nتلاوتك اليومية', [['أيام المواظبة', null], ['الأذكار والآيات والقضاء', null]]],
      ['الأشهر الهجرية من\nرؤية الهلال حيث أنت', [['المناسبات الإسلامية', null], ['مواقيت الصلاة', 'لأي يوم ولأي مدينة']]],
      ['القبلة والتسبيح\nومتابعة القضاء'],
      ['زيارة عاشوراء\nوأكثر', [['مئات الأدعية والزيارات', null]]],
    ],
    tablet: ['الأدعية والزيارات والقرآن،\nبالوضعين الفاتح والداكن', 'القبلة والتسبيح،\nفي متناول يدك'],
  },
  ur: {
    badge: 'ورژن 4.0 میں نیا',
    tagline: 'دعائیں، زیارات، قرآن اور نماز کے اوقات، اب اردو میں',
    c: [
      ['نماز کے اوقات، دعائیں\nاور قرآن ایک ایپ میں'],
      ['ہر دعا پڑھیں\nاور سمجھیں', [['عربی + اردو ترجمہ', 'سطر بہ سطر'], ['سطر بک مارک کریں', 'وہیں سے پڑھیں جہاں چھوڑا'],
                                    ['خودکار اسکرول', null]]],
      ['اب اردو، فارسی،\nعربی اور گجراتی میں'],
      ['قرآن مجید، آپ کے\nاپنے ختم کے ساتھ', [['اردو ترجمہ', null], ['کسی بھی آیت پر نوٹ', null], ['ہر ختم کا حساب', null]]],
      ['دعائیں سنیں،\nیا پوری پلے لسٹ'],
      ['روزانہ کی تلاوت\nجاری رکھیں', [['روزانہ کا تسلسل', null], ['اذکار، آیات، قضا', null]]],
      ['ہجری تاریخیں آپ کے\nشہر کے چاند سے', [['اسلامی مناسبتیں', null], ['نماز کے اوقات', null]]],
      ['قبلہ، تسبیح اور\nقضا کا حساب'],
      ['مشہور دعائیں،\nاردو ترجمے کے ساتھ', [['دعائے کمیل، ندبہ، توسل', 'زیارت عاشورا، حدیث کساء…'],
                                             ['کوئی دعا نہیں ملی؟', 'ایپ میں ترجمے کی درخواست کریں']]],
    ],
    tablet: ['دعائیں، زیارات اور قرآن،\nروشن اور تاریک انداز میں', 'قبلہ اور تسبیح،\nہمیشہ ساتھ'],
  },
  fa: {
    badge: 'تازه در 4.0',
    tagline: 'دعاها، زیارت‌ها، قرآن و اوقات شرعی، اکنون به فارسی',
    c: [
      ['اوقات شرعی، دعاها\nو قرآن در یک برنامه'],
      ['هر دعا را\nبخوانید', [['متن عربی', 'سطر به سطر'], ['نشانه‌گذاری سطر', 'از همان‌جا که ماندید'],
                             ['پیمایش خودکار', null]]],
      ['اکنون به فارسی، اردو،\nعربی و گجراتی'],
      ['قرآن کریم،\nبا ختم خودتان', [['ترجمهٔ فارسی', 'آیت‌الله مکارم شیرازی'], ['یادداشت روی هر آیه', null],
                                    ['پیگیری هر ختم', null]]],
      ['دعاها را بشنوید،\nیا یک فهرست کامل'],
      ['تلاوت روزانه را\nادامه دهید', [['روزهای پیوسته', null], ['اذکار، آیات، قضا', null]]],
      ['ماه‌های قمری از رؤیت\nهلال در شهر شما', [['مناسبت‌های اسلامی', null], ['اوقات شرعی', null]]],
      ['قبله، تسبیح\nو حساب قضا'],
      ['زیارت عاشورا\nو صدها دعای دیگر', [['صدها دعا و زیارت', null]]],
    ],
    tablet: ['دعاها، زیارت‌ها و قرآن،\nدر حالت روشن و تیره', 'قبله و تسبیح،\nهمیشه همراه شما'],
  },
  gu: {
    badge: '4.0 માં નવું',
    tagline: 'દુઆઓ, ઝિયારતો, કુરઆન અને નમાઝના સમય, હવે ગુજરાતીમાં',
    c: [
      ['નમાઝના સમય, દુઆઓ અને\nકુરઆન એક જ એપમાં'],
      ['દરેક દુઆ વાંચો\nઅને સમજો', [['અરબી + ગુજરાતી અનુવાદ', 'દુઆએ કુમૈલ'], ['લાઇન બુકમાર્ક કરો', 'જ્યાં અટક્યા ત્યાંથી'],
                                   ['ઑટો-સ્ક્રોલ', null]]],
      ['હવે ગુજરાતી, ઉર્દૂ,\nફારસી અને અરબીમાં'],
      ['કુરઆન, તમારા\nપોતાના ખત્મ સાથે', [['ગુજરાતી અનુવાદ', null], ['કોઈ પણ આયત પર નોંધ', null],
                                          ['દરેક ખત્મનો હિસાબ', null]]],
      ['દુઆઓ સાંભળો,\nઅથવા આખી પ્લેલિસ્ટ'],
      ['રોજની તિલાવત\nચાલુ રાખો', [['રોજનો સિલસિલો', null], ['ઝિક્ર, આયતો, કઝા', null]]],
      ['હિજરી તારીખો તમારા\nશહેરના ચાંદથી', [['ઇસ્લામી પ્રસંગો', null], ['નમાઝના સમય', null]]],
      ['કિબલા, તસ્બીહ અને\nકઝાનો હિસાબ'],
      ['ઝિયારતે આશૂરા\nઅને સેંકડો દુઆઓ', [['સેંકડો દુઆઓ અને ઝિયારતો', null],
                                          ['અનુવાદ નથી મળ્યો?', 'એપમાં વિનંતી કરો']]],
    ],
    tablet: ['દુઆઓ, ઝિયારતો અને કુરઆન,\nલાઇટ અને ડાર્કમાં', 'કિબલા અને તસ્બીહ,\nહંમેશાં સાથે'],
  },
};

function slidesFor(lang) {
  const t = TEXT[lang];
  const s = (i, extra) => ({caption: t.c[i][0], callouts: t.c[i][1], ...extra});
  const tools = RTL.has(lang) ? ['qibla-d', 'tasbeeh-l', 'qaza-d'] : ['qaza-d', 'tasbeeh-l', 'qibla-d'];
  const phone = [
    s(0, {name: '01-light-dark', layout: 'fan', shots: ['home-l', 'home-d'], badge: t.badge}),
    s(1, {name: '02-reader', layout: 'tilt', shots: ['read-l']}),
    s(2, {name: '03-languages', layout: 'peek', shots: LANGUAGE_PEEK[lang]}),
    s(3, {name: '04-quran', layout: 'tilt', shots: ['quran-d']}),
    s(4, {name: '05-listen', layout: 'fan', shots: ['playlists-l', 'player-d']}),
    s(5, {name: '06-stats', layout: 'tilt', shots: ['stats-l']}),
    s(6, {name: '07-calendar', layout: 'tilt', shots: ['calendar-d']}),
    s(7, {name: '08-tools', layout: 'peek', shots: tools}),
  ];
  const phoneExtra = [s(8, {name: '09-ashura', layout: 'tilt', shots: ['ashura-d']})];
  const tablet = [
    {name: '01-reader', layout: 'fan', shots: ['read-l', 'read-d'], badge: t.badge, caption: t.tablet[0]},
    s(3, {name: '02-quran', layout: 'tilt', shots: ['quran-d']}),
    s(6, {name: '03-calendar', layout: 'tilt', shots: ['calendar-d']}),
    s(5, {name: '04-stats', layout: 'tilt', shots: ['stats-l']}),
    s(4, {name: '05-listen', layout: 'tilt', shots: ['playlists-l']}),
    {name: '06-tools', layout: 'fan', shots: ['qibla-d', 'tasbeeh-l'], caption: t.tablet[1]},
  ].map((x) => ({...x, lang}));
  return {
    phone: phone.map((x) => ({...x, lang})),
    phoneExtra: phoneExtra.map((x) => ({...x, lang})),
    tablet,
    tagline: t.tagline,
    appStore: lang !== 'fa',
  };
}

module.exports = {slidesFor, RTL};
