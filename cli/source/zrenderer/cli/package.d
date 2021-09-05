module zrenderer.cli;

import config : Config;
import zconfig : initializeConfig, getConfigArguments;

enum usage = "A tool to render sprites from Ragnarok Online";

int main(string[] args)
{
    string[] configArgs = getConfigArguments!Config("zrenderer.conf", args);

    if (configArgs.length > 0)
    {
        import std.array : insertInPlace;

        args.insertInPlace(1, configArgs);
    }
    import std.getopt : GetOptException;
    import std.conv : ConvException;

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
    catch (ConvException e)
    {
        import std.stdio : stderr;

        stderr.writefln("Error parsing options: %s", e.msg);
        return 1;
    }

    if (helpWanted)
    {
        return 0;
    }

    import app : run, createOutputDirectory, LogFunc;

    createOutputDirectory(config.outdir);

    void consoleLogger(string msg)
    {
        import std.stdio : writeln;

        writeln(msg);
    }

    run(cast(immutable) config, &consoleLogger);

    return 0;
}
