import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

public type orderRequest record {|
    string cardno;
    int itemId;
    int qty;
};

type inventoryDBRow record {
    int amount;
    int unitPrice;
};

public type DBConfigs record {
    string hostname;
    string username;
    string password;
    int port;
    string database;
};

configurable DBConfigs inventoryDBConfigs = ?;

sql:ConnectionPool pool = {
    maxOpenConnections: 5,
    maxConnectionLifeTime: 300,
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

    transactional resource function post getTotalPrice(orderRequest orderRequest) returns int|error? {
        // check if the item quantity is available
        sql:ParameterizedQuery selectQuery = `SELECT * FROM Stock WHERE itemId = ${orderRequest.itemId}`;
        inventoryDBRow|sql:Error result = self.inventoryDB->queryRow(selectQuery);
        if (result is sql:Error) {
            log:printError("Error while querying stock: ", result);
            // most probably the item is not found
            return error("Item not found!");
        }
        if (result.amount < orderRequest.qty) {
            log:printInfo("Insufficient stock! Available stock: " + result.amount.toString());
            return error("Insufficient stock!");
        }
        // get the total price
        int totalPrice = result.unitPrice * orderRequest.qty;
        log:printInfo(totalPrice.toString());
        return totalPrice;
    }

    transactional resource function post updateStock(orderRequest orderRequest) returns error? {
        log:printInfo(string`Updating stock: Item: ${orderRequest.itemId} | Qty: -${orderRequest.qty}`);
        sql:ParameterizedQuery updateQuery = `UPDATE Stock SET amount = amount - ${orderRequest.qty} WHERE itemId = ${orderRequest.itemId}`;
        sql:ExecutionResult|sql:Error updateResult = self.inventoryDB->execute(updateQuery);
        if (updateResult is sql:Error) {
            log:printError("Error while updating stock: ", updateResult);
            return error("Error while updating stock: ", updateResult);
        }
        log:printInfo("Stock update successfull!");
    }
}
