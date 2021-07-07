module zrenderer.server.api;

import config;
import vibe.data.json;
import vibe.web.rest;

struct RenderRequestData
{
    @optional uint action = 0;
    @optional int frame = 0;
    @optional Gender gender = Gender.male;
    @optional uint head = 1;
    @optional uint garment = 0;
    @optional uint weapon = 0;
    @optional uint shield = 0;
    @optional int bodyPalette = -1;
    @optional int headPalette = -1;
    @optional bool enableShadow = true;
    @optional uint[] headgear = [];
    string[] job;
}

struct RenderResponseData
{
    /// Status of 0 means OK. Anything above is an error.
    int status;
    /// Contains a message regarding the returned status. On status 0 it reads "OK", otherwise an error message.
    string message;
    /// Contains one or more paths the the rendered sprites.
    string[] renders;
}

@path("/")
interface Api
{
    Json postRender(string[] job, uint action = 0, int frame = 0, Gender gender = Gender.male,
            uint head = 1, uint garment = 0, uint weapon = 0, uint shield = 0,
            int bodyPalette = -1, int headPalette = -1, bool enableShadow = true, uint[] headgear = []) @trusted;
}

class ApiImpl : Api
{
    import luad.state : LuaState;
    import resolver : Resolver;
    import resource : ResourceManager;

    private
    {
        Config defaultConfig;
        LuaState L;
        ResourceManager resManager;
        Resolver resolve;
    }

    this(Config defaultConfig, LuaState L, ResourceManager resManager, Resolver resolve)
    {
        this.defaultConfig = defaultConfig;
        this.L = L;
        this.resManager = resManager;
        this.resolve = resolve;
    }

    void logDelegate(string msg)
    {
        import vibe.core.log : logError;

        logError(msg);
    }

    Json postRender(string[] job, uint action = 0, int frame = 0, Gender gender = Gender.male,
            uint head = 1, uint garment = 0, uint weapon = 0, uint shield = 0,
            int bodyPalette = -1, int headPalette = -1, bool enableShadow = true, uint[] headgear = []) @trusted
    {
        RenderResponseData res;

        import app : isJobArgValid;

        if (!isJobArgValid(job))
        {
            res.status = 1;
            res.message = "Invalid job ids";
            res.renders = [""];

            return res.serializeToJson();
        }

        Config mergedConfig = defaultConfig;
        mergedConfig.job = job;
        mergedConfig.action = action;
        mergedConfig.frame = frame;
        mergedConfig.gender = gender;
        mergedConfig.head = head;
        mergedConfig.garment = garment;
        mergedConfig.weapon = weapon;
        mergedConfig.shield = shield;
        mergedConfig.bodyPalette = bodyPalette;
        mergedConfig.headPalette = headPalette;
        mergedConfig.enableShadow = enableShadow;
        mergedConfig.headgear = headgear;
        //RenderRequestData defaultData;
        //static foreach (memberName; __traits(allMembers, RenderRequestData))
        //{
        //    if (__traits(getMember, data, memberName) != __traits(getMember, defaultData, memberName))
        //    {
        //        __traits(getMember, mergedConfig, memberName) = __traits(getMember, data, memberName);
        //    }
        //}

        import resource.base : ResourceException;

        try
        {
            import app : run;

            auto filenames = run(mergedConfig, &logDelegate, L, resManager, resolve);

            res.status = 0;
            res.message = "OK";
            res.renders = filenames;
        }
        catch (ResourceException err)
        {
            res.status = 1;
            res.message = err.msg;
            res.renders = [""];
        }

        return res.serializeToJson();
    }
}
