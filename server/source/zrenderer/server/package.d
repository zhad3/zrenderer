module zrenderer.server;

import app : createOutputDirectory;
import config : Config;
import logging : zLogLevel = LogLevel;
import std.conv : ConvException;
import std.getopt : GetOptException;
import std.stdio : stderr;
import vibe.core.core;
import vibe.core.log : LogLevel;
import vibe.http.router;
import vibe.http.server;
import zconfig : initializeConfig, getConfigArguments;
import zrenderer.server.auth;
import zrenderer.server.globals : defaultConfig, accessTokens;
import zrenderer.server.routes;

enum usage = "A REST server to render sprites from Ragnarok Online";

int main(string[] args)
{
    string[] configArgs = getConfigArguments!Config("zrenderer.conf", args);
    if (configArgs.length > 0)
    {
        import std.array : insertInPlace;

        args.insertInPlace(1, configArgs);
    }

    Config config;
    bool helpWanted = false;

    try
    {
        config = initializeConfig!(Config, usage)(args, helpWanted);

        import std.exception : enforce;
        import validation : isJobArgValid, isCanvasArgValid;

        enforce!GetOptException(isJobArgValid(config.job), "job ids are not valid.");
        enforce!GetOptException(isCanvasArgValid(config.canvas), "canvas is not valid.");
    }
    catch (GetOptException e)
    {
        stderr.writefln("Error parsing options: %s", e.msg);
        return 1;
    }
    catch (ConvException e)
    {
        stderr.writefln("Error parsing options: %s", e.msg);
        return 1;
    }

    if (helpWanted)
    {
        return 0;
    }

    defaultConfig = config;

    createOutputDirectory(config.outdir);

    if (config.logfile.length > 0)
    {
        import vibe.core.log : registerLogger, FileLogger;

        auto filelogger = cast(shared) new FileLogger(config.logfile);
        filelogger.minLevel = config.loglevel.toVibeLogLevel();

        registerLogger(filelogger);
    }

    if (!createOrLoadAccessTokens(config.tokenfile))
    {
        return 1;
    }

    auto router = new URLRouter;

    router.post("/render", &handleRenderRequest);
    router.get("/token/info", &getAccessTokenInfo);
    router.get("/admin/tokens", &getAccessTokens);
    router.post("/admin/tokens", &newAccessToken);
    router.post("/admin/tokens/:id", &modifyAccessToken);
    router.delete_("/admin/tokens/:id", &revokeAccessToken);
    router.get("/admin/health", &getHealth);

    auto settings = new HTTPServerSettings;
    settings.bindAddresses = config.hosts;
    settings.port = config.port;
    settings.accessLogToConsole = true;
    auto listener = listenHTTP(settings, router);

    import vibe.core.args : finalizeCommandLineOptions;

    finalizeCommandLineOptions(null);

    try
    {
        runApplication();
    }
    catch (Throwable e)
    {
        import vibe.core.log : logError;

        logError("%s in %s:%d", e.msg, e.file, e.line);
    }

    listener.stopListening();

    return 0;
}

bool createOrLoadAccessTokens(const scope string tokenfilename)
{
    import std.file : exists, FileException;

    if (!exists(tokenfilename))
    {
        accessTokens = new AccessTokenDB;

        AccessToken accessToken = accessTokens.generateAccessToken();
        accessToken.isAdmin = true;
        accessToken.description = "Auto-generated Admin Token";

        try
        {
            import std.string : join;
            import std.stdio : File;

            auto f = File(tokenfilename, "w");
            f.writeln(accessTokens.lastId);
            f.writeln(serializeAccessToken(accessToken));
        }
        catch (FileException err)
        {
            stderr.writeln(err.message);
            return false;
        }

        import std.stdio : writefln;

        writefln("Created access token file including a randomly generated admin token: %s", accessToken.token);
        accessTokens.storeToken(accessToken);
    }
    else
    {
        accessTokens = parseAccessTokensFile(tokenfilename);
    }

    return true;
}

LogLevel toVibeLogLevel(zLogLevel loglevel) pure nothrow @safe @nogc
{
    switch (loglevel)
    {
        case zLogLevel.all:
            return LogLevel.min;
        case zLogLevel.trace:
            return LogLevel.trace;
        case zLogLevel.info:
            return LogLevel.info;
        case zLogLevel.warning:
            return LogLevel.warn;
        case zLogLevel.error:
            return LogLevel.error;
        case zLogLevel.critical:
            return LogLevel.critical;
        case zLogLevel.fatal:
            return LogLevel.fatal;
        case zLogLevel.off:
            return LogLevel.none;
        default:
            return LogLevel.min;
    }
}
