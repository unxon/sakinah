import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/storage/local_store.dart';
import '../data/content/asset_devotion_repository.dart';
import '../domain/entities/devotion.dart';
import '../domain/services/counter_service.dart';

const bg = Color(0xFFF7F5EF);
const surface = Color(0xFFFFFDF8);
const ink = Color(0xFF24332F);
const muted = Color(0xFF77827D);
const sage = Color(0xFF44675D);
const terra = Color(0xFFC87555);
const line = Color(0xFFE4E4DA);

class SakeenaApp extends StatefulWidget {
  final LocalStore? store;
  const SakeenaApp({super.key, this.store});
  @override
  State<SakeenaApp> createState() => _SakeenaAppState();
}

class _SakeenaAppState extends State<SakeenaApp> {
  bool darkMode = false;
  double fontScale = 1.0;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'سَكينة',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: bg,
            colorScheme: ColorScheme.fromSeed(seedColor: sage)),
        darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
                seedColor: sage, brightness: Brightness.dark)),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(fontScale)),
            child: child ?? const SizedBox.shrink()),
        home: SakeenaShell(
            store: widget.store ?? LocalStore(),
            onSettingsChanged: (settings) => setState(() {
                  darkMode = settings['darkMode'] == '1';
                  fontScale =
                      double.tryParse(settings['fontScale'] ?? '1.0') ?? 1.0;
                })),
      );
}

class SakeenaShell extends StatefulWidget {
  final LocalStore store;
  final ValueChanged<Map<String, String>> onSettingsChanged;
  const SakeenaShell(
      {super.key, required this.store, required this.onSettingsChanged});
  @override
  State<SakeenaShell> createState() => _SakeenaShellState();
}

class _SakeenaShellState extends State<SakeenaShell> {
  final counter = const CounterService();
  final content = const AssetDevotionRepository();
  int index = 0;
  bool ready = false;
  List<Devotion> catalog = [];
  Set<String> favorites = {};
  Map<String, int> counts = {};
  List<Map<String, String>> personal = [];
  List<Map<String, String>> plans = [];
  Map<String, String> settings = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.store.open();
    final snapshot = await widget.store.load();
    final loadedCatalog = await content.list();
    if (!mounted) return;
    setState(() {
      catalog = loadedCatalog;
      favorites = snapshot.favorites;
      counts = snapshot.counts;
      personal = snapshot.personal;
      plans = snapshot.plans;
      settings = snapshot.settings;
      ready = true;
    });
    widget.onSettingsChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SplashScreen();
    final screens = [
      HomeScreen(
          catalog: catalog,
          counts: counts,
          favorites: favorites,
          onOpen: _openReader,
          onLibrary: () => setState(() => index = 1)),
      LibraryScreen(
          catalog: catalog,
          counts: counts,
          favorites: favorites,
          onOpen: _openReader,
          onFavorite: _toggleFavorite),
      PlansScreen(plans: plans, onAdd: _addPlan, onDelete: _deletePlan),
      PersonalScreen(
          items: personal,
          onAdd: _addPersonal,
          onDelete: _deletePersonal,
          onUpdate: _updatePersonal),
      SettingsScreen(settings: settings, onChanged: _setSetting),
    ];
    return Scaffold(
      appBar: AppBar(
          title: const Brand(),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: KeyedSubtree(key: ValueKey(index), child: screens[index])),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories),
                label: 'المكتبة'),
            NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'خططي'),
            NavigationDestination(
                icon: Icon(Icons.edit_note_outlined),
                selectedIcon: Icon(Icons.edit_note),
                label: 'الخاص'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'الإعدادات'),
          ]),
    );
  }

  Future<void> _toggleFavorite(String id) async {
    final next = !favorites.contains(id);
    await widget.store.setFavorite(id, next);
    if (mounted) {
      setState(() => next ? favorites.add(id) : favorites.remove(id));
    }
  }

  Future<void> _increment(Devotion item) async {
    final next = counter.nextValue(
        current: counts[item.id] ?? 0, target: item.targetCount);
    if (next == (counts[item.id] ?? 0)) return;
    await widget.store.addCount(item.id);
    if (mounted) setState(() => counts[item.id] = next);
  }

  Future<void> _openReader(Devotion item) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ReaderSheet(
            item: item,
            count: counts[item.id] ?? 0,
            favorite: favorites.contains(item.id),
            onFavorite: () => _toggleFavorite(item.id),
            onCount: () => _increment(item)));
  }

  Future<void> _addPersonal(String title, String body) async {
    final id = await widget.store.addPersonal(title, body);
    if (mounted) {
      setState(
          () => personal.insert(0, {'id': id, 'title': title, 'body': body}));
    }
  }

  Future<void> _updatePersonal(String id, String title, String body) async {
    await widget.store.updatePersonal(id, title, body);
    if (!mounted) return;
    setState(() {
      final index = personal.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        personal[index] = {'id': id, 'title': title, 'body': body};
      }
    });
  }

  Future<void> _deletePersonal(String id) async {
    await widget.store.deletePersonal(id);
    if (mounted) {
      setState(() => personal.removeWhere((item) => item['id'] == id));
    }
  }

  Future<void> _addPlan(String title, String subtitle) async {
    final id = await widget.store.addPlan(title, subtitle);
    if (mounted) {
      setState(() => plans.insert(0, {
            'id': id,
            'title': title,
            'subtitle': subtitle,
            'progress': '0',
            'active': '1',
          }));
    }
  }

  Future<void> _deletePlan(String id) async {
    await widget.store.deletePlan(id);
    if (mounted) setState(() => plans.removeWhere((plan) => plan['id'] == id));
  }

  Future<void> _setSetting(String key, String value) async {
    await widget.store.setSetting(key, value);
    if (!mounted) return;
    setState(() => settings[key] = value);
    widget.onSettingsChanged(settings);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: sage,
              child: Text('س',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 24),
            Text('سَكينة', style: TextStyle(color: ink, fontSize: 30)),
            SizedBox(height: 8),
            Text('نجهّز مساحتك...',
                style: TextStyle(color: muted, fontSize: 13)),
            SizedBox(height: 28),
            SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: sage)),
          ],
        ),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        const CircleAvatar(
            radius: 19,
            backgroundColor: sage,
            child: Text('س',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سَكينة',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const Text('مساحتك الهادئة',
              style: TextStyle(color: muted, fontSize: 10))
        ])
      ]);
}

