import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/screens/main_screen.dart';
import 'package:mprs_android/screens/support_screen.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:url_launcher/url_launcher.dart';

class NoRatesAvailableScreen extends StatefulWidget {
  final String? originPort;
  final String? destinationPort;

  const NoRatesAvailableScreen({
    super.key,
    this.originPort,
    this.destinationPort,
  });

  @override
  State<NoRatesAvailableScreen> createState() => _NoRatesAvailableScreenState();
}

class _NoRatesAvailableScreenState extends State<NoRatesAvailableScreen> {
  List<Map<String, dynamic>> _supportPersons = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSupportDetails());
  }

  String _resolveAccountId() {
    final fromDb = DbHelper().getUserModel()?.accountId?.trim() ?? '';
    if (fromDb.isNotEmpty) return fromDb;
    return AuthDataHelper.getAccountId().trim();
  }

  Future<void> _fetchSupportDetails() async {
    final accountId = _resolveAccountId();
    final token = AuthDataHelper.getToken();
    final isInternal = AuthDataHelper.isInternalUser();

    if (accountId.isEmpty && isInternal) {
      if (!mounted) return;
      setState(() {
        _supportPersons = List<Map<String, dynamic>>.from(kDefaultSupportContacts);
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    if (accountId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _supportPersons = List.from(kDefaultSupportContacts);
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await HttpClientHelper.getWithBearer(
        ApiConstants.supportDetailsForAccount(accountId),
        token,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.data);
        final List raw = jsonData['supportPersonDetails'] ?? [];
        final list = raw.cast<Map<String, dynamic>>();

        if (!mounted) return;
        setState(() {
          _supportPersons = list.isNotEmpty
              ? list
              : List.from(kDefaultSupportContacts);
          _loadError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _supportPersons = List.from(kDefaultSupportContacts);
          _loadError = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supportPersons = List.from(kDefaultSupportContacts);
        _loadError = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
      return;
    }

    final homeNav = MainScreen.homeTabNavigatorKey.currentState;
    if (homeNav != null && homeNav.canPop()) {
      homeNav.popUntil((route) => route.isFirst);
    }
  }

  void _callNumber(String number) async {
    final dial = number.split('/').first.trim().replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: dial);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _email(String email, String subject) async {
    final gmailIntent = Uri.parse(
      'googlegmail:///co?to=$email&subject=${Uri.encodeComponent(subject)}',
    );
    final defaultEmail = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    if (await canLaunchUrl(gmailIntent)) {
      await launchUrl(gmailIntent);
    } else if (await canLaunchUrl(defaultEmail)) {
      await launchUrl(defaultEmail);
    }
  }

  Widget _contactBox({
    required String title,
    required String phone,
    required String email,
    required String subject,
    String? hours,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.phone, color: AppColors.main, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _callNumber(phone),
                  child: Text(
                    phone,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.email_outlined, color: AppColors.main, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _email(email, subject),
                  child: Text(
                    email,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hours != null && hours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, color: AppColors.main, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(hours)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String get _routeLabel {
    final origin = widget.originPort?.trim() ?? '';
    final destination = widget.destinationPort?.trim() ?? '';
    if (origin.isNotEmpty && destination.isNotEmpty) {
      return '$origin → $destination';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final routeLabel = _routeLabel;

    return Scaffold(
      appBar: const CommonAppBar(title: 'Search Rates'),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.route_outlined,
                          size: 52,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No rates available right now',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          routeLabel.isNotEmpty
                              ? 'We could not find published rates for $routeLabel at the moment.'
                              : 'We could not find published rates for this route at the moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please don\'t worry — our team will connect with you shortly to assist with your enquiry.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Need immediate help? Reach out to our team',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.main,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (_loadError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _loadError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ..._supportPersons.map((person) {
                      final name = person['userName']?.toString() ?? '';
                      final phone = person['userMobilePhone']?.toString() ?? '';
                      final email = person['userEmail']?.toString() ?? '';
                      final role =
                          person['teamMemberRole']?.toString() ?? 'Support';
                      return _contactBox(
                        title: '$name ($role)',
                        phone: phone,
                        email: email,
                        subject: '$role Enquiry',
                      );
                    }),
                    _contactBox(
                      title: kGeneralSupportContact['title']!,
                      phone: kGeneralSupportContact['phone']!,
                      email: kGeneralSupportContact['email']!,
                      subject: 'General Support Enquiry',
                      hours: kGeneralSupportContact['hours'],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
