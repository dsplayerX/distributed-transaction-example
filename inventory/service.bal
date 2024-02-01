import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

public type PurchaseRequest record {
    string cardno;
    int itemId;
    int qty;
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

type rowType record {
    int amount;
};

service /inventory on new http:Listener(9006) {
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
    }

    resource function get stock/[int itemId]() returns int|error? {
        sql:ParameterizedQuery selectQuery = `SELECT amount FROM Stock WHERE itemId = ${itemId}`;
        int|sql:Error stock = self.inventoryDB->queryRow(selectQuery);
        return stock;
    }

    transactional resource function post purchase(PurchaseRequest purchaseRequest) returns error? {
        sql:ParameterizedQuery selectQuery = `SELECT unitPrice FROM Stock WHERE itemId = ${purchaseRequest.itemId}`;
        int|sql:Error price = self.inventoryDB->queryRow(selectQuery);
        if (price is sql:Error) {
            return error("Item not found!");
        }
        // int totalPrice = price * purchaseRequest.qty;
        sql:ParameterizedQuery updateQuery = `UPDATE Stock SET amount = amount - ${purchaseRequest.qty} WHERE itemId = ${purchaseRequest.itemId}`;
        sql:ExecutionResult|sql:Error updateResult = self.inventoryDB->execute(updateQuery);
        if (updateResult is sql:Error) {
            return error("Error while updating stock: ", updateResult);
        }
        return;
    }
}