class PageHeader extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const PageHeader(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow,
            style: const TextStyle(
                color: terra, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                color: ink, fontSize: 28, fontWeight: FontWeight.w400)),
        const SizedBox(height: 7),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 12))
      ]));
}

class HomeScreen extends StatelessWidget {
  final List<Devotion> catalog;
  final Map<String, int> counts;
  final Set<String> favorites;
  final void Function(Devotion) onOpen;
  final VoidCallback onLibrary;
  const HomeScreen(
      {super.key,
      required this.catalog,
      required this.counts,
      required this.favorites,
      required this.onOpen,
      required this.onLibrary});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        const PageHeader(
            eyebrow: 'الثلاثاء، ١٣ أكتوبر ٢٠٢٦',
            title: 'صباحك هادئ، محمد.',
            subtitle: 'خذ لحظة لك قبل أن يبدأ اليوم.'),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const HeroCard(),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('تعود إليها كثيرًا',
                    style: TextStyle(
                        color: ink, fontSize: 17, fontWeight: FontWeight.w600)),
                TextButton(
                    onPressed: onLibrary,
                    child: const Text('كل المكتبة ←',
                        style: TextStyle(color: terra, fontSize: 12)))
              ]),
              Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: catalog
                      .take(3)
                      .map((item) => SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 52) / 2,
                          child: DevotionCard(
                              item: item,
                              count: counts[item.id] ?? 0,
                              favorite: favorites.contains(item.id),
                              onOpen: () => onOpen(item),
                              onFavorite: null)))
                      .toList())
            ]))
      ]);
}

