import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: MortColors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MortApp());
}

class MortColors {
  static const black = Color(0xFF050505);
  static const ink = Color(0xFF0C0D0F);
  static const panel = Color(0xFF111214);
  static const raised = Color(0xFF18191C);
  static const line = Color(0xFF2A2C31);
  static const text = Color(0xFFF4F4F5);
  static const muted = Color(0xFF9DA0A6);
  static const soft = Color(0xFFD6D8DE);
  static const green = Color(0xFF7CFFB2);
  static const blue = Color(0xFF8EBBFF);
  static const amber = Color(0xFFFFD166);
  static const red = Color(0xFFFF6B6B);
}

enum PaymentMethod { cash, cashApp }

extension PaymentMethodLabel on PaymentMethod {
  String get label => this == PaymentMethod.cash ? 'Cash' : 'Cash App';
}

enum JobStatus { open, active, completed }

class MortJob {
  MortJob({
    required this.id,
    required this.title,
    required this.category,
    required this.poster,
    required this.location,
    required this.summary,
    required this.amount,
    required this.distanceMiles,
    required this.estimatedMinutes,
    required this.payment,
    required this.xp,
    required this.trustScore,
    required this.riskScore,
    required this.verifiedAdult,
    required this.parentAlertRequired,
    required this.teamJob,
    required this.postedAgo,
    required this.tags,
    required this.safetyFlags,
    this.status = JobStatus.open,
  });

  final String id;
  final String title;
  final String category;
  final String poster;
  final String location;
  final String summary;
  final double amount;
  final double distanceMiles;
  final int estimatedMinutes;
  final PaymentMethod payment;
  final int xp;
  final int trustScore;
  final int riskScore;
  final bool verifiedAdult;
  final bool parentAlertRequired;
  final bool teamJob;
  final String postedAgo;
  final List<String> tags;
  final List<String> safetyFlags;
  JobStatus status;
}

class FeedPost {
  const FeedPost({
    required this.name,
    required this.handle,
    required this.type,
    required this.text,
    required this.stat,
    required this.time,
    required this.likes,
    required this.icon,
    required this.accent,
  });

  final String name;
  final String handle;
  final String type;
  final String text;
  final String stat;
  final String time;
  final int likes;
  final IconData icon;
  final Color accent;
}

class Conversation {
  Conversation({
    required this.name,
    required this.subtitle,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.group,
    required this.safe,
    required this.messages,
  });

  final String name;
  final String subtitle;
  final String lastMessage;
  final String time;
  final int unread;
  final bool group;
  final bool safe;
  final List<ChatMessage> messages;
}

class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    required this.mine,
    required this.safe,
  });

  final String sender;
  final String text;
  final bool mine;
  final bool safe;
}

class SavingsGoal {
  SavingsGoal({
    required this.name,
    required this.saved,
    required this.target,
    required this.icon,
  });

  final String name;
  double saved;
  final double target;
  final IconData icon;

  double get progress => (saved / target).clamp(0, 1);
}

