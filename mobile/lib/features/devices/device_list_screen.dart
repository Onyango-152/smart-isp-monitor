import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/device_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import 'device_provider.dart';

/// DeviceListScreen shows all monitored devices with search and filter.
///
/// Layout:
///   Gradient AppBar (title, device count badge, refresh)
///   Search TextField
///   Horizontal filter chip row (status + type)
///   Results count / Clear Filters row
///   ListView of DeviceListTile (with pull-to-refresh)
///   FAB: Add Device
///
/// All state is owned by DeviceProvider.
class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<DeviceProvider>();
    // Restore persisted search query into the text field
    if (provider.searchQuery.isNotEmpty) {
      _searchController.text = provider.searchQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.loadDevices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar:          _buildAppBar(),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {

          // Loading
          if (provider.isLoading) {
            return ShimmerSkeleton.deviceList(animate: false);
          }

          // Error
          if (provider.hasError) {
            return EmptyState(
              icon:        Icons.cloud_off_rounded,
              title:       'Could Not Load Devices',
              message:     provider.errorMessage!,
              color:       AppColors.offline,
              animate:     false,
              actionLabel: 'Retry',
              onAction:    provider.loadDevices,
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
      floatingActionButton: null,
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
      title: Consumer<DeviceProvider>(
        builder: (_, provider, __) => Row(
          children: [
            const Text('Devices', style: TextStyle(color: AppColors.textOnDark)),
            if (!provider.isLoading && !provider.hasError) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColors.textOnDark.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.totalCount}',
                  style: const TextStyle(
                    color:      AppColors.textOnDark,
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
        Consumer<DeviceProvider>(
          builder: (_, provider, __) => IconButton(
            icon:      const Icon(Icons.refresh_rounded, color: AppColors.textOnDark),
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

  Widget _buildSearchBar(DeviceProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller:  _searchController,
        onChanged:   provider.search,
        style:       AppTextStyles.body,
        decoration: InputDecoration(
          hintText:   'Search by name, IP, location…',
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

  Widget _buildFilterRow(DeviceProvider provider) {
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
            label:    'Online',
            selected: provider.statusFilter == AppConstants.statusOnline,
            onTap:    () =>
                provider.setStatusFilter(AppConstants.statusOnline),
            color:    AppColors.primary,
          ),
          _FilterChip(
            label:    'Offline',
            selected: provider.statusFilter == AppConstants.statusOffline,
            onTap:    () =>
                provider.setStatusFilter(AppConstants.statusOffline),
            color:    AppColors.primary,
          ),
          _FilterChip(
            label:    'Degraded',
            selected: provider.statusFilter == AppConstants.statusDegraded,
            onTap:    () =>
                provider.setStatusFilter(AppConstants.statusDegraded),
            color:    AppColors.primary,
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child:   VerticalDivider(width: 1),
          ),

          // ── Type chips ───────────────────────────────────────────────
          _FilterChip(
            label:    'Routers',
            selected: provider.typeFilter == AppConstants.deviceRouter,
            onTap:    () =>
                provider.setTypeFilter(AppConstants.deviceRouter),
          ),
          _FilterChip(
            label:    'Switches',
            selected: provider.typeFilter == AppConstants.deviceSwitch,
            onTap:    () =>
                provider.setTypeFilter(AppConstants.deviceSwitch),
          ),
          _FilterChip(
            label:    'OLTs',
            selected: provider.typeFilter == AppConstants.deviceOlt,
            onTap:    () =>
                provider.setTypeFilter(AppConstants.deviceOlt),
          ),
          _FilterChip(
            label:    'Access Points',
            selected: provider.typeFilter == AppConstants.deviceAccessPoint,
            onTap:    () =>
                provider.setTypeFilter(AppConstants.deviceAccessPoint),
          ),
        ],
      ),
    );
  }

  // ── Results bar ───────────────────────────────────────────────────────────

  Widget _buildResultsBar(DeviceProvider provider) {
    final showing = provider.filteredCount;
    final total   = provider.totalCount;
    final label   = provider.hasActiveFilters
        ? 'Showing $showing of $total'
        : '$total device${total != 1 ? "s" : ""}';

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

  // ── Device list ───────────────────────────────────────────────────────────

  Widget _buildList(DeviceProvider provider) {
    if (provider.devices.isEmpty) {
      final isSearchEmpty = provider.searchQuery.isNotEmpty;
      return EmptyState(
        icon:    isSearchEmpty
            ? Icons.search_off_rounded
            : Icons.filter_list_off_rounded,
        title:   isSearchEmpty ? 'No Results' : 'No Devices Match',
        message: isSearchEmpty
            ? 'No devices match "${provider.searchQuery}". Try different keywords.'
            : 'No devices match the selected filters.',
        color:           AppColors.primary,
        animate:         false,
        actionLabel:     isSearchEmpty ? 'Clear Search' : 'Clear Filters',
        onAction: () {
          _searchController.clear();
          provider.clearFilters();
        },
        secondaryLabel: provider.hasActiveFilters && isSearchEmpty
            ? 'Clear All Filters'
            : null,
        onSecondary: provider.hasActiveFilters && isSearchEmpty
            ? () {
                _searchController.clear();
                provider.clearFilters();
              }
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color:     AppColors.primary,
      child: ListView.builder(
        padding:     const EdgeInsets.only(top: 8, bottom: 100),
        itemCount:   provider.devices.length,
        itemBuilder: (context, index) {
          final device = provider.devices[index];
          return DeviceListTile(
            device:       device,
            latestMetric: provider.getLatestMetric(device.id),
            onTap: () => Navigator.of(context).pushNamed(
              AppConstants.deviceDetailRoute,
              arguments: device,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterChip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final Color?       color;    // accent colour when selected

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
          child: Container(
          padding:  const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
            color:        selected
                ? accent.withOpacity(0.12)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : AppColors.dividerOf(context),
              width: selected ? 1.5   : 1.0,
            ),
            boxShadow: selected
                ? []
                : [
                    BoxShadow(
                      color:      AppColors.dividerOf(context).withOpacity(0.4),
                      blurRadius: 4,
                      offset:     const Offset(0, 1),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize:   12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:      selected ? accent : AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}