library dataconnect_generated;

import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_products.dart';

part 'create_customers.dart';

part 'create_stores.dart';

part 'create_orders.dart';

part 'update_product.dart';

part 'delete_product.dart';

part 'get_product.dart';

part 'list_all_products.dart';

part 'list_customer_orders.dart';

class ExampleConnector {
  CreateProductsVariablesBuilder createProducts() {
    return CreateProductsVariablesBuilder(dataConnect);
  }

  CreateCustomersVariablesBuilder createCustomers() {
    return CreateCustomersVariablesBuilder(dataConnect);
  }

  CreateStoresVariablesBuilder createStores() {
    return CreateStoresVariablesBuilder(dataConnect);
  }

  CreateOrdersVariablesBuilder createOrders() {
    return CreateOrdersVariablesBuilder(dataConnect);
  }

  UpdateProductVariablesBuilder updateProduct({required String id}) {
    return UpdateProductVariablesBuilder(dataConnect, id: id);
  }

  DeleteProductVariablesBuilder deleteProduct({required String id}) {
    return DeleteProductVariablesBuilder(dataConnect, id: id);
  }

  GetProductVariablesBuilder getProduct({required String id}) {
    return GetProductVariablesBuilder(dataConnect, id: id);
  }

  ListAllProductsVariablesBuilder listAllProducts() {
    return ListAllProductsVariablesBuilder(dataConnect);
  }

  ListCustomerOrdersVariablesBuilder listCustomerOrders() {
    return ListCustomerOrdersVariablesBuilder(dataConnect);
  }

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east1',
    'example',
    'cafeandbrews',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
      dataConnect: FirebaseDataConnect.instanceFor(
        connectorConfig: connectorConfig,
        sdkType: CallerSDKType.generated,
      ),
    );
  }

  FirebaseDataConnect dataConnect;
}
