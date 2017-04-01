/**
 * This file defines the contrib native C functions. You can access these as
 * storm.n.<function>
 * for example storm.n.hello()
 */

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "lrotable.h"
#include "auxmods.h"
#include <platform_generic.h>
#include <string.h>
#include <stdint.h>
#include <interface.h>
#include <stdlib.h>
#include <libstorm.h>

/**
 * This is required for the LTR patch that puts module tables
 * in ROM
 */
#define MIN_OPT_LEVEL 2
#include "lrodefs.h"

//Include some libs as C files into this file
#include "natlib/util.c"
#include "natlib/svcd.c"
#include "natlib/analog/analog.c"

#include "natlib/reliableNetworkQueue/rnq.c"

// #include "natlib/chair/chaircontrol.c"
// #include "natlib/chair/blchair.c"
// #include "natlib/chair/flash.c"
// #include "natlib/chair/receiver.c"
#include "natlib/neopixel.c"


////////////////// BEGIN FUNCTIONS /////////////////////////////

int contrib_fourth_root_m1000(lua_State *L) //mandatory signature
{
    //Get param 1 from top of stack
    double val = (double) luaL_checknumber(L, 1);

    int i;
    double guess = val / 2;
    double step = val / 4;
    for (i=0;i<20;i++)
    {
        if (guess*guess*guess*guess > val)
            guess -= step;
        else
            guess += step;
        step = step / 2;
    }

    //push back a *1000 fixed point
    lua_pushnumber(L, (int)(guess*1000));
    return 1; //one return value
}


int contrib_run_foobar(lua_State *L)
{
    //Load a symbol "foobar" from global table
    lua_getglobal(L, "foobar"); //this is TOS now
    lua_pushnumber(L, 3); //arg1
    lua_pushnumber(L, 5); //arg2
    lua_call(L, /*args=*/ 2, /*retvals=*/ 1);
    int rv = lua_tonumber(L, -1); //-1 is TOS
    printf("from C, rv is=%d\n", rv);
    return 0; //no return values
}

int contrib_run_run_foobar(lua_State *L)
{
    //Load the contrib_run_foobar symbol
    //Could also have got this by loading global storm table
    //then loading the .n key, then getting the value

    //Note that pushlightfunction is eLua specific
    lua_pushlightfunction(L, contrib_run_foobar);
    lua_call(L, 0, 0);
    return 0;
}

int counter(lua_State *L)
{
    int val = lua_tonumber(L, lua_upvalueindex(1));
    val++;

    //Set upvalue (closure variable)
    lua_pushnumber(L, val);
    lua_replace(L, lua_upvalueindex(1));

    //return it too
    lua_pushnumber(L, val);
    return 1;
}

int contrib_makecounter(lua_State *L)
{
    lua_pushnumber(L, 0); //initial val
    lua_pushcclosure(L, &counter, 1);
    return 1; //return the closure
}

/**
 * Prints out hello world
 *
 * Lua signature: hello() -> nil
 * Maintainer: Michael Andersen <m.andersen@cs.berkeley.edu>
 */
static int contrib_hello(lua_State *L)
{
    printf("Hello world\n");
    // The number of return values
    return 0;
}

/**
 * Prints out hello world N times, X ticks apart
 *
 * N >= 1
 * Lua signature: helloX(N,X) -> 42
 * Maintainer: Michael Andersen <m.andersen@cs.berkeley.edu>
 */
static int contrib_helloX_tail(lua_State *L);
static int contrib_helloX_entry(lua_State *L)
{
    //First run of the loop, lets configure N and X
    int N = luaL_checknumber(L, 1);
    int X = luaL_checknumber(L, 2);
    int loopcounter = 0;

    //Do our job
    printf ("Hello world\n");

    //We already have these on the top of the stack, but this is
    //how you would push variables you want access to in the continuation
    //Also counting down would be more efficient, but this is an example
    lua_pushnumber(L, loopcounter + 1);
    lua_pushnumber(L, N);
    lua_pushnumber(L, X);
    //Now we want to sleep, and when we are done, invoke helloX_tail with
    //the top 3 values of the stack available as upvalues
    cord_set_continuation(L, contrib_helloX_tail, 3);
    return nc_invoke_sleep(L, X);

    //We can't do anything after a cord_invoke_* call, ever!
}
static int contrib_helloX_tail(lua_State *L)
{
    //Grab our upvalues (state passed to us from the previous func)
    int loopcounter = lua_tonumber(L, lua_upvalueindex(1));
    int N = lua_tonumber(L, lua_upvalueindex(2));
    int X = lua_tonumber(L, lua_upvalueindex(3));

    //Do our job with them
    if (loopcounter < N)
    {
        printf ("Hello world\n");
        //Again, an example, these are already at the top of
        //the stack
        lua_pushnumber(L, loopcounter + 1);
        lua_pushnumber(L, N);
        lua_pushnumber(L, X);
        cord_set_continuation(L, contrib_helloX_tail, 3);
        return nc_invoke_sleep(L, X);
    }
    else
    {
        //Base case, now we do our return
        //We promised to return the number 42
        lua_pushnumber(L, 42);
        return cord_return(L, 1);
    }
}

int bytesread = 0;

static int contrib_tcp_demo_get_kbits_read_and_reset(lua_State* L) {
    int kbitsread = (bytesread << 3) / 1000;
    bytesread = 0;
    lua_pushnumber(L, kbitsread);
    return 1;
}

