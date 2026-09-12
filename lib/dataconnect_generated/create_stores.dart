part of 'generated.dart';

class CreateStoresVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  CreateStoresVariablesBuilder(this._dataConnect, );
  Deserializer<CreateStoresData> dataDeserializer = (dynamic json)  => CreateStoresData.fromJson(jsonDecode(json));
  
  Future<OperationResult<CreateStoresData, void>> execute() {
    return ref().execute();
  }

  MutationRef<CreateStoresData, void> ref() {
    
    return _dataConnect.mutation("CreateStores", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class CreateStoresStoreInsert {
  final String id;
  CreateStoresStoreInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateStoresStoreInsert otherTyped = other as CreateStoresStoreInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateStoresStoreInsert({
    required this.id,
  });
}

@immutable
class CreateStoresData {
  final CreateStoresStoreInsert store_insert;
  CreateStoresData.fromJson(dynamic json):
  
  store_insert = CreateStoresStoreInsert.fromJson(json['store_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateStoresData otherTyped = other as CreateStoresData;
    return store_insert == otherTyped.store_insert;
    
  }
  @override
  int get hashCode => store_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['store_insert'] = store_insert.toJson();
    return json;
  }

  CreateStoresData({
    required this.store_insert,
  });
}

