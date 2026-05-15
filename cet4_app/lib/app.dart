import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'provider/navigation_provider.dart';
import 'provider/user_provider.dart';
import 'services/notification_service.dart';
import 'pages/home/home_page.dart';
import 'pages/vocabulary/vocabulary_page.dart';
import 'pages/vocabulary/word_study_page.dart';
import 'pages/question_bank/exam_home_page.dart';
import 'pages/ai_assistant/ai_assistant_page.dart';
import 'pages/profile/profile_page.dart';

class Cet4App extends StatelessWidget {
  const Cet4App({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return MaterialApp(
      title: 'CET4',
      debugShowCheckedModeBanner: false,
      themeMode: userProvider.themeMode,
      theme: _buildLightTheme(userProvider.fontSize),
      darkTheme: _buildDarkTheme(userProvider.fontSize),
      home: const MainScreen(),
    );
  }

  ThemeData _buildLightTheme(double fontSize) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF165DFF),
        primaryContainer: Color(0xFFE8F0FE),
        secondary: Color(0xFF64748B),
        secondaryContainer: Color(0xFFF1F5F9),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFF8FAFC),
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1E293B),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: const Color(0xFFFFFFFF),
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF1E293B),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
          letterSpacing: 0,
        ),
        shape: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        selectedItemColor: Color(0xFF165DFF),
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
      ),
      textTheme: _buildTextTheme(fontSize, Brightness.light),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF165DFF),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFF165DFF), width: 1.5),
          foregroundColor: const Color(0xFF165DFF),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF165DFF),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF165DFF), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: Color(0xFFF1F5F9),
        selectedColor: Color(0xFF165DFF),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide.none,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF1E293B),
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        minLeadingWidth: 32,
      ),
    );
  }

  ThemeData _buildDarkTheme(double fontSize) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5B8DEF),
        primaryContainer: Color(0xFF1A3A6E),
        secondary: Color(0xFF94A3B8),
        secondaryContainer: Color(0xFF1E293B),
        surface: Color(0xFF0F172A),
        surfaceVariant: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
        onPrimary: Color(0xFF0F172A),
        onSecondary: Color(0xFF0F172A),
        onSurface: Color(0xFFF1F5F9),
        onError: Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: const Color(0xFF1E293B),
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Color(0xFFF1F5F9),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF1F5F9),
          letterSpacing: 0,
        ),
        shape: Border(
          bottom: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        selectedItemColor: Color(0xFF5B8DEF),
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
      ),
      textTheme: _buildTextTheme(fontSize, Brightness.dark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF5B8DEF),
          foregroundColor: const Color(0xFF0F172A),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFF5B8DEF), width: 1.5),
          foregroundColor: const Color(0xFF5B8DEF),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF5B8DEF),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF334155), width: 1),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF334155), width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF5B8DEF), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
        space: 1,
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: Color(0xFF1E293B),
        selectedColor: Color(0xFF5B8DEF),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide.none,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFF1F5F9),
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        minLeadingWidth: 32,
      ),
    );
  }

  TextTheme _buildTextTheme(double scale, Brightness brightness) {
    final base = brightness == Brightness.light
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
    final secondary = brightness == Brightness.light
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);
    final tertiary = brightness == Brightness.light
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return TextTheme(
      displayLarge: TextStyle(fontSize: 40 * scale, fontWeight: FontWeight.w700, color: base, letterSpacing: -1, height: 1.1),
      displayMedium: TextStyle(fontSize: 32 * scale, fontWeight: FontWeight.w600, color: base, letterSpacing: -0.5, height: 1.2),
      displaySmall: TextStyle(fontSize: 28 * scale, fontWeight: FontWeight.w700, color: const Color(0xFF165DFF), letterSpacing: -0.5, height: 1.2),
      headlineLarge: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w600, color: base, letterSpacing: 0, height: 1.3),
      headlineMedium: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w600, color: base, letterSpacing: 0, height: 1.3),
      headlineSmall: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.w500, color: base, letterSpacing: 0, height: 1.4),
      titleLarge: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w500, color: base, letterSpacing: 0, height: 1.4),
      titleMedium: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500, color: base, letterSpacing: 0, height: 1.4),
      titleSmall: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w400, color: secondary, letterSpacing: 0, height: 1.4),
      bodyLarge: TextStyle(fontSize: 16 * scale, color: base, height: 1.7, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14 * scale, color: secondary, height: 1.6, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12 * scale, color: tertiary, height: 1.5, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600, color: base, letterSpacing: 0),
      labelMedium: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0),
      labelSmall: TextStyle(fontSize: 10 * scale, fontWeight: FontWeight.w400, color: tertiary, letterSpacing: 0),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService().onNotificationTap = (target) {
      if (!mounted) return;
      final navProvider = context.read<NavigationProvider>();
      switch (target) {
        case NotificationTarget.home:
          navProvider.goToHome();
          break;
        case NotificationTarget.vocabulary:
          navProvider.goToVocabulary();
          break;
        case NotificationTarget.wordStudy:
          navProvider.goToVocabulary();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WordStudyPage()),
          );
          break;
        case NotificationTarget.review:
          navProvider.goToVocabulary();
          break;
      }
    };
  }

  @override
  void dispose() {
    NotificationService().onNotificationTap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      const HomePage(),
      const VocabularyPage(),
      const ExamHomePage(),
      const AiAssistantPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: pages[navProvider.currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '首页', index: 0),
                _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: '词汇', index: 1),
                _NavItem(icon: Icons.quiz_outlined, activeIcon: Icons.quiz, label: '题库', index: 2),
                _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'AI', index: 3),
                _NavItem(icon: Icons.person_outlined, activeIcon: Icons.person, label: '我的', index: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.index});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final isSelected = navProvider.currentIndex == widget.index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        navProvider.setIndex(widget.index);
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? widget.activeIcon : widget.icon,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.35),
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.35),
                      letterSpacing: 0.5,
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
