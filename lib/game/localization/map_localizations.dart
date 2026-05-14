import 'package:flutter/widgets.dart';

import '../models/territory.dart';

class MapLocalizations {
  const MapLocalizations._();

  static String languageCodeOf(BuildContext context) {
    return Localizations.localeOf(context).languageCode;
  }

  static String territoryName(BuildContext context, Territory territory) {
    final code = languageCodeOf(context);
    return _territoryNames[territory.id]?[code] ?? territory.name;
  }

  static String continentName(BuildContext context, String continent) {
    final code = languageCodeOf(context);
    return _continentNames[continent]?[code] ?? continent;
  }

  static const _continentNames = <String, Map<String, String>>{
    'North America': <String, String>{
      'tr': 'Kuzey Amerika',
      'en': 'North America',
      'de': 'Nordamerika',
    },
    'South America': <String, String>{
      'tr': 'Güney Amerika',
      'en': 'South America',
      'de': 'Südamerika',
    },
    'Europe': <String, String>{'tr': 'Avrupa', 'en': 'Europe', 'de': 'Europa'},
    'Africa': <String, String>{'tr': 'Afrika', 'en': 'Africa', 'de': 'Afrika'},
    'Asia': <String, String>{'tr': 'Asya', 'en': 'Asia', 'de': 'Asien'},
    'Oceania': <String, String>{
      'tr': 'Okyanusya',
      'en': 'Oceania',
      'de': 'Ozeanien',
    },
    'Anatolia': <String, String>{
      'tr': 'Anadolu',
      'en': 'Anatolia',
      'de': 'Anatolien',
    },
  };

