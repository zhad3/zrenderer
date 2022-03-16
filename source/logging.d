module logging;

import core.sync.mutex : Mutex;
import std.datetime : SysTime;
import std.range : Appender, appender;
import std.format : formattedWrite;

enum LogLevel : ubyte
{
    all         = 1,
    trace       = 32,
    info        = 64,
    warning     = 96,
    error       = 128,
    critical    = 160,
    fatal       = 192,
    off         = ubyte.max
}

string toString(LogLevel ll) pure nothrow @safe
{
    final switch (ll)
    {
        case LogLevel.all:
            return "ALL";
        case LogLevel.trace:
            return "TRACE";
        case LogLevel.info:
            return "INFO";
        case LogLevel.warning:
            return "WARNING";
        case LogLevel.error:
            return "ERROR";
        case LogLevel.critical:
            return "CRITICAL";
        case LogLevel.fatal:
            return "FATAL";
        case LogLevel.off:
            return "OFF";
    }
}

class BasicLogger
{
    private this(LogLevel ll) {
        _ll = ll;
    }

    private __gshared BasicLogger _instance;
    private static bool _instantiated;
    private static Mutex _mutex;

    private LogLevel _ll;

    static BasicLogger get(LogLevel ll)
    {
        if (!_instantiated)
        {
            synchronized (BasicLogger.classinfo)
            {
                if (!_instance)
                {
                    _instance = new BasicLogger(ll);
                    _mutex = new Mutex();
                }

                _instantiated = true;
            }
        }

        return _instance;
    }

    void log(A...)(LogLevel logLevel, lazy A args) const @trusted
    {
        if (logLevel >= _ll)
        {
            synchronized (_mutex)
            {
                auto msg = appender!string();

                msg.formattedWrite("[%s] ", logLevel.toString());
                foreach (arg; args)
                {
                    msg.formattedWrite("%s", arg);
                }

                import std.stdio : stdout, stderr;

                if (logLevel > logLevel.warning)
                {
                    stderr.writeln(msg.data);
                }
                else
                {
                    stdout.writeln(msg.data);
                }
            }
        }
    }

    template log(LogLevel logLevel)
    {
        void log(A...)(lazy bool condition, lazy A args) const @trusted
        {
            if (condition)
            {
                log(line, file, func, prettyFunc, mod)(args);
            }
        }

        void log (A...)(lazy A args) const @trusted
        {
            log(logLevel, args);
        }
    }

    alias trace = log!(LogLevel.trace);
    alias info = log!(LogLevel.info);
    alias warning = log!(LogLevel.warning);
    alias error = log!(LogLevel.error);
    alias critical = log!(LogLevel.critical);
    alias fatal = log!(LogLevel.fatal);
}

alias LogDg = void delegate(LogLevel, string);

