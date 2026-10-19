import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/color_shader.dart';
import '../models/edit_params.dart';
import '../state/providers.dart';
import '../widgets/param_slider.dart';
import '../widgets/suggestion_card.dart';

const _labels = <String, String>{
  'exposure': '曝光',
  'contrast': '对比度',
  'temperature': '色温',
  'tint': '色调',
  'saturation': '饱和度',
  'vibrance': '鲜艳度',
  'highlights': '高光',
  'shadows': '阴影',
};

class EditScreen extends ConsumerWidget {
  final ui.Image? image;
  final ColorShader? colorShader;

  const EditScreen({super.key, this.image, this.colorShader});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(editParamsProvider);
    final notifier = ref.read(editParamsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('编辑'), actions: [
        TextButton(onPressed: () {}, child: const Text('导出')),
      ]),
      body: Column(
        children: [
          Expanded(
            child: image == null || colorShader == null
                ? const Center(child: Text('无图像'))
                : ShaderPreview(image: image!, params: params, colorShader: colorShader!),
          ),
          const SuggestionCard(),
          Expanded(
            flex: 2,
            child: ListView(
              children: EditParams.paramNames.map((name) {
                return ParamSlider(
                  name: name,
                  label: _labels[name] ?? name,
                  value: params[name],
                  onChanged: (v) => notifier.updateParam(name, v),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
