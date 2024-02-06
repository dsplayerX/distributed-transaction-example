import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerinax/mysql;

public type Payment record {|
    string cardno;
    int amount;
|};

type paymentDBRow record {
    int amount;
};

public type DBConfigs record {
    string hostname;
    string username;
    string password;
    int port;
    string database;
};

configurable DBConfigs paymentDBConfigs = ?;

sql:ConnectionPool pool = {
    maxOpenConnections: 5,
    maxConnectionLifeTime: 300,
    minIdleConnections: 0
};

service /payment on new http:Listener(9651) {
    final mysql:Client paymentDB;
    function init() returns error? {
        self.paymentDB = check new (host = paymentDBConfigs.hostname,
            user = paymentDBConfigs.username, password = paymentDBConfigs.password,
            port = paymentDBConfigs.port, database = paymentDBConfigs.database,
            connectionPool = pool,
            options = {
                useXADatasource: true
            }
        );
        log:printInfo("Payment service started!");
    }

    transactional resource function post pay(Payment payment) returns error? {
        // see if card exists and has enough balance
        log:printInfo(string `Card no: ${payment.cardno} amount: ${payment.amount}`);
        sql:ParameterizedQuery selectQuery = `SELECT amount FROM Payments WHERE cardno = ${payment.cardno}`;
        paymentDBRow|sql:Error selectResult = self.paymentDB->queryRow(selectQuery);
        if (selectResult is sql:Error) {
            return error("Card not found!");
        }
        log:printInfo(string `Balance: ${selectResult.amount}`);
        if (selectResult.amount < payment.amount) {
            log:printInfo(string `Insufficient balance! Available balance: ${selectResult.amount} requested: ${payment.amount}`);
            return error("Insufficient balance!");
        }

        // do the payment
        sql:ParameterizedQuery updateQuery = `UPDATE Payments SET amount = amount - ${payment.amount} WHERE cardno = ${payment.cardno}`;
        sql:ExecutionResult|sql:Error updateResult = self.paymentDB->execute(updateQuery);
        if (updateResult is sql:ExecutionResult) {
            if (updateResult.affectedRowCount == 1) {
                log:printInfo("Payment update successful!");
                return;
            }
        }
        log:printInfo("Payment update failed!");
        return error("Payment update failed!");
    }
}
