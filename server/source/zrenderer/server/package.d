module zrenderer.server;

import zrenderer.server.api;
import config : Config;
import vibe.core.core;
import vibe.http.router;
import vibe.http.server;
import vibe.web.rest;
import zconfig : initializeConfig, getConfigArguments;

enum usage = "A REST server to render sprites from a Gravity game";

int main(string[] args)
{
    string[] configArgs = getConfigArguments!Config("zrenderer.conf", args);
    if (configArgs.length > 0)
    {
        import std.array : insertInPlace;

        args.insertInPlace(1, configArgs);
    }
    import std.getopt : GetOptException;

    Config config;
    bool helpWanted = false;

    try
    {
        config = initializeConfig!(Config, usage)(args, helpWanted);

        import std.exception : enforce;
        import app : isJobArgValid;

        enforce!GetOptException(isJobArgValid(config.job), "job ids are not valid.");
    }
    catch (GetOptException e)
    {
        import std.stdio : stderr;

        stderr.writefln("Error parsing options: %s", e.msg);
        return 1;
    }

    if (helpWanted)
    {
        return 0;
    }

    import app : createOutputDirectory;

    createOutputDirectory(config.outdir);

    import luad.state : LuaState;

    LuaState L = new LuaState;
    L.openLibs();

    import resource : ResourceManager;

    ResourceManager resManager = new ResourceManager(config.resourcepath);

    import luamanager : loadRequiredLuaFiles;

    loadRequiredLuaFiles(L, resManager);

    import resolver : Resolver;

    Resolver resolve = new Resolver(L);

    if (config.logfile.length > 0)
    {
        import vibe.core.log : registerLogger, FileLogger;

        registerLogger(cast(shared) new FileLogger(config.logfile));
    }

    auto router = new URLRouter;
    router.registerRestInterface(new ApiImpl(config, L, resManager, resolve));

    auto settings = new HTTPServerSettings;
    settings.bindAddresses = config.hosts;
    settings.port = config.port;
    auto listener = listenHTTP(settings, router);

    runApplication();

    listener.stopListening();

    return 0;
}
