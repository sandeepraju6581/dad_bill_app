// orders_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Order Model ───────────────────────────────────────────────────────────────

class OrderImage {
  String path;
  String width;
  String height;

  OrderImage({required this.path, this.width = '', this.height = ''});

  Map<String, dynamic> toJson() => {
        'path': path,
        'width': width,
        'height': height,
      };

  factory OrderImage.fromJson(Map<String, dynamic> json) => OrderImage(
        path: json['path'] ?? '',
        width: json['width'] ?? '',
        height: json['height'] ?? '',
      );
}

class Order {
  final String id;
  String customerName;
  String width;
  String height;
  List<OrderImage> images;
  String status; // 'working' | 'completed' | 'delivery'
  String createdAt;
  String description;

  Order({
    required this.id,
    required this.customerName,
    required this.width,
    required this.height,
    required this.images,
    required this.status,
    required this.createdAt,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerName': customerName,
        'width': width,
        'height': height,
        'images': images.map((e) => e.toJson()).toList(),
        'status': status,
        'createdAt': createdAt,
        'description': description,
      };

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderImage> parsedImages = [];
    
    if (json['images'] != null) {
      final list = json['images'] as List;
      parsedImages = list.map((e) => OrderImage.fromJson(e)).toList();
    } else {
      // Backward compat for old 'imagePaths' array or 'imagePath' string
      List<String> paths = [];
      if (json['imagePaths'] != null) {
        paths = List<String>.from(json['imagePaths']);
      } else if (json['imagePath'] != null &&
          (json['imagePath'] as String).isNotEmpty) {
        paths = [json['imagePath'] as String];
      }
      // Assign the order's top-level width/height to these legacy images
      parsedImages = paths.map((p) => OrderImage(
        path: p, 
        width: json['width'] ?? '', 
        height: json['height'] ?? ''
      )).toList();
    }

    return Order(
      id: json['id'],
      customerName: json['customerName'],
      width: json['width'] ?? '',
      height: json['height'] ?? '',
      images: parsedImages,
      status: json['status'] ?? 'working',
      createdAt: json['createdAt'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

// ─── Status Config ─────────────────────────────────────────────────────────────

class _StatusConfig {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _StatusConfig({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.icon,
  });
}

final Map<String, _StatusConfig> _statusConfig = {
  'working': _StatusConfig(
    label: 'Working',
    color: const Color(0xFFE65100),
    bgColor: const Color(0xFFFFF3E0),
    icon: Icons.construction_rounded,
  ),
  'completed': _StatusConfig(
    label: 'Completed',
    color: const Color(0xFF1B5E20),
    bgColor: const Color(0xFFE8F5E9),
    icon: Icons.check_circle_rounded,
  ),
  'delivery': _StatusConfig(
    label: 'Delivery',
    color: const Color(0xFF1A237E),
    bgColor: const Color(0xFFE8EAF6),
    icon: Icons.local_shipping_rounded,
  ),
};

// ─── Orders Page ───────────────────────────────────────────────────────────────

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  List<Order> _orders = [];
  late TabController _filterTab;
  final _filters = ['All', 'Working', 'Completed', 'Delivery'];
  bool _loading = true;
  bool _showNamesOnly = false;

  @override
  void initState() {
    super.initState();
    _filterTab = TabController(length: _filters.length, vsync: this);
    _filterTab.addListener(() => setState(() {}));
    _loadOrders();
  }

  @override
  void dispose() {
    _filterTab.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('orders_list');
    if (raw != null) {
      final List decoded = json.decode(raw);
      setState(() {
        _orders = decoded.map((e) => Order.fromJson(e)).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'orders_list', json.encode(_orders.map((e) => e.toJson()).toList()));
    setState(() {});
  }

  List<Order> get _filtered {
    final tab = _filters[_filterTab.index];
    if (tab == 'All') return _orders;
    return _orders.where((o) => o.status == tab.toLowerCase()).toList();
  }

  void _openOrderForm({Order? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderFormSheet(
        existing: editing,
        onSave: (order) async {
          setState(() {
            if (editing != null) {
              final idx = _orders.indexWhere((o) => o.id == editing.id);
              if (idx != -1) _orders[idx] = order;
            } else {
              _orders.insert(0, order);
            }
          });
          await _saveOrders();
        },
      ),
    );
  }

  Future<void> _deleteOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Order?'),
        content: Text(
            'Remove order for "${order.customerName}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _orders.removeWhere((o) => o.id == order.id));
      await _saveOrders();
    }
  }

  Future<void> _changeStatus(Order order, String newStatus) async {
    setState(() => order.status = newStatus);
    await _saveOrders();
  }

  void _openGallery(List<OrderImage> images, int startIndex) {
    if (images.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => _ImageGalleryDialog(images: images, initialIndex: startIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // ── Main content ──────────────────────────────────────────────
        Container(
          color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
          child: Column(
            children: [
              // Filter Tabs
              Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: TabBar(
                  controller: _filterTab,
                  labelColor: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                  tabs: _filters
                      .map((f) => Tab(
                            text: f,
                            icon: f == 'All'
                                ? const Icon(Icons.list_alt_rounded, size: 18)
                                : Icon(_statusConfig[f.toLowerCase()]!.icon,
                                    size: 18),
                          ))
                      .toList(),
                ),
              ),
              // Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEF2FF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _statusConfig.entries.map((e) {
                    final count =
                        _orders.where((o) => o.status == e.key).length;
                    return _SummaryChip(
                        label: e.value.label,
                        count: count,
                        color: e.value.color,
                        icon: e.value.icon);
                  }).toList(),
                ),
              ),
              // Compact Toggle Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Orders (${filtered.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Name Only Show',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 24,
                          width: 40,
                          child: Switch(
                            value: _showNamesOnly,
                            onChanged: (val) {
                              setState(() {
                                _showNamesOnly = val;
                              });
                            },
                            activeThumbColor: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Order List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _OrderCard(
                              order: filtered[i],
                              showNamesOnly: _showNamesOnly,
                              onEdit: () => _openOrderForm(editing: filtered[i]),
                              onDelete: () => _deleteOrder(filtered[i]),
                              onOpenGallery: (idx) =>
                                  _openGallery(filtered[i].images, idx),
                              onStatusChange: (s) =>
                                  _changeStatus(filtered[i], s),
                            ),
                          ),
              ),
            ],
          ),
        ),
        // ── FAB (positioned) ─────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openOrderForm(),
            backgroundColor: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
            icon: Icon(Icons.add, color: isDark ? const Color(0xFF121212) : Colors.white),
            label: Text('New Order',
                style: TextStyle(
                    color: isDark ? const Color(0xFF121212) : Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No orders here',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Tap + New Order to add one',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ─── Summary Chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryChip(
      {required this.label,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // In dark mode, we lighten the icon/text color for better contrast
    // against the dark background, since the original colors are quite dark.
    final displayColor = isDark ? color.withValues(alpha: 0.8) : color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: displayColor),
        const SizedBox(width: 4),
        Text('$count ',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: displayColor, fontSize: 14)),
        Text(label, style: TextStyle(color: displayColor, fontSize: 12)),
      ],
    );
  }
}

