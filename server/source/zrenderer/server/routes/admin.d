module zrenderer.server.routes.admin;

import vibe.data.json;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.status;
import zrenderer.server.auth : AccessToken, checkAuth, isAllowedToSetTokenData;
import zrenderer.server.globals : accessTokens, defaultConfig;
import zrenderer.server.routes : setErrorResponse, setOkResponse, mergeStruct, unauthorized;

void getAccessTokens(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull() || (!accessToken.get.isAdmin &&
            !accessToken.get.capabilities.readAccessTokens))
    {
        unauthorized(res);
        return;
    }

    import std.algorithm.iteration : filter, map;
    import std.range : tee;
    import std.array : array;

    res.writeJsonBody(accessTokens.tokenMap
            .byValue()
            .filter!(token => accessToken.get.isAdmin || !token.isAdmin)
            .map!((token) {
                auto t = serializeToJson(token);
                t.remove("isValid");
                if (!accessToken.get.isAdmin)
                    t.remove("isAdmin");
                return t;
            })
            .array);
}

void newAccessToken(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull() || (!accessToken.get.isAdmin && !accessToken.get
            .capabilities.createAccessTokens))
    {
        unauthorized(res);
        return;
    }

    if (req.json == Json.undefined)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Expected json input");
        return;
    }

    import zrenderer.server.dto : AccessTokenData;

    AccessTokenData tokenData;

    try
    {
        tokenData = deserializeJson!AccessTokenData(req.json);
    }
    catch (Exception err)
    {
        setErrorResponse(res, HTTPStatus.badRequest, err.msg);
        return;
    }

    if (!tokenData.description.isNull)
    {
        import std.array : replace;

        tokenData.description = tokenData.description.get.replace(",", "");
        if (tokenData.description.get.length == 0)
        {
            tokenData.description.nullify();
        }
    }

    if (tokenData.description.isNull)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Mandatory 'description' is missing");
        return;
    }

    if (!accessToken.get.isAdmin && !isAllowedToSetTokenData(accessToken.get, tokenData))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Not allowed to set token capability/property");
        return;
    }

    accessTokens.mtx.lock();
    scope (exit)
        accessTokens.mtx.unlock();

    import std.stdio : File;
    import std.exception : ErrnoException;
    import zrenderer.server.auth : serializeAccessToken;

    try
    {
        auto tokenfile = File(defaultConfig.tokenfile, "w+");
        tokenfile.lock();
        scope (exit)
            tokenfile.unlock();

        auto newToken = mergeStruct(accessTokens.generateAccessToken(), tokenData);

        accessTokens.storeToken(newToken);
        tokenfile.write(accessTokens.serialize());
        res.writeJsonBody(Json(["token": Json(newToken.token), "id": Json(newToken.id)]));
    }
    catch (ErrnoException err)
    {
        setErrorResponse(res, HTTPStatus.internalServerError, "Failed to persist tokens file");
    }
}

void modifyAccessToken(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull() || (!accessToken.get.isAdmin && !accessToken.get
            .capabilities.modifyAccessTokens))
    {
        unauthorized(res);
        return;
    }

    if (req.json == Json.undefined)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Expected json input");
        return;
    }

    import std.exception : ifThrown;
    import std.conv : to;

    const tokenId = req.params["id"].to!uint.ifThrown(uint.max);

    if (tokenId == uint.max)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid token id provided");
        return;
    }

    import zrenderer.server.dto : AccessTokenData;

    AccessTokenData tokenData;

    try
    {
        tokenData = deserializeJson!AccessTokenData(req.json);
    }
    catch (Exception err)
    {
        setErrorResponse(res, HTTPStatus.badRequest, err.msg);
        return;
    }

    if (!accessToken.get.isAdmin && !isAllowedToSetTokenData(accessToken.get, tokenData))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Not allowed to set token capability/property");
        return;
    }

    if (!tokenData.description.isNull)
    {
        import std.array : replace;

        tokenData.description = tokenData.description.get.replace(",", "");
        if (tokenData.description.get.length == 0)
        {
            tokenData.description.nullify();
        }
    }

    accessTokens.mtx.lock();
    scope (exit)
        accessTokens.mtx.unlock();

    auto existingToken = accessTokens.getById(tokenId);
    if (existingToken.isNull)
    {
        setErrorResponse(res, HTTPStatus.notFound, "Token doesn't exist");
        return;
    }
    else if (existingToken.get.isAdmin)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Cannot change token");
        return;
    }

    import std.stdio : File;
    import std.exception : ErrnoException;
    import zrenderer.server.auth : serializeAccessToken;

    try
    {
        auto tokenfile = File(defaultConfig.tokenfile, "w+");
        tokenfile.lock();
        scope (exit)
            tokenfile.unlock();

        auto updatedToken = mergeStruct(existingToken.get, tokenData);

        accessTokens.storeToken(updatedToken);
        tokenfile.write(accessTokens.serialize());
        setOkResponse(res);
    }
    catch (ErrnoException err)
    {
        setErrorResponse(res, HTTPStatus.internalServerError, "Failed to persist tokens file");
    }
}

void revokeAccessToken(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull() || (!accessToken.get.isAdmin && !accessToken.get
            .capabilities.revokeAccessTokens))
    {
        unauthorized(res);
        return;
    }

    import std.exception : ifThrown;
    import std.conv : to;

    const tokenId = req.params["id"].to!uint.ifThrown(uint.max);

    if (tokenId == uint.max)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid token id provided");
        return;
    }

    accessTokens.mtx.lock();
    scope (exit)
        accessTokens.mtx.unlock();

    auto existingToken = accessTokens.getById(tokenId);
    if (existingToken.isNull)
    {
        setErrorResponse(res, HTTPStatus.notFound, "Token doesn't exist");
        return;
    }
    else if (existingToken.get.isAdmin)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Cannot revoke token");
        return;
    }

    import std.stdio : File;
    import std.exception : ErrnoException;
    import zrenderer.server.auth : serializeAccessToken;

    try
    {
        auto tokenfile = File(defaultConfig.tokenfile, "w+");
        tokenfile.lock();
        scope (exit)
            tokenfile.unlock();

        accessTokens.removeById(tokenId);
        tokenfile.write(accessTokens.serialize());
        setOkResponse(res);
    }
    catch (ErrnoException err)
    {
        setErrorResponse(res, HTTPStatus.internalServerError, "Failed to persist tokens file");
    }
}

void getHealth(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull() || (!accessToken.get.isAdmin && !accessToken.get
            .capabilities.readHealth))
    {
        unauthorized(res);
        return;
    }

    auto reply = Json(["up": Json(true)]);

    if (accessToken.get.isAdmin)
    {
        import core.memory : GC;

        reply["gc"] = Json(["usedSize": Json(GC.stats.usedSize), "freeSize": Json(GC.stats.freeSize)]);
    }

    res.writeJsonBody(reply);
}
