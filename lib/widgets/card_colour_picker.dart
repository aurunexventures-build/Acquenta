import 'package:flutter/material.dart';

class CardColourPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const CardColourPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: Icon(
      Icons.palette_outlined,
      color: Color(int.parse(value.substring(1), radix: 16) | 0xFF000000),
    ),
    label: const Text('Choose any colour'),
    onPressed: () async {
      final selected = await showDialog<String>(
        context: context,
        builder: (_) => _ColourDialog(value: value),
      );
      if (selected != null) onChanged(selected);
    },
  );
}

class _ColourDialog extends StatefulWidget {
  final String value;
  const _ColourDialog({required this.value});
  @override
  State<_ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends State<_ColourDialog> {
  late HSVColor _colour;
  late TextEditingController _hex;
  String? _error;
  String get hex =>
      '#${_colour.toColor().toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  @override
  void initState() {
    super.initState();
    _colour = HSVColor.fromColor(
      Color(int.parse(widget.value.substring(1), radix: 16) | 0xFF000000),
    );
    _hex = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void change(HSVColor colour) => setState(() {
    _colour = colour;
    _hex.text = hex;
    _error = null;
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Card colour'),
    content: SizedBox(
      width: 300,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _colour.toColor(),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Hue')),
            Slider(
              value: _colour.hue,
              max: 360,
              activeColor: _colour.toColor(),
              onChanged: (v) => change(_colour.withHue(v)),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Saturation'),
            ),
            Slider(
              value: _colour.saturation,
              onChanged: (v) => change(_colour.withSaturation(v)),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Brightness'),
            ),
            Slider(
              value: _colour.value,
              onChanged: (v) => change(_colour.withValue(v)),
            ),
            TextField(
              controller: _hex,
              decoration: InputDecoration(
                labelText: 'Hex colour',
                hintText: '#2563EB',
                errorText: _error,
              ),
              onChanged: (value) {
                final raw = value.replaceAll('#', '');
                if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) {
                  setState(() {
                    _colour = HSVColor.fromColor(
                      Color(int.parse(raw, radix: 16) | 0xFF000000),
                    );
                    _error = null;
                  });
                } else {
                  setState(() => _error = 'Enter six hex digits');
                }
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _error != null ? null : () => Navigator.pop(context, hex),
        child: const Text('Use colour'),
      ),
    ],
  );
}
