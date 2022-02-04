module zrenderer.server.routes;

public import zrenderer.server.routes.admin;
public import zrenderer.server.routes.render;
public import zrenderer.server.routes.token;

import std.typecons : Nullable;
import vibe.data.json;
import vibe.http.server : HTTPServerResponse, HTTPServerRequest;
import vibe.http.status;
import zrenderer.server.auth : AccessToken;
import zrenderer.server.globals : defaultConfig;

void setErrorResponse(ref HTTPServerResponse res, HTTPStatus httpStatus, const scope string message = string.init)
{
    res.statusCode = httpStatus;
    auto jsonResponse = Json(["statusMessage": Json(message)]);
    res.writeJsonBody(jsonResponse);
}

void setOkResponse(ref HTTPServerResponse res, const scope string message = string.init)
{
    res.statusCode = HTTPStatus.ok;
    if (message == string.init)
    {
        res.writeJsonBody(Json(["statusMesage": Json("Ok")]));
    }
    else
    {
        res.writeJsonBody(Json(["statusMessage": Json(message)]));
    }
}

void unauthorized(HTTPServerResponse res)
{
    setErrorResponse(res, HTTPStatus.unauthorized, "Unauthorized");
}

void addCORSOriginHeader(HTTPServerRequest req, HTTPServerResponse res)
{
    // If Origin is not set we assume that this is not a CORS request
    immutable origin = req.headers.get("Origin", string.init);
    if (origin != string.init)
    {
        import std.algorithm.searching : canFind;

        const allowOrigins = defaultConfig.allowCORSOrigin;

        if (allowOrigins.length > 1)
        {
            res.headers.addField("Vary", "Origin");
        }

        if (allowOrigins.length > 0)
        {
            if (allowOrigins[0] == "*")
            {
                res.headers.addField("Access-Control-Allow-Origin", "*");
            }
            else if (allowOrigins.canFind(origin))
            {
                res.headers.addField("Access-Control-Allow-Origin", origin);
            }
            else
            {
                res.headers.addField("Access-Control-Allow-Origin", defaultConfig.allowCORSOrigin[0]);
            }
        }
        else
        {
            res.headers.addField("Access-Control-Allow-Origin", "*");
        }
    }
}

void logCustomRequest(HTTPServerRequest req, const scope string message,
        Nullable!AccessToken accessToken = Nullable!AccessToken.init) @safe
{
    import std.exception : ifThrown;
    import std.format : format;
    import vibe.core.log : logInfo;

    auto remoteHost = req.headers["X-REAL-IP"].ifThrown(req.peer);

    logInfo("%s - %s %s \"%s\" -- Token: %s",
            remoteHost,
            req.username.length > 0 ? req.username : "-",
            req.timeCreated.toSimpleString(),
            message,
            accessToken.isNull ? "-" : format("%s Id: %u Desc: %s",
                accessToken.get.token,
                accessToken.get.id,
                accessToken.get.description));

}

T mergeStruct(T, S)(T target, S source) pure nothrow @safe
{
    T mergedStruct = target;

    static foreach (memberName; __traits(allMembers, S))
    {
        static if (__traits(hasMember, mergedStruct, memberName))
        {
            static if (__traits(compiles, (__traits(getMember, source, memberName)).isNull))
            {
                if (!(__traits(getMember, source, memberName)).isNull)
                {
                    static if (is(typeof(__traits(getMember, source, memberName).get) == struct) && is(typeof(__traits(getMember, target, memberName)) == struct))
                    {
                        __traits(getMember, mergedStruct, memberName) = mergeStruct!(typeof(__traits(getMember, target, memberName)), typeof(__traits(getMember, source, memberName).get))(__traits(getMember, target, memberName), __traits(getMember, source, memberName).get);
                    }
                    else
                    {
                        __traits(getMember, mergedStruct, memberName) = __traits(getMember, source, memberName).get();
                    }
                }
            }
            else
            {
                static if (is(typeof(__traits(getMember, source, memberName).get) == struct) && is(typeof(__traits(getMember, target, memberName)) == struct))
                {
                    __traits(getMember, mergedStruct, memberName) = mergeStruct!(typeof(__traits(getMember, target, memberName)), typeof(__traits(getMember, source, memberName)))(__traits(getMember, target, memberName), __traits(getMember, source, memberName));
                }
                else
                {
                    __traits(getMember, mergedStruct, memberName) = __traits(getMember, source, memberName);
                }
            }
        }
    }

    return mergedStruct;
}

