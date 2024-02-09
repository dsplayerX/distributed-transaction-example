# Distributed Transactions in Ballerina

This repository contains a distributed transaction example implemented using Ballerina, showcasing how to coordinate transactions across multiple microservices. The example implementation is a simple e-commerce platform that handles inventory updates, payment processing, and user notifications.

## How It Works
1. Place Order: When an order is placed through the order service, it initiates a transaction.
2. Transaction Coordination: Within the transaction, the order service interacts with the payment service and the inventory service.
3. Payment Verification: The order service verifies the payment by calling the payment service.
4. Inventory Update: Simultaneously, it updates the inventory by calling the inventory service.
5. Commit/Rollback: If all operations are successful, the transaction commits, ensuring the order is completed. Otherwise, it rolls back, ensuring data consistency.

## Services

| Service            | Service Path | Port | Description                                                                                            |
|--------------------|--------------|------|--------------------------------------------------------------------------------------------------------|
| Order Service      | `/`          | 9650 | Manages order placement and coordinates with the payment and inventory services for order completion. |
| Payment Service    | `/payment`   | 9651 | Handles payment transactions and interacts with a MySQL database for payment validation and updates.  |
| Inventory Service  | `/inventory` | 9652 | Manages inventory, ensures item availability, and updates inventory status after order placement.   |

## Usage

### Pre-requisists 
Create necessary databases, tables and add configurations in Config.toml files.

- Run 2 database (MySQL) instances on separate docker containers.

    ```
    docker run -e MYSQL_ROOT_PASSWORD=<password> -p <PORT>:3306 -d mysql
    ```
- Create `Stock` table.
    ```
    CREATE TABLE IF NOT EXISTS Stock (
        itemId INT PRIMARY KEY,
        amount INT,
        unitPrice INT
    );
    ```
- Create `Payments` table.
    ```
    CREATE TABLE IF NOT EXISTS Payments (
        `cardno` VARCHAR(16) NOT NULL PRIMARY KEY,
        `amount` INT NOT NULL
    );
    ```
<details> 
<summary>Populate both tables with dummy data.</summary>

```
INSERT INTO `Stock`
    (`itemId`, `amount`, `unitPrice`)
    VALUES
    (1, 100, 20),
    (2, 150, 25),
    (3, 200, 18),
    (4, 10, 60);
```
```
INSERT INTO `Payments`
    (`cardno`, `amount`)
    VALUES
    ('card1', 1000),
    ('card2', 2000),
    ('card3', 5000);
```
</details>

### Running the Example
1. Run the payment, inventory and order services using `bal run` command.
2. Try it out by sending a post request to `placeOrder` endpoint on port `9650` with a `OrderRequest`
       (```
       {
           cardNo='',
           itemId='',
           qty=''
       }
       ```).

## Sequence Diagram

```mermaid
sequenceDiagram
    participant OrderService
    participant Coordinator
    participant PaymentService
    participant InventoryService
 
        OrderService->>Coordinator: Begin Transaction
        Coordinator->PaymentService: Register participant for txn
        Coordinator->InventoryService: Register participant for txn
    
    OrderService->>Coordinator: Make Payment
    Coordinator->>PaymentService: Do Payment
    OrderService->>Coordinator: Update Inventory
    Coordinator->>InventoryService: Update Inventory


    PaymentService-->>Coordinator: Payment Response
    InventoryService-->>Coordinator: Inventory Update Response
    
    rect rgba(138,138,138,255)
        Coordinator->>PaymentService: Prepare
        Coordinator->>InventoryService: Prepare
            PaymentService->>Coordinator: Prepared
            InventoryService->>Coordinator: Prepared
    end
    Note over Coordinator: Makes Decision    
    alt Prepare Successful
        Coordinator-->>PaymentService: Commit Payment
        Coordinator-->>InventoryService: Commit Inventory Update
        OrderService->>OrderService: Send Order Confirmation        
        Coordinator-->>OrderService: Transaction Committed
    else Transaction / Prepare Failed
        Coordinator-->>PaymentService: Rollback Payment
        Coordinator-->>InventoryService: Rollback Inventory Update
        Coordinator-->>OrderService: Transaction Rolled Back
    end
    Coordinator->>OrderService: End Transaction
    
```

## Tech Stack
1. Ballerina
2. MySQL Databases

