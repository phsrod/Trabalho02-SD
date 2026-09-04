class DetectioResult {
    final List<String> objects;

    const DetectionResult({required this.objects,})

    factory DetectionResult.fromJson(Map<String, dynamic> json){
        List<String> objectsList = [];
        if(json['objects'] != null) {
            objectsList = List<String>.from(json['objects']);
        }
        return DetectionResult(objects: objectsList,);
    }
}