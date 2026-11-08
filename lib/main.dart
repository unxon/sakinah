import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_database.dart';
import 'data/local_repository.dart';
import 'security/backup_service.dart';
import 'security/sensitive_field_codec.dart';
import 'security/secure_vault.dart';

const ink = Color(0xFF173B3F);
const cream = Color(0xFFF4F1E9);
const card = Color(0xFFFFFDF7);
const sage = Color(0xFFD8E6DC);
const accent = Color(0xFFC47C58);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final vault = SecureVault();
  final storedKey = await vault.readDataKey();
  AppDatabase database;
  if (storedKey == null) {
    final probe = await AppDatabase.open();
    final hasEncryptedData = await probe.hasEncryptedData();
    await probe.close();
    if (hasEncryptedData) {
      runApp(const KeyRecoveryApp());
      return;
    }
    final dataKey = base64Url.decode(await vault.createDataKey());
    database = await AppDatabase.open(codec: SensitiveFieldCodec(dataKey));
  } else {
    final dataKey = base64Url.decode(storedKey);
    database = await AppDatabase.open(codec: SensitiveFieldCodec(dataKey));
  }
  final store = LocalStore(
    await SharedPreferences.getInstance(),
    database: database,
    repository: LocalRepository(database),
  );
  await store.hydrateFromDatabase();
  runApp(SerenityApp(store: store));
}

class KeyRecoveryApp extends StatelessWidget {
  const KeyRecoveryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: ink),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_reset, size: 64, color: ink),
                const SizedBox(height: 20),
                const Text(
                  'تعذر فتح بياناتك المشفّرة',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'لم ينشئ سكون مفتاحًا جديدًا فوق بياناتك القديمة. استعد نسخة سكون المشفّرة من إعدادات النسخ الاحتياطي أو تواصل مع الدعم قبل حذف التطبيق.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LocalStore extends ChangeNotifier {
  LocalStore(this._prefs, {this._database, this._repository})
    : sessions = _prefs.getInt('completed_sessions') ?? 0,
      journal = _prefs.getString('journal') ?? '',
      mood = _prefs.getString('mood') ?? '',
      darkMode = _prefs.getBool('dark_mode') ?? false,
      reducedMotion = _prefs.getBool('reduced_motion') ?? false,
      onboardingComplete = _prefs.getBool('onboarding_complete') ?? false;
  final SharedPreferences _prefs;
  final AppDatabase? _database;
  final LocalRepository? _repository;
  BackupService? get backupService {
    final repository = _repository;
    return repository == null ? null : BackupService(repository);
  }

  int sessions;
  String journal;
  String mood;
  bool darkMode;
  bool reducedMotion;
  bool onboardingComplete;

  Future<void> hydrateFromDatabase() async {
    final summary = await _repository?.loadSummary();
    if (summary == null) return;
    sessions = summary.sessions;
    if (summary.latestJournal != null) journal = summary.latestJournal!;
    if (summary.latestMood != null) mood = summary.latestMood!;
  }

  Future<void> saveJournal(String value, String selectedMood) async {
    journal = value.trim();
    mood = selectedMood;
    await _prefs.setString('journal', journal);
    await _prefs.setString('mood', mood);
    await _database?.saveReflection(
      id: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
      body: journal,
      mood: mood,
    );
    notifyListeners();
  }

  Future<void> completeSession() async {
    sessions++;
    await _prefs.setInt('completed_sessions', sessions);
    await _database?.recordSession(
      id: '${DateTime.now().toUtc().millisecondsSinceEpoch}-$sessions',
      kind: 'guided_reflection',
      durationSeconds: 300,
    );
    notifyListeners();
  }

  Future<void> saveMood(String value) async {
    mood = value;
    await _prefs.setString('mood', mood);
    await _database?.recordMood(
      id: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
      mood: mood,
    );
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    onboardingComplete = true;
    await _prefs.setBool('onboarding_complete', true);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    await _prefs.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setReducedMotion(bool value) async {
    reducedMotion = value;
    await _prefs.setBool('reduced_motion', value);
    notifyListeners();
  }

  Future<void> deleteAllData() async {
    await _repository?.deleteAllData();
    await _prefs.remove('completed_sessions');
    await _prefs.remove('journal');
    await _prefs.remove('mood');
    sessions = 0;
    journal = '';
    mood = '';
    notifyListeners();
  }
}

class SerenityApp extends StatelessWidget {
  const SerenityApp({super.key, required this.store});
  final LocalStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سكون',
      theme: ThemeData(
        useMaterial3: true,
        brightness: store.darkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: store.darkMode
            ? const Color(0xFF102A2D)
            : cream,
        colorScheme: ColorScheme.fromSeed(seedColor: ink),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: ink,
          elevation: 0,
        ),
      ),
      home: SplashGate(store: store),
    ),
  );
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.store});
  final LocalStore store;
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: Future<void>.delayed(const Duration(milliseconds: 850)),
    builder: (_, snapshot) => snapshot.connectionState != ConnectionState.done
        ? Scaffold(
            backgroundColor: ink,
            body: Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: controller,
                  curve: Curves.easeOutBack,
                ),
                child: const AppMark(large: true),
              ),
            ),
          )
        : widget.store.onboardingComplete
        ? HomePage(store: widget.store)
        : WelcomePage(store: widget.store),
  );
}

