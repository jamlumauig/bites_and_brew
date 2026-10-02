part of 'generated.dart';

class GetProductVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetProductVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetProductData> dataDeserializer = (dynamic json)  => GetProductData.fromJson(jsonDecode(json));
  Serializer<GetProductVariables> varsSerializer = (GetProductVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetProductData, GetProductVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetProductData, GetProductVariables> ref() {
    GetProductVariables vars= GetProductVariables(id: id,);
    return _dataConnect.query("GetProduct", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetProductProduct {
  final String name;
  final double price;
  final String sku;
  GetProductProduct.fromJson(dynamic json):
  
  name = nativeFromJson<String>(json['name']),
  price = nativeFromJson<double>(json['price']),
  sku = nativeFromJson<String>(json['sku']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetProductProduct otherTyped = other as GetProductProduct;
    return name == otherTyped.name && 
    price == otherTyped.price && 
    sku == otherTyped.sku;
    
  }
  @override
  int get hashCode => Object.hashAll([name.hashCode, price.hashCode, sku.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['name'] = nativeToJson<String>(name);
    json['price'] = nativeToJson<double>(price);
    json['sku'] = nativeToJson<String>(sku);
    return json;
  }

  GetProductProduct({
    required this.name,
    required this.price,
    required this.sku,
  });
}

@immutable
class GetProductData {
  final GetProductProduct? product;
  GetProductData.fromJson(dynamic json):
  
  product = json['product'] == null ? null : GetProductProduct.fromJson(json['product']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetProductData otherTyped = other as GetProductData;
    return product == otherTyped.product;
    
  }
  @override
  int get hashCode => product.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (product != null) {
      json['product'] = product!.toJson();
    }
    return json;
  }

  GetProductData({
    this.product,
  });
}

@immutable
class GetProductVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetProductVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetProductVariables otherTyped = other as GetProductVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  GetProductVariables({
    required this.id,
  });
}

