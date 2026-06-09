import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoothManagementScreen extends StatefulWidget {
  final String exhibitionId;
  final String exhibitionName;

  const BoothManagementScreen({
    super.key,
    required this.exhibitionId,
    required this.exhibitionName,
  });

  @override
  State<BoothManagementScreen> createState() => _BoothManagementScreenState();
}

class _BoothManagementScreenState extends State<BoothManagementScreen> {
  final TextEditingController _boothNumberController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedType = 'Standard';
  String _selectedStatus = 'available';

  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingBoothId;

  final List<String> _boothTypes = ['Standard', 'Premium', 'VIP'];
  final List<String> _boothStatuses = ['available', 'booked'];

  Future<void> _saveBooth() async {
    if (_boothNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter booth number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final boothData = {
      'exhibitionId': widget.exhibitionId,
      'boothNumber': _boothNumberController.text.trim().toUpperCase(),
      'type': _selectedType,
      'price': double.parse(_priceController.text),
      'status': _selectedStatus,
    };

    try {
      if (_isEditing && _editingBoothId != null) {
        await FirebaseFirestore.instance
            .collection('booths')
            .doc(_editingBoothId)
            .update(boothData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booth updated successfully!')),
        );
      } else {
        await FirebaseFirestore.instance.collection('booths').add(boothData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booth added successfully!')),
        );
      }
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editBooth(String id, Map<String, dynamic> data) {
    setState(() {
      _isEditing = true;
      _editingBoothId = id;
      _boothNumberController.text = data['boothNumber'] ?? '';
      _priceController.text = (data['price'] ?? 0).toString();
      _selectedType = data['type'] ?? 'Standard';
      _selectedStatus = data['status'] ?? 'available';
    });
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _editingBoothId = null;
      _boothNumberController.clear();
      _priceController.clear();
      _selectedType = 'Standard';
      _selectedStatus = 'available';
    });
  }

  Future<void> _deleteBooth(String id, String boothNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booth'),
        content: Text('Are you sure you want to delete booth $boothNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('booths').doc(id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booth $boothNumber deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateSampleBooths() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Sample Booths'),
        content: const Text(
          'This will generate 20 sample booths (A-01 to A-10, B-01 to B-10). '
              'Existing booths will remain. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final booths = [
      // A Row (Premium)
      'A-01', 'A-02', 'A-03', 'A-04', 'A-05',
      'A-06', 'A-07', 'A-08', 'A-09', 'A-10',
      // B Row (Standard)
      'B-01', 'B-02', 'B-03', 'B-04', 'B-05',
      'B-06', 'B-07', 'B-08', 'B-09', 'B-10',
    ];

    try {
      for (int i = 0; i < booths.length; i++) {
        final isPremium = booths[i].startsWith('A');
        await FirebaseFirestore.instance.collection('booths').add({
          'exhibitionId': widget.exhibitionId,
          'boothNumber': booths[i],
          'type': isPremium ? 'Premium' : 'Standard',
          'price': isPremium ? 1500 : 800,
          'status': 'available',
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${booths.length} sample booths!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Booths - ${widget.exhibitionName}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _clearForm,
            tooltip: 'Add New Booth',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _generateSampleBooths,
            tooltip: 'Generate Sample Booths',
          ),
        ],
      ),
      body: Column(
        children: [
          // Add/Edit Form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _boothNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Booth Number',
                          hintText: 'e.g., A-01',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (RM)',
                          hintText: 'e.g., 1500',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Booth Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _boothTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedType = value!);
                          if (_selectedType == 'Premium') {
                            _priceController.text = '1500';
                          } else if (_selectedType == 'VIP') {
                            _priceController.text = '3000';
                          } else {
                            _priceController.text = '800';
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: _boothStatuses.map((status) {
                          return DropdownMenuItem(value: status, child: Text(status));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedStatus = value!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveBooth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEditing ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: Text(_isEditing ? 'UPDATE' : 'ADD'),
                    ),
                  ],
                ),
                if (_isEditing)
                  TextButton(
                    onPressed: _clearForm,
                    child: const Text('Cancel Edit'),
                  ),
              ],
            ),
          ),

          const Divider(),

          // Booths List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('booths')
                  .where('exhibitionId', isEqualTo: widget.exhibitionId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final booths = snapshot.data?.docs ?? [];

                if (booths.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No booths found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _generateSampleBooths,
                          child: const Text('Generate Sample Booths'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: booths.length,
                  itemBuilder: (context, index) {
                    final doc = booths[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final boothNumber = data['boothNumber'] ?? 'Unknown';
                    final type = data['type'] ?? 'Standard';
                    final price = (data['price'] as num?)?.toDouble() ?? 0;
                    final status = data['status'] ?? 'available';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: status == 'available'
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          child: Text(
                            boothNumber.split('-').last,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: status == 'available' ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        title: Text(boothNumber),
                        subtitle: Text('$type • RM${price.toInt()}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'available'
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: status == 'available' ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editBooth(doc.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteBooth(doc.id, boothNumber),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}