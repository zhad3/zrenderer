module zrenderer.server.auth;

import core.sync.mutex : Mutex;
import std.typecons : Tuple, Nullable;
import vibe.core.log : logWarn, logError;
import vibe.http.server : HTTPServerRequest;
import zrenderer.server.dto.accesstoken : AccessTokenData, CapabilitiesData, PropertiesData;

private immutable TOKEN_LENGTH = 32;
private auto TOKEN_CHARACTERS = cast(immutable ubyte[]) "0123456789abcdefghijklmnopqrstuvwxyz";

struct AccessToken
{
    uint id;
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
    bool modifyAccessTokens;
    bool readAccessTokens;
    bool readHealth;
}

struct Properties
{
    int maxJobIdsPerRequest = -1;
    int maxRequestsPerHour = -1;
}

class AccessTokenDB
{
    Mutex mtx;
    int lastId = -1;
    AccessToken[string] tokenMap;
    AccessToken[uint] idMap;

    this()
    {
        mtx = new Mutex();
    }

    Nullable!AccessToken getByToken(const scope string accessToken) pure nothrow @safe @nogc
    {
        auto token = accessToken in tokenMap;
        if (token is null)
        {
            return Nullable!AccessToken.init;
        }
        return Nullable!AccessToken(*token);
    }

    Nullable!AccessToken getById(uint id) pure nothrow @safe @nogc
    {
        auto token = id in idMap;
        if (token is null)
        {
            return Nullable!AccessToken.init;
        }
        return Nullable!AccessToken(*token);
    }

    void storeToken(AccessToken token) nothrow @safe
    {
        if (token.id > lastId)
        {
            lastId = token.id;
        }
        tokenMap[token.token] = token;
        idMap[token.id] = token;
    }

    AccessToken generateAccessToken() nothrow @safe
    {
        AccessToken token;

        token.id = ++lastId;
        token.token = generateToken();

        return token;
    }

    bool removeByToken(const scope string token) nothrow @safe
    {
        const existingToken = getByToken(token);
        if (existingToken.isNull)
        {
            return false;
        }

        const id = existingToken.get.id;

        idMap.remove(id);
        tokenMap.remove(token);

        return true;
    }

    bool removeById(uint id) nothrow @safe
    {
        const existingToken = getById(id);
        if (existingToken.isNull)
        {
            return false;
        }

        const token = existingToken.get.token;

        idMap.remove(id);
        tokenMap.remove(token);

        return true;
    }

    string serialize() @safe
    {
        import std.algorithm : map, sort;
        import std.array : array, join;
        import std.ascii : newline;
        import std.conv : to;

        return lastId.to!string ~ newline ~
            tokenMap.byValue()
            .array
            .sort!((a, b) => a.id < b.id)
            .map!(token => serializeAccessToken(token))
            .join(newline);
    }
}

Nullable!AccessToken checkAuth(HTTPServerRequest req, AccessTokenDB tokens) @safe
{
    import std.exception : ifThrown;

    const tokenString = req.query["accesstoken"].ifThrown(string.init);

    if (tokenString == string.init)
    {
        return Nullable!AccessToken.init;
    }

    auto token = tokens.getByToken(tokenString);

    if (!token.isNull)
    {
        // Placing the token description into the request allows us to include it in the access log
        req.headers["x-token-desc"] = token.get.description;
    }

    return token;
}

