import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

public type OrderRequest record {|
    string cardNo;
    int itemId;
    int qty;
|};

type InventoryDBRow record {
    int amount;
    int unitPrice;
};

public type DBConfigs record {|
    string hostname;
    string username;
    string password;
    int port;
    string database;
|};

configurable DBConfigs inventoryDBConfigs = ?;

sql:ConnectionPool pool = {
    maxOpenConnections: 5,
    maxConnectionLifeTime: 60,
    minIdleConnections: 0
};

service /inventory on new http:Listener(9652) {
    final mysql:Client inventoryDB;

    function init() returns error? {
        self.inventoryDB = check new (host = inventoryDBConfigs.hostname,
            user = inventoryDBConfigs.username, password = inventoryDBConfigs.password,
            port = inventoryDBConfigs.port, database = inventoryDBConfigs.database,
            connectionPool = pool,
            options = {
                useXADatasource: true
            }
        );
        log:printInfo("Inventory service started!");
    }

    transactional resource function post getTotalPrice(OrderRequest OrderRequest) returns int|error? {
        // check if the item quantity is available
        sql:ParameterizedQuery selectQuery = `SELECT * FROM Stock WHERE itemId = ${OrderRequest.itemId}`;
        InventoryDBRow|sql:Error result = self.inventoryDB->queryRow(selectQuery);
        if result is sql:Error {
            log:printError("Error while querying stock: ", result);
            // most probably the item is not found
            return error("Item not found!");
        }
        if result.amount < OrderRequest.qty {
            log:printInfo("Insufficient stock! Available stock: " + result.amount.toString());
            return error("Insufficient stock!");
        }
        // get the total price
        int totalPrice = result.unitPrice * OrderRequest.qty;
        log:printInfo(totalPrice.toString());
        return totalPrice;
    }

    transactional resource function post updateStock(OrderRequest OrderRequest) returns error? {
        log:printInfo(string`Updating stock: Item: ${OrderRequest.itemId} | Qty: -${OrderRequest.qty}`);
        sql:ParameterizedQuery updateQuery = `UPDATE Stock SET amount = amount - ${OrderRequest.qty} WHERE itemId = ${OrderRequest.itemId}`;
        sql:ExecutionResult|sql:Error updateResult = self.inventoryDB->execute(updateQuery);
        if updateResult is sql:Error {
            log:printError("Error while updating stock: ", updateResult);
            return error("Error while updating stock: ", updateResult);
        }
        log:printInfo("Stock update successfull!");
    }
}
