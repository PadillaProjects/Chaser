import 'dart:math';
import 'package:flutter/material.dart';
import '../character/widgets/character_avatar.dart';
import '../models/character/character_profile.dart'; // Verified path
import '../character/layout/character_layout.dart'; // import layout to use characterLayout map keys in animation

class CharacterVerificationScreen extends StatefulWidget {
  const CharacterVerificationScreen({super.key});

  @override
  State<CharacterVerificationScreen> createState() => _CharacterVerificationScreenState();
}

class _CharacterVerificationScreenState extends State<CharacterVerificationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _size = 256.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(title: const Text('Character Verification')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Simple idle-ish animation to test pivots
                  final t = _controller.value;
                  final rotation = sin(t * pi * 2); 

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red),
                    ),
                    child: CharacterAvatar(
                      profile: CharacterProfile.runnerBlue(),
                      size: _size,
                      animationRotation: {
                        CharacterPart.upperArm: sin(t * pi) * 0.2,
                        CharacterPart.lowerArm: sin(t * pi) * 0.4,
                         // Add more parts if needed
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Size: ${_size.toStringAsFixed(0)}'),
                Slider(
                  min: 50,
                  max: 512,
                  value: _size,
                  onChanged: (v) => setState(() => _size = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
