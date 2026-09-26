class CountryCodeModel {
  final String name;
  final String dialCode;
  final String code;
  final String flag;

  const CountryCodeModel({
    required this.name,
    required this.dialCode,
    required this.code,
    required this.flag,
  });
}

class CountryCodeData {
  static const List<CountryCodeModel> allCountries = [
    CountryCodeModel(name: 'India', dialCode: '+91', code: 'IN', flag: '🇮🇳'),
    CountryCodeModel(name: 'United States', dialCode: '+1', code: 'US', flag: '🇺🇸'),
    CountryCodeModel(name: 'United Kingdom', dialCode: '+44', code: 'GB', flag: '🇬🇧'),
    CountryCodeModel(name: 'United Arab Emirates', dialCode: '+971', code: 'AE', flag: '🇦🇪'),
    CountryCodeModel(name: 'Singapore', dialCode: '+65', code: 'SG', flag: '🇸🇬'),
    CountryCodeModel(name: 'Malaysia', dialCode: '+60', code: 'MY', flag: '🇲🇾'),
    CountryCodeModel(name: 'Saudi Arabia', dialCode: '+966', code: 'SA', flag: '🇸🇦'),
    CountryCodeModel(name: 'Qatar', dialCode: '+974', code: 'QA', flag: '🇶🇦'),
    CountryCodeModel(name: 'Oman', dialCode: '+968', code: 'OM', flag: '🇴🇲'),
    CountryCodeModel(name: 'Kuwait', dialCode: '+965', code: 'KW', flag: '🇰🇼'),
    CountryCodeModel(name: 'Bahrain', dialCode: '+973', code: 'BH', flag: '🇧🇭'),
    CountryCodeModel(name: 'Canada', dialCode: '+1', code: 'CA', flag: '🇨🇦'),
    CountryCodeModel(name: 'Australia', dialCode: '+61', code: 'AU', flag: '🇦🇺'),
    CountryCodeModel(name: 'Germany', dialCode: '+49', code: 'DE', flag: '🇩🇪'),
    CountryCodeModel(name: 'France', dialCode: '+33', code: 'FR', flag: '🇫🇷'),
    CountryCodeModel(name: 'Italy', dialCode: '+39', code: 'IT', flag: '🇮🇹'),
    CountryCodeModel(name: 'Spain', dialCode: '+34', code: 'ES', flag: '🇪🇸'),
    CountryCodeModel(name: 'Sri Lanka', dialCode: '+94', code: 'LK', flag: '🇱🇰'),
    CountryCodeModel(name: 'Bangladesh', dialCode: '+880', code: 'BD', flag: '🇧🇩'),
    CountryCodeModel(name: 'Nepal', dialCode: '+977', code: 'NP', flag: '🇳🇵'),
    CountryCodeModel(name: 'Pakistan', dialCode: '+92', code: 'PK', flag: '🇵🇰'),
    CountryCodeModel(name: 'South Africa', dialCode: '+27', code: 'ZA', flag: '🇿🇦'),
    CountryCodeModel(name: 'New Zealand', dialCode: '+64', code: 'NZ', flag: '🇳🇿'),
    CountryCodeModel(name: 'Japan', dialCode: '+81', code: 'JP', flag: '🇯🇵'),
    CountryCodeModel(name: 'China', dialCode: '+86', code: 'CN', flag: '🇨🇳'),
    CountryCodeModel(name: 'Indonesia', dialCode: '+62', code: 'ID', flag: '🇮🇩'),
    CountryCodeModel(name: 'Thailand', dialCode: '+66', code: 'TH', flag: '🇹🇭'),
    CountryCodeModel(name: 'Philippines', dialCode: '+63', code: 'PH', flag: '🇵🇭'),
    CountryCodeModel(name: 'Vietnam', dialCode: '+84', code: 'VN', flag: '🇻🇳'),
    CountryCodeModel(name: 'Brazil', dialCode: '+55', code: 'BR', flag: '🇧🇷'),
    CountryCodeModel(name: 'Mexico', dialCode: '+52', code: 'MX', flag: '🇲🇽'),
    CountryCodeModel(name: 'Argentina', dialCode: '+54', code: 'AR', flag: '🇦🇷'),
    CountryCodeModel(name: 'Nigeria', dialCode: '+234', code: 'NG', flag: '🇳🇬'),
    CountryCodeModel(name: 'Kenya', dialCode: '+254', code: 'KE', flag: '🇰🇪'),
    CountryCodeModel(name: 'Egypt', dialCode: '+20', code: 'EG', flag: '🇪🇬'),
    CountryCodeModel(name: 'Turkey', dialCode: '+90', code: 'TR', flag: '🇹🇷'),
    CountryCodeModel(name: 'Russia', dialCode: '+7', code: 'RU', flag: '🇷🇺'),
    CountryCodeModel(name: 'Netherlands', dialCode: '+31', code: 'NL', flag: '🇳🇱'),
    CountryCodeModel(name: 'Switzerland', dialCode: '+41', code: 'CH', flag: '🇨🇭'),
    CountryCodeModel(name: 'Sweden', dialCode: '+46', code: 'SE', flag: '🇸🇪'),
    CountryCodeModel(name: 'Norway', dialCode: '+47', code: 'NO', flag: '🇳🇴'),
    CountryCodeModel(name: 'Ireland', dialCode: '+353', code: 'IE', flag: '🇮🇪'),
  ];

  static CountryCodeModel defaultCountry = allCountries.first;

  static CountryCodeModel findByDialCode(String dialCode) {
    return allCountries.firstWhere(
      (c) => c.dialCode == dialCode,
      orElse: () => defaultCountry,
    );
  }
}
