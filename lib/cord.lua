-------------------------------------
-- CORoutine Daemon (CORD)
-- this implements scheduled fibers
-------------------------------------

cord = {}

cord._coidx = 1
cord._activeidx = 1
cord._cors    = {}
cord._PROMISE = 1
cord._NORMAL  = 2
-- status a cord can be in
cord._READY   = 3
cord._AWAIT   = 4
cord._PROMISEDONE = 5

cord.new = function (f)
    local co = coroutine.create(f)
    cord._cors[cord._coidx] = {c=co,s=cord._READY }
    local handle = cord._coidx
    cord._coidx = cord._coidx + 1
    return handle
end

cord.await = function(f, ...)
    cord._cors[cord._activeidx].s = cord._AWAIT
    cord._cors[cord._activeidx].rv=nil
    local aidx = cord._activeidx
    local args = {...}
    args[#args+1] = function (...)
        if cord._cors[aidx] ~= nil then
            cord._cors[aidx].s=cord._PROMISEDONE
            cord._cors[aidx].rv={... }
        end
    end
    f(unpack(args))
    return coroutine.yield()
end

cord.enter_loop = function ()
    while true do
        local ro = false
        local s
        for i,v in pairs(cord._cors) do
            if v.k then
                cord._cors[i] = nil
            elseif v.s == cord._READY or v.s == cord._PROMISEDONE then
                ro = true
                cord._activeidx = i
                v.s = cord._READY
                if v.rv ~= nil then
                    s, v.t, v.x, v.a = coroutine.resume(v.c,unpack(v.rv))
                else
                    s, v.t, v.x, v.a = coroutine.resume(v.c)
                end
                if not s then
                    print (v.t)
                end
                if (coroutine.status(v.c) == "dead" or v.k) then
                    cord._cors[i] = nil
                end
            end
        end
        collectgarbage("collect")
        if ro then
            storm.os.run_callback()
        else
            storm.os.wait_callback() -- go to sleep
        end
    end
end

cord.nc = function(f, ...)
    local c = cord._cors[cord._activeidx]
    f(...) -- call the head function
    while c.t ~= nil do --while there is a tail function
        local t = c.t
        if t == -1 then
            return unpack(c.x)
        end
        --if there is a target function, call it
        local r = {}
        if c.x then
            r = {c.x(unpack(c.a))} --call it
        end
        t(unpack(r))
    end
end

cord.ncw = function(f)
    return function(...) cord.nc(f, unpack({...})) end
end

cord.yield = function()
    coroutine.yield()
end

cord.cancel = function(handle)
    cord._cors[handle].k = true
end
