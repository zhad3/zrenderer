module luamanager;

import luad.state : LuaState;
import resource : ResourceManager;
import linearalgebra : Vector2;
import config : Gender;

void loadRequiredLuaFiles(ref LuaState L, ResourceManager resManager)
{
    luaLoader("datainfo/accessoryid", resManager, L);
    luaLoader("datainfo/accname", resManager, L);
    luaLoader("datainfo/accname_f", resManager, L);
    luaLoader("datainfo/spriterobeid", resManager, L);
    luaLoader("datainfo/spriterobename", resManager, L);
    luaLoader("datainfo/spriterobename_f", resManager, L);
    luaLoader("datainfo/weapontable", resManager, L);
    luaLoader("datainfo/weapontable_f", resManager, L);
    luaLoader("datainfo/npcidentity", resManager, L);
    luaLoader("datainfo/jobidentity", resManager, L);
    luaLoader("datainfo/jobname", resManager, L);
    luaLoader("datainfo/jobname_f", resManager, L);
    luaLoader("datainfo/shadowtable", resManager, L);
    luaLoader("datainfo/shadowtable_f", resManager, L);
    luaLoader("skillinfoz/jobinheritlist", resManager, L);
    luaLoader("spreditinfo/2dlayerdir_f", resManager, L);
    luaLoader("spreditinfo/biglayerdir_female", resManager, L);
    luaLoader("spreditinfo/biglayerdir_male", resManager, L);
    luaLoader("spreditinfo/_new_2dlayerdir_f", resManager, L);
    luaLoader("spreditinfo/_new_biglayerdir_female", resManager, L);
    luaLoader("spreditinfo/_new_biglayerdir_male", resManager, L);
    luaLoader("spreditinfo/_new_smalllayerdir_female", resManager, L);
    luaLoader("spreditinfo/_new_smalllayerdir_male", resManager, L);
    luaLoader("spreditinfo/smalllayerdir_female", resManager, L);
    luaLoader("spreditinfo/smalllayerdir_male", resManager, L);
    luaLoader("offsetitempos/offsetitempos_f", resManager, L);
    luaLoader("offsetitempos/offsetitempos", resManager, L);
}

import resource.lua : LuaResource;

private void luaLoader(string luaFilename, ResourceManager resManager, ref LuaState L)
{
    auto luaRes = resManager.get!LuaResource(luaFilename);
    luaRes.load();

    import std.exception : enforce;
    import std.format : format;
    import resource : ResourceException;

    enforce!ResourceException(luaRes.usable,
            format("Lua resource (%s) is not usable. This usually happens when " ~
            "the resource has not been loaded yet.", luaRes.name));

    luaRes.loadIntoLuaState(L);
}

float shadowfactor(uint jobid, ref LuaState L)
{
    import luad.lfunction : LuaFunction;

    auto reqShadowFactor = L.get!LuaFunction("ReqshadowFactor");

    float factor = reqShadowFactor.call!float(jobid);

    return factor;
}

auto headgearOffsetForDoram(uint headgear, uint direction, const Gender gender, ref LuaState L)
{
    import luad.lfunction : LuaFunction;
    import luad.base : LuaObject;
    import config : toInt;

    struct Point
    {
        int x;
        int y;
    }

    auto getOffsetForDoram = L.get!LuaFunction("OffsetItemPos_GetOffsetForDoram");

    scope LuaObject[] returnValues = getOffsetForDoram(headgear, direction, gender.toInt());

    if (returnValues.length == 2)
    {
        int x = returnValues[0].isNil() ? 0 : returnValues[0].to!int;
        int y = returnValues[1].isNil() ? 0 : returnValues[1].to!int;
        return Point(x, y);
    }

    return Point.init;
}
