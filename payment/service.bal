import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

public type Payment record {
    string cardno;
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

service /payment on new http:Listener(9002) {
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
    }

    resource function post pay(Payment payment) returns boolean|error? {
        sql:ParameterizedQuery updateQuery = `UPDATE Payments SET amount = amount + ${payment.amount} WHERE cardno = ${payment.cardno}`;
        sql:ExecutionResult|sql:Error updateResult = self.paymentDB->execute(updateQuery);
        if (updateResult is sql:ExecutionResult) {
            if (updateResult.affectedRowCount == 1) {
                return true;
            }
        }
        return false;
    }
}
