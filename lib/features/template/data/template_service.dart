import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// One field in a built-in template.
class TemplateField {
  final String key;
  final String Function(AppLocalizations l10n) label;
  final bool protected;
  final bool multiline;

  const TemplateField({
    required this.key,
    required this.label,
    this.protected = false,
    this.multiline = false,
  });
}

/// A built-in entry template (1Password-style category).
class EntryTemplate {
  final String id;
  final KdbxIcon icon;
  final List<TemplateField> fields;

  const EntryTemplate({required this.id, required this.icon, required this.fields});
}

TemplateField _standard(String key, String Function(AppLocalizations) label) =>
    TemplateField(key: key, label: label);

/// Built-in templates shown in the new-entry flow. `login` is the implicit
/// default (the plain form) and is not listed as a picker option.
final builtInTemplates = <EntryTemplate>[
  EntryTemplate(
    id: 'login',
    icon: KdbxIcon.key,
    fields: [],
  ),
  EntryTemplate(
    id: 'bankAccount',
    icon: KdbxIcon.homebanking,
    fields: [
      _standard('Title', _lBankName),
      _standard('UserName', _lAccountHolder),
      TemplateField(key: 'BankName', label: _lBankName),
      TemplateField(key: 'AccountNumber', label: _lAccountNumber),
      TemplateField(key: 'RoutingNumber', label: _lRoutingNumber),
      _standard('Password', _lPassword),
      TemplateField(key: 'SWIFT', label: _lSwift),
      TemplateField(key: 'IBAN', label: _lIban),
      _standard('Notes', _lNotes),
    ],
  ),
  EntryTemplate(
    id: 'creditCard',
    icon: KdbxIcon.money,
    fields: [
      _standard('Title', _lCardName),
      TemplateField(key: 'CardType', label: _lCardType),
      TemplateField(key: 'CardNumber', label: _lCardNumber, protected: true),
      TemplateField(key: 'CardholderName', label: _lCardholderName),
      TemplateField(key: 'ExpirationDate', label: _lExpirationDate),
      TemplateField(key: 'CVV', label: _lCvv, protected: true),
      TemplateField(key: 'PIN', label: _lPin, protected: true),
      _standard('Notes', _lNotes),
    ],
  ),
  EntryTemplate(
    id: 'secureNote',
    icon: KdbxIcon.note,
    fields: [
      _standard('Title', _lTitle),
      TemplateField(key: 'NoteContent', label: _lNoteContent, multiline: true),
    ],
  ),
  EntryTemplate(
    id: 'server',
    icon: KdbxIcon.networkServer,
    fields: [
      _standard('Title', _lServerName),
      _standard('URL', _lUrl),
      _standard('UserName', _lUsername),
      _standard('Password', _lPassword),
      TemplateField(key: 'Host', label: _lHost),
      TemplateField(key: 'Port', label: _lPort),
      TemplateField(key: 'AdminUsername', label: _lAdminUsername),
      TemplateField(key: 'AdminPassword', label: _lAdminPassword, protected: true),
      _standard('Notes', _lNotes),
    ],
  ),
  EntryTemplate(
    id: 'identity',
    icon: KdbxIcon.identity,
    fields: [
      _standard('Title', _lIdentityName),
      TemplateField(key: 'FullName', label: _lFullName),
      TemplateField(key: 'IDNumber', label: _lIdNumber, protected: true),
      TemplateField(key: 'PhoneNumber', label: _lPhoneNumber),
      TemplateField(key: 'Email', label: _lEmail),
      TemplateField(key: 'Address', label: _lAddress, multiline: true),
      _standard('Notes', _lNotes),
    ],
  ),
  EntryTemplate(
    id: 'softwareLicense',
    icon: KdbxIcon.certificate,
    fields: [
      _standard('Title', _lSoftwareName),
      TemplateField(key: 'LicenseKey', label: _lLicenseKey, protected: true),
      TemplateField(key: 'LicensedTo', label: _lLicensedTo),
      TemplateField(key: 'Version', label: _lVersion),
      TemplateField(key: 'PurchaseDate', label: _lPurchaseDate),
      _standard('Notes', _lNotes),
    ],
  ),
];

