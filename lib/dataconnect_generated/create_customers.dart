part of 'generated.dart';

class CreateCustomersVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  CreateCustomersVariablesBuilder(this._dataConnect, );
  Deserializer<CreateCustomersData> dataDeserializer = (dynamic json)  => CreateCustomersData.fromJson(jsonDecode(json));
  
  Future<OperationResult<CreateCustomersData, void>> execute() {
    return ref().execute();
  }

  MutationRef<CreateCustomersData, void> ref() {
    
    return _dataConnect.mutation("CreateCustomers", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class CreateCustomersCustomerInsert {
  final String id;
  CreateCustomersCustomerInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateCustomersCustomerInsert otherTyped = other as CreateCustomersCustomerInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateCustomersCustomerInsert({
    required this.id,
  });
}

@immutable
class CreateCustomersData {
  final CreateCustomersCustomerInsert customer_insert;
  CreateCustomersData.fromJson(dynamic json):
  
  customer_insert = CreateCustomersCustomerInsert.fromJson(json['customer_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateCustomersData otherTyped = other as CreateCustomersData;
    return customer_insert == otherTyped.customer_insert;
    
  }
  @override
  int get hashCode => customer_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['customer_insert'] = customer_insert.toJson();
    return json;
  }

  CreateCustomersData({
    required this.customer_insert,
  });
}

