import 'package:flutter/material.dart';

import '../services/media_service.dart';
import 'home_screen.dart';

class DateSelectionScreen extends StatefulWidget {
  const DateSelectionScreen({super.key});

  @override
  State<DateSelectionScreen> createState() => _DateSelectionScreenState();
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  final MediaService _mediaService = MediaService();
  bool _isLoading = true;
  List<DateGroup> _groups = [];
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final hasPermission = await _mediaService.requestPermission();
    setState(() => _hasPermission = hasPermission);

    if (hasPermission) {
      final groups = await _mediaService.getAvailableMonths();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _onGroupSelected(DateGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(selectedDate: group.date, album: group.album),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      appBar: AppBar(
        title: const Text(
          'Selecionar Período',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Acesso à galeria necessário',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroups,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
              child: const Text('Permitir Acesso', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return const Center(
        child: Text('Nenhuma foto encontrada', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Card(
          color: const Color(0xFF1a1a2e),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              group.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${group.count} arquivo(s)',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () => _onGroupSelected(group),
          ),
        );
      },
    );
  }
}
