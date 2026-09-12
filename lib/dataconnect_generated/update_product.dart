part of 'generated.dart';

class UpdateProductVariablesBuilder {
  String id;
  Optional<double> _price = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateProductVariablesBuilder price(double? t) {
   _price.value = t;
   return this;
  }

  UpdateProductVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateProductData> dataDeserializer = (dynamic json)  => UpdateProductData.fromJson(jsonDecode(json));
  Serializer<UpdateProductVariables> varsSerializer = (UpdateProductVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateProductData, UpdateProductVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateProductData, UpdateProductVariables> ref() {
    UpdateProductVariables vars= UpdateProductVariables(id: id,price: _price,);
    return _dataConnect.mutation("UpdateProduct", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateProductProductUpdate {
  final String id;
  UpdateProductProductUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateProductProductUpdate otherTyped = other as UpdateProductProductUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateProductProductUpdate({
    required this.id,
  });
}

@immutable
class UpdateProductData {
  final UpdateProductProductUpdate? product_update;
  UpdateProductData.fromJson(dynamic json):
  
  product_update = json['product_update'] == null ? null : UpdateProductProductUpdate.fromJson(json['product_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateProductData otherTyped = other as UpdateProductData;
    return product_update == otherTyped.product_update;
    
  }
  @override
  int get hashCode => product_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (product_update != null) {
      json['product_update'] = product_update!.toJson();
    }
    return json;
  }

  UpdateProductData({
    this.product_update,
  });
}

@immutable
class UpdateProductVariables {
  final String id;
  late final Optional<double>price;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateProductVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    price = Optional.optional(nativeFromJson, nativeToJson);
    price.value = json['price'] == null ? null : nativeFromJson<double>(json['price']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateProductVariables otherTyped = other as UpdateProductVariables;
    return id == otherTyped.id && 
    price == otherTyped.price;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, price.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(price.state == OptionalState.set) {
      json['price'] = price.toJson();
    }
    return json;
  }

  UpdateProductVariables({
    required this.id,
    required this.price,
  });
}

