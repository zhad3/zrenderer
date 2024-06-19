module luamanager;

import std.typecons : Flag, No, Yes;
import luad.state : LuaState;
import resource : ResourceManager;
import linearalgebra : Vector2;
import logging : LogLevel, LogDg;
import config : Gender;

bool[string] luaFunctionAvailability;

void loadRequiredLuaFiles(ref LuaState L, ResourceManager resManager, LogDg log)
{
    luaFunctionAvailability = [
        "ReqshadowFactor": true,
        "OffsetItemPos_GetOffsetForDoram": true,
        "ReqJobName": true,
        "ReqWeaponName": true,
        "GetRealWeaponId": true,
        "ReqAccName": true,
        "ReqRobSprName_V2": true,
        "_New_DrawOnTop": true,
        "IsTopLayer": true
    ];

    luaLoader("datainfo/accessoryid", resManager, L, log);
    luaLoader("datainfo/accname", resManager, L, log);
    luaLoader("datainfo/accname_f", resManager, L, log);
    luaLoader("datainfo/spriterobeid", resManager, L, log);
    luaLoader("datainfo/spriterobename", resManager, L, log);
    luaLoader("datainfo/spriterobename_f", resManager, L, log);
    luaLoader("datainfo/weapontable", resManager, L, log);
    luaLoader("datainfo/weapontable_f", resManager, L, log);
    luaLoader("datainfo/npcidentity", resManager, L, log);
    luaLoader("datainfo/jobidentity", resManager, L, log);
    luaLoader("datainfo/jobname", resManager, L, log);
    luaLoader("datainfo/jobname_f", resManager, L, log);
    luaLoader("datainfo/shadowtable", resManager, L, log, Yes.optional);
    luaLoader("datainfo/shadowtable_f", resManager, L, log, Yes.optional);
    luaLoader("skillinfoz/jobinheritlist", resManager, L, log);
    luaLoader("spreditinfo/2dlayerdir_f", resManager, L, log);
    luaLoader("spreditinfo/biglayerdir_female", resManager, L, log);
    luaLoader("spreditinfo/biglayerdir_male", resManager, L, log);
    luaLoader("spreditinfo/_new_2dlayerdir_f", resManager, L, log);
    luaLoader("spreditinfo/_new_biglayerdir_female", resManager, L, log);
    luaLoader("spreditinfo/_new_biglayerdir_male", resManager, L, log);
    luaLoader("spreditinfo/_new_smalllayerdir_female", resManager, L, log);
    luaLoader("spreditinfo/_new_smalllayerdir_male", resManager, L, log);
    luaLoader("spreditinfo/smalllayerdir_female", resManager, L, log);
    luaLoader("spreditinfo/smalllayerdir_male", resManager, L, log);
    luaLoader("offsetitempos/offsetitempos_f", resManager, L, log);
    luaLoader("offsetitempos/offsetitempos", resManager, L, log);

    import luad.error : LuaErrorException;
    import luad.lfunction : LuaFunction;
    import std.format : format;

    foreach (functionName; luaFunctionAvailability.keys)
    {
        try
        {
            L.get!LuaFunction(functionName);
        }
        catch (LuaErrorException err)
        {
            log(LogLevel.info, format("Lua function \"%s\" is not available. Rendered output might not be correct", functionName));
            luaFunctionAvailability[functionName] = false;
        }
    }
}

import resource.lua : LuaResource;

private void luaLoader(string luaFilename, ResourceManager resManager, ref LuaState L, LogDg log, Flag!"optional" optional = No.optional)
{
    import resource : ResourceException;
    try
    {
        auto luaRes = resManager.get!LuaResource(luaFilename);
        luaRes.load();

        import std.exception : enforce;
        import std.format : format;

        enforce!ResourceException(luaRes.usable,
                format("Lua resource (%s) is not usable. This usually happens when " ~
                "the resource has not been loaded yet.", luaRes.name));

        luaRes.loadIntoLuaState(L);
    }
    catch (ResourceException err)
    {
        if (optional)
        {
            log(LogLevel.info, err.msg);
        }
        else
        {
            throw err;
        }
    }
}

T executeLuaFunctionOrElse(T, U...)(ref LuaState L, string functionName, T fallback, U args)
{
    bool* available = functionName in luaFunctionAvailability;

    if (available is null || !(*available))
    {
        return fallback;
    }

    import luad.lfunction : LuaFunction;

    auto func = L.get!LuaFunction(functionName);
    return func.call!(T)(args);
}

float shadowfactor(uint jobid, ref LuaState L)
{
    return executeLuaFunctionOrElse(L, "ReqshadowFactor", 1, jobid);
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

    bool* available = "OffsetItemPos_GetOffsetForDoram" in luaFunctionAvailability;
    if (available is null || !(*available))
    {
        return Point.init;
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

