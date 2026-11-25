import 'package:mprs_android/model/country_code_model.dart';

class CountryUtils {
  static List<String> getAllCountries() {
  return [
  "Afghanistan",
  "Albania",
  "Algeria",
  "Andorra",
  "Angola",
  "Antigua and Barbuda",
  "Argentina",
  "Armenia",
  "Australia",
  "Austria",
  "Azerbaijan",
  "Bahamas",
  "Bahrain",
  "Bangladesh",
  "Barbados",
  "Belarus",
  "Belgium",
  "Belize",
  "Benin",
  "Bhutan",
  "Bolivia",
  "Bosnia and Herzegovina",
  "Botswana",
  "Brazil",
  "Brunei",
  "Bulgaria",
  "Burkina Faso",
  "Burundi",
  "Cabo Verde",
  "Cambodia",
  "Cameroon",
  "Canada",
  "Central African Republic",
  "Chad",
  "Chile",
  "China",
  "Colombia",
  "Comoros",
  "Congo, Democratic Republic of the",
  "Congo, Republic of the",
  "Costa Rica",
  "Croatia",
  "Cuba",
  "Cyprus",
  "Czech Republic",
  "Denmark",
  "Djibouti",
  "Dominica",
  "Dominican Republic",
  "Ecuador",
  "Egypt",
  "El Salvador",
  "Equatorial Guinea",
  "Eritrea",
  "Estonia",
  "Eswatini",
  "Ethiopia",
  "Fiji",
  "Finland",
  "France",
  "Gabon",
  "Gambia",
  "Georgia",
  "Germany",
  "Ghana",
  "Greece",
  "Grenada",
  "Guatemala",
  "Guinea",
  "Guinea-Bissau",
  "Guyana",
  "Haiti",
  "Honduras",
  "Hungary",
  "Iceland",
  "India",
  "Indonesia",
  "Iran",
  "Iraq",
  "Ireland",
  "Israel",
  "Italy",
  "Jamaica",
  "Japan",
  "Jordan",
  "Kazakhstan",
  "Kenya",
  "Kiribati",
  "Kuwait",
  "Kyrgyzstan",
  "Laos",
  "Latvia",
  "Lebanon",
  "Lesotho",
  "Liberia",
  "Libya",
  "Liechtenstein",
  "Lithuania",
  "Luxembourg",
  "Madagascar",
  "Malawi",
  "Malaysia",
  "Maldives",
  "Mali",
  "Malta",
  "Marshall Islands",
  "Mauritania",
  "Mauritius",
  "Mexico",
  "Micronesia",
  "Moldova",
  "Monaco",
  "Mongolia",
  "Montenegro",
  "Morocco",
  "Mozambique",
  "Myanmar (Burma)",
  "Namibia",
  "Nauru",
  "Nepal",
  "Netherlands",
  "New Zealand",
  "Nicaragua",
  "Niger",
  "Nigeria",
  "North Korea",
  "North Macedonia",
  "Norway",
  "Oman",
  "Pakistan",
  "Palau",
  "Palestine",
  "Panama",
  "Papua New Guinea",
  "Paraguay",
  "Peru",
  "Philippines",
  "Poland",
  "Portugal",
  "Qatar",
  "Romania",
  "Russia",
  "Rwanda",
  "Saint Kitts and Nevis",
  "Saint Lucia",
  "Saint Vincent and the Grenadines",
  "Samoa",
  "San Marino",
  "Sao Tome and Principe",
  "Saudi Arabia",
  "Senegal",
  "Serbia",
  "Seychelles",
  "Sierra Leone",
  "Singapore",
  "Slovakia",
  "Slovenia",
  "Solomon Islands",
  "Somalia",
  "South Africa",
  "South Korea",
  "South Sudan",
  "Spain",
  "Sri Lanka",
  "Sudan",
  "Suriname",
  "Sweden",
  "Switzerland",
  "Syria",
  "Taiwan",
  "Tajikistan",
  "Tanzania",
  "Thailand",
  "Timor-Leste",
  "Togo",
  "Tonga",
  "Trinidad and Tobago",
  "Tunisia",
  "Turkey",
  "Turkmenistan",
  "Tuvalu",
  "Uganda",
  "Ukraine",
  "United Arab Emirates",
  "United Kingdom",
  "United States of America",
  "Uruguay",
  "Uzbekistan",
  "Vanuatu",
  "Vatican City",
  "Venezuela",
  "Vietnam",
  "Yemen",
  "Zambia",
  "Zimbabwe",
  ];

  }


