import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chaser/config/colors.dart';
import 'package:chaser/models/player.dart';
import 'package:chaser/models/user_profile.dart';
import 'package:chaser/character/widgets/character_avatar.dart';
import 'package:chaser/screens/session/session_detail_screen.dart';

/// A horizontal scrollable track showing players positioned at their distances.
/// Auto-scrolls to center on the current user's position when first displayed.
class DistanceTrackWidget extends ConsumerStatefulWidget {
  final String sessionId;
  final List<PlayerModel> players;
  final String? currentUserId;
  final double? localDistance;

  const DistanceTrackWidget({
    super.key,
    required this.sessionId,
    required this.players,
    this.currentUserId,
    this.localDistance,
  });

  @override
  ConsumerState<DistanceTrackWidget> createState() => _DistanceTrackWidgetState();
}

class _DistanceTrackWidgetState extends ConsumerState<DistanceTrackWidget> {
  // Configuration
  static const double _trackHeight = 140.0;
  static const double _characterSize = 48.0;
  static const double _minCharacterSpacing = 60.0; // Minimum pixels between character centers
  static const double _trackPadding = 100.0; // Padding on left/right of track
  
  // Dynamic scaling based on distance spread
  late double _pixelsPerMeter;
  late double _chaserDistance;
  late double _maxRunnerDistance;
  late double _distanceSpread;

  void _calculateDistanceMetrics() {
    // Find chaser distance
    _chaserDistance = 0;
    _maxRunnerDistance = 0;
    
    for (final player in widget.players) {
      if (player.role == 'spectator' || player.captureState == 'captured') continue;
      
      final dist = _getPlayerDistance(player);
      
      if (player.role == 'chaser') {
        if (dist > _chaserDistance) _chaserDistance = dist;
      } else {
        if (dist > _maxRunnerDistance) _maxRunnerDistance = dist;
      }
    }
    
    // If no runners or chaser ahead, use absolute max distance
    if (_maxRunnerDistance <= _chaserDistance) {
      _maxRunnerDistance = _chaserDistance + 100; // Buffer
    }
    
    // Calculate spread from chaser to farthest runner
    _distanceSpread = _maxRunnerDistance - _chaserDistance;
    
    // Calculate dynamic scale: fit the spread into screen width
    // Use screen width minus padding for the spread
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (2 * _trackPadding) - _characterSize;
    
    // Scale so the spread fits nicely on screen
    // Minimum 0.2 pixels/meter (for very long distances), maximum 5 pixels/meter (for short)
    _pixelsPerMeter = (availableWidth / _distanceSpread).clamp(0.2, 5.0);
    
    // Ensure minimum spacing between players at same-ish distance
    // This is handled in _buildPlayerMarkers with offset stacking
  }

  double _getPlayerDistance(PlayerModel player) {
    return (widget.currentUserId != null && 
            player.userId == widget.currentUserId && 
            widget.localDistance != null)
        ? widget.localDistance!
        : player.currentDistance;
  }

  double _distanceToPixels(double distance) {
    // Position relative to chaser at left edge with padding
    return _trackPadding + ((distance - _chaserDistance) * _pixelsPerMeter);
  }

  double _getTrackWidth() {
    // Base width on distance spread plus padding
    final spreadPixels = _distanceSpread * _pixelsPerMeter;
    return spreadPixels + (2 * _trackPadding) + _characterSize;
  }

