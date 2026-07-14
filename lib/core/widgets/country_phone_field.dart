import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../../app/theme/design_tokens.dart';

/// یک کشور + کد شمارهٔ تلفن بین‌المللی آن.
class Country {
  final String name;
  final String iso2;
  final String dialCode;
  final String flag;
  const Country(this.name, this.iso2, this.dialCode, this.flag);
}

/// فهرست تقریباً کامل کشورهای جهان به همراه کد تلفن و پرچم — بدون نیاز به
/// هیچ پکیج بیرونی (برای جلوگیری از نیاز به `flutter pub get`). افغانستان
/// عمداً در ابتدای لیست قرار دارد تا پیش‌فرض باشد؛ بقیه به ترتیب حروف انگلیسی.
const List<Country> kCountries = [
  Country('Afghanistan', 'AF', '+93', '🇦🇫'),
  Country('Albania', 'AL', '+355', '🇦🇱'),
  Country('Algeria', 'DZ', '+213', '🇩🇿'),
  Country('Andorra', 'AD', '+376', '🇦🇩'),
  Country('Angola', 'AO', '+244', '🇦🇴'),
  Country('Argentina', 'AR', '+54', '🇦🇷'),
  Country('Armenia', 'AM', '+374', '🇦🇲'),
  Country('Australia', 'AU', '+61', '🇦🇺'),
  Country('Austria', 'AT', '+43', '🇦🇹'),
  Country('Azerbaijan', 'AZ', '+994', '🇦🇿'),
  Country('Bahamas', 'BS', '+1242', '🇧🇸'),
  Country('Bahrain', 'BH', '+973', '🇧🇭'),
  Country('Bangladesh', 'BD', '+880', '🇧🇩'),
  Country('Belarus', 'BY', '+375', '🇧🇾'),
  Country('Belgium', 'BE', '+32', '🇧🇪'),
  Country('Belize', 'BZ', '+501', '🇧🇿'),
  Country('Benin', 'BJ', '+229', '🇧🇯'),
  Country('Bhutan', 'BT', '+975', '🇧🇹'),
  Country('Bolivia', 'BO', '+591', '🇧🇴'),
  Country('Bosnia and Herzegovina', 'BA', '+387', '🇧🇦'),
  Country('Botswana', 'BW', '+267', '🇧🇼'),
  Country('Brazil', 'BR', '+55', '🇧🇷'),
  Country('Brunei', 'BN', '+673', '🇧🇳'),
  Country('Bulgaria', 'BG', '+359', '🇧🇬'),
  Country('Burkina Faso', 'BF', '+226', '🇧🇫'),
  Country('Burundi', 'BI', '+257', '🇧🇮'),
  Country('Cambodia', 'KH', '+855', '🇰🇭'),
  Country('Cameroon', 'CM', '+237', '🇨🇲'),
  Country('Canada', 'CA', '+1', '🇨🇦'),
  Country('Cape Verde', 'CV', '+238', '🇨🇻'),
  Country('Central African Republic', 'CF', '+236', '🇨🇫'),
  Country('Chad', 'TD', '+235', '🇹🇩'),
  Country('Chile', 'CL', '+56', '🇨🇱'),
  Country('China', 'CN', '+86', '🇨🇳'),
  Country('Colombia', 'CO', '+57', '🇨🇴'),
  Country('Comoros', 'KM', '+269', '🇰🇲'),
  Country('Congo (DRC)', 'CD', '+243', '🇨🇩'),
  Country('Congo (Republic)', 'CG', '+242', '🇨🇬'),
  Country('Costa Rica', 'CR', '+506', '🇨🇷'),
  Country("Côte d'Ivoire", 'CI', '+225', '🇨🇮'),
  Country('Croatia', 'HR', '+385', '🇭🇷'),
  Country('Cuba', 'CU', '+53', '🇨🇺'),
  Country('Cyprus', 'CY', '+357', '🇨🇾'),
  Country('Czech Republic', 'CZ', '+420', '🇨🇿'),
  Country('Denmark', 'DK', '+45', '🇩🇰'),
  Country('Djibouti', 'DJ', '+253', '🇩🇯'),
  Country('Dominica', 'DM', '+1767', '🇩🇲'),
  Country('Dominican Republic', 'DO', '+1', '🇩🇴'),
  Country('Ecuador', 'EC', '+593', '🇪🇨'),
  Country('Egypt', 'EG', '+20', '🇪🇬'),
  Country('El Salvador', 'SV', '+503', '🇸🇻'),
  Country('Equatorial Guinea', 'GQ', '+240', '🇬🇶'),
  Country('Eritrea', 'ER', '+291', '🇪🇷'),
  Country('Estonia', 'EE', '+372', '🇪🇪'),
  Country('Eswatini', 'SZ', '+268', '🇸🇿'),
  Country('Ethiopia', 'ET', '+251', '🇪🇹'),
  Country('Fiji', 'FJ', '+679', '🇫🇯'),
  Country('Finland', 'FI', '+358', '🇫🇮'),
  Country('France', 'FR', '+33', '🇫🇷'),
  Country('Gabon', 'GA', '+241', '🇬🇦'),
  Country('Gambia', 'GM', '+220', '🇬🇲'),
  Country('Georgia', 'GE', '+995', '🇬🇪'),
  Country('Germany', 'DE', '+49', '🇩🇪'),
  Country('Ghana', 'GH', '+233', '🇬🇭'),
  Country('Greece', 'GR', '+30', '🇬🇷'),
  Country('Grenada', 'GD', '+1473', '🇬🇩'),
  Country('Guatemala', 'GT', '+502', '🇬🇹'),
  Country('Guinea', 'GN', '+224', '🇬🇳'),
  Country('Guinea-Bissau', 'GW', '+245', '🇬🇼'),
  Country('Guyana', 'GY', '+592', '🇬🇾'),
  Country('Haiti', 'HT', '+509', '🇭🇹'),
  Country('Honduras', 'HN', '+504', '🇭🇳'),
  Country('Hungary', 'HU', '+36', '🇭🇺'),
  Country('Iceland', 'IS', '+354', '🇮🇸'),
  Country('India', 'IN', '+91', '🇮🇳'),
  Country('Indonesia', 'ID', '+62', '🇮🇩'),
  Country('Iran', 'IR', '+98', '🇮🇷'),
  Country('Iraq', 'IQ', '+964', '🇮🇶'),
  Country('Ireland', 'IE', '+353', '🇮🇪'),
  Country('Israel', 'IL', '+972', '🇮🇱'),
  Country('Italy', 'IT', '+39', '🇮🇹'),
  Country('Jamaica', 'JM', '+1876', '🇯🇲'),
  Country('Japan', 'JP', '+81', '🇯🇵'),
  Country('Jordan', 'JO', '+962', '🇯🇴'),
  Country('Kazakhstan', 'KZ', '+7', '🇰🇿'),
  Country('Kenya', 'KE', '+254', '🇰🇪'),
  Country('Kiribati', 'KI', '+686', '🇰🇮'),
  Country('Kosovo', 'XK', '+383', '🇽🇰'),
  Country('Kuwait', 'KW', '+965', '🇰🇼'),
  Country('Kyrgyzstan', 'KG', '+996', '🇰🇬'),
  Country('Laos', 'LA', '+856', '🇱🇦'),
  Country('Latvia', 'LV', '+371', '🇱🇻'),
  Country('Lebanon', 'LB', '+961', '🇱🇧'),
  Country('Lesotho', 'LS', '+266', '🇱🇸'),
  Country('Liberia', 'LR', '+231', '🇱🇷'),
  Country('Libya', 'LY', '+218', '🇱🇾'),
  Country('Liechtenstein', 'LI', '+423', '🇱🇮'),
  Country('Lithuania', 'LT', '+370', '🇱🇹'),
  Country('Luxembourg', 'LU', '+352', '🇱🇺'),
  Country('Madagascar', 'MG', '+261', '🇲🇬'),
  Country('Malawi', 'MW', '+265', '🇲🇼'),
  Country('Malaysia', 'MY', '+60', '🇲🇾'),
  Country('Maldives', 'MV', '+960', '🇲🇻'),
  Country('Mali', 'ML', '+223', '🇲🇱'),
  Country('Malta', 'MT', '+356', '🇲🇹'),
  Country('Marshall Islands', 'MH', '+692', '🇲🇭'),
  Country('Mauritania', 'MR', '+222', '🇲🇷'),
  Country('Mauritius', 'MU', '+230', '🇲🇺'),
  Country('Mexico', 'MX', '+52', '🇲🇽'),
  Country('Micronesia', 'FM', '+691', '🇫🇲'),
  Country('Moldova', 'MD', '+373', '🇲🇩'),
  Country('Monaco', 'MC', '+377', '🇲🇨'),
  Country('Mongolia', 'MN', '+976', '🇲🇳'),
  Country('Montenegro', 'ME', '+382', '🇲🇪'),
  Country('Morocco', 'MA', '+212', '🇲🇦'),
  Country('Mozambique', 'MZ', '+258', '🇲🇿'),
  Country('Myanmar', 'MM', '+95', '🇲🇲'),
  Country('Namibia', 'NA', '+264', '🇳🇦'),
  Country('Nauru', 'NR', '+674', '🇳🇷'),
  Country('Nepal', 'NP', '+977', '🇳🇵'),
  Country('Netherlands', 'NL', '+31', '🇳🇱'),
  Country('New Zealand', 'NZ', '+64', '🇳🇿'),
  Country('Nicaragua', 'NI', '+505', '🇳🇮'),
  Country('Niger', 'NE', '+227', '🇳🇪'),
  Country('Nigeria', 'NG', '+234', '🇳🇬'),
  Country('North Korea', 'KP', '+850', '🇰🇵'),
  Country('North Macedonia', 'MK', '+389', '🇲🇰'),
  Country('Norway', 'NO', '+47', '🇳🇴'),
  Country('Oman', 'OM', '+968', '🇴🇲'),
  Country('Pakistan', 'PK', '+92', '🇵🇰'),
  Country('Palau', 'PW', '+680', '🇵🇼'),
  Country('Palestine', 'PS', '+970', '🇵🇸'),
  Country('Panama', 'PA', '+507', '🇵🇦'),
  Country('Papua New Guinea', 'PG', '+675', '🇵🇬'),
  Country('Paraguay', 'PY', '+595', '🇵🇾'),
  Country('Peru', 'PE', '+51', '🇵🇪'),
  Country('Philippines', 'PH', '+63', '🇵🇭'),
  Country('Poland', 'PL', '+48', '🇵🇱'),
  Country('Portugal', 'PT', '+351', '🇵🇹'),
  Country('Qatar', 'QA', '+974', '🇶🇦'),
  Country('Romania', 'RO', '+40', '🇷🇴'),
  Country('Russia', 'RU', '+7', '🇷🇺'),
  Country('Rwanda', 'RW', '+250', '🇷🇼'),
  Country('Saint Lucia', 'LC', '+1758', '🇱🇨'),
  Country('Samoa', 'WS', '+685', '🇼🇸'),
  Country('San Marino', 'SM', '+378', '🇸🇲'),
  Country('Sao Tome and Principe', 'ST', '+239', '🇸🇹'),
  Country('Saudi Arabia', 'SA', '+966', '🇸🇦'),
  Country('Senegal', 'SN', '+221', '🇸🇳'),
  Country('Serbia', 'RS', '+381', '🇷🇸'),
  Country('Seychelles', 'SC', '+248', '🇸🇨'),
  Country('Sierra Leone', 'SL', '+232', '🇸🇱'),
  Country('Singapore', 'SG', '+65', '🇸🇬'),
  Country('Slovakia', 'SK', '+421', '🇸🇰'),
  Country('Slovenia', 'SI', '+386', '🇸🇮'),
  Country('Solomon Islands', 'SB', '+677', '🇸🇧'),
  Country('Somalia', 'SO', '+252', '🇸🇴'),
  Country('South Africa', 'ZA', '+27', '🇿🇦'),
  Country('South Korea', 'KR', '+82', '🇰🇷'),
  Country('South Sudan', 'SS', '+211', '🇸🇸'),
  Country('Spain', 'ES', '+34', '🇪🇸'),
  Country('Sri Lanka', 'LK', '+94', '🇱🇰'),
  Country('Sudan', 'SD', '+249', '🇸🇩'),
  Country('Suriname', 'SR', '+597', '🇸🇷'),
  Country('Sweden', 'SE', '+46', '🇸🇪'),
  Country('Switzerland', 'CH', '+41', '🇨🇭'),
  Country('Syria', 'SY', '+963', '🇸🇾'),
  Country('Taiwan', 'TW', '+886', '🇹🇼'),
  Country('Tajikistan', 'TJ', '+992', '🇹🇯'),
  Country('Tanzania', 'TZ', '+255', '🇹🇿'),
  Country('Thailand', 'TH', '+66', '🇹🇭'),
  Country('Timor-Leste', 'TL', '+670', '🇹🇱'),
  Country('Togo', 'TG', '+228', '🇹🇬'),
  Country('Tonga', 'TO', '+676', '🇹🇴'),
  Country('Trinidad and Tobago', 'TT', '+1868', '🇹🇹'),
  Country('Tunisia', 'TN', '+216', '🇹🇳'),
  Country('Turkey', 'TR', '+90', '🇹🇷'),
  Country('Turkmenistan', 'TM', '+993', '🇹🇲'),
  Country('Tuvalu', 'TV', '+688', '🇹🇻'),
  Country('Uganda', 'UG', '+256', '🇺🇬'),
  Country('Ukraine', 'UA', '+380', '🇺🇦'),
  Country('United Arab Emirates', 'AE', '+971', '🇦🇪'),
  Country('United Kingdom', 'GB', '+44', '🇬🇧'),
  Country('United States', 'US', '+1', '🇺🇸'),
  Country('Uruguay', 'UY', '+598', '🇺🇾'),
  Country('Uzbekistan', 'UZ', '+998', '🇺🇿'),
  Country('Vanuatu', 'VU', '+678', '🇻🇺'),
  Country('Vatican City', 'VA', '+379', '🇻🇦'),
  Country('Venezuela', 'VE', '+58', '🇻🇪'),
  Country('Vietnam', 'VN', '+84', '🇻🇳'),
  Country('Yemen', 'YE', '+967', '🇾🇪'),
  Country('Zambia', 'ZM', '+260', '🇿🇲'),
  Country('Zimbabwe', 'ZW', '+263', '🇿🇼'),
];

