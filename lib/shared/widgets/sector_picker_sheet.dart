import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/meter_model.dart';

class SectorPickerSheet extends StatefulWidget {
  final List<SectorModel> sectors;
  final SectorModel? selectedSector;
  final Function(SectorModel?) onSelect;

  const SectorPickerSheet({
    super.key,
    required this.sectors,
    this.selectedSector,
    required this.onSelect,
  });

  @override
  State<SectorPickerSheet> createState() => _SectorPickerSheetState();
}

class _SectorPickerSheetState extends State<SectorPickerSheet> {
  final _searchController = TextEditingController();
  List<SectorModel> _filteredSectors = [];

  @override
  void initState() {
    super.initState();
    _filteredSectors = widget.sectors;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {
      if (q.isEmpty) {
        _filteredSectors = widget.sectors;
      } else {
        final query = q.toLowerCase();
        _filteredSectors = widget.sectors
            .where((s) => s.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar Sector',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar sector...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _filteredSectors.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final sector = _filteredSectors[index];
                final isSelected = widget.selectedSector?.name == sector.name;
                
                return ListTile(
                  onTap: () {
                    widget.onSelect(sector);
                    Navigator.pop(context);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                    ),
                  ),
                  title: Text(
                    sector.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                    ),
                  ),
                  trailing: isSelected 
                    ? Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
                );
              },
            ),
          ),
          
          if (widget.selectedSector != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    widget.onSelect(null);
                    Navigator.pop(context);
                  },
                  child: const Text('Limpiar filtro', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
