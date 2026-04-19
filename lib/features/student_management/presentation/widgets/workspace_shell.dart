import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_navigation_history.dart';
import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import 'motion_widgets.dart';

enum WorkspaceSection {
  dashboard,
  studentIntake,
  operations,
  records,
  results,
  allResults,
  analytics,
  resultEntry,
  explorer,
  search,
  profiles,
  settings,
}

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.currentSection,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.session,
    this.actions = const <Widget>[],
    this.searchInitialValue = '',
    this.eyebrow = 'School Operations',
    this.breadcrumbs = const <Map<String, String>>[],
  });

  final WorkspaceSection currentSection;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final SessionUser? session;
  final List<Widget> actions;
  final String searchInitialValue;
  final List<Map<String, String>> breadcrumbs;

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  static const Duration _idleTimeout = Duration(minutes: 15);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TextEditingController _searchController;
  Timer? _idleTimer;
  bool _isLoggingOut = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchInitialValue);
    _restartInactivityTimer();
  }

  @override
  void didUpdateWidget(covariant WorkspaceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchInitialValue != oldWidget.searchInitialValue &&
        widget.searchInitialValue != _searchController.text) {
      _searchController.text = widget.searchInitialValue;
    }
    if (widget.session?.id != oldWidget.session?.id ||
        widget.currentSection != oldWidget.currentSection) {
      _restartInactivityTimer();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 1320;
    final List<Widget> headerActions = <Widget>[
      ...widget.actions,
      if (widget.session != null)
        FilledButton.tonalIcon(
          onPressed: _isRefreshing ? null : _refreshWorkspace,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      if (widget.session != null)
        FilledButton.tonalIcon(
          onPressed: _isLoggingOut ? null : () => _performLogout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
        ),
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        _registerUserActivity();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _registerUserActivity(),
        onPointerMove: (_) => _registerUserActivity(),
        onPointerSignal: (_) => _registerUserActivity(),
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: wide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: _ShellSidebar(
                      currentSection: widget.currentSection,
                      session: widget.session,
                      searchController: _searchController,
                      onSearch: _handleSearch,
                      onLogout: _isLoggingOut ? null : _performLogout,
                      idleTimeoutLabel:
                          '${_idleTimeout.inMinutes} min idle auto logout',
                      compact: true,
                    ),
                  ),
                ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _mobileIndex(widget.currentSection),
                  onDestinationSelected: (int index) {
                    _registerUserActivity();
                    switch (index) {
                      case 0:
                        context.go('/dashboard');
                      case 1:
                        context.go('/manage');
                      case 2:
                        context.go('/results');
                      case 3:
                        context.go('/analytics');
                      case 4:
                        _openNavigationDrawer();
                    }
                  },
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.edit_note_outlined),
                      selectedIcon: Icon(Icons.edit_note_rounded),
                      label: 'Manage',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check_rounded),
                      label: 'Results',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.analytics_outlined),
                      selectedIcon: Icon(Icons.analytics_rounded),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_open_rounded),
                      selectedIcon: Icon(Icons.menu_rounded),
                      label: 'More',
                    ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              children: <Widget>[
                if (wide)
                  _ShellSidebar(
                    currentSection: widget.currentSection,
                    session: widget.session,
                    searchController: _searchController,
                    onSearch: _handleSearch,
                    onLogout: _isLoggingOut ? null : _performLogout,
                    idleTimeoutLabel:
                        '${_idleTimeout.inMinutes} min idle auto logout',
                  ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      RevealMotion(
                        delay: const Duration(milliseconds: 40),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 12 : 20,
                            20,
                            20,
                            12,
                          ),
                          child: _ShellHeader(
                            eyebrow: widget.eyebrow,
                            title: widget.title,
                            subtitle: widget.subtitle,
                            actions: headerActions,
                            searchController: _searchController,
                            onSearch: _handleSearch,
                            breadcrumbs: widget.breadcrumbs,
                            showNavigationMenu: !wide,
                            onOpenNavigationMenu: _openNavigationDrawer,
                          ),
                        ),
                      ),
                      Expanded(
                        child: RevealMotion(
                          delay: const Duration(milliseconds: 120),
                          child: widget.session == null
                              ? widget.child
                              : RefreshIndicator.adaptive(
                                  onRefresh: _refreshWorkspace,
                                  child: widget.child,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _registerUserActivity() {
    if (widget.session == null || _isLoggingOut) {
      return;
    }
    _restartInactivityTimer();
  }

  void _restartInactivityTimer() {
    _idleTimer?.cancel();
    if (widget.session == null) {
      return;
    }
    _idleTimer = Timer(_idleTimeout, () => _performLogout(automatic: true));
  }

  int _mobileIndex(WorkspaceSection section) {
    switch (section) {
      case WorkspaceSection.dashboard:
        return 0;
      case WorkspaceSection.studentIntake:
        return 1;
      case WorkspaceSection.operations:
        return 1;
      case WorkspaceSection.records:
        return 1;
      case WorkspaceSection.results:
        return 2;
      case WorkspaceSection.allResults:
        return 2;
      case WorkspaceSection.analytics:
        return 3;
      case WorkspaceSection.resultEntry:
        return 4;
      case WorkspaceSection.explorer:
        return 4;
      case WorkspaceSection.search:
        return 4;
      case WorkspaceSection.profiles:
        return 4;
      case WorkspaceSection.settings:
        return 4;
    }
  }

  void _openNavigationDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleSearch() {
    _registerUserActivity();
    final String query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    context.go('/search?query=${Uri.encodeComponent(query)}');
  }

  Future<void> _refreshWorkspace() async {
    if (!mounted || widget.session == null || _isRefreshing) {
      return;
    }
    _registerUserActivity();
    final SchoolAdminController controller = ref.read(
      schoolAdminProvider.notifier,
    );
    if (!controller.hasLiveBackend) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });
    try {
      await controller.refreshData();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _performLogout({bool automatic = false}) {
    if (!mounted || widget.session == null || _isLoggingOut) {
      return;
    }

    _isLoggingOut = true;
    _idleTimer?.cancel();
    ref.read(schoolAdminProvider.notifier).logout();

    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          automatic
              ? 'You were logged out after ${_idleTimeout.inMinutes} minutes of inactivity.'
              : 'You have been logged out securely.',
        ),
      ),
    );

    context.go('/login');
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.searchController,
    required this.onSearch,
    required this.breadcrumbs,
    this.showNavigationMenu = false,
    this.onOpenNavigationMenu,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final List<Map<String, String>> breadcrumbs;
  final bool showNavigationMenu;
  final VoidCallback? onOpenNavigationMenu;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compact = width < 1100 || (actions.length > 1 && width < 1320);
    final bool extraCompact = width < 520;
    final GoRouter router = GoRouter.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: extraCompact ? 16 : 20,
        vertical: extraCompact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedBuilder(
                  animation: AppNavigationHistory.instance,
                  builder: (BuildContext context, Widget? child) {
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        if (showNavigationMenu)
                          _HeaderToolbarButton(
                            icon: Icons.menu_rounded,
                            label: 'Menu',
                            compact: extraCompact,
                            onPressed: onOpenNavigationMenu,
                          ),
                        _HeaderToolbarButton(
                          icon: Icons.arrow_back_rounded,
                          label: 'Back',
                          compact: extraCompact,
                          onPressed: AppNavigationHistory.instance.canGoBack
                              ? () =>
                                    AppNavigationHistory.instance.goBack(router)
                              : null,
                        ),
                        _HeaderToolbarButton(
                          icon: Icons.arrow_forward_rounded,
                          label: 'Forward',
                          compact: extraCompact,
                          onPressed: AppNavigationHistory.instance.canGoForward
                              ? () => AppNavigationHistory.instance.goForward(
                                  router,
                                )
                              : null,
                        ),
                      ],
                    );
                  },
                ),
                if (breadcrumbs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _BreadcrumbTrail(breadcrumbs: breadcrumbs),
                ],
                const SizedBox(height: 16),
                _HeaderCopy(
                  eyebrow: eyebrow,
                  title: title,
                  subtitle: subtitle,
                  compact: extraCompact,
                ),
                const SizedBox(height: 16),
                _SearchBar(controller: searchController, onSearch: onSearch),
                if (actions.isNotEmpty) const SizedBox(height: 16),
                if (actions.isNotEmpty)
                  Wrap(spacing: 12, runSpacing: 12, children: actions),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: AppNavigationHistory.instance,
                        builder: (BuildContext context, Widget? child) {
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _HeaderToolbarButton(
                                icon: Icons.arrow_back_rounded,
                                label: 'Back',
                                compact: extraCompact,
                                onPressed:
                                    AppNavigationHistory.instance.canGoBack
                                    ? () => AppNavigationHistory.instance
                                          .goBack(router)
                                    : null,
                              ),
                              _HeaderToolbarButton(
                                icon: Icons.arrow_forward_rounded,
                                label: 'Forward',
                                compact: extraCompact,
                                onPressed:
                                    AppNavigationHistory.instance.canGoForward
                                    ? () => AppNavigationHistory.instance
                                          .goForward(router)
                                    : null,
                              ),
                            ],
                          );
                        },
                      ),
                      if (breadcrumbs.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        _BreadcrumbTrail(breadcrumbs: breadcrumbs),
                      ],
                      const SizedBox(height: 16),
                      _HeaderCopy(
                        eyebrow: eyebrow,
                        title: title,
                        subtitle: subtitle,
                        compact: extraCompact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 3,
                  child: _SearchBar(
                    controller: searchController,
                    onSearch: onSearch,
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 18),
                  Wrap(spacing: 12, runSpacing: 12, children: actions),
                ],
              ],
            ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF155EEF),
            letterSpacing: compact ? 0.8 : 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: compact
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: compact ? 3 : 4,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF475569),
            height: compact ? 1.35 : 1.45,
          ),
        ),
      ],
    );
  }
}