Country _defaultCountry() => kCountries.first; // Afghanistan

/// بهترین تطبیق کشور از روی یک شمارهٔ کامل (با یا بدون +) — طولانی‌ترین
/// کد تلفنِ منطبق را انتخاب می‌کند (مثلاً +1876 جامائیکا را از +1 آمریکا
/// تشخیص می‌دهد).
Country? _matchCountryFromFull(String raw) {
  final v = raw.trim();
  if (!v.startsWith('+')) return null;
  final candidates = kCountries.where((c) => v.startsWith(c.dialCode)).toList()
    ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
  return candidates.isEmpty ? null : candidates.first;
}

/// ویجت مشترک شمارهٔ تلفن با انتخاب‌گر پویا و قابل‌جست‌وجوی کد کشور — برای
/// استفاده در تمام صفحات ثبت‌نام (دانش‌آموز/والد/استاد) به‌جای پیش‌فرض
/// ثابتِ افغانستان (+93)، تا کاربران از هر کشوری بتوانند ثبت‌نام کنند.
///
/// مقدار نهایی («+کدکشور» + شمارهٔ محلی) همیشه در [controller] نگه داشته
/// می‌شود — دقیقاً مثل قبل — پس بقیهٔ کد (اعتبارسنجی/ارسال به سرور) بدون
/// تغییر کار می‌کند.
class CountryPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  const CountryPhoneField({
    super.key,
    required this.controller,
    required this.label,
    this.required = true,
  });

  @override
  State<CountryPhoneField> createState() => _CountryPhoneFieldState();
}