AccessTokenDB parseAccessTokensFile(const scope string filename)
{
    AccessTokenDB tokenDB = new AccessTokenDB;

    bool foundAdmin = false;
    int adminCount = 0;

    try
    {
        import std.algorithm.iteration : each, map, fold, filter, cache;
        import std.conv : to, ConvException;
        import std.range : enumerate;
        import std.stdio : File;

        auto file = File(filename, "r");
        string lastId = file.readln();

        try
        {
            if (lastId.length == 0 || (lastId.length == 1 && lastId[0] == '\n') ||
                    (lastId.length == 2 && lastId[0] == '\r' && lastId[1] == '\n'))
            {
                throw new ConvException("Empty lastId");
            }
            if (lastId[$ - 1] == '\r')
            {
                tokenDB.lastId = lastId[0 .. $ - 2].to!uint(10);
            }
            else
            {
                tokenDB.lastId = lastId[0 .. $ - 1].to!uint(10);
            }
        }
        catch (ConvException err)
        {
            logError("AccessToken: Invalid token file. Couldn't read first line for 'lastId'. " ~
                    "The server will continue to start but no access will be possible! " ~
                    "Access tokens file requires manual fixing! %s", err.msg);
            return tokenDB;
        }

        file.byLine()
            .enumerate
            .map!(parseAccessTokenLine)
            .cache
            .filter!(token => token.isValid)
            .each!((token) {
                bool tokenDoesntExist = token.token !in tokenDB.tokenMap;
                bool idDoesntExist = token.id !in tokenDB.idMap;
                if (!tokenDoesntExist)
                {
                    logWarn("AccessToken: Duplicate token: %s. Token will be ignored.", token.token);
                }
                if (!idDoesntExist)
                {
                    logWarn("AccessToken: Duplicate id: %s. Token will be ignored.", token.token);
                }
                if (token.id > tokenDB.lastId)
                {
                    logWarn("AccessToken: Found token id (%d) greater than lastId (%d)! " ~
                        "Will set lastId to this higher id.", token.id, tokenDB.lastId);
                    tokenDB.lastId = token.id;
                }
                if (tokenDoesntExist && idDoesntExist && (!token.isAdmin || !foundAdmin))
                {
                    tokenDB.storeToken(token);
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

    return tokenDB;
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
                import std.conv : to, ConvException;

                try
                {
                    accesstoken.id = value.to!uint;
                }
                catch (ConvException err)
                {
                    logWarn("AccessToken (line:%d): Encountered invalid id: %s", lineNumber, value);
                    return No.each;
                }
                break;
            case 1:
                if (!validToken(value))
                {
                    logWarn("AccessToken (line:%d): Encountered invalid token: %s", lineNumber, value);
                    return No.each;
                }
                accesstoken.token = value.dup;
                break;
            case 2:
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

bool validToken(const scope char[] token) pure nothrow @safe @nogc
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

string serializeAccessToken(const scope AccessToken accessToken) @safe
{
    import std.array : appender;
    import std.format : formattedWrite;

    auto app = appender!string;

    app.formattedWrite("%u,%s,%s,", accessToken.id, accessToken.token, accessToken.description);

    if (accessToken.isAdmin)
    {
        app.put("admin,");
    }

    foreach (memberName; __traits(allMembers, Capabilities))
    {
        import std.traits : isBoolean;

        alias member = __traits(getMember, accessToken.capabilities, memberName);
        static if (isBoolean!(typeof(member)))
        {
            if (__traits(getMember, accessToken.capabilities, memberName) == true)
            {
                app.put(memberName ~ ",");
            }
        }
    }

    immutable Properties defaultProperties;
    foreach (memberName; __traits(allMembers, Properties))
    {
        import std.traits : isNumeric;

        alias member = __traits(getMember, accessToken.properties, memberName);
        static if (isNumeric!(typeof(member)))
        {
            if (__traits(getMember, accessToken.properties, memberName) != __traits(getMember, defaultProperties, memberName))
            {
                import std.conv : to, ConvException;

                try
                {
                    app.formattedWrite("%s=%s,", memberName,
                            (__traits(getMember, accessToken.properties, memberName)).to!string);
                }
                catch (ConvException err)
                {
                    // This should never happen
                    logWarn("AccessToken: Couldn't serialize access token (%s). Error: %s.", accessToken.id, err
                            .msg);
                }
            }
        }
    }
    return app.data[0 .. $ - 1]; // Cut of trailing comma
}

/**
  Function goes through the tokenData and checks if it contains any capability or property
  which the requester themselves do not have
*/
bool isAllowedToSetTokenData(const AccessToken accessToken, AccessTokenData tokenData) pure nothrow @safe @nogc
{
    if (!tokenData.capabilities.isNull)
    {
        auto capabilities = tokenData.capabilities.get;
        static foreach (memberName; __traits(allMembers, CapabilitiesData))
        {
            static if (__traits(compiles, (__traits(getMember, capabilities, memberName)).isNull))
            {
                if (!(__traits(getMember, capabilities, memberName)).isNull &&
                        __traits(getMember, capabilities, memberName).get == true &&
                        __traits(getMember, accessToken.capabilities, memberName) == false)
                {
                    return false;
                }
            }
        }
    }

    if (!tokenData.properties.isNull)
    {
        auto properties = tokenData.properties.get;
        static foreach (memberName; __traits(allMembers, PropertiesData))
        {
            static if (__traits(compiles, (__traits(getMember, properties, memberName)).isNull))
            {
                if (!(__traits(getMember, properties, memberName)).isNull &&
                        __traits(getMember, properties, memberName).get > __traits(getMember, accessToken.properties, memberName))
                {
                    return false;
                }
            }
        }
    }

    return true;
}
