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
import vibe.http.log : HTTPLogger;
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

    if (defaultConfig.enableCORS)
    {
        router.any("*", &addCORSOriginHeader);
    }
    router.post("/render", &handleRenderRequest);
    router.get("/token/info", &getAccessTokenInfo);
    router.get("/admin/tokens", &getAccessTokens);
    router.post("/admin/tokens", &newAccessToken);
    router.post("/admin/tokens/:id", &modifyAccessToken);
    router.delete_("/admin/tokens/:id", &revokeAccessToken);
    router.get("/admin/health", &getHealth);

    if (defaultConfig.enableCORS)
    {
        router.corsOptionsRoute!("/render", "POST");
        router.corsOptionsRoute!("/token/info", "GET");
        router.corsOptionsRoute!("/admin/tokens", "GET, POST");
        router.corsOptionsRoute!("/admin/tokens/:id", "POST, DELETE");
        router.corsOptionsRoute!("/admin/health", "GET");
    }

    auto settings = new HTTPServerSettings;
    settings.bindAddresses = config.hosts;
    settings.port = config.port;
    settings.accessLogFormat = "%h - %u %t \"%r\" %s %b \"%{Referer}i\" \"%{User-Agent}i\" \"%{x-token-desc}i\"";
    settings.accessLogger = new MaskedConsoleLogger(settings, settings.accessLogFormat);

    if (defaultConfig.enableSSL)
    {
        import vibe.stream.tls : createTLSContext, TLSContextKind;

        settings.tlsContext = createTLSContext(TLSContextKind.server);
        settings.tlsContext.useCertificateChainFile(defaultConfig.certificateChainFile);
        settings.tlsContext.usePrivateKeyFile(defaultConfig.privateKeyFile);
    }

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
        accessToken.isValid = true;
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

class MaskedConsoleLogger : HTTPLogger
{
    import std.regex : regex, replaceAll;

    auto accesstokenRegex = regex(r"(accesstoken=)([^&\n\r\t\s]+)");

    this(HTTPServerSettings settings, string format)
    {
        super(settings, format);
    }

    override void writeLine(const(char)[] ln)
    {
        import vibe.core.log : logInfo;

        logInfo("%s", replaceAll(ln, accesstokenRegex, "$1***"));
    }
}

void corsOptionsRoute(string path, string methods)(URLRouter router)
{
    router.match(HTTPMethod.OPTIONS, path,
       delegate void(HTTPServerRequest req, HTTPServerResponse res) @safe
       {
           const allowHeaders = req.headers.get("Access-Control-Request-Headers", string.init);
           if (allowHeaders != string.init)
           {
                res.headers.addField("Access-Control-Allow-Headers", allowHeaders);
                const varyHeader = res.headers.get("Vary", string.init);
                if (varyHeader != string.init)
                {
                    res.headers["Vary"] = varyHeader ~ ", Access-Control-Request-Headers";
                }
                else
                {
                    res.headers.addField("Vary", "Access-Control-Request-Headers");
                }
           }
           res.headers.addField("Access-Control-Allow-Methods", methods);
           res.statusCode = HTTPStatus.noContent;
           res.writeBody("");
       });
}
