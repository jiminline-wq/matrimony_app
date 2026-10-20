import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/bd_districts.dart';

// ============================================================
// DISTRICT DROPDOWN — reusable
// ============================================================

class DistrictDropdown extends StatelessWidget {
  final String? value;
  final String label;
  final String hint;
  final bool isBangla;
  final ValueChanged<String?> onChanged;

  const DistrictDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'জেলা',
    this.hint = 'জেলা নির্বাচন করুন',
    this.isBangla = true,
  });

  @override
  Widget build(BuildContext context) {
    // বাংলা নাম → English (migration safety)
    final safeValue = _normalizeDistrict(value);

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.location_city, color: primaryMaroon),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: primaryMaroon.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryMaroon, width: 1.6),
        ),
      ),
      items: bdDistricts
          .map((d) => DropdownMenuItem<String>(
                value: d,
                child: Text(d, style: const TextStyle(fontSize: 15)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  /// যদি পুরনো বাংলা নাম থাকে, English এ convert করে মিলিয়ে দেয়
  String? _normalizeDistrict(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final t = raw.trim();

    // Direct match
    if (bdDistricts.contains(t)) return t;

    // Bangla → English mapping
    const map = {
      'ঢাকা': 'Dhaka',
      'চট্টগ্রাম': 'Chattogram',
      'খুলনা': 'Khulna',
      'রাজশাহী': 'Rajshahi',
      'সিলেট': 'Sylhet',
      'বরিশাল': 'Barishal',
      'রংপুর': 'Rangpur',
      'ময়মনসিংহ': 'Mymensingh',
      'কুমিল্লা': 'Cumilla',
      'নারায়ণগঞ্জ': 'Narayanganj',
      'গাজীপুর': 'Gazipur',
      'বগুড়া': 'Bogura',
      'যশোর': 'Jashore',
      'কক্সবাজার': "Cox's Bazar",
      'ফেনী': 'Feni',
      // ... চাইলে আরো যোগ করুন
    };

    if (map.containsKey(t)) return map[t];

    // Case-insensitive match
    for (final d in bdDistricts) {
      if (d.toLowerCase() == t.toLowerCase()) return d;
    }

    return null; // match না হলে null — user আবার select করবে
  }
}