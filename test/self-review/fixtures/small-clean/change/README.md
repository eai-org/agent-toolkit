# Orders

In-memory order service used by the checkout demo.

- An order holds line items priced in cents.
- An order may carry a note of at most 200 characters, given at placement.
- Orders can be cancelled while `PENDING`.