class HeroCard extends StatelessWidget {
  const HeroCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration:
          BoxDecoration(color: sage, borderRadius: BorderRadius.circular(26)),
      child:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ورد اليوم · ٣ من ٥',
            style: TextStyle(color: Color(0xFFCFE1D4), fontSize: 11)),
        SizedBox(height: 26),
        Text('«اللهم بك أصبحنا،\nوبك أمسينا»',
            style: TextStyle(color: Colors.white, fontSize: 24, height: 1.7)),
        SizedBox(height: 10),
        Text('لحظة واحدة تكفي لتعود إلى نفسك.',
            style: TextStyle(color: Color(0xFFD7E6DB), fontSize: 11))
      ]));
}

class LibraryScreen extends StatefulWidget {
  final List<Devotion> catalog;
  final Map<String, int> counts;
  final Set<String> favorites;
  final void Function(Devotion) onOpen;
  final Future<void> Function(String) onFavorite;
  const LibraryScreen(
      {super.key,
      required this.catalog,
      required this.counts,
      required this.favorites,
      required this.onOpen,
      required this.onFavorite});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.catalog
        .where((item) => '${item.title}${item.body}'.contains(query))
        .toList();
    return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
      const PageHeader(
          eyebrow: 'مكتبتك',
          title: 'اختر ما يلامس يومك.',
          subtitle: 'محتوى محلي موثوق، بلا اتصال ولا حساب.'),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                  hintText: '⌕  ابحث في الأدعية...',
                  filled: true,
                  fillColor: surface))),
      const SizedBox(height: 18),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map((item) => SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 52) / 2,
                      child: DevotionCard(
                          item: item,
                          count: widget.counts[item.id] ?? 0,
                          favorite: widget.favorites.contains(item.id),
                          onOpen: () => widget.onOpen(item),
                          onFavorite: () => widget.onFavorite(item.id))))
                  .toList()))
    ]);
  }
}

class DevotionCard extends StatelessWidget {
  final Devotion item;
  final int count;
  final bool favorite;
  final VoidCallback onOpen;
  final Future<void> Function()? onFavorite;
  const DevotionCard(
      {super.key,
      required this.item,
      required this.count,
      required this.favorite,
      required this.onOpen,
      required this.onFavorite});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: const BorderSide(color: line)),
      child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onOpen,
          child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.tag,
                              style:
                                  const TextStyle(color: terra, fontSize: 10)),
                          if (onFavorite != null)
                            IconButton(
                                onPressed: onFavorite,
                                icon: Icon(
                                    favorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: favorite ? terra : muted,
                                    size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints())
                        ]),
                    Text(item.title,
                        style: const TextStyle(
                            color: ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 7),
                    Text(item.body,
                        style: const TextStyle(
                            color: muted, fontSize: 11, height: 1.55)),
                    const SizedBox(height: 14),
                    Text('$count / ${item.targetCount} تمت',
                        style: const TextStyle(
                            color: sage,
                            fontSize: 10,
                            fontWeight: FontWeight.bold))
                  ]))));
}

class ReaderSheet extends StatelessWidget {
  final Devotion item;
  final int count;
  final bool favorite;
  final VoidCallback onFavorite;
  final Future<void> Function() onCount;
  const ReaderSheet(
      {super.key,
      required this.item,
      required this.count,
      required this.favorite,
      required this.onFavorite,
      required this.onCount});
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 22,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(item.title,
                  style: const TextStyle(color: ink, fontSize: 23)),
              IconButton(
                  onPressed: onFavorite,
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                      color: favorite ? terra : muted))
            ]),
            const SizedBox(height: 20),
            const Text(
                'اللهم اجعل في قلبي نورًا، وفي يومي سكينة، وبارك لي في خطواتي، وقرّبني إليك بلطفك ورحمتك.',
                style: TextStyle(color: ink, fontSize: 23, height: 2)),
            const SizedBox(height: 14),
            Text(item.source ?? 'المصدر غير متوفر',
                style: const TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: onCount,
                    style: FilledButton.styleFrom(
                        backgroundColor: terra,
                        padding: const EdgeInsets.all(16)),
                    child: Text('سجّل الذكر · ${count + 1}'))),
            Center(
                child: Text('أنجزت $count من ${item.targetCount}',
                    style: const TextStyle(color: muted, fontSize: 11)))
          ]));
}