static int contrib_tcp_demo_recvforever(lua_State* L) {
    lua_pushlightfunction(L, libstorm_net_tcprecvfull);
    lua_pushvalue(L, lua_upvalueindex(1)); // csock
    lua_pushnumber(L, 256);
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_pushcclosure(L, contrib_tcp_demo_recvforever, 1);
    lua_call(L, 3, 0);
    bytesread += 256;
    return 0;
}

static int contrib_tcp_demo_on_data(lua_State* L) {
    while (1) {
        lua_pushlightfunction(L, libstorm_net_tcprecv);
        lua_pushvalue(L, lua_upvalueindex(1));
        lua_pushnumber(L, 256);
        lua_call(L, 2, 2);

        int len = lua_objlen(L, -1);
        lua_pop(L, 1); // we're in a loop, so make stack flat
        bytesread += len;
        if (len != 256) {
            return 0;
        }
    }
    return 0;
}

static int contrib_tcp_demo_on_accept(lua_State* L) {
    //csock is top of stack
    if (lua_isnil(L, -1)) {
        return 0;
    }

    //csock is top of stack
    printf("Accepted connection\n");
    /*lua_pushlightfunction(L, libstorm_net_tcpaddconnectdone);
    lua_pushvalue(L, 1);
    lua_pushvalue(L, 1);
    lua_pushcclosure(L, contrib_tcp_demo_recvforever, 1);
    lua_call(L, 2, 0);*/

    lua_pushlightfunction(L, libstorm_net_tcpaddrecvready);
    lua_pushvalue(L, 1);
    lua_pushvalue(L, 1);
    lua_pushcclosure(L, contrib_tcp_demo_on_data, 1);
    lua_call(L, 2, 0);
    return 0;
}

static int contrib_tcp_demo(lua_State* L) {
    lua_pushlightfunction(L, libstorm_net_tcppassivesocket);
    lua_call(L, 0, 1);
    //passive socket is top of stack
    lua_pushlightfunction(L, libstorm_net_tcpbind);
    lua_pushvalue(L, -2);
    lua_pushnumber(L, 4000);
    lua_call(L, 2, 0);
    //passive socket it still top of stack
    lua_pushlightfunction(L, libstorm_net_tcplistenaccept);
    lua_pushvalue(L, -2);
    lua_pushnumber(L, 2500); // receive buffer
    lua_pushlightfunction(L, contrib_tcp_demo_on_accept);
    lua_call(L, 3, 0);
    return 0;
}

////////////////// BEGIN MODULE MAP /////////////////////////////
const LUA_REG_TYPE contrib_native_map[] =
{
    { LSTRKEY( "hello" ), LFUNCVAL ( contrib_hello ) },
    { LSTRKEY( "helloX" ), LFUNCVAL ( contrib_helloX_entry ) },
    { LSTRKEY( "fourth_root"), LFUNCVAL ( contrib_fourth_root_m1000 ) },
    { LSTRKEY( "run_foobar"), LFUNCVAL ( contrib_run_foobar ) },
    { LSTRKEY( "makecounter"), LFUNCVAL ( contrib_makecounter ) },

    SVCD_SYMBOLS
    //CHAIRCONTROL_SYMBOLS
    //I2CCHAIR_SYMBOLS
    //BLCHAIR_SYMBOLS
    //FLASH_SYMBOLS
    //RECEIVER_SYMBOLS
    ADCIFE_SYMBOLS
    RNQ_SYMBOLS
    //NEOPIXEL_SYMBOLS

    /* Constants for the Temp sensor. */
    // -- Register address --
    { LSTRKEY( "TMP006_VOLTAGE" ), LNUMVAL(0x00)},
    { LSTRKEY( "TMP006_LOCAL_TEMP" ), LNUMVAL(0x01)},
    { LSTRKEY( "TMP006_CONFIG" ), LNUMVAL(0x02)},
    { LSTRKEY( "TMP006_MFG_ID" ), LNUMVAL(0xFE)},
    { LSTRKEY( "TMP006_DEVICE_ID" ), LNUMVAL(0xFF)},

    // -- Config register values
    { LSTRKEY( "TMP006_CFG_RESET" ), LNUMVAL(0x80)},
    { LSTRKEY( "TMP006_CFG_MODEON" ), LNUMVAL(0x70)},
    { LSTRKEY( "TMP006_CFG_1SAMPLE" ), LNUMVAL(0x00)},
    { LSTRKEY( "TMP006_CFG_2SAMPLE" ), LNUMVAL(0x02)},
    { LSTRKEY( "TMP006_CFG_4SAMPLE" ), LNUMVAL(0x04)},
    { LSTRKEY( "TMP006_CFG_8SAMPLE" ), LNUMVAL(0x06)},
    { LSTRKEY( "TMP006_CFG_16SAMPLE" ), LNUMVAL(0x08)},
    { LSTRKEY( "TMP006_CFG_DRDYEN" ), LNUMVAL(0x01)},
    { LSTRKEY( "TMP006_CFG_DRDY" ), LNUMVAL(0x80)},

    { LSTRKEY( "tcpGetKbitsReset"), LFUNCVAL(contrib_tcp_demo_get_kbits_read_and_reset)},
    { LSTRKEY( "tcpDemo" ), LFUNCVAL(contrib_tcp_demo)},

    //The list must end with this
    { LNILKEY, LNILVAL }
};
