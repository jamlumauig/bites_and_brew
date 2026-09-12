part of 'generated.dart';

class CreateProductsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  CreateProductsVariablesBuilder(this._dataConnect, );
  Deserializer<CreateProductsData> dataDeserializer = (dynamic json)  => CreateProductsData.fromJson(jsonDecode(json));
  
  Future<OperationResult<CreateProductsData, void>> execute() {
    return ref().execute();
  }

  MutationRef<CreateProductsData, void> ref() {
    
    return _dataConnect.mutation("CreateProducts", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class CreateProductsProductInsertMany {
  final String id;
  CreateProductsProductInsertMany.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateProductsProductInsertMany otherTyped = other as CreateProductsProductInsertMany;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateProductsProductInsertMany({
    required this.id,
  });
}

@immutable
class CreateProductsData {
  final List<CreateProductsProductInsertMany> product_insertMany;
  CreateProductsData.fromJson(dynamic json):
  
  product_insertMany = (json['product_insertMany'] as List<dynamic>)
        .map((e) => CreateProductsProductInsertMany.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateProductsData otherTyped = other as CreateProductsData;
    return product_insertMany == otherTyped.product_insertMany;
    
  }
  @override
  int get hashCode => product_insertMany.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['product_insertMany'] = product_insertMany.map((e) => e.toJson()).toList();
    return json;
  }

  CreateProductsData({
    required this.product_insertMany,
  });
}