class PlansScreen extends StatelessWidget {
  final List<Map<String, String>> plans;
  final Future<void> Function(String, String) onAdd;
  final Future<void> Function(String) onDelete;

  const PlansScreen(
      {super.key,
      required this.plans,
      required this.onAdd,
      required this.onDelete});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          const PageHeader(
              eyebrow: 'بهدوء، خطوة بخطوة',
              title: 'خططي',
              subtitle: 'خطط بسيطة تساعدك دون ضغط أو منافسة.'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
                onPressed: () => _showAdd(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة خطة'),
                style: FilledButton.styleFrom(backgroundColor: sage)),
          ),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد خطط بعد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted))),
          ...plans.map((plan) => PlanTile(
              plan: plan,
              onDelete: () => _confirmDelete(context, plan['id']!))),
        ],
      );

  Future<void> _showAdd(BuildContext context) async {
    final title = TextEditingController();
    final subtitle = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(sheet).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('خطة جديدة', style: TextStyle(color: ink, fontSize: 23)),
          TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'اسم الخطة')),
          TextField(
              controller: subtitle,
              decoration: const InputDecoration(labelText: 'الوصف')),
          const SizedBox(height: 14),
          FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                await onAdd(
                    title.text.trim(),
                    subtitle.text.trim().isEmpty
                        ? 'خطة شخصية'
                        : subtitle.text.trim());
                if (sheet.mounted) Navigator.pop(sheet);
              },
              style: FilledButton.styleFrom(backgroundColor: sage),
              child: const Text('حفظ الخطة')),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final result = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('حذف الخطة؟'),
                content: const Text('سيتم إخفاء الخطة وسجلها من هذه القائمة.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('حذف'))
                ]));
    if (result == true) await onDelete(id);
  }
}

class PlanTile extends StatelessWidget {
  final Map<String, String> plan;
  final VoidCallback onDelete;
  const PlanTile({super.key, required this.plan, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(plan['progress'] ?? '0') ?? 0;
    return Card(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: line)),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(plan['title'] ?? '',
                        style: const TextStyle(color: ink, fontSize: 18))),
                IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: muted))
              ]),
              Text(plan['subtitle'] ?? '',
                  style: const TextStyle(color: muted, fontSize: 11)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                  value: value,
                  color: terra,
                  backgroundColor: const Color(0xFFF0EEE6)),
              const SizedBox(height: 8),
              Text('${(value * 100).round()}% مكتمل هذا الأسبوع',
                  style: const TextStyle(color: muted, fontSize: 11))
            ])));
  }
}

class PersonalScreen extends StatelessWidget {
  final List<Map<String, String>> items;
  final Future<void> Function(String, String) onAdd;
  final Future<void> Function(String) onDelete;
  final Future<void> Function(String, String, String) onUpdate;

