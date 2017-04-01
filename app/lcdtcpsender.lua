require "storm"
require "string"
require "cord"
require "router"

-- require "math"

-- server_ip = "2607:f140:400:a008:b99e:79bc:7043:f580"
server_ip = "fe80::0212:6d02:0000:4001"
-- server_ip = "2001:0470:83ae:2:0212:6d02:0000:401c"
-- server_ip = "2001:470:83ae:2:0212:6d02:0000:3033"
-- server_ip = "2001:470:1f04:5f2::2"
server_port = 4000

-- Create active socket
csock = storm.net.tcpactivesocket()

-- Bind socket to port 1024
storm.net.tcpbind(csock, 1024)

LENGTH = 3510

sendbufsize = 79872

prevcord = nil
function connection_lost(how, socket)
    --[[delete_routes()
    --setup_route("fe80::212:6d02:0:401c", "fe80::212:6d02:0:4001")
    for k, v in pairs(storm.os.gettable()) do
        for i, v2 in pairs(v) do
            print(i, v2)
        end
    end]]--
    if how ~= 0 then -- connection broken
        print("WARNING: connection broken")
        if prevcord ~= nil then
            cord.cancel(prevcord) -- connect failed, so stop this cord
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

local trial = 0

function tryconnect(clsock)
    cord.await(storm.net.tcpconnect, clsock, server_ip, server_port, 3000)

    --storm.os.invokePeriodically(storm.os.SECOND, function () print(storm.net.tcpstats(clsock)) end)

    while true do
        cord.await(storm.net.tcpsendwithmax, clsock, twokilobytes, sendbufsize)
    end

    storm.net.tcpshutdown(clsock, storm.net.SHUT_RDWR)
end

cord.new(function ()
    storm.net.tcpaddconnectionlost(csock, connection_lost)
    connection_lost(1, csock)
end)

local stepsize = 80
function print_string(str)
    local length = string.len(str)
    for i = 1, length, stepsize do
        print(string.sub(str, i, i + stepsize - 1))
    end
end


twokilobytes = "The Internet is the global system of interconnected computer networks that use the Internet protocol suite (TCP/IP) to link billions of devices worldwide. It is a network of networks that consists of millions of private, public, academic, business, and government networks of local to global scope, linked by a broad array of electronic, wireless, and optical networking technologies. The Internet carries an extensive range of information resources and services, such as the inter-linked hypertext documents and applications of the World Wide Web (WWW), electronic mail, telephony, and peer-to-peer networks for file sharing.\nAlthough the Internet protocol suite has been widely used by academia and the military industrial complex since the early 1980s, events of the late 1980s and 1990s such as more powerful and affordable computers, the advent of fiber optics, the popularization of HTTP and the Web browser, and a push towards opening the technology to commerce eventually incorporated its services and technologies into virtually every aspect of contemporary life.\nThe impact of the Internet has been so immense that it has been referred to as the '8th continent'.\nThe origins of the Internet date back to research and development commissioned by the United States government, the Government of the UK and France in the 1960s to build robust, fault-tolerant communication via computer networks. This work, led to the primary precursor networks, the ARPANET, in the United States, the Mark 1 NPL network in the United Kingdom and CYCLADES in France. The interconnection of regional academic networks in the 1980s marks the beginning of the transition to the modern Internet. From the late 1980s onward, the network experienced sustained exponential growth as generations of institutional, personal, and mobile computers were connected to it.\nInternet use grew rapidly in the West from the mid-1990s and from the late 1990s in the developing world. In the 20 years since 1995, Internet use has grown 100-times, measured for the period of one "
cord.enter_loop()
