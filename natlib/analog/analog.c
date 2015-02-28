
#include "adcife.h"

#define ADCIFE_SYMBOLS \
    { LSTRKEY( "adcife_init"), LFUNCVAL ( adcife_init ) }, \
    { LSTRKEY( "adcife_new"), LFUNCVAL ( adcife_new ) }, \
    { LSTRKEY( "adcife_sample_an0"), LFUNCVAL ( adcife_sample_an0 ) },


/* The analog pins on the firestorm go through several layers of translation
 * before you get to the channel numbers that are expected for the analog
 * peripheral. This maps the firestorm channel number to the MPU channel
 * number
 */
static const int chanmap [] = {
    6, //A0 maps to AN5 on storm which is AD6 on MPU
    5, //A1 maps to AN4 on storm which is AD5 on MPU
    4, //A2 maps to AN3 on storm which is AD4 on MPU
    3, //A3 maps to AN2 on storm which is AD3 on MPU
    2, //A4 maps to AN1 on storm which is AD2 on MPU
    1  //A5 maps to AN0 on storm which is AD1 on MPU
};

//////////////////////////////////////////////////////////////////////////////
// ADCIFE init implementation
// Initialises the module, but does not create any channels
// Maintainer: Michael Andersen <michael@steelcode.com>
/////////////////////////////////////////////////////////////

//Pure C functions
void c_adcife_init()
{
    //Still debugging the huge noise on the conversions
    //Hence duplicated code and weird delays here

    //Reset the ADCIFE so that we can apply any configuration changes
    //use APB clock
    ADCIFE->cfg.bits.clksel = 1;
    //The APB clock is at 48Mhz, we need it to be below 1.8 Mhz. /64 gets us closest
    ADCIFE->cfg.bits.prescal = 7;//0b100;
    //Set speed for 300ksps
    ADCIFE->cfg.bits.speed = 0b00;
    //Set the reference to be the external AREF pin
    ADCIFE->cfg.bits.refsel = 0b010;

    {
        int i;
        for (i=0;i<10000;i++);
    }
    ADCIFE->cr.bits.swrst = 1;
    ADCIFE->cr.bits.refbufen = 1;
    ADCIFE->cr.bits.bgreqen = 1;
    ADCIFE->tim = 0x11f;
    //Enable the ADC
    ADCIFE->cr.bits.en = 1;
    //Wait for it to be enabled
    while(!ADCIFE->sr.bits.en)
    {
        printf("waiting for enabled, sr is %d\n", ADCIFE->sr.flat);
    }
    {
        int i;
        for (i=0;i<10000;i++);
    }
        //use APB clock
    ADCIFE->cfg.bits.clksel = 1;
    //The APB clock is at 48Mhz, we need it to be below 1.8 Mhz. /64 gets us closest
    ADCIFE->cfg.bits.prescal = 7;//0b100;
    //Set speed for 300ksps
    ADCIFE->cfg.bits.speed = 0b00;
    //Set the reference to be the external AREF pin
    ADCIFE->cfg.bits.refsel = 0b010;
    ADCIFE->cr.bits.refbufen = 1;
    ADCIFE->cr.bits.bgreqen = 1;
    ADCIFE->tim = 0x11f;
    //ADCIFE->calib = 0x00007007;
    printf("SR POST ENABLE: %x\n", ADCIFE->sr);
        //Configure to FS_AN0
    adcife_seqcfg_t seqcfg;
        ADCIFE->scr.bits.seoc = 1;

    seqcfg.flat = 0;
    seqcfg.bits.muxpos = chanmap[0];
    seqcfg.bits.gcomp = 0;
    seqcfg.bits.bipolar = 1;
    seqcfg.bits.internal = 0b10;
    seqcfg.bits.muxneg = 0b011; //gnd
    seqcfg.bits.gain = 0;
    ADCIFE->seqcfg.flat = seqcfg.flat;
}

int c_adcife_sample_an0()
{

    //Clear conversion flag

    //Start the conversion
    ADCIFE->cr.bits.strig = 1;
    while(!ADCIFE->sr.bits.seoc){
        printf("waited\n");
    }
    return ADCIFE->lcv.bits.lcv;
}

//Lua: storm.n.adcife_init()
int adcife_init(lua_State *L)
{
    c_adcife_init();
    return 0;
}

int adcife_sample_an0(lua_State *L)
{
    int sample = c_adcife_sample_an0();
    lua_pushnumber(L, sample);
    return 1;
}

//Lua: storm.n.adcife_new(poschan, negchan, gain, resolution)
int adcife_new(lua_State *L)
{
    return 0;
}