  @override
  Widget build(BuildContext context) {
    _calculateDistanceMetrics();
    final trackWidth = _getTrackWidth();

    return Container(
      height: _trackHeight,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.voidBlack.withOpacity(0.6),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
      ),
      child: InteractiveViewer(
        constrained: false,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(100),
        child: SizedBox(
          width: trackWidth,
          height: _trackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track line
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.textMuted.withOpacity(0.3),
                        AppColors.textMuted.withOpacity(0.6),
                        AppColors.textMuted.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Distance markers
              ..._buildDistanceMarkers(),
              
              // Player markers
              ..._buildPlayerMarkers(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDistanceMarkers() {
    final markers = <Widget>[];
    
    // Determine marker interval based on distance spread
    int interval;
    if (_distanceSpread < 200) {
      interval = 25;
    } else if (_distanceSpread < 500) {
      interval = 50;
    } else if (_distanceSpread < 2000) {
      interval = 100;
    } else if (_distanceSpread < 5000) {
      interval = 500;
    } else {
      interval = 1000;
    }
    
    // Start from chaser distance (rounded down to nearest interval)
    final startDist = ((_chaserDistance / interval).floor() * interval).toInt();
    final endDist = (_maxRunnerDistance + interval).toInt();
    
    for (int dist = startDist; dist <= endDist; dist += interval) {
      final xPos = _distanceToPixels(dist.toDouble());
      if (xPos < 0) continue;
      
      final isMajor = dist % (interval * 5) == 0 || dist == startDist;
      
      markers.add(
        Positioned(
          left: xPos - 1,
          bottom: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2,
                height: isMajor ? 24 : 12,
                color: isMajor 
                    ? AppColors.ghostWhite.withOpacity(0.6)
                    : AppColors.textMuted.withOpacity(0.4),
              ),
              if (isMajor) ...[
                const SizedBox(height: 2),
                Text(
                  _formatDistance(dist),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    return markers;
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters}m';
  }

  List<Widget> _buildPlayerMarkers() {
    final markers = <Widget>[];
    
    // Get active players sorted by distance
    final activePlayers = widget.players
        .where((p) => p.role != 'spectator' && p.captureState != 'captured')
        .toList()
      ..sort((a, b) => _getPlayerDistance(a).compareTo(_getPlayerDistance(b)));
    
    // Track positions to avoid overlapping - offset horizontally if too close
    final placedPositions = <double>[];
    
    for (int i = 0; i < activePlayers.length; i++) {
      final player = activePlayers[i];
      final distance = _getPlayerDistance(player);
      final xPos = _distanceToPixels(distance);
      
      // Count how many players are overlapping at this position
      int horizontalOffset = 0;
      for (final prevX in placedPositions) {
        if ((xPos - prevX).abs() < _minCharacterSpacing) {
          horizontalOffset++;
        }
      }
      placedPositions.add(xPos);
      
      // Offset overlapping players horizontally (side by side)
      final xOffset = horizontalOffset * (_characterSize + 4);
      
      markers.add(
        SmoothPlayerMarker(
          key: ValueKey(player.userId), 
          left: xPos - _characterSize / 2 + xOffset,
          bottom: 20,
          driver: player,
          distance: distance,
          size: _characterSize,
        ),
      );
    }
    
    return markers;
  }
}

class SmoothPlayerMarker extends StatefulWidget {
  final double left;
  final double bottom;
  final PlayerModel driver;
  final double distance;
  final double size;

  const SmoothPlayerMarker({
    super.key,
    required this.left,
    required this.bottom,
    required this.driver,
    required this.distance,
    required this.size,
  });

  @override
  State<SmoothPlayerMarker> createState() => _SmoothPlayerMarkerState();
}

class _SmoothPlayerMarkerState extends State<SmoothPlayerMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _leftAnimation;
  
  AnimationType _currentAnimType = AnimationType.idle;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 1000)
    );
    _leftAnimation = AlwaysStoppedAnimation(widget.left);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SmoothPlayerMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.left != oldWidget.left) {
       final start = _leftAnimation.value;
       final end = widget.left;
       
       // Calculate speed in meters/second
       // This assumes 1000ms duration
       final distDelta = (widget.distance - oldWidget.distance).abs();
       final speed = distDelta / 1.0; 
       
       if (speed < 0.2) {
          _currentAnimType = AnimationType.idle;
       } else if (speed < 2.5) {
         _currentAnimType = AnimationType.walk;
       } else {
         _currentAnimType = AnimationType.run;
       }

       _leftAnimation = Tween<double>(begin: start, end: end).animate(
         CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad)
       );
       
       _controller.forward(from: 0).whenComplete(() {
         if (mounted) {
           setState(() => _currentAnimType = AnimationType.idle);
         }
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _leftAnimation.value,
          bottom: widget.bottom,
          child: child!,
        );
      },
      child: _PlayerContent(
        player: widget.driver,
        distance: widget.distance,
        size: widget.size,
        animationType: _currentAnimType,
        cycleDuration: _currentAnimType == AnimationType.run 
            ? const Duration(milliseconds: 350)
            : _currentAnimType == AnimationType.walk 
                ? const Duration(milliseconds: 800)
                : const Duration(milliseconds: 2000), 
      ),
    );
  }
}

class _PlayerContent extends ConsumerWidget {
  final PlayerModel player;
  final double distance;
  final double size;
  final AnimationType animationType;
  final Duration cycleDuration;

  const _PlayerContent({
    required this.player,
    required this.distance,
    required this.size,
    required this.animationType,
    required this.cycleDuration,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileFamily(player.userId));
    final isChaser = player.role == 'chaser';
    final roleColor = isChaser ? AppColors.bloodRed : AppColors.pulseBlue;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name & distance bubble
        userProfileAsync.when(
          data: (userProfile) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userProfile.displayName.split(' ').first.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ghostWhite,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${distance.toStringAsFixed(0)}m',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7,
                    color: AppColors.ghostWhite.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox(height: 20),
          error: (_, __) => const SizedBox(height: 20),
        ),
        const SizedBox(height: 2),
        // Character avatar
        SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: userProfileAsync.when(
              data: (userProfile) => AnimatedCharacterAvatar(
                profile: userProfile.character,
                size: size,
                isAnimating: true,
                animationType: animationType,
                cycleDuration: cycleDuration,
              ),
              loading: () => Container(
                color: roleColor.withOpacity(0.3),
                child: Icon(
                  isChaser ? Icons.gps_fixed : Icons.directions_run,
                  color: roleColor,
                  size: size * 0.5,
                ),
              ),
              error: (_, __) => Container(
                color: roleColor.withOpacity(0.3),
                child: Icon(
                  isChaser ? Icons.gps_fixed : Icons.directions_run,
                  color: roleColor,
                  size: size * 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
