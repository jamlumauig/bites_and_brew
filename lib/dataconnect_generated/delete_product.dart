part of 'generated.dart';

class DeleteProductVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteProductVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteProductData> dataDeserializer = (dynamic json)  => DeleteProductData.fromJson(jsonDecode(json));
  Serializer<DeleteProductVariables> varsSerializer = (DeleteProductVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteProductData, DeleteProductVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteProductData, DeleteProductVariables> ref() {
    DeleteProductVariables vars= DeleteProductVariables(id: id,);
    return _dataConnect.mutation("DeleteProduct", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteProductProductDelete {
  final String id;
  DeleteProductProductDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteProductProductDelete otherTyped = other as DeleteProductProductDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteProductProductDelete({
    required this.id,
  });
}

@immutable
class DeleteProductData {
  final DeleteProductProductDelete? product_delete;
  DeleteProductData.fromJson(dynamic json):
  
  product_delete = json['product_delete'] == null ? null : DeleteProductProductDelete.fromJson(json['product_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteProductData otherTyped = other as DeleteProductData;
    return product_delete == otherTyped.product_delete;
    
  }
  @override
  int get hashCode => product_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (product_delete != null) {
      json['product_delete'] = product_delete!.toJson();
    }
    return json;
  }

  DeleteProductData({
    this.product_delete,
  });
}

@immutable
class DeleteProductVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteProductVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteProductVariables otherTyped = other as DeleteProductVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteProductVariables({
    required this.id,
  });
}

