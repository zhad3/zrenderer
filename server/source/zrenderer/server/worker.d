module zrenderer.server.worker;

import vibe.core.log : logError;
import vibe.core.task : Task;
import vibe.core.concurrency : send;

import zrenderer.server.requestdata : RenderRequestData;
import config : Config;
import resource : ResourceManager, ResourceException;
import resolver : Resolver;
import luamanager : loadRequiredLuaFiles;
import luad.state : LuaState;

static ResourceManager createAndInitResourceManager(LuaState L, string resourcePath)
{
    auto resManager = new ResourceManager(resourcePath);

    loadRequiredLuaFiles(L, resManager);

    return resManager;
}

static void renderWorker(Task caller) nothrow
{
    try
    {
        static isInitialized = false;
        static LuaState L;
        static ResourceManager resManager;
        static Resolver resolver;

        import vibe.core.concurrency : receiveOnly;

        immutable config = receiveOnly!(immutable Config)();

        if (!isInitialized)
        {
            L = new LuaState;
            L.openLibs();
            resManager = createAndInitResourceManager(L, config.resourcepath);
            resolver = new Resolver(L);
            isInitialized = true;
        }

        import app : run;
        import vibe.core.log : logInfo;

        immutable(string)[] filenames = cast(immutable(string)[]) run(config, delegate(string) => logInfo(string), L, resManager, resolver);


        send(caller, filenames);
    }
    catch (Throwable e)
    {
        logError("%s in %s:%d", e.msg, e.file, e.line);
        return;
    }
}