  /// Indian states/UTs for Salesforce salesperson lookup (`state` query param).
  static List<String> getIndianStates() {
    return const [
      'Andhra Pradesh',
      'Arunachal Pradesh',
      'Assam',
      'Bihar',
      'Chhattisgarh',
      'Goa',
      'Gujarat',
      'Haryana',
      'Himachal Pradesh',
      'Jharkhand',
      'Karnataka',
      'Kerala',
      'Madhya Pradesh',
      'Maharashtra',
      'Manipur',
      'Meghalaya',
      'Mizoram',
      'Nagaland',
      'Odisha',
      'Punjab',
      'Rajasthan',
      'Sikkim',
      'Tamil Nadu',
      'Telangana',
      'Tripura',
      'Uttar Pradesh',
      'Uttarakhand',
      'West Bengal',
      'Andaman and Nicobar Islands',
      'Chandigarh',
      'Dadra and Nagar Haveli and Daman and Diu',
      'Delhi',
      'Jammu and Kashmir',
      'Ladakh',
      'Lakshadweep',
      'Puducherry',
    ];
  }

  static List<String> getRegion() {
    return [
      "Africa",
      "Asia",
      "Europe",
      "North America",
      "South America",
      "Central America",
      "Caribbean",
      "Oceania",
      "Middle East",
      "Central Asia",
      "East Asia",
      "South Asia",
      "Southeast Asia",
      "Western Asia",
      "Northern Europe",
      "Southern Europe",
      "Eastern Europe",
      "Western Europe",
      "Northern Africa",
      "Sub-Saharan Africa",
      "Australia & New Zealand",
      "Melanesia",
      "Micronesia",
      "Polynesia",
    ];
  }

