class SchoolDirectoryEntry {
  const SchoolDirectoryEntry({
    required this.id,
    required this.officialName,
    required this.displayName,
    required this.city,
    required this.state,
    required this.schoolType,
    this.district,
  });

  final String id;
  final String officialName;
  final String displayName;
  final String city;
  final String state;
  final String schoolType;
  final String? district;

  factory SchoolDirectoryEntry.fromJson(Map<String, dynamic> json) =>
      SchoolDirectoryEntry(
        id: json['id'] as String,
        officialName: json['official_name'] as String,
        displayName: json['display_name'] as String,
        district: json['district'] as String?,
        city: json['city'] as String,
        state: json['state'] as String,
        schoolType: json['school_type'] as String,
      );

  String get typeLabel => switch (schoolType) {
    'high_school' => 'High school',
    'middle_school' => 'Middle school',
    'k8' => 'K–8 school',
    _ => 'School',
  };
}
