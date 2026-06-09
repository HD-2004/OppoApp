import 'package:flutter/material.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../shared/presentation/widgets/network_asset_image.dart';

class HomeSidePoster extends StatelessWidget {
  const HomeSidePoster({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: NetworkAssetImage(
          url: S3AssetConfig.posterPhucLocTho,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(18),
          semanticLabel: 'Poster Phúc Lộc Thọ',
        ),
      ),
    );
  }
}