  static final List<CountryCodeModel> countryCodesList = [
    CountryCodeModel(name: "Afghanistan", code: "AF", dialCode: "+93", flag: "🇦🇫"),
    CountryCodeModel(name: "Albania", code: "AL", dialCode: "+355", flag: "🇦🇱"),
    CountryCodeModel(name: "Algeria", code: "DZ", dialCode: "+213", flag: "🇩🇿"),
    CountryCodeModel(name: "Argentina", code: "AR", dialCode: "+54", flag: "🇦🇷"),
    CountryCodeModel(name: "Australia", code: "AU", dialCode: "+61", flag: "🇦🇺"),
    CountryCodeModel(name: "Austria", code: "AT", dialCode: "+43", flag: "🇦🇹"),
    CountryCodeModel(name: "Bangladesh", code: "BD", dialCode: "+880", flag: "🇧🇩"),
    CountryCodeModel(name: "Belgium", code: "BE", dialCode: "+32", flag: "🇧🇪"),
    CountryCodeModel(name: "Brazil", code: "BR", dialCode: "+55", flag: "🇧🇷"),
    CountryCodeModel(name: "Canada", code: "CA", dialCode: "+1", flag: "🇨🇦"),
    CountryCodeModel(name: "China", code: "CN", dialCode: "+86", flag: "🇨🇳"),
    CountryCodeModel(name: "Denmark", code: "DK", dialCode: "+45", flag: "🇩🇰"),
    CountryCodeModel(name: "Egypt", code: "EG", dialCode: "+20", flag: "🇪🇬"),
    CountryCodeModel(name: "Finland", code: "FI", dialCode: "+358", flag: "🇫🇮"),
    CountryCodeModel(name: "France", code: "FR", dialCode: "+33", flag: "🇫🇷"),
    CountryCodeModel(name: "Germany", code: "DE", dialCode: "+49", flag: "🇩🇪"),
    CountryCodeModel(name: "Greece", code: "GR", dialCode: "+30", flag: "🇬🇷"),
    CountryCodeModel(name: "Hong Kong", code: "HK", dialCode: "+852", flag: "🇭🇰"),
    CountryCodeModel(name: "India", code: "IN", dialCode: "+91", flag: "🇮🇳"),
    CountryCodeModel(name: "Indonesia", code: "ID", dialCode: "+62", flag: "🇮🇩"),
    CountryCodeModel(name: "Iran", code: "IR", dialCode: "+98", flag: "🇮🇷"),
    CountryCodeModel(name: "Iraq", code: "IQ", dialCode: "+964", flag: "🇮🇶"),
    CountryCodeModel(name: "Ireland", code: "IE", dialCode: "+353", flag: "🇮🇪"),
    CountryCodeModel(name: "Israel", code: "IL", dialCode: "+972", flag: "🇮🇱"),
    CountryCodeModel(name: "Italy", code: "IT", dialCode: "+39", flag: "🇮🇹"),
    CountryCodeModel(name: "Japan", code: "JP", dialCode: "+81", flag: "🇯🇵"),
    CountryCodeModel(name: "Kenya", code: "KE", dialCode: "+254", flag: "🇰🇪"),
    CountryCodeModel(name: "Kuwait", code: "KW", dialCode: "+965", flag: "🇰🇼"),
    CountryCodeModel(name: "Malaysia", code: "MY", dialCode: "+60", flag: "🇲🇾"),
    CountryCodeModel(name: "Mexico", code: "MX", dialCode: "+52", flag: "🇲🇽"),
    CountryCodeModel(name: "Nepal", code: "NP", dialCode: "+977", flag: "🇳🇵"),
    CountryCodeModel(name: "Netherlands", code: "NL", dialCode: "+31", flag: "🇳🇱"),
    CountryCodeModel(name: "New Zealand", code: "NZ", dialCode: "+64", flag: "🇳🇿"),
    CountryCodeModel(name: "Nigeria", code: "NG", dialCode: "+234", flag: "🇳🇬"),
    CountryCodeModel(name: "Norway", code: "NO", dialCode: "+47", flag: "🇳🇴"),
    CountryCodeModel(name: "Pakistan", code: "PK", dialCode: "+92", flag: "🇵🇰"),
    CountryCodeModel(name: "Philippines", code: "PH", dialCode: "+63", flag: "🇵🇭"),
    CountryCodeModel(name: "Poland", code: "PL", dialCode: "+48", flag: "🇵🇱"),
    CountryCodeModel(name: "Portugal", code: "PT", dialCode: "+351", flag: "🇵🇹"),
    CountryCodeModel(name: "Qatar", code: "QA", dialCode: "+974", flag: "🇶🇦"),
    CountryCodeModel(name: "Russia", code: "RU", dialCode: "+7", flag: "🇷🇺"),
    CountryCodeModel(name: "Saudi Arabia", code: "SA", dialCode: "+966", flag: "🇸🇦"),
    CountryCodeModel(name: "Singapore", code: "SG", dialCode: "+65", flag: "🇸🇬"),
    CountryCodeModel(name: "South Africa", code: "ZA", dialCode: "+27", flag: "🇿🇦"),
    CountryCodeModel(name: "South Korea", code: "KR", dialCode: "+82", flag: "🇰🇷"),
    CountryCodeModel(name: "Spain", code: "ES", dialCode: "+34", flag: "🇪🇸"),
    CountryCodeModel(name: "Sri Lanka", code: "LK", dialCode: "+94", flag: "🇱🇰"),
    CountryCodeModel(name: "Sweden", code: "SE", dialCode: "+46", flag: "🇸🇪"),
    CountryCodeModel(name: "Switzerland", code: "CH", dialCode: "+41", flag: "🇨🇭"),
    CountryCodeModel(name: "Thailand", code: "TH", dialCode: "+66", flag: "🇹🇭"),
    CountryCodeModel(name: "Turkey", code: "TR", dialCode: "+90", flag: "🇹🇷"),
    CountryCodeModel(name: "UAE", code: "AE", dialCode: "+971", flag: "🇦🇪"),
    CountryCodeModel(name: "UK", code: "GB", dialCode: "+44", flag: "🇬🇧"),
    CountryCodeModel(name: "USA", code: "US", dialCode: "+1", flag: "🇺🇸"),
    CountryCodeModel(name: "Vietnam", code: "VN", dialCode: "+84", flag: "🇻🇳"),
  ];

