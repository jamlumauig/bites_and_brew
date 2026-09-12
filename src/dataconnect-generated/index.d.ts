import { ConnectorConfig, DataConnect, QueryRef, QueryPromise, ExecuteQueryOptions, MutationRef, MutationPromise, DataConnectSettings } from 'firebase/data-connect';

export const connectorConfig: ConnectorConfig;
export const dataConnectSettings: DataConnectSettings;

export type TimestampString = string;
export type UUIDString = string;
export type Int64String = string;
export type DateString = string;




export interface CreateCustomersData {
  customer_insert: Customer_Key;
}

export interface CreateOrdersData {
  order_insert: Order_Key;
}

export interface CreateProductsData {
  product_insertMany: Product_Key[];
}

export interface CreateStoresData {
  store_insert: Store_Key;
}

export interface Customer_Key {
  id: UUIDString;
  __typename?: 'Customer_Key';
}

export interface DeleteProductData {
  product_delete?: Product_Key | null;
}

export interface DeleteProductVariables {
  id: UUIDString;
}

export interface GetProductData {
  product?: {
    name: string;
    price: number;
    sku: string;
  };
}

export interface GetProductVariables {
  id: UUIDString;
}

export interface ListAllProductsData {
  products: ({
    name: string;
    price: number;
    sku: string;
  })[];
}

export interface ListCustomerOrdersData {
  orders: ({
    totalAmount: number;
    status: string;
  })[];
}

export interface OrderItem_Key {
  id: UUIDString;
  __typename?: 'OrderItem_Key';
}

export interface Order_Key {
  id: UUIDString;
  __typename?: 'Order_Key';
}

export interface Product_Key {
  id: UUIDString;
  __typename?: 'Product_Key';
}

export interface Store_Key {
  id: UUIDString;
  __typename?: 'Store_Key';
}

export interface UpdateProductData {
  product_update?: Product_Key | null;
}

export interface UpdateProductVariables {
  id: UUIDString;
  price?: number | null;
}

interface CreateProductsRef {
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateProductsData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): MutationRef<CreateProductsData, undefined>;
  operationName: string;
}
export const createProductsRef: CreateProductsRef;

export function createProducts(): MutationPromise<CreateProductsData, undefined>;
export function createProducts(dc: DataConnect): MutationPromise<CreateProductsData, undefined>;

interface CreateCustomersRef {
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateCustomersData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): MutationRef<CreateCustomersData, undefined>;
  operationName: string;
}
export const createCustomersRef: CreateCustomersRef;

export function createCustomers(): MutationPromise<CreateCustomersData, undefined>;
export function createCustomers(dc: DataConnect): MutationPromise<CreateCustomersData, undefined>;

interface CreateStoresRef {
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateStoresData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): MutationRef<CreateStoresData, undefined>;
  operationName: string;
}
export const createStoresRef: CreateStoresRef;

export function createStores(): MutationPromise<CreateStoresData, undefined>;
export function createStores(dc: DataConnect): MutationPromise<CreateStoresData, undefined>;

interface CreateOrdersRef {
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateOrdersData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): MutationRef<CreateOrdersData, undefined>;
  operationName: string;
}
export const createOrdersRef: CreateOrdersRef;

export function createOrders(): MutationPromise<CreateOrdersData, undefined>;
export function createOrders(dc: DataConnect): MutationPromise<CreateOrdersData, undefined>;

interface UpdateProductRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateProductVariables): MutationRef<UpdateProductData, UpdateProductVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateProductVariables): MutationRef<UpdateProductData, UpdateProductVariables>;
  operationName: string;
}
export const updateProductRef: UpdateProductRef;

export function updateProduct(vars: UpdateProductVariables): MutationPromise<UpdateProductData, UpdateProductVariables>;
export function updateProduct(dc: DataConnect, vars: UpdateProductVariables): MutationPromise<UpdateProductData, UpdateProductVariables>;

interface DeleteProductRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteProductVariables): MutationRef<DeleteProductData, DeleteProductVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeleteProductVariables): MutationRef<DeleteProductData, DeleteProductVariables>;
  operationName: string;
}
export const deleteProductRef: DeleteProductRef;

export function deleteProduct(vars: DeleteProductVariables): MutationPromise<DeleteProductData, DeleteProductVariables>;
export function deleteProduct(dc: DataConnect, vars: DeleteProductVariables): MutationPromise<DeleteProductData, DeleteProductVariables>;

interface GetProductRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetProductVariables): QueryRef<GetProductData, GetProductVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: GetProductVariables): QueryRef<GetProductData, GetProductVariables>;
  operationName: string;
}
export const getProductRef: GetProductRef;

export function getProduct(vars: GetProductVariables, options?: ExecuteQueryOptions): QueryPromise<GetProductData, GetProductVariables>;
export function getProduct(dc: DataConnect, vars: GetProductVariables, options?: ExecuteQueryOptions): QueryPromise<GetProductData, GetProductVariables>;

interface ListAllProductsRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListAllProductsData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<ListAllProductsData, undefined>;
  operationName: string;
}
export const listAllProductsRef: ListAllProductsRef;

export function listAllProducts(options?: ExecuteQueryOptions): QueryPromise<ListAllProductsData, undefined>;
export function listAllProducts(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListAllProductsData, undefined>;

interface ListCustomerOrdersRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListCustomerOrdersData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<ListCustomerOrdersData, undefined>;
  operationName: string;
}
export const listCustomerOrdersRef: ListCustomerOrdersRef;

export function listCustomerOrders(options?: ExecuteQueryOptions): QueryPromise<ListCustomerOrdersData, undefined>;
export function listCustomerOrders(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListCustomerOrdersData, undefined>;