class _HeaderToolbarButton extends StatelessWidget {
  const _HeaderToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: label,
        child: IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon)),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ShellSidebar extends StatelessWidget {
  const _ShellSidebar({
    required this.currentSection,
    required this.session,
    required this.searchController,
    required this.onSearch,
    required this.onLogout,
    required this.idleTimeoutLabel,
    this.compact = false,
  });

  final WorkspaceSection currentSection;
  final SessionUser? session;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback? onLogout;
  final String idleTimeoutLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? double.infinity : 300,
      margin: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 20, 0, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 0 : 32),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF162B4D),
            Color(0xFF155EEF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.hub_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Student Command',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Production workspace',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.76,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (session != null) ...<Widget>[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              session!.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${session!.role.shortLabel} • ${session!.schoolName}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SearchBar(
                      controller: searchController,
                      onSearch: onSearch,
                      darkMode: true,
                    ),
                    const SizedBox(height: 22),
                    RevealMotion(
                      delay: const Duration(milliseconds: 60),
                      child: _SidebarItem(
                        icon: Icons.space_dashboard_rounded,
                        title: 'Dashboard',
                        subtitle: 'School overview',
                        active: currentSection == WorkspaceSection.dashboard,
                        onTap: () => context.go('/dashboard'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 85),
                      child: _SidebarItem(
                        icon: Icons.person_add_rounded,
                        title: 'Student Registration',
                        subtitle: 'Add & manage student intake',
                        active:
                            currentSection == WorkspaceSection.studentIntake,
                        onTap: () => context.go('/student-intake'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 100),
                      child: _SidebarItem(
                        icon: Icons.edit_note_rounded,
                        title: 'School Operations',
                        subtitle: 'Intake, teachers, and upload flow',
                        active: currentSection == WorkspaceSection.operations,
                        onTap: () => context.go('/manage'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 140),
                      child: _SidebarItem(
                        icon: Icons.history_edu_rounded,
                        title: 'Records',
                        subtitle: 'Archive and registry',
                        active: currentSection == WorkspaceSection.records,
                        onTap: () => context.go('/records'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 180),
                      child: _SidebarItem(
                        icon: Icons.fact_check_rounded,
                        title: 'Results',
                        subtitle: 'Tables and divisions',
                        active: currentSection == WorkspaceSection.results,
                        onTap: () => context.go('/results'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 220),
                      child: _SidebarItem(
                        icon: Icons.border_color_rounded,
                        title: 'Result Entry',
                        subtitle: 'Dedicated subject scores',
                        active: currentSection == WorkspaceSection.resultEntry,
                        onTap: () => context.go('/result-entry'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 240),
                      child: _SidebarItem(
                        icon: Icons.table_chart_rounded,
                        title: 'Uploaded Results',
                        subtitle: 'Merged forms, subject rows',
                        active: currentSection == WorkspaceSection.allResults,
                        onTap: () => context.go('/all-results'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 280),
                      child: _SidebarItem(
                        icon: Icons.analytics_rounded,
                        title: 'Analytics',
                        subtitle: 'Student, subject, and class trends',
                        active: currentSection == WorkspaceSection.analytics,
                        onTap: () => context.go('/analytics'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 320),
                      child: _SidebarItem(
                        icon: Icons.perm_media_rounded,
                        title: 'Profiles',
                        subtitle: 'School and teachers',
                        active: currentSection == WorkspaceSection.profiles,
                        onTap: () => context.go('/profiles'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 360),
                      child: _SidebarItem(
                        icon: Icons.account_tree_rounded,
                        title: 'Explorer',
                        subtitle: 'District drill-down',
                        active: currentSection == WorkspaceSection.explorer,
                        onTap: () => context.go('/explorer'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 400),
                      child: _SidebarItem(
                        icon: Icons.manage_search_rounded,
                        title: 'Search',
                        subtitle: 'Students, teachers, results',
                        active: currentSection == WorkspaceSection.search,
                        onTap: () => context.go('/search'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RevealMotion(
                      delay: const Duration(milliseconds: 440),
                      child: _SidebarItem(
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        subtitle: 'Policies and permissions',
                        active: currentSection == WorkspaceSection.settings,
                        onTap: () => context.go('/settings'),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Platform posture',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Teachers can upload scores, headmaster can monitor every workflow, and reports can be exported from the live views.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  idleTimeoutLabel,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: onLogout,
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Logout'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BreadcrumbTrail extends StatelessWidget {
  const _BreadcrumbTrail({required this.breadcrumbs});

  final List<Map<String, String>> breadcrumbs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (int i = 0; i < breadcrumbs.length; i++) ...<Widget>[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Icon(Icons.chevron_right_rounded, size: 16),
            ),
          InkWell(
            onTap: breadcrumbs[i]['route'] != null
                ? () => context.go(breadcrumbs[i]['route']!)
                : null,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: breadcrumbs[i]['route'] == null
                    ? const Color(0xFFEAF1FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: breadcrumbs[i]['route'] == null
                      ? const Color(0xFFC9DAFF)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                breadcrumbs[i]['label']!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: breadcrumbs[i]['route'] == null
                      ? const Color(0xFF155EEF)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSearch,
    this.darkMode = false,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSearch(),
      style: TextStyle(
        color: darkMode ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: 'Search students, teachers, results, or classes',
        prefixIcon: Icon(
          Icons.search_rounded,
          color: darkMode ? Colors.white70 : const Color(0xFF64748B),
        ),
        suffixIcon: IconButton(
          onPressed: onSearch,
          icon: Icon(
            Icons.arrow_forward_rounded,
            color: darkMode ? Colors.white : const Color(0xFF155EEF),
          ),
        ),
        fillColor: darkMode
            ? Colors.white.withValues(alpha: 0.1)
            : const Color(0xFFF8FAFC),
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: darkMode ? Colors.white70 : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: Colors.black,
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
