REG = require "reg"
string = require "string"

--[[ References: The best documentation I could find about how to
LCD was actually a C++ library for it, at
Seeed-Studio/Grove_LCD_RGB_Backlight. I used the existing code
to figure out what messages I needed to send via I2C to actuate the
self. ]]--


local codes = {
    LCD_CLEARDISPLAY = 0x01,
    --LCD_RETURNHOME = 0x02,
    --LCD_ENTRYMODESET = 0x04,
    LCD_DISPLAYCONTROL = 0x08,
    --LCD_CURSORSHIFT = 0x10,
    LCD_FUNCTIONSET = 0x20,
    --LCD_SETCGRAMADDR = 0x40,
    --LCD_SETDDRAMADDR = 0x80,

    --lags for display entry mode
    --LCD_ENTRYRIGHT = 0x00,
    LCD_ENTRYLEFT = 0x02,
    --LCD_ENTRYSHIFTINCREMENT = 0x01,
    LCD_ENTRYSHIFTDECREMENT = 0x00,

    --lags for display on/off control
    LCD_DISPLAYON = 0x04,
    --LCD_DISPLAYOFF = 0x00,
    LCD_CURSORON = 0x02,
    --LCD_CURSOROFF = 0x00,
    LCD_BLINKON = 0x01,
    --LCD_BLINKOFF = 0x00,

    --flags for display/cursor shift
    --LCD_DISPLAYMOVE = 0x08,
    --LCD_CURSORMOVE = 0x00,
    --LCD_MOVERIGHT = 0x04,
    --LCD_MOVELEFT = 0x00,

    --flags for function set
    LCD_8BITMODE = 0x10,
    --LCD_4BITMODE = 0x00,
    LCD_2LINE = 0x08,
    --LCD_1LINE = 0x00,
    --LCD_5x10DOTS = 0x04,
    LCD_5x8DOTS = 0x00,

    -- flags for communication
    LCD_COMMAND = 0x80,
    LCD_WRITE = 0x40,

    RED_ADDR = 0x04,
    GREEN_ADDR = 0x03,
    BLUE_ADDR = 0x02,

    LED_OUTPUT = 0x08,
}

local LCD = {}


function LCD:command(val, cb)
    self.lcdreg:w(codes.LCD_COMMAND, val, cb)
end

-- Writes a character to the cursor's current position. --
function LCD:write(char, cb)
    self.lcdreg:w(codes.LCD_WRITE, char, cb)
end

function LCD:new(lcd_port, lcd_addr, rgb_port, rgb_addr)
    self.lcdreg = REG:new(lcd_port, lcd_addr)
    self.rgbreg = REG:new(rgb_port, rgb_addr)
    self.red = -1
    self.green = -1
    self.blue = -1
    return self
end

function LCD:init(lines, dotsize, cb)
    self._df = 0
    if lines == 2 then self._df = codes.LCD_2LINE end
    self._df = self._df + codes.LCD_8BITMODE
    self.nl = lines
    self._dc = 0
    self._dm = codes.LCD_ENTRYLEFT + codes.LCD_ENTRYSHIFTDECREMENT;
    self._cl = 0
    if dotsize ~=0 and lines ~= 1 then self._df = bit.bor(self._df, codes.LCD_5x8DOTS) end
    -- seriously, the chip requires this...
    storm.os.invokeLater(200*storm.os.MILLISECOND, function ()
        self:command(codes.LCD_FUNCTIONSET + self._df, function ()
            storm.os.invokeLater(50*storm.os.MILLISECOND, function ()
                self:command(codes.LCD_FUNCTIONSET + self._df, function ()
                    storm.os.invokeLater(50*storm.os.MILLISECOND, function ()
                        self:command(codes.LCD_FUNCTIONSET + self._df, function ()
                            storm.os.invokeLater(50*storm.os.MILLISECOND, function ()
                                self:command(codes.LCD_FUNCTIONSET + self._df, function ()
                                    storm.os.invokeLater(50*storm.os.MILLISECOND, function ()
                                        self:command(0x08, function()
                                            storm.os.invokeLater(50*storm.os.MILLISECOND, function ()
                                                self:command(0x01, function ()
                                                    storm.os.invokeLater(50*storm.os.MILLISECOND, function ()
                                                        self:command(0x6, function ()
                                                            storm.os.invokeLater(200*storm.os.MILLISECOND, function ()
                                                                self._dc  = codes.LCD_DISPLAYON + codes.LCD_CURSORON + codes.LCD_BLINKON
                                                                self:display(function ()
                                                                    storm.os.invokeLater(50*storm.os.MILLISECOND, function ()
                                                                        -- Initialization work for the backlight LED. --
                                                                        self.rgbreg:w(0, 0, function ()
                                                                            self.rgbreg:w(1, 0, function ()
                                                                                self.rgbreg:w(codes.LED_OUTPUT, 0xAA, function ()
                                                                                    cb()
                                                                                end)
                                                                            end)
                                                                        end)
                                                                    end)
                                                                end)
                                                            end)
                                                        end)
                                                    end)
                                                end)
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- Sets the position of the cursor. ROW and COL are 0-indexes --
function LCD:setCursor(row, col, cb)
    if row == 0 then
        col = bit.bor(col, 0x80)
    else
        col = bit.bor(col, 0xc0)
    end
    self:command(col, cb)
end
function LCD:display(cb)
    self._dc = bit.bor(self._dc, codes.LCD_DISPLAYON)
    self:command(codes.LCD_DISPLAYCONTROL + self._dc, cb)
end
function LCD:nodisplay(cb)
    self._dc = bit.bor(self._dc, bit.bnor(codes.LCD_DISPLAYON))
    self:command(codes.LCD_DISPLAYCONTROL + self._dc, cb)
end
-- Erases the screen. --
function LCD:clear(cb)
    self:command(codes.LCD_CLEARDISPLAY, function ()
        storm.os.invokeLater(2*storm.os.MILLISECOND, cb)
    end)
end

-- Writes a string to the LCD display at the cursor. --
function LCD:writeString(str, cb)
    local i = 0
    local writeremaining = nil
    writeremaining = function()
        if i == #str then
            cb()
            return
        end
        i = i + 1
        self:write(string.byte(str:sub(i, i)), writeremaining)
    end
    writeremaining()
end

--[[ Sets the color of the RGB backlight. RED, GREEN, and BLUE
should be integers from 0 to 255. ]]--
function LCD:setBackColor(red, green, blue, cb)
    local result
    if red ~= self.red then
        self.rgbreg:w(codes.RED_ADDR, red, function (result)
            self.red = red
            self:setBackColor(red, green, blue, cb)
        end)
    elseif green ~= self.green then
        self.rgbreg:w(codes.GREEN_ADDR, green, function (result)
            self.green = green
            self:setBackColor(red, green, blue, cb)
        end)
    elseif blue ~= self.blue then
        self.rgbreg:w(codes.BLUE_ADDR, blue, function (result)
            self.blue = blue
            self:setBackColor(red, green, blue, cb)
        end)
    else
        cb()
    end
end

return LCD
