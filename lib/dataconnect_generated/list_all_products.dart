part of 'generated.dart';

class ListAllProductsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListAllProductsVariablesBuilder(this._dataConnect, );
  Deserializer<ListAllProductsData> dataDeserializer = (dynamic json)  => ListAllProductsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListAllProductsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListAllProductsData, void> ref() {
    
    return _dataConnect.query("ListAllProducts", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListAllProductsProducts {
  final String name;
  final double price;
  final String sku;
  ListAllProductsProducts.fromJson(dynamic json):
  
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

    final ListAllProductsProducts otherTyped = other as ListAllProductsProducts;
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

  ListAllProductsProducts({
    required this.name,
    required this.price,
    required this.sku,
  });
}

@immutable
class ListAllProductsData {
  final List<ListAllProductsProducts> products;
  ListAllProductsData.fromJson(dynamic json):
  
  products = (json['products'] as List<dynamic>)
        .map((e) => ListAllProductsProducts.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListAllProductsData otherTyped = other as ListAllProductsData;
    return products == otherTyped.products;
    
  }
  @override
  int get hashCode => products.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['products'] = products.map((e) => e.toJson()).toList();
    return json;
  }

  ListAllProductsData({
    required this.products,
  });
}

