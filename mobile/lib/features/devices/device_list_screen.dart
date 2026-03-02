import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets/device_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import 'device_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadDevices();
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
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            onPressed: () => context.read<DeviceProvider>().refresh(),
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [

              // ── Search Bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller:  _searchController,
                  onChanged:   provider.search,
                  decoration:  InputDecoration(
                    hintText:    'Search by name, IP, or location...',
                    prefixIcon:  const Icon(Icons.search, size: 20),
                    filled:      true,
                    fillColor:   AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:   const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:   const BorderSide(color: AppColors.divider),
                    ),
                    suffixIcon: provider.searchQuery.isNotEmpty
                        ? IconButton(
                            icon:      const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              provider.search('');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // ── Status Filter Chips ───────────────────────────────────────
              _buildFilterRow(provider),

              // ── Results Count ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${provider.devices.length} device'
                      '${provider.devices.length != 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (provider.statusFilter != 'all' ||
                        provider.typeFilter != 'all' ||
                        provider.searchQuery.isNotEmpty) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          provider.clearFilters();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        child: const Text('Clear Filters',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Device List ───────────────────────────────────────────────
              Expanded(
                child: provider.devices.isEmpty
                    ? EmptyState(
                        title:   'No Devices Found',
                        message: provider.searchQuery.isNotEmpty
                            ? 'No devices match your search. Try different keywords.'
                            : 'No devices match the selected filters.',
                        icon:    Icons.search_off,
                        actionLabel: 'Clear Filters',
                        onAction: () {
                          _searchController.clear();
                          provider.clearFilters();
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: provider.refresh,
                        child: ListView.builder(
                          padding:     const EdgeInsets.only(top: 8, bottom: 80),
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
                      ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed:       () {},
        backgroundColor: AppColors.primary,
        tooltip:         'Add Device',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Builds the horizontal scrollable row of filter chips.
  Widget _buildFilterRow(DeviceProvider provider) {
    return SizedBox(
      height: 44,
      child: ListView(
        padding:      const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        children: [

          // ── Status filters ─────────────────────────────────────────
          _FilterChip(
            label:    'All',
            selected: provider.statusFilter == 'all',
            onTap:    () => provider.setStatusFilter('all'),
          ),
          _FilterChip(
            label:    'Online',
            selected: provider.statusFilter == 'online',
            onTap:    () => provider.setStatusFilter('online'),
            color:    AppColors.online,
          ),
          _FilterChip(
            label:    'Offline',
            selected: provider.statusFilter == 'offline',
            onTap:    () => provider.setStatusFilter('offline'),
            color:    AppColors.offline,
          ),
          _FilterChip(
            label:    'Degraded',
            selected: provider.statusFilter == 'degraded',
            onTap:    () => provider.setStatusFilter('degraded'),
            color:    AppColors.degraded,
          ),

          // Divider between status and type filters
          const VerticalDivider(width: 20, indent: 8, endIndent: 8),

          // ── Type filters ───────────────────────────────────────────
          _FilterChip(
            label:    'Routers',
            selected: provider.typeFilter == 'router',
            onTap:    () => provider.setTypeFilter('router'),
          ),
          _FilterChip(
            label:    'Switches',
            selected: provider.typeFilter == 'switch',
            onTap:    () => provider.setTypeFilter('switch'),
          ),
          _FilterChip(
            label:    'OLTs',
            selected: provider.typeFilter == 'olt',
            onTap:    () => provider.setTypeFilter('olt'),
          ),
          _FilterChip(
            label:    'Access Points',
            selected: provider.typeFilter == 'access_point',
            onTap:    () => provider.setTypeFilter('access_point'),
          ),
        ],
      ),
    );
  }
}

/// Private filter chip widget used only inside this screen.
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
    final activeColor = color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withOpacity(0.12)
                : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? activeColor : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize:   13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color:      selected ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}