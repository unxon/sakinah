import '../../domain/entities/devotion.dart';

const demoCatalog = <Devotion>[
  Devotion(
      id: 'morning-001',
      packageId: 'core-ar',
      title: 'أذكار الصباح',
      tag: 'يومي',
      body: 'اللهم بك أصبحنا، وبك أمسينا.',
      source: 'رواه مسلم · حِصن المسلم',
      targetCount: 5,
      verified: true),
  Devotion(
      id: 'evening-001',
      packageId: 'core-ar',
      title: 'أذكار المساء',
      tag: 'يومي',
      body: 'مساحة هادئة نختم بها النهار ونستودع الله قلوبنا.',
      source: 'رواه أبو داود · حِصن المسلم',
      targetCount: 7,
      verified: true),
  Devotion(
      id: 'gratitude-001',
      packageId: 'core-ar',
      title: 'دعاء الشكر',
      tag: 'تأمل',
      body: 'وقفة قصيرة لنرى النعم التي تحيط بنا كل يوم.',
      source: 'دعاء مأثور',
      targetCount: 1,
      verified: true),
  Devotion(
      id: 'ease-001',
      packageId: 'core-ar',
      title: 'دعاء التيسير',
      tag: 'طمأنينة',
      body: 'حين تضيق المساحة، نعود إلى كلمات بسيطة وصادقة.',
      source: 'دعاء مأثور',
      targetCount: 1,
      verified: true),
];
