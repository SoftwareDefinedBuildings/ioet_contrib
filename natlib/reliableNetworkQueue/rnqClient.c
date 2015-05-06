#include "rnqClient.h"

static const LUA_REG_TYPE rnqclient_meta_map[] = {
    { LSTRKEY("sendMessage"), LFUNCVAL("rnqclient_sendMessage") },
    { LSTRKEY("close"), LFUNCVAL("rnqclient_close") },
    { LNILKEY, LNILVAL },
};

// Not a lua function; meant to be invoked directly
int random(lua_State* L) {
    lua_pushlightfunction(L, libstorm_os_now);
    lua_pushnumber(L, 1);
    lua_call(L, 1, 1);
    int rand =  lua_tonumber(L, -1);
    lua_pop(L, 1);
    return rand;
}

int empty(lua_State* L) {
    return 0;
}

// Expects "self" as an upvalue
int nqclient_receipt_handler(lua_State* L) {
    lua_pushlightfunction(L, libmsgpack_mp_unpack);
    lua_pushvalue(L, 1); // payload
    lua_call(L, 1, 1);
    int unpacked_index = lua_gettop(L);
    int port = luaL_checkint(L, 3);
    lua_pushstring(L, "currPort");
    lua_gettable(L, lua_upvalueindex(1));
    int currPort = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_pushstring(L, "_id");
    lua_gettable(L, unpacked_index);
    int id = lua_tonumber(L, -1);
    lua_pop(L, 1);
    lua_pushstring(L, "currID");
    lua_gettable(L, lua_upvalueindex(1));
    int currID = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_pushstring(L, "pending");
    lua_gettable(L, lua_upvalueindex(1));
    int pending = lua_toboolean(L, -1);
    lua_pop(L, 1);

    if (port == currPort && id == currID && pending) {
	lua_pushstring(L, "pending");
	lua_pushboolean(L, 0);
	lua_settable(L, lua_upvalueindex(1));

	lua_pushstring(L, "currSuccess");
	lua_gettable(L, lua_upvalueindex(1));
	lua_pushvalue(L, unpacked_index);
	lua_pushvalue(L, 2); // ip
	lua_pushvalue(L, 3); // port
	lua_call(L, 3, 0);
    }

    return 0;
}

/* NQClient:new(port) */
int rnqclient_new(lua_State* L) {
    uint32_t port = luaL_checkinteger(L, 1);
    lua_newtable(L); // self
    int self_index = lua_gettop(L);
    lua_pushrotable(L, (void*) rnqclient_meta_map);
    lua_setmetatable(L, -2);

    lua_pushstring(L, "socket");
    lua_pushlightfunction(L, libstorm_net_udpsocket);
    lua_pushnumber(L, port);
    lua_pushvalue(L, self_index);
    lua_pushcclosure(L, nqclient_receipt_handler, 1);
    lua_call(L, 2, 1);
    lua_settable(L, self_index);

    lua_pushstring(L, "currIP");
    lua_pushnil(L);
    lua_settable(L, self_index);

    lua_pushstring(L, "currPort");
    lua_pushnil(L);
    lua_settable(L, self_index);

    lua_pushstring(L, "pending");
    lua_pushboolean(L, 0);
    lua_settable(L, self_index);

    lua_pushstring(L, "ready");
    lua_pushboolean(L, 1);
    lua_settable(L, self_index);

    lua_pushstring(L, "pendingID");
    lua_pushnil(L);
    lua_settable(L, self_index);

    lua_pushstring(L, "currSuccess");
    lua_pushlightfunction(L, empty);
    lua_settable(L, self_index);

    lua_pushstring(L, "queue");
    lua_newtable(L);
    lua_settable(L, self_index);

    lua_pushstring(L, "front");
    lua_pushnumber(L, 1);
    lua_settable(L, self_index);

    lua_pushstring(L, "back");
    lua_pushnumber(L, 1);
    lua_settable(L, self_index);

    lua_pushstring(L, "currID");
    lua_pushnumber(L, random(L));
    lua_settable(L, self_index);

    lua_pushvalue(L, self_index);
    return 1;
}

int rnqclient_processNextFromQueue(lua_State* L);

