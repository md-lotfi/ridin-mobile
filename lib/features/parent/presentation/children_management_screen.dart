import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import 'link_child_flow_screen.dart';

class ChildrenManagementScreen extends StatefulWidget {
  const ChildrenManagementScreen({super.key});

  @override
  State<ChildrenManagementScreen> createState() => _ChildrenManagementScreenState();
}

class _ChildrenManagementScreenState extends State<ChildrenManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _children = [];
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final response = await apiClient.dio.get('/parent/children');
      final requests = await apiClient.dio.get('/parent/requests');
      if (!mounted) return;
      _requests = (requests.data['requests'] as List? ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final raw = response.data['children'] as List<dynamic>? ?? [];
      setState(() {
        _children = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.fromError(e).message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Élèves'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LinkChildFlowScreen()),
          );
          _loadChildren();
        },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_link),
        label: const Text('Associer un Élève', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadChildren, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : _children.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.child_care_outlined, size: 72, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _requests.any((request) => request['status'] == 'pending') ? 'Demande en attente de validation par l’école' : _requests.isNotEmpty ? 'Accès non approuvé. Contactez l’école.' : 'Aucun élève associé',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Associez le code remis par l\'école pour activer le suivi en temps réel du bus scolaire.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LinkChildFlowScreen()),
                                );
                                _loadChildren();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Associer un élève maintenant'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChildren,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _children.length,
                        itemBuilder: (context, index) {
                          final child = _children[index];
                          final stop = child['stop'] as Map<String, dynamic>?;
                          final vehicle = child['vehicle'] as Map<String, dynamic>?;
                          final driver = child['driver'] as Map<String, dynamic>?;
                          final status = stop?['status'] as String? ?? 'unlinked';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          child['first_name']?[0] ?? 'E',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              child['full_name'] ?? '${child['first_name']} ${child['last_name']}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text(
                                              '${child['school_grade'] ?? ''} • ${child['school_name'] ?? 'École'}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (child['link_code'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            child['link_code'],
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 24),

                                  // Assigned Bus
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_bus_outlined, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          vehicle != null
                                              ? '${vehicle['name']} (${vehicle['plate_number']})'
                                              : 'Bus non assigné',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (driver != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Chauffeur : ${driver['name'] ?? '-'}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 12),

                                  // Stop Status Pill
                                  if (status == 'pending_approval') ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800, size: 18),
                                              const SizedBox(width: 6),
                                              Text(
                                                'En attente de validation par l\'école',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.amber.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Repère : ${stop?['address_label'] ?? ''}',
                                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'L\'administration examine l\'accessibilité pour le minibus. Vous serez notifié dès validation.',
                                            style: TextStyle(fontSize: 10, color: Colors.amber.shade800),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (status == 'approved') ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Arrêt Validé',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.green.shade900,
                                                  ),
                                                ),
                                                Text(
                                                  stop?['address_label'] ?? '',
                                                  style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (status == 'rejected') ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.cancel_rounded, color: Colors.red.shade700, size: 18),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Arrêt Refusé par l\'école',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade900),
                                              ),
                                            ],
                                          ),
                                          if (stop?['rejection_reason'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Motif : ${stop!['rejection_reason']}',
                                                style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