class AppMark extends StatelessWidget {
  const AppMark({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Container(
    width: large ? 104 : 52,
    height: large ? 104 : 52,
    decoration: BoxDecoration(
      color: const Color(0xFFE7EFE6),
      borderRadius: BorderRadius.circular(large ? 32 : 16),
    ),
    child: Icon(Icons.spa_rounded, color: ink, size: large ? 58 : 30),
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Center(child: AppMark(large: true)),
                const SizedBox(height: 36),
                const Text(
                  'مرحبًا بك في سكون',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'مساحة شخصية تساعدك على التمهّل، التنفّس، وملاحظة ما يحدث بداخلك — بهدوء ومن دون أحكام.',
                  style: TextStyle(
                    color: Color(0xFFD7E3DB),
                    fontSize: 17,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                const PrivacyNote(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await store.finishOnboarding();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => HomePage(store: store),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('ابدأ مساحتك الهادئة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0x1FFFFFFF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Icon(Icons.shield_outlined, color: Color(0xFFD7E3DB)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'يعمل دون اتصال. لا حسابات، لا إعلانات، ولا تتبّع. ملاحظاتك تبقى على جهازك.',
            style: TextStyle(color: Color(0xFFD7E3DB), height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final LocalStore store;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(store: widget.store, onOpen: (i) => setState(() => index = i)),
      SessionTab(store: widget.store),
      BreathingTab(store: widget.store),
      JournalTab(store: widget.store),
      ProgressTab(store: widget.store),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(index: index, children: pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          backgroundColor: card,
          indicatorColor: sage,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.self_improvement_outlined),
              selectedIcon: Icon(Icons.self_improvement),
              label: 'جلسة',
            ),
            NavigationDestination(
              icon: Icon(Icons.air_outlined),
              selectedIcon: Icon(Icons.air),
              label: 'تنفّس',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note),
              label: 'مذكراتي',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'تقدّمي',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.store, required this.onOpen});
  final LocalStore store;
  final ValueChanged<int> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مساحتك الهادئة',
                style: TextStyle(color: Color(0xFF5D736B)),
              ),
              SizedBox(height: 4),
              Text(
                'سكون',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
          IconButton.filledTonal(
            onPressed: () => showSettings(context, store),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Chip(
              label: Text('يعمل دون اتصال'),
              backgroundColor: Color(0x33FFFFFF),
              labelStyle: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text(
              'خذ لحظة لنفسك',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'دقائق قليلة من التنفس والتأمل قد تمنح يومك مساحة أهدأ.',
              style: TextStyle(color: Color(0xFFD7E3DB), fontSize: 16),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => onOpen(1),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('ابدأ جلسة هادئة  ←'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      MoodCheckin(store: store),
      const SizedBox(height: 22),
      const Text(
        'اختصارات',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Shortcut(
            icon: Icons.edit_note,
            title: 'ملاحظة خاصة',
            subtitle: 'اكتب ما تشعر به',
            onTap: () => onOpen(3),
          ),
          const SizedBox(width: 10),
          Shortcut(
            icon: Icons.air,
            title: 'تنفّس',
            subtitle: 'دورة هادئة',
            onTap: () => onOpen(2),
          ),
          const SizedBox(width: 10),
          Shortcut(
            icon: Icons.insights,
            title: 'تقدّمك',
            subtitle: '${store.sessions} جلسات',
            onTap: () => onOpen(4),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sage,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“',
              style: TextStyle(
                fontSize: 42,
                height: .5,
                color: Color(0xFF759184),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'ما الشيء الصغير الذي يستحق امتنانك الآن؟',
              style: TextStyle(fontSize: 17, color: ink),
            ),
            SizedBox(height: 8),
            Text(
              'اكتب إجابتك في مذكراتك',
              style: TextStyle(
                color: Color(0xFF9A5D42),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class MoodCheckin extends StatelessWidget {
  const MoodCheckin({super.key, required this.store});
  final LocalStore store;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE9E9DD)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'كيف هي مساحتك اليوم؟',
          style: TextStyle(fontWeight: FontWeight.w700, color: ink),
        ),
        const SizedBox(height: 4),
        const Text(
          'اختر كلمة واحدة، يكفي أن تلاحظ.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6D7C78)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['هادئ', 'متأمل', 'مثقل', 'ممتن']
              .map(
                (m) => ChoiceChip(
                  label: Text(m),
                  selected: store.mood == m,
                  onSelected: (_) => store.saveMood(m),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class Shortcut extends StatelessWidget {
  const Shortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        height: 132,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9E9DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 28),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6D7C78)),
            ),
          ],
        ),
      ),
    ),
  );
}

class SessionTab extends StatefulWidget {
  const SessionTab({super.key, required this.store});
  final LocalStore store;
  @override
  State<SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<SessionTab> {
  Timer? timer;
  int remaining = 300;
  bool finished = false;
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void toggle() {
    if (finished) return;
    if (timer != null) {
      timer!.cancel();
      timer = null;
      setState(() {});
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining == 0) {
        timer?.cancel();
        timer = null;
        finished = true;
        widget.store.completeSession();
        setState(() {});
      } else {
        setState(() => remaining--);
      }
    });
    setState(() {});
  }

  void reset() {
    timer?.cancel();
    setState(() {
      timer = null;
      remaining = 300;
      finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mins = (remaining ~/ 60).toString().padLeft(2, '0');
    final secs = (remaining % 60).toString().padLeft(2, '0');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Chip(label: Text('جلسة تأمل موجّه')),
              const SizedBox(height: 18),
              const Text(
                'العودة إلى اللحظة',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'لاحظ تنفّسك كما هو، من دون أن تحاول تغييره.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF536863)),
              ),
              const SizedBox(height: 28),
              Text(
                '$mins:$secs',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                  color: ink,
                ),
              ),
              LinearProgressIndicator(
                value: (300 - remaining) / 300,
                color: accent,
                backgroundColor: const Color(0xFFE8ECE5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    onPressed: toggle,
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    child: Text(
                      finished
                          ? 'اكتملت'
                          : timer == null
                          ? 'ابدأ'
                          : 'إيقاف مؤقت',
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(onPressed: reset, child: const Text('إعادة')),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                finished
                    ? 'أحسنت. خذ لحظة لملاحظة ما تغيّر.'
                    : timer == null
                    ? 'عندما تكون مستعدًا، ابدأ بهدوء.'
                    : 'وجودك هنا يكفي. استمر بلطف.',
                style: const TextStyle(color: Color(0xFF6D7C78)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BreathingTab extends StatefulWidget {
  const BreathingTab({super.key, required this.store});
  final LocalStore store;
  @override
  State<BreathingTab> createState() => _BreathingTabState();
}

class _BreathingTabState extends State<BreathingTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  Timer? phaseTimer;
  bool active = false;
  String phase = 'استعد';

  @override
  void dispose() {
    controller.dispose();
    phaseTimer?.cancel();
    super.dispose();
  }

  void toggle() {
    if (active) {
      phaseTimer?.cancel();
      controller.stop();
      setState(() {
        active = false;
        phase = 'استعد';
      });
      return;
    }
    setState(() {
      active = true;
      phase = 'شهيق';
    });
    controller.repeat(reverse: true);
    phaseTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => setState(() => phase = phase == 'شهيق' ? 'زفير' : 'شهيق'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Chip(label: Text('تنظيم الجهاز العصبي')),
              const SizedBox(height: 14),
              const Text(
                'تنفّس ببطء',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'دع إيقاع النفس يقودك إلى لحظة أكثر اتساعًا.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF536863)),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: controller,
                builder: (_, child) => Transform.scale(
                  scale: 0.88 + controller.value * 0.22,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sage,
                      boxShadow: [
                        BoxShadow(
                          color: sage.withValues(alpha: .8),
                          blurRadius: 0,
                          spreadRadius: 18,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        phase,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'شهيق 4 ثوانٍ • زفير 4 ثوانٍ',
                style: TextStyle(color: Color(0xFF6D7C78)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: toggle,
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: Text(active ? 'إيقاف الدورة' : 'ابدأ التنفّس'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JournalTab extends StatefulWidget {
  const JournalTab({super.key, required this.store});
  final LocalStore store;
  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  late final TextEditingController controller;
  String selected = '';
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.store.journal);
    selected = widget.store.mood;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Chip(label: Text('خاص على هذا الجهاز')),
            const SizedBox(height: 14),
            const Text(
              'ملاحظتك الهادئة',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'لا تُرسل كتابتك إلى أي خادم. تُحفظ محليًا على جهازك.',
              style: TextStyle(color: Color(0xFF536863)),
            ),
            const SizedBox(height: 22),
            const Text(
              'كيف تشعر الآن؟',
              style: TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['هادئ', 'متأمل', 'متعب', 'ممتن']
                  .map(
                    (m) => ChoiceChip(
                      label: Text(m),
                      selected: selected == m,
                      onSelected: (_) => setState(() => selected = m),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'مساحة الكتابة',
              style: TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: 7,
              maxLines: 12,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'اكتب لنفسك فقط...',
                filled: true,
                fillColor: Color(0xFFFFFEF9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () async {
                  await widget.store.saveJournal(controller.text, selected);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم الحفظ على هذا الجهاز')),
                    );
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: const Text('حفظ محلي'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key, required this.store});
  final LocalStore store;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Chip(label: Text('بلا منافسة')),
            const SizedBox(height: 14),
            const Text(
              'تقدّمك الهادئ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Stat(value: '${store.sessions}', label: 'جلسات'),
                const SizedBox(width: 10),
                Stat(
                  value: store.journal.isEmpty ? '0' : '1',
                  label: 'ملاحظات',
                ),
                const SizedBox(width: 10),
                const Stat(value: 'محلي', label: 'الخصوصية'),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'التقدّم هنا تذكير لطيف، وليس سباقًا. لا توجد سلاسل أو ترتيب أو مقارنات.',
              style: TextStyle(color: Color(0xFF536863)),
            ),
          ],
        ),
      ),
    ],
  );
}

class Stat extends StatelessWidget {
  const Stat({super.key, required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4ED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6D7C78)),
          ),
        ],
      ),
    ),
  );
}

void showPrivacy(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('خصوصيتك أولًا'),
      content: const Text(
        'سكون يعمل محليًا: لا حساب، لا إعلانات، لا تحليلات أو تتبع. الملاحظات تبقى على جهازك. المزامنة المستقبلية ستكون اختيارية بين أجهزتك الموثوقة.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('فهمت'),
        ),
      ],
    ),
  );
}

Future<void> showDeleteData(BuildContext context, LocalStore store) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('حذف بياناتك؟'),
      content: const Text(
        'سيحذف هذا الإجراء اليوميات والحالات والجلسات من هذا الجهاز. لا يمكن التراجع عنه. صدّر نسخة مشفّرة أولًا إن أردت الاحتفاظ بها.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف نهائي'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await store.deleteAllData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف بياناتك من هذا الجهاز.')),
      );
    }
  }
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.store});
  final LocalStore store;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final controller = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> export() async {
    if (controller.text.trim().length < 12) {
      setState(() => message = 'استخدم عبارة مرور من 12 حرفًا على الأقل.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final path = await widget.store.backupService?.exportBackup(
        controller.text,
      );
      if (mounted) {
        setState(
          () => message = path == null
              ? 'تم إلغاء التصدير.'
              : 'تم حفظ النسخة المشفّرة بأمان.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'تعذر إنشاء النسخة. لم يتم تغيير بياناتك.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    if (controller.text.trim().length < 12) {
      setState(() => message = 'أدخل عبارة مرور النسخة قبل الاستعادة.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final preview = await widget.store.backupService?.previewRestore(
        controller.text,
      );
      if (!mounted || preview == null) {
        if (mounted) setState(() => message = 'تم إلغاء الاستعادة.');
        return;
      }
      final approved =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('مراجعة النسخة'),
              content: Text(
                'سيتم دمج ${preview.reflections} ملاحظات، ${preview.sessions} جلسات، و${preview.moods} حالات شعورية. لا يتم حذف البيانات الحالية.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('دمج بأمان'),
                ),
              ],
            ),
          ) ??
          false;
      if (approved) {
        await widget.store.backupService!.restore(preview);
        if (mounted) setState(() => message = 'تمت الاستعادة والدمج بنجاح.');
      }
    } on FormatException {
      if (mounted) {
        setState(() => message = 'النسخة غير صالحة أو عبارة المرور غير صحيحة.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'تعذر قراءة النسخة. لم يتم تغيير بياناتك.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: sage,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: ink),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'نسختك مشفّرة على جهازك. لا نرفعها إلى خادم، ولا يمكن فتحها دون عبارة المرور.',
                    style: TextStyle(color: ink, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'عبارة مرور النسخة',
            style: TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '12 حرفًا أو أكثر',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'احفظها في مكان آمن. لا يمكن استعادة النسخة دونها.',
            style: TextStyle(color: Color(0xFF6D7C78)),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: busy ? null : export,
            icon: const Icon(Icons.upload_file),
            label: const Text('تصدير نسخة مشفّرة'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : restore,
            icon: const Icon(Icons.restore),
            label: const Text('استعادة نسخة'),
          ),
          const SizedBox(height: 18),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          if (message != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EEE3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(message!, style: const TextStyle(color: ink)),
            ),
        ],
      ),
    ),
  );
}

void showSettings(BuildContext context, LocalStore store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إعدادات سكون',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'اجعل التجربة مناسبة لإيقاعك واحتياجك.',
                style: TextStyle(color: Color(0xFF6D7C78)),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('الوضع الداكن'),
                subtitle: const Text('راحة أكبر في الإضاءة المنخفضة'),
                value: store.darkMode,
                onChanged: (v) async {
                  await store.setDarkMode(v);
                  setSheetState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('تقليل الحركة'),
                subtitle: const Text('انتقالات أهدأ وتقليل المؤثرات'),
                value: store.reducedMotion,
                onChanged: (v) async {
                  await store.setReducedMotion(v);
                  setSheetState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('نسخة احتياطية مشفّرة'),
                subtitle: const Text('تصدير أو استعادة بياناتك محليًا'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BackupPage(store: store)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('نموذج الخصوصية'),
                subtitle: const Text('بياناتك محلية ولا نستخدم التتبع'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showPrivacy(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('حذف بياناتي'),
                subtitle: const Text(
                  'حذف اليوميات والجلسات والحالات من هذا الجهاز',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDeleteData(context, store);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
