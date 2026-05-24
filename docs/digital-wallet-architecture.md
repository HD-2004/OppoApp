# Digital Wallet Architecture

## Security Boundary

Flutter must never write real wallet balances directly. The production flow is:

Flutter App -> Cognito Auth -> API Gateway or AppSync -> Lambda Wallet Service -> DynamoDB.

Backend rules:

- Read `userId` from Cognito claims, not from request body.
- Never log tokens, full bank account numbers, OTPs, passwords, or secrets.
- Store/display bank accounts using masked values on the client, for example `BIDV •••• 1234`.
- Encrypt full account numbers server-side if they must be stored.
- Create withdrawal requests instead of moving money from the mobile app.
- Validate wallet status, linked bank account, and available balance in Lambda.

## DynamoDB Tables

### UserWallets

Partition key: `userId`

Attributes:

- `availableBalance: number`
- `pendingBalance: number`
- `totalEarnings: number`
- `currency: "VND"`
- `status: "active" | "frozen"`
- `createdAt: string`
- `updatedAt: string`

### WalletTransactions

Partition key: `userId`

Sort key: `transactionId`

Attributes:

- `type: "earning" | "withdrawal" | "refund" | "adjustment"`
- `amount: number`
- `currency: "VND"`
- `status: "pending" | "processing" | "completed" | "failed" | "cancelled"`
- `description: string`
- `relatedJobId?: string`
- `relatedApplicationId?: string`
- `withdrawalRequestId?: string`
- `createdAt: string`
- `updatedAt: string`

Optional GSI: `userId` + `createdAt` for newest transactions.

### LinkedBankAccounts

Partition key: `userId`

Sort key: `bankAccountId`

Attributes:

- `bankName: string`
- `accountHolderName: string`
- `accountNumberMasked: string`
- `accountNumberEncrypted?: string`
- `branch?: string`
- `isDefault: boolean`
- `status: "active" | "removed"`
- `createdAt: string`
- `updatedAt: string`

### WithdrawalRequests

Partition key: `userId`

Sort key: `withdrawalRequestId`

Attributes:

- `amount: number`
- `currency: "VND"`
- `bankAccountId: string`
- `bankName: string`
- `accountNumberMasked: string`
- `status: "pending" | "processing" | "completed" | "failed" | "cancelled"`
- `requestedAt: string`
- `processedAt?: string`
- `failureReason?: string`

## API Contract

### `GET /wallet`

Returns wallet overview, default linked bank account, and recent transactions.

### `GET /wallet/transactions`

Query params:

- `type`
- `status`
- `limit`
- `nextToken`

### `POST /wallet/bank-accounts`

Body:

```json
{
  "bankName": "BIDV",
  "accountHolderName": "NGUYEN VAN A",
  "accountNumber": "1234567890",
  "branch": "Ho Chi Minh"
}
```

### `DELETE /wallet/bank-accounts/{bankAccountId}`

Soft remove by setting `status = removed`.

### `POST /wallet/withdrawals`

Body:

```json
{
  "amount": 300000,
  "bankAccountId": "bank_001"
}
```

Lambda must:

- Load userId from Cognito claims.
- Read wallet and active linked bank account.
- Check `wallet.status == active`.
- Check `availableBalance >= amount`.
- Create a pending withdrawal request.
- Create a pending wallet transaction.
- Hold or deduct available balance atomically.

### `GET /wallet/statistics`

Returns:

```json
{
  "thisWeekIncome": 450000,
  "thisMonthIncome": 2450000,
  "completedShifts": 12,
  "averageIncomePerShift": 204000
}
```
