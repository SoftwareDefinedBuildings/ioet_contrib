require "storm"
require "string"
require "cord"
AsyncQueue = require "aqueue"

server_ip = "fe80::0212:6d02:0000:4021"

-- Create active socket
csock = storm.net.tcpactivesocket()

-- Bind socket to port 1024
storm.net.tcpbind(csock, 1024)

prevcord = nil
outqueue = nil
function connection_lost(how, socket)
    if how ~= 0 then -- connection broken
        if prevcord ~= nil then
            cord.cancel(prevcord) -- connect failed, so stop this cord
        end
        if outqueue ~= nil then
            outqueue:reset()
        end
        
        print("Attempting to connect")
        prevcord = cord.new(function ()
            cord.await(storm.os.invokeLater, storm.os.SECOND)
            tryconnect(socket)
        end)
    else
        storm.net.tcpclose(socket)
        print("Closed socket")
        -- End of program
    end
end

local readchunksize = 100
function onreceiveready(clsock)
    -- Empty the receive completely
    local buf = ""
    local chunk
    repeat
        _, chunk = storm.net.tcprecv(csock, readchunksize)
        buf = buf .. chunk
    until string.len(chunk) ~= readchunksize
    io.write(buf)
end

function tryconnect(clsock)
    local inp
    cord.await(storm.net.tcpconnect, clsock, server_ip, 74)
    storm.net.tcpaddrecvready(clsock, onreceiveready)
    outqueue = AsyncQueue:new(function (string, callback)
        storm.net.tcpsendfull(clsock, string, callback)
    end)
    print("Connected successfully.")
    while true do
        inp = cord.await(storm.os.read_stdin)
        outqueue:enqueue(inp)
    end
    
    storm.net.tcpshutdown(clsock, storm.net.SHUT_RDWR)
end

cord.new(function ()
    storm.net.tcpaddconnectionlost(csock, connection_lost)
    connection_lost(1, csock)
end)

cord.enter_loop()
