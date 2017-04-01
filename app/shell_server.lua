require "storm"
require "string"
require "cord"

-- SENDFUNCS maps a socket's FD to a function to send data on that socket
sendfuncs = {}

-- For each socket, we create a cord, which needs to be cancelled if the connection is broken
-- CORDS maps a socket's FD to the cord that is running its interactive session
cords = {}

function do_nothing() end

-- Create server socket
lstnsock = storm.net.tcppassivesocket()

-- Bind socket to port 23
storm.net.tcpbind(lstnsock, 23)

function broadcast(str)
    for k, v in pairs(sendfuncs) do
        v(str)
    end
end

conn_lost_signal = do_nothing

function connection_lost(how, sock)
    local fd = storm.net.tcpfd(sock)
    local c = cords[fd]
    local addr
    local port
    cords[fd] = nil
    sendfuncs[fd] = nil

    cord.cancel(c)

    storm.os.setoutputhook(broadcast)
    addr, port = storm.net.tcppeerinfo(sock)
    print("Client disconnected: " .. addr .. "." .. port)

    storm.net.tcpclose(sock)
    conn_lost_signal() -- signal waiting thread, if any, to start
end

-- Accept incoming connection requests
cord.new(function ()
    local clntsock
    local cfd
    local addr
    local port
    print()
    while true do
        while true do
            storm.os.setoutputhook(broadcast)
            clntsock, _ = cord.await(storm.net.tcplistenaccept, lstnsock, 400)
            storm.os.setoutputhook(broadcast)
            if clntsock == nil then
                -- Wait until a connection is lost
                cord.await(function (cb) conn_lost_signal = cb end)
                conn_lost_signal = do_nothing
            else
		        addr, port = storm.net.tcppeerinfo(clntsock)
		        -- Broadcast a message announcing the arrival of the user
		        print("Client connected: " .. addr .. "." .. port)
		        break
            end
        end
        -- At this point, clntsock is the client socket
        storm.net.tcpaddconnectionlost(clntsock, connection_lost)
        cfd = storm.net.tcpfd(clntsock)
        cords[cfd] = cord.new(function () remote_shell(clntsock) end)
    end
end)

local readchunksize = 100
local SENDBUF_MAX = 800 -- Maximum number of queued bytes to send on any single socket
-- Accept commands from and send output to the remote user
function remote_shell(csock)
    local fd = storm.net.tcpfd(csock)
    if not storm.net.tcpisestablished(csock) then
        cord.await(storm.net.tcpaddconnectdone, csock)
    end
    local maxedbuffer = false
    storm.net.tcpaddsenddone(csock, function (nbytes)
        if maxedbuffer and storm.net.tcpoutstanding(csock) < (SENDBUF_MAX / 2) then
            storm.net.tcpsend(csock, "{ Shell Server: Send buffer is no longer full. }\n")
            maxedbuffer = false
        end
    end)
    local outputhook = function (str)
        local outstanding = storm.net.tcpoutstanding(csock)
        if not maxedbuffer and storm.net.tcpoutstanding(csock) < SENDBUF_MAX then
            storm.net.tcpsend(csock, str)
        elseif not maxedbuffer then
            storm.net.tcpsend(csock, "{ Shell Server: Send buffer full. Dropping characters... }\n")
            maxedbuffer = true
        end
    end
    sendfuncs[fd] = outputhook

    local buf
    local chunk

    storm.net.tcpsend(csock, "\27[34;1mstormsh> \27[0m")

    while true do
        if storm.net.tcphasrcvdfin(csock) then
            storm.net.tcpshutdown(csock, storm.net.SHUT_RDWR)
            cord.await(do_nothing) -- Wait until connection_lost cancels this cord
        end

        storm.os.setoutputhook(broadcast) -- before yielding

        -- Wait until something is in the receive buffer
        buf = cord.await(storm.net.tcprecvfull, csock, 1)

        -- We may have yielded to another cord while waiting, so restore output redirection
        storm.os.setoutputhook(outputhook)

        -- Then empty the receive buffer completely
        repeat
            _, chunk = storm.net.tcprecv(csock, readchunksize)
            buf = buf .. chunk
        until string.len(chunk) ~= readchunksize

        -- Now, buf contains a line of input, so execute it
        storm.os.stormshell(buf)
    end
end

cord.enter_loop()