// NQClient:sendMessage(message, address, port, timesToTry, timeBetweenTries, eachTry, callback)
int rnqclient_sendMessage(lua_State* L) {
    lua_newtable(L);
    int entry_index = lua_gettop(L);
    int i;

    for (i = 2; i < 9; i++) {
	switch (i) {
	case 2:
	    lua_pushstring(L, "msg");
	    break;
	case 3:
	    lua_pushstring(L, "addr");
	    break;
	case 4:
	    lua_pushstring(L, "port");
	    break;
	case 5:
	    lua_pushstring(L, "times");
	    break;
	case 6:
	    lua_pushstring(L, "period");
	    break;
	case 7:
	    lua_pushstring(L, "tcallback");
	    break;
	case 8:
	    lua_pushstring(L, "callback");
	    break;
	}
	if (i >= 7 && lua_isnil(L, i)) {
	    lua_pushlightfunction(L, empty);
	} else {
	    lua_pushvalue(L, i);
	}
	lua_settable(L, entry_index);
    }

    lua_pushstring(L, "queue");
    lua_gettable(L, 1);
    int queue_index = lua_gettop(L);

    lua_pushstring(L, "back");
    lua_gettable(L, 1);
    int back = lua_tointeger(L, -1);
    lua_pushnumber(L, back);
    lua_pushvalue(L, entry_index);
    lua_settable(L, queue_index);

    lua_pushstring(L, "back");
    lua_pushnumber(L, back + 1);
    lua_settable(L, 1);

    lua_pushlightfunction(L, rnqclient_processNextFromQueue);
    lua_pushvalue(L, 1);
    lua_call(L, 1, 0);
    return 0;
}

int rnqclient_poll_send(lua_State* L);
int rnqclient_processNextFromQueue(lua_State* L) {
    lua_pushstring(L, "ready");
    lua_gettable(L, 1);
    int ready = lua_toboolean(L, -1);
    lua_pushstring(L, "pending");
    lua_gettable(L, 1);
    int pending = lua_toboolean(L, -1);
    lua_pop(L, 2);

    if (!ready || pending) {
	return 0;
    }

    lua_pushstring(L, "front");
    lua_gettable(L, 1);
    int front = lua_tointeger(L, -1);
    lua_pushstring(L, "back");
    lua_gettable(L, 1);
    int back = lua_tointeger(L, -1);
    lua_pop(L, 2);

    if (front == back) {
	return 0;
    }

    lua_pushstring(L, "queue");
    lua_gettable(L, 1);
    int queue_index = lua_gettop(L);
    lua_pushnumber(L, front);
    lua_gettable(L, queue_index);
    int req_index = lua_gettop(L);

    lua_pushnumber(L, front);
    lua_pushnil(L);
    lua_settable(L, queue_index);

    lua_pushstring(L, "front");
    lua_pushnumber(L, front + 1);
    lua_settable(L, 1);

    lua_pushstring(L, "currIP");
    lua_pushstring(L, "addr");
    lua_gettable(L, req_index);
    lua_settable(L, 1);

    lua_pushstring(L, "currPort");
    lua_pushstring(L, "port");
    lua_gettable(L, req_index);
    lua_settable(L, 1);

    lua_pushstring(L, "msg");
    lua_gettable(L, req_index);
    int message_index = lua_gettop(L);

    lua_pushstring(L, "_id");
    lua_pushstring(L, "currID");
    lua_gettable(L, 1);
    lua_settable(L, message_index);

    lua_pushlightfunction(L, libmsgpack_mp_pack);
    lua_pushvalue(L, message_index);
    lua_call(L, 1, 1);
    int msg_index = lua_gettop(L);

    lua_pushstring(L, "currSuccess");
    lua_pushstring(L, "callback");
    lua_gettable(L, req_index);
    lua_settable(L, 1);

    lua_pushstring(L, "tcallback");
    lua_gettable(L, req_index);
    int tryCallback_index = lua_gettop(L);

    lua_pushstring(L, "pending");
    lua_pushboolean(L, 1);
    lua_settable(L, 1);

    lua_pushstring(L, "ready");
    lua_pushboolean(L, 0);
    lua_settable(L, 1);

    lua_pushstring(L, "times");
    lua_gettable(L, req_index);
    int timesToTry;

    if (lua_isnil(L, -1)) {
	timesToTry = 1000;
    } else {
	timesToTry = lua_tonumber(L, -1);
    }
    lua_pop(L, 1);

    lua_pushstring(L, "period");
    lua_gettable(L, req_index);
    int timeBetween;

    if (lua_isnil(L, -1)) {
	timeBetween = 50 * MILLISECOND_TICKS;
    } else {
	timeBetween = lua_tonumber(L, -1);
    }
    lua_pop(L, 1);

    lua_createtable(L, 1, 0);
    int table_index = lua_gettop(L);
    lua_pushnumber(L, 1); // the index of the watch in the table
    // Now for the cord part
    lua_pushlightfunction(L, libstorm_os_invoke_periodically);
    lua_pushnumber(L, timeBetween);
    lua_pushvalue(L, 1); // self
    lua_pushvalue(L, tryCallback_index); // tryCallback
    lua_pushnumber(L, timesToTry); // timesToTry
    lua_pushvalue(L, msg_index); // msg
    lua_pushnumber(L, 0); // i
    lua_pushvalue(L, req_index);
    lua_pushvalue(L, table_index); // table containing watch
    lua_pushcclosure(L, rnqclient_poll_send, 7);
    lua_call(L, 2, 1);
    lua_settable(L, table_index); // store watch in table

    return 0;
}

