import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  static const Color fluorescentGreen = Color(0xFF99FF00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Guía de Usuario'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroSection(),
          const SizedBox(height: 24),
          _buildGuideSection(
            context,
            icon: Icons.cloud_download_rounded,
            title: 'Descarga de Datos',
            color: const Color(0xFF6366F1),
            content: 'Para comenzar tu jornada, presiona el botón de descarga en el inicio.',
            visualization: _mockPrimaryButton(
              icon: Icons.cloud_download_rounded,
              label: 'Obtener periodo de trabajo',
              highlight: true,
            ),
          ),
          _buildGuideSection(
            context,
            icon: Icons.edit_note_rounded,
            title: 'Registro de Lecturas',
            color: const Color(0xFF0EA5E9),
            content: 'Ingresa la lectura actual. El sistema marcará con verde si es válida.',
            visualization: _mockInput(
              label: 'Lectura Actual',
              value: '1240',
              highlight: true,
            ),
          ),
          _buildGuideSection(
            context,
            icon: Icons.map_rounded,
            title: 'Mapa y Sectores',
            color: const Color(0xFF10B981),
            content: 'Filtra por sector para ver solo los medidores de una zona.',
            visualization: _mockSectorPicker(),
          ),
          _buildGuideSection(
            context,
            icon: Icons.sync_rounded,
            title: 'Sincronización Automática',
            color: const Color(0xFFF59E0B),
            content: 'Activa el envío automático en tu perfil para sincronizar en tiempo real.',
            visualization: _mockSwitch(
              label: 'Envío automático',
              value: true,
              highlight: true,
            ),
          ),
          _buildGuideSection(
            context,
            icon: Icons.bolt_rounded,
            title: 'Envío por Bloques',
            color: const Color(0xFF8B5CF6),
            content: 'Sincroniza todas tus lecturas de una vez presionando el botón de envío.',
            visualization: _mockProgressRing(0.65),
          ),
          _buildGuideSection(
            context,
            icon: Icons.file_present_rounded,
            title: 'Exportar CSV',
            color: const Color(0xFF3B82F6),
            content: 'Genera y comparte el reporte de tu trabajo en formato CSV.',
            visualization: _mockActionTile(
              icon: Icons.file_download_outlined,
              label: 'Exportar a CSV',
              highlight: true,
            ),
          ),
          _buildGuideSection(
            context,
            icon: Icons.verified_rounded,
            title: 'Finalizar Trabajo',
            color: const Color(0xFF22C55E),
            content: 'Al terminar, presiona este botón para cerrar tu periodo oficialmente.',
            visualization: _mockPrimaryButton(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Finalizar trabajo',
              color: const Color(0xFF22C55E),
              highlight: true,
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'Aurora v1.0.0',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_stories_rounded, color: Colors.white, size: 40),
          SizedBox(height: 16),
          Text(
            'Bienvenido a tu guía',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aprende a dominar todas las funciones de Aurora visualmente.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    required Widget visualization,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          iconColor: color,
          collapsedIconColor: const Color(0xFF94A3B8),
          backgroundColor: Colors.white,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedAlignment: Alignment.topLeft,
          children: [
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            visualization,
          ],
        ),
      ),
    );
  }

  // ─── Visual Mockup Widgets ────────────────────────────────

  Widget _mockPrimaryButton({
    required IconData icon,
    required String label,
    Color? color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: highlight
          ? BoxDecoration(
              border: Border.all(color: fluorescentGreen, width: 3),
              borderRadius: BorderRadius.circular(18),
            )
          : null,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: color ?? AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mockInput({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: highlight
              ? BoxDecoration(
                  border: Border.all(color: fluorescentGreen, width: 3),
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const Spacer(),
                const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mockSectorPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.map_outlined, color: Color(0xFF64748B), size: 18),
          SizedBox(width: 8),
          Text('Sector: Central', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _mockSwitch({
    required String label,
    required bool value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: highlight
          ? BoxDecoration(
              border: Border.all(color: fluorescentGreen, width: 3),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sync_rounded, color: Color(0xFFF59E0B), size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Switch.adaptive(value: value, onChanged: (_) {}, activeColor: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _mockProgressRing(double progress) {
    return Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mockActionTile({
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: highlight
          ? BoxDecoration(
              border: Border.all(color: fluorescentGreen, width: 3),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