class EarnedBadge {
  const EarnedBadge({
    required this.name,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  final String name;
  final String detail;
  final IconData icon;
  final Color accent;
}

class TrustSignal {
  const TrustSignal({
    required this.name,
    required this.value,
    required this.icon,
    required this.accent,
    required this.locked,
  });

  final String name;
  final String value;
  final IconData icon;
  final Color accent;
  final bool locked;
}

class MortState {
  MortState({
    required this.teenName,
    required this.age,
    required this.level,
    required this.xp,
    required this.nextLevelXp,
    required this.trustScore,
    required this.streak,
    required this.totalEarned,
    required this.todayEarned,
    required this.cashAppReady,
    required this.parentAlerts,
    required this.humanCheck,
    required this.deviceTrusted,
    required this.adultVerified,
    required this.emergencyActive,
    required this.lastCheckIn,
    required this.jobs,
    required this.feed,
    required this.conversations,
    required this.goals,
    required this.badges,
  });

  final String teenName;
  final int age;
  int level;
  int xp;
  int nextLevelXp;
  int trustScore;
  int streak;
  double totalEarned;
  double todayEarned;
  bool cashAppReady;
  bool parentAlerts;
  bool humanCheck;
  bool deviceTrusted;
  bool adultVerified;
  bool emergencyActive;
  String lastCheckIn;
  MortJob? activeJob;
  int scamFlagsCleared = 12;
  int botScore = 97;
  int payoutLockHours = 24;
  final List<MortJob> jobs;
  final List<FeedPost> feed;
  final List<Conversation> conversations;
  final List<SavingsGoal> goals;
  final List<EarnedBadge> badges;

  factory MortState.demo() {
    return MortState(
      teenName: 'Maya',
      age: 16,
      level: 12,
      xp: 1180,
      nextLevelXp: 1500,
      trustScore: 94,
      streak: 9,
      totalEarned: 428,
      todayEarned: 46,
      cashAppReady: true,
      parentAlerts: true,
      humanCheck: true,
      deviceTrusted: true,
      adultVerified: true,
      emergencyActive: false,
      lastCheckIn: '18 min ago',
      jobs: [
        MortJob(
          id: 'yard-12',
          title: 'Front yard cleanup',
          category: 'Yard',
          poster: 'Dana R.',
          location: 'Maple Ridge',
          summary: 'Rake leaves, bag sticks, and sweep walkway before 6 PM.',
          amount: 38,
          distanceMiles: 0.7,
          estimatedMinutes: 55,
          payment: PaymentMethod.cash,
          xp: 90,
          trustScore: 98,
          riskScore: 4,
          verifiedAdult: true,
          parentAlertRequired: false,
          teamJob: false,
          postedAgo: '4 min',
          tags: ['Quick', 'Outside', 'Cash'],
          safetyFlags: ['ID checked', 'Address matched'],
        ),
        MortJob(
          id: 'dogs-09',
          title: 'Walk two dogs',
          category: 'Pets',
          poster: 'Marcus T.',
          location: 'Oak Hollow',
          summary: 'Two friendly dogs, 30 minute route, water bowls after.',
          amount: 24,
          distanceMiles: 1.1,
          estimatedMinutes: 35,
          payment: PaymentMethod.cashApp,
          xp: 70,
          trustScore: 96,
          riskScore: 7,
          verifiedAdult: true,
          parentAlertRequired: true,
          teamJob: false,
          postedAgo: '11 min',
          tags: ['Pets', 'Same day', 'Check-in'],
          safetyFlags: ['Parent ping', 'Route shared'],
        ),
        MortJob(
          id: 'wash-22',
          title: 'Car wash duo',
          category: 'Cars',
          poster: 'Priya S.',
          location: 'Westgate',
          summary: 'Wash two sedans with a friend. Supplies are provided.',
          amount: 52,
          distanceMiles: 1.8,
          estimatedMinutes: 80,
          payment: PaymentMethod.cashApp,
          xp: 125,
          trustScore: 92,
          riskScore: 9,
          verifiedAdult: true,
          parentAlertRequired: true,
          teamJob: true,
          postedAgo: '17 min',
          tags: ['Team', 'Bigger payout', 'Supplies'],
          safetyFlags: ['Verified adult', 'No off-app pay'],
        ),
        MortJob(
          id: 'tutor-14',
          title: 'Algebra help',
          category: 'Tutoring',
          poster: 'Nell C.',
          location: 'Library',
          summary: 'Help a freshman review equations in a public room.',
          amount: 30,
          distanceMiles: 2.4,
          estimatedMinutes: 45,
          payment: PaymentMethod.cash,
          xp: 105,
          trustScore: 99,
          riskScore: 2,
          verifiedAdult: true,
          parentAlertRequired: false,
          teamJob: false,
          postedAgo: '22 min',
          tags: ['Public spot', 'Study', 'Cash'],
          safetyFlags: ['Public location', 'Guardian visible'],
        ),
      ],
      feed: [
        FeedPost(
          name: 'Jay',
          handle: '@jaycuts',
          type: 'Level up',
          text: 'Hit level 15 after a weekend mowing streak.',
          stat: '+240 XP',
          time: '3m',
          likes: 42,
          icon: Icons.bolt,
          accent: MortColors.amber,
        ),
        FeedPost(
          name: 'Kira',
          handle: '@kirahelps',
          type: 'Win',
          text: 'Saved enough for the white 4s. Two more jobs banked.',
          stat: r'$180 goal',
          time: '16m',
          likes: 88,
          icon: Icons.savings,
          accent: MortColors.green,
        ),
        FeedPost(
          name: 'Team West',
          handle: '@westcrew',
          type: 'Team hustle',
          text: 'Need one more for garage cleanout after school.',
          stat: r'$64 each',
          time: '34m',
          likes: 17,
          icon: Icons.groups_2,
          accent: MortColors.blue,
        ),
      ],
      conversations: [
        Conversation(
          name: 'Dana R.',
          subtitle: 'Front yard cleanup',
          lastMessage: 'Bags are by the garage.',
          time: 'Now',
          unread: 2,
          group: false,
          safe: true,
          messages: const [
            ChatMessage(
              sender: 'Dana R.',
              text: 'Bags are by the garage.',
              mine: false,
              safe: true,
            ),
            ChatMessage(
              sender: 'Maya',
              text: 'Got it. I will check in when I arrive.',
              mine: true,
              safe: true,
            ),
          ],
        ),
        Conversation(
          name: 'West Crew',
          subtitle: 'Team hustles',
          lastMessage: 'Who wants the car wash duo?',
          time: '8m',
          unread: 5,
          group: true,
          safe: true,
          messages: const [
            ChatMessage(
              sender: 'Kira',
              text: 'Who wants the car wash duo?',
              mine: false,
              safe: true,
            ),
            ChatMessage(
              sender: 'Jay',
              text: 'I can bring towels.',
              mine: false,
              safe: true,
            ),
          ],
        ),
        Conversation(
          name: 'Scam Shield',
          subtitle: 'Auto review',
          lastMessage: 'Blocked a request to move payment off app.',
          time: '21m',
          unread: 1,
          group: false,
          safe: false,
          messages: const [
            ChatMessage(
              sender: 'Shield',
              text: 'Blocked a request to move payment off app.',
              mine: false,
              safe: false,
            ),
          ],
        ),
      ],
      goals: [
        SavingsGoal(
          name: 'First car fund',
          saved: 428,
          target: 2500,
          icon: Icons.directions_car,
        ),
        SavingsGoal(
          name: 'Phone upgrade',
          saved: 310,
          target: 899,
          icon: Icons.phone_iphone,
        ),
        SavingsGoal(
          name: 'Shoes',
          saved: 124,
          target: 220,
          icon: Icons.shopping_bag,
        ),
      ],
      badges: const [
        EarnedBadge(
          name: 'Trusted',
          detail: '94 score',
          icon: Icons.verified_user,
          accent: MortColors.blue,
        ),
        EarnedBadge(
          name: 'Streak',
          detail: '9 days',
          icon: Icons.local_fire_department,
          accent: MortColors.amber,
        ),
        EarnedBadge(
          name: 'Closer',
          detail: '18 done',
          icon: Icons.task_alt,
          accent: MortColors.green,
        ),
      ],
    );
  }

  double feeFor(MortJob job) {
    if (job.payment == PaymentMethod.cash) return 0;
    return math.max(1.25, job.amount * 0.06);
  }

  double netFor(MortJob job) => job.amount - feeFor(job);

  double get xpProgress => (xp / nextLevelXp).clamp(0, 1);

  int get openJobs => jobs.where((job) => job.status == JobStatus.open).length;

  List<TrustSignal> get trustSignals => [
    TrustSignal(
      name: 'Human check',
      value: humanCheck ? 'Passed' : 'Needed',
      icon: Icons.front_hand,
      accent: humanCheck ? MortColors.green : MortColors.amber,
      locked: humanCheck,
    ),
    TrustSignal(
      name: 'Device trust',
      value: deviceTrusted ? 'Locked' : 'New device',
      icon: Icons.phonelink_lock,
      accent: deviceTrusted ? MortColors.blue : MortColors.amber,
      locked: deviceTrusted,
    ),
    TrustSignal(
      name: 'Payout lock',
      value: '${payoutLockHours}h',
      icon: Icons.lock_clock,
      accent: MortColors.soft,
      locked: true,
    ),
    TrustSignal(
      name: 'Bot score',
      value: '$botScore%',
      icon: Icons.shield,
      accent: botScore > 90 ? MortColors.green : MortColors.amber,
      locked: botScore > 90,
    ),
  ];

  void acceptJob(MortJob job) {
    if (activeJob != null || job.status != JobStatus.open) return;
    job.status = JobStatus.active;
    activeJob = job;
    xp += 25;
    lastCheckIn = 'Queued';
  }

  void completeActiveJob() {
    final job = activeJob;
    if (job == null) return;

    job.status = JobStatus.completed;
    activeJob = null;
    final net = netFor(job);
    totalEarned += net;
    todayEarned += net;
    xp += job.xp;
    trustScore = math.min(100, trustScore + 1);
    streak += 1;
    goals.first.saved = math.min(
      goals.first.target,
      goals.first.saved + net * .35,
    );
    lastCheckIn = 'Completed';

    if (xp >= nextLevelXp) {
      level += 1;
      xp = xp - nextLevelXp;
      nextLevelXp += 250;
    }

    feed.insert(
      0,
      FeedPost(
        name: teenName,
        handle: '@maya.moves',
        type: 'Completed',
        text:
            'Closed ${job.title.toLowerCase()} and banked ${formatMoney(net)}.',
        stat: '+${job.xp} XP',
        time: 'Now',
        likes: 0,
        icon: Icons.check_circle,
        accent: MortColors.green,
      ),
    );
  }

  void checkIn() {
    lastCheckIn = 'Just now';
    if (parentAlerts) {
      scamFlagsCleared += 1;
    }
  }

  void triggerEmergency() {
    emergencyActive = true;
    parentAlerts = true;
    lastCheckIn = 'Emergency sent';
  }

  void clearEmergency() {
    emergencyActive = false;
    lastCheckIn = 'Resolved';
  }

  void runHumanCheck() {
    humanCheck = true;
    deviceTrusted = true;
    botScore = 99;
  }

  void scanConversation() {
    scamFlagsCleared += 1;
    botScore = math.min(99, botScore + 1);
  }

  void addAdultJob(MortJob job) {
    jobs.insert(0, job);
  }
}

String formatMoney(double value) {
  final rounded = value.roundToDouble() == value;
  return rounded
      ? '\$${value.toStringAsFixed(0)}'
      : '\$${value.toStringAsFixed(2)}';
}

class MortApp extends StatefulWidget {
  const MortApp({super.key});

  @override
  State<MortApp> createState() => _MortAppState();
}

class _MortAppState extends State<MortApp> {
  final MortState _state = MortState.demo();
  bool _signedIn = true;
  bool _authHumanVerified = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MORT',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MortColors.black,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: MortColors.soft,
          primary: MortColors.text,
          secondary: MortColors.green,
          surface: MortColors.black,
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            color: MortColors.text,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          headlineSmall: TextStyle(
            color: MortColors.text,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          titleLarge: TextStyle(
            color: MortColors.text,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          titleMedium: TextStyle(
            color: MortColors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          bodyLarge: TextStyle(color: MortColors.soft, letterSpacing: 0),
          bodyMedium: TextStyle(color: MortColors.muted, letterSpacing: 0),
          labelLarge: TextStyle(
            color: MortColors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      home: MortDeviceFrame(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _signedIn
              ? MortShell(
                  key: const ValueKey('shell'),
                  state: _state,
                  onChanged: () => setState(() {}),
                  onSignOut: () => setState(() => _signedIn = false),
                  onPostJob: _openPostJobSheet,
                )
              : AuthScreen(
                  key: const ValueKey('auth'),
                  humanVerified: _authHumanVerified,
                  onHumanCheck: () => setState(() => _authHumanVerified = true),
                  onSignIn: () => setState(() {
                    _authHumanVerified = true;
                    _signedIn = true;
                  }),
                ),
        ),
      ),
    );
  }

  Future<void> _openPostJobSheet(BuildContext context) async {
    final job = await showModalBottomSheet<MortJob>(
      context: context,
      backgroundColor: MortColors.panel,
      barrierColor: Colors.black.withValues(alpha: .72),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => PostJobSheet(adultVerified: _state.adultVerified),
    );

    if (job == null) return;
    setState(() => _state.addAdultJob(job));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verified job posted to nearby teens')),
      );
    }
  }
}

class MortDeviceFrame extends StatelessWidget {
  const MortDeviceFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF111111),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 560;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(wide ? 28 : 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MortColors.black,
                    border: wide
                        ? Border.all(color: MortColors.line, width: 1)
                        : null,
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    required this.humanVerified,
    required this.onHumanCheck,
    required this.onSignIn,
    super.key,
  });

  final bool humanVerified;
  final VoidCallback onHumanCheck;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MortColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MortLogo(size: 58),
              const Spacer(),
              Text(
                'MORT',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontSize: 48, height: 1),
              ),
              const SizedBox(height: 14),
              const Text(
                'Local hustles. Safe chats. Real progress.',
                style: TextStyle(
                  color: MortColors.soft,
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              MortCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          humanVerified ? Icons.verified_user : Icons.shield,
                          color: humanVerified
                              ? MortColors.green
                              : MortColors.amber,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            humanVerified
                                ? 'Human check passed'
                                : 'Human check required',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onHumanCheck,
                          tooltip: 'Run check',
                          icon: const Icon(Icons.fingerprint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FullWidthAction(
                      icon: Icons.apple,
                      label: 'Continue with Apple',
                      onPressed: humanVerified ? onSignIn : null,
                    ),
                    const SizedBox(height: 10),
                    FullWidthAction(
                      icon: Icons.g_mobiledata,
                      label: 'Continue with Google',
                      onPressed: humanVerified ? onSignIn : null,
                      subtle: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: const [
                  Icon(Icons.lock, size: 16, color: MortColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Passkeys, device trust, age gates, and payout locks are active.',
                      style: TextStyle(color: MortColors.muted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MortShell extends StatefulWidget {
  const MortShell({
    required this.state,
    required this.onChanged,
    required this.onSignOut,
    required this.onPostJob,
    super.key,
  });

  final MortState state;
  final VoidCallback onChanged;
  final VoidCallback onSignOut;
  final Future<void> Function(BuildContext context) onPostJob;

  @override
  State<MortShell> createState() => _MortShellState();
}

class _MortShellState extends State<MortShell> {
  int _tab = 0;
  int _selectedConversation = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HustlesScreen(
        state: widget.state,
        onAccept: (job) {
          setState(() => widget.state.acceptJob(job));
          widget.onChanged();
          _snack('${job.title} accepted');
        },
        onComplete: () {
          final title = widget.state.activeJob?.title ?? 'Hustle';
          setState(widget.state.completeActiveJob);
          widget.onChanged();
          _snack('$title completed');
        },
        onCheckIn: () {
          setState(widget.state.checkIn);
          widget.onChanged();
          _snack('Check-in sent');
        },
        onPostJob: () => widget.onPostJob(context),
      ),
      MotionScreen(state: widget.state),
      MessagesScreen(
        state: widget.state,
        selectedIndex: _selectedConversation,
        onSelect: (index) => setState(() => _selectedConversation = index),
        onScan: () {
          setState(widget.state.scanConversation);
          widget.onChanged();
          _snack('Conversation scanned');
        },
      ),
      WalletScreen(state: widget.state),
      ShieldScreen(
        state: widget.state,
        onChanged: () {
          setState(() {});
          widget.onChanged();
        },
        onEmergency: () {
          setState(widget.state.triggerEmergency);
          widget.onChanged();
          _snack('Emergency alert sent');
        },
        onResolveEmergency: () {
          setState(widget.state.clearEmergency);
          widget.onChanged();
          _snack('Emergency resolved');
        },
        onHumanCheck: () {
          setState(widget.state.runHumanCheck);
          widget.onChanged();
          _snack('Account trust refreshed');
        },
        onPostJob: () => widget.onPostJob(context),
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      backgroundColor: MortColors.black,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tab, children: screens),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: MortColors.ink,
          indicatorColor: MortColors.raised,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? MortColors.text
                  : MortColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? MortColors.text
                  : MortColors.muted,
              size: 22,
            ),
          ),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Hustles',
            ),
            NavigationDestination(
              icon: Icon(Icons.dynamic_feed_outlined),
              selectedIcon: Icon(Icons.dynamic_feed),
              label: 'Motion',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Shield',
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: MortColors.raised,
      ),
    );
  }
}

class ScreenList extends StatelessWidget {
  const ScreenList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        for (final child in children) ...[child, const SizedBox(height: 16)],
      ],
    );
  }
}

