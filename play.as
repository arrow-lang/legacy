use std.io.net.tcp.Server;
use std.io.Channel;
use std.io.stdout;
use std.spawn;
use std.println;

let main() -> {
    let server = Server.new();
    server.bind("0.0.0.0", 5000);
    listen(server);
}

let listen(server: net.tcp.Server) -> {
    loop {
        let client = match server.accept() {
            Ok(client) => client,
            _ => {
                # Server stopped accepting connections for some reason
                # or another; just break the loop and return.
                break;
            }
        }

        # Spawn a handler for the new client.
        spawn(handle(client));
    }
}

let handle(connection: net.tcp.Connection) -> {
    let buffer = connection.read(10);
    connection.write(buffer);
    connection.close();
}
