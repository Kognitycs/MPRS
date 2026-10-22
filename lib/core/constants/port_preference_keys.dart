/// SharedPreferences keys for port usage and cached most-used ports.
class PortPreferenceKeys {
  PortPreferenceKeys._();

  static const String polUsageJson = 'port_usage_pol_counts_json';
  static const String podUsageJson = 'port_usage_pod_counts_json';

  static const String cachedPol = 'cached_most_used_pol';
  static const String cachedPod = 'cached_most_used_pod';
  static const String cachedPolCount = 'cached_most_used_pol_count';
  static const String cachedPodCount = 'cached_most_used_pod_count';
  static const String cachedAtMs = 'cached_most_used_ports_at_ms';
}