class HustlesScreen extends StatefulWidget {
  const HustlesScreen({
    required this.state,
    required this.onAccept,
    required this.onComplete,
    required this.onCheckIn,
    required this.onPostJob,
    super.key,
  });

  final MortState state;
  final ValueChanged<MortJob> onAccept;
  final VoidCallback onComplete;
  final VoidCallback onCheckIn;
  final VoidCallback onPostJob;

  @override
  State<HustlesScreen> createState() => _HustlesScreenState();
}

class _HustlesScreenState extends State<HustlesScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final jobs = _filteredJobs;

    return ScreenList(
      children: [
        AppHeader(
          eyebrow: 'Good afternoon, ${widget.state.teenName}',
          title: 'MORT',
          actionIcon: Icons.add_business,
          actionTooltip: 'Post job',
          onAction: widget.onPostJob,
          trailing: TrustChip(score: widget.state.trustScore),
        ),
        EarningsStrip(state: widget.state),
        if (widget.state.activeJob != null)
          ActiveJobCard(
            job: widget.state.activeJob!,
            state: widget.state,
            onCheckIn: widget.onCheckIn,
            onComplete: widget.onComplete,
          )
        else
          SafetyReadyCard(state: widget.state),
        SearchAndFilters(
          selected: _filter,
          onSelected: (index) => setState(() => _filter = index),
        ),
        SectionHeader(title: 'Nearby hustles', action: '${jobs.length} open'),
        for (final job in jobs)
          JobCard(
            job: job,
            fee: widget.state.feeFor(job),
            net: widget.state.netFor(job),
            disabled: widget.state.activeJob != null,
            onAccept: () => widget.onAccept(job),
          ),
      ],
    );
  }

  List<MortJob> get _filteredJobs {
    final open =
        widget.state.jobs.where((job) => job.status == JobStatus.open).toList()
          ..sort((a, b) => a.distanceMiles.compareTo(b.distanceMiles));

    switch (_filter) {
      case 1:
        return open.where((job) => job.amount >= 35).toList();
      case 2:
        return open.where((job) => job.teamJob).toList();
      case 3:
        return open.where((job) => job.riskScore <= 5).toList();
      default:
        return open;
    }
  }
}

