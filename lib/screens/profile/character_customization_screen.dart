import 'package:chaser/config/colors.dart';
import 'package:chaser/models/character/character_profile.dart';
import 'package:chaser/character/widgets/character_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chaser/providers/user_provider.dart';
import 'package:chaser/services/firebase/firestore_service.dart';

/// A wrapper that connects [CharacterCustomizationScreen] to Riverpod and Firestore
class ConnectedCharacterCustomizationScreen extends ConsumerWidget {
  const ConnectedCharacterCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (userProfile) {
        if (userProfile == null) {
          return const Scaffold(
            backgroundColor: AppColors.voidBlack,
            body: Center(child: Text("Profile not found", style: TextStyle(color: Colors.white))),
          );
        }
        return CharacterCustomizationScreen(
          initialProfile: userProfile.character,
          onSave: (newProfile) async {
             await FirestoreService().updateCharacterProfile(userProfile.uid, newProfile);
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Character saved successfully.')),
               );
             }
          },
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.voidBlack,
        body: Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.voidBlack,
        body: Center(child: Text("Error: $err", style: const TextStyle(color: AppColors.bloodRed))),
      ),
    );
  }
}

/// Customization tabs
enum CustomizationTab { parts, animations }

class CharacterCustomizationScreen extends ConsumerStatefulWidget {
  final CharacterProfile initialProfile;
  final Function(CharacterProfile) onSave;

  const CharacterCustomizationScreen({
    super.key,
    required this.initialProfile,
    required this.onSave,
  });

  @override
  ConsumerState<CharacterCustomizationScreen> createState() => _CharacterCustomizationScreenState();
}

class _CharacterCustomizationScreenState extends ConsumerState<CharacterCustomizationScreen> {
  late CharacterProfile _currentProfile;
  CharacterPart _selectedPart = CharacterPart.head;
  CustomizationTab _selectedTab = CustomizationTab.parts;
  String _selectedAnimation = 'idle'; // Currently selected animation

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.initialProfile;
    // Ensure partSkins is populated with defaults if empty
    if (_currentProfile.partSkins.isEmpty) {
      _currentProfile = _currentProfile.copyWith(
        partSkins: {for (var part in CharacterPart.values) part: 'default'},
      );
    }
  }

  void _updatePartSkin(CharacterPart part, String skinId) {
    setState(() {
      _currentProfile = _currentProfile.withPartSkin(part, skinId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        backgroundColor: AppColors.voidBlack,
        title: Text(
          'CUSTOMIZE',
          style: GoogleFonts.creepster(fontSize: 24, letterSpacing: 2, color: AppColors.ghostWhite),
        ),
        actions: [
          TextButton(
            onPressed: () {
               widget.onSave(_currentProfile);
               Navigator.pop(context);
            },
            child: Text(
              'SAVE',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                color: AppColors.bloodRed,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Selector
          _buildTabSelector(),
          
          // Content based on selected tab
          Expanded(
            child: _selectedTab == CustomizationTab.parts
                ? _buildPartsContent()
                : _buildAnimationsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.fogGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              'PARTS',
              CustomizationTab.parts,
              Icons.extension,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              'ANIMATIONS',
              CustomizationTab.animations,
              Icons.animation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, CustomizationTab tab, IconData icon) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bloodRed : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.ghostWhite : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.ghostWhite : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartsContent() {
    return Column(
      children: [
        // Preview Area
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.fogGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: CharacterAvatar(profile: _currentProfile, size: 200),
          ),
        ),

        // Part Selector (horizontal scrollable)
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: CharacterPart.values.length,
            itemBuilder: (context, index) {
              final part = CharacterPart.values[index];
              final isSelected = part == _selectedPart;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(
                    part.displayName.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.voidBlack : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.bloodRed,
                  backgroundColor: AppColors.fogGrey,
                  onSelected: (_) => setState(() => _selectedPart = part),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Skin Options Grid
        Expanded(
          flex: 2,
          child: _buildSkinGrid(_selectedPart),
        ),
      ],
    );
  }

  Widget _buildAnimationsContent() {
    // Available animations
    const animations = [
      {'id': 'idle', 'name': 'IDLE', 'icon': Icons.accessibility_new},
      {'id': 'walking', 'name': 'WALKING', 'icon': Icons.directions_walk},
      {'id': 'running', 'name': 'RUNNING', 'icon': Icons.directions_run},
    ];

    return Column(
      children: [
        // Animated Preview Area
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.fogGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: AnimatedCharacterAvatar(
              profile: _currentProfile,
              size: 200,
              isAnimating: true,
              animationType: _getAnimationType(_selectedAnimation),
              cycleDuration: _getAnimationDuration(_selectedAnimation),
            ),
          ),
        ),

        // Animation Selector
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANIMATION STYLE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: animations.length,
                    itemBuilder: (context, index) {
                      final anim = animations[index];
                      final isSelected = anim['id'] == _selectedAnimation;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAnimation = anim['id'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.bloodRed.withOpacity(0.2) : AppColors.fogGrey,
                            border: Border.all(
                              color: isSelected ? AppColors.bloodRed : AppColors.textMuted.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                anim['icon'] as IconData,
                                color: isSelected ? AppColors.bloodRed : AppColors.textSecondary,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                anim['name'] as String,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.ghostWhite : AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.bloodRed,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkinGrid(CharacterPart part) {
    final currentSkin = _currentProfile.partSkins[part] ?? 'default';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${part.displayName.toUpperCase()} SKIN',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: availableSkins.length,
              itemBuilder: (context, index) {
                final skinId = availableSkins[index];
                final isSelected = skinId == currentSkin;
                final assetPath = 'assets/characters/$skinId/${part.fileName}';

                return GestureDetector(
                  onTap: () => _updatePartSkin(part, skinId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.bloodRed.withOpacity(0.2) : AppColors.fogGrey,
                      border: Border.all(
                        color: isSelected ? AppColors.bloodRed : AppColors.textMuted.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                color: AppColors.textMuted,
                                size: 32,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          skinId.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.ghostWhite : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AnimationType _getAnimationType(String animId) {
    switch (animId) {
      case 'idle': return AnimationType.idle;
      case 'walking': return AnimationType.walk;
      case 'running': return AnimationType.run;
      default: return AnimationType.idle;
    }
  }

  Duration _getAnimationDuration(String animId) {
    switch (animId) {
      case 'idle': return const Duration(milliseconds: 2000); // Slow, subtle
      case 'walking': return const Duration(milliseconds: 800);
      case 'running': return const Duration(milliseconds: 350);
      default: return const Duration(milliseconds: 2000);
    }
  }
}