int rnqclient_transaction_handler(lua_State* L);
int rnqclient_poll_send(lua_State* L) {
    int self_index = lua_upvalueindex(1);
    lua_pushstring(L, "pending");
    lua_gettable(L, self_index);
    int pending = lua_toboolean(L, -1);
    lua_pop(L, 1);
    int i = lua_tointeger(L, lua_upvalueindex(5));
    int timesToTry = lua_tointeger(L, lua_upvalueindex(3));
    if (pending && i < timesToTry) {
	lua_pushlightfunction(L, libstorm_net_sendto);
	lua_pushstring(L, "socket");
	lua_gettable(L, self_index);
	lua_pushvalue(L, lua_upvalueindex(4));
	lua_pushstring(L, "currIP");
	lua_gettable(L, self_index);
	lua_pushstring(L, "currPort");
	lua_gettable(L, self_index);
	lua_call(L, 4, 0);
	lua_pushvalue(L, lua_upvalueindex(2));
	lua_call(L, 0, 0);
	lua_pushnumber(L, i + 1);
	lua_replace(L, lua_upvalueindex(5));
    } else {
	lua_pushlightfunction(L, libstorm_os_cancel);
	lua_pushnumber(L, 1);
	lua_gettable(L, lua_upvalueindex(7));
	lua_call(L, 1, 0);

	lua_pushvalue(L, self_index); // self
	lua_pushvalue(L, lua_upvalueindex(6)); // req
	lua_pushcclosure(L, rnqclient_transaction_handler, 2);
	int transaction_handler_index = lua_gettop(L);

	if (pending) {
	    lua_pushlightfunction(L, libstorm_os_invoke_later);
	    lua_pushnumber(L, 500 * MILLISECOND_TICKS);
	    lua_pushvalue(L, transaction_handler_index);
	    lua_call(L, 2, 0);
	} else {
	    lua_call(L, 0, 0);
	}
    }
    return 0;
}

int rnqclient_transaction_handler(lua_State* L) {
    int self_index = lua_upvalueindex(1);
    lua_pushstring(L, "currSuccess");
    lua_pushlightfunction(L, empty);
    lua_settable(L, self_index);

    lua_pushstring(L, "pending");
    lua_gettable(L, self_index);
    int pending = lua_toboolean(L, -1);
    lua_pop(L, 1);

    if (pending) {
	lua_pushstring(L, "pending");
	lua_pushboolean(L, 0); // give up;
	lua_settable(L, self_index);
	lua_pushstring(L, "callback");
	lua_gettable(L, lua_upvalueindex(2));
	lua_pushnil(L);
	lua_pushnil(L);
	lua_pushnil(L);
	lua_call(L, 3, 0);
    }

    lua_pushstring(L, "currID");
    lua_pushnumber(L, random(L));
    lua_settable(L, self_index);

    lua_pushstring(L, "ready");
    lua_pushboolean(L, 1);
    lua_settable(L, self_index);

    lua_pushlightfunction(L, rnqclient_processNextFromQueue);
    lua_pushvalue(L, self_index);
    lua_call(L, 1, 0);

    return 0;
}

int rnqclient_close(lua_State* L) {
    lua_pushlightfunction(L, libstorm_net_close);
    lua_pushstring(L, "socket");
    lua_gettable(L, 1);
    lua_call(L, 1, 0);
    return 0;
}