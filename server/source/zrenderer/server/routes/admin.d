module zrenderer.server.routes.admin;

import vibe.data.json;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.status;
import zrenderer.server.auth : AccessToken, checkAuth;
import zrenderer.server.globals : accessTokens, defaultConfig;
import zrenderer.server.routes : setErrorResponse, mergeStruct;

private void unauthorized(HTTPServerResponse res)
{
    setErrorResponse(res, HTTPStatus.unauthorized, "Unauthorized");
}

void getAccessTokens(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull() || (!accessToken.get.isAdmin && !accessToken.get.capabilities.readAccessTokens))
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
                return t;
            })
            .array);
}

void postAccessToken(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull() || (!accessToken.get.isAdmin && !accessToken.get.capabilities.createAccessTokens))
    {
        unauthorized(res);
        return;
    }

    if (req.json == Json.undefined)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Expected json input");
        return;
    }

    import std.conv : ConvException;
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

    synchronized
    {
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
}

