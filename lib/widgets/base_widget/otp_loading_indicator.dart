import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';

class OtpLoadingIndicator extends StatelessWidget {
  const OtpLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalBarrier(
          dismissible: false,
          color: Colors.black.withOpacity(0.7),
        ),
        Center(
          child: SizedBox(
            height: 80,
            width: 80,
            child: LoadingIndicator(
              indicatorType: Indicator.lineScale,
              colors: [Colors.white],
              strokeWidth: 2,
              backgroundColor: Colors.transparent,
              pathBackgroundColor: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
