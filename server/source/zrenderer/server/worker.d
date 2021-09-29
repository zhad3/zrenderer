module zrenderer.server.worker;

import vibe.core.log;
import vibe.core.task : Task;
import vibe.core.concurrency : send;

import zrenderer.server.requestdata : RenderRequestData;
import config : Config;
import resource : ResourceManager, ResourceException;
import resolver : Resolver;
import luamanager : loadRequiredLuaFiles;
import luad.state : LuaState;

/// Throws ResourceException
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
        import logging : LogLevel;

        void logger (LogLevel logLevel, string msg)
        {
            switch (logLevel)
            {
                case LogLevel.trace:
                    logTrace(msg);
                    break;
                default:
                case LogLevel.info:
                    logInfo(msg);
                    break;
                case LogLevel.warning:
                    logWarn(msg);
                    break;
                case LogLevel.error:
                    logError(msg);
                    break;
                case LogLevel.critical:
                    logCritical(msg);
                    break;
                case LogLevel.fatal:
                    logFatal(msg);
                    break;
            }
        }

        immutable(string)[] filenames = cast(immutable(string)[]) run(config, &logger, L, resManager, resolver);

        send(caller, filenames);
    }
    catch (Throwable e)
    {
        logError("%s in %s:%d", e.msg, e.file, e.line);
        try
        {
            send(caller, true); // Don't make the caller wait and tell it we failed
        }
        catch (Throwable e2)
        {
            // I have no clue what is supposed to be thrown here. Docs say nothing.
            // Not even gonna bother logging anything, because at this point the whole
            // service is dead anyway
        }
    }
}
