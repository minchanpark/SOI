const List<String> _blockedUsernameFragments = <String>[
  'anonymous',
  'anon',
  '익명',
];

bool isForbiddenUsername(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return _blockedUsernameFragments.any(normalized.contains);
}
