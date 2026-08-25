import '../utils/geo_utils.dart';

/// A place the compass can point at.
///
/// Coordinates are of the shrine or mosque itself rather than the city centre.
/// The distinction is invisible in the bearing — a few hundred metres at a
/// thousand kilometres is thousandths of a degree — but it is what the label
/// claims, so it is what is stored.
class HolySite {
  const HolySite({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.location,
    this.arabicName,
  });

  /// Stable key for persisting the user's last selection. Never derived from
  /// [name], so the saved choice survives a wording change.
  final String id;

  final String name;
  final String? arabicName;
  final String city;
  final String country;
  final GeoPoint location;

  /// `Najaf, Iraq`, for the one-line subtitle under the name.
  String get place => '$city, $country';
}

/// The Kaaba — the qibla itself, and the default target.
///
/// Held separately because it is not one option among many: it is the direction
/// of prayer, and every other entry is a "while you're here" extra.
const HolySite kaaba = HolySite(
  id: 'kaaba',
  name: 'Kaaba',
  arabicName: 'ٱلْكَعْبَة',
  city: 'Makkah',
  country: 'Saudi Arabia',
  location: GeoPoint(kaabaLatitude, kaabaLongitude),
);

/// Shrines and mosques the compass can point at, after the qibla.
///
/// Ordered the way a Shia user would expect to scan them — the Prophet's
/// mosque, then the shrines of the Imams by seniority of the Imam buried
/// there, then the remaining ziyarat destinations.
const List<HolySite> otherHolySites = [
  HolySite(
    id: 'masjid_an_nabawi',
    name: 'Masjid an-Nabawi',
    arabicName: 'ٱلْمَسْجِد ٱلنَّبَوِي',
    city: 'Madinah',
    country: 'Saudi Arabia',
    location: GeoPoint(24.4672, 39.6112),
  ),
  HolySite(
    id: 'jannat_al_baqi',
    name: 'Jannat al-Baqi',
    arabicName: 'جَنَّة ٱلْبَقِيع',
    city: 'Madinah',
    country: 'Saudi Arabia',
    location: GeoPoint(24.4671, 39.6142),
  ),
  HolySite(
    id: 'imam_ali_najaf',
    name: 'Shrine of Imam Ali',
    arabicName: 'حَرَم ٱلْإِمَام عَلِيّ',
    city: 'Najaf',
    country: 'Iraq',
    location: GeoPoint(32.0297, 44.3145),
  ),
  HolySite(
    id: 'imam_husayn_karbala',
    name: 'Shrine of Imam Husayn',
    arabicName: 'حَرَم ٱلْإِمَام ٱلْحُسَيْن',
    city: 'Karbala',
    country: 'Iraq',
    location: GeoPoint(32.6165, 44.0325),
  ),
  HolySite(
    id: 'abbas_karbala',
    name: 'Shrine of Abbas',
    arabicName: 'حَرَم ٱلْعَبَّاس',
    city: 'Karbala',
    country: 'Iraq',
    location: GeoPoint(32.6167, 44.0346),
  ),
  HolySite(
    id: 'kadhimiya',
    name: 'Kadhimiya Shrine',
    arabicName: 'حَرَم ٱلْكَاظِمَيْن',
    city: 'Baghdad',
    country: 'Iraq',
    location: GeoPoint(33.3797, 44.3383),
  ),
  HolySite(
    id: 'imam_reza_mashhad',
    name: 'Shrine of Imam Reza',
    arabicName: 'حَرَم ٱلْإِمَام ٱلرِّضَا',
    city: 'Mashhad',
    country: 'Iran',
    location: GeoPoint(36.2880, 59.6157),
  ),
  HolySite(
    id: 'al_askari_samarra',
    name: 'Al-Askari Shrine',
    arabicName: 'حَرَم ٱلْعَسْكَرِيَّيْن',
    city: 'Samarra',
    country: 'Iraq',
    location: GeoPoint(34.1986, 43.8739),
  ),
  HolySite(
    id: 'fatima_masuma_qum',
    name: 'Shrine of Fatima Masuma',
    arabicName: 'حَرَم فَاطِمَة ٱلْمَعْصُومَة',
    city: 'Qum',
    country: 'Iran',
    location: GeoPoint(34.6419, 50.8786),
  ),
  HolySite(
    id: 'jamkaran',
    name: 'Jamkaran Mosque',
    arabicName: 'مَسْجِد جَمْكَرَان',
    city: 'Qum',
    country: 'Iran',
    location: GeoPoint(34.5836, 50.9536),
  ),
  HolySite(
    id: 'sayyida_zaynab',
    name: 'Shrine of Sayyida Zaynab',
    arabicName: 'حَرَم ٱلسَّيِّدَة زَيْنَب',
    city: 'Damascus',
    country: 'Syria',
    location: GeoPoint(33.4436, 36.3413),
  ),
  HolySite(
    id: 'sayyida_ruqayya',
    name: 'Shrine of Sayyida Ruqayya',
    arabicName: 'حَرَم ٱلسَّيِّدَة رُقَيَّة',
    city: 'Damascus',
    country: 'Syria',
    location: GeoPoint(33.5136, 36.3053),
  ),
  HolySite(
    id: 'masjid_al_aqsa',
    name: 'Masjid al-Aqsa',
    arabicName: 'ٱلْمَسْجِد ٱلْأَقْصَىٰ',
    city: 'Jerusalem',
    country: 'Palestine',
    location: GeoPoint(31.7761, 35.2358),
  ),
  HolySite(
    id: 'masjid_al_kufa',
    name: 'Masjid al-Kufa',
    arabicName: 'مَسْجِد ٱلْكُوفَة',
    city: 'Kufa',
    country: 'Iraq',
    location: GeoPoint(32.0286, 44.4008),
  ),
  HolySite(
    id: 'sahla',
    name: 'Masjid al-Sahla',
    arabicName: 'مَسْجِد ٱلسَّهْلَة',
    city: 'Kufa',
    country: 'Iraq',
    location: GeoPoint(32.0000, 44.4028),
  ),
];

/// Everything the picker offers, qibla first.
const List<HolySite> allHolySites = [kaaba, ...otherHolySites];

/// The site saved under [id], or the Kaaba when the id is unknown — a renamed
/// or removed entry falls back to the qibla rather than to nothing.
HolySite holySiteById(String? id) {
  if (id == null) return kaaba;
  for (final site in allHolySites) {
    if (site.id == id) return site;
  }
  return kaaba;
}
