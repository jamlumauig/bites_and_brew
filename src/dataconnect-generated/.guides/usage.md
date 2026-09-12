# Basic Usage

Always prioritize using a supported framework over using the generated SDK
directly. Supported frameworks simplify the developer experience and help ensure
best practices are followed.





## Advanced Usage
If a user is not using a supported framework, they can use the generated SDK directly.

Here's an example of how to use it with the first 5 operations:

```js
import { createProducts, createCustomers, createStores, createOrders, updateProduct, deleteProduct, getProduct, listAllProducts, listCustomerOrders } from '@dataconnect/generated';


// Operation CreateProducts: 
const { data } = await CreateProducts(dataConnect);

// Operation CreateCustomers: 
const { data } = await CreateCustomers(dataConnect);

// Operation CreateStores: 
const { data } = await CreateStores(dataConnect);

// Operation CreateOrders: 
const { data } = await CreateOrders(dataConnect);

// Operation UpdateProduct:  For variables, look at type UpdateProductVars in ../index.d.ts
const { data } = await UpdateProduct(dataConnect, updateProductVars);

// Operation DeleteProduct:  For variables, look at type DeleteProductVars in ../index.d.ts
const { data } = await DeleteProduct(dataConnect, deleteProductVars);

// Operation GetProduct:  For variables, look at type GetProductVars in ../index.d.ts
const { data } = await GetProduct(dataConnect, getProductVars);

// Operation ListAllProducts: 
const { data } = await ListAllProducts(dataConnect);

// Operation ListCustomerOrders: 
const { data } = await ListCustomerOrders(dataConnect);


```