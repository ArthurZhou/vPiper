# vPiper

Chat across firewalls

# Run
1. Type `v -enable-globals run ./main.v` to run main file. This will start a server on `ws://localhost:28174`
2. Run `test/client1.v`. client1 will try to connect port `28174` and open a server on port `28175`
3. Run `test/client2.v`. client2 will connect to port `28175`
4. Send a message on one of the clients and others will display your message.
Although `main.v` and `test/client2.v` are not connected with each other, they can communicate with each other through `test/client1.v`


