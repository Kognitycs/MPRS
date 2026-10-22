import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mprs_android/core/auth_data_helper.dart';
import 'package:mprs_android/core/constants/api_constants.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/core/constants/db_helper.dart';
import 'package:mprs_android/service/http_client_helper.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Default MPRS support team — shown for Admin/Internal when no account is linked
/// (same contacts External users see for their account managers).
const List<Map<String, dynamic>> kDefaultSupportContacts = [
  {
    'userName': 'Kanchan Hargane',
    'userMobilePhone': '9869213221',
    'userEmail': 'shubham@kognitycs.com',
    'teamMemberRole': 'Sales Manager',
  },
  {
    'userName': 'Lubna Patel',
    'userMobilePhone': '9987462095',
    'userEmail': 'lubna.patel@mprsshipping.com',
    'teamMemberRole': 'Sales Rep',
  },
];

const Map<String, String> kGeneralSupportContact = {
  'title': 'General support',
  'phone': '+91-22-2868 8622 / 33',
  'email': 'corporate@mprsshipping.com',
  'hours': 'Mon – Sat: 9:30 AM to 6:30 PM',
};

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<Map<String, dynamic>> _supportPersons = [];
  bool _isLoading = false;
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

    debugPrint(
      'Support: role=${AuthDataHelper.getUserType()} accountId=$accountId',
    );

    if (accountId.isEmpty && isInternal) {
      setState(() {
        _supportPersons = List<Map<String, dynamic>>.from(
          kDefaultSupportContacts,
        );
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    if (accountId.isEmpty) {
      setState(() {
        _supportPersons = [];
        _isLoading = false;
        _loadError = 'Account not linked. Support contacts are unavailable.';
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

      debugPrint('Support API => ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.data);
        final List raw = jsonData['supportPersonDetails'] ?? [];
        final list = raw.cast<Map<String, dynamic>>();

        if (!mounted) return;
        setState(() {
          _supportPersons =
              list.isNotEmpty
                  ? list
                  : (isInternal ? List.from(kDefaultSupportContacts) : []);
          _loadError = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _supportPersons =
              isInternal ? List.from(kDefaultSupportContacts) : [];
          _loadError = isInternal ? null : 'Could not load support contacts.';
        });
      }
    } catch (e) {
      debugPrint('Support ERROR => $e');
      if (!mounted) return;
      setState(() {
        _supportPersons = isInternal ? List.from(kDefaultSupportContacts) : [];
        _loadError = isInternal ? null : 'Could not load support contacts.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _callNumber(String number) async {
    final dial = number
        .split('/')
        .first
        .trim()
        .replaceAll(RegExp(r'[^\d+]'), '');
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

  static const TextStyle _linkTextStyle = TextStyle(
    fontSize: 16,
    color: Colors.blue,
    decoration: TextDecoration.underline,
    decorationColor: Colors.blue,
    decorationThickness: 1.2,
    height: 1.4,
  );

  Widget _contactLink({required String text, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: AppColors.main.withOpacity(0.12),
        highlightColor: AppColors.main.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text, style: _linkTextStyle),
        ),
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.main, size: 22),
        const SizedBox(width: 10),
        Expanded(child: _contactLink(text: text, onTap: onTap)),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.main, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactBox({
    required String displayName,
    String? role,
    required String phone,
    required String email,
    required String subject,
    String? hours,
    bool isGeneralSupport = false,
  }) {
    final hoursText = hours?.trim() ?? '';
    final showHours = isGeneralSupport || hoursText.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.main.withOpacity(0.12),
            child: Icon(
              isGeneralSupport
                  ? Icons.support_agent_rounded
                  : Icons.person_rounded,
              size: 30,
              color: AppColors.main,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          if (role != null && role.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              role,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _contactRow(
                    icon: Icons.phone,
                    text: phone,
                    onTap: () => _callNumber(phone),
                  ),
                  const SizedBox(height: 8),
                  _contactRow(
                    icon: Icons.email_outlined,
                    text: email,
                    onTap: () => _email(email, subject),
                  ),
                  if (showHours) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      icon: Icons.access_time,
                      text: hoursText.isNotEmpty
                          ? hoursText
                          : kGeneralSupportContact['hours']!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContactCards() {
    final cards = <Widget>[];

    for (final person in _supportPersons) {
      final name = person['userName']?.toString() ?? '';
      final phone = person['userMobilePhone']?.toString() ?? '';
      final email = person['userEmail']?.toString() ?? '';
      final role = person['teamMemberRole']?.toString() ?? 'Support';
      cards.add(
        _contactBox(
          displayName: name,
          role: role,
          phone: phone,
          email: email,
          subject: '$role Enquiry',
        ),
      );
    }

    cards.add(
      _contactBox(
        displayName: kGeneralSupportContact['title']!,
        role: 'Corporate helpdesk',
        phone: kGeneralSupportContact['phone']!,
        email: kGeneralSupportContact['email']!,
        subject: 'General Support Enquiry',
        hours: kGeneralSupportContact['hours'],
        isGeneralSupport: true,
      ),
    );

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final isInternal = AuthDataHelper.isInternalUser();
    final contactCards = _buildContactCards();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: const CommonAppBar(title: 'Support'),
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _fetchSupportDetails,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32 - bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isInternal) ...[
                            Text(
                              'MPRS Support Team',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.main,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _resolveAccountId().isEmpty
                                  ? 'Contact your account managers (same as customer support).'
                                  : 'Account support contacts for ${_resolveAccountId()}.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_loadError != null) ...[
                            Text(
                              _loadError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_supportPersons.isEmpty && !isInternal)
                            SizedBox(
                              height: constraints.maxHeight * 0.4,
                              child: const Center(
                                child: Text(
                                  'No account managers assigned',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ...[
                              for (var i = 0; i < contactCards.length; i++) ...[
                                contactCards[i],
                                if (i < contactCards.length - 1)
                                  const SizedBox(height: 16),
                              ],
                            ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