class EarningsStrip extends StatelessWidget {
  const EarningsStrip({required this.state, super.key});

  final MortState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Today',
                value: formatMoney(state.todayEarned),
                icon: Icons.trending_up,
                accent: MortColors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Level',
                value: '${state.level}',
                icon: Icons.bolt,
                accent: MortColors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Streak',
                value: '${state.streak}d',
                icon: Icons.local_fire_department,
                accent: MortColors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MortProgress(
          label: '${state.xp} / ${state.nextLevelXp} XP',
          value: state.xpProgress,
          accent: MortColors.amber,
        ),
      ],
    );
  }
}

class SafetyReadyCard extends StatelessWidget {
  const SafetyReadyCard({required this.state, super.key});

  final MortState state;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: MortColors.green),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ready for safe pickup',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              StatusDot(active: state.parentAlerts),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TagPill(icon: Icons.near_me, label: '${state.openJobs} local'),
              const TagPill(icon: Icons.badge, label: 'Adults verified'),
              TagPill(
                icon: Icons.shield,
                label: '${state.botScore}% bot score',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActiveJobCard extends StatelessWidget {
  const ActiveJobCard({
    required this.job,
    required this.state,
    required this.onCheckIn,
    required this.onComplete,
    super.key,
  });

  final MortJob job;
  final MortState state;
  final VoidCallback onCheckIn;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run, color: MortColors.green),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Active hustle',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                state.lastCheckIn,
                style: const TextStyle(
                  color: MortColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${job.location} • ${job.distanceMiles.toStringAsFixed(1)} mi • ${job.estimatedMinutes} min',
            style: const TextStyle(color: MortColors.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCheckIn,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Check in'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.done),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SearchAndFilters extends StatelessWidget {
  const SearchAndFilters({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Quick cash', 'Team', 'Lowest risk'];
    return Column(
      children: [
        TextField(
          style: const TextStyle(color: MortColors.text),
          decoration: InputDecoration(
            hintText: 'Search jobs, places, skills',
            hintStyle: const TextStyle(color: MortColors.muted),
            prefixIcon: const Icon(Icons.search, color: MortColors.muted),
            filled: true,
            fillColor: MortColors.panel,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: MortColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: MortColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: MortColors.soft),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: labels.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final active = selected == index;
              return ChoiceChip(
                selected: active,
                label: Text(labels[index]),
                onSelected: (_) => onSelected(index),
                selectedColor: MortColors.text,
                backgroundColor: MortColors.panel,
                labelStyle: TextStyle(
                  color: active ? MortColors.black : MortColors.soft,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(
                  color: active ? MortColors.text : MortColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class JobCard extends StatelessWidget {
  const JobCard({
    required this.job,
    required this.fee,
    required this.net,
    required this.disabled,
    required this.onAccept,
    super.key,
  });

  final MortJob job;
  final double fee;
  final double net;
  final bool disabled;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final riskColor = job.riskScore <= 5
        ? MortColors.green
        : job.riskScore <= 8
        ? MortColors.blue
        : MortColors.amber;

    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: _iconForCategory(job.category),
                accent: riskColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${job.poster} • ${job.location}',
                      style: const TextStyle(
                        color: MortColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(job.amount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    job.payment.label,
                    style: const TextStyle(
                      color: MortColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.summary,
            style: const TextStyle(
              color: MortColors.soft,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TagPill(
                icon: Icons.near_me,
                label: '${job.distanceMiles.toStringAsFixed(1)} mi',
              ),
              TagPill(icon: Icons.schedule, label: '${job.estimatedMinutes}m'),
              TagPill(icon: Icons.bolt, label: '+${job.xp} XP'),
              TagPill(
                icon: Icons.shield,
                label: 'Risk ${job.riskScore}/100',
                accent: riskColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  fee == 0
                      ? 'Teen keeps full cash payout'
                      : '${formatMoney(fee)} MORT cut • ${formatMoney(net)} same day',
                  style: const TextStyle(
                    color: MortColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: disabled ? null : onAccept,
                icon: const Icon(Icons.flash_on),
                label: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    return switch (category) {
      'Yard' => Icons.yard,
      'Pets' => Icons.pets,
      'Cars' => Icons.local_car_wash,
      'Tutoring' => Icons.menu_book,
      _ => Icons.work,
    };
  }
}

class MotionScreen extends StatelessWidget {
  const MotionScreen({required this.state, super.key});

  final MortState state;

  @override
  Widget build(BuildContext context) {
    return ScreenList(
      children: [
        const AppHeader(
          eyebrow: 'Motion Feed',
          title: 'Wins move fast',
          actionIcon: Icons.add,
          actionTooltip: 'Post win',
        ),
        LeaderboardCard(state: state),
        const SectionHeader(title: 'Live progress', action: 'Local'),
        for (final post in state.feed) FeedCard(post: post),
        TeamHustleCard(openJobs: state.openJobs),
      ],
    );
  }
}

class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({required this.state, super.key});

  final MortState state;

  @override
  Widget build(BuildContext context) {
    final leaders = [
      ('Maya', state.todayEarned, MortColors.green),
      ('Jay', 42.0, MortColors.amber),
      ('Kira', 36.0, MortColors.blue),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Today board', action: 'Top 3'),
        Row(
          children: [
            for (var i = 0; i < leaders.length; i++) ...[
              Expanded(
                child: MortCard(
                  compact: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: leaders[i].$3,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        leaders[i].$1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatMoney(leaders[i].$2),
                        style: const TextStyle(
                          color: MortColors.soft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i != leaders.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class FeedCard extends StatelessWidget {
  const FeedCard({required this.post, super.key});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: post.icon, accent: post.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${post.name} ${post.handle}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${post.type} • ${post.time}',
                      style: const TextStyle(
                        color: MortColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                post.stat,
                style: TextStyle(
                  color: post.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.text,
            style: const TextStyle(
              color: MortColors.soft,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconText(icon: Icons.favorite_border, text: '${post.likes}'),
              const SizedBox(width: 18),
              const IconText(icon: Icons.mode_comment_outlined, text: 'Reply'),
              const Spacer(),
              const Icon(Icons.ios_share, size: 18, color: MortColors.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class TeamHustleCard extends StatelessWidget {
  const TeamHustleCard({required this.openJobs, super.key});

  final int openJobs;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Row(
        children: [
          const IconBadge(icon: Icons.groups_2, accent: MortColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Team queue',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  '$openJobs nearby jobs can turn into team hustles',
                  style: const TextStyle(color: MortColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Open team queue',
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({
    required this.state,
    required this.selectedIndex,
    required this.onSelect,
    required this.onScan,
    super.key,
  });

  final MortState state;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final selected = state.conversations[selectedIndex];

    return ScreenList(
      children: [
        AppHeader(
          eyebrow: 'Safe messages',
          title: 'Chat',
          actionIcon: Icons.shield,
          actionTooltip: 'Scan',
          onAction: onScan,
          trailing: TagPill(icon: Icons.auto_awesome, label: 'Shield on'),
        ),
        ScamShieldBanner(flags: state.scamFlagsCleared),
        const SectionHeader(title: 'Threads', action: 'Live'),
        for (var i = 0; i < state.conversations.length; i++)
          ConversationTile(
            conversation: state.conversations[i],
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
        SectionHeader(
          title: selected.name,
          action: selected.safe ? 'Safe' : 'Flagged',
        ),
        ChatPreview(conversation: selected, onScan: onScan),
      ],
    );
  }
}

class ScamShieldBanner extends StatelessWidget {
  const ScamShieldBanner({required this.flags, super.key});

  final int flags;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Row(
        children: [
          const Icon(Icons.security, color: MortColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scam Shield',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  '$flags risky links, off-app payment asks, and spam bursts cleared',
                  style: const TextStyle(color: MortColors.muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: MortCard(
        compact: true,
        highlighted: selected,
        child: Row(
          children: [
            IconBadge(
              icon: conversation.group ? Icons.groups : Icons.person,
              accent: conversation.safe ? MortColors.blue : MortColors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        conversation.time,
                        style: const TextStyle(
                          color: MortColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: MortColors.muted),
                  ),
                ],
              ),
            ),
            if (conversation.unread > 0) ...[
              const SizedBox(width: 10),
              CountBubble(count: conversation.unread),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatPreview extends StatelessWidget {
  const ChatPreview({
    required this.conversation,
    required this.onScan,
    super.key,
  });

  final Conversation conversation;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final message in conversation.messages) ...[
            Align(
              alignment: message.mine
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: message.mine ? MortColors.text : MortColors.raised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: message.safe ? MortColors.line : MortColors.red,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.mine
                            ? MortColors.black
                            : MortColors.soft,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Message locked to safe chat',
                    hintStyle: const TextStyle(color: MortColors.muted),
                    filled: true,
                    fillColor: MortColors.black,
                    prefixIcon: const Icon(Icons.lock, color: MortColors.muted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: MortColors.line),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: MortColors.line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onScan,
                tooltip: 'Scan chat',
                icon: const Icon(Icons.manage_search),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({required this.state, super.key});

  final MortState state;

  @override
  Widget build(BuildContext context) {
    return ScreenList(
      children: [
        AppHeader(
          eyebrow: 'Money stack',
          title: formatMoney(state.totalEarned),
          actionIcon: Icons.visibility,
          actionTooltip: 'Hide balance',
          trailing: TagPill(
            icon: state.cashAppReady ? Icons.check_circle : Icons.error,
            label: state.cashAppReady ? 'Cash App ready' : 'Setup',
          ),
        ),
        PayoutFlowCard(state: state),
        const SectionHeader(title: 'Goals', action: 'Auto-save on'),
        for (final goal in state.goals) GoalCard(goal: goal),
        const SectionHeader(title: 'Badges', action: 'Earned'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final badge in state.badges) BadgeCard(badge: badge)],
        ),
      ],
    );
  }
}

class PayoutFlowCard extends StatelessWidget {
  const PayoutFlowCard({required this.state, super.key});

  final MortState state;

  @override
  Widget build(BuildContext context) {
    final active = state.activeJob;
    final fee = active == null ? 0.0 : state.feeFor(active);
    final net = active == null ? 0.0 : state.netFor(active);

    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.payments, color: MortColors.green),
              SizedBox(width: 10),
              Text(
                'Payment paths',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PaymentRow(
            icon: Icons.payments_outlined,
            title: 'Cash',
            detail: 'Teen keeps 100%',
            amount: active?.payment == PaymentMethod.cash
                ? formatMoney(net)
                : 'Full',
            accent: MortColors.soft,
          ),
          const Divider(color: MortColors.line, height: 24),
          PaymentRow(
            icon: Icons.bolt,
            title: 'Cash App',
            detail: fee == 0
                ? 'Small MORT cut'
                : '${formatMoney(fee)} service cut',
            amount: fee == 0 ? 'Same day' : formatMoney(net),
            accent: MortColors.green,
          ),
        ],
      ),
    );
  }
}

class PaymentRow extends StatelessWidget {
  const PaymentRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.amount,
    required this.accent,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String amount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, accent: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(color: MortColors.muted)),
            ],
          ),
        ),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({required this.goal, super.key});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      compact: true,
      child: Row(
        children: [
          IconBadge(icon: goal.icon, accent: MortColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${(goal.progress * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: goal.progress,
                    color: MortColors.green,
                    backgroundColor: MortColors.line,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatMoney(goal.saved)} of ${formatMoney(goal.target)}',
                  style: const TextStyle(
                    color: MortColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeCard extends StatelessWidget {
  const BadgeCard({required this.badge, super.key});

  final EarnedBadge badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: MortCard(
        compact: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: badge.icon, accent: badge.accent),
            const SizedBox(height: 14),
            Text(
              badge.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(badge.detail, style: const TextStyle(color: MortColors.muted)),
          ],
        ),
      ),
    );
  }
}

class ShieldScreen extends StatelessWidget {
  const ShieldScreen({
    required this.state,
    required this.onChanged,
    required this.onEmergency,
    required this.onResolveEmergency,
    required this.onHumanCheck,
    required this.onPostJob,
    required this.onSignOut,
    super.key,
  });

  final MortState state;
  final VoidCallback onChanged;
  final VoidCallback onEmergency;
  final VoidCallback onResolveEmergency;
  final VoidCallback onHumanCheck;
  final VoidCallback onPostJob;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ScreenList(
      children: [
        AppHeader(
          eyebrow: 'Account shield',
          title: 'Safety',
          actionIcon: Icons.logout,
          actionTooltip: 'Sign out',
          onAction: onSignOut,
          trailing: TrustChip(score: state.trustScore),
        ),
        EmergencyPanel(
          active: state.emergencyActive,
          onEmergency: onEmergency,
          onResolve: onResolveEmergency,
        ),
        CheckInPanel(state: state, onChanged: onChanged),
        const SectionHeader(title: 'Failsafes', action: 'Connected'),
        for (final signal in state.trustSignals)
          TrustSignalTile(signal: signal),
        AdultVerificationPanel(
          verified: state.adultVerified,
          onToggle: (value) {
            state.adultVerified = value;
            onChanged();
          },
          onPostJob: onPostJob,
        ),
        AccountControls(
          state: state,
          onChanged: onChanged,
          onHumanCheck: onHumanCheck,
        ),
      ],
    );
  }
}

class EmergencyPanel extends StatelessWidget {
  const EmergencyPanel({
    required this.active,
    required this.onEmergency,
    required this.onResolve,
    super.key,
  });

  final bool active;
  final VoidCallback onEmergency;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      highlighted: active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active ? Icons.emergency_share : Icons.emergency,
                color: active ? MortColors.red : MortColors.soft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active ? 'Emergency alert live' : 'Emergency ready',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FullWidthAction(
            icon: active ? Icons.done : Icons.sos,
            label: active ? 'Resolve alert' : 'Send emergency alert',
            danger: !active,
            onPressed: active ? onResolve : onEmergency,
          ),
        ],
      ),
    );
  }
}

class CheckInPanel extends StatelessWidget {
  const CheckInPanel({required this.state, required this.onChanged, super.key});

  final MortState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.family_restroom, color: MortColors.blue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Parent alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              Switch(
                value: state.parentAlerts,
                onChanged: (value) {
                  state.parentAlerts = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TagPill(icon: Icons.timer, label: 'Last ${state.lastCheckIn}'),
              const TagPill(icon: Icons.location_on, label: 'Radius 3 mi'),
              const TagPill(icon: Icons.person_pin_circle, label: 'Live route'),
            ],
          ),
        ],
      ),
    );
  }
}

class TrustSignalTile extends StatelessWidget {
  const TrustSignalTile({required this.signal, super.key});

  final TrustSignal signal;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      compact: true,
      child: Row(
        children: [
          IconBadge(icon: signal.icon, accent: signal.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              signal.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            signal.value,
            style: TextStyle(color: signal.accent, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class AdultVerificationPanel extends StatelessWidget {
  const AdultVerificationPanel({
    required this.verified,
    required this.onToggle,
    required this.onPostJob,
    super.key,
  });

  final bool verified;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPostJob;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.badge : Icons.badge_outlined,
                color: verified ? MortColors.green : MortColors.amber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verified ? 'Adult poster verified' : 'Adult poster locked',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch(value: verified, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  verified
                      ? 'ID, payment, address, and device checks passed'
                      : 'ID and payment checks must pass before posting',
                  style: const TextStyle(color: MortColors.muted, height: 1.35),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: verified ? onPostJob : null,
                tooltip: 'Post verified job',
                icon: const Icon(Icons.add_business),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AccountControls extends StatelessWidget {
  const AccountControls({
    required this.state,
    required this.onChanged,
    required this.onHumanCheck,
    super.key,
  });

  final MortState state;
  final VoidCallback onChanged;
  final VoidCallback onHumanCheck;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account links',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          const LinkedAccountRow(
            icon: Icons.apple,
            name: 'Apple',
            status: 'Ready',
          ),
          const Divider(color: MortColors.line, height: 24),
          const LinkedAccountRow(
            icon: Icons.g_mobiledata,
            name: 'Google',
            status: 'Linked',
          ),
          const Divider(color: MortColors.line, height: 24),
          LinkedAccountRow(
            icon: Icons.attach_money,
            name: 'Cash App',
            status: state.cashAppReady ? 'Verified' : 'Needs setup',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onHumanCheck,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Trust check'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    state.cashAppReady = !state.cashAppReady;
                    onChanged();
                  },
                  icon: const Icon(Icons.sync_lock),
                  label: const Text('Payout lock'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LinkedAccountRow extends StatelessWidget {
  const LinkedAccountRow({
    required this.icon,
    required this.name,
    required this.status,
    super.key,
  });

  final IconData icon;
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MortColors.soft),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          status,
          style: const TextStyle(
            color: MortColors.green,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class PostJobSheet extends StatefulWidget {
  const PostJobSheet({required this.adultVerified, super.key});

  final bool adultVerified;

  @override
  State<PostJobSheet> createState() => _PostJobSheetState();
}

class _PostJobSheetState extends State<PostJobSheet> {
  final _title = TextEditingController(text: 'Garage box cleanup');
  final _amount = TextEditingController(text: '42');
  PaymentMethod _payment = PaymentMethod.cashApp;
  bool _team = false;
  bool _parentPing = true;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.adultVerified ? Icons.verified_user : Icons.lock,
                color: widget.adultVerified ? MortColors.green : MortColors.red,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Post verified job',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MortInput(controller: _title, label: 'Title', icon: Icons.work),
          const SizedBox(height: 10),
          MortInput(
            controller: _amount,
            label: 'Payout',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(
                value: PaymentMethod.cash,
                icon: Icon(Icons.payments),
                label: Text('Cash'),
              ),
              ButtonSegment(
                value: PaymentMethod.cashApp,
                icon: Icon(Icons.bolt),
                label: Text('Cash App'),
              ),
            ],
            selected: {_payment},
            onSelectionChanged: (selected) {
              setState(() => _payment = selected.first);
            },
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _team,
            onChanged: (value) => setState(() => _team = value),
            title: const Text('Team hustle'),
            secondary: const Icon(Icons.groups_2),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _parentPing,
            onChanged: (value) => setState(() => _parentPing = value),
            title: const Text('Parent alert required'),
            secondary: const Icon(Icons.family_restroom),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          FullWidthAction(
            icon: Icons.publish,
            label: widget.adultVerified
                ? 'Post to MORT'
                : 'Verification locked',
            onPressed: widget.adultVerified ? _submit : null,
          ),
        ],
      ),
    );
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim()) ?? 30;
    Navigator.of(context).pop(
      MortJob(
        id: 'adult-${DateTime.now().millisecondsSinceEpoch}',
        title: _title.text.trim().isEmpty
            ? 'Local helper job'
            : _title.text.trim(),
        category: 'General',
        poster: 'Verified adult',
        location: 'Nearby',
        summary:
            'Adult verified, payment locked, and safety check-ins enabled.',
        amount: amount,
        distanceMiles: 1.3,
        estimatedMinutes: 60,
        payment: _payment,
        xp: 95,
        trustScore: 95,
        riskScore: 6,
        verifiedAdult: true,
        parentAlertRequired: _parentPing,
        teamJob: _team,
        postedAgo: 'Now',
        tags: ['Verified', _team ? 'Team' : 'Solo', _payment.label],
        safetyFlags: ['ID checked', 'Payment locked', 'Bot screened'],
      ),
    );
  }
}

class MortInput extends StatelessWidget {
  const MortInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: MortColors.black,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MortColors.soft),
        ),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.eyebrow,
    required this.title,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.trailing,
    super.key,
  });

  final String eyebrow;
  final String title;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const MortLogo(size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MortColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MortColors.text,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (actionIcon != null) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onAction,
            tooltip: actionTooltip,
            icon: Icon(actionIcon),
          ),
        ],
      ],
    );
  }
}

class MortLogo extends StatelessWidget {
  const MortLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MortColors.text,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'M',
            style: TextStyle(
              color: MortColors.black,
              fontSize: size * .52,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class MortCard extends StatelessWidget {
  const MortCard({
    required this.child,
    this.compact = false,
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final bool compact;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? MortColors.raised : MortColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? MortColors.soft : MortColors.line,
          width: highlighted ? 1.2 : 1,
        ),
      ),
      child: Padding(padding: EdgeInsets.all(compact ? 12 : 16), child: child),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MortColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.action, super.key});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            color: MortColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class MortProgress extends StatelessWidget {
  const MortProgress({
    required this.label,
    required this.value,
    required this.accent,
    super.key,
  });

  final String label;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt, size: 16, color: MortColors.amber),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: MortColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: value,
            color: accent,
            backgroundColor: MortColors.line,
          ),
        ),
      ],
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({required this.icon, required this.accent, super.key});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: .35)),
        ),
        child: Icon(icon, color: accent, size: 21),
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill({
    required this.icon,
    required this.label,
    this.accent = MortColors.soft,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MortColors.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MortColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: MortColors.soft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrustChip extends StatelessWidget {
  const TrustChip({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    return TagPill(
      icon: Icons.verified_user,
      label: '$score',
      accent: score > 90 ? MortColors.green : MortColors.amber,
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? MortColors.green : MortColors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class CountBubble extends StatelessWidget {
  const CountBubble({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MortColors.text,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '$count',
          style: const TextStyle(
            color: MortColors.black,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class IconText extends StatelessWidget {
  const IconText({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: MortColors.muted, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: MortColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class FullWidthAction extends StatelessWidget {
  const FullWidthAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtle = false,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool subtle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final style = subtle
        ? OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: danger ? MortColors.red : MortColors.text,
            foregroundColor: MortColors.black,
            disabledBackgroundColor: MortColors.line,
            disabledForegroundColor: MortColors.muted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );

    return subtle
        ? OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}
