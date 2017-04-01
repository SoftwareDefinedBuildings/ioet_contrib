require "storm"
require "string"
require "cord"
tcpstr = require "tcpstr"

-- Create server socket
lstnsock = storm.net.tcppassivesocket()

-- Bind socket to port 32067
storm.net.tcpbind(lstnsock, 32067)

-- No call to listen() is needed
cord.new(function ()
    while true do
        clntsock = cord.await(storm.net.tcplistenaccept, lstnsock, 3000)
        if clntsock ~= nil then
            cord.new(function () server(clntsock) end)
        else
            cord.yield()
        end
    end
end)

-- Function to perform interaction with client
function server(csock)
    cord.await(storm.net.tcpaddconnectdone, csock)
    resp = tcpstr:send_string(csock, long_string_1)
    print("Got response: " .. resp)
    resp = tcpstr:send_string(csock, long_string_2)
    print("Got response: " .. resp)
    resp = tcpstr:send_string(csock, "")
    print("Got response: " .. resp)
    local string = nil
    while string ~= "" do
        string = tcpstr:recv_string(csock)
        print_string(string)
    end
    
    storm.net.tcpshutdown(csock, storm.net.SHUT_RDWR)
    how = cord.await(storm.net.tcpaddconnectionlost, csock)
    print("Connection ended. Reason: " .. how)
    storm.net.tcpclose(csock)
end

local stepsize = 80
function print_string(str)
    local length = string.len(str)
    for i = 1, length, stepsize do
        print(string.sub(str, i, i + stepsize - 1))
    end
end

long_string_1 = "The Transmission Control Protocol (TCP) is a core protocol of the Internet protocol suite. It originated in the initial network implementation in which it complemented the Internet Protocol (IP). Therefore, the entire suite is commonly referred to as TCP/IP. TCP provides reliable, ordered, and error-checked delivery of a stream of octets between applications running on hosts communicating over an IP network. TCP is the protocol that major Internet applications such as the World Wide Web, email, remote administration and file transfer rely on. Applications that do not require reliable data stream service may use the User Datagram Protocol (UDP), which provides a connectionless datagram service that emphasizes reduced latency over reliability."

long_string_2 = "6LoWPAN is an acronym of IPv6 over Low power Wireless Personal Area Networks. 6LoWPAN is the name of a concluded working group in the Internet area of the IETF.\nThe 6LoWPAN concept originated from the idea that \"the Internet Protocol could and should be applied even to the smallest devices,\" and that low-power devices with limited processing capabilities should be able to participate in the Internet of Things.\nThe 6LoWPAN group has defined encapsulation and header compression mechanisms that allow IPv6 packets to be sent and received over IEEE 802.15.4 based networks. IPv4 and IPv6 are the work horses for data delivery for local-area networks, metropolitan area networks, and wide-area networks such as the Internet. Likewise, IEEE 802.15.4 devices provide sensing communication-ability in the wireless domain. The inherent natures of the two networks though, are different."

cord.enter_loop()
