import 'package:bcalio/controllers/filter_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

class ColorPickerBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final FilterController controller = Get.find();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: ColorPicker(
        color: controller.customColor.value,
        onColorChanged: (Color color) {
          controller.applyCustomFilter(color);
        },
        pickersEnabled: const <ColorPickerType, bool>{
          ColorPickerType.both: true,
          ColorPickerType.primary: true,
          ColorPickerType.accent: true,
          ColorPickerType.bw: true,
          ColorPickerType.custom: true,
          ColorPickerType.wheel: true,
        },
        width: 40,
        height: 40,
        borderRadius: 4,
        spacing: 5,
        runSpacing: 5,
        wheelDiameter: 200,
        heading: Text(
          'Select filter color',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subheading: Text(
          'Select color shade',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        wheelSubheading: Text(
          'Selected color and its shades',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        showMaterialName: true,
        showColorName: true,
        showColorCode: true,
        copyPasteBehavior: const ColorPickerCopyPasteBehavior(
          longPressMenu: true,
        ),
        recentColors: const <Color>[
          Colors.red,
          Colors.green,
          Colors.blue,
          Colors.yellow,
          Colors.purple,
        ],
        pickerTypeLabels: const <ColorPickerType, String>{
          ColorPickerType.primary: 'Primary',
          ColorPickerType.accent: 'Accent',
          ColorPickerType.both: 'Both',
          ColorPickerType.bw: 'B&W',
          ColorPickerType.custom: 'Custom',
          ColorPickerType.wheel: 'Wheel',
        },
        // customColorSwatchesAndNames: const <ColorSwatch<Object>, String>{
        //   Colors.red: 'Red',
        //   Colors.pink: 'Pink',
        //   Colors.purple: 'Purple',
        //   Colors.deepPurple: 'Deep Purple',
        //   Colors.blue: 'Blue',
        //   Colors.lightBlue: 'Light Blue',
        //   Colors.cyan: 'Cyan',
        //   Colors.teal: 'Teal',
        //   Colors.green: 'Green',
        //   Colors.lightGreen: 'Light Green',
        //   Colors.lime: 'Lime',
        //   Colors.yellow: 'Yellow',
        //   Colors.amber: 'Amber',
        //   Colors.orange: 'Orange',
        //   Colors.deepOrange: 'Deep Orange',
        //   Colors.brown: 'Brown',
        //   Colors.blueGrey: 'Blue Grey',
        // },
   
   
      ),
    );
  }
}