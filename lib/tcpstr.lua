local STR = {}

-- Protocol for sending a string over TCP
function STR:send_string(sock, string)
    local data
    local err
    local strlen = string.len(string)
    cord.await(storm.net.tcpsendfull, sock, string.format("%04d", strlen))
    if strlen ~= 0 then
        cord.await(storm.net.tcpsendfull, sock, string)
    end
    data, err = cord.await(storm.net.tcprecvfull, sock, 2)
    return data
end

-- Protocol for receiving a string over TCP
function STR:recv_string(sock)
    local data
    local err
    data, err = cord.await(storm.net.tcprecvfull, sock, 4)
    local strlen = tonumber(data)
    if strlen == 0 then
        data = ""
        err = 0
    else
        data, err = cord.await(storm.net.tcprecvfull, sock, strlen)
    end
    cord.await(storm.net.tcpsendfull, sock, "ok")
    return data
end

return STR
