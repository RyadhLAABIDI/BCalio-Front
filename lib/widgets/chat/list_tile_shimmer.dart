import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ListTileShimmer extends StatelessWidget {
  final int count; // Number of shimmer tiles to display
  const ListTileShimmer({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = count.isEven
        ? Colors.grey.withOpacity(0.3)
        : Colors.grey.withOpacity(0.2);
    final highlight = count.isEven
        ? Colors.grey.withOpacity(0.4)
        : Colors.grey.withOpacity(0.3);

    return ListView.builder(
      itemCount: count,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar Placeholder with Shimmer
              Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: base,
                ),
              ),
              const SizedBox(width: 16),

              // Name + Last Message Placeholder with Shimmer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender Name Placeholder with Shimmer
                    Shimmer.fromColors(
                      baseColor: base,
                      highlightColor: highlight,
                      child: Container(
                          width: 100,
                          height: 20,
                          decoration: BoxDecoration(
                            color: highlight,
                            borderRadius: BorderRadius.circular(8),
                          )),
                    ),
                    const SizedBox(height: 4),
                    // Last Message Placeholder with Shimmer
                    Row(
                      children: [
                        Expanded(
                          child: Shimmer.fromColors(
                            baseColor: base,
                            highlightColor: highlight,
                            child: Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  color: base,
                                  borderRadius: BorderRadius.circular(8),
                                )),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Seen Indicator Placeholder with Shimmer
                        Shimmer.fromColors(
                          baseColor: base,
                          highlightColor: highlight,
                          child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: highlight,
                                borderRadius: BorderRadius.circular(8),
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Time Placeholder with Shimmer
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Shimmer.fromColors(
                    baseColor: base,
                    highlightColor: highlight,
                    child: Container(
                        width: 40,
                        height: 13,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(8),
                        )),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
