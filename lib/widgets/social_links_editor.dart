import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/card_link.dart';

class SocialLinkDraft {
  final String id;
  final LinkType type;
  final String? originalTitle;
  final TextEditingController input;
  SocialLinkDraft({
    required this.type,
    String text = '',
    String? id,
    this.originalTitle,
  }) : id = id ?? const Uuid().v4(),
       input = TextEditingController(text: text);
  factory SocialLinkDraft.fromLink(CardLink link) {
    var value = link.url;
    final uri = Uri.tryParse(value);
    if (link.platform.usesUsername && uri != null) {
      final path = uri.pathSegments;
      if (link.platform == LinkType.linkedin &&
          path.length == 2 &&
          path.first == 'in') {
        value = path.last;
      } else if (link.platform != LinkType.linkedin && path.length == 1) {
        value = path.first.replaceFirst(RegExp(r'^@'), '');
      }
    }
    return SocialLinkDraft(
      type: link.platform,
      text: value,
      id: link.id,
      originalTitle: link.title,
    );
  }
  String? validate() {
    if (input.text.trim().isEmpty) return null;
    try {
      CardLink.normalizeInput(type, input.text);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  CardLink? get link => input.text.trim().isEmpty
      ? null
      : CardLink(
          id: id,
          title: originalTitle ?? type.label,
          type: type,
          url: CardLink.normalizeInput(type, input.text),
        );
  void dispose() => input.dispose();
  static List<CardLink> validLinks(List<SocialLinkDraft> drafts) => [
    for (final d in drafts)
      if (d.validate() == null && d.link != null) d.link!,
  ];
}

class SocialLinksEditor extends StatefulWidget {
  final List<SocialLinkDraft> drafts;
  final VoidCallback onChanged;
  const SocialLinksEditor({
    super.key,
    required this.drafts,
    required this.onChanged,
  });
  @override
  State<SocialLinksEditor> createState() => _SocialLinksEditorState();
}

class _SocialLinksEditorState extends State<SocialLinksEditor> {
  // Removed controllers remain alive until the old field has unmounted.
  final _removed = <SocialLinkDraft>[];
  @override
  void dispose() {
    for (final d in _removed) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Social profiles & websites'),
      const SizedBox(height: 6),
      const Text(
        'Enter a username for social profiles. We build the link. Websites can use a full address.',
      ),
      for (final d in widget.drafts)
        Padding(
          key: ValueKey(d.id),
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 15, right: 10),
                child: Icon(
                  CardLink(
                    id: 'icon',
                    title: '',
                    url: '',
                    type: d.type,
                  ).defaultIcon,
                  size: 22,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: d.input,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (_) => d.validate(),
                  onChanged: (_) => widget.onChanged(),
                  keyboardType: d.type.usesUsername
                      ? TextInputType.text
                      : TextInputType.url,
                  decoration: InputDecoration(
                    labelText: d.type.label,
                    hintText: d.type.usesUsername
                        ? 'Username, e.g. yourname'
                        : d.type == LinkType.whatsapp
                        ? 'Phone number with country code'
                        : 'https://yourwebsite.com',
                    helperText: d.type.usesUsername
                        ? 'Username only · a full profile link also works'
                        : null,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove ${d.type.label}',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    widget.drafts.remove(d);
                    _removed.add(d);
                  });
                  widget.onChanged();
                },
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: PopupMenuButton<LinkType>(
          tooltip: 'Add social profile or website',
          enabled: widget.drafts.length < 20,
          onSelected: (type) {
            setState(() => widget.drafts.add(SocialLinkDraft(type: type)));
            widget.onChanged();
          },
          itemBuilder: (_) => [
            for (final type in [
              LinkType.linkedin,
              LinkType.instagram,
              LinkType.youtube,
              LinkType.facebook,
              LinkType.twitter,
              LinkType.github,
              LinkType.telegram,
              LinkType.whatsapp,
              LinkType.website,
            ])
              PopupMenuItem(value: type, child: Text(type.label)),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_link),
                SizedBox(width: 8),
                Flexible(child: Text('Add social profile or website')),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