  const PersonalScreen({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        const PageHeader(
            eyebrow: 'مساحتك الخاصة',
            title: 'نصوصك، بصوتك.',
            subtitle: 'تُحفظ على هذا الجهاز فقط.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilledButton(
            onPressed: () => _showAdd(context),
            style: FilledButton.styleFrom(backgroundColor: sage),
            child: const Text('＋ إضافة نص'),
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: EmptyPersonal()),
        ...items.map((item) => Card(
              elevation: 0,
              color: surface,
              child: ListTile(
                title: Text(item['title']!, style: const TextStyle(color: ink)),
                subtitle:
                    Text(item['body']!, style: const TextStyle(color: muted)),
                onTap: () => _showEditor(context, item),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value != 'delete') return;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('حذف النص؟'),
                        content: const Text('سيُحذف هذا النص من هذا الجهاز.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('إلغاء')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('حذف')),
                        ],
                      ),
                    );
                    if (confirmed == true) await onDelete(item['id']!);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('حذف'))
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Future<void> _showAdd(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(sheet).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أضف ما تحب.',
                style: TextStyle(color: ink, fontSize: 23)),
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'النص')),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
                  return;
                }
                await onAdd(title.text.trim(), body.text.trim());
                if (sheet.mounted) Navigator.pop(sheet);
              },
              style: FilledButton.styleFrom(backgroundColor: sage),
              child: const Text('حفظ على هذا الجهاز'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditor(
      BuildContext context, Map<String, String> item) async {
    final title = TextEditingController(text: item['title']);
    final body = TextEditingController(text: item['body']);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(sheet).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تعديل النص',
                style: TextStyle(color: ink, fontSize: 23)),
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'النص')),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
                  return;
                }
                await onUpdate(
                    item['id']!, title.text.trim(), body.text.trim());
                if (sheet.mounted) Navigator.pop(sheet);
              },
              style: FilledButton.styleFrom(backgroundColor: sage),
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyPersonal extends StatelessWidget {
  const EmptyPersonal({super.key});
  @override
  Widget build(BuildContext context) => const Card(
      color: surface,
      child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(children: [
            Text('◌', style: TextStyle(color: sage, fontSize: 34)),
            Text('لم تضف نصوصًا بعد',
                style: TextStyle(color: ink, fontSize: 18)),
            SizedBox(height: 8),
            Text('أضف دعاءً خاصًا ليبقى على هذا الجهاز.',
                style: TextStyle(color: muted, fontSize: 12))
          ])));
}

class SettingsScreen extends StatelessWidget {
  final Map<String, String> settings;
  final Future<void> Function(String, String) onChanged;
  const SettingsScreen(
      {super.key, required this.settings, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final scale = double.tryParse(settings['fontScale'] ?? '1.0') ?? 1.0;
    return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
      const PageHeader(
          eyebrow: 'على طريقتك',
          title: 'الإعدادات',
          subtitle: 'تحكم في تجربتك وخصوصيتك من مكان واحد.'),
      _SwitchSetting(
          title: 'الوضع الداكن',
          subtitle: 'ألوان هادئة للقراءة الليلية.',
          value: settings['darkMode'] == '1',
          onChanged: (value) => onChanged('darkMode', value ? '1' : '0')),
      _SwitchSetting(
          title: 'إظهار المصادر',
          subtitle: 'عرض مصدر الدعاء عند توفره.',
          value: settings['showSources'] != '0',
          onChanged: (value) => onChanged('showSources', value ? '1' : '0')),
      _SwitchSetting(
          title: 'تقليل الحركة',
          subtitle: 'انتقالات أبسط وأكثر هدوءًا.',
          value: settings['reducedMotion'] == '1',
          onChanged: (value) => onChanged('reducedMotion', value ? '1' : '0')),
      Card(
          elevation: 0,
          color: surface,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حجم النص',
                        style: TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('${(scale * 100).round()}%',
                        style: const TextStyle(color: muted, fontSize: 11)),
                    Slider(
                        value: scale.clamp(.8, 2.0),
                        min: .8,
                        max: 2.0,
                        divisions: 12,
                        activeColor: sage,
                        onChanged: (value) =>
                            onChanged('fontScale', value.toStringAsFixed(2)))
                  ]))),
      const SettingTile(
          title: 'الخصوصية والبيانات',
          subtitle: 'بياناتك تحفظ محليًا ولا تحتاج حسابًا.'),
      const SettingTile(
          title: 'النسخ الاحتياطي',
          subtitle: 'سيضاف التصدير المشفر في مرحلة الحماية.'),
      const SettingTile(
          title: 'المزامنة', subtitle: 'اختيارية ولا تبدأ إلا بموافقة صريحة.'),
    ]);
  }
}

class _SwitchSetting extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchSetting(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      color: surface,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: sage,
          title: Text(title,
              style: const TextStyle(
                  color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: muted, fontSize: 11))));
}

class SettingTile extends StatelessWidget {
  final String title, subtitle;
  const SettingTile({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Card(
          elevation: 0,
          color: surface,
          child: ListTile(
              title: Text(title,
                  style: const TextStyle(
                      color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle,
                  style: const TextStyle(color: muted, fontSize: 11)),
              trailing: const Icon(Icons.chevron_left, color: muted))));
}
