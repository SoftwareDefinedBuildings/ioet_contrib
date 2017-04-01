
--[[
function scan_i2c(port)
    for i = 0x00, 0xFE, 2 do
        local arr = storm.array.create(1, storm.array.UINT8)
        local rv = cord.await(storm.i2c.read, port + i, storm.i2c.START + storm.i2c.STOP, arr)
        if rv == storm.i2c.OK then
            print(string.format("Device found at 0x%02x", i))
        end
    end
end
]]--

function scan_i2c_async(port)
    local arr = storm.array.create(1, storm.array.UINT8)
    local i = 0x00
    local scan_and_inc = nil
    scan_and_inc = function ()
        print(i)
        storm.i2c.read(port + i, storm.i2c.START + storm.i2c.STOP, arr, function (rv)
            if rv == storm.i2c.OK then
                print(string.format("Device found at 0x%02x", i))
            end

            -- Increment if it's needed
            if i == 0xFE then
                return
            else
                i = i + 2
                scan_and_inc()
            end
        end)
    end
    scan_and_inc()
end

return scan_i2c_async
