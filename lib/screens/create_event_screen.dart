import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Event details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();

  // Dates
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isPublished = true;
  bool _isLoading = false;

  // Booth Types dengan color
  List<Map<String, dynamic>> _boothTypes = [
    {'type': 'Premium', 'price': 1500, 'color': Colors.amber},
    {'type': 'Standard', 'price': 800, 'color': Colors.blue},
  ];

  final List<Color> _availableColors = [
    Colors.amber, Colors.blue, Colors.green, Colors.red,
    Colors.purple, Colors.orange, Colors.pink, Colors.teal
  ];

  void _addBoothType() {
    setState(() {
      _boothTypes.add({
        'type': 'New Type',
        'price': 0,
        'color': Colors.grey
      });
    });
  }

  void _removeBoothType(int index) {
    setState(() {
      _boothTypes.removeAt(index);
    });
  }

  void _updateBoothType(int index, String field, dynamic value) {
    setState(() {
      _boothTypes[index][field] = value;
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select dates'), backgroundColor: Colors.orange),
      );
      return;
    }

    final validBoothTypes = _boothTypes.where((b) =>
    b['type'].toString().isNotEmpty && (b['price'] as num) > 0
    ).toList();

    if (validBoothTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one booth type'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Compute status from dates — never manual
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final end   = DateTime(_endDate!.year,   _endDate!.month,   _endDate!.day);
      final computedStatus = today.isBefore(start)
          ? 'upcoming'
          : today.isAfter(end)
          ? 'completed'
          : 'ongoing';

      await FirebaseFirestore.instance.collection('exhibitions').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'venue': _venueController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'status': computedStatus,
        'isPublished': _isPublished,
        'organizerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'boothTypes': validBoothTypes.map((b) => {
          'type': b['type'],
          'price': b['price'],
          'color': b['color'].value,
        }).toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Event'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Event Name *',
                  hintText: 'e.g., Kuala Lumpur Trade Show 2026',
                  prefixIcon: const Icon(Icons.event),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe the event...',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 4,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Venue
              TextFormField(
                controller: _venueController,
                decoration: InputDecoration(
                  labelText: 'Venue *',
                  hintText: 'e.g., Kuala Lumpur Convention Centre',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Start Date
              InkWell(
                onTap: () => _selectStartDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Start Date *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _startDate == null
                        ? 'Select date'
                        : DateFormat('dd MMM yyyy').format(_startDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Date
              InkWell(
                onTap: () => _selectEndDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _endDate == null
                        ? 'Select date'
                        : DateFormat('dd MMM yyyy').format(_endDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Auto status info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Status is set automatically based on the dates you choose. '
                        'Upcoming → Ongoing → Completed.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  )),
                ]),
              ),
              const SizedBox(height: 16),

              // Published Switch
              SwitchListTile(
                title: const Text('Publish Immediately'),
                subtitle: const Text('Make event visible to guests and exhibitors'),
                value: _isPublished,
                onChanged: (value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
                activeColor: Colors.green,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),

              // Booth Types & Prices Section - CANTIK DENGAN WARNA
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Booth Types & Prices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addBoothType,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Type'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _boothTypes.length,
                      itemBuilder: (context, index) {
                        final boothType = _boothTypes[index];
                        final Color typeColor = boothType['color'] is Color
                            ? boothType['color']
                            : Color(boothType['color'] ?? Colors.blue.value);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Color indicator
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.event_seat, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              // Type and price
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      initialValue: boothType['type'],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        labelText: 'Booth Type',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) => _updateBoothType(index, 'type', value),
                                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: boothType['price'].toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Price (RM)',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final price = double.tryParse(value) ?? 0;
                                        _updateBoothType(index, 'price', price);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // Color picker
                              PopupMenuButton<Color>(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.palette, size: 20, color: typeColor),
                                ),
                                onSelected: (color) => _updateBoothType(index, 'color', color),
                                itemBuilder: (context) => _availableColors.map((color) {
                                  return PopupMenuItem(
                                    value: color,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_getColorName(color)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(width: 4),
                              // Delete button
                              if (_boothTypes.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeBoothType(index),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Create Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'CREATE EVENT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getColorName(Color color) {
    if (color == Colors.amber) return 'Amber';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.green) return 'Green';
    if (color == Colors.red) return 'Red';
    if (color == Colors.purple) return 'Purple';
    if (color == Colors.orange) return 'Orange';
    if (color == Colors.pink) return 'Pink';
    if (color == Colors.teal) return 'Teal';
    return 'Custom';
  }
}