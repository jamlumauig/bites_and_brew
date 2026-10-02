part of 'generated.dart';

class ListCustomerOrdersVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListCustomerOrdersVariablesBuilder(this._dataConnect, );
  Deserializer<ListCustomerOrdersData> dataDeserializer = (dynamic json)  => ListCustomerOrdersData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListCustomerOrdersData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListCustomerOrdersData, void> ref() {
    
    return _dataConnect.query("ListCustomerOrders", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListCustomerOrdersOrders {
  final double totalAmount;
  final String status;
  ListCustomerOrdersOrders.fromJson(dynamic json):
  
  totalAmount = nativeFromJson<double>(json['totalAmount']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListCustomerOrdersOrders otherTyped = other as ListCustomerOrdersOrders;
    return totalAmount == otherTyped.totalAmount && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([totalAmount.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['totalAmount'] = nativeToJson<double>(totalAmount);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  ListCustomerOrdersOrders({
    required this.totalAmount,
    required this.status,
  });
}

@immutable
class ListCustomerOrdersData {
  final List<ListCustomerOrdersOrders> orders;
  ListCustomerOrdersData.fromJson(dynamic json):
  
  orders = (json['orders'] as List<dynamic>)
        .map((e) => ListCustomerOrdersOrders.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListCustomerOrdersData otherTyped = other as ListCustomerOrdersData;
    return orders == otherTyped.orders;
    
  }
  @override
  int get hashCode => orders.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['orders'] = orders.map((e) => e.toJson()).toList();
    return json;
  }

  ListCustomerOrdersData({
    required this.orders,
  });
}

