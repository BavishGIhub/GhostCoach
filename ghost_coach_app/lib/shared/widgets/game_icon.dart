import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GameIcon extends StatelessWidget {
  final String gameType;
  final double size;
  final Color? color;

  const GameIcon({
    super.key,
    required this.gameType,
    this.size = 24,
    this.color,
  });

  static String assetPath(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'fortnite':
        return 'assets/icons/fortnite.svg';
      case 'valorant':
        return 'assets/icons/valorant.svg';
      case 'warzone':
        return 'assets/icons/warzone.svg';
      case 'soccer':
        return 'assets/icons/soccer.svg';
      default:
        return 'assets/icons/game_general.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath(gameType),
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
