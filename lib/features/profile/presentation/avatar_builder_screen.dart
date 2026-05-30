import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import 'package:go_router/go_router.dart';

class AvatarBuilderScreen extends ConsumerStatefulWidget {
  const AvatarBuilderScreen({super.key});

  @override
  ConsumerState<AvatarBuilderScreen> createState() => _AvatarBuilderScreenState();
}

class _AvatarBuilderScreenState extends ConsumerState<AvatarBuilderScreen> {
  // DiceBear Avataaars Options
  final List<String> topTypes = [
    'NoHair', 'Eyepatch', 'Hat', 'Hijab', 'Turban', 'WinterHat1', 'WinterHat2', 'WinterHat3', 
    'WinterHat4', 'LongHairBigHair', 'LongHairBob', 'LongHairBun', 'LongHairCurly', 'LongHairCurvy', 
    'LongHairDreads', 'LongHairFrida', 'LongHairFro', 'LongHairFroBand', 'LongHairNotTooLong', 
    'LongHairShavedSides', 'LongHairMiaWallace', 'LongHairStraight', 'LongHairStraight2', 
    'LongHairStraightStrand', 'ShortHairDreads01', 'ShortHairDreads02', 'ShortHairFrizzle', 
    'ShortHairShaggyMullet', 'ShortHairShortCurly', 'ShortHairShortFlat', 'ShortHairShortRound', 
    'ShortHairShortWaved', 'ShortHairSides', 'ShortHairTheCaesar', 'ShortHairTheCaesarSidePart'
  ];

  final List<String> hairColors = [
    'Auburn', 'Black', 'Blonde', 'BlondeGolden', 'Brown', 'BrownDark', 'PastelPink', 'Platinum', 'Red', 'SilverGray'
  ];

  final List<String> facialHairs = [
    'Blank', 'BeardMedium', 'BeardLight', 'BeardMajestic', 'MoustacheFancy', 'MoustacheMagnum'
  ];

  final List<String> skinColors = [
    'Tanned', 'Yellow', 'Pale', 'Light', 'Brown', 'DarkBrown', 'Black'
  ];

  final List<String> eyesTypes = [
    'Close', 'Cry', 'Default', 'Dizzy', 'EyeRoll', 'Happy', 'Hearts', 'Side', 'Squint', 'Surprised', 'Wink', 'WinkWacky'
  ];

  // Current selections
  String _topType = 'ShortHairShortFlat';
  String _hairColor = 'BrownDark';
  String _facialHair = 'Blank';
  String _skinColor = 'Light';
  String _eyesType = 'Default';

  bool _isSaving = false;

  String get _avatarUrl {
    return 'https://api.dicebear.com/7.x/avataaars/svg?top=$_topType&hairColor=$_hairColor&facialHair=$_facialHair&skinColor=$_skinColor&eyes=$_eyesType&backgroundColor=c0aede,b6e3f4,d1d4f9,ffd5dc,ffdfbf';
  }

  void _saveAvatar() async {
    setState(() => _isSaving = true);
    final settingsDao = ref.read(settingsDaoProvider);
    await settingsDao.setSetting('profile_avatar_url', _avatarUrl);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creador de Avatar')),
      body: Column(
        children: [
          const SizedBox(height: 32),
          // Preview
          Center(
            child: Hero(
              tag: 'avatar_profile',
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                child: SvgPicture.network(
                  _avatarUrl,
                  width: 160,
                  height: 160,
                  placeholderBuilder: (context) => const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Controls
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _OptionSelector(
                    label: 'Cabello / Accesorio',
                    options: topTypes,
                    value: _topType,
                    onChanged: (v) => setState(() => _topType = v!),
                  ),
                  _OptionSelector(
                    label: 'Color de Cabello',
                    options: hairColors,
                    value: _hairColor,
                    onChanged: (v) => setState(() => _hairColor = v!),
                  ),
                  _OptionSelector(
                    label: 'Tono de Piel',
                    options: skinColors,
                    value: _skinColor,
                    onChanged: (v) => setState(() => _skinColor = v!),
                  ),
                  _OptionSelector(
                    label: 'Vello Facial',
                    options: facialHairs,
                    value: _facialHair,
                    onChanged: (v) => setState(() => _facialHair = v!),
                  ),
                  _OptionSelector(
                    label: 'Ojos',
                    options: eyesTypes,
                    value: _eyesType,
                    onChanged: (v) => setState(() => _eyesType = v!),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAvatar,
                      child: _isSaving 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Guardar Avatar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _OptionSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String?> onChanged;

  const _OptionSelector({required this.label, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: value,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
