require "cord"

-- turn on LED to indicate power is on
storm.io.set_mode(storm.io.OUTPUT, storm.io.GP0)
storm.io.set(1, storm.io.GP0)

my_addr_local = "fe80::212:6d02:0:4021"
my_addr_global = "2001:470:83ae:2:212:6d02:0:4021"

print("Welcome to Chat!")

dst_addr_local = "fe80::212:6d02:0:4019"
dst_addr_global = "2001:470:83ae:2:212:6d02:0:4019"
dst_addr = dst_addr_global 
dst_port = 1019

port = 1019
net_callback = 
function (payload, srcip, srcport) 
    print("\27[31m" .. payload .. "\27[0m")
    print("\27[31mFrom: " .. srcip .. "\27[0m")
    --dst_addr = srcip
end
socket = storm.net.udpsocket(port, net_callback)

send_callback = 
function()
    print("sending to the other end")
    storm.net.sendto(socket, "Hey There", dst_addr, dst_port)
end
storm.os.invokePeriodically(10*storm.os.SECOND, send_callback)

cord.enter_loop()
