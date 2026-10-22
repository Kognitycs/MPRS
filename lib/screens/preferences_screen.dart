import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/service/most_used_ports_service.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/rounded_field.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final MostUsedPortsService _portsService = MostUsedPortsService();
  final TextEditingController _polController = TextEditingController();
  final TextEditingController _podController = TextEditingController();

  bool smsNotification = false;
  bool emailNotification = true;
  bool _loadingPorts = true;
  String? _portsError;
  int _polUseCount = 0;
  int _podUseCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMostUsedPorts();
  }

  @override
  void dispose() {
    _polController.dispose();
    _podController.dispose();
    super.dispose();
  }

  Future<void> _loadMostUsedPorts({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loadingPorts = true;
      _portsError = null;
    });

    final result = await _portsService.resolve(forceRefresh: refresh);

    if (!mounted) return;
    setState(() {
      _loadingPorts = false;
      _polUseCount = result.loadingUseCount;
      _podUseCount = result.dischargeUseCount;
      _polController.text = result.hasLoading
          ? result.portOfLoading!
          : 'No usage data yet';
      _podController.text = result.hasDischarge
          ? result.portOfDischarge!
          : 'No usage data yet';
      if (!result.hasLoading && !result.hasDischarge) {
        _portsError =
            'Complete a quote or booking to set preferred ports from your history.';
      }
    });
  }

  String _usageHint(int count, String role) {
    if (_loadingPorts) return 'Loading…';
    if (count <= 0) return 'Based on your most used $role';
    return 'Most used · $count ${count == 1 ? 'time' : 'times'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(title: "Preferences", onActionPressed: () {}),
      body: RefreshIndicator(
        onRefresh: () => _loadMostUsedPorts(refresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle("Notification"),
              buildSwitchRow(
                "Push Notification",
                "Receive notification",
                emailNotification,
                (v) => setState(() => emailNotification = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: sectionTitle("Saved Preferences")),
                  if (_loadingPorts)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(
                      onPressed: () => _loadMostUsedPorts(refresh: true),
                      child: const Text('Refresh'),
                    ),
                ],
              ),
              if (_portsError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _portsError!,
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
              ],
              const SizedBox(height: 8),
              RoundedInputField(
                label: "Preferred port of Loading",
                controller: _polController,
                hint: _usageHint(_polUseCount, 'origin port'),
                editable: false,
              ),
              RoundedInputField(
                label: "Preferred port of Discharge",
                controller: _podController,
                hint: _usageHint(_podUseCount, 'destination port'),
                editable: false,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSwitchRow(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(subtitle, style: TextStyle(color: AppColors.grey)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.green,
              inactiveThumbColor: AppColors.white,
              inactiveTrackColor: AppColors.lightGrey,
              trackOutlineColor:
                  WidgetStateProperty.all(Colors.transparent),
              trackOutlineWidth: WidgetStateProperty.all(0),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: TextStyle(fontSize: 14, color: AppColors.main)),
    );
  }
}
