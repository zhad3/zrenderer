module zrenderer.server.auth;

import vibe.core.log : logWarn;
import vibe.http.server : HTTPServerRequest;

import std.typecons : Tuple;

private immutable TOKEN_LENGTH = 32;
private auto TOKEN_CHARACTERS = cast(immutable ubyte[]) "0123456789abcdefghijklmnopqrstuvwxyz";

struct AccessToken
{
    string token;
    string description;
    bool isValid;
    bool isAdmin;
    Capabilities capabilities;
    Properties properties;
}

struct Capabilities
{
    bool createAccessTokens;
    bool revokeAccessTokens;
    bool readHealth;
    bool readStatistics;
}

struct Properties
{
    uint maxJobIdsPerRequest = uint.max;
    uint maxRequestsPerHour = uint.max;
}

AccessToken[string] parseAccessTokensFile(const scope string filename)
{
    AccessToken[string] accessTokens;

    bool foundAdmin = false;
    int adminCount = 0;

    try
    {
        import std.stdio : File;
        import std.algorithm.iteration : each, map, fold, filter, cache;
        import std.range : enumerate;

        auto file = File(filename, "r");
        file.byLine()
            .enumerate
            .map!(parseAccessTokenLine)
            .cache
            .filter!(token => token.isValid)
            .each!((token) {
                if (token.token !in accessTokens && (!token.isAdmin || !foundAdmin))
                {
                    accessTokens[token.token] = token;
                }
                if (token.isAdmin)
                {
                    foundAdmin = true;
                    adminCount++;
                }
            });
    }
    catch (Exception err)
    {
        logWarn(err.message);
    }

    if (adminCount > 1)
    {
        logWarn("AccessToken: Found %d access tokens with admin privileges. " ~
                "Only the first admin token will be enabled.", adminCount);
    }

    return accessTokens;
}

AccessToken parseAccessTokenLine(Tuple!(ulong, "index", char[], "value") lineTuple) @safe
{
    import std.algorithm.iteration : splitter, each;
    import std.typecons : No, Yes;

    const lineNumber = lineTuple[0];
    const(char[]) tokenLine = lineTuple[1];

    AccessToken accesstoken;

    tokenLine.splitter(',')
        .each!((index, value) {
            switch (index)
            {
            case 0:
                if (!validToken(value))
                {
                    logWarn("AccessToken (line:%d): Encountered invalid token: %s", lineNumber, value);
                    return No.each;
                }
                accesstoken.token = value.dup;
                break;
            case 1:
                accesstoken.description = value.dup;
                accesstoken.isValid = true;
                break;
            default:
                setPropertyOnAccessToken(lineNumber, value, accesstoken);
                break;
            }
            return Yes.each;
        });

    return accesstoken;
}

bool validToken(const scope char[] token) pure nothrow @safe
{
    auto i = 0;
    foreach (c; token)
    {
        if (c < 0x30 ||
                (c > 0x39 && c < 0x61) ||
                c > 0x7A ||
                (i++) > TOKEN_LENGTH)
        {
            return false;
        }
    }

    if (i < TOKEN_LENGTH)
    {
        return false;
    }

    return true;
}

string generateToken() nothrow @safe
{
    ubyte[] token = new ubyte[TOKEN_LENGTH];

    foreach (i; 0 .. TOKEN_LENGTH)
    {
        try
        {
            import std.random : uniform;

            token[i] = TOKEN_CHARACTERS[uniform(0, TOKEN_CHARACTERS.length)];
        }
        catch (Exception err)
        {
            // Will never throw
        }
    }

    import std.string : assumeUTF;

    return token.assumeUTF;
}

private void setPropertyOnAccessToken(const long lineNumber, const scope char[] prop, ref AccessToken token) @safe
{
    import std.algorithm.iteration : splitter;
    import std.range : take;
    import std.array : array;

    alias setPropertyFunc = void delegate(const scope char[] value) @safe;

    bool*[string] availableCapabilities;
    setPropertyFunc[string] availableProperties;

    foreach (memberName; __traits(allMembers, Capabilities))
    {
        availableCapabilities[memberName] = &(__traits(getMember, token.capabilities, memberName));
    }

    foreach (memberName; __traits(allMembers, Properties))
    {
        alias Type = typeof(__traits(getMember, token.properties, memberName));
        availableProperties[memberName] = (const scope char[] value) @safe {
            import std.conv : to;

            __traits(getMember, token.properties, memberName) = value.to!Type;
        };
    }

    auto keyvalue = prop.splitter('=').take(2).array;

    if (keyvalue.length == 1)
    {
        const key = keyvalue[0];
        if (key == "admin")
        {
            token.isAdmin = true;
        }
        else
        {
            auto refValue = key in availableCapabilities;
            if (refValue !is null)
            {
                **refValue = true;
            }
            else
            {
                logWarn("AccessToken (line:%d): Unknown capability found: %s", lineNumber, key);
            }
        }
    }
    else
    {
        const key = keyvalue[0];
        const value = keyvalue[1];
        auto setFunc = key in availableProperties;

        if (setFunc !is null)
        {
            import std.conv : ConvException;

            try
            {
                (*setFunc)(value);
            }
            catch (ConvException err)
            {
                logWarn("AccessToken (line:%d): Invalid property value: Property: %s, Value: %s",
                        lineNumber, key, value);
            }
        }
        else
        {
            logWarn("AccessToken (line:%d): Unknown property: %s", lineNumber, key);
        }
    }
}
