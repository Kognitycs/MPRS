class IcdModel {
  final String id;
  final String name;

  IcdModel({required this.id, required this.name});

  factory IcdModel.fromJson(Map<String, dynamic> json) {
    return IcdModel(
      id: json['Id'],
      name: json['Name'],
    );
  }
}