import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../data/models/user_model.dart';
import 'clients_provider.dart';
import 'client_detail_screen.dart';

/// ClientsScreen shows all customer accounts managed by the technician.
///
/// Layout:
///   Gradient AppBar (title, client count badge, refresh)
///   Search TextField
///   Horizontal filter chip row (status + plan)
///   Results count / Clear Filters row
///   ListView of client cards (with pull-to-refresh)
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<ClientsProvider>();
    if (provider.searchQuery.isNotEmpty) {
      _searchController.text = provider.searchQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.loadClients();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar:          _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context)
              .pushNamed(AppConstants.clientFormRoute);
          if (created == true && mounted) {
            AppUtils.showSnackbar(context, 'Client added');
          }
        },
        backgroundColor: AppColors.primary,
        icon:  const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Client',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Consumer<ClientsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return ShimmerSkeleton.deviceList();
          }

          if (provider.hasError) {
            return EmptyState(
              icon:        Icons.cloud_off_rounded,
              title:       'Could Not Load Clients',
              message:     provider.errorMessage!,
              color:       AppColors.offline,
              actionLabel: 'Retry',
              onAction:    provider.loadClients,
            );
          }

          return Column(
            children: [
              _buildSearchBar(provider),
              _buildFilterRow(provider),
              _buildResultsBar(provider),
              const Divider(height: 1),
              Expanded(child: _buildList(provider)),
            ],
          );
        },
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [
              AppColors.appBarGradientStart,
              AppColors.appBarGradientEnd,
            ],
          ),
        ),
      ),
      title: Consumer<ClientsProvider>(
        builder: (_, provider, __) => Row(
          children: [
            const Text('Clients', style: TextStyle(color: Colors.white)),
            if (!provider.isLoading && !provider.hasError) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.totalCount}',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Consumer<ClientsProvider>(
          builder: (_, provider, __) => IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: provider.isLoading ? null : () {
              AppUtils.haptic();
              provider.refresh();
            },
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(ClientsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller:  _searchController,
        onChanged:   provider.search,
        style:       AppTextStyles.body,
        decoration: InputDecoration(
          hintText:   'Search by name, email, plan…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: provider.searchQuery.isNotEmpty
              ? IconButton(
                  icon:      const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    provider.search('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ── Filter chip row ───────────────────────────────────────────────────────

  Widget _buildFilterRow(ClientsProvider provider) {
    return SizedBox(
      height: 46,
      child: ListView(
        padding:         const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        children: [
          // ── Status chips ─────────────────────────────────────────────
          _FilterChip(
            label:    'All',
            selected: provider.statusFilter == 'all',
            onTap:    () => provider.setStatusFilter('all'),
          ),
          _FilterChip(
            label:    'Active',
            selected: provider.statusFilter == 'active',
            onTap:    () => provider.setStatusFilter('active'),
            color:    AppColors.online,
          ),
          _FilterChip(
            label:    'Inactive',
            selected: provider.statusFilter == 'inactive',
            onTap:    () => provider.setStatusFilter('inactive'),
            color:    AppColors.offline,
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child:   VerticalDivider(width: 1),
          ),

          // ── Plan chips ───────────────────────────────────────────────
          ...provider.availablePlans.map((plan) => _FilterChip(
            label:    plan,
            selected: provider.planFilter == plan,
            onTap:    () => provider.setPlanFilter(
                provider.planFilter == plan ? 'all' : plan),
          )),
        ],
      ),
    );
  }

  // ── Results bar ───────────────────────────────────────────────────────────

  Widget _buildResultsBar(ClientsProvider provider) {
    final showing = provider.filteredCount;
    final total   = provider.totalCount;
    final label   = provider.hasActiveFilters
        ? 'Showing $showing of $total'
        : '$total client${total != 1 ? "s" : ""}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          if (provider.hasActiveFilters) ...[
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              onPressed: () {
                _searchController.clear();
                AppUtils.hapticSelect();
                provider.clearFilters();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
              ),
              label: Text('Clear Filters',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                  )),
            ),
          ],
        ],
      ),
    );
  }

  // ── Client list ───────────────────────────────────────────────────────────

  Widget _buildList(ClientsProvider provider) {
    if (provider.clients.isEmpty) {
      final isSearchEmpty = provider.searchQuery.isNotEmpty;
      return EmptyState(
        icon:    isSearchEmpty
            ? Icons.search_off_rounded
            : Icons.filter_list_off_rounded,
        title:   isSearchEmpty ? 'No Results' : 'No Clients Match',
        message: isSearchEmpty
            ? 'No clients match "${provider.searchQuery}". Try different keywords.'
            : 'No clients match the selected filters.',
        color:       AppColors.primary,
        actionLabel: isSearchEmpty ? 'Clear Search' : 'Clear Filters',
        onAction: () {
          _searchController.clear();
          provider.clearFilters();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color:     AppColors.primary,
      child: ListView.builder(
        padding:     const EdgeInsets.only(top: 8, bottom: 100),
        itemCount:   provider.clients.length,
        itemBuilder: (context, index) {
          final client = provider.clients[index];
          return _ClientListTile(
            client:     client,
            plan:       provider.getPlan(client.id),
            devices:    provider.getDevices(client.id),
            onlineCount: provider.getOnlineDeviceCount(client.id),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: ClientDetailScreen(client: client),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ClientListTile
// ─────────────────────────────────────────────────────────────────────────────

class _ClientListTile extends StatelessWidget {
  final UserModel client;
  final String    plan;
  final List      devices;
  final int       onlineCount;
  final VoidCallback onTap;

  const _ClientListTile({
    required this.client,
    required this.plan,
    required this.devices,
    required this.onlineCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(client.username);
    final isActive = client.isActive;
    final statusColor = isActive ? AppColors.online : AppColors.offline;
    final statusBg    = isActive ? AppColors.onlineLight : AppColors.offlineLight;
    final statusLabel = isActive ? 'Active' : 'Inactive';
    final totalDevices = devices.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap:         onTap,
          borderRadius:  BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                // ── Avatar ──────────────────────────────────────────────
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color:        AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color:      AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize:   16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Info ────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.username,
                              style: AppTextStyles.heading3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:        statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color:      statusColor,
                                fontSize:   10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Email
                      Text(
                        client.email,
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Plan + devices row
                      Row(
                        children: [
                          // Plan badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _planColor(plan).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              plan,
                              style: TextStyle(
                                color:      _planColor(plan),
                                fontSize:   10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Device count
                          Icon(Icons.router_rounded,
                              size: 13, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(
                            '$onlineCount/$totalDevices online',
                            style: AppTextStyles.caption.copyWith(
                              color: onlineCount == totalDevices
                                  ? AppColors.online
                                  : onlineCount == 0
                                      ? AppColors.offline
                                      : AppColors.degraded,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          // Last seen
                          Text(
                            AppUtils.timeAgo(client.lastLogin),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _planColor(String plan) {
    switch (plan) {
      case 'Business Pro':        return AppColors.primary;
      case 'Business Enterprise': return AppColors.maintenance;
      case 'Home Premium':        return AppColors.degraded;
      case 'Home Basic':          return AppColors.online;
      default:                    return AppColors.unknown;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterChip (same pattern as DeviceListScreen)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final Color?       color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: GestureDetector(
        onTap: () {
          AppUtils.hapticSelect();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:  const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
            color:        selected
                ? accent.withOpacity(0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : AppColors.divider,
              width: selected ? 1.5   : 1.0,
            ),
            boxShadow: selected
                ? []
                : [
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset:     const Offset(0, 1),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize:   12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color:      selected ? accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
