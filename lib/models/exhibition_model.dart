import 'package:cloud_firestore/cloud_firestore.dart';

enum ExhibitionStatus { upcoming, ongoing, completed }

// Derive status purely from dates — never store manually
ExhibitionStatus computeStatus(DateTime startDate, DateTime endDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end   = DateTime(endDate.year, endDate.month, endDate.day);

  if (today.isBefore(start))                return ExhibitionStatus.upcoming;
  if (today.isAfter(end))                   return ExhibitionStatus.completed;
  return ExhibitionStatus.ongoing; // today >= start && today <= end
}

class Exhibition {
  final String id;
  final String name;
  final String description;
  final String venue;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final ExhibitionStatus status;
  final bool isPublished;
  final String organizerId;
  final String? floorPlanUrl;
  final DateTime createdAt;
  final List<Map<String, dynamic>>? boothTypes; // ADDED: for custom booth types & prices

  Exhibition({
    required this.id,
    required this.name,
    required this.description,
    required this.venue,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.isPublished,
    required this.organizerId,
    this.floorPlanUrl,
    required this.createdAt,
    this.boothTypes, // ADDED
  });

  // Always derived from dates — never trust the stored 'status' field
  ExhibitionStatus get computedStatus => computeStatus(startDate, endDate);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'venue': venue,
      'imageUrl': imageUrl,
      'startDate': startDate,
      'endDate': endDate,
      'status': computedStatus.name, // always write computed value
      'isPublished': isPublished,
      'organizerId': organizerId,
      'floorPlanUrl': floorPlanUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'boothTypes': boothTypes,
    };
  }

  factory Exhibition.fromMap(String id, Map<String, dynamic> map) {
    final start = (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final end   = (map['endDate']   as Timestamp?)?.toDate() ?? DateTime.now();
    return Exhibition(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      venue: map['venue'] ?? '',
      imageUrl: map['imageUrl'],
      startDate: start,
      endDate: end,
      status: computeStatus(start, end), // always compute, ignore stored value
      isPublished: map['isPublished'] ?? false,
      organizerId: map['organizerId'] ?? '',
      floorPlanUrl: map['floorPlanUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      boothTypes: map['boothTypes'] != null
          ? List<Map<String, dynamic>>.from(map['boothTypes'])
          : null,
    );
  }
}