// ─── Order Card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool showNamesOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onOpenGallery;
  final ValueChanged<String> onStatusChange;

  const _OrderCard({
    required this.order,
    this.showNamesOnly = false,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenGallery,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig[order.status]!;
    final hasImages = order.images.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (showNamesOnly) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: isDark ? 1 : 2,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => _OrderDetailsPopupDialog(order: order),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              order.customerName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: order.status,
                tooltip: 'Change Status',
                onSelected: onStatusChange,
                itemBuilder: (context) => _statusConfig.entries.map((e) {
                  return PopupMenuItem(
                    value: e.key,
                    child: Row(
                      children: [
                        Icon(e.value.icon, color: e.value.color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          e.value.label,
                          style: TextStyle(
                            color: e.value.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? cfg.color.withValues(alpha: 0.2) : cfg.bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cfg.icon, size: 12, color: isDark ? cfg.color.withValues(alpha: 0.8) : cfg.color),
                      const SizedBox(width: 3),
                      Text(cfg.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? cfg.color.withValues(alpha: 0.8) : cfg.color,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: Colors.blue,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: Colors.red,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isDark ? 1 : 3,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: info + status badge ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => _OrderDetailsPopupDialog(order: order),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    order.customerName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 15,
                                  color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.straighten,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text('${order.width}" × ${order.height}"',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey)),
                          if (hasImages) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.photo_library_rounded,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Text('${order.images.length} photo${order.images.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                      if (order.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            order.description,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (order.createdAt.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(order.createdAt,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? cfg.color.withValues(alpha: 0.2) : cfg.bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cfg.icon, size: 12, color: isDark ? cfg.color.withValues(alpha: 0.8) : cfg.color),
                      const SizedBox(width: 3),
                      Text(cfg.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? cfg.color.withValues(alpha: 0.8) : cfg.color,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Multi-image Thumbnail Strip ───────────────────────────────
          if (hasImages)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: order.images.length,
                  itemBuilder: (_, idx) {
                    return GestureDetector(
                      onTap: () => onOpenGallery(idx),
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.file(
                                File(order.images[idx].path),
                                fit: BoxFit.cover,
                                width: 90,
                                height: 90,
                                errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.broken_image,
                                        color: Colors.grey)),
                              ),
                            ),
                            // Index badge
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text('${idx + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            // Dim Info bottom-left
                            if (order.images[idx].width.isNotEmpty && order.images[idx].height.isNotEmpty)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${order.images[idx].width}x${order.images[idx].height}',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            // Zoom icon bottom-right
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.zoom_in_rounded,
                                    color: Colors.white,
                                    size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? const Color(0xFF3C3C3C) : Colors.grey.shade200,
                      style: BorderStyle.solid),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 18, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Text('No photos — tap Edit to add',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Status Buttons + Actions ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2B2B2B) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: _statusConfig.entries.map((e) {
                      final active = order.status == e.key;
                      return GestureDetector(
                        onTap: () => onStatusChange(e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                active ? e.value.color : (isDark ? const Color(0xFF121212) : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: active
                                    ? e.value.color
                                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                        color: e.value.color
                                            .withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(e.value.icon,
                                  size: 13,
                                  color: active
                                      ? Colors.white
                                      : e.value.color),
                              const SizedBox(width: 4),
                              Text(
                                e.value.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: active
                                      ? Colors.white
                                      : e.value.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: Colors.blue,
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20),
                  color: Colors.red,
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order Details Popup Dialog ─────────────────────────────────────────

class _OrderDetailsPopupDialog extends StatefulWidget {
  final Order order;

  const _OrderDetailsPopupDialog({required this.order});

  @override
  State<_OrderDetailsPopupDialog> createState() => _OrderDetailsPopupDialogState();
}

class _OrderDetailsPopupDialogState extends State<_OrderDetailsPopupDialog> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = _statusConfig[order.status]!;
    final hasImages = order.images.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (order.createdAt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Created: ${order.createdAt}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              // Status and size row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Size Badge
                    Row(
                      children: [
                        const Icon(Icons.straighten_rounded, size: 18, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Size: ${order.width}" × ${order.height}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? cfg.color.withValues(alpha: 0.2) : cfg.bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? cfg.color.withValues(alpha: 0.4) : cfg.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cfg.icon, size: 14, color: isDark ? cfg.color.withValues(alpha: 0.8) : cfg.color),
                          const SizedBox(width: 5),
                          Text(
                            cfg.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? cfg.color.withValues(alpha: 0.8) : cfg.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Description if not empty
              if (order.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3C3C3C) : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description / Notes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

              // Image Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasImages) ...[
                      // Main image preview viewport
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => _ImageGalleryDialog(
                              images: order.images,
                              initialIndex: _selectedIndex,
                            ),
                          );
                        },
                        child: Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            ),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Center(
                                  child: Image.file(
                                    File(order.images[_selectedIndex].path),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (_, _, _) => Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Image not found',
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Zoom Indicator Overlay
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              // Image dimension overlay
                              if (order.images[_selectedIndex].width.isNotEmpty &&
                                  order.images[_selectedIndex].height.isNotEmpty)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${order.images[_selectedIndex].width}" × ${order.images[_selectedIndex].height}"',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              // Image index indicator
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_selectedIndex + 1} / ${order.images.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Thumbnail strip if there are multiple images
                      if (order.images.length > 1) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: order.images.length,
                            itemBuilder: (context, index) {
                              final isSelected = index == _selectedIndex;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedIndex = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 60,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? (isDark ? Colors.blue.shade400 : const Color(0xFF1d6f96))
                                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(order.images[index].path),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ] else ...[
                      // No images placeholder
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF3C3C3C) : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 36,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No images attached to this order',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

// ─── Full Screen Image Gallery Dialog ─────────────────────────────────────────

class _ImageGalleryDialog extends StatefulWidget {
  final List<OrderImage> images;
  final int initialIndex;

  const _ImageGalleryDialog(
      {required this.images, required this.initialIndex});

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          // Swipeable image pages
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.file(
                  File(widget.images[i].path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image,
                        size: 80, color: Colors.white30),
                  ),
                ),
              ),
            ),
          ),
          // Top bar: counter + close
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_current + 1} / ${widget.images.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        if (widget.images[_current].width.isNotEmpty || widget.images[_current].height.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.straighten_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.images[_current].width}" × ${widget.images[_current].height}"',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom dot indicators
          if (widget.images.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _current == i
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          // Left/Right arrows
          if (widget.images.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _current > 0
                    ? GestureDetector(
                        onTap: () => _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 28),
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _current < widget.images.length - 1
                    ? GestureDetector(
                        onTap: () => _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.chevron_right,
                              color: Colors.white, size: 28),
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Add/Edit Order Bottom Sheet ───────────────────────────────────────────────

class _OrderFormSheet extends StatefulWidget {
  final Order? existing;
  final Future<void> Function(Order) onSave;

  const _OrderFormSheet({this.existing, required this.onSave});

  @override
  State<_OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<_OrderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _widthCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _descCtrl;
  String _status = 'working';
  List<OrderImage> _images = [];
  bool _saving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    _widthCtrl = TextEditingController(text: e?.width ?? '');
    _heightCtrl = TextEditingController(text: e?.height ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _status = e?.status ?? 'working';
    if (e != null) {
      _images = e.images.map((img) => OrderImage(path: img.path, width: img.width, height: img.height)).toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Pick Images ──────────────────────────────────────────────────────────────

  bool _containsPath(String p) => _images.any((img) => img.path == p);

  Future<void> _pickImages(ImageSource source) async {
    if (source == ImageSource.gallery) {
      // Pick multiple from gallery
      final picked = await _picker.pickMultiImage(
          imageQuality: 85, limit: 10);
      if (picked.isNotEmpty) {
        setState(() {
          for (var f in picked) {
            if (!_containsPath(f.path)) {
              _images.add(OrderImage(path: f.path, width: _widthCtrl.text.trim(), height: _heightCtrl.text.trim()));
            }
          }
        });
      }
    } else {
      // Camera picks one at a time
      final picked = await _picker.pickImage(
          source: source, imageQuality: 85, maxWidth: 1920);
      if (picked != null && !_containsPath(picked.path)) {
        setState(() => _images.add(OrderImage(path: picked.path, width: _widthCtrl.text.trim(), height: _heightCtrl.text.trim())));
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Images From',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImages(ImageSource.camera);
                    },
                  ),
                  _SourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery\n(Multi)',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImages(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final order = Order(
      id: widget.existing?.id ?? 'order_${now.millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      width: _widthCtrl.text.trim(),
      height: _heightCtrl.text.trim(),
      images: List<OrderImage>.from(_images.map((e) => OrderImage(path: e.path, width: e.width.trim(), height: e.height.trim()))),
      status: _status,
      description: _descCtrl.text.trim(),
      createdAt:
          '${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
    );
    await widget.onSave(order);
    if (mounted) Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.93,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
              Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_box_rounded,
                    color: isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Order' : 'New Order',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDec(
                            'Customer Name', Icons.person_rounded),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Please enter customer name'
                                : null,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      // Size Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _widthCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDec('Width"',
                                  Icons.width_normal_rounded),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 8),
                            child: Text('×',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _heightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDec(
                                  'Height"', Icons.height_rounded),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Description
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: _inputDec(
                            'Description / Notes (optional)',
                            Icons.notes_rounded),
                      ),
                      const SizedBox(height: 20),

                      // ── Images Section ─────────────────────────────
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Images',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.shade800 : const Color(0xFF1d6f96),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_images.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: const Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 18),
                            label: const Text('Add Photos'),
                            style: TextButton.styleFrom(
                                foregroundColor:
                                    isDark ? Colors.blue.shade300 : const Color(0xFF1d6f96)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                    // ── Image Grid ─────────────────────────────────
                      if (_images.isEmpty)
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                  width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 40,
                                    color: Colors.grey.shade500),
                                const SizedBox(height: 8),
                                Text('Tap to add images',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13)),
                                Text('Camera or Gallery (multi-select)',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: _images.length + 1,
                          itemBuilder: (_, i) {
                            // Last cell = "Add more" button
                            if (i == _images.length) {
                              return GestureDetector(
                                onTap: _showImageSourceDialog,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                        style: BorderStyle.solid),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_rounded,
                                          size: 28,
                                          color: Colors.grey.shade500),
                                      Text('Add More',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            // Image thumbnail with TextFields
                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade900 : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                          child: Image.file(
                                            File(_images[i].path),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder: (_, _, _) => Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                            ),
                                          ),
                                        ),
                                        // Number badge
                                        Positioned(
                                          top: 4,
                                          left: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('${i + 1}',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        // Delete button
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(i),
                                            child: Container(
                                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                              padding: const EdgeInsets.all(4),
                                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Dimensions inputs
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: _images[i].width,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                              hintText: 'W"',
                                              hintStyle: TextStyle(fontSize: 11),
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (v) => _images[i].width = v,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4),
                                          child: Text('×', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: _images[i].height,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                              hintText: 'H"',
                                              hintStyle: TextStyle(fontSize: 11),
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (v) => _images[i].height = v,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 20),

                      // ── Status Section ─────────────────────────────
                      const Text('Status',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(
                        children: _statusConfig.entries.map((e) {
                          final active = _status == e.key;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _status = e.key),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  color: active
                                      ? e.value.color
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: active
                                          ? e.value.color
                                          : Colors.grey.shade300),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: e.value.color
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset:
                                                const Offset(0, 3),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  children: [
                                    Icon(e.value.icon,
                                        color: active
                                            ? Colors.white
                                            : e.value.color,
                                        size: 22),
                                    const SizedBox(height: 4),
                                    Text(e.value.label,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.bold,
                                            color: active
                                                ? Colors.white
                                                : e.value.color)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
            // Save Button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1d6f96),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.save_rounded,
                          color: Colors.white),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : (isEditing
                            ? 'Update Order'
                            : 'Save Order'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14),
      );
}

// ─── Source Button ─────────────────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
