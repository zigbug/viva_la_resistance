// SI (1000-based) traffic formatters — presentation layer only.
// Raw byte values from the SDK are never modified; these helpers are used
// exclusively when rendering values for display.

String formatSpeed(int bps) {
  if (bps >= 1000000000) return '${(bps / 1000000000).toStringAsFixed(1)} GB/s';
  if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} MB/s';
  if (bps >= 1000) return '${(bps / 1000).toStringAsFixed(1)} KB/s';
  return '$bps B/s';
}

String formatBytes(int bytes) {
  if (bytes >= 1000000000) return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
  if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(2)} MB';
  if (bytes >= 1000) return '${(bytes / 1000).toStringAsFixed(1)} KB';
  return '$bytes B';
}
