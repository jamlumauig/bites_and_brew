# Generated TypeScript README
This README will guide you through the process of using the generated JavaScript SDK package for the connector `example`. It will also provide examples on how to use your generated SDK to call your Data Connect queries and mutations.

***NOTE:** This README is generated alongside the generated SDK. If you make changes to this file, they will be overwritten when the SDK is regenerated.*

# Table of Contents
- [**Overview**](#generated-javascript-readme)
- [**Accessing the connector**](#accessing-the-connector)
  - [*Connecting to the local Emulator*](#connecting-to-the-local-emulator)
- [**Queries**](#queries)
  - [*GetProduct*](#getproduct)
  - [*ListAllProducts*](#listallproducts)
  - [*ListCustomerOrders*](#listcustomerorders)
- [**Mutations**](#mutations)
  - [*CreateProducts*](#createproducts)
  - [*CreateCustomers*](#createcustomers)
  - [*CreateStores*](#createstores)
  - [*CreateOrders*](#createorders)
  - [*UpdateProduct*](#updateproduct)
  - [*DeleteProduct*](#deleteproduct)

# Accessing the connector
A connector is a collection of Queries and Mutations. One SDK is generated for each connector - this SDK is generated for the connector `example`. You can find more information about connectors in the [Data Connect documentation](https://firebase.google.com/docs/data-connect#how-does).

You can use this generated SDK by importing from the package `@dataconnect/generated` as shown below. Both CommonJS and ESM imports are supported.

You can also follow the instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#set-client).

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
```

## Connecting to the local Emulator
By default, the connector will connect to the production service.

To connect to the emulator, you can use the following code.
You can also follow the emulator instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#instrument-clients).

```typescript
import { connectDataConnectEmulator, getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
connectDataConnectEmulator(dataConnect, 'localhost', 9399);
```

After it's initialized, you can call your Data Connect [queries](#queries) and [mutations](#mutations) from your generated SDK.

# Queries

There are two ways to execute a Data Connect Query using the generated Web SDK:
- Using a Query Reference function, which returns a `QueryRef`
  - The `QueryRef` can be used as an argument to `executeQuery()`, which will execute the Query and return a `QueryPromise`
- Using an action shortcut function, which returns a `QueryPromise`
  - Calling the action shortcut function will execute the Query and return a `QueryPromise`

The following is true for both the action shortcut function and the `QueryRef` function:
- The `QueryPromise` returned will resolve to the result of the Query once it has finished executing
- If the Query accepts arguments, both the action shortcut function and the `QueryRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Query
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `example` connector's generated functions to execute each query. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-queries).

## GetProduct
You can execute the `GetProduct` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
getProduct(vars: GetProductVariables, options?: ExecuteQueryOptions): QueryPromise<GetProductData, GetProductVariables>;

interface GetProductRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetProductVariables): QueryRef<GetProductData, GetProductVariables>;
}
export const getProductRef: GetProductRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getProduct(dc: DataConnect, vars: GetProductVariables, options?: ExecuteQueryOptions): QueryPromise<GetProductData, GetProductVariables>;

interface GetProductRef {
  ...
  (dc: DataConnect, vars: GetProductVariables): QueryRef<GetProductData, GetProductVariables>;
}
export const getProductRef: GetProductRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getProductRef:
```typescript
const name = getProductRef.operationName;
console.log(name);
```

### Variables
The `GetProduct` query requires an argument of type `GetProductVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface GetProductVariables {
  id: UUIDString;
}
```
### Return Type
Recall that executing the `GetProduct` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetProductData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface GetProductData {
  product?: {
    name: string;
    price: number;
    sku: string;
  };
}
```
### Using `GetProduct`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getProduct, GetProductVariables } from '@dataconnect/generated';

// The `GetProduct` query requires an argument of type `GetProductVariables`:
const getProductVars: GetProductVariables = {
  id: ..., 
};

// Call the `getProduct()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getProduct(getProductVars);
// Variables can be defined inline as well.
const { data } = await getProduct({ id: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getProduct(dataConnect, getProductVars);

console.log(data.product);

// Or, you can use the `Promise` API.
getProduct(getProductVars).then((response) => {
  const data = response.data;
  console.log(data.product);
});
```

### Using `GetProduct`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getProductRef, GetProductVariables } from '@dataconnect/generated';

// The `GetProduct` query requires an argument of type `GetProductVariables`:
const getProductVars: GetProductVariables = {
  id: ..., 
};

// Call the `getProductRef()` function to get a reference to the query.
const ref = getProductRef(getProductVars);
// Variables can be defined inline as well.
const ref = getProductRef({ id: ..., });

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getProductRef(dataConnect, getProductVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.product);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.product);
});
```

## ListAllProducts
You can execute the `ListAllProducts` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listAllProducts(options?: ExecuteQueryOptions): QueryPromise<ListAllProductsData, undefined>;

interface ListAllProductsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListAllProductsData, undefined>;
}
export const listAllProductsRef: ListAllProductsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listAllProducts(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListAllProductsData, undefined>;

interface ListAllProductsRef {
  ...
  (dc: DataConnect): QueryRef<ListAllProductsData, undefined>;
}
export const listAllProductsRef: ListAllProductsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listAllProductsRef:
```typescript
const name = listAllProductsRef.operationName;
console.log(name);
```

### Variables
The `ListAllProducts` query has no variables.
### Return Type
Recall that executing the `ListAllProducts` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListAllProductsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListAllProductsData {
  products: ({
    name: string;
    price: number;
    sku: string;
  })[];
}
```
### Using `ListAllProducts`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listAllProducts } from '@dataconnect/generated';


// Call the `listAllProducts()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listAllProducts();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listAllProducts(dataConnect);

console.log(data.products);

// Or, you can use the `Promise` API.
listAllProducts().then((response) => {
  const data = response.data;
  console.log(data.products);
});
```

### Using `ListAllProducts`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listAllProductsRef } from '@dataconnect/generated';


// Call the `listAllProductsRef()` function to get a reference to the query.
const ref = listAllProductsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listAllProductsRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.products);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.products);
});
```

## ListCustomerOrders
You can execute the `ListCustomerOrders` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listCustomerOrders(options?: ExecuteQueryOptions): QueryPromise<ListCustomerOrdersData, undefined>;

interface ListCustomerOrdersRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListCustomerOrdersData, undefined>;
}
export const listCustomerOrdersRef: ListCustomerOrdersRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listCustomerOrders(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListCustomerOrdersData, undefined>;

interface ListCustomerOrdersRef {
  ...
  (dc: DataConnect): QueryRef<ListCustomerOrdersData, undefined>;
}
export const listCustomerOrdersRef: ListCustomerOrdersRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listCustomerOrdersRef:
```typescript
const name = listCustomerOrdersRef.operationName;
console.log(name);
```

### Variables
The `ListCustomerOrders` query has no variables.
### Return Type
Recall that executing the `ListCustomerOrders` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListCustomerOrdersData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListCustomerOrdersData {
  orders: ({
    totalAmount: number;
    status: string;
  })[];
}
```
### Using `ListCustomerOrders`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listCustomerOrders } from '@dataconnect/generated';


// Call the `listCustomerOrders()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listCustomerOrders();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listCustomerOrders(dataConnect);

console.log(data.orders);

// Or, you can use the `Promise` API.
listCustomerOrders().then((response) => {
  const data = response.data;
  console.log(data.orders);
});
```

### Using `ListCustomerOrders`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listCustomerOrdersRef } from '@dataconnect/generated';


// Call the `listCustomerOrdersRef()` function to get a reference to the query.
const ref = listCustomerOrdersRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listCustomerOrdersRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.orders);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.orders);
});
```

# Mutations

There are two ways to execute a Data Connect Mutation using the generated Web SDK:
- Using a Mutation Reference function, which returns a `MutationRef`
  - The `MutationRef` can be used as an argument to `executeMutation()`, which will execute the Mutation and return a `MutationPromise`
- Using an action shortcut function, which returns a `MutationPromise`
  - Calling the action shortcut function will execute the Mutation and return a `MutationPromise`

The following is true for both the action shortcut function and the `MutationRef` function:
- The `MutationPromise` returned will resolve to the result of the Mutation once it has finished executing
- If the Mutation accepts arguments, both the action shortcut function and the `MutationRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Mutation
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `example` connector's generated functions to execute each mutation. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-mutations).

## CreateProducts
You can execute the `CreateProducts` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createProducts(): MutationPromise<CreateProductsData, undefined>;

interface CreateProductsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateProductsData, undefined>;
}
export const createProductsRef: CreateProductsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createProducts(dc: DataConnect): MutationPromise<CreateProductsData, undefined>;

interface CreateProductsRef {
  ...
  (dc: DataConnect): MutationRef<CreateProductsData, undefined>;
}
export const createProductsRef: CreateProductsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createProductsRef:
```typescript
const name = createProductsRef.operationName;
console.log(name);
```

### Variables
The `CreateProducts` mutation has no variables.
### Return Type
Recall that executing the `CreateProducts` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateProductsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateProductsData {
  product_insertMany: Product_Key[];
}
```
### Using `CreateProducts`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createProducts } from '@dataconnect/generated';


// Call the `createProducts()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createProducts();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createProducts(dataConnect);

console.log(data.product_insertMany);

// Or, you can use the `Promise` API.
createProducts().then((response) => {
  const data = response.data;
  console.log(data.product_insertMany);
});
```

### Using `CreateProducts`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createProductsRef } from '@dataconnect/generated';


// Call the `createProductsRef()` function to get a reference to the mutation.
const ref = createProductsRef();

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createProductsRef(dataConnect);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.product_insertMany);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.product_insertMany);
});
```

## CreateCustomers
You can execute the `CreateCustomers` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createCustomers(): MutationPromise<CreateCustomersData, undefined>;

interface CreateCustomersRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateCustomersData, undefined>;
}
export const createCustomersRef: CreateCustomersRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createCustomers(dc: DataConnect): MutationPromise<CreateCustomersData, undefined>;

interface CreateCustomersRef {
  ...
  (dc: DataConnect): MutationRef<CreateCustomersData, undefined>;
}
export const createCustomersRef: CreateCustomersRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createCustomersRef:
```typescript
const name = createCustomersRef.operationName;
console.log(name);
```

### Variables
The `CreateCustomers` mutation has no variables.
### Return Type
Recall that executing the `CreateCustomers` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateCustomersData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateCustomersData {
  customer_insert: Customer_Key;
}
```
### Using `CreateCustomers`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createCustomers } from '@dataconnect/generated';


// Call the `createCustomers()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createCustomers();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createCustomers(dataConnect);

console.log(data.customer_insert);

// Or, you can use the `Promise` API.
createCustomers().then((response) => {
  const data = response.data;
  console.log(data.customer_insert);
});
```

### Using `CreateCustomers`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createCustomersRef } from '@dataconnect/generated';


// Call the `createCustomersRef()` function to get a reference to the mutation.
const ref = createCustomersRef();

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createCustomersRef(dataConnect);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.customer_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.customer_insert);
});
```

## CreateStores
You can execute the `CreateStores` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createStores(): MutationPromise<CreateStoresData, undefined>;

interface CreateStoresRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateStoresData, undefined>;
}
export const createStoresRef: CreateStoresRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createStores(dc: DataConnect): MutationPromise<CreateStoresData, undefined>;

interface CreateStoresRef {
  ...
  (dc: DataConnect): MutationRef<CreateStoresData, undefined>;
}
export const createStoresRef: CreateStoresRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createStoresRef:
```typescript
const name = createStoresRef.operationName;
console.log(name);
```

### Variables
The `CreateStores` mutation has no variables.
### Return Type
Recall that executing the `CreateStores` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateStoresData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateStoresData {
  store_insert: Store_Key;
}
```
### Using `CreateStores`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createStores } from '@dataconnect/generated';


// Call the `createStores()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createStores();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createStores(dataConnect);

console.log(data.store_insert);

// Or, you can use the `Promise` API.
createStores().then((response) => {
  const data = response.data;
  console.log(data.store_insert);
});
```

### Using `CreateStores`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createStoresRef } from '@dataconnect/generated';


// Call the `createStoresRef()` function to get a reference to the mutation.
const ref = createStoresRef();

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createStoresRef(dataConnect);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.store_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.store_insert);
});
```

## CreateOrders
You can execute the `CreateOrders` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createOrders(): MutationPromise<CreateOrdersData, undefined>;

interface CreateOrdersRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateOrdersData, undefined>;
}
export const createOrdersRef: CreateOrdersRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createOrders(dc: DataConnect): MutationPromise<CreateOrdersData, undefined>;

interface CreateOrdersRef {
  ...
  (dc: DataConnect): MutationRef<CreateOrdersData, undefined>;
}
export const createOrdersRef: CreateOrdersRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createOrdersRef:
```typescript
const name = createOrdersRef.operationName;
console.log(name);
```

### Variables
The `CreateOrders` mutation has no variables.
### Return Type
Recall that executing the `CreateOrders` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateOrdersData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateOrdersData {
  order_insert: Order_Key;
}
```
### Using `CreateOrders`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createOrders } from '@dataconnect/generated';


// Call the `createOrders()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createOrders();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createOrders(dataConnect);

console.log(data.order_insert);

// Or, you can use the `Promise` API.
createOrders().then((response) => {
  const data = response.data;
  console.log(data.order_insert);
});
```

### Using `CreateOrders`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createOrdersRef } from '@dataconnect/generated';


// Call the `createOrdersRef()` function to get a reference to the mutation.
const ref = createOrdersRef();

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createOrdersRef(dataConnect);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.order_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.order_insert);
});
```

## UpdateProduct
You can execute the `UpdateProduct` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateProduct(vars: UpdateProductVariables): MutationPromise<UpdateProductData, UpdateProductVariables>;

interface UpdateProductRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateProductVariables): MutationRef<UpdateProductData, UpdateProductVariables>;
}
export const updateProductRef: UpdateProductRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateProduct(dc: DataConnect, vars: UpdateProductVariables): MutationPromise<UpdateProductData, UpdateProductVariables>;

interface UpdateProductRef {
  ...
  (dc: DataConnect, vars: UpdateProductVariables): MutationRef<UpdateProductData, UpdateProductVariables>;
}
export const updateProductRef: UpdateProductRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateProductRef:
```typescript
const name = updateProductRef.operationName;
console.log(name);
```

### Variables
The `UpdateProduct` mutation requires an argument of type `UpdateProductVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateProductVariables {
  id: UUIDString;
  price?: number | null;
}
```
### Return Type
Recall that executing the `UpdateProduct` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateProductData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateProductData {
  product_update?: Product_Key | null;
}
```
### Using `UpdateProduct`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateProduct, UpdateProductVariables } from '@dataconnect/generated';

// The `UpdateProduct` mutation requires an argument of type `UpdateProductVariables`:
const updateProductVars: UpdateProductVariables = {
  id: ..., 
  price: ..., // optional
};

// Call the `updateProduct()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateProduct(updateProductVars);
// Variables can be defined inline as well.
const { data } = await updateProduct({ id: ..., price: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateProduct(dataConnect, updateProductVars);

console.log(data.product_update);

// Or, you can use the `Promise` API.
updateProduct(updateProductVars).then((response) => {
  const data = response.data;
  console.log(data.product_update);
});
```

### Using `UpdateProduct`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateProductRef, UpdateProductVariables } from '@dataconnect/generated';

// The `UpdateProduct` mutation requires an argument of type `UpdateProductVariables`:
const updateProductVars: UpdateProductVariables = {
  id: ..., 
  price: ..., // optional
};

// Call the `updateProductRef()` function to get a reference to the mutation.
const ref = updateProductRef(updateProductVars);
// Variables can be defined inline as well.
const ref = updateProductRef({ id: ..., price: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateProductRef(dataConnect, updateProductVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.product_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.product_update);
});
```

## DeleteProduct
You can execute the `DeleteProduct` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deleteProduct(vars: DeleteProductVariables): MutationPromise<DeleteProductData, DeleteProductVariables>;

interface DeleteProductRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteProductVariables): MutationRef<DeleteProductData, DeleteProductVariables>;
}
export const deleteProductRef: DeleteProductRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deleteProduct(dc: DataConnect, vars: DeleteProductVariables): MutationPromise<DeleteProductData, DeleteProductVariables>;

interface DeleteProductRef {
  ...
  (dc: DataConnect, vars: DeleteProductVariables): MutationRef<DeleteProductData, DeleteProductVariables>;
}
export const deleteProductRef: DeleteProductRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deleteProductRef:
```typescript
const name = deleteProductRef.operationName;
console.log(name);
```

### Variables
The `DeleteProduct` mutation requires an argument of type `DeleteProductVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeleteProductVariables {
  id: UUIDString;
}
```
### Return Type
Recall that executing the `DeleteProduct` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeleteProductData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeleteProductData {
  product_delete?: Product_Key | null;
}
```
### Using `DeleteProduct`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deleteProduct, DeleteProductVariables } from '@dataconnect/generated';

// The `DeleteProduct` mutation requires an argument of type `DeleteProductVariables`:
const deleteProductVars: DeleteProductVariables = {
  id: ..., 
};

// Call the `deleteProduct()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteProduct(deleteProductVars);
// Variables can be defined inline as well.
const { data } = await deleteProduct({ id: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deleteProduct(dataConnect, deleteProductVars);

console.log(data.product_delete);

// Or, you can use the `Promise` API.
deleteProduct(deleteProductVars).then((response) => {
  const data = response.data;
  console.log(data.product_delete);
});
```

### Using `DeleteProduct`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deleteProductRef, DeleteProductVariables } from '@dataconnect/generated';

// The `DeleteProduct` mutation requires an argument of type `DeleteProductVariables`:
const deleteProductVars: DeleteProductVariables = {
  id: ..., 
};

// Call the `deleteProductRef()` function to get a reference to the mutation.
const ref = deleteProductRef(deleteProductVars);
// Variables can be defined inline as well.
const ref = deleteProductRef({ id: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deleteProductRef(dataConnect, deleteProductVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.product_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.product_delete);
});
```

