import ballerina/http;
import ballerina/log;

public type Payment record {|
    string cardno;
    int amount;
|};

public type OrderRequest record {|
    string cardno;
    int itemId;
    int qty;
|};

final http:Client paymentClient;
final http:Client inventoryClient;

service / on new http:Listener(9650) {
    function init() returns error? {
        paymentClient = check new ("http://localhost:9651");
        inventoryClient = check new ("http://localhost:9652");
        log:printInfo("Order service started!");
    }

    resource function post placeOrder(OrderRequest orderRequest) returns string|error? {
        // log:printInfo(string`Is within transaction: ${transactional}`);
        log:printInfo("Transaction start!");
        transaction {
            transaction:onCommit(commitHanlder);
            transaction:onRollback(rollbackHandler);
            // log:printInfo(string`Is within transaction: ${transactional}`);

            check makePayment(orderRequest);
            check updateInventory(orderRequest);

            check commit;
        }
        log:printInfo("Transaction end!");
        return "Order placed successfully!";
    }
}

transactional function makePayment(OrderRequest orderRequest) returns error? {
    int totalPrice = check getTotalPrice(orderRequest) ?: 0;
    if (totalPrice == 0) {
        return error("Item not found or insufficient quantity available.");
    }
    Payment payment = {cardno: orderRequest.cardno, amount: totalPrice};
    error? response = paymentClient->post("/payment/pay", payment);
    if (response is error) {
        return error("Payment failed!");
    }
    log:printInfo("Payment successful!");
}

transactional function updateInventory(OrderRequest orderRequest) returns error? {
    json|error? response = inventoryClient->post("/inventory/updateStock", orderRequest);
    if (response is error) {
        return error("Inventory update failed!");
    }
    log:printInfo("Inventory update successful!");
}

transactional function getTotalPrice(OrderRequest orderRequest) returns int|error? {
    int|error? response = inventoryClient->post("/inventory/getTotalPrice", orderRequest);
    if (response is int) {
        log:printInfo(string `Total price: ${response}`);
        return response;
    }
    return error("Item not found or insufficient quantity available.");
}

isolated function commitHanlder('transaction:Info info) {
    // send a message/email
    log:printDebug("EMAIL SENT!");

    log:printInfo("Commit Handler: Transaction committed!");
}

isolated function rollbackHandler(transaction:Info info, error? cause, boolean willRetry = true) {
    log:printInfo("Rollback Handler: Transaction rolled back!");
}
