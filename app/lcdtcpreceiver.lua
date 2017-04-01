require "storm"
LCD = require "lcd"
--require "cord"

--require "router"
--[[
-- Create server socket
lstnsock = storm.net.tcppassivesocket()

-- Bind socket to port 4000
storm.net.tcpbind(lstnsock, 4000)

bytesread = 0

-- No call to listen() is needed
storm.net.tcplistenaccept(lstnsock, 2000, function (csock)
    if csock ~= nil then
        print("Accepted connection")
        recvforever = function()
            storm.net.tcprecvfull(csock, 256, recvforever)
            bytesread = bytesread + 256
        end
        storm.net.tcpaddconnectdone(csock, recvforever)
    end
end)
]]

storm.n.tcpDemo()

-- Separate cord for LCD stuff
lcd = LCD:new(storm.i2c.INT, 0x7c, storm.i2c.INT, 0xc4)
lcd:init(2, 1, function ()
    lcd:setBackColor(255, 255, 255, function ()
        lcd:writeString("Sam's TCP Demo", function ()
            lcd:setCursor(1, 0, function()
                lcd:writeString("Goodput: ", function ()
                    storm.os.invokePeriodically(storm.os.SECOND, function()
                        collectgarbage()
                        lcd:setCursor(1, 9, function()
                            local kbs = storm.n.tcpGetKbitsReset()
                            lcd:writeString(kbs .. " kb/s ", function()
                                local gb = kbs * 2
                                if gb > 255 then gb = 255 end
                                lcd:setBackColor(255, gb, gb, function() end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)
--[[cord.new(function ()
    lcd:init(2, 1)
    lcd:writeString("THE INTERNET OF")
    lcd:setCursor(1, 0)
    lcd:writeString("THINGS, Spr '15")
    while true do
        lcd:setBackColor(255, 255, 0)
        cord.await(storm.os.invokeLater, storm.os.SECOND)
        lcd:setBackColor(0, 255, 0)
        cord.await(storm.os.invokeLater, storm.os.SECOND)
        lcd:setBackColor(255, 255, 255)
        cord.await(storm.os.invokeLater, storm.os.SECOND)
    end
end)]]

while true do
    storm.os.wait_callback()
end