class _CountryPhoneFieldState extends State<CountryPhoneField> {
  late Country _country;
  late TextEditingController _localController;

  @override
  void initState() {
    super.initState();
    final raw = widget.controller.text.trim();
    _country = _matchCountryFromFull(raw) ?? _defaultCountry();
    final local = raw.startsWith(_country.dialCode) ? raw.substring(_country.dialCode.length) : '';
    _localController = TextEditingController(text: local);
    _localController.addListener(_syncToOuterController);
    _syncToOuterController();
  }

  void _syncToOuterController() {
    widget.controller.text = '${_country.dialCode}${_localController.text.trim()}';
  }

  @override
  void dispose() {
    _localController.dispose();
    super.dispose();
  }

  Future<void> _openPicker() async {
    final selected = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(current: _country),
    );
    if (selected != null && mounted) {
      setState(() {
        _country = selected;
        _syncToOuterController();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _localController,
      keyboardType: TextInputType.phone,
      validator: widget.required
          ? (v) => (v == null || v.trim().length < 4) ? context.tr('common.required') : null
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: _openPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_country.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  Text(_country.dialCode,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Container(width: 1, height: 20, color: scheme.outlineVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final Country current;
  const _CountryPickerSheet({required this.current});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? kCountries
        : kCountries
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.dialCode.contains(q) ||
                c.iso2.toLowerCase() == q)
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: context.tr('auth.searchCountry'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      final selected = c.iso2 == widget.current.iso2;
                      return ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(c.name),
                        trailing: Text(c.dialCode,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected ? scheme.primary : scheme.onSurfaceVariant)),
                        selected: selected,
                        onTap: () => Navigator.of(ctx).pop(c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