  static const _territoryNames = <String, Map<String, String>>{
    'alaska': <String, String>{'tr': 'Alaska', 'en': 'Alaska', 'de': 'Alaska'},
    'western_canada': <String, String>{
      'tr': 'Batı Kanada',
      'en': 'Western Canada',
      'de': 'Westkanada',
    },
    'eastern_canada': <String, String>{
      'tr': 'Doğu Kanada',
      'en': 'Eastern Canada',
      'de': 'Ostkanada',
    },
    'greenland': <String, String>{
      'tr': 'Grönland',
      'en': 'Greenland',
      'de': 'Grönland',
    },
    'western_us': <String, String>{
      'tr': 'Batı ABD',
      'en': 'Western US',
      'de': 'Westliche USA',
    },
    'central_us': <String, String>{
      'tr': 'Orta ABD',
      'en': 'Central US',
      'de': 'Zentrale USA',
    },
    'eastern_us': <String, String>{
      'tr': 'Doğu ABD',
      'en': 'Eastern US',
      'de': 'Östliche USA',
    },
    'mexico': <String, String>{'tr': 'Meksika', 'en': 'Mexico', 'de': 'Mexiko'},
    'central_america_caribbean': <String, String>{
      'tr': 'Orta Amerika ve Karayipler',
      'en': 'Central America and Caribbean',
      'de': 'Mittelamerika und Karibik',
    },
    'northern_south_america': <String, String>{
      'tr': 'Kuzey Güney Amerika',
      'en': 'Northern South America',
      'de': 'Nördliches Südamerika',
    },
    'andes': <String, String>{
      'tr': 'And Dağları',
      'en': 'Andes',
      'de': 'Anden',
    },
    'amazon_basin': <String, String>{
      'tr': 'Amazon Havzası',
      'en': 'Amazon Basin',
      'de': 'Amazonasbecken',
    },
    'brazil': <String, String>{
      'tr': 'Brezilya',
      'en': 'Brazil',
      'de': 'Brasilien',
    },
    'southern_cone': <String, String>{
      'tr': 'Güney Konisi',
      'en': 'Southern Cone',
      'de': 'Südkegel',
    },
    'patagonia': <String, String>{
      'tr': 'Patagonya',
      'en': 'Patagonia',
      'de': 'Patagonien',
    },
    'british_isles': <String, String>{
      'tr': 'Britanya Adaları',
      'en': 'British Isles',
      'de': 'Britische Inseln',
    },
    'scandinavia': <String, String>{
      'tr': 'İskandinavya',
      'en': 'Scandinavia',
      'de': 'Skandinavien',
    },
    'western_europe': <String, String>{
      'tr': 'Batı Avrupa',
      'en': 'Western Europe',
      'de': 'Westeuropa',
    },
    'iberia': <String, String>{'tr': 'İberya', 'en': 'Iberia', 'de': 'Iberien'},
    'central_europe': <String, String>{
      'tr': 'Orta Avrupa',
      'en': 'Central Europe',
      'de': 'Mitteleuropa',
    },
    'italy_balkans': <String, String>{
      'tr': 'İtalya ve Balkanlar',
      'en': 'Italy Balkans',
      'de': 'Italien und Balkan',
    },
    'eastern_europe': <String, String>{
      'tr': 'Doğu Avrupa',
      'en': 'Eastern Europe',
      'de': 'Osteuropa',
    },
    'north_africa': <String, String>{
      'tr': 'Kuzey Afrika',
      'en': 'North Africa',
      'de': 'Nordafrika',
    },
    'west_africa': <String, String>{
      'tr': 'Batı Afrika',
      'en': 'West Africa',
      'de': 'Westafrika',
    },
    'central_africa': <String, String>{
      'tr': 'Orta Afrika',
      'en': 'Central Africa',
      'de': 'Zentralafrika',
    },
    'east_africa': <String, String>{
      'tr': 'Doğu Afrika',
      'en': 'East Africa',
      'de': 'Ostafrika',
    },
    'horn_africa': <String, String>{
      'tr': 'Afrika Boynuzu',
      'en': 'Horn of Africa',
      'de': 'Horn von Afrika',
    },
    'southern_africa': <String, String>{
      'tr': 'Güney Afrika',
      'en': 'Southern Africa',
      'de': 'Südliches Afrika',
    },
    'madagascar': <String, String>{
      'tr': 'Madagaskar',
      'en': 'Madagascar',
      'de': 'Madagaskar',
    },
    'ural_russia': <String, String>{
      'tr': 'Ural Rusyası',
      'en': 'Ural Russia',
      'de': 'Ural-Russland',
    },
    'siberia': <String, String>{
      'tr': 'Sibirya',
      'en': 'Siberia',
      'de': 'Sibirien',
    },
    'far_east_russia': <String, String>{
      'tr': 'Uzak Doğu Rusyası',
      'en': 'Far East Russia',
      'de': 'Fernost-Russland',
    },
    'anatolia': <String, String>{
      'tr': 'Anadolu',
      'en': 'Anatolia',
      'de': 'Anatolien',
    },
    'middle_east': <String, String>{
      'tr': 'Orta Doğu',
      'en': 'Middle East',
      'de': 'Naher Osten',
    },
    'arabia': <String, String>{
      'tr': 'Arabistan',
      'en': 'Arabia',
      'de': 'Arabien',
    },
    'persia': <String, String>{
      'tr': 'İran Platosu',
      'en': 'Persia',
      'de': 'Persien',
    },
    'central_asia': <String, String>{
      'tr': 'Orta Asya',
      'en': 'Central Asia',
      'de': 'Zentralasien',
    },
    'india': <String, String>{'tr': 'Hindistan', 'en': 'India', 'de': 'Indien'},
    'china_north': <String, String>{
      'tr': 'Kuzey Çin',
      'en': 'North China',
      'de': 'Nordchina',
    },
    'china_south': <String, String>{
      'tr': 'Güney Çin',
      'en': 'South China',
      'de': 'Südchina',
    },
    'southeast_asia': <String, String>{
      'tr': 'Güneydoğu Asya',
      'en': 'Southeast Asia',
      'de': 'Südostasien',
    },
    'korea_japan': <String, String>{
      'tr': 'Kore ve Japonya',
      'en': 'Korea Japan',
      'de': 'Korea und Japan',
    },
    'indonesia': <String, String>{
      'tr': 'Endonezya',
      'en': 'Indonesia',
      'de': 'Indonesien',
    },
    'australia_west': <String, String>{
      'tr': 'Batı Avustralya',
      'en': 'West Australia',
      'de': 'Westaustralien',
    },
    'australia_east': <String, String>{
      'tr': 'Doğu Avustralya',
      'en': 'East Australia',
      'de': 'Ostaustralien',
    },
    'new_guinea': <String, String>{
      'tr': 'Yeni Gine',
      'en': 'New Guinea',
      'de': 'Neuguinea',
    },
    'pacific_islands': <String, String>{
      'tr': 'Pasifik Adaları',
      'en': 'Pacific Islands',
      'de': 'Pazifikinseln',
    },
    'new_zealand': <String, String>{
      'tr': 'Yeni Zelanda',
      'en': 'New Zealand',
      'de': 'Neuseeland',
    },
  };
}
