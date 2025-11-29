import 'package:flutter/material.dart';

/// A shimmer loading skeleton widget
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Use theme surface colors with slight opacity variations
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor = colorScheme.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                0.0,
                _animation.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for anime info section
class AnimeInfoSkeleton extends StatelessWidget {
  const AnimeInfoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Skeleton(
            width: 250,
            height: 28,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          // Rating and type chips
          Row(
            children: [
              Skeleton(
                width: 60,
                height: 20,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(width: 16),
              Skeleton(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 8),
              Skeleton(
                width: 100,
                height: 32,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Episodes info
          Skeleton(
            width: 200,
            height: 16,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 12),
          // Genre chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              5,
              (index) => Skeleton(
                width: 60 + (index * 10.0),
                height: 32,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Synopsis title
          Skeleton(
            width: 100,
            height: 22,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          // Synopsis lines
          Skeleton(
            width: double.infinity,
            height: 16,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          Skeleton(
            width: double.infinity,
            height: 16,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          Skeleton(
            width: 250,
            height: 16,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for episode list
class EpisodeListSkeleton extends StatelessWidget {
  const EpisodeListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Header
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Skeleton(
                width: 150,
                height: 24,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }

          // Episode items - wrapped in Card to match real UI
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    Skeleton(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Skeleton(
                        height: 16,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Skeleton(
                      width: 24,
                      height: 24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: 6, // Show 5 episode skeletons + header
      ),
    );
  }
}

/// Skeleton loader for recommendations section
class RecommendationsSkeleton extends StatelessWidget {
  const RecommendationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 140,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(
                    width: 140,
                    height: 160,
                    borderRadius: BorderRadius.zero, // Card clips the border
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(
                          width: 110,
                          height: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Skeleton(
                          width: 80,
                          height: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
