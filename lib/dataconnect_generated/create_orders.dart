part of 'generated.dart';

class CreateOrdersVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  CreateOrdersVariablesBuilder(this._dataConnect, );
  Deserializer<CreateOrdersData> dataDeserializer = (dynamic json)  => CreateOrdersData.fromJson(jsonDecode(json));
  
  Future<OperationResult<CreateOrdersData, void>> execute() {
    return ref().execute();
  }

  MutationRef<CreateOrdersData, void> ref() {
    
    return _dataConnect.mutation("CreateOrders", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class CreateOrdersOrderInsert {
  final String id;
  CreateOrdersOrderInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateOrdersOrderInsert otherTyped = other as CreateOrdersOrderInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateOrdersOrderInsert({
    required this.id,
  });
}

@immutable
class CreateOrdersData {
  final CreateOrdersOrderInsert order_insert;
  CreateOrdersData.fromJson(dynamic json):
  
  order_insert = CreateOrdersOrderInsert.fromJson(json['order_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateOrdersData otherTyped = other as CreateOrdersData;
    return order_insert == otherTyped.order_insert;
    
  }
  @override
  int get hashCode => order_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['order_insert'] = order_insert.toJson();
    return json;
  }

  CreateOrdersData({
    required this.order_insert,
  });
}

