import ballerina/http;

public type Payment record {
    string cardno;
    int amount;
};

public type PurchaseRequest record {
    string cardno;
    int itemId;
    int qty;
};

string cardNo = "card10";

final http:Client paymentClient;
final http:Client inventoryClient;

function init() returns error? {
    paymentClient = check new ("http://localhost:9002");
    inventoryClient = check new ("http://localhost:9006");
}

public function main() returns error? {
    retry transaction {
        check pay(cardNo);
        check updateInventory(cardNo);
        check commit;
    }
}

transactional function pay(string cardno) returns error? {
    Payment payment = {cardno: cardno, amount: 10};
    boolean|error? response = paymentClient->post("/pay", payment);
    if (response is error) {
        return error 'error:Retriable("Payment failed");
    }
}

transactional function updateInventory(string cardno) returns error? {
    PurchaseRequest purchaseRequest = {cardno: cardno, itemId: 20, qty: 2};
    json|error? response = inventoryClient->post("/inventory/purchase", purchaseRequest);
    if (response is error) {
        return error 'error:Retriable("Inventory update failed");
    }
}

