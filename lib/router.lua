function delete_routes()
    local t = storm.os.gettable()

    local routes = {}
    local k
    local route_ent
    for k, route_ent in pairs(t) do
        table.insert(routes, route_ent.route_key)
    end

    local route_key
    for k, route_key in pairs(routes) do
        print(route_key)
        storm.os.delroute(route_key)
    end
end


function setup_route(from, to)

    local rv

    rv = storm.os.addroute(from, 128, to, storm.os.ROUTE_IFACE_154)
    if rv <= 0 then
        print("Route setup failed")
    end

end
