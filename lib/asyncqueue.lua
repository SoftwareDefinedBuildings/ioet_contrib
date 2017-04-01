-- For each socket, we need a queue of messages to send
-- QUEUES maps a socket's FD to a queue of messages
local AQUEUE = {}

-- Creates a queue of items to be processed by the asynchronous function ACTION.
-- ACTION must take two arguments: (1) the item to be processed, and (2) a callback that is invoked once it is processed.
function AQUEUE:new(cb)
    local obj = { first = 1, last = 0, action = cb, processing = false }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Invokes the queue's callback on the specified item, and then processes the next element.
-- For internal use by the queue.
function AQUEUE:_processqueue(item)
    self.processing = true
    self.action(item, function ()
        self.processing = false
        self:_checkqueue()
    end)
end

-- Processes the next element in the queue (if any) and then processes it.
-- For internal use by the queue.
function AQUEUE:_checkqueue()
    if self.first <= self.last then
        local item = self[self.first]
        self[self.first] = nil
        if self.first == self.last then
            self:reset()
        else
            self.first = self.first + 1
        end
        self:_processqueue(item)
    end
end

-- Adds a new item to the queue. If the queue is empty, it will be processed immediately.
function AQUEUE:enqueue(item)
    if not self.processing then
        assert(self.first > self.last, "Nonempty queue is not processing")
        assert(self.first == 1 and self.last == 0, "Nonempty queue is not reset")
        self:_processqueue(item)
    else
        self.last = self.last + 1
        self[self.last] = item
    end
end

-- Empties the queue of all pending items and resets the indices
function AQUEUE:reset()
    self.first = 1
    self.last = 0
end
    

return AQUEUE
