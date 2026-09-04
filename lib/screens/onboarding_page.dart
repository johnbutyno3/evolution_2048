import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../game/services/save_manager.dart';
import 'profile_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<_OnboardingItem> _pages(AppLocalizations l10n) {
    return [
      _OnboardingItem(
        imagePath: 'assets/onboarding/onboarding_01.png',
        title: l10n.onboarding01Title,
        description: l10n.onboarding01Description,
      ),
      _OnboardingItem(
        imagePath: 'assets/onboarding/onboarding_02.png',
        title: l10n.onboarding02Title,
        description: l10n.onboarding02Description,
      ),
      _OnboardingItem(
        imagePath: 'assets/onboarding/onboarding_03.png',
        title: l10n.onboarding03Title,
        description: l10n.onboarding03Description,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await SaveManager.completeOnboarding();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _pages(l10n);
    final isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final page = pages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(page.imagePath, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 0.72, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 48, 28, 105),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              shadows: [
                                Shadow(
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.45,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 82,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: index == _currentPage
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _nextPage,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
                child: Text(
                  isLastPage ? l10n.onboardingStart : l10n.onboardingNext,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  final String imagePath;
  final String title;
  final String description;

  const _OnboardingItem({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}