  /// ISO 3166-2:IN codes for Salesforce `Address__StateCode__s` (India).
  static const Map<String, String> _indianStateToSalesforceCode = {
    'Andhra Pradesh': 'AP',
    'Arunachal Pradesh': 'AR',
    'Assam': 'AS',
    'Bihar': 'BR',
    'Chhattisgarh': 'CT',
    'Goa': 'GA',
    'Gujarat': 'GJ',
    'Haryana': 'HR',
    'Himachal Pradesh': 'HP',
    'Jharkhand': 'JH',
    'Karnataka': 'KA',
    'Kerala': 'KL',
    'Madhya Pradesh': 'MP',
    'Maharashtra': 'MH',
    'Manipur': 'MN',
    'Meghalaya': 'ML',
    'Mizoram': 'MZ',
    'Nagaland': 'NL',
    'Odisha': 'OR',
    'Punjab': 'PB',
    'Rajasthan': 'RJ',
    'Sikkim': 'SK',
    'Tamil Nadu': 'TN',
    'Telangana': 'TG',
    'Tripura': 'TR',
    'Uttar Pradesh': 'UP',
    'Uttarakhand': 'UT',
    'West Bengal': 'WB',
    'Andaman and Nicobar Islands': 'AN',
    'Chandigarh': 'CH',
    'Dadra and Nagar Haveli and Daman and Diu': 'DH',
    'Delhi': 'DL',
    'Jammu and Kashmir': 'JK',
    'Ladakh': 'LA',
    'Lakshadweep': 'LD',
    'Puducherry': 'PY',
  };

  static String salesforceIndianStateCode(String? stateName) {
    final name = stateName?.trim();
    if (name == null || name.isEmpty) return '';
    if (name.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(name)) {
      return name.toUpperCase();
    }
    return _indianStateToSalesforceCode[name] ?? name;
  }

  /// ISO 3166-1 alpha-2 for APIs/Salesforce `Address__CountryCode__s` picklists.
  static String salesforceCountryCode(String? countryName) {
    final name = countryName?.trim();
    if (name == null || name.isEmpty) return '';
    if (name.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(name)) {
      return name.toUpperCase();
    }
    for (final c in countryCodesList) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c.code;
    }
    const aliases = <String, String>{
      'United Arab Emirates': 'AE',
      'United Kingdom': 'GB',
      'United States of America': 'US',
      'United States': 'US',
    };
    return aliases[name] ?? name;
  }

  /// Display label for a stored country (ISO code or full name).
  static String? displayCountryName(String? stored) {
    final value = stored?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(value)) {
      final code = value.toUpperCase();
      for (final c in countryCodesList) {
        if (c.code.toUpperCase() == code) return c.name;
      }
      const codeToName = {
        'AE': 'United Arab Emirates',
        'GB': 'United Kingdom',
        'US': 'United States of America',
      };
      return codeToName[code] ?? value;
    }
    if (getAllCountries().any((c) => c.toLowerCase() == value.toLowerCase())) {
      return getAllCountries().firstWhere(
        (c) => c.toLowerCase() == value.toLowerCase(),
      );
    }
    return value;
  }

  /// Display label for stored Indian state (SF code or full name).
  static String? displayIndianStateName(String? stored) {
    final value = stored?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(value)) {
      final code = value.toUpperCase();
      for (final entry in _indianStateToSalesforceCode.entries) {
        if (entry.value.toUpperCase() == code) return entry.key;
      }
      return value;
    }
    if (_indianStateToSalesforceCode.containsKey(value)) return value;
  for (final name in getIndianStates()) {
      if (name.toLowerCase() == value.toLowerCase()) return name;
    }
    return value;
  }
}
