# distributed-transaction-example

# Tech Stack
1. Ballerina
2. MySQL Databases

# Usage

1. Create necessary databases, tables and add configurations in Config.toml files.
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

2. Run all three services with `bal run`.
3. Try it out by sending a post request to `placeOrder` endpoint on port `9650` with a `OrderRequest`.

# Sequence Diagram

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
