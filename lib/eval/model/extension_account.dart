/// Public profile information returned by an extension's `getAccount()` hook.
///
/// Extensions should return only display-safe fields; authentication tokens and
/// cookies belong in the extension session manager, never in this model.
class ExtensionAccount {
  const ExtensionAccount({
    this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.email,
  });

  final String? id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? email;

  factory ExtensionAccount.fromJson(Map<String, dynamic> json) {
    final nested = json['attributes'];
    final attributes = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;

    String? readString(Iterable<dynamic> values) {
      for (final value in values) {
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    return ExtensionAccount(
      id: readString([json['id'], attributes['id']]),
      username: readString([attributes['username'], json['username']]),
      displayName: readString([
        attributes['displayName'],
        attributes['display_name'],
        attributes['name'],
        attributes['username'],
        json['displayName'],
        json['name'],
      ]),
      avatarUrl: readString([
        attributes['avatarUrl'],
        attributes['avatar_url'],
        attributes['avatar'],
        json['avatarUrl'],
        json['avatar_url'],
      ]),
      email: readString([attributes['email'], json['email']]),
    );
  }
}
