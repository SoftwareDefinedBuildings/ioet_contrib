LCD = require "lcd"

lcd = LCD:new(storm.i2c.INT, 0x7c, storm.i2c.INT, 0xc4)
cord.new(function ()
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
end)

cord.enter_loop()