EntryTemplate? templateById(String id) {
  for (final t in builtInTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

// Label resolvers keep the template table const while translations come from
// the caller's l10n instance.
String _lTitle(AppLocalizations l) => l.title;
String _lUsername(AppLocalizations l) => l.username;
String _lPassword(AppLocalizations l) => l.password;
String _lUrl(AppLocalizations l) => l.url;
String _lNotes(AppLocalizations l) => l.notes;
String _lBankName(AppLocalizations l) => l.tplBankName;
String _lAccountHolder(AppLocalizations l) => l.tplAccountHolder;
String _lAccountNumber(AppLocalizations l) => l.tplAccountNumber;
String _lRoutingNumber(AppLocalizations l) => l.tplRoutingNumber;
String _lSwift(AppLocalizations l) => l.tplSwift;
String _lIban(AppLocalizations l) => l.tplIban;
String _lCardName(AppLocalizations l) => l.tplCardName;
String _lCardType(AppLocalizations l) => l.tplCardType;
String _lCardNumber(AppLocalizations l) => l.tplCardNumber;
String _lCardholderName(AppLocalizations l) => l.tplCardholderName;
String _lExpirationDate(AppLocalizations l) => l.tplExpirationDate;
String _lCvv(AppLocalizations l) => l.tplCvv;
String _lPin(AppLocalizations l) => l.tplPin;
String _lNoteContent(AppLocalizations l) => l.tplNoteContent;
String _lServerName(AppLocalizations l) => l.tplServerName;
String _lHost(AppLocalizations l) => l.tplHost;
String _lPort(AppLocalizations l) => l.tplPort;
String _lAdminUsername(AppLocalizations l) => l.tplAdminUsername;
String _lAdminPassword(AppLocalizations l) => l.tplAdminPassword;
String _lIdentityName(AppLocalizations l) => l.tplIdentityName;
String _lFullName(AppLocalizations l) => l.tplFullName;
String _lIdNumber(AppLocalizations l) => l.tplIdNumber;
String _lPhoneNumber(AppLocalizations l) => l.tplPhoneNumber;
String _lEmail(AppLocalizations l) => l.tplEmail;
String _lAddress(AppLocalizations l) => l.tplAddress;
String _lSoftwareName(AppLocalizations l) => l.tplSoftwareName;
String _lLicenseKey(AppLocalizations l) => l.tplLicenseKey;
String _lLicensedTo(AppLocalizations l) => l.tplLicensedTo;
String _lVersion(AppLocalizations l) => l.tplVersion;
String _lPurchaseDate(AppLocalizations l) => l.tplPurchaseDate;

String templateDisplayName(EntryTemplate template, AppLocalizations l10n) {
  switch (template.id) {
    case 'login':
      return l10n.tplLogin;
    case 'bankAccount':
      return l10n.tplBankAccount;
    case 'creditCard':
      return l10n.tplCreditCard;
    case 'secureNote':
      return l10n.tplSecureNote;
    case 'server':
      return l10n.tplServer;
    case 'identity':
      return l10n.tplIdentity;
    case 'softwareLicense':
      return l10n.tplSoftwareLicense;
  }
  return template.id;
}

/// Shows the template picker and returns the chosen template (never null —
/// dismissing without choosing returns the default login template).
Future<EntryTemplate> pickTemplate(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final chosen = await showModalBottomSheet<EntryTemplate>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final template in builtInTemplates.skip(1))
            ListTile(
              leading: Icon(templateIcon(template.icon)),
              title: Text(templateDisplayName(template, l10n)),
              onTap: () => Navigator.pop(sheetContext, template),
            ),
        ],
      ),
    ),
  );
  return chosen ?? builtInTemplates.first;
}

IconData templateIcon(KdbxIcon icon) => switch (icon) {
  KdbxIcon.homebanking => Icons.account_balance_rounded,
  KdbxIcon.money => Icons.credit_card_rounded,
  KdbxIcon.note => Icons.note_rounded,
  KdbxIcon.networkServer => Icons.dns_rounded,
  KdbxIcon.identity => Icons.badge_rounded,
  KdbxIcon.certificate => Icons.verified_rounded,
  _ => Icons.key_rounded,
};
